extends SceneTree

## Zehirli Gonca + Filiz + tohumlar ve Medusa bakışı + taşlaşma (madde 682) GERÇEK ÇİZİCİDE, oyundaki ölçekte (oyuncu kökü 0,5, kamera zoom 2).
## Bosslar gerçek EnemySpawner kurulumuyla doğar (_setup_boss_enemy: boyut, statlar), yetenekleri kendi kendine çalışır (bekleme süreleri öne çekilir).
## Kareler BC_CAP_DIR'e: g_<sıra>.png (Gonca), m_<sıra>.png (Medusa). Kullanım: tools/boss_gorsel/boss_682_capture.ps1 (gizli masaüstü).
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("BC_CAP_DIR")
var _player: Node2D = null
var _shot: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float, pose: bool = false) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if pose and is_instance_valid(_player):
			_player.call("_play_cc_anim") ## fizik kapalı: taş pozunu elle uygula
			_player.call("_process_stun", 1.0 / 60.0)
		await process_frame


func _snap(prefix: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join("%s_%02d.png" % [prefix, _shot]))
	_shot += 1


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
	bg.size = Vector2(12000, 12000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var sp: Node = (load("res://scripts/enemy_spawner.gd") as GDScript).new()
	sp.name = "EnemySpawner"
	scene.add_child(sp)
	sp.set("max_concurrent_enemies", 0)
	sp.set_process(false)
	sp.set_physics_process(false)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	_player.set("max_health", 1000000.0)
	_player.set("health", 1000000.0)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)

	## ---------------- Zehirli Gonca
	var boss: Node2D = sp._spawn_creature("gonca1", _player.global_position + Vector2(150, -40), 990001)
	boss.add_to_group("boss")
	sp._setup_boss_enemy(boss, "gonca1", 5, 1)
	boss.call("_init_abilities")
	for off: Vector2 in [Vector2(-120, -90), Vector2(250, 60), Vector2(60, 110)]:
		var f: Node = sp.spawn_summon("filiz1", boss.global_position + off, boss)
		if f != null:
			f.call("_init_abilities")
	cam.global_position = _player.global_position + Vector2(70, -10)
	cam.make_current()
	await _wait(0.8)
	await _snap("g") ## bekleme + filizler doğuyor
	var kit: Object = (boss.get("_abilities") as Object).get("_boss_kit") if boss.get("_abilities") != null else null
	if kit != null:
		kit.set("_ring_cd", 999.0)
		kit.set("_migrate_cd", 999.0)
		kit.set("_seed_cd", 0.0)
	await _wait(0.55)
	await _snap("g") ## tükürme klibi + tohumlar havada
	await _wait(0.45)
	await _snap("g") ## tohumlar düştü
	await _wait(0.9)
	await _snap("g") ## filizlenme
	if kit != null:
		_player.global_position = boss.global_position + Vector2(-90, 30)
		kit.set("_ring_cd", 0.0)
	await _wait(0.25)
	await _snap("g") ## diken halkası uyarısı
	await _wait(0.35)
	await _snap("g") ## halka patlaması
	for g: String in ["enemies", "summons"]:
		for e: Node in get_nodes_in_group(g):
			e.queue_free()
	await _wait(0.3)

	## ---------------- Medusa
	_shot = 0
	_player.global_position = Vector2(6000, 3000)
	var med: Node2D = sp._spawn_creature("medusa1", _player.global_position + Vector2(0, -170), 990101)
	med.add_to_group("boss")
	sp._setup_boss_enemy(med, "medusa1", 10, 1)
	med.call("_init_abilities")
	var mkit: Object = (med.get("_abilities") as Object).get("_boss_kit") if med.get("_abilities") != null else null
	if mkit != null:
		mkit.set("_snake_cd", 999.0)
		mkit.set("_dash_cd", 999.0)
		mkit.set("_gaze_cd", 999.0)
	cam.global_position = _player.global_position + Vector2(0, -110)
	cam.make_current()
	await _wait(0.6)
	await _snap("m") ## Medusa bekleme
	if mkit != null:
		mkit.set("_gaze_cd", 0.0)
	await _wait(0.5)
	await _snap("m") ## bakış uyarısı
	await _wait(0.45)
	await _snap("m") ## ışınlar
	_player.call("apply_petrify", 2.0)
	await _wait(0.3, true)
	await _snap("m") ## taşlaşmış oyuncu
	await _wait(2.0, true)
	_player.call("apply_stone_slow", 0.3, 2.0)
	await _wait(0.3)
	await _snap("m") ## taş ağırlığı (bacaklar)
	if mkit != null:
		mkit.set("_snake_cd", 0.0)
		mkit.set("_busy", 0.0)
	_player.global_position = med.global_position + Vector2(0, 90)
	await _wait(0.4)
	await _snap("m") ## yılan kırbacı
	quit(0)
