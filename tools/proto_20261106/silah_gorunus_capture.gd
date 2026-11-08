extends SceneTree

## Madde 402 doğrulaması (GERÇEK ÇİZİCİ, oyun ölçeği: oyuncu kökü 0,5, kamera zoom 2): 4 oyuncu x 3 silah, ortada bir slime (silahlar
## görüşte düşman varken çıkar). Üst iki satır masaüstü çizimleri + Yıldırım, alt iki satır eski ikonlar; her satırda kademe 1 / 3 / 5
## (kontür: yok / mavi / kırmızı). Çıktı SG_CAP_DIR/silah_gorunus.png. Kullanım: Godot --path . -s tools/proto_20261106/silah_gorunus_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok.

const ROWS := [
	["uzunkilic", "arcane", "fire_staff"],
	["buz_asasi", "gokkusagi", "lightning_staff"],
	["dagger", "topuz", "pence"],
	["tuftuf", "yay", "boomerang"], ## tuftuf = Zehir Asası (masaüstü çizimi)
]
const TIER_ENCH := [
	{},
	{"id": "cap_yok", "ups": [0, 1], "final": false},
	{"id": "cap_yok", "ups": [0, 1, 2, 3], "final": true},
]


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 5
	gm.selected_character = 16
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var p0 := Vector2(2900, 3000)
	var players: Array = []
	for r in ROWS.size():
		var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
		player.scale = Vector2(0.5, 0.5)
		player.z_index = 1
		scene.add_child(player)
		player.global_position = p0 + Vector2(0, -120 + 80 * r)
		player.set_physics_process(false)
		for k in ROWS[r]:
			player.call("buy_weapon_copy", k, 1)
		players.append(player)
	await process_frame
	for player in players:
		var i: int = 0
		for w in player.get("owned_weapon_nodes"):
			w.call("set_enchant", TIER_ENCH[i % 3])
			(w.get("fire_timer") as Timer).paused = true ## atış/savuruş yok: sadece duruş + kontür
			i += 1
	var slime: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(slime)
	slime.global_position = p0 + Vector2(170, 0)
	slime.set("speed", 0.0)
	slime.max_health = 600000.0
	slime.health = 600000.0
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = p0 + Vector2(50, -30)
	cam.make_current()
	await _wait(2.2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var rect := Rect2i(int(c.x) - 330, int(c.y) - 500, 660, 1000).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var dir: String = OS.get_environment("SG_CAP_DIR")
	img.get_region(rect).save_png(dir.path_join("silah_gorunus.png"))
	print("BITTI")
	quit()
