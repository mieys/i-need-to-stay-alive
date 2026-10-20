extends Node2D
class_name FearEmote

## KORKU BALONU (madde 313): açılıştaki depremde oyuncuların / babaannenin, ev saldırı altındayken babaannenin üstünde çıkan küçük piksel
## balon (assets/fx/ev_kusatma/korku.png, tools/gen_ev_kusatma_fx.py): 0 korkmuş yüz, 1 ünlem, 2 ter damlaları.
## Karakterin KÖKÜNE çocuk olarak eklenir (oyuncu/kukla/NPC kökü 0,5 ölçekli) -> sprite ölçeği karakter sprite'ıyla aynı, balonun pikseli
## karakterin pikseliyle aynı boyda. Yerel/kozmetik: her peer kendisi çağırır (house_intro.gd seçimi peer kimliğinden, herkes aynı seçer).

const TEX: Texture2D = preload("res://assets/fx/ev_kusatma/korku.png")
const CELL := 16
const KIND_FACE := 0
const KIND_ALERT := 1
const KIND_SWEAT := 2
const NODE_NAME := &"FearEmote"
const Y_LOCAL := -64.0 ## kök yereli (0,5 ölçek): baloncuğun ortası başın ~5 dünya px üstünde
const POP_TIME := 0.16

var _sprite: Sprite2D = null
var _life: float = 0.0
var _delay: float = 0.0
var _t: float = 0.0
var _y: float = Y_LOCAL


## Hedefin üstünde balon (varsa eskisinin yerine). delay: kalabalıkta hepsi aynı anda patlamasın.
static func show_on(target: Node2D, kind: int, duration: float = 2.6, delay: float = 0.0, raise: float = 0.0) -> FearEmote:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return null
	var old: Node = target.get_node_or_null(NodePath(String(NODE_NAME)))
	if old != null:
		old.free()
	var e := FearEmote.new()
	e.name = NODE_NAME
	e._life = duration
	e._delay = delay
	e._y = Y_LOCAL + raise
	e._build(kind)
	target.add_child(e)
	return e


## Açılışta "bazılarının" üstünde: peer kimliğinden kararlı seçim (3'te 2) - her peer aynı oyuncular için çıkarır.
static func picks_peer(peer_id: int) -> bool:
	return posmod(peer_id * 7 + 3, 3) != 0


static func kind_for(peer_id: int) -> int:
	return [KIND_FACE, KIND_SWEAT, KIND_ALERT][posmod(peer_id * 5 + 1, 3)]


func _build(kind: int) -> void:
	z_index = 40
	z_as_relative = false
	position = Vector2(0.0, _y)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(clampi(kind, 0, 2) * CELL, 0, CELL, CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * NpcActor.BASE_SPRITE_SCALE * EntityScale.SIZE
	_sprite.offset = Vector2(0.0, -CELL * 0.5 + 2.0) ## kuyruk ucu düğümün noktasına yakın
	add_child(_sprite)
	scale = Vector2.ZERO
	visible = false


func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		return
	visible = true
	_t += delta
	## piksel tarzı: balon iki adımda belirir (yarım -> taşma -> tam), yumuşak ölçek animasyonu yok
	if _t < POP_TIME * 0.5:
		scale = Vector2.ONE * 0.6
	elif _t < POP_TIME:
		scale = Vector2.ONE * 1.15
	else:
		scale = Vector2.ONE
	## hafif zıplama (tam piksel adımlarıyla)
	position.y = _y - (2.0 if fmod(_t, 0.6) < 0.3 else 0.0)
	if _t >= _life:
		modulate.a = maxf(0.0, 1.0 - (_t - _life) / 0.3)
		if _t >= _life + 0.3:
			queue_free()
