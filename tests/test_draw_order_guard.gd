extends Node

## Çizim sırası koruması (2026-10-09, kullanıcı: "solucanlar bazen glitchlenip diğerinin üstünde görünüyor"): Godot, Main'in bir çocuğu ağaçtan çıkınca ondan sonraki kardeşlerin çizim
## indeksini ağaç sırasına geri sarar; C++ draw_order bunu 1-2 kare sonra düzeltiyordu (o karede ters sıra). main.gd artık çocuk çıkınca/sırası değişince bayrak kaldırıp sırayı
## RenderingServer.frame_pre_draw'da (çizimden hemen önce) yeniden uygular. Gerçek ters-sıra karesi pencereli ekran görüntüsüyle önce/sonra doğrulandı (başsız çizim yok);
## burada kablolama + bayrak kuralı sınanır.

const MainScript: GDScript = preload("res://scripts/main.gd")


func test_guard_is_wired_marks_dirty_and_clears_on_the_pre_draw_hook() -> void:
	var m: Node2D = MainScript.new() as Node2D
	m._install_draw_order_guard()
	assert(m.child_exiting_tree.is_connected(m._mark_draw_order_dirty), "çocuk ağaçtan çıkınca bayrak kalkar")
	assert(RenderingServer.frame_pre_draw.is_connected(m._on_frame_pre_draw), "çizimden hemen önce kancası bağlı")
	if m.has_signal(&"child_order_changed"):
		assert(m.is_connected(&"child_order_changed", m._mark_draw_order_dirty), "sıra değişince (move_child) de bayrak kalkar")
	assert(m._draw_order_dirty == false)
	m._mark_draw_order_dirty()
	assert(m._draw_order_dirty == true, "bayrak kalkar")
	m._on_frame_pre_draw() ## ağaçta değil: sıra uygulanmaz ama bayrak temizlenir (sonraki karede boşuna tekrar etmez)
	assert(m._draw_order_dirty == false, "kanca bayrağı temizler")
	m._on_frame_pre_draw() ## bayrak yokken hiçbir şey yapmaz (hata vermez)
	## kurulum iki kez çağrılsa da bağlantı tekrarlanmaz
	m._install_draw_order_guard()
	m._install_draw_order_guard()
	assert(m.child_exiting_tree.get_connections().filter(func(c: Dictionary) -> bool: return c["callable"] == m._mark_draw_order_dirty).size() == 1, "tek bağlantı")
	m.free()
