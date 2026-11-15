extends Node

## Menü müziği (scripts/menu_music.gd): akış yüklenir, döngülü, Müzik bus'ında; karakter seçiminde çalar (kısık), diğer sahnelerde söner.


func _make() -> AudioStreamPlayer:
	var m: AudioStreamPlayer = preload("res://scripts/menu_music.gd").new()
	add_child(m)
	return m


func test_stream_loops_on_music_bus() -> void:
	var m := _make()
	assert(m.stream is AudioStreamMP3, "mp3 akışı yüklenmeli")
	assert((m.stream as AudioStreamMP3).loop, "döngülü olmalı")
	assert(m.bus == &"Music", "Müzik bus'ında olmalı: %s" % m.bus)
	m.queue_free()


func test_plays_in_select_quiet_and_fades_elsewhere() -> void:
	var m := _make()
	var scene: Node = get_tree().current_scene
	assert(scene != null, "current_scene yok")
	var old_path: String = scene.scene_file_path
	scene.scene_file_path = "res://scenes/character_select.tscn"
	for i in 40:
		m._process(0.1)
	assert(m.playing, "karakter seçiminde çalmalı")
	assert(m.volume_db <= -9.0 and m.volume_db > -30.0, "kısık ama duyulur olmalı: %s" % m.volume_db)
	for path in ["res://scenes/loading_screen.tscn", "res://scenes/main.tscn"]:
		scene.scene_file_path = "res://scenes/lobby_menu.tscn"
		for i in 40:
			m._process(0.1)
		assert(m.playing, "çok oyunculu seçimde çalmalı")
		scene.scene_file_path = path
		for i in 40:
			m._process(0.1)
		assert(not m.playing, "%s sahnesinde susmalı" % path)
	scene.scene_file_path = old_path
	m.queue_free()


## 2026-11-15: ana menü / oda sahnelerinde For Originz, seçim ekranında Home Stretch; geçişte eski parça söner.
func test_main_menu_track_then_select_track() -> void:
	var m := _make()
	var scene: Node = get_tree().current_scene
	var old_path: String = scene.scene_file_path
	scene.scene_file_path = "res://scenes/main_menu.tscn"
	for i in 40:
		m._process(0.1)
	assert(m.playing and m.stream.resource_path.ends_with("menu_music_for_originz.mp3"), "ana menüde For Originz: %s" % str(m.stream))
	scene.scene_file_path = "res://scenes/character_select.tscn"
	for i in 80:
		m._process(0.1)
	assert(m.playing and m.stream.resource_path.ends_with("menu_music_home_stretch.mp3"), "seçimde Home Stretch: %s" % str(m.stream))
	scene.scene_file_path = old_path
	m.queue_free()
