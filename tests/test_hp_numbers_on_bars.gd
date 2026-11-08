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


## Madde 479: masaüstünde müttefik çubukları oyuncu panelinin çubuğu (hud_pixel_bar.gd) - sayı çubuğun kendi yazısı (ortada "mevcut/azami"),
## etiket düğümü yok, yenilenme yazısı hiç yok. Sayılar PartyScript.row_value_text ile okunur (telefonda eski etiket).
func _hp(row) -> String:
	return PartyScript.row_value_text(row, false)


func _sh(row) -> String:
	return PartyScript.row_value_text(row, true)


func test_party_panel_rows_show_hp_and_shield_numbers_inside_the_bars() -> void:
	_cleanup()
	var a := FakeAlly.new()
	var pp: Control = _panel_with([a])
	var row = pp._rows[a.peer_id]
	var PixelBar: GDScript = load("res://scripts/hud_pixel_bar.gd")
	assert(row.health_bar.get_script() == PixelBar and row.shield_bar.get_script() == PixelBar, "masaüstü: oyuncu paneliyle aynı çubuk")
	assert(row.health_label == null and row.shield_label == null, "sayı çubuğun içinde çizilir, ayrı etiket yok")
	assert(bool(row.health_bar.get("merged")) and str(row.health_bar.get("icon_kind")) == "", "ikonsuz birleşik kip")
	assert(str(row.health_bar.get("regen_text")) == "" and str(row.shield_bar.get("regen_text")) == "", "müttefikte yenilenme yazısı yok")
	assert(_hp(row) == "640/800", "can sayısı HUD biçimiyle: %s" % _hp(row))
	assert(_sh(row) == "150/400", "kalkan sayısı: %s" % _sh(row))
	assert(row.health_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fareyi geçirir (satır ipucu)")
	assert(row.health_bar.custom_minimum_size.y >= 22.0 and row.shield_bar.custom_minimum_size.y >= 18.0, "çubuk boyları eskisi gibi")
	## Güncelleme: can düşünce sayı da düşer; kalkan kalmayınca yazı boşalır (çubuk görünür kalır).
	a.health = 12.4
	a.item_shield_hp = 0.0
	a.item_shield_max = 0.0
	pp._update_rows()
	assert(_hp(row) == "12/800", "can güncellendi: %s" % _hp(row))
	assert(_sh(row) == "" and row.shield_bar.visible, "kalkansız: yazı yok, çubuk yerinde (satır zıplamaz)")
	a.health = -5.0 ## ölü: negatif sayı yazılmaz
	pp._update_rows()
	assert(_hp(row) == "0/800", "ölüde 0: %s" % _hp(row))
	a.item_shield_max = 2000.0
	a.item_shield_hp = 1999.6
	pp._update_rows()
	assert(_sh(row) == "2000/2000", "yuvarlama: %s" % _sh(row))
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
	assert(_hp(pp._rows[2]) == "640/800" and _hp(pp._rows[3]) == "50/100", "iki satır ayrı sayı gösterir")
	assert(_sh(pp._rows[2]) == "150/400" and _sh(pp._rows[3]) == "5/10", "kalkanlar da ayrı")
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
