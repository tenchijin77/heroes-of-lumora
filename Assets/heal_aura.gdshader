shader_type canvas_item;

uniform float pulse_speed = 2.0;
uniform float base_alpha = 0.3;
uniform float pulse_strength = 0.3;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.05;

void fragment() {
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    vec4 tex_color = texture(TEXTURE, UV);
    tex_color.a *= base_alpha + pulse * pulse_strength;

    // Discard pixels below alpha threshold
    if (tex_color.a < alpha_cutoff) {
        discard;
    }

    COLOR = tex_color;
}
