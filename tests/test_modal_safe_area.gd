extends Node

## Kullanıcı bildirimi (2026-10-08): "oyundaki bazı arayüzler içeriğine göre büyüyüp küçülüyor dükkanlar gibi. grup panelinin altında kalınca çarpıya
## basamıyorum" - grup paneli (layer 96) dükkan pencerelerinin (layer 80) üstünde durur; ortalanan pencerenin X düğmesi şeridin altına düşebiliyordu.
## Kapsam: ModalSafeArea (şerit genişliği), demirci + seyyar satıcı pencerelerinin güvenli alana sığması, X düğmesinin şeritle kesişmemesi,
## panel sonradan görünür/gizli olunca yeniden sığdırma.

const ScreenScript: GDScript = preload("res://scripts/weapon_shop_screen.gd")
const MerchantScript: GDScript = preload("res://scripts/merchant_shop_screen.gd")
const SafeArea: GDScript = preload("res://scripts/modal_safe_area.gd")
const PartyScript: GDScript = preload("res://scripts/party_panel.gd")
const MobileUIPath := "res://scripts/mobile_ui.gd"

var _nodes: Array[Node] = []
var _saved_weapons: Array = []
var _saved_gold: int = 0


class FakePlayer extends Node2D:
	func get_max_owned_weapons() -> int:
		return 5

	func buy_weapon_copy(_key: String, _level: int) -> bool:
		return true


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size


## Sağ üstte, gerçek panelle aynı ölçülerde sahte grup paneli (Background çocuğu görünür).
func _fake_party(height: float = 320.0, left: float = -1.0) -> Control:
	var pp := Control.new()
	pp.name = "PartyPanel"
	add_child(pp)
	pp.add_to_group(&"party_panel")
	var bg := Control.new()
	bg.name = "Background"
	pp.add_child(bg)
	## left verilirse şerit o x'ten ekranın sağına uzanır (geniş şerit: ortalanmış pencerenin sığmadığı durumu zorlar).
	var x: float = left if left >= 0.0 else _view().x - PartyScript.RIGHT_MARGIN - PartyScript.ROW_WIDTH
	bg.size = Vector2(_view().x - x - PartyScript.RIGHT_MARGIN if left >= 0.0 else PartyScript.ROW_WIDTH, height)
	bg.global_position = Vector2(x, PartyScript.TOP_Y)
	_nodes.append(pp)
	return pp


func _drop(n: Node) -> void:
	if is_instance_valid(n):
		if n.is_in_group(&"party_panel"):
			n.remove_from_group(&"party_panel")
		n.free()


func _cleanup() -> void:
	for n in _nodes:
		_drop(n)
	_nodes.clear()
	GameManager.owned_weapons = _saved_weapons
	GameManager.gold = _saved_gold


func _begin() -> void:
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	_saved_gold = GameManager.gold
	(load(MobileUIPath) as GDScript).set(&"enabled", false)


func _find_close_button(root_node: Node) -> Button:
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text == "X":
			return n as Button
		stack.append_array(n.get_children())
	return null


## Kontrol dikdörtgeni, ölçek/pivot dahil gerçek ekran konumuyla (Control.get_global_rect ölçeği hesaba katmıyor).
func _screen_rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform()
	var a: Vector2 = xf * Vector2.ZERO
	var b: Vector2 = xf * c.size
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _window_of(screen: Node) -> Control:
	for c in screen.get_children():
		if c is CenterContainer and c.get_child_count() > 0:
			return c.get_child(0) as Control
	return null


# ------------------------------------------------------------------ şerit hesabı

func test_reserved_strip_is_zero_without_a_visible_party_panel() -> void:
	assert(is_equal_approx(SafeArea.reserved_right(get_tree(), _view()), 0.0), "panel yokken şerit 0")
	var pp: Control = _fake_party()
	pp.visible = false
	assert(is_equal_approx(SafeArea.reserved_right(get_tree(), _view()), 0.0), "panel gizliyken şerit 0")
	pp.visible = true
	var expect: float = PartyScript.RIGHT_MARGIN + PartyScript.ROW_WIDTH + SafeArea.GAP
	assert(is_equal_approx(SafeArea.reserved_right(get_tree(), _view()), expect), "görünürken şerit = kenar boşluğu + levha + boşluk: %s" % SafeArea.reserved_right(get_tree(), _view()))
	var r: Rect2 = SafeArea.rect(get_tree(), _view())
	assert(is_equal_approx(r.size.x, _view().x - expect) and is_equal_approx(r.size.y, _view().y), "güvenli alan = ekran - şerit")
	_cleanup()


func test_reserved_strip_is_capped_on_narrow_screens() -> void:
	var pp: Control = _fake_party()
	var bg: Control = pp.get_node("Background") as Control
	bg.global_position.x = 10.0 ## panel neredeyse tüm genişlikte (bozuk yerleşim)
	assert(SafeArea.reserved_right(get_tree(), _view()) <= _view().x * SafeArea.MAX_RESERVED_FRACTION + 0.01, "şerit ekranın %40'ını geçemez")
	_cleanup()


# ------------------------------------------------------------------ demirci penceresi

