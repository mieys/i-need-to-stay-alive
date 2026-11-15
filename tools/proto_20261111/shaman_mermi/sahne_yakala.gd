extends SceneTree

## Shaman Q ateş topu / E kalkan gönderme PROTOTİPLERİ için gerçek çizicide sahne (madde 562, oyuna bağlı DEĞİL).
## Shaman ortada, solda Q rün taşı + hedef yaratık, sağda E rün taşı + müttefik Elara (RemotePlayer kuklası). Karakter/yaratık
## animasyonları DURAKLATILIR (silüet sabit, maske tek kare), taşların rün döngüsü işler.
## SM_MODE=bos  : taşların sahibi yok -> efekt yok (prototip efektleri Python'da bunun üstüne çizilir) + meta.json + maskeler
## SM_MODE=suan : bugünkü oyun efektleri (ağ kopyası kipi: gerçek ateş topu + kalkan dalgası)
## SM_MODE=tas : bos gibi ama rün taşlarının RÜNLERİ ve parıltısı gizli (rün prototipleri Python'da çizilir, madde 568) + meta'ya taş konumu/ölçeği
## SM_MODE=yeni : OYUNA ALINAN hâl (madde 567) - gerçek efekt kodu (ağ kopyası kipi) + iki baloncuk açık
## SM_MODE=kalkan : bos gibi + iki karakterin KENDİ kalkan yenilenme baloncuğu açık (ShieldVisual.appear, döngüde kalır);
##   Shaman SM_SHIELD_A (vars. shield_standart), Elara SM_SHIELD_B (vars. shield_kale); meta.json'a baloncuk dikdörtgenleri
## SM_DIR'e kare_NNN.png (kırpılmış). Kullanım: Godot --path . -s tools/proto_20261111/shaman_mermi/sahne_yakala.gd (gizli masaüstü)

const FRAMES := 64
const STEP := 0.05
## Dünya düzeni (Shaman ayağına göre)
const P_ENEMY := Vector2(-175, 0)
const P_Q := Vector2(-55, 6)
const P_E := Vector2(52, 6)
const P_ALLY := Vector2(118, -8)
const CROP_WORLD := Rect2(-215, -62, 380, 96)

var _dir: String = OS.get_environment("SM_DIR")
var _mode: String = OS.get_environment("SM_MODE")
var _player: Node2D = null
var _ally: Node2D = null
var _enemy: Node2D = null
var _q: Node2D = null
var _e: Node2D = null
var _bg: ColorRect = null


class FakeCaster extends Node2D:
	func has_evo(_evo_id: String) -> bool:
		return false

	func is_safe_zone_frozen() -> bool:
		return false


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _xf() -> Transform2D:
	return root.get_final_transform() * root.get_canvas_transform()


func _crop_rect(img: Image) -> Rect2i:
	var a: Vector2 = _xf() * (_player.global_position + CROP_WORLD.position)
	var b: Vector2 = _xf() * (_player.global_position + CROP_WORLD.end)
	return Rect2i(Vector2i(a.round()), Vector2i((b - a).round())).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.get_region(_crop_rect(img)).save_png(_dir.path_join(name))


func _first_anim(n: Node) -> AnimatedSprite2D:
	if n is AnimatedSprite2D:
		return n
	for c in n.get_children():
		var r: AnimatedSprite2D = _first_anim(c)
		if r:
			return r
	return null


func _pause_anim(n: Node) -> void:
	var a: AnimatedSprite2D = _first_anim(n)
	if a:
		a.pause()


## Kırpma içindeki ekran pikseli (sol üst = 0,0).
func _to_crop(world: Vector2) -> Array:
	var img_origin: Vector2 = _xf() * (_player.global_position + CROP_WORLD.position)
	var p: Vector2 = _xf() * world - img_origin.round()
	return [p.x, p.y]


