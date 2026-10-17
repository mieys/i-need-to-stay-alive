extends Node2D

## Melek Q (Can Basma) / E (Kalkan Yenileme): bağ sürerken Melek'in KENDİ halesi bağın rengine bürünür (Q yeşil, E mavi; kullanıcı:
## "bağ kafasının üstündeki melek halkasında olsun ordan gidiyormuş gibi olsun"), kendi tiklerinde parlar ve göğsünden yeşil artı /
## mana kristali yükselir (Q'da kuruluşta büyük artı = anlık %15). Madde 212; bağın kendisi dostta (melek_bond_fx.gd).
## Hale boyama: karakterin O ANKİ karesinin kopyası + shaders/melek_halo_tint.gdshader (sadece hale pikselleri; hale büyümez).
## Ağ: Melek'in istemcisinde player.gd _play_and_broadcast_skill_fx(FxMelekHaloScene, {"aura_type": ...}); uzak kopya "skill_scene"
## ile aynı props'la doğar ve kendini kuklanın _ally_aura_fx sözlüğüne yazar (fx_recovery_aura.gd deseni) - erken bitişte
## broadcast_ally_aura_stop -> stop_ally_aura_fx -> stop_aura() iki tarafta da çalışır.

const BondMath := preload("res://scripts/melek_bond_math.gd")
const TINT_SHADER: Shader = preload("res://shaders/melek_halo_tint.gdshader")
const GLYPH_TEX: Texture2D = preload("res://assets/fx/melek_bond/glyphs.png")
const GLYPH_N := 11
const GLYPH_LIFE := 8.0 / BondMath.PROTO_FPS
## Melek'in göğsü (artı/kristal), kare merkezine göre sanat pikseli (prototip mx-1, feet-22).
const CHEST := Vector2(-0.5, -5.5)
const TICK_INTERVAL := 1.0

## "heal" / "shield" - _ally_aura_fx anahtarı (props ile kurulur).
@export var aura_type: String = "heal"
## Güvenlik ağı (yetenek 6 sn; durdurma kaybolursa uzak kopya sonsuza dek kalmasın).
@export var max_lifetime: float = 7.5
## Gece ışığı rengi (night_glow_catalog.gd "cp") - Q yeşil, E mavi.
var glow_color: Color:
	get:
		return BondMath.palette(aura_type)[3]

var _age: float = 0.0
var _stopping: bool = false
var _sprite: AnimatedSprite2D = null
var _copy: Sprite2D = null
var _mat: ShaderMaterial = null
var _bright: int = -1
var _last_tick: float = 0.0
var _next_tick: float = TICK_INTERVAL
var _glyphs: Array = [] ## [Sprite2D, doğuş _age, glif türü]


func _ready() -> void:
	if aura_type != "":
		var host: Node = get_parent()
		if host != null and "_ally_aura_fx" in host:
			var registry: Dictionary = host.get("_ally_aura_fx")
			if not (registry.has(aura_type) and is_instance_valid(registry[aura_type])):
				registry[aura_type] = self
	_sprite = get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D if get_parent() != null else null
	_mat = ShaderMaterial.new()
	_mat.shader = TINT_SHADER
	_copy = Sprite2D.new()
	_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_copy.material = _mat
	add_child(_copy)
	_set_bright(true)
	_sync_copy()
	var snd: AudioStreamPlayer2D = get_node_or_null("Sound") as AudioStreamPlayer2D
	if snd != null:
		snd.pitch_scale = randf_range(0.95, 1.05)
		snd.play()
	## kuruluş: Q anlık can (büyük artı), E'nin ilk tiki kuruluşla aynı anda (kristal)
	_spawn_glyph("plus_big" if aura_type == "heal" else "crystal")


func stop_aura() -> void:
	_stopping = true
	if _copy != null:
		_copy.visible = false


func is_tinting() -> bool:
	return _copy != null and _copy.visible and not _stopping


func is_bright() -> bool:
	return _bright == 1


func glyph_count() -> int:
	return _glyphs.size()


func _set_bright(on: bool) -> void:
	var b: int = 1 if on else 0
	if b == _bright:
		return
	_bright = b
	var pal: Array = BondMath.palette(aura_type)
	_mat.set_shader_parameter("ring_col", pal[4] if on else pal[3])
	_mat.set_shader_parameter("edge_col", pal[2] if on else pal[1])


func _process(delta: float) -> void:
	_age += delta
	var body: Node = get_parent()
	if not _stopping and (_age >= max_lifetime or (body != null and body.get("is_dead") == true)):
		stop_aura()
	if not _stopping:
		while _age >= _next_tick:
			_last_tick = _next_tick
			_next_tick += TICK_INTERVAL
			_spawn_glyph("plus" if aura_type == "heal" else "crystal")
		_set_bright(_age < BondMath.BRIGHT_TIME or (_last_tick > 0.0 and _age - _last_tick < BondMath.BRIGHT_TIME))
		_sync_copy()
	_update_glyphs()
	if _stopping and _glyphs.is_empty():
		queue_free()


func _sync_copy() -> void:
	if _copy == null:
		return
	var s: AnimatedSprite2D = _sprite
	if s == null or not is_instance_valid(s) or s.sprite_frames == null or not s.sprite_frames.has_animation(s.animation):
		_copy.texture = null
		return
	_copy.texture = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	_copy.position = s.position
	_copy.rotation = s.rotation
	_copy.scale = s.scale
	_copy.offset = s.offset
	_copy.centered = s.centered
	_copy.flip_h = s.flip_h
	_copy.flip_v = s.flip_v
	_copy.z_index = s.z_index
	_copy.visible = s.visible and not _stopping


func _spawn_glyph(glyph: String) -> void:
	var g := Sprite2D.new()
	g.texture = GLYPH_TEX
	g.hframes = GLYPH_N
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = 60
	add_child(g)
	_glyphs.append([g, _age, glyph])
	_update_glyphs()


func _update_glyphs() -> void:
	var sc := Vector2.ONE
	var base := Vector2.ZERO
	if _sprite != null and is_instance_valid(_sprite):
		sc = _sprite.scale.abs()
		base = _sprite.position + (_sprite.offset + CHEST) * _sprite.scale
	for i in range(_glyphs.size() - 1, -1, -1):
		var e: Array = _glyphs[i]
		var g: Sprite2D = e[0]
		var age: float = _age - float(e[1])
		if age >= GLYPH_LIFE or not is_instance_valid(g):
			if is_instance_valid(g):
				g.queue_free()
			_glyphs.remove_at(i)
			continue
		var k: int = int(age * BondMath.PROTO_FPS)
		g.frame = BondMath.glyph_frame(e[2], k)
		g.scale = sc
		g.position = base + Vector2(0.0, -float(k) * (1.2 if e[2] == "crystal" else 1.3)) * sc
