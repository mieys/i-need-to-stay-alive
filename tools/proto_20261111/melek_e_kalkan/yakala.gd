extends SceneTree

## PROTOTİP yakalama (oyuna bağlı DEĞİL): Melek E bağı + dostun kalkan yenilenme baloncuğu, GERÇEK ÇİZİCİDE oyun ölçeğinde
## (Melek = yerel Player 0,5 ölçek, dost = RemotePlayer kuklası, kamera zoom 2). Dört seçenek sırayla (bond_variant.gd):
## suan / a / b / c. Her seçenek kendi temiz sahnesinde; ME_DIR/<seçenek>/f_###.png (15 fps, --fixed-fps 30 ile her 2. kare).
## Kullanım: yakala.ps1 (gizli masaüstü).

const FPS := 30
const TOTAL := 156 ## 5,2 sn
const EV_START := 6
const EV_TICKS := [36, 66, 96]
const EV_STOP := 126
const CROP := Vector2i(520, 280)

var _dir: String = OS.get_environment("ME_DIR")
var _shield_type: String = OS.get_environment("ME_SHIELD")
## ME_VARIANTS: virgüllü liste (boşsa suan,a,b,c)
var _variants: PackedStringArray = (OS.get_environment("ME_VARIANTS") if OS.get_environment("ME_VARIANTS") != "" else "suan,a,b,c").split(",")


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
	player.damage_bonus = 60.0
	var ally: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(ally)
	ally.setup(77, 7, "Dost")
	ally.global_position = player.global_position + Vector2(104, 6)
	ally.set("_target_position", ally.global_position)
	ally.set("health", 30.0)
	ally.set("item_shield_max", 100.0)
	ally.set("item_shield_hp", 12.0)
	var sv: Node2D = ally.get_node("ShieldVisual")
	sv.call("set_shield_type", _shield_type)
	sv.visible = false
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = (player.global_position + ally.global_position) * 0.5 + Vector2(0, -14)
	cam.make_current()
	for i in range(12):
		await process_frame
	var bond: Node = null
	var echo_prev: int = 0
	var arrivals: int = 0
	for i in range(TOTAL):
		if i == EV_START:
			if v.begins_with("oyun"):
				## OYUNUN KENDİ bağı (madde 565): "oyun" = bağ halkası, "oyun_e1" = Kutsal Zırh evrimiyle + sarmal
				if v == "oyun_e1":
					player.skill_evolutions["melek_e1"] = true
				player.skill2_state = "active"
				player.skill2_timer = 6.0
				player._skill_kalkan_yenileme()
				bond = (ally.get("_ally_aura_fx") as Dictionary).get("shield")
			else:
				## dostun bağını önce bizim alt sınıfımızla kur (start_ally_aura_fx varken erken döner)
				var fx: Node2D = (load("res://tools/proto_20261111/melek_e_kalkan/bond_variant.gd") as GDScript).new()
				fx.set("variant", v)
				fx.call("setup", "shield", player)
				ally.add_child(fx)
				var reg: Dictionary = ally.get("_ally_aura_fx")
				reg["shield"] = fx
				bond = fx
				player.skill2_state = "active"
				player.skill2_timer = 6.0
				player._skill_kalkan_yenileme()
		if EV_TICKS.has(i):
			player._spawn_wave_beam_to_ally(ally, "shield")
		if i == EV_STOP:
			player.skill2_state = "cooldown"
			player.call("_end_skill2_effects")
			ally.call("stop_ally_aura_fx", "shield")
		## varış = yankı halkası listesinin 0 -> 1 geçişi; ilki kuruluşun yıldızı, sonrakilerde dostun kalkan çubuğu yükselir
		if bond != null and is_instance_valid(bond):
			var n: int = (bond.get("_echoes") as Array).size()
			if n > echo_prev:
				arrivals += 1
				print("VARIS %s kare %d" % [v, i / 2])
				if arrivals > 1:
					ally.set("item_shield_hp", minf(100.0, float(ally.get("item_shield_hp")) + 20.0))
					var ob: Node = ally.get("overhead_bar")
					if ob != null:
						ob.call("set_shield", float(ally.get("item_shield_hp")), 100.0)
			echo_prev = n
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var img: Image = root.get_texture().get_image()
			var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
			var rect := Rect2i(c - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			img.get_region(rect).save_png(_dir.path_join(v).path_join("f_%03d.png" % (i / 2)))
	print("SECENEK %s kare %d varis %d" % [v, TOTAL / 2, arrivals])
	scene.queue_free()
	for i in range(4):
		await process_frame
