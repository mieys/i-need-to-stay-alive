extends SceneTree

## Yeni evciller (madde 509) GERÇEK ÇİZİCİDE, oyundaki ölçekte: düz çimen + Matthew (kirpi_capture.gd deseni).
## EVCIL_CAP_DIR'e yazar: evcil_slime.png (büyü aşamaları yan yana), evcil_menzil.png (buff sürerken tam kare, menzil çizgisi),
## evcil_hayalet.png (süzülme -> uçuş -> toplanma -> örtü -> dağılma -> yeniden belirme).
## Kullanım: gizli masaüstünde tools/proto_20261109/evcil_run.ps1 (pencere kullanıcıya görünmez).

const TILE := Vector2i(300, 300)

var _dir: String = OS.get_environment("EVCIL_CAP_DIR")
var _player: Node2D = null
var _tiles: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (_player.global_position + Vector2(0, -16)))
	var rect := Rect2i(Vector2i(int(c.x), int(c.y)) - TILE / 2, TILE).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	_tiles.append(img.get_region(rect))


func _save_strip(name: String) -> void:
	var out := Image.create(TILE.x * _tiles.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i in _tiles.size():
		var t: Image = _tiles[i]
		t.convert(Image.FORMAT_RGBA8)
		out.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(i * TILE.x, 0))
	out.save_png(_dir.path_join(name))
	_tiles.clear()


func _spawn(scene: Node, pet: String) -> void:
	if is_instance_valid(_player):
		_player.queue_free()
		await process_frame
	var gm: Node = root.get_node("GameManager")
	gm.selected_pet = pet
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.get_node("AnimatedSprite2D").play("idle_down")
	_player.buy_weapon_copy("tabanca", 1) ## menzil çizgisi için (oyunda başlangıç silahını main.gd verir)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 3
	gm.selected_character = 43
	gm.selected_start_weapon = "yay"
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)

	## --- Minik Cadı
	await _spawn(scene, "slime")
	var s: Node2D = _player.get_node("Slime")
	s.global_position = _player.global_position + Vector2(-34, 6)
	await _wait(0.6)
	await _grab() ## duruş
	print("SLIME olcek=%s silah=%d" % [s.global_scale, _player.owned_weapon_nodes.size()])
	_player._pet_on_ult_used()
	var prev: float = 0.0
	for t in [0.3, 0.5, 0.62, 0.74, 0.86, 0.98, 1.3, 2.4]: ## madde 523: küre uçuşu (0,4-0.82) + varış + buff görünüşü
		await _wait(t - prev)
		prev = t
		await _grab()
		print("  t=%.2f klip=%s buff=%s" % [t, s.current_clip(), _player.slime_buff_active()])
	_save_strip("evcil_slime.png")
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var full: Image = root.get_texture().get_image()
	full.resize(full.get_width() / 2, full.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	full.save_png(_dir.path_join("evcil_menzil.png"))
	print("MENZIL boy=%.2f menzil=%.0f" % [_player.get_pet_size_mult(), _player.get_node("SlimeRangeRing").max_weapon_range(_player)])
	if OS.get_environment("EVCIL_ONLY") == "slime":
		print("BITTI")
		quit()
		return

	## --- Hayalet
	await _spawn(scene, "hayalet")
	var g: Node2D = _player.get_node("Hayalet")
	await _wait(0.8)
	await _grab() ## süzülme
	_player.max_health = 200.0
	_player.health = 40.0
	for t in [0.08, 0.3]:
		await _wait(0.08 if t < 0.1 else 0.22)
		await _grab()
		print("  t=%.2f klip=%s ortu=%s" % [t, g.current_clip(), _player.ghost_cover_active()])
	await _wait(0.6)
	## örtü sırasında yürüme (madde 513): sağa, sonra sola, sonra dur - hayalet doğal hâlindeki gibi eğilip aynalanmalı
	## Gerçek girdiyle (fizik + ara-değerleme oyundaki gibi açık): sağa 0,7 sn, sola 0,7 sn, dur.
	for act in ["move_right", "move_left"]:
		Input.action_press(act)
		await _wait(0.55)
		await _grab()
		print("  yurume %s klip=%s ayna=%s" % [act, g.current_clip(), g._sprite.flip_h])
		await _wait(0.15)
		Input.action_release(act)
	await _wait(0.6)
	await _grab()
	print("  durdu klip=%s" % g.current_clip())
	_player._ghost_cover_timer = 0.01 ## süreyi kısalt: kıvrılıp küçülme + yeniden belirme
	for w in [0.15, 0.2, 0.45, 0.3]:
		await _wait(w)
		await _grab()
		print("  bitis klip=%s kare=%d" % [g.current_clip(), g._sprite.frame])
	_save_strip("evcil_hayalet.png")
	print("BITTI")
	quit()
