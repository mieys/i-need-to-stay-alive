extends Node2D
class_name AssasinDashFx

## Assasin Çocuk'un yeni ULTİ'si (Gölge Hücumu) aktifken oyuncuya eklenen
## "piksel tarzı" (retro, ızgaraya oturan/chunky) mor renkli hızlı savrulma
## izi - bkz. player.gd _skill_assasin_dash/_assasin_dash_direction. Diğer
## tüm FX'lerin aksine (fx_kurtadam_rage.gd, fx_assasin_stealth.gd gibi)
## sabit bir "duration" ile kendi kendine kapanmaz - oyuncu bu süre boyunca
## SÜREKLİ hareket ettiği için hedefe göre değişken uzunlukta sürer, bu
## yüzden player.gd hücum bitince stop() çağırır (bkz. _end_skill_effects).
## Sürerken her karede oyuncunun o anki global konumunda küçük, ızgaraya
## oturan (piksel) kareler bırakır - bunlar bu node'a (oyuncuya) bağlı
## OLMADAN dünya konumunda sabit kalıp hızla solar, böylece arkada gerçek
## bir "hızlı geçiş" izi hissi bırakır.

var color_main: Color = Color(0.55, 0.15, 0.85) # koyu mor
var color_bright: Color = Color(0.85, 0.65, 1.0) # parlak leylak
const PIXEL_GRID := 4.0
const SPAWN_INTERVAL := 0.012
const SAFETY_DURATION := 6.0 ## player.gd stop() çağırmazsa (ör. uzak client kopyası) diye güvenlik tavanı

var elapsed: float = 0.0
var _stopping: bool = false
var _spawn_accum: float = 0.0
var _trail: Array[Dictionary] = [] # {sprite, life, max_life}
var _afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL := 0.035
const AFTERIMAGE_LIFETIME := 0.24

@onready var _sound: AudioStreamPlayer2D = get_node_or_null("Sound")


func _ready() -> void:
	position = Vector2.ZERO
	if _sound:
		_sound.pitch_scale = randf_range(0.9, 1.1)
		_sound.play()


## player.gd, hücum tamamlandığında (hedef kalmayınca) çağırır - artık yeni
## piksel yaymayı durdurur, mevcut izin kendi kendine sönmesini bekleyip
## sonra queue_free() eder.
func stop() -> void:
	_stopping = true


## Bir yaratığa çarpılınca player.gd tarafından çağrılır - vuruş anında
## çarpma noktasında ekstra parlak bir piksel patlaması bırakır.
func hit_flash() -> void:
	# Hit bursts are handled by the dedicated shadow-slash scene.
	return


func _spawn_shadow_afterimage() -> void:
	var player_node: Node = get_parent()
	if not player_node:
		return
	var player_sprite: AnimatedSprite2D = player_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not player_sprite or not player_sprite.sprite_frames:
		return
	var ghost_texture: Texture2D = player_sprite.sprite_frames.get_frame_texture(player_sprite.animation, player_sprite.frame)
	if not ghost_texture or not get_tree().current_scene:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = ghost_texture
	ghost.global_position = player_sprite.global_position
	ghost.global_rotation = player_sprite.global_rotation
	ghost.global_scale = player_sprite.global_scale
	ghost.flip_h = player_sprite.flip_h
	ghost.flip_v = player_sprite.flip_v
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keep it above the map but below the live player sprite.
	ghost.z_index = player_node.z_index
	ghost.modulate = Color(0.12, 0.04, 0.22, 0.62)
	get_tree().current_scene.add_child(ghost)
	var fade: Tween = ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	fade.tween_callback(ghost.queue_free)


func _process(delta: float) -> void:
	elapsed += delta
	if not _stopping:
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = AFTERIMAGE_INTERVAL
			_spawn_shadow_afterimage()

	var active: Array[Dictionary] = []
	for p in _trail:
		p.life += delta
		var ghost: Sprite2D = p.sprite as Sprite2D
		if is_instance_valid(ghost):
			ghost.modulate.a = (1.0 - p.life / p.max_life) * 0.62
		if p.life < p.max_life:
			active.append(p)
	_trail = active

	if (_stopping and _trail.is_empty()) or elapsed >= SAFETY_DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for p in _trail:
		var t: float = p.life / p.max_life
		var col: Color = color_bright if p.bright else color_main
		col.a = (1.0 - t) * 0.9
		var local_pos: Vector2 = p.gpos - global_position
		## Retro/piksel hissi için konumu kaba bir ızgaraya oturtuyoruz.
		var snapped := Vector2(
			round(local_pos.x / PIXEL_GRID) * PIXEL_GRID,
			round(local_pos.y / PIXEL_GRID) * PIXEL_GRID
		)
		var half: float = p.size * (1.0 - t * 0.35) * 0.5
		draw_rect(Rect2(snapped - Vector2(half, half), Vector2(half, half) * 2.0), col)
