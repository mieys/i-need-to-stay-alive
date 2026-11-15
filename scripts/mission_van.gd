extends Node2D
class_name MissionVan

## "Konvoyu Koru" (Escort the van) - kullanıcı isteği: "ufak bir daire olucak o daireye yakın
## durarak hedefe itmesini sağlıcaz uzaklaşırsak daire geri döner yavaşça (gidiş hızının
## %20si kadar)". Bu script SALT GÖRSEL - gerçek itme/geri kayma hesabı world_event_manager.gd
## _tick_mission'da (host-only) yapılır, sonuç world_event_progress (value = rota boyunca kat edilen
## mesafe) ile TÜM istemcilere yayılır; bu Node HER istemcide (host dahil) o ilerlemeden konumunu
## türetir (bkz. set_progress / point_on_path) - Capture the Point'in aynı "host hesaplar, herkes aynı
## formülle çizer" mantığı.
##
## GÜNCELLEME (kullanıcı isteği 2026-09-24): "Konvoy arabasının görüntüsünü sıfırdan pixel art olarak tasarla 4
## direction ve hareket edebilen bir konvoy arabası olmalı ayrıca arabayı götüreceğimiz yerler çok daha uzak olmalı"):
## - Görsel: (2026-11-13'te at + seyyar satıcı arabasıyla DEĞİŞTİ, bkz. aşağıdaki GÜNCELLEME; eski çizim arabası silindi).
## - Rota: artık düz bir çizgi DEĞİL, host'ta orman duvarlarını dolanan çok parçalı bir yol (world_event_manager.gd
##   _escort_route, yaratıkların A* yol bulmasıyla) - başlangıç + dönüş noktaları + bitiş, extra["route"] ile gelir.
##   Kalan rota yerde noktalarla, varış noktası damalı bir bayrakla gösterilir (uzun rotada nereye gidildiği belli olsun).

## GÜNCELLEME (kullanıcı isteği 2026-11-13, madde 650): "konvoy şu anda ai. onu oyunumdaki at arabası ve at assetiyle değiştir, çalışma mantığı
## aynı, seyyar satıcıdakine benzer": görsel artık seyyar satıcının yeşil brandalı arabası + ona koşulu at (tools/gen_convoy_horse_cart_sprite.py,
## satıcıyla aynı karolar/katman sırası, 1 sanat px = 1 dünya px - satıcı sahnesiyle aynı ölçek). Kaynakta yalnız YAN görünüş araba var: sola bakan
## sayfa, sağa flip_h; dikey rota parçasında son yatay yön korunur. İtilirken at "walk" (geri kayarken TERS), dururken "idle" oynar.
const CartFrames := preload("res://assets/fx/mission_van/horse_cart_frames.tres")
const HorseBlockerScript := preload("res://scripts/mission_van_horse_blocker.gd")
const TEXEL := 1.212 ## PixelDraw.TEXEL - rota noktaları / bayrak piksel dili
const SPRITE_SCALE := 1.0 ## seyyar satıcı sahnesiyle aynı (16 px karo = 16 dünya px)
const SHEET_W := 96
const SHEET_H := 58
const SHEET_GROUND_Y := 52 ## gen_convoy_horse_cart_sprite.py - tekerleklerin yere değdiği satır
const MOVE_ANIM_HOLD := 0.35 ## son ilerleme değişiminden bu kadar sn sonra araba "durdu" sayılır
const DISPLAY_SMOOTHING := 8.0 ## 1/sn - ağdan 10 Hz gelen ilerlemeyi karede yumuşat
const ROUTE_DOT_SPACING := 26.0
const ROUTE_DOT_COLOR := Color(1.0, 0.92, 0.55, 0.55)
## Çarpışma + derinlik (2026-10-10, kullanıcı: "konvoy görevi de y eksenine uygun olmalı ve collision shape içermeli"): "move_blockers" grubu (player.gd
## _block_movement_into_blockers) - araba gövdesi bu düğüm, at ayrı bir çocuk engel (mission_van_horse_blocker.gd; tek çember uzun at+arabayı kaplayamaz).
## Sola bakarken araba merkezi düğümün CART_DX sağında, at HORSE_DX solunda (sağa bakarken ayna). Oyuncu arabanın arkasındaysa araba onun üstüne çizilir.
const BLOCK_RADIUS := 24.0
const BLOCK_CENTER_UP := 8.0
const CART_DX := 17.0
const HORSE_DX := -26.0
const HORSE_BLOCK_RADIUS := 11.0
const DEPTH_HALF_WIDTH := 48.0
const DEPTH_HEIGHT := 52.0
var block_radius: float = BLOCK_RADIUS

