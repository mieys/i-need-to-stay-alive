shader_type canvas_item;

// Kullanıcı isteği: "hasar alan yaratıkların anlık beyazlaması ... pixel
// oyunlarda kullanılan hasar alıncaki beyazlama efekti" - flash_amount 1.0
// olduğunda sprite'ı (alfa korunarak) düz beyaza boyar, enemy.gd _flash()
// bunu hızlıca 1.0 -> 0.0'a tweenleyerek anlık bir "pop" oluşturur.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// Madde 711 (2026-11-15, göz yorgunluğu): saf beyaz yerine krem (hud_theme TEXT #f3e6cc); en parlak renk krem kuralı.
// Tepe gücünü enemy.gd HIT_FLASH_PEAK verir (eskiden 1,0 = alan hasarında 60 yaratık birden bembeyaz).
uniform vec3 flash_color : source_color = vec3(0.953, 0.902, 0.8);

// Madde 749 (2026-11-16): renk dokudan YENİDEN okunuyordu -> modulate (vertex rengi) yok sayılıyordu. Malzeme ilk vuruşta takıldığı
// için o andan sonra durum tonları (Buz Asası / Don Nova buz mavisi, öfke kırmızısı - enemy.gd _status_tint_color) ve ölümdeki
// modulate:a solması ekranda hiç görünmüyordu. COLOR (fragment başında = vertex rengi x doku) kullanılır; flaş onun üstüne karışır.
void fragment() {
	vec4 c = COLOR;
	COLOR = vec4(mix(c.rgb, flash_color, flash_amount), c.a);
}