func _totem(path: String, offset: Vector2, with_fx: bool) -> Node2D:
	var t: Node2D = (load(path) as PackedScene).instantiate()
	current_scene.add_child(t)
	if with_fx:
		var fc := FakeCaster.new()
		current_scene.add_child(fc)
		t.set("caster", fc)
		t.call("mark_as_network_visual")
	t.global_position = _player.global_position + offset
	return t


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 12
	gm.selected_character = 27
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	_bg = ColorRect.new()
	_bg.color = Color8(122, 173, 85)
	_bg.size = Vector2(8000, 8000)
	_bg.position = Vector2(-1000, -1000)
	_bg.z_index = -10
	scene.add_child(_bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_ally = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	_ally.scale = Vector2(0.5, 0.5)
	scene.add_child(_ally)
	_ally.call("setup", 2, 8, "Elara")
	_ally.global_position = _player.global_position + P_ALLY
	_ally.set_process(false)
	_ally.set_physics_process(false)
	await _wait(0.4)
	_enemy = (load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene).instantiate()
	scene.add_child(_enemy)
	_enemy.global_position = _player.global_position + P_ENEMY
	_enemy.set("speed", 0.0)
	_enemy.max_health = 600000.0
	_enemy.health = 600000.0
	var fx: bool = _mode == "suan" or _mode == "yeni"
	_q = _totem("res://scenes/totem_attack.tscn", P_Q, fx)
	_e = _totem("res://scenes/totem_shield.tscn", P_E, fx)
	await _wait(1.2) ## dikilme animasyonu bitsin
	if _mode == "tas":
		for t in [_q, _e]:
			var st: Node2D = (t as Node).get_node("TotemSprite")
			st.set_process(false)
			for ch in st.get_children():
				(ch as CanvasItem).visible = false
	for n in [_player, _ally, _enemy]:
		_pause_anim(n)
	if _mode == "kalkan" or _mode == "yeni":
		var ta: String = OS.get_environment("SM_SHIELD_A")
		var tb: String = OS.get_environment("SM_SHIELD_B")
		for pair in [[_player, ta if ta != "" else "shield_standart"], [_ally, tb if tb != "" else "shield_kale"]]:
			var sv: Node = (pair[0] as Node).get_node("ShieldVisual")
			sv.call("set_shield_type", pair[1])
			sv.call("appear")
		await _wait(1.0) ## "grow" bitsin, "loop"ta kalsın
	await _wait(0.1)
	for i in range(FRAMES):
		await _wait(STEP)
		await _shot("kare_%03d.png" % i)
	if _mode == "bos" or _mode == "kalkan" or _mode == "tas":
		await _write_meta()
	if _mode == "bos":
		await _masks()
	print("BITTI")
	quit()


## Sprite'ın kırpmadaki ekran dikdörtgeni [x, y, w, h].
func _sprite_rect(n: Node) -> Array:
	var a: AnimatedSprite2D = _first_anim(n)
	if a == null:
		return []
	var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame)
	var sz: Vector2 = tex.get_size()
	var tl: Vector2 = a.global_transform * (a.offset - sz * 0.5)
	var br: Vector2 = a.global_transform * (a.offset + sz * 0.5)
	var p0: Array = _to_crop(tl)
	var p1: Array = _to_crop(br)
	return [p0[0], p0[1], p1[0] - p0[0], p1[1] - p0[1]]


## AnimatedSprite2D'nin o anki karesinin DOLU piksellerinin kırpmadaki ekran dikdörtgeni [x, y, w, h].
func _used_rect(a: AnimatedSprite2D) -> Array:
	var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation, a.frame)
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	var sz: Vector2 = tex.get_size()
	var origin: Vector2 = (a.offset - sz * 0.5) if a.centered else a.offset
	var p0: Array = _to_crop(a.global_transform * (origin + Vector2(used.position)))
	var p1: Array = _to_crop(a.global_transform * (origin + Vector2(used.end)))
	return [p0[0], p0[1], p1[0] - p0[0], p1[1] - p0[1]]


func _write_meta() -> void:
	var s: float = _xf().get_scale().x
	var q_rc: Vector2 = _q.global_position + Vector2(_q.get("rune_center"))
	var e_rc: Vector2 = _e.global_position + Vector2(_e.get("rune_center"))
	var meta := {
		"px_per_world": s,
		"q_rune": _to_crop(q_rc), "e_rune": _to_crop(e_rc),
		"q_feet": _to_crop(_q.global_position), "e_feet": _to_crop(_e.global_position),
		"enemy_feet": _to_crop(_enemy.global_position), "enemy_rect": _sprite_rect(_enemy),
		"shaman_feet": _to_crop(_player.global_position), "shaman_rect": _sprite_rect(_player),
		"ally_feet": _to_crop(_ally.global_position), "ally_rect": _sprite_rect(_ally),
	}
	if _mode == "tas":
		for pair in [["q_stone", _q], ["e_stone", _e]]:
			var st2: Node2D = (pair[1] as Node).get_node("TotemSprite")
			meta[pair[0]] = _to_crop(st2.global_position)
			meta[pair[0] + "_px"] = st2.global_scale.x * _xf().get_scale().x ## ekran px / taş sanat pikseli
	if _mode == "kalkan":
		meta["shaman_bubble"] = _used_rect(_player.get_node("ShieldVisual/BubbleSprite"))
		meta["ally_bubble"] = _used_rect(_ally.get_node("ShieldVisual/BubbleSprite"))
	var f := FileAccess.open(_dir.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()


## Müttefik + Shaman silüet maskeleri (macenta zemin üstünde yalnız o karakter): mavi hale (E-D) için.
func _masks() -> void:
	_bg.color = Color(1, 0, 1)
	var all: Array = [_player, _ally, _enemy, _q, _e]
	for pair in [["maske_shaman.png", _player], ["maske_elara.png", _ally]]:
		for n in all:
			(n as CanvasItem).visible = n == pair[1]
		await _wait(0.1)
		await _shot(pair[0])
	for n in all:
		(n as CanvasItem).visible = true
	_bg.color = Color8(122, 173, 85)