var route: PackedVector2Array = PackedVector2Array()
var push_radius: float = 130.0
var _cum: PackedFloat32Array = PackedFloat32Array() ## rota noktalarına kadar birikimli uzunluk
var _total: float = 0.0
var _target_dist: float = 0.0
var _shown_dist: float = 0.0
var _last_drawn_dist: float = -1.0
var _pushed: bool = false ## son ilerleme yönü ileri miydi (daire rengi)
var _move_hold: float = 0.0
var _move_dir: int = 0 ## +1 ileri, -1 geri, 0 duruyor
var _anim: AnimatedSprite2D = null
var _route_layer: Node2D = null
var _horse_blocker: Node2D = null
var _facing_left: bool = true ## sayfa sola bakar; sağa = flip_h


## Rota üzerindeki `dist` mesafesindeki nokta - host'un itme dairesi hesabı (world_event_manager.gd
## _escort_current_pos) ile her istemcinin çizimi AYNI fonksiyonu kullanır (iki yerde ayrı formül olmasın).
static func point_on_path(path: PackedVector2Array, dist: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var left: float = maxf(0.0, dist)
	for i in range(path.size() - 1):
		var seg: float = path[i].distance_to(path[i + 1])
		if left <= seg:
			return path[i].lerp(path[i + 1], left / maxf(seg, 0.001))
		left -= seg
	return path[path.size() - 1]


static func path_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	return total


func setup(p_route: PackedVector2Array, p_push_radius: float) -> void:
	route = p_route
	push_radius = p_push_radius
	_cum = PackedFloat32Array()
	_total = 0.0
	for i in range(route.size()):
		if i > 0:
			_total += route[i - 1].distance_to(route[i])
		_cum.append(_total)
	_target_dist = 0.0
	_shown_dist = 0.0
	if not route.is_empty():
		global_position = route[0]
		## İlk yatay yön: ilk belirgin yatay parça, yoksa baştan sona yön (dikey rotada da at bir yana baksın).
		_facing_left = route[route.size() - 1].x < route[0].x
		for i in range(route.size() - 1):
			var d: Vector2 = route[i + 1] - route[i]
			if absf(d.x) > absf(d.y) * 0.5 and absf(d.x) > 1.0:
				_facing_left = d.x < 0.0
				break
	_update_facing()
	queue_redraw()
	if _route_layer:
		_route_layer.queue_redraw()


func _ready() -> void:
	z_index = 0 ## itme dairesi zemin gibi; arabanın kendisi _update_depth ile oyuncunun önüne/arkasına geçer
	add_to_group("move_blockers")
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = CartFrames
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	## Sayfadaki tekerlek-zemin satırı bu Node'un konumuna (rota noktası) denk gelsin.
	_anim.position = Vector2(0.0, -(float(SHEET_GROUND_Y) - float(SHEET_H) * 0.5) * SPRITE_SCALE)
	add_child(_anim)
	_anim.play(&"idle")
	_horse_blocker = HorseBlockerScript.new()
	_horse_blocker.set("block_radius", HORSE_BLOCK_RADIUS)
	add_child(_horse_blocker)
	## Kalan rota + varış bayrağı dünya koordinatında (araba hareket ettikçe kaymasın) ayrı bir katmanda.
	_route_layer = Node2D.new()
	_route_layer.top_level = true
	_route_layer.z_index = 0
	_route_layer.draw.connect(_draw_route)
	add_child(_route_layer)
	_update_facing()


## value: rota boyunca kat edilen mesafe (0..target), target: rota uzunluğu (bkz. world_event_manager.gd).
func set_progress(value: float, target: float, pushed: bool) -> void:
	var total: float = _total if _total > 0.0 else target
	var new_dist: float = clampf(value, 0.0, total)
	if absf(new_dist - _target_dist) > 0.01:
		_move_dir = 1 if new_dist > _target_dist else -1
		_move_hold = MOVE_ANIM_HOLD
	_target_dist = new_dist
	_pushed = pushed


func _process(delta: float) -> void:
	if route.is_empty():
		return
	_shown_dist = lerpf(_shown_dist, _target_dist, 1.0 - exp(-DISPLAY_SMOOTHING * delta))
	if absf(_shown_dist - _target_dist) < 0.05:
		_shown_dist = _target_dist
	global_position = point_on_path(route, _shown_dist)
	_update_facing()
	_update_depth()
	_move_hold -= delta
	if _move_hold <= 0.0:
		_move_dir = 0
	if _move_dir == 0:
		if _anim.animation != &"idle":
			_anim.play(&"idle")
	elif _anim.animation != &"walk" or not _anim.is_playing() or (_move_dir < 0) != (_anim.get_playing_speed() < 0.0):
		if _move_dir > 0:
			_anim.play(&"walk")
		else:
			_anim.play_backwards(&"walk")
	if absf(_shown_dist - _last_drawn_dist) >= 2.0:
		_last_drawn_dist = _shown_dist
		queue_redraw()
		_route_layer.queue_redraw()


## Araba gövdesinin çember merkezi (at çocuk engelde, bkz. _update_facing).
func block_center() -> Vector2:
	return global_position + Vector2(-CART_DX if not _facing_left else CART_DX, -BLOCK_CENTER_UP)


func _update_depth() -> void:
	var behind: bool = false
	for group_name in ["player", "remote_players"]:
		for p: Node in get_tree().get_nodes_in_group(group_name):
			if not (p is Node2D) or not is_instance_valid(p):
				continue
			var feet: Vector2 = (p as Node2D).global_position + Vector2(0.0, 12.75)
			if feet.y < global_position.y and feet.y > global_position.y - DEPTH_HEIGHT and absf(feet.x - global_position.x) < DEPTH_HALF_WIDTH:
				behind = true
	_anim.z_index = 2 if behind else 0


## Şu anki rota segmentinin yatay yönüne göre sola/sağa bak (araba geri kayarken de yüzü gidiş yönünde kalır); belirgin yatay bileşeni olmayan
## (dikey) parçada son yön korunur - kaynakta önden/arkadan araba yok.
func _update_facing() -> void:
	if _anim == null or route.size() < 2:
		return
	var i: int = 0
	while i < route.size() - 2 and _cum[i + 1] <= _shown_dist:
		i += 1
	var dir: Vector2 = route[i + 1] - route[i]
	if absf(dir.x) > absf(dir.y) * 0.5 and absf(dir.x) > 1.0:
		_facing_left = dir.x < 0.0
	_anim.flip_h = not _facing_left
	if _horse_blocker:
		_horse_blocker.position = Vector2(HORSE_DX if _facing_left else -HORSE_DX, -BLOCK_CENTER_UP)


func _draw() -> void:
	## İtme yarıçapı (kullanıcı isteği: "ufak bir daire") - itilirken mavi, geri kayarken turuncu.
	draw_arc(Vector2.ZERO, push_radius, 0, TAU, 48, Color(0.55, 0.9, 1.0, 0.4) if _pushed else Color(1.0, 0.55, 0.3, 0.5), 2.5)
	## İlerleme çubuğu (arabanın üstünde).
	var ratio: float = _shown_dist / maxf(_total, 0.001)
	var bar_w := 56.0
	var bar_y: float = -(float(SHEET_GROUND_Y) + 6.0) * SPRITE_SCALE
	draw_rect(Rect2(-bar_w * 0.5 - 1.0, bar_y - 1.0, bar_w + 2.0, 8.0), Color(0.08, 0.06, 0.05, 0.9))
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * clampf(ratio, 0.0, 1.0), 6.0), Color(0.95, 0.8, 0.25, 1.0))


