shader_type spatial;
// Horizontal ribs for the roller door, done in the normal so it stays a single quad.

uniform vec3 color : source_color = vec3(0.2, 0.21, 0.22);
uniform float ribs_per_meter = 7.0;
uniform float rib_depth = 0.35;
uniform float roughness = 0.42;
uniform float metallic = 0.65;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = sin(world_pos.y * ribs_per_meter * TAU);
	NORMAL_MAP = normalize(vec3(0.5, 0.5 + rib_depth * s, 1.0));
	ALBEDO = color * (0.92 + 0.08 * s);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
