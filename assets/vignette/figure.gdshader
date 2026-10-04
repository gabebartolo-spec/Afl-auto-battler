shader_type canvas_item;
// The vignettes' footballers: pre-rendered figures (figures_shade.png) recoloured
// per club and per player. Only draws from the figure sheet are recoloured - it
// is recognised by its size - so the ground, text and letterbox the same Control
// draws pass straight through.
//
// A figure's draw colour carries its looks, not a tint:
//   r = kit index / 4, g = skin tone index / 8, b = hair index / 8, a = opacity.
// A kit is a guernsey: base colour (guernsey and socks), pattern colour (its design
// and the sock band), a second pattern colour, the design (GameDB.GUERNSEY_DESIGNS)
// and shorts. See VignetteFigures.gd for the sheet layout.

uniform sampler2D mask_tex : filter_linear;
uniform sampler2D design_tex : filter_linear;
uniform ivec2 sheet_size = ivec2(2048, 2304);
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
	}
	return vec2(0.0);
}

void fragment() {
	if (textureSize(TEXTURE, 0) == sheet_size) {
		vec4 s = texture(TEXTURE, UV);     // lighting, hair, shorts, coverage
		vec4 m = texture(mask_tex, UV);    // base colour, sock band, skin, guernsey alone
		vec3 g = texture(design_tex, UV).rgb;
		int kit = clamp(int(round(looks.r * 4.0)), 0, 3);
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
