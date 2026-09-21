extends Node2D

## Talon'un Hamle Vuruşu (Q): atılış boyunca kırmızı/turuncu pixel-art iz. Üç katman:
##  1) hayalet (afterimage): karakterin o anki karesinin düz turuncu-kırmızı siluetleri, sönerek geride kalır
##  2) alev şeridi: geçtiği yolda sarı->turuncu->kırmızı->koyu kırmızıya soğuyan, incelen pixel kareler
##  3) kor parçacıkları: şeritten savrulan minik pixel kıvılcımlar
## Karakterin (Player) ya da diğer istemcideki kuklanın (RemotePlayer) ÇOCUĞU olarak doğar (player.gd
## _play_and_broadcast_skill_fx) - iki tarafta da aynı kod, konumu parent'ın gerçek hareketinden okur.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const TalonMath := preload("res://scripts/talon_formation_math.gd")

const GHOST_INTERVAL := 0.028
const GHOST_LIFE := 0.4
const STREAK_LIFE := 0.5
const TAIL := 0.32 ## atılış bittikten sonra izin sönme süresi

const GHOST_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.1, 1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""

var _host: Node2D = null
var _t: float = 0.0
var _ghost_timer: float = 0.0
var _samples: Array = [] ## [world_pos, age]
var _ghosts: Array = [] ## [Sprite2D, age]
var _embers: Array = [] ## [world_pos, velocity, age, size]
var _shader: Shader = null


func _ready() -> void:
	top_level = true
	z_index = 0 ## efektif z = oyuncununki (1); negatif z harita altında kalır (bkz. weapon.gd gölge notu)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	_shader = Shader.new()
	_shader.code = GHOST_SHADER_CODE
	if _host != null:
		global_position = Vector2.ZERO
		_add_sample()
		_spawn_ghost()
		## Fırlama anında geriye pixel toz/kıvılcım patlaması.
		for i in range(10):
			_embers.append([_host.global_position, Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0)), 0.0, randi_range(1, 2)])


func _add_sample() -> void:
	_samples.append([_host.global_position + Vector2(0, -6), 0.0])
	if _samples.size() > 40:
		_samples.remove_at(0)


func _spawn_ghost() -> void:
	var anim: AnimatedSprite2D = _host.get("anim") as AnimatedSprite2D
	if anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.top_level = true
	ghost.texture = tex
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = anim.global_scale
	ghost.flip_h = anim.flip_h
	ghost.global_position = anim.global_position
	ghost.offset = anim.offset
	ghost.z_index = 0
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	ghost.material = mat
	add_child(ghost)
	_ghosts.append([ghost, 0.0])


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	var moving: bool = _t < TalonMath.DASH_TIME + 0.05
	if moving:
		_add_sample()
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer += GHOST_INTERVAL
			_spawn_ghost()
		## Şeritten kor savrulur.
		if randf() < 0.9:
			_embers.append([_host.global_position + Vector2(randf_range(-6, 6), randf_range(-4, 12)), Vector2(randf_range(-40, 40), randf_range(-55, -10)), 0.0, randi_range(1, 2)])
	for s in _samples:
		s[1] += delta
	while not _samples.is_empty() and float(_samples[0][1]) > STREAK_LIFE:
		_samples.remove_at(0)
	for e in _embers:
		e[2] += delta
		e[0] += e[1] * delta
		e[1] = e[1] * (1.0 - clampf(3.0 * delta, 0.0, 1.0))
	_embers = _embers.filter(func(e): return float(e[2]) < 0.45)
	var kept: Array = []
	for g in _ghosts:
		g[1] += delta
		var age: float = float(g[1])
		var sprite: Sprite2D = g[0]
		if age >= GHOST_LIFE or not is_instance_valid(sprite):
			if is_instance_valid(sprite):
				sprite.queue_free()
			continue
		## Sıcaktan soğuğa: sarı-turuncu -> kırmızı, sonra kısa süre saydam. Kademeli (dither gibi) alfa.
		## Karakterin hemen üstünde kalan (yeni doğmuş / yavaşlayan) hayaletler gerçek karakteri boyamasın.
		sprite.visible = sprite.global_position.distance_to(_host.get("anim").global_position) > 10.0
		var k: float = age / GHOST_LIFE
		var col: Color = PixelDraw.fire_color(0.15 + k * 0.7)
		var a: float = 0.75 * (1.0 - k)
		a = floorf(a * 4.0 + 0.5) / 4.0 ## 4 kademe: yumuşak geçiş değil, pixel-art "basamaklı" solma
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Color(col.r, col.g, col.b, a))
		kept.append(g)
	_ghosts = kept
	if not moving and _samples.is_empty() and _ghosts.is_empty() and _embers.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var n: int = _samples.size()
	## Alev şeridi: yeniden eskiye; yeni = geniş/sıcak, eski = dar/soğuk. Sadece komşu örnekler arası doldurulur.
	for i in range(n - 1, -1, -1):
		var s: Array = _samples[i]
		var k: float = float(s[1]) / STREAK_LIFE
		var size_texel: int = 6 if k < 0.14 else (5 if k < 0.28 else (4 if k < 0.45 else (3 if k < 0.65 else (2 if k < 0.85 else 1))))
		var col: Color = PixelDraw.fire_color(0.2 + k * 0.8) ## turuncudan başlar (beyaz-sarı sadece çekirdek çizgide)
		var jitter := Vector2(PixelDraw.hash01(int(float(s[1]) * 1000.0) + i * 7) - 0.5, PixelDraw.hash01(i * 13 + 3) - 0.5) * PixelDraw.TEXEL * 2.0 * k
		PixelDraw.px(self, s[0] + jitter, size_texel, col)
		if i < n - 1:
			var nxt: Array = _samples[i + 1]
			PixelDraw.line(self, s[0], nxt[0], col, maxi(size_texel - 1, 1))
	## Sıcak çekirdek çizgisi (en yeni 6 örnek boyunca beyaz-sarı).
	for i in range(maxi(0, n - 6), n - 1):
		PixelDraw.line(self, _samples[i][0], _samples[i + 1][0], Color(1.0, 0.94, 0.62), 2)
	for e in _embers:
		var k2: float = float(e[2]) / 0.45
		PixelDraw.px(self, e[0], int(e[3]) if k2 < 0.6 else 1, PixelDraw.fire_color(0.1 + k2 * 0.8))
