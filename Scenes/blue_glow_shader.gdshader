shader_type canvas_item;

uniform float pulse_speed = 2.0;
uniform float max_alpha = 0.05; // ultra subtle

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);

    // Wider, softer falloff
    float radial_alpha = smoothstep(0.6, 0.0, dist);

    // Gentle pulse
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float final_alpha = radial_alpha * pulse * max_alpha;

    // This is the only line that was changed!
    COLOR = vec4(0.0, 0.65, 1.0, final_alpha);
}