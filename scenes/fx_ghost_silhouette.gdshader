shader_type canvas_item;

// Karakter karesinin DÜZ RENKLİ silüeti (madde 734, ruhani Taktiksel "Ruh Işığı" hayaletleri): renk + alfa = düğümün
// modulate/self_modulate'i, şekil = dokunun alfası. Köşe rengi vertex()'te ayrı taşınır - fragment()'teki COLOR zaten
// doku x köşe rengi olduğundan onu çarpınca renk dokuya karışırdı (hafıza: prototype-scale-vs-game).
varying vec4 v_col;

void vertex() {
	v_col = COLOR;
}

void fragment() {
	COLOR = vec4(v_col.rgb, v_col.a * texture(TEXTURE, UV).a);
}