## Kalan rota: yerde eşit aralıklı küçük kare noktalar + varışta damalı bayrak (piksel dili: TEXEL kareleri).
func _draw_route() -> void:
	if route.size() < 2:
		return
	var d: float = ceilf((_shown_dist + push_radius * 0.5) / ROUTE_DOT_SPACING) * ROUTE_DOT_SPACING
	var dot := Vector2(2.0, 2.0) * TEXEL
	while d < _total - ROUTE_DOT_SPACING * 0.5:
		var p: Vector2 = point_on_path(route, d)
		_route_layer.draw_rect(Rect2(p - dot * 0.5, dot), ROUTE_DOT_COLOR)
		d += ROUTE_DOT_SPACING
	var end: Vector2 = route[route.size() - 1]
	var t := TEXEL
	## Direk (1x16 texel) + 6x4 damalı bayrak + zemin gölgesi.
	_route_layer.draw_rect(Rect2(end + Vector2(-3.0 * t, -0.5 * t), Vector2(7.0 * t, 1.0 * t)), Color(0, 0, 0, 0.35))
	_route_layer.draw_rect(Rect2(end + Vector2(-1.0 * t, -17.0 * t), Vector2(3.0 * t, 17.0 * t)), Color(0.09, 0.06, 0.04, 1.0))
	_route_layer.draw_rect(Rect2(end + Vector2(0.0, -16.0 * t), Vector2(1.0 * t, 16.0 * t)), Color(0.55, 0.36, 0.2, 1.0))
	var flag_origin: Vector2 = end + Vector2(1.0 * t, -16.0 * t)
	_route_layer.draw_rect(Rect2(flag_origin - Vector2(0.0, t), Vector2(8.0 * t, 6.0 * t)), Color(0.09, 0.06, 0.04, 1.0))
	for fy in range(4):
		for fx in range(6):
			var white: bool = (fx + fy) % 2 == 0
			_route_layer.draw_rect(Rect2(flag_origin + Vector2(float(fx) * t, float(fy) * t), Vector2(t, t)),
				Color(0.95, 0.93, 0.86, 1.0) if white else Color(0.12, 0.1, 0.1, 1.0))
