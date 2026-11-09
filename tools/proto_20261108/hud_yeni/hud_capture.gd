extends SceneTree

## OYUN İÇİ ARAYÜZ prototipleri yakalayıcısı (2026-11-08, oyuna bağlı DEĞİL). Gerçek SP main.tscn açılır (Oakley + Peri + ruhani "can",
## 3 efsanevi, 2 sahte takım arkadaşı, görev satırı); HUD_PROTO boş -> bugünkü HUD ("simdi.png"), A/B/C/D -> eski HUD + grup paneli +
## görev şeridi gizlenir, hud_proto.gd tam ekran kurulur, gerçek MinimapControl prototipe taşınır.
## Kullanım: tools/proto_20261108/hud_yeni/run.ps1 [-Only "simdi,A,B,C,D"]

const CHAR_ID := 2

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
	if img.get_width() != 1920 and OS.get_environment("HUDY_NATIVE") != "1":
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(_dir.path_join(name))
	print("SHOT %s" % name)


func _t(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _data(hud: Node) -> Dictionary:
	var chars: GDScript = load("res://scripts/characters.gd") as GDScript
	var def: Dictionary = chars.call("get_def", CHAR_ID)
	var spir: GDScript = load("res://scripts/spiritual_skills.gd") as GDScript
	var sdef: Dictionary = spir.call("get_def", "can")
	var items_s: GDScript = load("res://scripts/items.gd") as GDScript
	var pets: GDScript = load("res://scripts/pet_catalog.gd") as GDScript
	var allies: Array = []
	for a in [["Mira", 10, 412.0, 520.0, 180.0, 240.0], ["Kerem", 5, 160.0, 610.0, 0.0, 0.0]]:
		var ad: Dictionary = chars.call("get_def", int(a[1]))
		allies.append({"name": a[0], "portrait": _t(str(ad.get("portrait", ""))), "hp": a[2], "hp_max": a[3], "sh": a[4], "sh_max": a[5]})
	return {
		"name": str(def.get("name", "Oakley")),
		"portrait": _t(str(def.get("portrait", ""))),
		"skills": [
			{"tex": _t(str(def.get("passive_icon", ""))), "key": ""},
			{"tex": _t(str(def.get("skill_icon", ""))), "key": "Q"},
			{"tex": _t(str(def.get("skill2_icon", ""))), "key": "E", "cd": 4.0, "cd_ratio": 0.4},
			{"tex": _t(str(def.get("skill3_icon", ""))), "key": "R"},
			{"tex": _t(str(sdef.get("icon", ""))), "key": "F"},
		],
		"items": [items_s.call("icon", "ruzgar_eldiveni"), items_s.call("icon", "anka_kusunun_kalbi"), items_s.call("icon", "zaman_kiran")],
		"pet": pets.call("icon", "peri"),
		"level": 12, "xp_ratio": 0.62,
		"hp": 96.0, "hp_max": 130.0, "sh": 113.0, "sh_max": 150.0,
		"hearts": 2, "heart_timer": "4:12",
		"gold": 1240, "shards": 3,
		"allies": allies,
		"mission": {"title": "Konvoyu Koru", "cur": 3, "max": 5},
		"minimap": hud.get_node_or_null("MinimapControl"),
	}


## Düğümün ekrandaki dikdörtgeni (ölçek dahil; dock 0,92 ölçekli). Görünmüyorsa boş.
func _gr(c: Variant) -> Rect2:
	if c == null or not (c is Control) or not is_instance_valid(c):
		return Rect2()
	var ctl: Control = c
	if not ctl.is_visible_in_tree():
		return Rect2()
	var xf: Transform2D = ctl.get_global_transform_with_canvas()
	var a: Vector2 = xf * Vector2.ZERO
	var b: Vector2 = xf * ctl.size
	return Rect2(a, b - a)


## V2 (bugünkü yerleşim) için gerçek HUD geometrisi - HUD gizlenmeden ÖNCE okunur.
func _geo(hud: Node, main: Node, data: Dictionary) -> Dictionary:
	var g: Dictionary = {}
	g["frame"] = _gr(hud.get("dock_frame"))
	g["legend"] = _gr(hud.get("dock_legend"))
	g["pet"] = _gr(hud.get("dock_pet"))
	g["toggle"] = _gr(hud.get("dock_stats_toggle"))
	g["divider"] = _gr(hud.get("dock_divider"))
	g["hp"] = _gr(hud.get("dock_hp_bar"))
	g["sh"] = _gr(hud.get("dock_shield_bar"))
	g["portrait"] = _gr(hud.get_node_or_null("CharacterCluster/PortraitFrame"))
	g["badge"] = _gr(hud.get_node_or_null("CharacterCluster/LevelBadge"))
	g["q"] = _gr(hud.get_node_or_null("SkillBar/SkillIcon"))
	g["e"] = _gr(hud.get_node_or_null("SkillBar/Skill2Icon"))
	g["r"] = _gr(hud.get("skill3_icon"))
	g["f"] = _gr(hud.get("spirit_icon"))
	g["passive"] = _gr(hud.get_node_or_null("SkillBar/PassiveIcon"))
	g["hearts"] = _gr(hud.get("revive_hearts"))
	g["envanter"] = _gr(hud.get_node_or_null("EnvanterToggleButton"))
	g["gold"] = _gr(hud.get_node_or_null("GoldIndicator"))
	g["shard"] = _gr(hud.get("_shard_indicator"))
	g["xp"] = _gr(hud.get_node_or_null("XPBar"))
	var mm: Control = hud.get_node_or_null("MinimapControl") as Control
	if mm:
		var mxf: Transform2D = mm.get_global_transform_with_canvas()
		g["minimap_pos"] = mxf.origin
		g["minimap_center"] = mxf * Vector2(82, 82)
	var lg: Control = hud.get("dock_legend") as Control
	if lg:
		var lxf: Transform2D = lg.get_global_transform_with_canvas()
		var ls: GDScript = lg.get_script() as GDScript
		var cells: Array = []
		for c: Vector2 in ls.get("CELLS"):
			cells.append(Rect2(lxf * c, lxf.get_scale() * Vector2(40, 40)))
		g["legend_cells"] = cells
		g["legend_shield"] = Rect2(lxf * (ls.get("SHIELD_CELL") as Vector2), lxf.get_scale() * Vector2(40, 40))
		g["legend_icons"] = lg.get("_icons")
		g["legend_shield_tex"] = lg.get("_shield_tex")
	var pp: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
	var party: Array = []
	if pp:
		var rows: Dictionary = pp.get("_rows")
		var ids: Array = rows.keys()
		ids.sort()
		for id in ids:
			var row: Object = rows[id]
			var av: TextureRect = row.get("avatar") as TextureRect
			party.append({"row": _gr(row.get("container")), "avatar": _gr(av), "name": _gr(row.get("name_label")),
				"hp": _gr(row.get("health_bar")), "sh": _gr(row.get("shield_bar")), "gold_btn": _gr(row.get("gold_button")),
				"portrait": av.texture if av else null})
		g["dmg_btn"] = _gr(pp.get("_stats_button"))
	g["party"] = party
	var banner: Node = main.get_node_or_null("WorldEventBannerLayer/WorldEventBanner")
	if banner:
		var brows: Dictionary = banner.get("_rows")
		if brows.has(1):
			g["banner"] = _gr((brows[1] as Dictionary).get("panel"))
	for k in g:
		if g[k] is Rect2:
			print("GEO ", k, " ", g[k])
	return g


## SOLG prototipi için veriler + gerçek düğümleri gizler (madde 480).
func _solg_data(hud: Node, main: Node) -> Dictionary:
	var sgd: Dictionary = {}
	sgd["env"] = _gr(hud.get_node_or_null("EnvanterToggleButton"))
	sgd["gold"] = _gr(hud.get_node_or_null("GoldIndicator"))
	sgd["shard"] = _gr(hud.get("_shard_indicator"))
	var gl: Label = hud.get("gold_indicator_label") as Label
	sgd["gold_text"] = gl.text if gl else "0"
	var shn: Node = hud.get("_shard_indicator")
	sgd["shard_text"] = "0"
	if shn:
		for c in shn.find_children("*", "Label", true, false):
			sgd["shard_text"] = (c as Label).text
	for nn in ["EnvanterToggleButton", "GoldIndicator"]:
		var c2: CanvasItem = hud.get_node_or_null(nn) as CanvasItem
		if c2:
			c2.visible = false
	if shn:
		(shn as CanvasItem).visible = false
	var rows_out: Array = []
	var pp: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
	if pp:
		var rows: Dictionary = pp.get("_rows")
		var ids: Array = rows.keys()
		ids.sort()
		for id in ids:
			var row: Object = rows[id]
			var hb: Control = row.get("health_bar")
			var sb: Control = row.get("shield_bar")
			var av: TextureRect = row.get("avatar") as TextureRect
			var avbg: TextureRect = row.get("avatar_bg") as TextureRect
			var nl: Label = row.get("name_label") as Label
			var dl: Label = row.get("downed_label") as Label
			rows_out.append({"row": _gr(row.get("container")), "avatar": _gr(av), "name": _gr(nl), "hp": _gr(hb), "sh": _gr(sb),
				"gold_btn": _gr(row.get("gold_button")), "name_text": nl.text if nl else "", "face": av.texture if av else null,
				"bg": avbg.texture if avbg else null, "downed": dl != null and dl.visible,
				"hp_ratio": hb.get("ratio"), "hp_fill": hb.get("fill"), "hp_text": hb.get("text"),
				"sh_ratio": sb.get("ratio"), "sh_text": sb.get("text")})
		sgd["dmg"] = _gr(pp.get("_stats_button"))
		var ppl: CanvasLayer = hud.get_node_or_null("PartyPanelLayer") as CanvasLayer
		if ppl:
			ppl.visible = false ## panel kendini her karede yeniden görünür yapıyor -> katmanı gizle
	sgd["rows"] = rows_out
	var banner: Node = main.get_node_or_null("WorldEventBannerLayer/WorldEventBanner")
	if banner:
		var brows: Dictionary = banner.get("_rows")
		if brows.has(1):
			sgd["banner"] = {"rect": _gr((brows[1] as Dictionary).get("panel")), "title": "Konvoyu Koru", "cur": 3, "max": 5}
		(banner as CanvasItem).visible = false
	var notices: Array = []
	var NoticeScript: Script = load("res://scripts/game_notice.gd")
	sgd["kind_colors"] = NoticeScript.get("KIND_COLOR")
	for cl in main.get_children():
		if not (cl is CanvasLayer):
			continue
		for c3 in cl.get_children():
			if c3 is Control and (c3 as Control).get_script() == NoticeScript and str(c3.get("variant")) == "toast":
				notices.append({"rect": _gr(c3), "kind": c3.get("kind"), "title": c3.get("title"), "countdown": c3.get("countdown")})
				(cl as CanvasLayer).visible = false
	notices.sort_custom(func(a, b): return (a["rect"] as Rect2).position.y < (b["rect"] as Rect2).position.y)
	sgd["notices"] = notices
	print("SOLG ", sgd.keys(), " rows=", rows_out.size(), " notices=", notices.size())
	return sgd


## SOHBET (2026-11-08): aynı 5 mesaj, aynı yazılan metin, oyuncunun + solundaki müttefik sprite'ının (Mira, isim etiketiyle) başında balon.
## simdi = gerçek ChatLayer + gerçek chat_bubble.gd; A-D = gerçek ChatLayer gizli, tools/proto_20261108/sohbet/sohbet_proto.gd.
func _sohbet(st: String, hud: Node, main: Node, player: Node2D) -> void:
	const TYPED := "geliyorum, 30 saniye"
	const B_PLAYER := "geliyorum, bekleyin!"
	var nm: Node = root.get_node("NetworkManager")
	nm.set("local_player_name", "Deniz")
	var DK: GDScript = load("res://scripts/menu_dark_kit.gd") as GDScript
	var PF: GDScript = load("res://scripts/portrait_face.gd") as GDScript
	var raw: Array = [["Mira", 1, 10, "kuzeydoğuda elit var, bekleyin"], ["Kerem", 2, 5, "tamam geliyorum"],
		["Deniz", 0, CHAR_ID, "satıcı geldi, iksir alıp dönüyorum"], ["Mira", 1, 10, "Ağacı Koru başlıyor, herkes ağacın yanına gelsin"],
		["Kerem", 2, 5, "kalkan totemini ben koyarım"]]
	var msgs: Array = []
	for r in raw:
		msgs.append({"name": r[0], "col": DK.call("player_color", int(r[1])), "text": r[3],
			"face": PF.call("face", int(r[2]), 16), "bg": PF.call("background", int(r[2]), 16)})
	var b_ally: String = str(raw[3][3])
	## Müttefik: oyuncu sahnesiyle aynı düzen (kök 0,5, sprite 1,27575 + ofset), isim etiketi remote_player_name.gd.
	var ally := Node2D.new()
	ally.scale = Vector2(0.5, 0.5)
	main.add_child(ally)
	ally.global_position = player.global_position + Vector2(-210, 6)
	var spr := AnimatedSprite2D.new()
	var cdef: Dictionary = (load("res://scripts/characters.gd") as GDScript).call("get_def", 10)
	var fr: SpriteFrames = load(str(cdef.get("frames", ""))) as SpriteFrames
	spr.sprite_frames = fr
	spr.scale = Vector2(1.27575, 1.27575)
	spr.offset = Vector2(0, -5)
	var anim: StringName = &"idle_down" if fr.has_animation(&"idle_down") else fr.get_animation_names()[0]
	spr.play(anim)
	ally.add_child(spr)
	var nl := Label.new()
	nl.set_script(load("res://scripts/remote_player_name.gd"))
	nl.text = "Mira"
	ally.add_child(nl)
	if st == "simdi":
		## Madde 499'den sonra "simdi" = OYUNDAKİ C (chat_window.gd + yeni chat_bubble.gd); 3. mesajdan sonra bir altın hediyesi satırı.
		var emo: Dictionary = {1: " :begen:", 4: " :kalp:"} ## emoji jetonları (chat_emoji.gd)
		for i in msgs.size():
			var m: Dictionary = msgs[i]
			hud.call("append_chat_message", m["name"], str(m["text"]) + str(emo.get(i, "")), int(raw[i][2]), m["col"])
			if i == 2 and OS.get_environment("SOHBET_GIFT") != "0":
				hud.call("append_chat_gift", "Kerem", msgs[1]["col"], "Deniz", msgs[2]["col"], 50)
		player.call("show_chat_bubble", B_PLAYER + " :ates:")
		var rb := Node2D.new()
		rb.set_script(load("res://scripts/chat_bubble.gd"))
		ally.add_child(rb)
		rb.call("show_message", b_ally)
		await _wait(0.6)
		await _shot("sohbet_simdi_oku.png")
		hud.call("_open_chat_input")
		var le: LineEdit = hud.get("_chat_input") as LineEdit
		le.text = TYPED
		le.caret_column = TYPED.length()
		le.caret_blink = false
		var cv: Node = hud.get("_chat_view")
		if cv and OS.get_environment("SOHBET_PICKER") != "0":
			cv.call("_set_picker", true)
		await _wait(0.4)
		await _shot("sohbet_simdi_yaz.png")
		return
	var cl: CanvasLayer = hud.get("_chat_layer") as CanvasLayer
	if cl:
		cl.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 40
	main.add_child(layer)
	var ui: Control = (load("res://tools/proto_20261108/sohbet/sohbet_proto.gd") as GDScript).new()
	layer.add_child(ui)
	ui.call("setup_chat", st, {"msgs": msgs, "typing": false, "typed": TYPED})
	player.add_child(ui.call("make_bubble", B_PLAYER))
	ally.add_child(ui.call("make_bubble", b_ally))
	await _wait(0.6)
	await _shot("sohbet_%s_oku.png" % st)
	ui.call("set_typing", true)
	await _wait(0.4)
	await _shot("sohbet_%s_yaz.png" % st)


func _run() -> void:
	await process_frame
	## madde 508: HUDY_STRETCH=viewport -> oyun 1920x1080'de çizilir, bitmiş kare pencereye büyütülür (yazı 1080p şeklini korur)
	if OS.get_environment("HUDY_STRETCH") == "viewport":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	## madde 508: HUDY_NO_OVERSAMPLING=1 -> font yeniden çizimi kapalı (fontlar taban boyda rasterlanır, sonra doku gibi büyür)
	print("OVS root.oversampling=", root.get("oversampling"), " setting=", ProjectSettings.get_setting("gui/fonts/dynamic_fonts/use_oversampling", "yok"))
	if OS.get_environment("HUDY_NO_OVERSAMPLING") == "1":
		if "oversampling" in root:
			root.set("oversampling", false)
		ProjectSettings.set_setting("gui/fonts/dynamic_fonts/use_oversampling", false)
		print("OVS kapandı -> root.oversampling=", root.get("oversampling"))
	_dir = OS.get_environment("HUDY_DIR")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261108/hud_yeni/out")
	DirAccess.make_dir_recursive_absolute(_dir)
	AudioServer.set_bus_mute(0, true)
	var proto: String = OS.get_environment("HUD_PROTO")
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
	## Bugünkü HUD da prototiplerle AYNI durumu göstersin: sv 12 (Q/E/R açık), %62 XP, 1.240 altın, 3 parçacık.
	if player:
		player.set("level", 12)
	gm.set("gold", 1240)
	gm.call("add_weapon_shards", 3)
	if hud:
		hud.call("update_level", 12)
		hud.call("update_xp", 62.0, 100.0)
		## Çubuk yazısı biçimi (madde 511): BAR_TEXT=outline -> eski piksel yazı (karşılaştırma için; varsayılan yumuşak)
		var btxt: String = OS.get_environment("BAR_TEXT")
		if btxt != "":
			var tbars: Array = [hud.get("dock_hp_bar"), hud.get("dock_shield_bar")]
			var ppn: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
			if ppn:
				for prow in (ppn.get("_rows") as Dictionary).values():
					tbars.append(prow.get("health_bar"))
					tbars.append(prow.get("shield_bar"))
			for tb in tbars:
				if tb is Control and "value_style" in tb:
					tb.set("value_style", btxt)
					(tb as Control).queue_redraw()
		## Can/kalkan çubuğu görünüş prototipi (2026-11-08): BAR_PROTO=<A..D> -> dock çubuklarına bar_proto.gd takılır, değerler korunur.
		var bproto: String = OS.get_environment("BAR_PROTO")
		if bproto != "":
			var bscript: GDScript = load("res://tools/proto_20261108/bar_proto/bar_proto.gd") as GDScript
			for bn in ["dock_hp_bar", "dock_shield_bar"]:
				var bar: Control = hud.get(bn) as Control
				if bar == null:
					continue
				var keep: Dictionary = {}
				for k in ["ratio", "fill", "under", "text", "font_size", "merged", "icon_kind", "value_color"]:
					keep[k] = bar.get(k)
				for ch in bar.get_children():
					if ch.name == "ValueLayer": ## taban betiğin değer katmanı; yeni betik kendi katmanını kurar
						ch.queue_free()
				bar.set_script(bscript)
				for k in keep:
					bar.set(k, keep[k])
				bar.set("proto_style", bproto)
				bar.queue_redraw()
		## Portre arka planı prototipi (madde 458 devamı): PORTRE_BG=<A..D> -> tools/proto_20261108/portre_bg/out/tex/<X>_dock/_party.png
		var pbg: String = OS.get_environment("PORTRE_BG")
		if pbg != "":
			var tdir: String = ProjectSettings.globalize_path("res://tools/proto_20261108/portre_bg/out/tex/")
			var dock_tex := ImageTexture.create_from_image(Image.load_from_file(tdir + pbg + "_dock.png"))
			var party_tex := ImageTexture.create_from_image(Image.load_from_file(tdir + pbg + "_party.png"))
			var fr: TextureRect = hud.get_node_or_null("CharacterCluster/PortraitFrame") as TextureRect
			if fr:
				fr.texture = dock_tex
			var pp: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
			if pp:
				var prow: Dictionary = pp.get("_rows")
				for id in prow:
					var av: TextureRect = (prow[id] as Object).get("avatar") as TextureRect
					if av and av.get_parent() and av.get_parent().get_child_count() > 0:
						var bgr: TextureRect = av.get_parent().get_child(0) as TextureRect
						if bgr:
							bgr.texture = party_tex
		if OS.get_environment("HUD_STATS") == "1": ## mini stat panelini açık yakala (madde 454 doğrulaması)
			var tgl: Node = hud.get_node_or_null("DockStatsToggle")
			if tgl:
				tgl.call("set_open", true)
		var gl: Label = hud.get("gold_indicator_label") as Label
		if gl:
			gl.text = "1240"
	await _wait(0.6)
	if hud and player:
		player.set("health", 96.0)
	var v2: bool = proto.length() == 2 and proto.ends_with("2")
	if proto != "" and hud:
		var data: Dictionary = _data(hud)
		var geo: Dictionary = _geo(hud, main, data) if v2 else {}
		(hud as CanvasLayer).visible = false
		## HUD'un içindeki ayrı CanvasLayer'lar (grup paneli katmanı) ebeveynin görünürlüğünü almaz -> tek tek gizle.
		for cl in hud.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
		for path in ["WorldEventBannerLayer"]:
			var n2: Node = main.get_node_or_null(path)
			if n2 is CanvasLayer:
				(n2 as CanvasLayer).visible = false
			elif n2 is CanvasItem:
				(n2 as CanvasItem).visible = false
		var layer := CanvasLayer.new()
		layer.layer = (hud as CanvasLayer).layer
		main.add_child(layer)
		if v2:
			data["hearts"] = 3
			data["heart_timer"] = "-:--"
			data["skills"][2].erase("cd")
			var ui2: Control = (load("res://tools/proto_20261108/hud_yeni/hud_proto_v2.gd") as GDScript).new()
			layer.add_child(ui2)
			ui2.call("setup_v2", proto.substr(0, 1), data, geo)
		else:
			var ui: Control = (load("res://tools/proto_20261108/hud_yeni/hud_proto.gd") as GDScript).new()
			layer.add_child(ui)
			ui.call("setup", proto, data)
	await _wait(1.0)
	if player:
		player.set("health", 96.0)
		if OS.get_environment("REGEN_DEMO") == "1": ## madde 476: çubuk sağındaki "+N" yenilenme yazısı için örnek değer (12,5 / 5 sn = 2,5/sn)
			player.set("item_health_regen", 12.5)
	await _wait(0.4 if OS.get_environment("REGEN_DEMO") == "1" else 0.2)
	## Can/kalkan çubuğu animasyon kaydı (madde 470): BAR_ANIM=1 -> hasar (0,4 sn) + iyileşme (2,2 sn), her karede çubuk bölgesi
	## out/anim/f_###.png + zaman damgaları out/anim/zaman.txt (GIF'i bar_anim_gif.py kurar).
	if hud and player and OS.get_environment("BAR_ANIM") == "1":
		var adir: String = _dir.path_join("anim")
		DirAccess.make_dir_recursive_absolute(adir)
		var stamps: PackedStringArray = []
		var t_start: int = Time.get_ticks_msec()
		var did_hit: bool = false
		var did_heal: bool = false
		var fi: int = 0
		while Time.get_ticks_msec() - t_start < 3600:
			var el: float = float(Time.get_ticks_msec() - t_start) / 1000.0
			if not did_hit and el >= 0.4:
				did_hit = true
				player.set("health", 55.0)
				player.emit_signal("health_changed", 55.0, float(player.get("max_health"))) ## gerçek hasarla aynı yol
				hud.call("_on_item_shield_changed", 60.0, 150.0)
			if not did_heal and el >= 2.2:
				did_heal = true
				player.set("health", 125.0)
				player.emit_signal("health_changed", 125.0, float(player.get("max_health")))
			paused = false
			await RenderingServer.frame_post_draw
			var fimg: Image = root.get_texture().get_image()
			if fimg.get_width() != 1920: ## _shot ile aynı: gizli pencere gerçek boyutu farklı olabilir
				fimg.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
			fimg.get_region(Rect2i(725, 982, 470, 66)).save_png(adir.path_join("f_%03d.png" % fi))
			stamps.append(str(Time.get_ticks_msec() - t_start))
			fi += 1
		var zf := FileAccess.open(adir.path_join("zaman.txt"), FileAccess.WRITE)
		zf.store_string("\n".join(stamps))
		zf.close()
		print("ANIM kare=", fi)
	## Sol üst + grup paneli + Hasar + bildirim prototipleri (madde 480): SOLG=simdi|A|B|C|D. Hepsinde iki gerçek bildirim (satıcı geldi +
	## sayaçlı görev uyarısı) açılır; A-D'de bu parçaların gerçek düğümleri gizlenir, verileri tools/proto_20261108/sol_grup/sol_grup_proto.gd'ye.
	var solg: String = OS.get_environment("SOLG")
	if hud and solg != "":
		main.call("_show_notice", "merchant", "Seyyar satıcı geldi", "", 999.0)
		main.call("_show_notice", "warn", "Ağacı Koru başlıyor", "", 30.0, 30.0)
		await _wait(0.8)
		if solg != "simdi":
			var sgd: Dictionary = _solg_data(hud, main)
			var sl := CanvasLayer.new()
			sl.layer = 60
			main.add_child(sl)
			var sui: Control = (load("res://tools/proto_20261108/sol_grup/sol_grup_proto.gd") as GDScript).new()
			sl.add_child(sui)
			sui.call("setup_sg", solg, sgd)
			await _wait(0.4)
	## Sohbet penceresi + balon prototipleri (2026-11-08): SOHBET=<simdi|A..D> -> sohbet_<X>_oku.png (yazı kutusu kapalı) + sohbet_<X>_yaz.png.
	var sohbet: String = OS.get_environment("SOHBET")
	if hud and player and sohbet != "":
		await _sohbet(sohbet, hud, main, player)
		quit()
		return
	## Can yeşili adayları (madde 473): HP_CANDS="simdi,3cb043,..." -> her aday x HP_PCTS oranı için gerçek dock can çubuğu yakalanır
	## (out/hpsw/<i>_<j>.png). "simdi" = eski RGB karışımı, diğerleri HudTheme.hp_color(pct, aday). Sayfayı hp_swatch.py kurar.
	if hud and player and OS.get_environment("HP_CANDS") != "":
		var hb: Control = hud.get("dock_hp_bar") as Control
		var sdir: String = _dir.path_join("hpsw")
		DirAccess.make_dir_recursive_absolute(sdir)
		player.set("health", float(player.get("max_health")))
		await _wait(0.3)
		hb.set_process(false)
		hb.set("_anim_t", 3.0) ## parlaklık geçişi dışında
		var cands: PackedStringArray = OS.get_environment("HP_CANDS").split(",")
		var pcts: PackedStringArray = OS.get_environment("HP_PCTS").split(",") if OS.get_environment("HP_PCTS") != "" else PackedStringArray(["1.0", "0.7", "0.35", "0.12"])
		var HT = load("res://scripts/hud_theme.gd")
		var fss: PackedStringArray = OS.get_environment("HP_FS").split(",") if OS.get_environment("HP_FS") != "" else PackedStringArray()
		if not fss.is_empty(): ## HP_FS="10,11,12" -> satırlar yazı boyu (renk = ilk aday)
			cands.resize(fss.size())
			cands.fill(OS.get_environment("HP_CANDS").split(",")[0])
		for i in cands.size():
			if not fss.is_empty():
				hb.set("value_fs", int(fss[i]))
			for j in pcts.size():
				var pc: float = float(pcts[j])
				var col: Color = Color(0.84, 0.22, 0.22).lerp(Color(0.36, 0.78, 0.29), pc) if cands[i] == "simdi" else HT.hp_color(pc, Color("#" + cands[i]))
				hb.set("_shown", -1.0)
				hb.call("set_values", pc, col, "%d/250" % int(round(pc * 250.0)))
				await RenderingServer.frame_post_draw
				var simg: Image = root.get_texture().get_image()
				if simg.get_width() != 1920:
					simg.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
				var rr: Rect2i = Rect2i(hb.get_global_rect().grow(6.0))
				simg.get_region(rr).save_png(sdir.path_join("%d_%d.png" % [i, j]))
		print("HPSW ", cands.size(), "x", pcts.size())
		quit()
		return
	if hud and OS.get_environment("BAR_DEBUG") == "1":
		for bn in ["dock_hp_bar", "dock_shield_bar"]:
			var bdbg: Control = hud.get(bn) as Control
			if bdbg:
				print("BARDBG ", bn, " text=", bdbg.get("text"), " merged=", bdbg.get("merged"), " bar_px=", bdbg.get("_bar_px"), " script=",
					(bdbg.get_script() as Script).resource_path, " rect=", bdbg.get_global_rect(), " vis=", bdbg.is_visible_in_tree())
	var out_name: String = ("proto_%s.png" % proto) if proto != "" else "simdi.png"
	if OS.get_environment("HUDY_OUT") != "":
		out_name = OS.get_environment("HUDY_OUT")
	await _shot(out_name)
	quit()
