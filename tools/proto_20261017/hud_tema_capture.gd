extends SceneTree

## HUD TEMA prototipi (2026-10-17): gerçek oyunu (SP, main.tscn) açar ve HUD'u yakalar. Oyuna bağlı DEĞİL.
## HUD_TEMA boş -> mevcut HUD ("simdi.png"); A/B/C/D -> tema oyun AÇILMADAN önce yerleştirilir:
##  1) dokular: tools/proto_20261017/hud_tema_gen.py çıktısı ImageTexture olarak ORİJİNAL res:// yolunu devralır
##     (Resource.take_over_path) - hud.tscn + preload'lar aynı boyut/silüetteki yeni dokuyu yükler, yerleşim AYNI.
##  2) _draw ile çizen HUD betiklerinin renk sabitleri kaynakta değiştirilip yeniden derlenir (aynı önbellek nesnesi).
##  3) koyu zeminde okunmayan koyu yazılar (görev/grup satırları, altın) tema yazı rengine çekilir.
## Yetenek yuvalarının yerleşimi, ikonları, çubuk dolgu renkleri DEĞİŞMEZ (kullanıcı: sadece çerçeve/arka plan).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/hud_tema_capture.gd
## HUD_DUMP=1 -> HUD düğüm ağacını yazar.

const OUT := "res://tools/proto_20261017/out/hud_tema/"
const CHAR_ID := 2

## Tema boyunca canlı tutulmalı: önbellek zayıf referans tutar, nesne ölürse yol orijinal dokuya döner.
var _keep: Array = []


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])


# ---------------------------------------------------------------- tema yerleştirme
func _hex(c: Color) -> String:
	return "Color(\"#%s\")" % c.to_html(false)


func _override_textures(tema: String) -> void:
	var dir: String = ProjectSettings.globalize_path(OUT + "tex_" + tema)
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".png"):
			continue
		var res_path: String = "res://" + f.replace("__", "/")
		var img: Image = Image.load_from_file(dir.path_join(f))
		if img == null:
			print("TEX_FAIL ", f)
			continue
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		tex.take_over_path(res_path)
		_keep.append(tex)
		print("TEX ", res_path)


func _patch(path: String, consts: Dictionary, literals: Dictionary = {}) -> void:
	var s: GDScript = load(path) as GDScript
	var src: String = s.source_code
	for name: String in consts:
		var re := RegEx.new()
		re.compile("(?m)^((?:const|var) " + name + "\\s*:?[^=\\n]*=\\s*)Color\\([^)]*\\)")
		if re.search(src) == null:
			print("PATCH_MISS ", path.get_file(), " ", name)
			continue
		src = re.sub(src, "$1" + _hex(consts[name]), false)
	for lit: String in literals:
		if not src.contains(lit):
			print("PATCH_MISS ", path.get_file(), " ", lit)
			continue
		src = src.replace(lit, _hex(literals[lit]))
	s.source_code = src
	var err: int = s.reload()
	_keep.append(s)
	print("PATCH ", path.get_file(), " err=", err)


func _patch_scripts(p: Dictionary) -> void:
	var out_c: Color = p["out"]
	var inset: Color = p["inset"]
	var rim: Color = p["rim"]
	var rim_lo: Color = p["rim_lo"]
	var rim_hi: Color = p["rim_hi"]
	var dim: Color = p["dim"]
	_patch("res://scripts/hud_pixel_bar.gd", {"under": inset, "OUTLINE": out_c, "VALUE_DIM": dim})
	_patch("res://scripts/hud_legend_slots.gd", {"SLOT_UNDER": inset, "EMPTY_RING": rim_lo, "EMPTY_MARK": inset.lerp(rim_lo, 0.5)})
	_patch("res://scripts/hud_pet_slot.gd", {"UNDER": inset})
	_patch("res://scripts/revive_hearts_hud.gd", {"DOCK_PLATE_FILL": inset, "DOCK_TIMER_IDLE": dim})
	_patch("res://scripts/hud_stat_toggle.gd", {"OUTLINE": out_c, "PLATE": inset, "PLATE_ON": inset.lerp(rim, 0.35),
			"PLATE_HOVER": inset.lerp(rim, 0.2)}, {"Color(0.36, 0.25, 0.15)": rim_lo})
	_patch("res://scripts/hud_stat_panel.gd", {"OUTLINE": out_c, "PLATE": inset, "STRIPE": inset.lerp(rim_lo, 0.35),
			"TAB_ON": rim_hi, "TAB_OFF": rim_lo, "TAB_OFF_TEXT": dim})
	_patch("res://scripts/bottom_exp_bar.gd", {"C_BG": inset, "C_OUTLINE": rim})
	_patch("res://scripts/world_event_banner.gd", {}, {"Color(\"#3a2212\")": out_c, "Color(\"#5a361d\")": inset})


