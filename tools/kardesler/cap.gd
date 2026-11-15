extends SceneTree

## Üç Kardeş görsel kontrolü (2026-11-14): gerçek çizicide, oyun kamerası yakınlığında (zoom 2) üç kardeş + ölçek referansı (Goblin 3, Minotaur K5 bossu)
## + ortak 3 parçalı üst bar; ikinci kare: özel animasyonlar + alan / mermi efektleri. Çıktı tools/kardesler/out/.

## -s betikleri autoload'lardan önce derlenir: oyun betikleri burada preload EDİLMEZ, _run'da load() ile gelir.
var SpawnerScript: GDScript = null
var AbilitiesScript: GDScript = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(dir: String, name_: String, region: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.get_region(region).save_png(dir.path_join(name_ + ".png"))
	print("KC SHOT %s" % name_)


func _run() -> void:
	await process_frame
	SpawnerScript = load("res://scripts/enemy_spawner.gd")
	AbilitiesScript = load("res://scripts/enemy_abilities.gd")
	var dir: String = OS.get_environment("KC_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var bg := ColorRect.new()
	bg.color = Color(0.27, 0.36, 0.22)
	bg.position = Vector2(-1200, -800)
	bg.size = Vector2(2400, 1600)
	bg.z_index = -10
	world.add_child(bg)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	world.add_child(cam)
	cam.make_current()
	var sp: Node = SpawnerScript.new()
	sp.name = "EnemySpawner"
	world.add_child(sp)
	var bosses: Array = []
	var xs := {"kardes_kilic1": -110.0, "kardes_ok1": 0.0, "kardes_buyu1": 110.0}
	var nid: int = 990001
	for id: String in xs.keys():
		var b: Node = sp._spawn_creature(id, Vector2(xs[id], 0), nid)
		nid += 1
		b.add_to_group("boss")
		sp._setup_boss_enemy(b, id, 10, 1)
		bosses.append(b)
	var mino: Node = sp._spawn_creature("minotaur1", Vector2(250, 0), nid)
	mino.add_to_group("boss")
	sp._setup_boss_enemy(mino, "minotaur1", 5, 1)
	mino.remove_from_group("boss") ## bar yalnız kardeşleri göstersin
	var gob: Node = sp._spawn_creature("goblin3", Vector2(-240, 0), nid + 1)
	## Hasar almış görünüm: Kılıç tam, Ok yarı can + kalkansız, Büyü çeyrek
	bosses[1].health = bosses[1].max_health * 0.5
	bosses[1].item_shield_hp = 0.0
	bosses[2].health = bosses[2].max_health * 0.25
	bosses[2].item_shield_hp = bosses[2].item_shield_max * 0.4
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var bar := Control.new()
	bar.set_script(load("res://scripts/boss_bar_top.gd"))
	layer.add_child(bar)
	await _wait(1.2)
	bar.call("refresh")
	await _wait(0.5)
	await _shot(dir, "kardesler_dinlenme", Rect2i(0, 0, 1920, 1080))
	await _shot(dir, "kardesler_yakin", Rect2i(560, 380, 800, 340))
	await _shot(dir, "bar", Rect2i(560, 30, 800, 160))
	## Efektler: uyarılar (uzun) + çarpma anı
	for b: Node in bosses:
		b.set_physics_process(false)
	bosses[0].play_special_anim("spin", 2.0)
	bosses[1].play_special_anim("attack", 2.0)
	bosses[2].play_special_anim("cast", 2.0)
	var tree: SceneTree = self
	layer.visible = false
	cam.position = Vector2(0, 90)
	## 0,5 sn sonra yakalanır: meteor düşüyor, yıldırım çakıyor, diken çıkıyor, kasırga dönüyor, oklar iniyor; sağda uzun uyarı halkası
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(-260, 170), {"style": "meteor", "warn": 0.65, "radius": 120.0}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(-60, 190), {"style": "bolt", "warn": 0.42, "radius": 44.0}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(60, 190), {"style": "spikes", "warn": 0.42, "radius": 34.0}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(-110, 0), {"style": "spin", "warn": 0.42, "radius": 130.0}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(190, 190), {"style": "arrows", "warn": 0.62, "radius": 48.0}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_zone", Vector2(330, 120), {"style": "meteor", "warn": 3.0, "radius": 60.0}, false)
	for i in range(3):
		AbilitiesScript.spawn_world_fx(tree, "kardes_shot", Vector2(-40, -70 + i * 22), {"style": "arrow", "dir": Vector2.LEFT.rotated(0.15 * (i - 1)), "speed": 30.0, "kind": "x"}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_shot", Vector2(170, -40), {"style": "fireball", "dir": Vector2(1, 0.3), "speed": 30.0, "kind": "fireball"}, false)
	AbilitiesScript.spawn_world_fx(tree, "kardes_shot", Vector2(170, -90), {"style": "ice", "dir": Vector2.RIGHT, "speed": 30.0, "kind": "x"}, false)
	await _wait(0.5)
	await _shot(dir, "efektler", Rect2i(0, 0, 1920, 1080))
	layer.visible = true
	await _wait(0.6)
	await _shot(dir, "bar_tam", Rect2i(0, 0, 1920, 300))
	quit(0)
