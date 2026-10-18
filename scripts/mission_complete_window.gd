extends CanvasLayer

## "Görev Tamamlandı" penceresi (kullanıcı isteği 2026-10-02: "görev tamamlanınca da görev tamamlandı penceresi
## açılmasını ve o pencereden aynı şekilde para paneline gitmesini istiyorum"). main.gd _on_world_event_completed başarıda
## açar (eskiden yalnız sağ üstte bir bildirim yazısı vardı). Görev altını world_event_manager.gd / NetworkManager.
## grant_reward_gold tarafından GoldRewardFx.hold(&"mission") ile zaten eklendi ve bekletiliyor: pencere belirince altın
## satırındaki külçeden release edilir, paralar sol üstteki altın paneline uçar (gold_reward_fx.gd). Bu oyuncu görev
## bölgesinde değildiyse altın satırı çıkmaz. Oyunu durdurmaz, tıklamaları yutmaz, kendi kendine kapanır.

## 2026-10-18 (madde 264): görünüş "A Ahşap Levha" - HUD levhası + altın kumaş kurdele + ödül kuyuları (game_notice.gd complete);
## eski bej PanelContainer + etiketler kalktı. Paralar altın kuyusunun merkezinden uçar.

const UiAnim := preload("res://scripts/ui_anim.gd")
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const GameNotice := preload("res://scripts/game_notice.gd")

const LAYER := 40 ## altın uçuş katmanının (41) hemen altı - paralar pencerenin üstünden çıkar
const TOP := 128.0
const STACK_GAP := 12.0
const POP_TIME := 0.25
const RELEASE_AT := 0.45
const HOLD_TIME := 3.6
const FADE_TIME := 0.35

static var _open: Array = []

var mission_label: String = ""
var _panel: Control = null
var _gold: int = 0
var _t: float = 0.0
var _released: bool = false


## Pencereyi açar. Başlıktan önce çağıran (main.gd) etiketi verir.
static func open(parent: Node, label: String) -> void:
	if parent == null:
		return
	var w: CanvasLayer = (load("res://scripts/mission_complete_window.gd") as GDScript).new()
	w.set("mission_label", label)
	parent.add_child(w)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open.append(self)
	_gold = GoldRewardFx.held_amount(&"mission")
	_build()
	UiAnim.window_in(self)


func _exit_tree() -> void:
	_open.erase(self)
	## Kapanırken hâlâ bırakılmamış altın varsa (çok kısa ömür) bekletilmesin.
	if not _released and _gold > 0:
		_release_gold()


## Paralar altın kuyusunun ekran merkezinden altın paneline uçar.
func _release_gold() -> void:
	if not is_instance_valid(_panel):
		return
	var local: Vector2 = _panel.call("coin_center")
	if local.x < 0.0:
		local = _panel.size * 0.5
	GoldRewardFx.release(&"mission", _panel.get_global_transform_with_canvas() * local)


func _build() -> void:
	## 2026-10-10: görev ödülü elit sandık yerine silah parçacığı (bkz. world_event_manager.gd MISSION_SHARD_REWARD).
	var shards: int = int((load("res://scripts/world_event_manager.gd") as GDScript).get_script_constant_map().get("MISSION_SHARD_REWARD", 5))
	_panel = GameNotice.complete(mission_label, _gold, shards, HOLD_TIME)
	add_child(_panel)
	## Boyut içerikten - ekranın üst ortasına, açık başka bir pencere varsa onun altına.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var y: float = TOP
	for w in _open:
		if w == self:
			break
		if is_instance_valid(w) and w.get("_panel") != null:
			var other: Control = w.get("_panel")
			y = maxf(y, other.position.y + other.size.y + STACK_GAP)
	_panel.position = Vector2(roundf((view.x - _panel.size.x) * 0.5), y)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.85
	_panel.modulate.a = 0.0


func _process(delta: float) -> void:
	_t += delta
	var pop: float = clampf(_t / POP_TIME, 0.0, 1.0)
	var back: float = 1.0 + 2.70158 * pow(pop - 1.0, 3.0) + 1.70158 * pow(pop - 1.0, 2.0) ## easeOutBack
	_panel.scale = Vector2.ONE * lerpf(0.85, 1.0, back)
	_panel.modulate.a = pop
	if not _released and _t >= RELEASE_AT:
		_released = true
		if _gold > 0:
			_release_gold()
	if _t > HOLD_TIME:
		var k: float = clampf((_t - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
		_panel.modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