func _load_palette(tema: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(OUT + "palettes.json")
	var all: Dictionary = JSON.parse_string(txt)
	var raw: Dictionary = all[tema]
	var p: Dictionary = {}
	for k: String in raw:
		var v = raw[k]
		p[k] = Color(str(v)) if (v is String and str(v).begins_with("#")) else v
	return p


func _relabel(n: Node, text: Color) -> void:
	if n is Button:
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			(n as Button).add_theme_color_override(k, text)
	if n is Label:
		var l := n as Label
		var c: Color = l.get_theme_color("font_color")
		if c.get_luminance() < 0.4:
			l.add_theme_color_override("font_color", text)
	for ch in n.get_children():
		_relabel(ch, text)


# ---------------------------------------------------------------- akış
func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var tema: String = OS.get_environment("HUD_TEMA")
	var pal: Dictionary = {}
	if tema != "":
		pal = _load_palette(tema)
		_override_textures(tema)
		_patch_scripts(pal)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	var def: Dictionary = load("res://scripts/characters.gd").get_def(CHAR_ID)
	gm.set("selected_character", def.get("skill", 1))
	gm.set("selected_pet", "peri")
	gm.set("selected_spiritual", "can")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170) ## kapı uyarısı ("Eve girmek için...") yetenek panelini örtmesin
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "zaman_kiran"}])

	## 2 sahte takım arkadaşı (grup paneli + minimap) + 1 görev satırı (sağdaki görev göstergesi)
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
		current_scene.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-260 + 520 * i, -120)
	var banner: Node = current_scene.get_node_or_null("WorldEventBannerLayer/WorldEventBanner")
	if banner:
		banner.call("upsert", 1, "Konvoyu Koru", false)
		banner.call("set_progress", 1, 3.0, 5.0)
	await _wait(1.2)

	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud:
		var toggle: Node = hud.get_node_or_null("DockStatsToggle")
		if toggle:
			toggle.call("set_open", true)
		hud.call("update_level", 12)
		if player:
			player.set("health", float(player.get("max_health")) * 0.72)
	if tema != "" and hud:
		var dv: ColorRect = hud.get_node_or_null("DockDivider") as ColorRect
		if dv:
			dv.color = Color(pal["out"], 0.6)
		var lv: Label = hud.get("level_label") as Label
		if lv:
			lv.add_theme_color_override("font_color", pal["text"])
		var gold_l: Label = hud.get("gold_indicator_label") as Label
		if gold_l:
			gold_l.add_theme_color_override("font_color", pal["price"])
		var shard: Node = hud.get_node_or_null("ShardIndicator")
		if shard:
			for l: Node in shard.find_children("*", "Label", true, false):
				(l as Label).add_theme_color_override("font_color", Color("#a8d8f0"))
		for n: String in ["PartyPanelLayer", "EnvanterToggleButton"]:
			var nn: Node = hud.get_node_or_null(n)
			if nn:
				_relabel(nn, pal["text"])
		if banner:
			_relabel(banner, pal["text"])
	await _wait(0.8)

	if OS.get_environment("HUD_DUMP") == "1" and hud:
		for c: Node in hud.get_node("PartyPanelLayer").find_children("*", "Control", true, false):
			if (c as Control).is_visible_in_tree():
				print("PARTY ", c.name, " ", (c as Control).get_global_rect())
		if banner:
			for c: Node in banner.find_children("*", "Control", true, false):
				print("BANNER ", c.name, " ", (c as Control).get_global_rect(), " ", (c as Control).is_visible_in_tree())
	if OS.get_environment("HUD_POPUP") == "1" and hud:
		## grup panelinin "Hasar" istatistik penceresi (koyu levha + açık yazı doğrulaması)
		var pp: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
		if pp:
			pp.call("_on_stats_button_pressed")
		await _wait(0.5)
	var out_name: String = OS.get_environment("HUD_OUT") ## boş değilse bu adla (ör. oyuna geçirilmiş temanın doğrulaması)
	if out_name == "":
		out_name = ("tema_%s.png" % tema) if tema != "" else "simdi.png"
	await _shot(out_name)
	quit()
