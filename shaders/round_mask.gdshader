shader_type canvas_item;

// Telefon HUD'u (bkz. scripts/mobile_ui.gd, hud.gd _apply_mobile_skill_look): yetenek ikonu kendi her şeyini (ikon, bekleme
// örtüsü, kilit, aktiflik çerçevesi) kare çiziyor - bu maske o düğümün TÜM çizimlerini yerel bir daireye kırpar, böylece
// yuvarlak çerçevenin içinde yuvarlak görünür. Çocuklar (çerçeve dokusu, bekleme sayısı) etkilenmez.
uniform vec2 merkez = vec2(26.0);
uniform float yaricap = 24.0;

varying vec2 yerel;

void vertex() {
	yerel = VERTEX;
}

void fragment() {
	if (distance(yerel, merkez) > yaricap) {
		discard;
	}
}
