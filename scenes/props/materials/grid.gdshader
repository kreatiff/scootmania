shader_type spatial;
// World-space grid, projected onto whichever plane a surface faces
// (triplanar), so ramps and walls get the same 1 m / 5 m grid as the ground.
// Makes speed, height and angle readable without any real textures.

uniform vec3 base_color : source_color = vec3(0.45);
uniform vec3 minor_line_color : source_color = vec3(0.34);
uniform vec3 major_line_color : source_color = vec3(0.2);
uniform float minor_spacing = 1.0;
uniform float major_spacing = 5.0;
uniform float line_width_px = 1.2;
uniform float surface_roughness = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1 on a grid line, 0 elsewhere. Anti-aliased with screen-space
// derivatives, and faded out where lines get denser than a few pixels.
float grid(vec2 p, float spacing) {
	vec2 cell = p / spacing;
	vec2 width = fwidth(cell);
	vec2 dist = abs(fract(cell - 0.5) - 0.5) / max(width, vec2(1e-5));
	float line = 1.0 - clamp(min(dist.x, dist.y) / line_width_px, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.15, 0.5, max(width.x, width.y));
	return line * fade;
}

float triplanar_grid(vec3 p, vec3 weights, float spacing) {
	return grid(p.zy, spacing) * weights.x
		+ grid(p.xz, spacing) * weights.y
		+ grid(p.xy, spacing) * weights.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 color = mix(base_color, minor_line_color, triplanar_grid(world_pos, w, minor_spacing));
	color = mix(color, major_line_color, triplanar_grid(world_pos, w, major_spacing));
	ALBEDO = color;
	ROUGHNESS = surface_roughness;
}
