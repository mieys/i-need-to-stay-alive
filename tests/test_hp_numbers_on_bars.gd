extends Node

## Kullanıcı isteği (2026-10-09): "bossların can ve kalkan sayısı görünmüyor, dostların can ve kalkan sayısı grup sekmesindeki barlarında görünmüyor".
## Boss barı (boss_bar_top.gd + boss_bar_art.gd): çubukların içinde "şimdiki / en çok" (binlik noktalı). Grup paneli (party_panel.gd): her müttefikin can ve kalkan
## çubuğunun içinde HUD'daki kendi sayısıyla aynı "%d/%d" biçimi.

const BarScript: GDScript = preload("res://scripts/boss_bar_top.gd")
const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const PartyScript: GDScript = preload("res://scripts/party_panel.gd")

var _made: Array[Node] = []


class FakeBoss extends Node2D:
	var is_dead: bool = false
	var health: float = 100.0
	var max_health: float = 100.0
	var item_shield_hp: float = 50.0
	var item_shield_max: float = 100.0


class FakeAlly extends Node2D:
	var peer_id: int = 2
	var player_name: String = "Dost"
	var char_id: int = 5
	var health: float = 640.0
	var max_health: float = 800.0
	var item_shield_hp: float = 150.0
	var item_shield_max: float = 400.0
	var is_dead: bool = false
	var is_downed: bool = false


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func test_number_formatting_uses_dots_and_clamps() -> void:
	assert(ArtScript.fmt_int(0.0) == "0" and ArtScript.fmt_int(7.0) == "7" and ArtScript.fmt_int(999.0) == "999", "küçük sayılar nokta almaz")
	assert(ArtScript.fmt_int(1000.0) == "1.000" and ArtScript.fmt_int(50000.0) == "50.000" and ArtScript.fmt_int(164549.0) == "164.549", "binlik nokta")
	assert(ArtScript.fmt_int(1234567.4) == "1.234.567", "milyon")
	assert(ArtScript.fmt_int(-50.0) == "0" and ArtScript.fmt_int(0.4) == "0" and ArtScript.fmt_int(0.6) == "1", "negatif 0, yuvarlama")
	assert(ArtScript.bar_text(49900.0, 50000.0) == "49.900 / 50.000", "şimdiki / en çok: %s" % ArtScript.bar_text(49900.0, 50000.0))
	assert(ArtScript.bar_text(0.0, 0.0) == "" and ArtScript.bar_text(10.0, -5.0) == "", "en çok yoksa (kalkansız boss) yazı yok")


func test_top_boss_bar_carries_the_numbers_and_redraws_when_only_the_number_changes() -> void:
	_cleanup()
	var bar := Control.new()
	bar.set_script(BarScript)
	add_child(bar)
	_made.append(bar)
	var b := FakeBoss.new()
	b.health = 75000.0
	b.max_health = 75000.0
	b.item_shield_hp = 90000.0
	b.item_shield_max = 90000.0
	b.set_meta("creature_id", "underground1")
	b.add_to_group("boss")
	add_child(b)
	_made.append(b)
	bar.refresh()
	assert(str(bar._entry.get("hp_text", "")) == "75.000 / 75.000" and str(bar._entry.get("sh_text", "")) == "90.000 / 90.000", "boss barı sayıları taşır: %s" % str(bar._entry))
	var sig_before: String = bar._signature
	b.health = 74999.0 ## oran 0,001'den az değişti ama sayı değişti
	bar.refresh()
	assert(bar._signature != sig_before and str(bar._entry["hp_text"]) == "74.999 / 75.000", "sayı değişince bar yeniden çizilir (imza sayıyı içerir)")
	b.max_health = 100.0
	b.health = 40.0
	b.item_shield_max = 0.0 ## kalkansız boss
	b.item_shield_hp = 0.0
	bar.refresh()
	assert(str(bar._entry["sh_text"]) == "" and str(bar._entry["hp_text"]) == "40 / 100", "kalkansız bossta kalkan yazısı yok: %s" % str(bar._entry))
	assert(is_equal_approx(bar.size.y, float(ArtScript.TOP_H) * float(bar.get("scale_px"))), "bar plaket yüksekliğinde")
	b.free()
	_made.erase(b)
	_cleanup()


func test_plaque_draws_with_and_without_numbers_without_errors() -> void:
	_cleanup()
	var c := Control.new()
	c.size = Vector2(800, 200)
	add_child(c)
	_made.append(c)
	## _draw dışında çizim çağrıları geçerli değil: çizimi bir Control alt sınıfı gibi tetiklemek için draw sinyaline bağla.
	var calls: Array = [0]
	c.draw.connect(func() -> void:
		ArtScript.top_plaque(c, Vector2.ZERO, 3.0, "YERALTI CANAVARI", 0.8, 0.5, ArtScript.TOP_W, "60.000 / 75.000", "45.000 / 90.000")
		ArtScript.top_plaque(c, Vector2(0, 150), 2.0, "MİNOTAUR", 1.0, 0.0)
		calls[0] += 1)
	c.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(int(calls[0]) >= 1, "plaket sayılı ve sayısız çizildi")
	## Çubuk içi sayı plaketin içine sığar: en uzun makul yazı (13 hane) çubuk genişliğinden küçük.
	var bw: float = float(ArtScript.TOP_W - 30 - 6)
	assert(ArtScript.text_width("1.234.567 / 1.234.567", 3.0) < bw, "en uzun makul boss yazısı çubuğa sığar: %.0f < %.0f" % [ArtScript.text_width("1.234.567 / 1.234.567", 3.0), bw])
	_cleanup()


