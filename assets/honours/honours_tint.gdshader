shader_type canvas_item;
// The Trophy room's honours in a club's colours (assets/honours/honours.json: an honour with a
// "mask"). The art renders its club-coloured parts - the pennant's cloth, the shield's enamel -
// in a neutral grey, lit like the rest; mask_tex says where: R = the club's primary colour,
// G = its secondary. The grey's lighting carries onto the colour, and what is brighter than
// `lit` (a sheen on the enamel) stays white, so black and navy clubs still show their shape.
// Pass GameDB.club_colours() as they are; draw with TEXTURE_FILTER_LINEAR_WITH_MIPMAPS.
// Made with ard-asset-pipeline tools/blender/honours.py (tools/honours_sheet.py previews it).

uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform vec4 primary : source_color = vec4(0.04, 0.12, 0.30, 1.0);
uniform vec4 secondary : source_color = vec4(1.0);
// The grey where it faces the light squarely: full colour there, sheen above it.
uniform float lit = 0.8;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 m = texture(mask_tex, UV).rg;
	float l = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	float shade = min(l / lit, 1.0);
	float sheen = max(l - lit, 0.0) / (1.0 - lit);
	vec3 rgb = mix(art.rgb, primary.rgb * shade + sheen, m.r);
	rgb = mix(rgb, secondary.rgb * shade + sheen, m.g);
	COLOR = vec4(min(rgb, vec3(1.0)), art.a) * modulate;
}
