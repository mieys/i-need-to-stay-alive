extends Node2D

## Büyücü Kız "Yükseliş" (R1 evrimi, kullanıcı isteği 2026-10-04): "Meteor atışı aktifkenki süre boyunca yukarı doğru uçup hedef
## alınamaz hale gelirsin (karakter havada parıltılı bir biçimde görünür)". Mekanik (hedef alınamaz + hasar işlenmez) player.gd
## is_buyucu_airborne'da; bu düğüm SADECE görünüm. Yerel oyuncu (player.gd _skill_buyucu_meteor) ve uzak kukla (remote_player.gd,
## main.gd extra["byc_fly"]) AYNI script - CLAUDE.md "iki ayrı yer" hata sınıfı: ensure() ile kurulur, sonra her karede
## host.is_buyucu_airborne()'u sorar:
##  - gövde (AnimatedSprite2D offset'i, karakterin kendi sanat pikseli adımlarıyla - Hadime Q süzülmesindeki gibi) yükselir ve
##    havada hafifçe salınır; ayak gölgesi yerde kalıp küçülür ve solar (yükseklik hissi),
##  - gövdenin çevresinde parıltılar + ayağının altında havada dönen rün halkası (sayfa tools/gen_evolution_fx.py buyucu_levitate),
##  - gövde parlaklığı nabız gibi artar (anim.self_modulate - main.gd'nin gönderdiği "modulate"a GİRMEZ, ağ trafiği oluşturmaz).
## Bayrak düşünce (kanal bitti / öldü) iner, taban ofset/gölge/parlaklık geri yüklenir ve düğüm kendini siler.

const SELF_PATH := "res://scripts/buyucu_levitate.gd"
const NODE_NAME := "BuyucuLevitate"
const FRAMES_PATH := "res://assets/fx/evolution/buyucu_levitate_frames.tres"
const TEXEL := 1.212 ## karaktere bağlı evrim sayfaları: 1 sanat pikseli = 1.212 yerel birim (gen_evolution_fx.py başı)
const LIFT_ART_PX := 14.0 ## karakterin KENDİ sanat pikseli (anim.offset birimi)
const BOB_ART_PX := 1.0
const BOB_SPEED := 2.6
const RISE_TIME := 0.35
const LAND_TIME := 0.3
const SHADOW_MIN_SCALE := 0.7
const SHADOW_MIN_ALPHA_MULT := 0.55
const GLOW_PEAK := Color(1.3, 1.25, 1.15)
const GLOW_SPEED := 5.0
## Parıltı sayfasının merkezinin, yükselmemiş gövdeye göre yeri (kök yerel birimi): sayfa merkezi gövdenin ortasında.
const SPARKLE_LOCAL := Vector2(0.0, -4.0)

static var _frames: SpriteFrames = null

var host: Node2D = null
var _anim: AnimatedSprite2D = null
var _shadow: Node2D = null
var _base_offset: Vector2 = Vector2.ZERO
var _base_self_modulate: Color = Color.WHITE
var _shadow_scale: Vector2 = Vector2.ONE
var _shadow_alpha: float = 1.0
var _h: float = 0.0 ## 0..1 yükseklik ilerlemesi
var _t: float = 0.0
var _sparkle: AnimatedSprite2D = null
var _restored: bool = false


## Yoksa kurar (iniş sürerken yeniden havalanırsa mevcut düğüm tekrar yükselir - ikinci kopya açılmaz).
static func ensure(p_host: Node2D, p_anim: AnimatedSprite2D, p_shadow: Node2D) -> void:
	if p_host == null or not is_instance_valid(p_host) or p_anim == null or not is_instance_valid(p_anim):
		return
	var existing: Node = p_host.get_node_or_null(NODE_NAME)
	if existing != null and not existing.is_queued_for_deletion():
		return
	var n: Node2D = (load(SELF_PATH) as GDScript).new()
	n.name = NODE_NAME
	n.call("_setup", p_host, p_anim, p_shadow)
	p_host.add_child(n)


func _setup(p_host: Node2D, p_anim: AnimatedSprite2D, p_shadow: Node2D) -> void:
	host = p_host
	_anim = p_anim
	_shadow = p_shadow if (p_shadow != null and is_instance_valid(p_shadow)) else null
	_base_offset = _anim.offset
	_base_self_modulate = _anim.self_modulate
	if _shadow != null:
		_shadow_scale = _shadow.scale
		_shadow_alpha = _shadow.modulate.a
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _frames == null and ResourceLoader.exists(FRAMES_PATH):
		_frames = load(FRAMES_PATH) as SpriteFrames
	if _frames != null:
		_sparkle = AnimatedSprite2D.new()
		_sparkle.sprite_frames = _frames
		_sparkle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sparkle.scale = Vector2.ONE * TEXEL
		_sparkle.modulate.a = 0.0
		add_child(_sparkle)
		if _frames.has_animation(&"loop"):
			_sparkle.play(&"loop")


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host) or _anim == null or not is_instance_valid(_anim):
		queue_free()
		return
	var want: bool = host.has_method("is_buyucu_airborne") and bool(host.call("is_buyucu_airborne"))
	if want:
		_h = minf(1.0, _h + delta / RISE_TIME)
	else:
		_h = maxf(0.0, _h - delta / LAND_TIME)
	_t += delta
	var e: float = _h * _h * (3.0 - 2.0 * _h) ## smoothstep - kalkış ve iniş yumuşak, yarıda dönerse sıçramaz
	## Sanat pikseline yuvarlanır (gövde alt-piksel kaymasın - Hadime süzülmesiyle aynı kural).
	var lift: float = roundf(LIFT_ART_PX * e + sin(_t * BOB_SPEED) * BOB_ART_PX * e)
	_anim.offset = _base_offset + Vector2(0.0, -lift)
	var glow_k: float = e * (0.5 + 0.5 * sin(_t * GLOW_SPEED))
	var glow: Color = _base_self_modulate * Color.WHITE.lerp(GLOW_PEAK, glow_k)
	glow.a = _base_self_modulate.a
	_anim.self_modulate = glow
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.scale = _shadow_scale * lerpf(1.0, SHADOW_MIN_SCALE, e)
		_shadow.modulate.a = _shadow_alpha * lerpf(1.0, SHADOW_MIN_ALPHA_MULT, e)
	if _sparkle != null:
		_sparkle.position = _anim.position + SPARKLE_LOCAL + Vector2(0.0, -lift * absf(_anim.scale.y))
		_sparkle.modulate.a = e
	if not want and _h <= 0.0:
		_restore()
		queue_free()


func _restore() -> void:
	if _restored:
		return
	_restored = true
	if _anim != null and is_instance_valid(_anim):
		_anim.offset = _base_offset
		_anim.self_modulate = _base_self_modulate
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.scale = _shadow_scale
		_shadow.modulate.a = _shadow_alpha


func _exit_tree() -> void:
	_restore()
