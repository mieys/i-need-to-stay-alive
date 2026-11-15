extends Node2D
class_name TotemLinkRibbon

## Shaman E (Kalkan Totemi) KALKAN ŞERİDİ: taştan bir hedefe giden SÜREKLİ ışık tülü (madde 567; prototip madde 562 D2 + ızgara G1).
## Tek dikdörtgen çizer, görünüş tamamen `shaders/totem_shield_link.gdshader`'da (dünya ızgarasına oturan piksel, dither yok).
## Hedefin KENDİ kalkan baloncuğunun (ShieldVisual/BubbleSprite) taşa bakan yüzüne bağlanır; rengi baloncuğun o anki sanatından
## (kalkan türü, ShieldEnchantDefs.EFFECT_OF) okunur. Baloncuk düğümü yoksa göğse iner.
## Totem (totem_shield.gd) her karede `update_link` çağırır; hedef menzilden çıkınca `release` -> kısa sönme, sonra kendini siler.
## Totemin çocuğu (top_level): totemle birlikte silinir, ruh hâlinde (limbo) totemle birlikte donar. Kozmetik, ağ yok: gerçek totem ve
## ağ görsel kopyası aynı kodu yerelde çalıştırır.

const LINK_SHADER := preload("res://shaders/totem_shield_link.gdshader")
const BUBBLE_FRAME_PX := 24.0 ## baloncuk karesi (assets/fx/shield_bubble*/bubble_frames.tres)
const BUBBLE_VISIBLE_R := 0.46 ## görünen baloncuk yarıçapı / kare genişliği (madde 562 ek: gerçek çizicide ölçüldü)
const CHEST_LIFT := 14.0 ## baloncuk yoksa hedefin göğsü
const FADE_TIME := 0.25
const ARC_H := 10.0
const PAD := 8.0 ## çizim kutusu payı (dünya): dalga + tül yarı genişliği + yay
const ICE_OUTER := Color8(74, 168, 255)
const ICE_INNER := Color8(166, 216, 255)
const ICE_HOT := Color8(255, 255, 255)
## Baloncuk sanatı klasörü -> [dış (core), iç (crest), sıcak (krem)] (sayfalardan örneklendi, madde 567).
const BUBBLE_PALETTES := {
	"shield_bubble_enerji": [Color8(0x89, 0xff, 0x39), Color8(0xe2, 0xff, 0x39), Color8(0xf5, 0xff, 0xbf)],
	"shield_bubble_kale": [Color8(0x40, 0xf7, 0xaf), Color8(0xb8, 0xff, 0xe4), Color8(0xe8, 0xff, 0xf6)],
	"shield_bubble_savas": [Color8(0xce, 0x39, 0x39), Color8(0xed, 0xdb, 0xdb), Color8(0xfb, 0xf3, 0xf3)],
	"shield_bubble": [Color8(0x39, 0xe7, 0xff), Color8(0xdb, 0xea, 0xff), Color8(0xf4, 0xf8, 0xff)],
}

var target_ref: Node2D = null
var _mat: ShaderMaterial = null
var _t: float = 0.0
var _alpha: float = 0.0
var _releasing: bool = false
var _bbox: Rect2 = Rect2()
var _p0: Vector2 = Vector2.ZERO
var _p1: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 60
	_mat = ShaderMaterial.new()
	_mat.shader = LINK_SHADER
	material = _mat
	_mat.set_shader_parameter("arc_h", ARC_H)
	_mat.set_shader_parameter("col_outer_a", ICE_OUTER)
	_mat.set_shader_parameter("col_inner_a", ICE_INNER)
	_mat.set_shader_parameter("col_hot_a", ICE_HOT)
	_mat.set_shader_parameter("alpha_mult", 0.0)


## Baloncuk merkezi + görünen yarıçap (yoksa göğüs + 0).
static func bubble_geometry(target: Node2D) -> Array:
	var bubble: AnimatedSprite2D = target.get_node_or_null("ShieldVisual/BubbleSprite") as AnimatedSprite2D
	if bubble == null:
		return [target.global_position + Vector2(0.0, -CHEST_LIFT), 0.0]
	return [bubble.global_position, BUBBLE_FRAME_PX * BUBBLE_VISIBLE_R * absf(bubble.global_scale.x)]


static func palette_for(target: Node2D) -> Array:
	var bubble: AnimatedSprite2D = target.get_node_or_null("ShieldVisual/BubbleSprite") as AnimatedSprite2D
	if bubble and bubble.sprite_frames:
		var folder: String = bubble.sprite_frames.resource_path.get_base_dir().get_file()
		if BUBBLE_PALETTES.has(folder):
			return BUBBLE_PALETTES[folder]
	return BUBBLE_PALETTES["shield_bubble"]


## Bağın bittiği nokta: baloncuğun taşa bakan yüzü (baloncuk yoksa göğüs).
static func contact_point(p0: Vector2, target: Node2D) -> Vector2:
	var geo: Array = bubble_geometry(target)
	var c: Vector2 = geo[0]
	var r: float = geo[1]
	var v: Vector2 = p0 - c
	return c + (v.normalized() * r if v.length() > 0.01 else Vector2.ZERO)


func update_link(p0: Vector2, target: Node2D, delta: float) -> void:
	target_ref = target
	_releasing = false
	_t += delta
	var geo: Array = bubble_geometry(target)
	var c: Vector2 = geo[0]
	var r: float = geo[1]
	var v: Vector2 = p0 - c
	var p1: Vector2 = c + (v.normalized() * r if v.length() > 0.01 else Vector2.ZERO)
	var pal: Array = palette_for(target)
	_p0 = p0
	_p1 = p1
	_mat.set_shader_parameter("p0", p0)
	_mat.set_shader_parameter("p1", p1)
	_mat.set_shader_parameter("bub_c", c)
	_mat.set_shader_parameter("bub_r", r)
	_mat.set_shader_parameter("th0", atan2(v.y, v.x))
	_mat.set_shader_parameter("col_outer_b", pal[0])
	_mat.set_shader_parameter("col_inner_b", pal[1])
	_mat.set_shader_parameter("col_hot_b", pal[2])
	var box := Rect2(p0, Vector2.ZERO).expand(p1).expand((p0 + p1) * 0.5 - Vector2(0.0, ARC_H))
	if r > 0.0:
		box = box.merge(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
	box = box.grow(PAD)
	if box != _bbox:
		_bbox = box
		queue_redraw()


## Hedef menzilden çıktı / öldü: kısa sönme, sonra silinir.
func release() -> void:
	_releasing = true


func is_releasing() -> bool:
	return _releasing


func _process(delta: float) -> void:
	if _releasing:
		_t += delta
		_alpha = maxf(0.0, _alpha - delta / FADE_TIME)
		if _alpha <= 0.0:
			queue_free()
			return
	else:
		_alpha = minf(1.0, _alpha + delta / FADE_TIME)
	_mat.set_shader_parameter("time_s", _t)
	_mat.set_shader_parameter("alpha_mult", _alpha)


## Gece ışığı (night_glow_catalog.gd BY_SCRIPT): taştan baloncuğa bağ boyunca.
func get_glow_segment() -> Array:
	return [_p0, _p1]


func _draw() -> void:
	if _bbox.size != Vector2.ZERO:
		draw_rect(_bbox, Color.WHITE)
