extends Control

## ÜST ORTA BOSS BARI (kullanıcı isteği 2026-10-05: "boss aktifken diğer oyunlardaki gibi ekranın üst ortasında, kendine özel can ve
## kalkan barı tasarımı"; prototip T1 "Ahşap Plaket" seçildi). Sahnede canlı en az bir boss ("boss" grubu) varken gösterilir.
##
## Her peer KENDİ ekranı için kendi seçimini yapar (ağdan bir şey gönderilmez): host'ta gerçek yaratıkları, istemcide kuklaları okur
## (can, kalkan ve ölüm zaten senkron; maks can/kalkan istemcide aynı formülle hesaplanıyor, bkz. enemy_spawner _rpc_client_spawn_creature).
## TEK bar (kullanıcı isteği 2026-10-05: "birden fazla boss barı gözükmemeli"): kamera merkezine en yakın boss gösterilir, iki boss
## yarışırken bar sürekli el değiştirmesin diye histerezisli (bkz. order_bosses). Final'de 13 boss birden çıksa da tek bar vardır.
## Çizim boss_bar_art.gd'de (boss üstü kafatası plakasıyla ortak). Kendi opaklığı UISound'un "Arayüz Opaklığı" ayarına bağlı (main.gd).

const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const MobileUI := preload("res://scripts/mobile_ui.gd")

const TOP_Y := 50.0 ## FPS göstergesinin (y 8-44) ve sonsuz mod yazısının altı
const PHONE_TOP_Y := 10.0
const REFRESH_SECONDS := 1.0 / 15.0
const FADE_SECONDS := 0.25
## Ana boss el değiştirsin diye gereken üstünlük: yeni en yakın, eski ana bossun mesafesinin bu oranından (+ pay) yakın olmalı.
const FOCUS_RATIO := 1.25
const FOCUS_SLACK := 120.0

var scale_px: float = 3.0 ## 1 sanat pikseli = kaç ekran pikseli (telefonda 2)
## Üst kenar (ekran y) sağlayıcısı: main.gd verir (telefonda görev satırlarının altı). Boşsa sabit TOP_Y.
var top_y_getter: Callable = Callable()

var _entry: Dictionary = {} ## gösterilen bossun {"name": String, "hp": float, "sh": float}; boş = gösterme
var _signature: String = ""
var _main_id: int = 0
var _timer: float = 0.0
var _shown: bool = false
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_px = 2.0 if MobileUI.enabled else 3.0
	visible = false
	self_modulate.a = 0.0
	get_viewport().size_changed.connect(_layout)


## Ekrandaki barın alt kenarı (ekran y); gösterilmiyorsa 0. main.gd bildirimleri (toast) bunun altına yerleştirir.
func get_bottom_y() -> float:
	return position.y + size.y if (_shown and visible) else 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_SECONDS:
		return
	_timer = 0.0
	refresh()


## Seçim kuralı (SAF - testler çağırır). items: [{"id": int, "dist": float}]; döner: id'ler, ana boss ilk, kalanlar yakından uzağa.
## current_id canlı ve "yeterince yakın" kalıyorsa ana boss o kalır.
static func order_bosses(items: Array, current_id: int) -> Array:
	var sorted: Array = items.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["dist"]), float(b["dist"])):
			return int(a["id"]) < int(b["id"])
		return float(a["dist"]) < float(b["dist"]))
	var ids: Array = []
	for it: Dictionary in sorted:
		ids.append(int(it["id"]))
	if ids.is_empty():
		return ids
	var main_id: int = int(ids[0])
	var nearest: float = float(sorted[0]["dist"])
	for it: Dictionary in sorted:
		if int(it["id"]) == current_id and float(it["dist"]) <= nearest * FOCUS_RATIO + FOCUS_SLACK:
			main_id = current_id
	ids.erase(main_id)
	ids.push_front(main_id)
	return ids


func _view_center() -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	return cam.get_screen_center_position() if cam else Vector2.ZERO


static func _ratio(value: float, maximum: float) -> float:
	return clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


## Canlı bossları okur, gösterilecek listeyi kurar, değiştiyse yeniden çizer. (Testler doğrudan çağırabilir.)
func refresh() -> void:
	var center: Vector2 = _view_center()
	var items: Array = []
	var by_id: Dictionary = {}
	for b: Node in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b) or b.get("is_dead") == true or float(b.get("max_health")) <= 0.0:
			continue
		var id: int = b.get_instance_id()
		by_id[id] = b
		items.append({"id": id, "dist": (b as Node2D).global_position.distance_to(center)})
	if items.is_empty():
		if _shown:
			_shown = false
			_fade(0.0)
		return
	var order: Array = order_bosses(items, _main_id)
	_main_id = int(order[0])
	var boss: Node = by_id[_main_id]
	var e := {
		"name": ArtScript.display_name(str(boss.get_meta("creature_id", ""))),
		"hp": _ratio(float(boss.get("health")), float(boss.get("max_health"))),
		"sh": _ratio(float(boss.get("item_shield_hp")), float(boss.get("item_shield_max"))),
	}
	var sig: String = "%s:%d:%d" % [e["name"], int(round(float(e["hp"]) * 1000.0)), int(round(float(e["sh"]) * 1000.0))]
	if not _shown:
		_shown = true
		visible = true
		_fade(1.0)
	if sig != _signature:
		_signature = sig
		_entry = e
		_layout()
		queue_redraw()


func _fade(to: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "self_modulate:a", to, FADE_SECONDS)
	if to <= 0.0:
		_tween.tween_callback(func() -> void:
			visible = false
			_entry = {}
			_signature = "")


func _layout() -> void:
	var s: float = scale_px
	size = Vector2(float(ArtScript.TOP_W) * s, float(ArtScript.TOP_H) * s)
	var y: float = TOP_Y if scale_px >= 3.0 else PHONE_TOP_Y
	if top_y_getter.is_valid():
		y = float(top_y_getter.call())
	position = Vector2(roundf((get_viewport_rect().size.x - size.x) * 0.5), y)


func _draw() -> void:
	if _entry.is_empty():
		return
	ArtScript.top_plaque(self, Vector2.ZERO, scale_px, str(_entry["name"]), float(_entry["hp"]), float(_entry["sh"]))
