extends Node

## Matthew pasifi "Yıldırım Hızı"nın izi (madde 98): sahibi yürüdükçe arkasında, her TRAIL_STEP yolda bir "damga" bırakır; damga
## 1 sn boyunca 8 evrede incelip kıvılcıma dönerek söner (assets/fx/matthew_lightning/trail.png, güçlenmiş: trail_max.png).
## Sahibin (Player ya da RemotePlayer) çocuğudur; damgalar DÜNYAYA (current_scene) eklenir - Matthew ilerlerken iz yerinde kalır.
## Kaster de kukla da kendi kopyasını AYNI betikle kurar: seviye (0 yok / 1 normal / 2 güçlenmiş) kasterde hız birikiminden,
## kuklada main.gd extra["mt"]'den gelir; damga yerleri iki tarafta da sahibin kendi hareketinden çıkar.
## Güçlenmiş izin VURUŞU burada değil (player.gd _matthew_trail_scan) - bu düğüm sadece `points` listesini (canlı güçlenmiş iz
## noktaları) tutar; kukla tarafında liste okunmaz.

const ML := preload("res://scripts/matthew_lightning.gd")
const NightGlowScript := preload("res://scripts/night_glow.gd")

var level: int = 0 ## 0 kapalı, 1 normal, 2 güçlenmiş
var intensity: float = 1.0 ## 0..1 hız birikimi / tavan - normal izin görünürlüğü (hız arttıkça iz belirginleşir)
var points: Array = [] ## güçlenmiş damga noktaları: [[Vector2 konum, float doğum_sn], ...]

var _stamps: Array = [] ## [[Sprite2D, float doğum_sn, int varyant, int son_evre], ...]
var _has_last: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _count: int = 0
var _clock: float = 0.0


func _process(delta: float) -> void:
	_clock += delta
	_age_stamps()
	var owner_node: Node2D = get_parent() as Node2D
	if owner_node == null:
		return
	var pos: Vector2 = owner_node.global_position + ML.TRAIL_OFFSET * owner_node.global_scale
	if level <= 0:
		_has_last = false
		return
	if not _has_last:
		_has_last = true
		_last_pos = pos
		return
	var gap: float = _last_pos.distance_to(pos)
	if gap > ML.TRAIL_STEP * 6.0: ## ışınlanma / uzak sıçrama: araya iz çekme
		_last_pos = pos
		return
	var guard: int = 0
	while gap >= ML.TRAIL_STEP and guard < 6:
		guard += 1
		var dir: Vector2 = (pos - _last_pos) / gap
		var next: Vector2 = _last_pos + dir * ML.TRAIL_STEP
		## Damga yarım karo İLERİ kaydırılır: ön yarısı gövdenin altında kalır, bir sonraki damgaya kadar arkada boşluk açılmaz
		## (oyuncu hızı ~82-110 birim/sn: karo başına ~0,2 sn - kaydırmasız iz gövdeden kopuk görünürdü).
		_spawn_stamp((_last_pos + next) * 0.5 + dir * (ML.TRAIL_STEP * 0.5), dir)
		_last_pos = next
		gap -= ML.TRAIL_STEP


func _spawn_stamp(at: Vector2, dir: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	var strong: bool = level >= 2
	var tex: Texture2D = ML.sheet_texture("trail_max" if strong else "trail")
	if scene == null or tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = tex
	spr.region_enabled = true
	var variant: int = _count % ML.TRAIL_VARIANTS
	_count += 1
	spr.region_rect = Rect2(0.0, float(variant) * ML.TRAIL_TILE.y, ML.TRAIL_TILE.x, ML.TRAIL_TILE.y)
	spr.scale = Vector2.ONE * ML.WORLD_TEXEL ## dünyada duran efekt: Matthew'in piksel boyu (bkz. matthew_lightning.gd ÖLÇEK notu)
	spr.rotation = dir.angle()
	spr.z_index = 0 ## yerde: oyuncuların (z 1) altında
	if not strong:
		spr.modulate.a = lerpf(0.6, 1.0, clampf(intensity, 0.0, 1.0))
	scene.add_child(spr)
	spr.global_position = at
	## Gece ışığı (2026-10-13, kullanıcı: "yıldırım izi karanlıkta parıldamalı"): damga sahnesiz Sprite2D olduğu için katalog
	## takmaz - her damgaya, damganın ömrü (1 sn) boyunca doğrusal sönen bir ışık takılır. Güçlenmiş iz daha parlak/beyazımsı.
	NightGlowScript.attach(spr, {
		"color": Color(1.0, 0.93, 0.55) if strong else Color(1.0, 0.86, 0.3),
		"radius": 26.0,
		"energy": 0.65 if strong else lerpf(0.35, 0.5, clampf(intensity, 0.0, 1.0)),
		"flicker": 0.2,
		"decay": ML.TRAIL_LIFE,
	})
	_stamps.append([spr, _clock, variant, 0])
	if strong:
		points.append([at, _clock])


func _age_stamps() -> void:
	var i: int = 0
	while i < _stamps.size():
		var st: Array = _stamps[i]
		var spr: Sprite2D = st[0]
		var age: float = _clock - float(st[1])
		if age >= ML.TRAIL_LIFE or not is_instance_valid(spr):
			if is_instance_valid(spr):
				spr.queue_free()
			_stamps.remove_at(i)
			continue
		var stage: int = mini(ML.TRAIL_STAGES - 1, int(age / ML.TRAIL_LIFE * float(ML.TRAIL_STAGES)))
		if stage != int(st[3]):
			st[3] = stage
			spr.region_rect = Rect2(float(stage) * ML.TRAIL_TILE.x, float(st[2]) * ML.TRAIL_TILE.y, ML.TRAIL_TILE.x, ML.TRAIL_TILE.y)
		i += 1
	while not points.is_empty() and _clock - float(points[0][1]) >= ML.TRAIL_LIFE:
		points.pop_front()


## Canlı güçlenmiş iz noktalarının konumları (player.gd vuruş taraması).
func live_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in points:
		out.append(p[0])
	return out


func _exit_tree() -> void:
	for st: Array in _stamps:
		if is_instance_valid(st[0]):
			(st[0] as Node).queue_free()
	_stamps.clear()
	points.clear()
