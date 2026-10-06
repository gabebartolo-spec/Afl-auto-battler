shader_type canvas_item;
// The vignettes' footballers: pre-rendered figures (figures_shade.png) recoloured
// per club and per player. Only draws from the figure sheet are recoloured - it
// is recognised by its size - so the ground, text and letterbox the same Control
// draws pass straight through.
//
// Known limitation: a draw is taken to be a figure purely by its texture's size
// (sheet_size). Any other texture with exactly those dimensions drawn through this
// material - a future background, a crowd texture at that size - would be misread as
// figures and recoloured. Nothing in the game has that size today; if one ever does,
// tell the shader explicitly (a flag in the draw colour or a uniform) instead.
//
// The shade and mask sheets are imported VRAM compressed, high quality (ASTC 4x4 on
// Android, BPTC on desktop): ETC2 breaks their weights and coordinates. The design
// sheet (guernsey coordinates: stripes, numbers) stays lossless.
//
// A figure's draw colour carries its looks, not a tint:
//   r = (kit index * 2 + mirrored) / 8, g = skin tone index / 8, b = hair index / 8,
//   a = opacity. "Mirrored" (the frame drawn flipped, to face the other way) only
//   matters to the number, which is un-mirrored so it still reads.
// Drawn a second time with g = 1 and b = (number + 1) / 128, the same frame prints
// that number on the guernsey's back instead (digits_tex), in place on the fabric:
// the same spot and size in every frame, following the shirt, hidden behind arms.
// A kit is a guernsey: base colour (guernsey and socks), pattern colour (its design
// and the sock band), a second pattern colour, the design (GameDB.GUERNSEY_DESIGNS)
// and shorts. See VignetteFigures.gd for the sheet layout.
//
// Hair overlays (VignetteFigures.HAIR_TEXTURES): the figures are bald, and each one's
// hair is drawn straight after it from its style's atlas (R lighting, A coverage),
// recognised by size like the sheet (hair_sizes). Its draw colour: g = skin tone / 8,
// b = hair index / 8, r = 1 to tint it the skin colour (a bare scalp), else the hair.

uniform sampler2D mask_tex : filter_linear;
uniform sampler2D design_tex : filter_linear;
uniform sampler2D digits_tex : filter_linear, repeat_disable;   // 0-9: R fill, G outline
uniform ivec2 sheet_size = ivec2(2048, 2304);
uniform ivec2 hair_sizes[8];
uniform int hair_count = 0;
uniform vec4 kit_base[4];
uniform vec4 kit_pattern[4];
uniform vec4 kit_pattern2[4];
uniform vec4 kit_shorts[4];
uniform float kit_design[4];
uniform vec4 skin_tones[8];
uniform vec4 hair_tones[8];
uniform vec4 boots = vec4(0.06, 0.06, 0.07, 1.0);
// The sheet's lighting is rendered a shade dark so highlights don't clip.
uniform float gain = 1.3;

// Where the number sits on the back, in guernsey coordinates (across from the
// wearer's right, up from the hem): two digits share the width; one is centred.
const vec2 NUMBER_ACROSS = vec2(0.24, 0.76);   // about 26 cm for two digits
const vec2 NUMBER_UP = vec2(0.34, 0.80);       // about 27 cm tall, as AFL numbers are

varying vec4 looks;

void vertex() {
	looks = COLOR;
}

// 1 where x is past edge, 0 before it, anti-aliased over a pixel.
float over(float x, float edge) {
	float w = max(fwidth(x), 1e-4);
	return clamp((x - edge) / w + 0.5, 0.0, 1.0);
}

// 1 on alternate bands of a coordinate (count bands across 0..1).
float bands(float x, float count) {
	float t = abs(fract(x * count * 0.5) - 0.5) * 2.0;   // triangle wave, 0..1
	float w = max(fwidth(x * count), 1e-4);
	return clamp((t - 0.5) / w + 0.5, 0.0, 1.0);
}

