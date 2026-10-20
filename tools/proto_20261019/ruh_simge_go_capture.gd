extends SceneTree

## Oyun Bitti panosundaki Ruh Kıymığı kristalini (madde 343) gerçek çizicide yakalar: PC panosu + Ruh Mağazası kristali yan yana.
## Kullanım: Godot --path . --windowed --resolution 1600x900 -s tools/proto_20261019/ruh_simge_go_capture.gd  (CAP_DIR = çıktı klasörü)

var _dir: String = OS.get_environment("CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("#151520")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var board: Control = (load("res://scripts/game_over_board.gd") as GDScript).new()
	board.position = Vector2(20, 20)
	board.size = Vector2(1180, 860)
	root.add_child(board)
	board.call("set_summary", {"time": 754.0, "tier": 6, "kills": 400, "layer": 0, "level": 14}, {"shards": 42})
	board.call("set_team", {1: {"name": "Sen", "dealt": 9000.0, "taken": 800.0, "kills": 200}}, {1: 2}, 1)
	var DK: GDScript = load("res://scripts/menu_dark_kit.gd")
	var x := 1240.0
	for px: float in [20.0, 38.0, 52.0]:
		var ic: Control = DK.ShardIcon.new(px)
		ic.position = Vector2(x, 60)
		ic.size = Vector2(px, px)
		root.add_child(ic)
		x += px + 24.0
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("oyun_bitti_kristal.png"))
	print("SHOT ok")
	quit()
