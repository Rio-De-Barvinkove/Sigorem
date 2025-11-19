shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Texture array for different terrain types
uniform sampler2DArray terrain_textures : hint_albedo;

// Terrain parameters
uniform float uv_scale = 0.08;
uniform float normal_blend_threshold = 0.7;
uniform float height_blend_start = 40.0;
uniform float height_blend_end = 60.0;

// Procedural moss parameters
uniform float moss_strength = 0.3;
uniform float moss_height_start = 15.0;
uniform float moss_height_end = 35.0;
uniform vec3 moss_direction = vec3(0.0, 0.0, -1.0); // Northern exposure

// Material properties
uniform float roughness_base = 0.8;
uniform float metallic_base = 0.0;

vec3 triplanar_sample(sampler2DArray tex, vec3 world_pos, vec3 normal, float layer) {
	vec3 blend = abs(normal);
	blend = normalize(max(blend, 0.00001));
	float b = (blend.x + blend.y + blend.z);
	blend /= b;

	vec3 x_axis = texture(tex, vec3(world_pos.zy * uv_scale, layer)).rgb;
	vec3 y_axis = texture(tex, vec3(world_pos.xz * uv_scale, layer)).rgb;
	vec3 z_axis = texture(tex, vec3(world_pos.xy * uv_scale, layer)).rgb;

	return x_axis * blend.x + y_axis * blend.y + z_axis * blend.z;
}

float get_normal_blend_factor(vec3 normal) {
	// Blend based on surface steepness
	float up_dot = dot(normal, vec3(0.0, 1.0, 0.0));
	return smoothstep(normal_blend_threshold, 1.0, up_dot);
}

float get_height_blend_factor(float height) {
	return smoothstep(height_blend_start, height_blend_end, height);
}

float get_moss_factor(vec3 world_pos, vec3 normal, float height) {
	// Moss appears on relatively flat surfaces, within height range, and facing certain direction
	float flatness = get_normal_blend_factor(normal);
	float height_factor = 1.0 - smoothstep(moss_height_start, moss_height_end, height);

	// Direction factor (northern exposure)
	float dir_dot = dot(normal, normalize(moss_direction));
	float dir_factor = smoothstep(0.3, 0.8, dir_dot);

	return flatness * height_factor * dir_factor * moss_strength;
}

void fragment() {
	vec3 world_pos = (CAMERA_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Base surface type determination
	float height = world_pos.y;
	float steepness = 1.0 - get_normal_blend_factor(NORMAL);

	// Texture selection based on surface properties
	float grass_weight = get_normal_blend_factor(NORMAL);
	float rock_weight = steepness;
	float snow_weight = get_height_blend_factor(height);

	// Normalize weights
	float total_weight = grass_weight + rock_weight + snow_weight;
	if (total_weight > 0.0) {
		grass_weight /= total_weight;
		rock_weight /= total_weight;
		snow_weight /= total_weight;
	}

	// Sample textures
	vec3 grass_color = triplanar_sample(terrain_textures, world_pos, NORMAL, 0.0);
	vec3 dirt_color = triplanar_sample(terrain_textures, world_pos, NORMAL, 1.0);
	vec3 rock_color = triplanar_sample(terrain_textures, world_pos, NORMAL, 2.0);
	vec3 moss_color = triplanar_sample(terrain_textures, world_pos, NORMAL, 3.0);
	vec3 snow_color = triplanar_sample(terrain_textures, world_pos, NORMAL, 4.0);

	// Blend colors
	vec3 final_color = grass_color * grass_weight +
					  dirt_color * (1.0 - grass_weight - rock_weight - snow_weight) +
					  rock_color * rock_weight +
					  snow_color * snow_weight;

	// Add procedural moss
	float moss_factor = get_moss_factor(world_pos, NORMAL, height);
	final_color = mix(final_color, moss_color, moss_factor);

	// Simple ambient occlusion based on normal
	float ao = mix(0.7, 1.0, get_normal_blend_factor(NORMAL));
	final_color *= ao;

	// Material properties based on surface type
	float roughness = roughness_base;
	float metallic = metallic_base;

	// Rock is rougher, snow is smoother
	roughness = mix(roughness, 0.9, rock_weight);
	roughness = mix(roughness, 0.3, snow_weight);
	metallic = mix(metallic, 0.1, rock_weight);

	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