// Pattern weights on the guernsey: x = pattern colour, y = second pattern colour.
// g = (across 0..1 from the wearer's right, up 0..1 from the hem, front 1 / back 0).
vec2 design(int d, vec3 g) {
	if (d == 1) {          // stripes
		return vec2(bands(g.x, 7.0), 0.0);
	} else if (d == 2) {   // hoops
		return vec2(bands(g.y, 9.0), 0.0);
	} else if (d == 3) {   // sash: wearer's left shoulder to right hip
		float off = g.x - (0.14 + 0.72 * g.y);
		return vec2(over(0.11, abs(off)), 0.0);
	} else if (d == 4) {   // yoke: across the shoulders, to a V at the chest
		return vec2(over(g.y, 0.62 + 0.8 * abs(g.x - 0.5)), 0.0);
	} else if (d == 5) {   // band: three hoops round the middle, the centre one in the second colour
		float inside = over(g.y, 0.40) * over(0.64, g.y);
		float centre = over(g.y, 0.48) * over(0.56, g.y);
		return vec2(inside - centre, centre);
	} else if (d == 6) {   // chevrons on the front
		float c = g.y - 0.9 * abs(g.x - 0.5);
		float on = over(c, 0.38) * over(0.86, c) * g.z;
		return vec2(bands(c, 6.0) * on, 0.0);
	} else if (d == 7) {   // panels: wearer's right third, middle third, left third
		float mid = over(g.x, 0.36) * over(0.64, g.x);
		float right = over(0.36, g.x);
		return vec2(mid, right);
	} else if (d == 8) {   // chevron: a deep V from the shoulders, pattern colour outside, second colour inside
		float c = g.y - 2.0 * abs(g.x - 0.5);
		float band = over(c, 0.44) * over(0.76, c);
		float inside = over(c, 0.60);
		return vec2(band * (1.0 - inside), band * inside) * g.z;
	} else if (d == 9) {   // sides: panels down each side, widening to the hem
		return vec2(over(abs(g.x - 0.5), 0.33 - 0.06 * (1.0 - g.y)), 0.0);
	} else if (d == 10) {  // tiers: the top in the pattern colour, a band below it, the base under that
		float top = over(g.y, 0.62);
		float band = over(g.y, 0.52) * over(0.62, g.y);
		return vec2(top, band);
	} else if (d == 11) {  // shoulders: panels over each shoulder, from beside the neck to the armpit
		return vec2(over(g.y, 1.18 - 2.27 * abs(g.x - 0.5)), 0.0);
	} else if (d == 12) {  // map: Tasmania on the chest in the pattern colour, a T on it in the second colour
		float a = (g.x - 0.5) / 0.17;          // -1..1 across the map, west on the wearer's right
		float b = (g.y - 0.47) / 0.35;         // 0 at the southern tip, 1 along the north coast
		float lean = 0.12 * (1.0 - b);         // the south tip sits east of centre
		float half_w = 1.0 - pow(1.0 - clamp(b, 0.0, 1.0), 2.6);   // full and blunt, not a shield
		float land = over(half_w, abs(a - lean)) * over(b, 0.0) * over(1.0 - 0.06 * a, b) * g.z;
		float bar = over(b, 0.62) * over(0.80, b) * over(0.55, abs(a));
		float stem = over(b, 0.22) * over(0.80, b) * over(0.17, abs(a));
		float t = max(bar, stem) * land;
		return vec2(land - t, t);
	} else if (d == 13) {  // suit (the coach): the jacket open at the collar on the shirt (pattern), a tie (second colour)
		float open = over(g.y, 0.58 + 1.9 * abs(g.x - 0.5)) * g.z;
		float tie = open * over(0.028, abs(g.x - 0.5)) * over(0.93, g.y);
		return vec2(open - tie, tie);
	}
	return vec2(0.0);
}

