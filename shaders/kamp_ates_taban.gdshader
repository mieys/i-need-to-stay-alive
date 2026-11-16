shader_type canvas_item;

// ANA MENÜ kamp ateşinin TABANI (taş halka + kor; Night Camp paketi, gece_kamp_atesi.png) (2026-11-16, kullanıcı: "kamp ateşinin neden
// gölgesi yok, ışığa duyarlı"). Paketin çizimi taşların ateşe bakan yüzlerini ZATEN ateş ışığıyla boyamış; taban ışık katmanının
// (kamp_gunbatimi.gdshader) altında kalınca ateş havuzunun tam ortasında ikinci kez aydınlanıp pembe-somon düz bir lekeye dönüyordu
// (taşların koyu yüzleri / dış hattı kayboluyordu). Taban artık ışık katmanının ÜSTÜNDE bu shader'la çizilir: kor/alev pikselleri
// (doygun turuncu) aynen, taşlar + kömürleşmiş odun hafif sıcak gece tonuyla ve ışık katmanıyla AYNI titremeyle (TIME) çarpılır.

uniform vec3 stone_tint : source_color = vec3(0.95, 0.80, 0.72);
uniform float flick_amount = 0.6; // taşların ateş titremesine katılımı (1 = ışık katmanıyla aynı genlik)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// kamp_gunbatimi.gdshader'daki titreme (ortalama ~0,93)
	float flick = 0.93 + 0.045 * sin(TIME * 7.3) + 0.03 * sin(TIME * 12.7 + 1.3) + 0.02 * sin(TIME * 3.1 + 0.4);
	float f = mix(1.0, flick / 0.93, flick_amount);
	// kor / alev: kırmızı yüksek, mavi düşük (taşların ateşe bakan sıcak yüzleri mavisi ~0,38 -> taş sayılır)
	float e = smoothstep(0.34, 0.28, c.b) * smoothstep(0.66, 0.74, c.r);
	vec3 stone = c.rgb * stone_tint * f;
	COLOR = vec4(mix(stone, c.rgb, e), c.a);
}
