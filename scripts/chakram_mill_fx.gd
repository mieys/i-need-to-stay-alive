extends Node2D

## ÇELİK DEĞİRMEN görseli (madde 591, Seken Çelik finali - scripts/weapon_traits/seken_celik.gd): çakramın döndüğü yerde bıraktığı,
## yerinde testere gibi dönen ÇELİK KOPYASI. Yalnız görsel - hasarı kasterdeki özellik davranışı verir (yerinde tik). Kaster ve diğer
## oyuncular AYNI yoldan kurar: EnchantFx "chakram_mill" (spawn yerelde, broadcast_enchant_area güvenilir kanaldan; CLAUDE.md iki-yer kuralı).
## Katmanlar çakramın kendi sayfaları, aynı sanat ızgarasında (1 piksel = 0,7475 dünya px, uçan çakram ve kafadaki ikonla aynı):
##   mill (dış bıçak halkası + gövdeye sarmal inen buz izi, tools/gen_chakram_fx.py) -> whirl (gövdenin girdabı) -> gövde (RotSprite).
## Kare dönüş açısına göre SEÇİLİR (gövde döndürülmez - piksel ızgarası), uçan çakramla aynı kural. Açılış: küçükten büyüyerek belirir,
## kapanış: son FADE_OUT sn küçülerek söner. Ruh hâli (madde 438): owner_peer alanı -> sahibi menüdeyken donar (Limbo).
const WeaponTierArtScript := preload("res://scripts/weapon_tier_art.gd")
const RotFrames := preload("res://assets/weapons/chakram/spin_frames.tres")
const WhirlFrames := preload("res://assets/fx/chakram/whirl_frames.tres")
const MillFrames := preload("res://assets/fx/chakram/mill_frames.tres")
const ROT_STEPS := 24
const SPIN_DEG := 720.0
const FADE_IN := 0.12
const FADE_OUT := 0.35
## Çelik kopya: gövde hafif soğuk ve az saydam (asıl çakramdan ayırt edilsin, sahnede ikinci bir silah gibi durmasın).
const TINT := Color(0.86, 0.94, 1.0, 0.88)

var duration: float = 2.5
var owner_peer: int = 0
var _t: float = 0.0
var _rot: float = 0.0
var _layers: Array[AnimatedSprite2D] = []


static func spawn(tree: SceneTree, pos: Vector2, data: Dictionary) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var n: Node2D = (load("res://scripts/chakram_mill_fx.gd") as GDScript).new()
	n.set("duration", float(data.get("dur", 2.5)))
	n.set("owner_peer", int(data.get("peer", 0)))
	tree.current_scene.add_child(n)
	n.global_position = pos
	return n


func _ready() -> void:
	name = "ChakramMill"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var px: float = WeaponTierArtScript.WORLD_PX * WeaponTierArtScript.size_mult("boomerang")
	for frames in [MillFrames, WhirlFrames, RotFrames]:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.animation = &"spin"
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * px
		add_child(s)
		_layers.append(s)
	modulate = Color(TINT.r, TINT.g, TINT.b, 0.0)
	_apply(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	_rot += deg_to_rad(SPIN_DEG) * delta
	_apply(delta)


func _apply(_delta: float) -> void:
	var frame: int = int(fposmod(_rot, TAU) / TAU * float(ROT_STEPS)) % ROT_STEPS
	for s in _layers:
		s.frame = frame
	var k: float = 1.0
	var a: float = 1.0
	if _t < FADE_IN:
		var u: float = _t / FADE_IN
		k = lerpf(0.6, 1.0, 1.0 - (1.0 - u) * (1.0 - u))
		a = u
	elif _t > duration - FADE_OUT:
		var v: float = clampf((duration - _t) / FADE_OUT, 0.0, 1.0)
		k = lerpf(0.75, 1.0, v)
		a = v
	scale = Vector2.ONE * k
	modulate.a = TINT.a * a
