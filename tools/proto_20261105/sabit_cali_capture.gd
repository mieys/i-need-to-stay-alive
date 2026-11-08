extends SceneTree
## Sabit geniş çalı doğrulaması (2026-11-05): gerçek çizicide harita + GrassSway, iki çalının çevresinden 0,8 sn arayla iki kare.
## Sabit çalı (Objects.png, liste 5 = hücre 131,13; liste 1 = 55,27) pikselleri kareler arasında DEĞİŞMEMELİ.
## Koşu: tools/proto_20261105/sabit_cali_run.ps1 (gizli masaüstü). Çıktı: tools/proto_20261105/out/

const OUT := "res://tools/proto_20261105/out/"
const CELLS := [Vector2i(131, 13), Vector2i(55, 27), Vector2i(65, 5), Vector2i(35, 92)] ## son = kontrol (Çalılar exterior ot öbeği, sallanmalı)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	root.add_child(harita)
	current_scene = harita
	var gs: Node = (load("res://scripts/grass_sway.gd") as GDScript).new()
	gs.setup(harita)
	var layer: TileMapLayer = harita.get_node("Shader Eklenecek/Çalılar1")
	var cam := Camera2D.new()
	cam.zoom = Vector2(4, 4)
	cam.ignore_rotation = true
	harita.add_child(cam)
	cam.make_current()
	root.size = Vector2i(320, 240)
	for i in CELLS.size():
		var c: Vector2i = CELLS[i]
		cam.global_position = layer.to_global(layer.map_to_local(c)) + Vector2(8, 8)
		for f in 20:
			await process_frame
		var a: Image = root.get_texture().get_image()
		await create_timer(0.8).timeout
		await process_frame
		var b: Image = root.get_texture().get_image()
		print("SABIT_CALI zaman=%d ms boyut=%s zoom=%s" % [Time.get_ticks_msec(), a.get_size(), cam.zoom])
		var diff := 0
		for y in a.get_height():
			for x in a.get_width():
				if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
					diff += 1
		a.save_png(OUT + "cali_%d_a.png" % i)
		b.save_png(OUT + "cali_%d_b.png" % i)
		print("SABIT_CALI hucre=%s fark_piksel=%d" % [c, diff])
	quit(0)
