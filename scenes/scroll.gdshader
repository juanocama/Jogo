shader_type canvas_item;

uniform float offset_y = 0.0;
uniform float zoom = 1.0;

void fragment() {
	vec2 uv = UV;
	uv = (uv - vec2(0.5)) / zoom + vec2(0.5);
	
	uv.y = uv.y / zoom + offset_y;
	
	COLOR = texture(TEXTURE, uv);
}