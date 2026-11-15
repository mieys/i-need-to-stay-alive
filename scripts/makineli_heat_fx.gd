extends Node2D

## MAKİNELİ NAMLU KIZARMASI (madde 652, 2026-11-13). Şarjör içinde hızlandıkça namlunun soğutma kanatçıkları uçtan geriye doğru
## turuncuya, en yüksek hızda sarımsı beyaza döner; doldurmada ve ateş kesilince soğur. Silah dokusunun KENDİ pikselleri boyanır
## (1 doku px = 1 kare; yeni şekil yok - piksel ızgarası silahla aynı).
## İki yer kuralı (CLAUDE.md): kaster (weapon.gd _fire_at -> GunReloadFx.on_shot) ve uzak kukla (remote_player.gd "weapon_fire" ->
## GunReloadFx.on_shot) AYNI shot() çağrısını yapar; doldurma başı (GunReloadFx.begin, iki tarafta da) cool() çağırır. Isı, bu şarjörde
## görülen atış sayısından GunMagMath.ramp_heat ile hesaplanır -> ek RPC yok (kuklada özellik geliştirmeleri bilinmez: kozmetik yaklaşık).

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const KEY := "makineli"
const NODE_NAME := "MakineliHeat"
## assets/weapons/makineli/icon.png (64x64) namlunun siyah olmayan pikselleri: kanatçıklar x41-52, gövde x54-59, ağız x61.
const HOT_PX := [Vector2i(61, 19), Vector2i(41, 20), Vector2i(42, 20), Vector2i(44, 20), Vector2i(46, 20), Vector2i(48, 20), Vector2i(50, 20),
	Vector2i(52, 20), Vector2i(54, 20), Vector2i(55, 20), Vector2i(56, 20), Vector2i(57, 20), Vector2i(58, 20), Vector2i(59, 20), Vector2i(61, 20),
	Vector2i(41, 21), Vector2i(42, 21), Vector2i(44, 21), Vector2i(46, 21), Vector2i(48, 21), Vector2i(50, 21), Vector2i(52, 21), Vector2i(58, 21),
	Vector2i(59, 21), Vector2i(61, 21)]
const MUZZLE_X := 61
const SPREAD_PX := 20.0 ## tam ısıda kızarma ağızdan bu kadar piksel geriye yayılır
const HOT_A := Color(1.0, 0.42, 0.12) ## ılık: koyu turuncu
const HOT_B := Color(1.0, 0.9, 0.55) ## en yüksek hız: sarımsı beyaz
const MAX_ALPHA := 0.85
const IDLE_COOL_AFTER := 0.3 ## son atıştan bu kadar sn sonra soğumaya başlar
const COOL_RATE := 1.4 ## ısı/sn
const RELOAD_COOL_RATE := 3.0

var icon: Sprite2D = null
var shots: int = 0
var heat: float = 0.0
var _since_shot: float = 0.0
var _cooling_fast: bool = false


static func _find(p_icon: Node2D, create: bool) -> Node:
	if p_icon == null or not is_instance_valid(p_icon) or not (p_icon is Sprite2D):
		return null
	var n: Node = p_icon.get_node_or_null(NODE_NAME)
	if n == null and create:
		n = (load("res://scripts/makineli_heat_fx.gd") as GDScript).new()
		n.name = NODE_NAME
		n.set("icon", p_icon)
		p_icon.add_child(n)
	return n


## Her atışta (kaster + kukla).
static func shot(p_icon: Node2D) -> void:
	var n: Node = _find(p_icon, true)
	if n != null:
		n.call("_on_shot")


## Doldurma başladı: sayaç sıfır, namlu hızla soğur.
static func cool(p_icon: Node2D) -> void:
	var n: Node = _find(p_icon, false)
	if n != null:
		n.set("shots", 0)
		n.set("_cooling_fast", true)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func _on_shot() -> void:
	shots += 1
	_since_shot = 0.0
	_cooling_fast = false
	## shots. atışın öncesindeki aralık = (shots - 2). aralık; ilk atış soğuk
	var h: float = GunMagMath.ramp_heat(KEY, shots - 2) if shots >= 2 else 0.0
	heat = maxf(heat, h)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_since_shot += delta
	if _cooling_fast or _since_shot >= IDLE_COOL_AFTER:
		heat = maxf(0.0, heat - delta * (RELOAD_COOL_RATE if _cooling_fast else COOL_RATE))
		queue_redraw()
	if heat <= 0.0:
		set_process(false)


func _draw() -> void:
	if heat <= 0.01 or icon == null or not is_instance_valid(icon) or icon.texture == null:
		return
	## Yalnız silahın kendi çizimi görünürken (doldurmanın şarjörsüz gövdesi de aynı namlu pikselleri) - başka doku varsa çizme.
	var tex_size: Vector2 = icon.texture.get_size()
	if tex_size != Vector2(64.0, 64.0):
		return
	draw_set_transform(icon.offset, 0.0, Vector2(-1.0 if icon.flip_h else 1.0, -1.0 if icon.flip_v else 1.0))
	var half: Vector2 = tex_size * 0.5 if icon.centered else Vector2.ZERO
	var col: Color = HOT_A.lerp(HOT_B, clampf((heat - 0.5) * 2.0, 0.0, 1.0))
	var reach: float = SPREAD_PX * heat
	for p in HOT_PX:
		var back: float = float(MUZZLE_X - p.x)
		var w: float = clampf(1.0 - back / maxf(1.0, reach + 2.0), 0.0, 1.0)
		if w <= 0.0:
			continue
		draw_rect(Rect2(Vector2(p) - half, Vector2.ONE), Color(col, MAX_ALPHA * heat * (0.35 + 0.65 * w)))
