extends SceneTree
## ALTIN KUMLAR (çöl) collision doğrulaması: Main.i çöl haritasıyla açar, haritanın HER hücresinin ortasında oyunun hareket engelini
## (GameManager.is_position_blocked_by_walls: orman katmanı + terrain_collision su / ağaç gövdesi / katı nesne ayak izi) sorgular ve
## tools/col/out/oyun_engel.bin'e (W*H bayt, satır satır, 1 = engel) yazar. bu betik + üretecin out/engel.npy üretecin taklidiyle
## (out/engel.npy) karşılaştırır: eşleşme = üretecin ulaşılabilirlik analizi oyunla birebir.
## Kullanım: $env:HARITA="col"; Godot --headless --path . -s res://tools/col/engel_karsilastir.gd

const W := 307
const H := 283


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	gm.set("selected_start_weapon", "sword")
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	for i in range(30):
		paused = false
		await process_frame
	var out := PackedByteArray()
	out.resize(W * H)
	var n := 0
	for y in range(H):
		for x in range(W):
			var b: bool = gm.call("is_position_blocked_by_walls", Vector2(x * 16 + 8, y * 16 + 8))
			out[y * W + x] = 1 if b else 0
			n += int(b)
	var path: String = ProjectSettings.globalize_path("res://tools/col/out/oyun_engel.bin")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
	print("ENGEL yazildi %d engel hucre -> %s" % [n, path])
	quit(0)
