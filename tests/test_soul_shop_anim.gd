extends Node

## madde 323: Ruh Mağazası animasyonları (soul_shop_screen.gd _play_anims; tasarım C, madde 383). Sayfa girişi / seçim / satın alma animasyonu
## oynar ve bitince her şey TAM eski hâlinde (alfa 1, ölçek 1, parlama sönmüş, figür ofseti son değerinde); ayar kapalıyken anında.
## Kıymıklar GEÇİCİ dosyada (path_override) - gerçek user://meta.cfg'ye dokunmaz. Başlangıç evcili (köpek) mağaza listesinde yok.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const SETTLE := 1.6 ## en uzun animasyon ~0,6 sn; ekransız koşuda ilk kareler yavaş (ana menü sahnesi arka planı da kuruluyor)

var _tmp: String = ""
var _prev_enabled: bool = true


func _begin() -> void:
	_tmp = "user://test_soul_anim_%d.cfg" % Time.get_ticks_usec()
	MetaProgressScript.set_path_override(_tmp)
	MetaProgressScript.set_unlock_all(false)
	_prev_enabled = UISound.ui_anim_enabled
	UISound.ui_anim_enabled = true


func _end(shop: Node) -> void:
	if is_instance_valid(shop):
		shop.queue_free()
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	MetaProgressScript.set_path_override("")
	_tmp = ""
	UISound.ui_anim_enabled = _prev_enabled


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Animasyon bitince hiçbir öğe saydam / ölçekli / parlak kalmamalı (ana menü sahnesi arka planı hariç: ekrana göre ölçeklenir, tonludur).
func _assert_settled(shop: Node, what: String) -> void:
	for c: Node in shop.find_children("*", "Control", true, false):
		if _in_background(c, shop):
			continue
		var ctl := c as Control
		assert(is_equal_approx(ctl.modulate.a, 1.0), "%s: saydam kaldı %s (%s)" % [what, ctl, ctl.modulate])
		assert(ctl.modulate.r <= 1.001 and ctl.modulate.g <= 1.001, "%s: parlama sönmedi %s" % [what, ctl.modulate])
		assert(ctl.scale.is_equal_approx(Vector2.ONE), "%s: ölçek kaldı %s (%s)" % [what, ctl, ctl.scale])


func _in_background(n: Node, shop: Node) -> bool:
	var p: Node = n
	while p != null and p != shop:
		if p.name == "BackgroundImage":
			return true
		p = p.get_parent()
	return false


## Liste satırı = şeffaf katman ("row:<id>") -> satır kutusu.
func _row(shop: Node, id: String) -> PanelContainer:
	for b: Node in shop.find_children("*", "Button", true, false):
		if b.has_meta("sid") and str(b.get_meta("sid")) == "row:" + id:
			return b.get_parent() as PanelContainer
	return null


## Seçili satırın zemini vurgulu.
func _row_on(shop: Node, id: String) -> bool:
	var r := _row(shop, id)
	return r != null and (r.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.05


## Sahne figürü: alttan + ortadan çapalı TextureRect.
func _figure(shop: Node) -> TextureRect:
	for t: Node in shop.find_children("*", "TextureRect", true, false):
		var tr := t as TextureRect
		if is_equal_approx(tr.anchor_left, 0.5) and is_equal_approx(tr.anchor_top, 1.0):
			return tr
	return null


func _find(shop: Node, id: String) -> Dictionary:
	for it: Dictionary in shop.call("_items"):
		if shop.call("_id", it) == id:
			return it
	return {}


func test_page_in_selection_purchase_restore() -> void:
	_begin()
	MetaProgressScript.grant_victory() ## 150
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	var page_box: VBoxContainer = shop.get("_page_box")
	assert(page_box.get_child(0).modulate.a < 0.5, "açılışta üst şerit saydamdan başlamalı")
	await _wait(SETTLE)
	_assert_settled(shop, "açılış")

	## Sayfa değişimi: satırlar sırayla belirir.
	shop.call("_on_tab_pressed", "pet")
	var a: String = "pet:papagan"
	var b: String = "pet:kelebek"
	assert(_row(shop, a) != null and _row(shop, b) != null, "evcil satırları kuruldu")
	assert(_row(shop, b).modulate.a < 0.5, "sayfa girişinde satırlar saydamdan başlamalı")
	await _wait(SETTLE)
	_assert_settled(shop, "evcil sayfası")
	if not _row_on(shop, a): ## ilk seçili papağan değilse önce onu seç
		shop.call("_select", _find(shop, a))
		await _wait(SETTLE)

	## Seçim: figür yandan kayar, ayrıntı belirir, vurgu yeni satıra geçer.
	shop.call("_select", _find(shop, b))
	var fig := _figure(shop)
	assert(fig != null, "sahne figürü var")
	assert(not is_zero_approx(fig.offset_left + fig.offset_right), "figür yandan kayarak başlamalı")
	assert(fig.modulate.a < 0.5, "figür saydamdan başlamalı")
	assert(_row_on(shop, b) and not _row_on(shop, a), "vurgu yeni seçili satırda")
	await _wait(SETTLE)
	_assert_settled(shop, "seçim")
	assert(is_zero_approx(fig.offset_left + fig.offset_right), "figür ortaya oturmalı: %s %s" % [fig.offset_left, fig.offset_right])

	## Satın alma (papağan 120): bakiye eskisinden sayar, figür parlar.
	shop.call("_select", _find(shop, a))
	await _wait(SETTLE)
	shop.call("_on_buy_pressed", "pet", "papagan")
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert(MetaProgressScript.is_unlocked("pet", "papagan"), "satın alındı")
	var bal: Label = shop.get("_balance_label")
	assert(bal.text == "150", "sayaç eski bakiyeden başlamalı: %s" % bal.text)
	assert(_figure(shop).modulate.r > 1.0, "alınan figür parlamalı: %s" % _figure(shop).modulate)
	assert(_row(shop, a).modulate.r > 1.0, "alınan satır parlamalı: %s" % _row(shop, a).modulate)
	await _wait(SETTLE)
	assert(bal.text == str(MetaProgressScript.shards()) and bal.text == "30", "sayaç yeni bakiyede durmalı: %s" % bal.text)
	_assert_settled(shop, "satın alma")
	_end(shop)


func test_disabled_setting_is_instant() -> void:
	_begin()
	UISound.ui_anim_enabled = false
	MetaProgressScript.grant_victory()
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	_assert_settled(shop, "kapalı açılış")
	shop.call("_on_tab_pressed", "pet")
	_assert_settled(shop, "kapalı sayfa")
	for id: String in ["pet:kelebek", "pet:papagan"]:
		shop.call("_select", _find(shop, id))
		var fig := _figure(shop)
		assert(is_zero_approx(fig.offset_left + fig.offset_right), "kapalıyken figür anında yerinde")
		assert(_row_on(shop, id), "kapalıyken vurgu anında seçili satırda")
	shop.call("_on_buy_pressed", "pet", "papagan")
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert((shop.get("_balance_label") as Label).text == "30", "kapalıyken bakiye anında")
	_assert_settled(shop, "kapalı satın alma")
	_end(shop)
