shader_type canvas_item;

uniform float pulse_speed = 2.0;
uniform float max_alpha = 0.05;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);

    float radial_alpha = smoothstep(0.6, 0.0, dist);

    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float final_alpha = radial_alpha * pulse * max_alpha;

    // This line changes the color to red
    COLOR = vec4(1.0, 0.0, 0.0, final_alpha);
}