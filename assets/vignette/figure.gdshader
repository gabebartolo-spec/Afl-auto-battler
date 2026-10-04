shader_type canvas_item;
// The vignettes' footballers: pre-rendered figures (figures_shade.png) recoloured
// per club and per player. Only draws from the figure sheet are recoloured - it
// is recognised by its size - so the ground, text and letterbox the same Control
// draws pass straight through.
//
// A figure's draw colour carries its looks, not a tint:
//   r = kit index / 4, g = skin tone index / 8, b = hair index / 8, a = opacity.
// See VignetteFigures.gd for the sheet layout.

uniform sampler2D mask_tex : filter_linear;
uniform ivec2 sheet_size = ivec2(2048, 2304);
uniform vec4 kit_primary[4];
uniform vec4 kit_secondary[4];
uniform vec4 kit_shorts[4];
uniform vec4 skin_tones[8];
uniform vec4 hair_tones[8];
uniform vec4 boots = vec4(0.06, 0.06, 0.07, 1.0);
// The sheet's lighting is rendered a shade dark so highlights don't clip.
uniform float gain = 1.3;

varying vec4 looks;

void vertex() {
	looks = COLOR;
}

void fragment() {
	if (textureSize(TEXTURE, 0) == sheet_size) {
		vec4 s = texture(TEXTURE, UV);   // lighting, hair, shorts, coverage
		vec4 m = texture(mask_tex, UV);  // primary, secondary, skin
		int kit = clamp(int(round(looks.r * 4.0)), 0, 3);
		int tone = clamp(int(round(looks.g * 8.0)), 0, 7);
		int hair = clamp(int(round(looks.b * 8.0)), 0, 7);
		float rest = clamp(1.0 - (m.r + m.g + m.b + s.g + s.b), 0.0, 1.0);
		vec3 base = kit_primary[kit].rgb * m.r + kit_secondary[kit].rgb * m.g
				+ skin_tones[tone].rgb * m.b + hair_tones[hair].rgb * s.g
				+ kit_shorts[kit].rgb * s.b + boots.rgb * rest;
		COLOR = vec4(base * s.r * gain, s.a * looks.a);
	}
}
