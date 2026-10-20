extends Sprite2D

## Lich "Ruh Alevi" isabeti (madde 280): yukarı kıvrılan turkuaz alev dilleri + merkez parlama + yere yayılan kesik halka, pişmiş sayfa
## (tools/gen_lich_ruh_alevi.py, 25 fps). fx_enemy_bolt_impact.gd'nin lich karşılığı - aynı MAX_ALIVE bütçesi (aynı anda çok isabet
## oyuncunun üstünde tek parlama gibi görünür, fazlası atlanır). `color` gece ışığı içindir (night_glow_catalog BY_SCRIPT "cp").

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const LichFlame := preload("res://scripts/lich_soul_flame.gd")
const SHEET: Texture2D = preload("res://assets/fx/lich/ruh_alevi_isabet.png")
const SHEET_SMALL: Texture2D = preload("res://assets/fx/lich/ruh_alevi_isabet_kucuk.png")
const NF := 9
const NF_SMALL := 7
const FPS := 25.0
const MAX_ALIVE := 16

static var _alive: int = 0

## Normal atışın (STYLE_SMALL) küçük isabeti.
var small: bool = false
var color: Color = LichFlame.TINT
var _t: float = 0.0
var _nf: int = NF
var _counted: bool = false


func _ready() -> void:
	if _alive >= MAX_ALIVE:
		queue_free()
		return
	_alive += 1
	_counted = true
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = SHEET_SMALL if small else SHEET
	_nf = NF_SMALL if small else NF
	hframes = _nf
	frame = 0
	scale = Vector2(PixelDraw.TEXEL, PixelDraw.TEXEL)


func _exit_tree() -> void:
	if _counted:
		_alive -= 1
		_counted = false


func _process(delta: float) -> void:
	_t += delta
	var f: int = int(_t * FPS)
	if f >= _nf:
		queue_free()
		return
	if f != frame:
		frame = f