func _panel_with(allies: Array) -> Control:
	var pp: Control = PartyScript.new()
	add_child(pp)
	_made.append(pp)
	for a in allies:
		a.add_to_group("remote_players")
		add_child(a)
		_made.append(a)
	pp._rebuild_rows()
	pp._update_rows()
	return pp


func test_party_panel_rows_show_hp_and_shield_numbers_inside_the_bars() -> void:
	_cleanup()
	var a := FakeAlly.new()
	var pp: Control = _panel_with([a])
	var row = pp._rows[a.peer_id]
	assert(row.health_label != null and row.shield_label != null, "satırda iki sayı etiketi var")
	assert(row.health_label.get_parent() == row.health_bar and row.shield_label.get_parent() == row.shield_bar, "sayılar çubukların İÇİNDE")
	assert(row.health_label.text == "640/800", "can sayısı HUD biçimiyle: %s" % row.health_label.text)
	assert(row.shield_label.text == "150/400", "kalkan sayısı: %s" % row.shield_label.text)
	assert(row.health_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fareyi geçirir")
	assert(row.health_bar.custom_minimum_size.y >= 22.0 and row.shield_bar.custom_minimum_size.y >= 18.0, "çubuklar 2x yazıyı alacak kadar yüksek")
	## Güncelleme: can düşünce sayı da düşer; kalkan kalmayınca yazı boşalır (çubuk görünür kalır).
	a.health = 12.4
	a.item_shield_hp = 0.0
	a.item_shield_max = 0.0
	pp._update_rows()
	assert(row.health_label.text == "12/800", "can güncellendi: %s" % row.health_label.text)
	assert(row.shield_label.text == "" and row.shield_bar.visible, "kalkansız: yazı yok, çubuk yerinde (satır zıplamaz)")
	a.health = -5.0 ## ölü: negatif sayı yazılmaz
	pp._update_rows()
	assert(row.health_label.text == "0/800", "ölüde 0: %s" % row.health_label.text)
	a.item_shield_max = 2000.0
	a.item_shield_hp = 1999.6
	pp._update_rows()
	assert(row.shield_label.text == "2000/2000", "yuvarlama: %s" % row.shield_label.text)
	_cleanup()


func test_two_allies_have_independent_numbers() -> void:
	_cleanup()
	var a := FakeAlly.new()
	var b := FakeAlly.new()
	b.peer_id = 3
	b.player_name = "Diğer"
	b.health = 50.0
	b.max_health = 100.0
	b.item_shield_hp = 5.0
	b.item_shield_max = 10.0
	var pp: Control = _panel_with([a, b])
	assert(pp._rows[2].health_label.text == "640/800" and pp._rows[3].health_label.text == "50/100", "iki satır ayrı sayı gösterir")
	assert(pp._rows[2].shield_label.text == "150/400" and pp._rows[3].shield_label.text == "5/10", "kalkanlar da ayrı")
	_cleanup()


func test_bar_value_label_picks_the_biggest_size_that_fits_and_centers_the_baseline() -> void:
	var LabelScript: GDScript = preload("res://scripts/bar_value_label.gd")
	## Panelin GERÇEK çubuğu: 130 px genişlik (gerçek renderer'da ölçüldü), 22/18 px yükseklik; çizimde iki yandan PAD_X çıkarılır.
	var avail: float = 130.0 - LabelScript.PAD_X * 2.0
	assert(LabelScript.pick_size("640/800", avail, 22.0) == 32, "tipik sayı 2x (32) yazılır")
	assert(LabelScript.pick_size("2000/2000", avail, 22.0) == 32, "9 karakter hâlâ 2x sığar: %d" % LabelScript.pick_size("2000/2000", avail, 22.0))
	assert(LabelScript.pick_size("9999/10000", avail, 22.0) == 24, "10 karakter kenara dayanmasın: 1,5x: %d" % LabelScript.pick_size("9999/10000", avail, 22.0))
	assert(LabelScript.pick_size("12345/23456", avail, 22.0) == 24, "11 karakter 1,5x sığar: %d" % LabelScript.pick_size("12345/23456", avail, 22.0))
	assert(LabelScript.pick_size("1234567/1234567", avail, 22.0) == 16, "çok uzun: en küçük (1x)")
	assert(LabelScript.pick_size("100/100", avail, 18.0) == 32, "kalkan çubuğunda (18 px) da 2x: rakam 14 + pay 4 = 18")
	assert(LabelScript.pick_size("100/100", avail, 14.0) < 32, "çubuk 14 px ise 2x sığmaz")
	## Taban çizgisi hesabı: rakamın üstü ile altı çubuğun ortasına simetrik oturur.
	var cap: float = roundf(32.0 * LabelScript.CAP_RATIO)
	assert(cap == 14.0, "32 punto = 14 px rakam")
	var baseline: float = roundf((22.0 + cap) * 0.5)
	assert(baseline - cap == 4.0 and 22.0 - baseline == 4.0, "22 px çubukta rakamın üstünde ve altında 4'er px boşluk: üst %.0f alt %.0f" % [baseline - cap, 22.0 - baseline])
	var baseline_sh: float = roundf((18.0 + cap) * 0.5)
	assert(baseline_sh - cap == 2.0 and 18.0 - baseline_sh == 2.0, "18 px çubukta 2'şer px")