func test_smithy_window_stays_left_of_the_party_panel_and_close_button_is_clickable() -> void:
	_begin()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("dagger", 1, 0)]
	GameManager.gold = 1000
	var pp: Control = _fake_party()
	var p := FakePlayer.new()
	add_child(p)
	_nodes.append(p)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	_nodes.append(screen)
	screen.setup(p)
	await _frames(8)
	var window: Control = _window_of(screen)
	assert(window != null, "pencere bulunmalı")
	var strip_left: float = (pp.get_node("Background") as Control).global_position.x
	var wr: Rect2 = _screen_rect(window)
	assert(wr.end.x <= strip_left + 0.5, "pencerenin sağ kenarı (%.0f) grup panelinin sol kenarından (%.0f) sonra başlamamalı" % [wr.end.x, strip_left])
	var close_btn: Button = _find_close_button(screen)
	assert(close_btn != null, "X düğmesi bulunmalı")
	var br: Rect2 = _screen_rect(close_btn)
	var strip: Rect2 = Rect2(strip_left, 0.0, _view().x - strip_left, _view().y)
	assert(not br.intersects(strip), "X düğmesi grup şeridiyle kesişmemeli: X %s şerit %s" % [str(br), str(strip)])
	## Pencere güvenli alanda ortalı.
	var safe: Rect2 = SafeArea.rect(get_tree(), _view())
	assert(absf(wr.get_center().x - safe.get_center().x) <= 2.0, "pencere güvenli alanda ortalı: %.1f / %.1f" % [wr.get_center().x, safe.get_center().x])
	## Sekme değişince (içerik boyu değişir) X hâlâ şeridin dışında.
	for tab in [screen.Tab.SHIELDS, screen.Tab.ENCHANTS, screen.Tab.WEAPONS]:
		screen._show_tab(tab)
		await _frames(4)
		var br2: Rect2 = _screen_rect(_find_close_button(screen))
		assert(not br2.intersects(strip), "sekme %d: X şeritle kesişmemeli" % tab)
	screen._on_close_pressed()
	_nodes.erase(screen)
	_cleanup()


func test_smithy_window_is_centered_on_the_whole_screen_without_a_party_panel() -> void:
	_begin()
	GameManager.owned_weapons = []
	var p := FakePlayer.new()
	add_child(p)
	_nodes.append(p)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	_nodes.append(screen)
	screen.setup(p)
	await _frames(8)
	var wr: Rect2 = _screen_rect(_window_of(screen))
	assert(absf(wr.get_center().x - _view().x * 0.5) <= 2.0, "panel yokken pencere ekranın ortasında: %.1f / %.1f" % [wr.get_center().x, _view().x * 0.5])
	screen._on_close_pressed()
	_nodes.erase(screen)
	_cleanup()


func test_open_smithy_refits_when_the_party_panel_appears_later() -> void:
	_begin()
	GameManager.owned_weapons = []
	var p := FakePlayer.new()
	add_child(p)
	_nodes.append(p)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	_nodes.append(screen)
	screen.setup(p)
	await _frames(8)
	var before: float = _screen_rect(_window_of(screen)).get_center().x
	var pp: Control = _fake_party()
	await get_tree().create_timer(0.5).timeout ## ekran durumu 0,25 sn'de bir yoklar
	var after: Rect2 = _screen_rect(_window_of(screen))
	assert(after.get_center().x < before - 10.0, "panel sonradan görününce pencere sola kayar: %.1f -> %.1f" % [before, after.get_center().x])
	assert(after.end.x <= (pp.get_node("Background") as Control).global_position.x + 0.5, "ve şeridin soluna sığar")
	pp.visible = false
	await get_tree().create_timer(0.5).timeout
	assert(absf(_screen_rect(_window_of(screen)).get_center().x - before) <= 2.0, "panel gizlenince pencere yeniden ortalanır")
	screen._on_close_pressed()
	_nodes.erase(screen)
	_cleanup()


# ------------------------------------------------------------------ seyyar satıcı penceresi

func test_merchant_window_stays_left_of_the_party_panel() -> void:
	_begin()
	## Geniş şerit (ekranın sağ %38'i): satıcı penceresi ortalanmış hâliyle sığmaz, güvenli alana küçülmeli.
	var pp: Control = _fake_party(320.0, _view().x * 0.62)
	var p := FakePlayer.new()
	add_child(p)
	_nodes.append(p)
	var screen: CanvasLayer = MerchantScript.new()
	add_child(screen)
	_nodes.append(screen)
	screen.setup(p, [])
	await _frames(8)
	var window: Control = _window_of(screen)
	assert(window != null, "satıcı penceresi bulunmalı")
	var strip_left: float = (pp.get_node("Background") as Control).global_position.x
	assert(_screen_rect(window).end.x <= strip_left + 0.5, "satıcı penceresi grup panelinin soluna sığmalı: %.0f / %.0f" % [_screen_rect(window).end.x, strip_left])
	var close_btn: Button = _find_close_button(screen)
	assert(close_btn != null and not _screen_rect(close_btn).intersects(Rect2(strip_left, 0.0, _view().x - strip_left, _view().y)), "X şeritle kesişmemeli")
	screen._on_close_pressed()
	_nodes.erase(screen)
	_cleanup()
