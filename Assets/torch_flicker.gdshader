shader_type canvas_item;

uniform float flicker_speed = 2.5;
uniform float flicker_intensity = 0.2;

void fragment() {
	float time = TIME * flicker_speed;
	float flicker = sin(time + UV.x * 10.0) * flicker_intensity;
	COLOR.a *= 1.0 + flicker;
