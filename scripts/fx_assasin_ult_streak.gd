extends Node2D

## Assasin Çocuk ULTİ (Gölge Hücumu) - TEK bir sıçrayışın yolu (kurulum: scripts/assasin_ult_fx.gd spawn_step).
##  - Işık çizgisi: ult_streak karoları TAM karo genişliği aralıkla dizilir (sayfa x'te 16 px periyodik -> dikişsiz), ilk
##    karo kuyruk ucu (ult_streak_cap, sivri), son karo onun yatay aynası (baş). Her karo sıçrayış onun üstünden geçtiği an
##    belirir (kuyruktan başa "fermuar"), HOLD kadar tam parlak kalır, sonra 6 kareyle söner - baş en son söner.
##  - Hayaletler: yol boyunca GHOST_FRACS noktalarında, sıçrayış oradan geçtiği an mor silüet (shaders/assasin_ghost.gdshader).
##    Kare: gidiş yönündeki atılma pozu dash_<yön> (kullanıcı isteği 2026-10-16: "sabit durmasın, koşarkenki atılmaya benzer
##    framelerden biri olsun gittiği yöne doğru, o şekilde görünsün gölgesi" - CharAnim.DASH_POSE_*); klip yoksa o anki kare.
##    Hepsi TAM DOLU başlar, GHOST_HOLDS kadar dolu kalır (kuyruktaki en kısa) ve Bayer deseniyle piksel piksel dağılır.
## Düğüm dünya konumunda `from`'da durur, rotation = sıçrayış açısı (+x = yön). Hayaletler döndürülmez (sahneye eklenir).

const TEXEL := 1.212
const BODY_TEX: Texture2D = preload("res://assets/fx/assasin/ult_streak_sheet.png")
const CAP_TEX: Texture2D = preload("res://assets/fx/assasin/ult_streak_cap_sheet.png")
const FRAMES := 6
const VARIANTS := 3 ## gövde sayfasının satırları: hız çizgisi varyantları (tools/gen_assasin_ult_fx.py FLECKS)
const FPS := 30.0
const HOLD := 0.05
## Karonun yarısından kısa sıçrayışta çizgi çizilmez (yan yana duran iki yaratık) - sadece hayalet.
const MIN_TILE_FRACTION := 0.75

const CharAnim := preload("res://scripts/char_anim.gd")
const GHOST_SHADER: Shader = preload("res://shaders/assasin_ghost.gdshader")
const GHOST_FRACS: Array[float] = [0.2, 0.46, 0.72]
## Dolu bekleme süreleri (kuyruk -> baş). Yarı alfayla başlatmak (ilk deneme 0,5/0,7/0,9) oyunda silüet değil dama deseni gibi
## okundu (Bayer %50 = dama): hepsi tam dolu başlar, kademeyi dağılma sırası verir.
const GHOST_HOLDS: Array[float] = [0.03, 0.06, 0.09]
const GHOST_FADE := 0.16

static var _ghost_mat: ShaderMaterial = null

var _tiles: Array[Sprite2D] = []
var _tile_at: PackedFloat32Array = PackedFloat32Array()
var _tile_row: PackedInt32Array = PackedInt32Array()
var _t: float = 0.0
var _sweep: float = 0.09
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _ghost_src: AnimatedSprite2D = null
var _ghost_tex: Texture2D = null ## atılma pozunun karesi (setup'ta bir kez; yoksa _spawn_ghost o anki kareyi alır)
var _ghost_rel: Vector2 = Vector2.ZERO
var _ghost_z: int = 0
var _ghost_next: int = 0


## Sahneye eklendikten SONRA çağrılır. body: sıçrayan oyuncu (yerel Player ya da uzak kukla) - hayaletin karesi onun
## "AnimatedSprite2D"inden okunur; yoksa hayalet çizilmez.
func setup(from: Vector2, to: Vector2, sweep_time: float, body: Node2D) -> void:
	_from = from
	_to = to
	global_position = from
	var seg: Vector2 = to - from
	var length: float = seg.length()
	rotation = seg.angle()
	_sweep = maxf(0.02, sweep_time)
	if body != null and is_instance_valid(body):
		_ghost_src = body.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _ghost_src != null:
			_ghost_rel = _ghost_src.global_position - body.global_position
			var pose := StringName(CharAnim.DASH_POSE_PREFIX + CharAnim.dir_from_vector(seg))
			if _ghost_src.sprite_frames != null and _ghost_src.sprite_frames.has_animation(pose):
				_ghost_tex = _ghost_src.sprite_frames.get_frame_texture(pose, 0)
		_ghost_z = body.z_index
	var tile_w: float = float(BODY_TEX.get_width()) / FRAMES * TEXEL
	if length < tile_w * MIN_TILE_FRACTION:
		return
	var n: int = maxi(1, int(round(length / tile_w)))
	var start_x: float = (length - tile_w * n) * 0.5
	var row_seed: int = int(absf(from.x) + absf(from.y) * 3.0)
	for i in range(n):
		var is_cap: bool = n > 1 and (i == 0 or i == n - 1)
		var spr := Sprite2D.new()
		spr.texture = CAP_TEX if is_cap else BODY_TEX
		spr.hframes = FRAMES
		spr.vframes = 1 if is_cap else VARIANTS
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2.ONE * TEXEL
		spr.position = Vector2(start_x + tile_w * (float(i) + 0.5), 0.0)
		spr.flip_h = is_cap and i == n - 1
		spr.visible = false
		add_child(spr)
		_tiles.append(spr)
		_tile_at.append(_sweep * (float(i) + 0.5) / float(n))
		_tile_row.append(0 if is_cap else (row_seed + i * 7) % VARIANTS)


func _process(delta: float) -> void:
	_t += delta
	var alive: bool = false
	for i in range(_tiles.size()):
		var spr: Sprite2D = _tiles[i]
		var age: float = _t - _tile_at[i]
		if age < 0.0:
			alive = true
			continue
		var f: int = 0 if age < HOLD else 1 + int((age - HOLD) * FPS)
		if f >= FRAMES:
			spr.visible = false
			continue
		spr.frame_coords = Vector2i(f, _tile_row[i])
		spr.visible = true
		alive = true
	while _ghost_next < GHOST_FRACS.size() and _t >= GHOST_FRACS[_ghost_next] * _sweep:
		_spawn_ghost(GHOST_FRACS[_ghost_next], GHOST_HOLDS[_ghost_next])
		_ghost_next += 1
	if _ghost_next < GHOST_FRACS.size():
		alive = true
	if not alive:
		queue_free()


func _spawn_ghost(frac: float, hold: float) -> void:
	var src: AnimatedSprite2D = _ghost_src
	if src == null or not is_instance_valid(src) or src.sprite_frames == null:
		return
	var tex: Texture2D = _ghost_tex
	if tex == null and src.sprite_frames.has_animation(src.animation):
		tex = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if tex == null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	if _ghost_mat == null:
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = GHOST_SHADER
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.centered = src.centered
	ghost.offset = src.offset
	ghost.flip_h = src.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.material = _ghost_mat
	ghost.z_index = _ghost_z
	ghost.modulate = Color.WHITE ## alfa = shader'daki dağılma eşiği
	parent.add_child(ghost)
	ghost.global_position = _from.lerp(_to, frac) + _ghost_rel
	ghost.global_scale = src.global_scale
	var fade := ghost.create_tween()
	fade.tween_interval(hold)
	fade.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	fade.tween_callback(ghost.queue_free)
