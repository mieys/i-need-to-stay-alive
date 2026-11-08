extends SceneTree

## YETENEK PANELİ ARKA PENCERESİ prototipleri (2026-10-31, madde 391; oyuna bağlı DEĞİL). Gerçek SP main.tscn açılır, HUD yakalanır.
## DOCK_PROTO boş -> mevcut ("simdi.png"); A/B/C/D -> gen_dock_pencere.py çıktısı out/tex_<X>/{dock,side}.png HUD kurulunca DockFrame'in
## stiline + yan panellerin (_panel_box) kutusuna yerleşir (dock dokusu tam yükseklikte, payları palettes.json) -> yerleşim, yuvalar, çubuklar AYNI.
## palettes.json'daki "inset"/"rim_lo" varsa panel içi kuyular (çubuk/yuva/levha altı) da o tona çekilir (betik sabiti yamalanır).
## Kullanım: tools/proto_20261031/dock_pencere/dock_run.ps1 [-Only "A,B"]

const CHAR_ID := 2

var _keep: Array = []
var _dir: String = ""


class FakeAlly extends Node2D:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 0
	var health: float = 100.0
	var max_health: float = 100.0
	var item_shield_max: float = 0.0
	var item_shield_hp: float = 0.0
	var is_dead: bool = false
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(_dir.path_join(name))
	print("SHOT %s" % name)


## e = taşma payları (expand_margin; v2'de kemer/tomar topuzu/kütük çıkıntısı panel dikdörtgeninin dışına çizilir).
func _box(proto: String, file: String, m: Array, tile: bool, e: Array = [0, 0, 0, 0]) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(Image.load_from_file(_dir.path_join("tex_" + proto).path_join(file)))
	sb.texture_margin_left = float(m[0])
	sb.texture_margin_top = float(m[1])
	sb.texture_margin_right = float(m[2])
	sb.texture_margin_bottom = float(m[3])
	sb.expand_margin_left = float(e[0])
	sb.expand_margin_top = float(e[1])
	sb.expand_margin_right = float(e[2])
	sb.expand_margin_bottom = float(e[3])
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


## Pencere dokuları HUD kurulduktan sonra yerleşir: DockFrame'in stili + iki yan panelin (efsanevi / mini stat) önbellekli kutusu.
func _apply_windows(hud: Node, proto: String, spec: Dictionary) -> void:
	var frame: Panel = hud.get("dock_frame") as Panel
	if frame:
		frame.add_theme_stylebox_override("panel", _box(proto, "dock.png", spec["dock_margins"], bool(spec.get("dock_tile", false)),
				spec.get("dock_expand", [0, 0, 0, 0])))
	var side: StyleBoxTexture = _box(proto, "side.png", spec["side_margins"], false)
	for n: String in ["dock_legend", "dock_stats"]:
		var c: Control = hud.get(n) as Control
		if c:
			c.set("_panel_box", side)
			c.queue_redraw()

func _patch(path: String, consts: Dictionary) -> void:
	var s: GDScript = load(path) as GDScript
	var src: String = s.source_code
	for name: String in consts:
		var re := RegEx.new()
		re.compile("(?m)^((?:const|var) " + name + "\\s*:?[^=\\n]*=\\s*)(?:Color\\([^)]*\\)|HudTheme\\.[A-Z_]+)")
		if re.search(src) == null:
			print("!! PATCH_MISS ", path.get_file(), " ", name)
			continue
		src = re.sub(src, "$1Color(\"#%s\")" % (consts[name] as Color).to_html(true), false)
	s.source_code = src
	print("PATCH ", path.get_file(), " err=", s.reload())
	_keep.append(s)


func _palette(proto: String) -> Dictionary:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join("palettes.json")))
	var p: Dictionary = {}
	var raw: Dictionary = all.get(proto, {})
	for k: String in raw:
		var v = raw[k]
		p[k] = Color(str(v)) if (v is String and str(v).begins_with("#")) else v
	return p

func _run() -> void:
	await process_frame
	_dir = OS.get_environment("DOCK_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261031/dock_pencere/out")
	DirAccess.make_dir_recursive_absolute(_dir)
	AudioServer.set_bus_mute(0, true)
	var proto: String = OS.get_environment("DOCK_PROTO")
	var pal: Dictionary = {}
	if proto != "":
		pal = _palette(proto)
		if pal.has("inset"):
			var inset: Color = pal["inset"]
			var rim_lo: Color = pal.get("rim_lo", inset)
			_patch("res://scripts/hud_pixel_bar.gd", {"under": inset})
			_patch("res://scripts/hud_legend_slots.gd", {"SLOT_UNDER": inset, "EMPTY_RING": rim_lo, "EMPTY_MARK": inset.lerp(rim_lo, 0.5)})
			_patch("res://scripts/hud_pet_slot.gd", {"UNDER": inset})
			_patch("res://scripts/revive_hearts_hud.gd", {"DOCK_PLATE_FILL": inset})
			_patch("res://scripts/hud_stat_toggle.gd", {"PLATE": inset, "PLATE_ON": inset.lerp(rim_lo, 0.6), "PLATE_HOVER": inset.lerp(rim_lo, 0.35)})
			_patch("res://scripts/hud_stat_panel.gd", {"PLATE": inset, "STRIPE": inset.lerp(rim_lo, 0.35), "TAB_OFF": rim_lo})
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", CHAR_ID).get("skill", 1))
	gm.set("selected_pet", "peri")
	gm.set("selected_spiritual", "can")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			n.set_process(false)
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170)
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "zaman_kiran"}])
	var allies: Array = [["Mira", 10, 412.0, 520.0, 180.0, 240.0], ["Kerem", 5, 160.0, 610.0, 0.0, 0.0]]
	for i in allies.size():
		var a := FakeAlly.new()
		a.peer_id = 1000 + i
		a.player_name = allies[i][0]
		a.char_id = allies[i][1]
		a.health = allies[i][2]
		a.max_health = allies[i][3]
		a.item_shield_hp = allies[i][4]
		a.item_shield_max = allies[i][5]
		a.match_damage_dealt = 1200.0 * (i + 1)
		main.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-260 + 520 * i, -120)
	var banner: Node = main.get_node_or_null("WorldEventBannerLayer/WorldEventBanner")
	if banner:
		banner.call("upsert", 1, "Konvoyu Koru", false)
		banner.call("set_progress", 1, 3.0, 5.0)
	await _wait(1.2)
	var hud: Node = main.get_node_or_null("HUD")
	if hud:
		var toggle: Node = hud.get_node_or_null("DockStatsToggle")
		if toggle:
			toggle.call("set_open", true)
		hud.call("update_level", 12)
		if proto != "":
			_apply_windows(hud, proto, pal)
		if player:
			player.set("health", float(player.get("max_health")) * 0.72)
	if main.has_method("_show_notice"):
		main.call("_show_notice", "info", "Kademe yaklaşıyor", "Kapı 40 sn sonra açılır.", 30.0)
	await _wait(1.0)
	var out_name: String = OS.get_environment("DOCK_OUT")
	if out_name == "":
		out_name = ("proto_%s.png" % proto) if proto != "" else "simdi.png"
	await _shot(out_name)
	quit()