// The number printed on the back: x = 1 where it's drawn (alpha), rgb its colour.
vec4 number_on_back(int n, vec3 g, vec3 base, bool mirrored) {
	float x = (NUMBER_ACROSS.y - g.x) / (NUMBER_ACROSS.y - NUMBER_ACROSS.x);   // from behind, left to right
	if (mirrored) {
		x = 1.0 - x;      // the frame is flipped on screen: flip the digits back
	}
	float y = (NUMBER_UP.y - g.y) / (NUMBER_UP.y - NUMBER_UP.x);             // top down
	int digit = n;
	float dx = (x - 0.25) * 2.0;
	if (n >= 10) {
		digit = x < 0.5 ? n / 10 : n % 10;
		dx = x < 0.5 ? x * 2.0 : x * 2.0 - 1.0;
	}
	if (dx < 0.0 || dx > 1.0 || y < 0.0 || y > 1.0) {
		return vec4(0.0);
	}
	vec4 d = texture(digits_tex, vec2((float(digit) + dx) / 10.0, y));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 ink = lum > 0.58 ? vec3(0.06, 0.06, 0.07) : vec3(1.0);
	// Edged in the guernsey's own colour, so it reads across stripes and panels.
	return vec4(mix(base, ink, d.r), d.g * (1.0 - smoothstep(0.35, 0.6, g.z)));
}

// The design sheet sampled with a cubic B-spline (four bilinear taps) instead of plain
// bilinear: magnified on a phone, bilinear coordinates bend at every texel, which shows
// as stair-steps along the stripe and number edges.
vec3 design_at(vec2 uv) {
	vec2 size = vec2(textureSize(design_tex, 0));
	vec2 t = uv * size - 0.5;
	vec2 f = fract(t);
	vec2 i = t - f;
	vec2 f2 = f * f, f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 s0 = w0 + w1, s1 = w2 + w3;
	vec2 c0 = (i - 0.5 + w1 / s0) / size, c1 = (i + 1.5 + w3 / s1) / size;
	return s0.y * (s0.x * texture(design_tex, vec2(c0.x, c0.y)).rgb + s1.x * texture(design_tex, vec2(c1.x, c0.y)).rgb)
		+ s1.y * (s0.x * texture(design_tex, vec2(c0.x, c1.y)).rgb + s1.x * texture(design_tex, vec2(c1.x, c1.y)).rgb);
}

bool is_hair(ivec2 size) {
	for (int i = 0; i < 8; i++) {
		if (i < hair_count && size == hair_sizes[i]) {
			return true;
		}
	}
	return false;
}

void fragment() {
	ivec2 tex_size = textureSize(TEXTURE, 0);
	if (tex_size != sheet_size && is_hair(tex_size)) {
		vec4 s = texture(TEXTURE, UV);     // lighting, -, -, coverage
		int tone = clamp(int(round(looks.g * 8.0)), 0, 7);
		int hair = clamp(int(round(looks.b * 8.0)), 0, 7);
		vec3 col = looks.r > 0.5 ? skin_tones[tone].rgb : hair_tones[hair].rgb;
		COLOR = vec4(col * s.r * gain, s.a * looks.a);
	} else if (tex_size == sheet_size) {
		vec4 s = texture(TEXTURE, UV);     // lighting, hair, shorts, coverage
		vec4 m = texture(mask_tex, UV);    // base colour, sock band, skin, guernsey alone
		vec3 g = design_at(UV);
		int code = int(round(looks.r * 8.0));
		int kit = clamp(code / 2, 0, 3);
		bool mirrored = (code % 2) == 1;
		if (looks.g > 0.95) {
			int n = clamp(int(round(looks.b * 128.0)) - 1, 0, 99);
			vec4 num = number_on_back(n, g, kit_base[kit].rgb, mirrored);
			COLOR = vec4(num.rgb * s.r * gain, num.a * m.a * s.a * looks.a);
		} else {
			int tone = clamp(int(round(looks.g * 8.0)), 0, 7);
			int hair = clamp(int(round(looks.b * 8.0)), 0, 7);
			vec2 p = design(int(round(kit_design[kit])), g) * m.a;
			vec3 base = kit_base[kit].rgb, pat = kit_pattern[kit].rgb, pat2 = kit_pattern2[kit].rgb;
			vec3 kit_col = base * m.r + (pat - base) * p.x + (pat2 - base) * p.y;
			float rest = clamp(1.0 - (m.r + m.g + m.b + s.g + s.b), 0.0, 1.0);
			vec3 col = kit_col + pat * m.g + skin_tones[tone].rgb * m.b
					+ hair_tones[hair].rgb * s.g + kit_shorts[kit].rgb * s.b + boots.rgb * rest;
			COLOR = vec4(col * s.r * gain, s.a * looks.a);
		}
	}
}
