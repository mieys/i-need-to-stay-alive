extends SceneTree

## KALKAN DARBE PROTOTİPİ yakalama (oyuna bağlı DEĞİL): gerçek çizicide oyun ölçeğinde (Player 0,5, kamera zoom 2), gerçek
## take_damage ile 8 darbe (doğu, kuzey, batı, güney, kuzeydoğu, güneybatı + art arda iki). Her seçenek kendi temiz sahnesinde;
## KD_DIR/<seçenek>/f_###.png (15 fps, --fixed-fps 30 ile her 2. kare). Kalkan her darbeden sonra doldurulur (kırılma /
## yenilenme baloncuğu karışmasın - yalnız hasar alma efekti). Kullanım: yakala.ps1 (gizli masaüstü).

const TOTAL := 150 ## 5 sn
const HITS := [[10, 0.0], [28, -PI * 0.5], [46, PI], [64, PI * 0.5], [82, -PI * 0.25], [100, PI * 0.75], [118, 0.45], [125, 2.5]]
const CROP := Vector2i(280, 230)

var _dir: String = OS.get_environment("KD_DIR")
var _shield_type: String = OS.get_environment("KD_SHIELD")
var _variants: PackedStringArray = (OS.get_environment("KD_VARIANTS") if OS.get_environment("KD_VARIANTS") != "" else "suan,a,b,c,d").split(",")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	if _shield_type == "":
		_shield_type = "shield_standart"
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 10
	gm.selected_character = 1
	gm.set("shield_standart_level", 1)
	gm.set("shield_enchant", "" if _shield_type == "shield_standart" else _shield_type)
	for v: String in _variants:
		await _run_variant(v)
	print("BITTI")
	quit()


func _run_variant(v: String) -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join(v))
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(126, 176, 84)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = Vector2(3000, 3000)
	player.set_physics_process(false)
	for i in range(3):
		await process_frame
	## bugünkü efekti (ManaShieldFx + arka katman) prototip alt sınıfıyla değiştir
	var old_fx: Node = player.get("mana_fx")
	var old_back: Node = player.get_node_or_null("ManaShieldBack")
	for n: Node in [old_fx, old_back]:
		if n != null:
			player.remove_child(n)
			n.free()
	var back := Node2D.new()
	back.name = "ManaShieldBack"
	back.show_behind_parent = true
	player.add_child(back)
	var fx: Node2D = (load("res://tools/proto_20261111/kalkan_darbe/hit_variant.gd") as GDScript).new()
	fx.name = "ManaShieldFx"
	fx.set("host", player)
	fx.set("_back", back)
	fx.set("variant", v)
	player.add_child(fx)
	fx.set("hit_only", true)
	player.set("mana_fx", fx)
	fx.call("set_shield_type", _shield_type)
	var sv: Node = player.get_node("ShieldVisual")
	sv.call("set_shield_type", _shield_type)
	var src := Node2D.new()
	scene.add_child(src)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = player.global_position + Vector2(0, -6)
	cam.make_current()
	for i in range(12):
		await process_frame
	for i in range(TOTAL):
		for h: Array in HITS:
			if int(h[0]) == i:
				player.set("item_shield_max", 100.0)
				player.set("item_shield_hp", 100.0)
				player.set("max_health", 500.0)
				player.set("health", 500.0)
				src.global_position = player.global_position + Vector2.from_angle(float(h[1])) * 70.0
				player.call("take_damage", 9.0, src)
				player.set("item_shield_hp", 100.0)
				player.set("item_shield_regen_delay", 0.0)
				player.set("health", 500.0)
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var img: Image = root.get_texture().get_image()
			var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
			var rect := Rect2i(c - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			img.get_region(rect).save_png(_dir.path_join(v).path_join("f_%03d.png" % (i / 2)))
	print("SECENEK %s kare %d" % [v, TOTAL / 2])
	scene.queue_free()
	for i in range(4):
		await process_frame
