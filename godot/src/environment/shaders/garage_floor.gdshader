shader_type spatial;
// Sealed garage concrete with glossy wet patches. Procedural until a texture set is
// assigned in assets.cfg [floor_textures]; values come from lighting.cfg [floor].

uniform vec3 base_color : source_color = vec3(0.07);
uniform float base_roughness = 0.5;
uniform float wet_roughness = 0.035;
uniform float wet_amount : hint_range(0.0, 1.0) = 0.48;
uniform float wet_scale = 0.12;
uniform float wet_edge = 0.07;
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.55;
uniform float grain_scale = 3.5;
uniform float grain_strength = 0.18;
uniform float specular_amount = 0.5;

uniform bool use_textures = false;
uniform float tiling = 0.25;
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float grain = fbm(p * grain_scale);
	// Streaky patches: stretch the noise a little along X like squeegee marks.
	float wet_noise = fbm(p * vec2(wet_scale * 0.6, wet_scale) + vec2(31.7, 4.1));
	float wet = smoothstep(1.0 - wet_amount - wet_edge, 1.0 - wet_amount + wet_edge, wet_noise);

	vec3 col = base_color * (1.0 - grain_strength + 2.0 * grain_strength * grain);
	float rough = base_roughness * (0.75 + 0.5 * grain);
	if (use_textures) {
		vec2 uv = p * tiling;
		col = texture(albedo_texture, uv).rgb;
		rough = texture(roughness_texture, uv).g;
		NORMAL_MAP = texture(normal_texture, uv).rgb;
		NORMAL_MAP_DEPTH = mix(1.0, 0.2, wet);
	}

	ALBEDO = col * mix(1.0, 1.0 - wet_darkening, wet);
	ROUGHNESS = mix(rough, wet_roughness, wet);
	SPECULAR = specular_amount;
	METALLIC = 0.0;
}
