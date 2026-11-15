extends SceneTree

## PROTOTİP yakalama (oyuna bağlı DEĞİL): Şovalye E "Koruma Bariyeri" - dostun etrafındaki bariyerin kendisi, GERÇEK ÇİZİCİDE
## oyun ölçeğinde (kuklalar 0,5 kök, kamera zoom 2). Ortada Şovalye, iki yanında bariyerli Talon + Büyücü Kız.
## Seçenekler sırayla kendi temiz sahnesinde: suan (fx_paladin_barrier_link.gd) / a / b / c / d (bariyer_variant.gd).
## SB_DIR/<seçenek>/f_###.png (15 fps, --fixed-fps 30 ile her 2. kare). Kullanım: yakala.ps1 (gizli masaüstü).

const TOTAL := 150 ## 5 sn
const EV_START := 9
const EV_STOP := 120
const CROP := Vector2i(520, 248)
## Dostların Şovalye'ye uzaklığı (dünya px). Gizli masaüstü 2560x1440 -> zoom 2'de 2,67 ekran px / dünya px.
const ALLY_DX := 60.0

var _dir: String = OS.get_environment("SB_DIR")
var _variants: PackedStringArray = (OS.get_environment("SB_VARIANTS") if OS.get_environment("SB_VARIANTS") != "" else "suan,a,b,c,d").split(",")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	for v: String in _variants:
		await _run_variant(v)
	print("BITTI")
	quit()


func _kukla(scene: Node2D, peer: int, char_id: int, nm: String, pos: Vector2) -> Node2D:
	var k: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(k)
	k.setup(peer, char_id, nm)
	k.global_position = pos
	k.set("_target_position", pos)
	var sv: Node2D = k.get_node_or_null("ShieldVisual")
	if sv != null:
		sv.visible = false
	return k


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
	var c := Vector2(3000, 3000)
	_kukla(scene, 71, 7, "Şovalye", c)
	var allies: Array[Node2D] = [
		_kukla(scene, 72, 1, "Talon", c + Vector2(-ALLY_DX, 4)),
		_kukla(scene, 73, 4, "Büyücü", c + Vector2(ALLY_DX, -2)),
	]
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = c + Vector2(0, -10)
	cam.make_current()
	for i in range(12):
		await process_frame
	var fxs: Array[Node2D] = []
	for i in range(TOTAL):
		if i == EV_START:
			for a: Node2D in allies:
				var fx := Node2D.new()
				if v == "suan" or v == "oyun":
					## "oyun": oyunun KENDİ betiği + içe aktarılmış sayfalar (madde 581 A5); "suan" eski kayıt adıydı
					fx.set_script(load("res://scripts/fx_paladin_barrier_link.gd"))
				else:
					fx.set_script(load("res://tools/proto_20261111/sovalye_bariyer/bariyer_variant.gd"))
					fx.set("variant", v)
				a.add_child(fx)
				fxs.append(fx)
		if i == EV_STOP:
			for fx: Node2D in fxs:
				if not is_instance_valid(fx):
					continue
				if fx.has_method("dismiss"):
					fx.call("dismiss") ## oyundaki gibi (player/remote_player _refresh_barrier_link_visual)
				elif v == "suan":
					fx.queue_free() ## eski betik: anında
				else:
					fx.call("stop")
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var img: Image = root.get_texture().get_image()
			var ctr := Vector2i(img.get_width() / 2, img.get_height() / 2)
			var rect := Rect2i(ctr - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			img.get_region(rect).save_png(_dir.path_join(v).path_join("f_%03d.png" % (i / 2)))
	print("SECENEK %s kare %d" % [v, TOTAL / 2])
	scene.queue_free()
	for i in range(4):
		await process_frame
