extends Node

## madde 323: Ruh Mağazası animasyonları (soul_shop_screen.gd _play_anims). Sayfa girişi / seçim / satın alma animasyonu oynar ve
## bitince her şey TAM eski hâlinde (alfa 1, ölçek 1, parlama sönmüş, figür ofseti ve kart payları son değerinde); ayar kapalıyken anında.
## Kıymıklar GEÇİCİ dosyada (path_override) - gerçek user://meta.cfg'ye dokunmaz. Başlangıç evcili (köpek) mağaza listesinde yok.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const SETTLE := 1.0 ## en uzun animasyon ~0,6 sn; ekransız koşuda ilk kareler yavaş olabiliyor

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


## Animasyon bitince hiçbir öğe saydam / ölçekli / parlak kalmamalı.
func _assert_settled(shop: Node, what: String) -> void:
	for c: Node in shop.find_children("*", "Control", true, false):
		var ctl := c as Control
		assert(is_equal_approx(ctl.modulate.a, 1.0), "%s: saydam kaldı %s (%s)" % [what, ctl, ctl.modulate])
		assert(ctl.modulate.r <= 1.001 and ctl.modulate.g <= 1.001, "%s: parlama sönmedi %s" % [what, ctl.modulate])
		assert(ctl.scale.is_equal_approx(Vector2.ONE), "%s: ölçek kaldı %s (%s)" % [what, ctl, ctl.scale])


## Kart sarmalayıcısı = şeffaf katman ("card:<id>") -> kart -> sarmalayıcı.
func _wrap(shop: Node, id: String) -> MarginContainer:
	for b: Node in shop.find_children("*", "Button", true, false):
		if b.has_meta("sid") and str(b.get_meta("sid")) == "card:" + id:
			return b.get_parent().get_parent() as MarginContainer
	return null


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

	## Sayfa değişimi: kartlar sırayla belirir.
	shop.call("_on_tab_pressed", "pet")
	var a: String = "pet:papagan"
	var b: String = "pet:kelebek"
	assert(_wrap(shop, a) != null and _wrap(shop, b) != null, "evcil kartları kuruldu")
	assert(_wrap(shop, b).modulate.a < 0.5, "sayfa girişinde kartlar saydamdan başlamalı")
	await _wait(SETTLE)
	_assert_settled(shop, "evcil sayfası")
	if _wrap(shop, a).get_theme_constant("margin_top") != 0: ## ilk seçili papağan değilse önce onu seç
		shop.call("_select", _find(shop, a))
		await _wait(SETTLE)

	## Seçim: figür yandan kayar, yeni kart yükselir, eskisi iner.
	shop.call("_select", _find(shop, b))
	var fig := _figure(shop)
	assert(fig != null, "sahne figürü var")
	assert(not is_zero_approx(fig.offset_left + fig.offset_right), "figür yandan kayarak başlamalı")
	assert(fig.modulate.a < 0.5, "figür saydamdan başlamalı")
	assert(_wrap(shop, b).get_theme_constant("margin_top") == 14, "yeni seçili kart aşağıdan başlamalı")
	assert(_wrap(shop, a).get_theme_constant("margin_top") == 0, "eski seçili kart yukarıdan başlamalı")
	await _wait(SETTLE)
	_assert_settled(shop, "seçim")
	assert(is_zero_approx(fig.offset_left + fig.offset_right), "figür ortaya oturmalı: %s %s" % [fig.offset_left, fig.offset_right])
	var ws := _wrap(shop, b)
	var wp := _wrap(shop, a)
	assert(ws.get_theme_constant("margin_top") == 0 and ws.get_theme_constant("margin_bottom") == 14, "seçili kart yukarıda")
	assert(wp.get_theme_constant("margin_top") == 14 and wp.get_theme_constant("margin_bottom") == 0, "eski kart aşağıda")

	## Satın alma (papağan 120): bakiye eskisinden sayar, figür parlar.
	shop.call("_select", _find(shop, a))
	await _wait(SETTLE)
	shop.call("_on_buy_pressed", "pet", "papagan")
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert(MetaProgressScript.is_unlocked("pet", "papagan"), "satın alındı")
	var bal: Label = shop.get("_balance_label")
	assert(bal.text == "150", "sayaç eski bakiyeden başlamalı: %s" % bal.text)
	assert(_figure(shop).modulate.r > 1.0, "alınan figür parlamalı: %s" % _figure(shop).modulate)
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
		assert(_wrap(shop, id).get_theme_constant("margin_top") == 0, "kapalıyken kart anında yukarıda")
	shop.call("_on_buy_pressed", "pet", "papagan")
	shop.call("_on_buy_pressed", "pet", "papagan")
	assert((shop.get("_balance_label") as Label).text == "30", "kapalıyken bakiye anında")
	_assert_settled(shop, "kapalı satın alma")
	_end(shop)
