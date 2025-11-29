shader_type spatial;

// Microvoxel terrain shader with triplanar mapping
// Based on Zylann's voxelgame reference

// Textures
uniform sampler2D u_texture_top : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D u_texture_sides : source_color, filter_linear_mipmap, repeat_enable;
uniform float u_texture_scale : hint_range(0.01, 1.0) = 0.1;

// Triplanar settings
uniform float u_triplanar_sharpness : hint_range(1.0, 16.0) = 4.0;

// Top detection
uniform float u_top_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float u_top_smoothness : hint_range(0.01, 0.5) = 0.1;

// Color tinting
uniform vec3 u_color_tint : source_color = vec3(1.0, 1.0, 1.0);

// Varying
varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	// World position for triplanar mapping
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// World normal
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

vec3 get_triplanar_blend(vec3 normal, float sharpness) {
	vec3 blend = abs(normal);
	blend = pow(blend, vec3(sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.00001);
	return blend;
}

vec4 texture_triplanar(sampler2D tex, vec3 world_pos, vec3 blend) {
	vec4 x_proj = texture(tex, world_pos.zy);
	vec4 y_proj = texture(tex, world_pos.xz);
	vec4 z_proj = texture(tex, world_pos.xy);
	return x_proj * blend.x + y_proj * blend.y + z_proj * blend.z;
}

void fragment() {
	vec3 normal = normalize(v_world_normal);
	vec3 wpos = v_world_pos * u_texture_scale;
	
	// Triplanar blend weights
	vec3 blend = get_triplanar_blend(normal, u_triplanar_sharpness);
	
	// Top detection based on normal Y component
	float top_min = u_top_threshold - u_top_smoothness;
	float top_max = u_top_threshold + u_top_smoothness;
	float topness = smoothstep(top_min, top_max, normal.y);
	
	// Sample textures with triplanar mapping
	vec3 top_col = texture_triplanar(u_texture_top, wpos, blend).rgb;
	vec3 side_col = texture_triplanar(u_texture_sides, wpos, blend).rgb;
	
	// Mix based on topness
	vec3 final_color = mix(side_col, top_col, topness);
	
	// Apply tint
	ALBEDO = final_color * u_color_tint;
	
	// Roughness for non-metallic terrain
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

