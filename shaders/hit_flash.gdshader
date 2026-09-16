shader_type canvas_item;

// Kullanıcı isteği: "hasar alan yaratıkların anlık beyazlaması ... pixel
// oyunlarda kullanılan hasar alıncaki beyazlama efekti" - flash_amount 1.0
// olduğunda sprite'ı (alfa korunarak) düz beyaza boyar, enemy.gd _flash()
// bunu hızlıca 1.0 -> 0.0'a tweenleyerek anlık bir "pop" oluşturur.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex_color.rgb, vec3(1.0), flash_amount), tex_color.a);
}
