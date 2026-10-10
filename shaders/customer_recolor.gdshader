shader_type canvas_item;

// Palette-swap shader for customer_base.png (Seal Diner).
// Every pixel that exactly matches one of the original colours below is
// replaced with the matching uniform. Everything else (outline, eyes,
// cutlery) is left untouched. Modulate / self_modulate still work.

// --- Original colours painted in customer_base.png (do not edit) ---
const vec3 SRC_SKIN         = vec3(227.0, 168.0, 122.0) / 255.0; // #e3a87a
const vec3 SRC_SKIN_SHADOW  = vec3(191.0, 130.0,  87.0) / 255.0; // #bf8257
const vec3 SRC_BLUSH        = vec3(232.0, 132.0, 114.0) / 255.0; // #e88472
const vec3 SRC_HAIR         = vec3(122.0,  74.0,  44.0) / 255.0; // #7a4a2c
const vec3 SRC_HAIR_SHADOW  = vec3( 85.0,  49.0,  28.0) / 255.0; // #55311c
const vec3 SRC_SHIRT        = vec3( 79.0, 163.0, 165.0) / 255.0; // #4fa3a5
const vec3 SRC_SHIRT_SHADOW = vec3( 58.0, 125.0, 128.0) / 255.0; // #3a7d80
const vec3 SRC_PANTS        = vec3( 90.0,  95.0, 122.0) / 255.0; // #5a5f7a
const vec3 SRC_SHOES        = vec3(138.0,  90.0,  58.0) / 255.0; // #8a5a3a

// --- New colours (defaults = original look) ---
uniform vec4 skin         : source_color = vec4(0.890, 0.659, 0.478, 1.0);
uniform vec4 skin_shadow  : source_color = vec4(0.749, 0.510, 0.341, 1.0);
uniform vec4 blush        : source_color = vec4(0.910, 0.518, 0.447, 1.0);
uniform vec4 hair         : source_color = vec4(0.478, 0.290, 0.173, 1.0);
uniform vec4 hair_shadow  : source_color = vec4(0.333, 0.192, 0.110, 1.0);
uniform vec4 shirt        : source_color = vec4(0.310, 0.639, 0.647, 1.0);
uniform vec4 shirt_shadow : source_color = vec4(0.227, 0.490, 0.502, 1.0);
uniform vec4 pants        : source_color = vec4(0.353, 0.373, 0.478, 1.0);
uniform vec4 shoes        : source_color = vec4(0.541, 0.353, 0.227, 1.0);

// How close a pixel must be to count as a match (0-1 per channel distance).
uniform float tolerance = 0.01;

varying vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;
}

bool near(vec3 a, vec3 b) {
	return distance(a, b) < tolerance;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;
	if      (near(c, SRC_SKIN))         c = skin.rgb;
	else if (near(c, SRC_SKIN_SHADOW))  c = skin_shadow.rgb;
	else if (near(c, SRC_BLUSH))        c = blush.rgb;
	else if (near(c, SRC_HAIR))         c = hair.rgb;
	else if (near(c, SRC_HAIR_SHADOW))  c = hair_shadow.rgb;
	else if (near(c, SRC_SHIRT))        c = shirt.rgb;
	else if (near(c, SRC_SHIRT_SHADOW)) c = shirt_shadow.rgb;
	else if (near(c, SRC_PANTS))        c = pants.rgb;
	else if (near(c, SRC_SHOES))        c = shoes.rgb;
	COLOR = vec4(c, tex.a) * vertex_modulate;
}
