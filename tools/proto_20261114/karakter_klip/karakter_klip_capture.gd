extends SceneTree

## KARAKTER TANITIM KLİPLERİ (2026-11-14, kullanıcı isteği): her karakter temasına uygun haritada, ekrana bakan idle pozunda; sağda Q/E/R/pasif
## ikonları + İngilizce adları. GERÇEK Main (harita gölgelendiricileri, ağaç sallanması, su, hava) - HUD gizlenir, oyuncu işlemesi durdurulur.
## Koşturucu: karakter_klip_run.ps1 (gizli masaüstü, APPDATA yalıtılır, --fixed-fps 30).
##   KK_MODE=survey  KK_MAPS="ana,bataklik,..."  -> her haritanın kuşbakışı + koordinat ızgarası (survey_<harita>.png)
##   KK_MODE=clip    [KK_ONLY="1,3"] [KK_STILL=1] [KK_SPEC="id:harita:x:y;..."] -> <id>/f_0000.jpg... (KK_STILL=1: tek kare still_<id>.png)
##   KK_MODE=weapon  [KK_ONLY="dagger,kalkan"] [KK_STILL=1] [KK_SEED=n] -> SİLAH KLİPLERİ (2026-11-14 ikinci istek): her silah, temasına uyan
##                   karakter havuzundan rastgele (dengeli) bir karakterle, o karakterin harita noktasında; yakında 3 hareketsiz ölümsüz hedef, silah
##                   gerçekten saldırır. Kalkan: soldaki büyücü yaratıktan gelen mermileri siper duruşuyla bloklar (madde 685), sonra yanına gelen
##                   hedefi döver. Çıktı <NN>_<Silah>_<Karakter>/f_*.jpg.
## Ortak: KK_DIR çıktı klasörü, KK_ZOOM kamera yakınlığı (tamsayı; karakter pikseli tam ekran pikseline yuvarlanır).

const FPS := 30
const CLIP_SEC := 6.0
const WARM_FRAMES := 75
const SCREEN := Vector2(1920, 1080)

## id -> [harita, x, y, saat (cycle_time sn; 0-330 gündüz, 330-390 gün batımı), hava]   x < 0: evden çıkış noktası.
## Yer işaretleri tools/<harita>/gen_*.py REGIONS'tan (dünya = (yerel hücre + (32, 20)) x 16 + 8); karakter yer işaretinin sağ önünde
## (sağ taraf panelin altında kalır). KK_SPEC ile ezilebilir.
const SPOTS := {
	1: ["ana", -1.0, -1.0, 150.0, 0], ## Talon: ana harita, ev önü (oyunun başladığı yer)
	2: ["ana", 1850.0, 2250.0, 150.0, 0], ## Oakley: çiçekli çayır
	3: ["kis", 3940.0, 1075.0, 150.0, 0], ## Matthew: Kristal Vadisi
	4: ["col", 1225.0, 1010.0, 150.0, 0], ## Lyra: Küre Tapınağı
	5: ["bataklik", 3600.0, 1640.0, 365.0, 0], ## Kestrel: ölü orman, gün batımı
	7: ["kis", 4160.0, 4000.0, 150.0, 0], ## Aldric: Eski Harabe
	8: ["ana", 1453.0, 2090.0, 150.0, 0], ## Elara: göl köprüsü
	9: ["col", 3150.0, 3560.0, 150.0, 0], ## Flint: Büyük Vaha kıyısı
	10: ["kis", 2795.0, 2300.0, 150.0, 0], ## Seraphine: Kadim Buz Ağacı
	11: ["bataklik", 2500.0, 3280.0, 150.0, 0], ## Corvina: kemik tarlası
	12: ["kis", 1185.0, 995.0, 150.0, 0], ## Ulric: Ayı Totemi Tapınağı
	13: ["batik_nekropol", 1745.0, 1680.0, 150.0, 0], ## Nox: nekropol
	14: ["col", 2215.0, 2300.0, 150.0, 0], ## Hadime: Firavun Vadisi
	15: ["bataklik", 1090.0, 950.0, 150.0, 0], ## Hazel: cadı oyuğu
}

## Silah -> temasına uyan karakterler (silah modunda bunlardan rastgele, kullanım sayısı en az olanlar arasından, art arda aynı karakter olmadan).
const WEAPON_POOLS := {
	"dagger": [5, 13, 1], "fire_staff": [4, 12, 15], "lightning_staff": [3, 4, 12], "tabanca": [8, 9, 1], "tuftuf": [15, 11, 2],
	"tufek": [8, 1, 9], "arcane": [4, 10, 11], "yay": [8, 2, 5], "crossbow": [5, 1, 7], "boomerang": [5, 3, 1], "buz_asasi": [4, 10, 14],
	"fisek": [9, 1], "pence": [11, 14, 13], "topuz": [7, 12, 1], "uzunkilic": [7, 1, 10], "gokkusagi": [2, 10, 4], "mizrak": [7, 12, 1],
	"kalkan": [7, 10], "yinyang": [14, 4, 10], "pompali": [9, 1, 8], "makineli": [1, 8, 9],
}
## Silah modunda nokta değişikliği: hedefler suya / dekorun arkasına düşmesin (Elara köprüsü -> ana harita çayırı, Flint kumsala,
## Ulric totemlerin altına).
const WEAPON_SPOT_OVERRIDE := {
	8: ["ana", 2600.0, 2560.0, 150.0, 0],
	9: ["col", 3150.0, 3604.0, 150.0, 0],
	12: ["kis", 1185.0, 1035.0, 150.0, 0],
}
## Hedefler oyuncuya göre (dünya birimi; yakın dövüş menzili ~55): sağ, sol, alt - sudan kaçınmak için yukarı yok.
const TARGET_OFFSETS := [Vector2(48, 6), Vector2(-44, 14), Vector2(4, 46)]
const WEAPON_ZOOM := 6.0
const WEAPON_SEC := 5.0
const KALKAN_SEC := 8.0
const PLAYER_SCREEN := Vector2(640, 620) ## silah modunda karakterin ekran konumu
## Kalkan klibi: karakter aşağıda, atıcı sol üstte (kalkanın baş üstü yuvasına doğru gelen atış kalkanın hemen önünde söner).
const PLAYER_SCREEN_KALKAN := Vector2(700, 850)

var _out: String = OS.get_environment("KK_DIR")
var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _zoom: float = float(OS.get_environment("KK_ZOOM")) if OS.get_environment("KK_ZOOM") != "" else 8.0
var _font: FontFile = null
var _ht: GDScript = null
var _mute: Array = []
var _keep: Array = [] ## silah modunda bizim koyduğumuz yaratıklar (diğerleri temizlenir)
var _pscreen: Vector2 = PLAYER_SCREEN


func _pre_draw() -> void:
	for n in _mute:
		if is_instance_valid(n):
			(n as CanvasItem).visible = false


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	_ht = load("res://scripts/hud_theme.gd")
	_font = load("res://assets/fonts/m5x7.ttf")
	if OS.get_environment("KK_MODE") == "survey":
		await _survey()
	elif OS.get_environment("KK_MODE") == "weapon":
		await _weapons()
	else:
		await _clips()
	print("BITTI")
	quit()


## ------------------------------------------------------------------ açılış
func _boot(char_id: int, map_id: String, time: float, weather: int, start_weapon: String = "") -> bool:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_map", map_id)
	if start_weapon != "":
		_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(70)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	## Ana harita açılışı (madde 313): deprem + kamera sarsıntısı + oyuncunun üstünde korku balonu (fear_emote.gd) çıkmasın -> evre DONE.
	var intro: Node = _main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	await _frames(60)
	_player = _main.get_node_or_null("Player") as Node2D
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", time)
		atmo.call("debug_set_weather", weather)
		atmo.call("debug_set_time_scale", 0.0)
	return _player != null


func _clear_world() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)


## HUD + oyun üstü katmanlar gizlenir (dünya rengi/vinyet katmanları kalır - adlar keşifte basılır).
func _hide_hud() -> void:
	var keep: PackedStringArray = PackedStringArray(["VignetteOverlay"])
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
		(hud as CanvasLayer).offset = Vector2(100000, 100000)
	## Ev kapısı ipucu / "CANAVARLAR GELİYOR" sayacı her karede yeniden açılıyor: işlemeyi durdur + katmanı ekran dışına it.
	for nm in ["HouseInterior", "TravelingMerchant"]:
		var h: Node = _main.get_node_or_null(nm)
		if h:
			h.set_process(false)
	for n in _all_nodes(root):
		if n is CanvasLayer and n != hud and n.has_meta("kk_ui") == false:
			var cl := n as CanvasLayer
			if cl.layer >= 5 and not keep.has(String(cl.name)):
				cl.visible = false
				cl.offset = Vector2(100000, 100000)
		elif n is Label and not n.has_meta("kk_ui") and n.get_viewport() == root and _is_world_label(n as Label):
			(n as Label).visible = false
		elif n is CanvasItem and n.get_script() != null and str((n.get_script() as Script).resource_path).ends_with("fear_emote.gd"):
			(n as CanvasItem).visible = false ## açılış depreminin korku balonu (yedek; evre DONE'a alınınca hiç çıkmamalı)
			if not _mute.has(n):
				_mute.append(n)


## Dünyada duran oyun yazıları (kapı ipucu vb.): CanvasLayer altında olmayan Label'lar.
func _is_world_label(l: Label) -> bool:
	var p: Node = l.get_parent()
	while p != null:
		if p is CanvasLayer:
			return false
		p = p.get_parent()
	return true


func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func _dump_tree() -> void:
	for n in _all_nodes(root):
		if n is CanvasLayer:
			print("CL ", n.get_path(), " layer=", (n as CanvasLayer).layer, " vis=", (n as CanvasLayer).visible)
	for c in _player.get_children():
		print("PC ", c.name, " ", c.get_class(), " vis=", (c as CanvasItem).visible if c is CanvasItem else "-",
				" script=", str((c.get_script() as Script).resource_path) if c.get_script() else "")
	for c in _main.get_children():
		print("MC ", c.name, " ", c.get_class(), " script=", str((c.get_script() as Script).resource_path) if c.get_script() else "")


func _setup_camera(center_world: Vector2, zoom: float) -> Camera2D:
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(zoom, zoom)
	cam.offset = center_world - _player.global_position
	cam.force_update_scroll()
	return cam


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


## ------------------------------------------------------------------ keşif
func _survey() -> void:
	var first := true
	for m in OS.get_environment("KK_MAPS").split(","):
		if not await _boot(1, m, 150.0, 0):
			print("BOOT FAIL ", m)
			continue
		_clear_world()
		_player.set_process(false)
		_player.set_physics_process(false)
		if first:
			_dump_tree()
			first = false
		_hide_hud()
		var rect := Rect2(0, 0, 4608, 4608)
		if _gm.has_method("get_map_world_rect"):
			rect = _gm.call("get_map_world_rect")
		print("RECT ", m, " ", rect)
		var z: float = minf(SCREEN.x / rect.size.x, SCREEN.y / rect.size.y)
		_player.global_position = rect.get_center()
		_setup_camera(rect.get_center(), z)
		var grid: Node2D = Node2D.new()
		grid.set_script(load("res://tools/proto_20261114/karakter_klip/grid_overlay.gd"))
		grid.set("rect", rect)
		grid.set("zoom", z)
		grid.z_index = 4000
		grid.z_as_relative = false
		_main.add_child(grid)
		await _frames(20)
		await _shot(_out.path_join("survey_%s.png" % m))


## ------------------------------------------------------------------ klipler
func _spots() -> Dictionary:
	var d: Dictionary = SPOTS.duplicate()
	for item in OS.get_environment("KK_SPEC").split(";", false):
		var p: PackedStringArray = item.split(":")
		if p.size() >= 4:
			d[int(p[0])] = [p[1], float(p[2]), float(p[3]), float(p[4]) if p.size() > 4 else 150.0, int(p[5]) if p.size() > 5 else 0]
	return d


func _clips() -> void:
	var spots: Dictionary = _spots()
	var only: PackedStringArray = OS.get_environment("KK_ONLY").split(",", false)
	var still: bool = OS.get_environment("KK_STILL") == "1"
	TranslationServer.set_locale("en")
	var ids: Array = spots.keys()
	ids.sort()
	for id in ids:
		if not only.is_empty() and not only.has(str(id)):
			continue
		var s: Array = spots[id]
		if not await _boot(int(id), s[0], s[3], s[4]):
			print("BOOT FAIL ", id)
			continue
		TranslationServer.set_locale("en")
		_clear_world()
		_player.set_process(false)
		_player.set_physics_process(false)
		if float(s[1]) >= 0.0:
			_player.global_position = Vector2(s[1], s[2])
		print("SPOT ", id, " ", s[0], " ", _player.global_position)
		_hide_hud()
		_pose_player(int(id))
		var cam: Camera2D = _setup_camera(Vector2.ZERO, _zoom)
		## Karakter ekranın sol üçte birinde: kamera merkezi oyuncunun sağında.
		cam.offset = Vector2((SCREEN.x * 0.5 - 600.0) / _zoom, (SCREEN.y * 0.5 - 600.0) / _zoom)
		for k in WARM_FRAMES / 15:
			await _frames(15)
			_clear_world()
			_hide_hud()
		var ui: CanvasLayer = _build_ui(int(id))
		if still:
			await _frames(int(FPS * 1.6))
			_hide_hud()
			await _shot(_out.path_join("still_%d.png" % id))
		else:
			var dir: String = _out.path_join(str(id))
			DirAccess.make_dir_recursive_absolute(dir)
			var n: int = int(CLIP_SEC * FPS)
			for f in n:
				if f % 10 == 0:
					_clear_world()
					_hide_hud()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(dir.path_join("f_%04d.jpg" % f), 0.95)
				await process_frame
			print("CLIP ", id, " frames=", n)
		ui.queue_free()


func _pose_player(id: int, keep_weapons: bool = false) -> void:
	for nm in ["NameLabel", "OverheadBar", "DownedTimerLabel", "ShieldVisual"]:
		var n: Node = _player.get_node_or_null(nm)
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	_mute.clear()
	for c in _player.get_children():
		var sc: Variant = c.get_script()
		var file: String = str((sc as Script).resource_path).get_file() if sc != null else ""
		if "weapon" in file and not keep_weapons:
			(c as CanvasItem).visible = false
		elif file in ["chat_bubble.gd", "overhead_bar.gd"] or String(c.name) in ["NameLabel", "OverheadBar", "DownedTimerLabel", "ShieldVisual"]:
			_mute.append(c) ## sohbet balonu (ana haritada açılışta emoji balonu çıkıyordu) her çizimden önce gizlenir
	if not RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.connect(_pre_draw)
	var spr: AnimatedSprite2D = _player.get_node("AnimatedSprite2D")
	if not keep_weapons:
		spr.play("idle_down")
	## Keskin piksel: karakter pikseli tamsayı ekran pikseline yuvarlanır (oyunda ~0,9 dünya birimi).
	var root_k: float = absf(_player.global_scale.x)
	var world_px: float = absf(spr.scale.x) * root_k
	var target: float = maxf(1.0, roundf(world_px * _zoom)) / _zoom
	spr.scale = Vector2(signf(spr.scale.x), signf(spr.scale.y)) * target / root_k
	print("POSE ", id, " world_px=", world_px, " -> ", target, " screen_px=", target * _zoom)


## ------------------------------------------------------------------ arayüz
func _tr(s: String) -> String:
	return String(TranslationServer.translate(StringName(s)))


func _split_passive_name(desc: String) -> Array:
	var i: int = desc.find(": ")
	if i <= 0 or i > 28:
		return ["", desc]
	var head: String = desc.substr(0, i)
	if head == head.to_upper():
		return ["", desc]
	var re := RegEx.new()
	re.compile("[0-9(),%]")
	if re.search(head) != null:
		return ["", desc]
	return [head, desc.substr(i + 2)]


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = _ht.get("OUTLINE")
	l.label_settings = ls
	l.text = text
	return l


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBox:
	var b: StyleBox = (load("res://scripts/pixel_box.gd") as GDScript).new()
	b.set("bg_color", bg)
	b.set("border_color", border)
	b.call("set_border_width_all", bw)
	b.call("set_corner_radius_all", radius)
	return b


func _build_ui(id: int) -> CanvasLayer:
	var def: Dictionary = (load("res://scripts/characters.gd") as GDScript).get_def(id)
	var ui := CanvasLayer.new()
	ui.layer = 120
	ui.set_meta("kk_ui", true)
	root.add_child(ui)
	var rows: Array = []
	var set_re := RegEx.new()
	set_re.compile("\\s*\\((Set|Takım)[^)]*\\)\\s*$") ## Lyra: "Arcane Curse (Set 1/2)" -> taban ad
	for k in [["skill_name", "skill_icon", "Q"], ["skill2_name", "skill2_icon", "E"], ["skill3_name", "skill3_icon", "R"]]:
		rows.append([set_re.sub(_tr(str(def.get(k[0], ""))), ""), str(def.get(k[1], "")), k[2], false])
	var pdesc: String = _tr(str(def.get("passive", "")))
	var pn: Array = _split_passive_name(pdesc)
	var pname: String = str(def.get("passive_name", pn[0])) if def.has("passive_name") else str(pn[0])
	## Adlı pasif: ad + altında küçük "Passive"; adsız pasif: yalnız "Passive" (ikonda tuş etiketi yok).
	var psub: String = _tr("Pasif") if pname != "" else ""
	if pname == "":
		pname = _tr("Pasif")
	rows.append([pname, str(def.get("passive_icon", "")), psub, true])
	print("NAMES ", id, " ", _tr(str(def.get("name", ""))), " | ", rows.map(func(r: Array) -> String: return r[0]))

	## Karakter adı: başın üstünde (oyuncu ekranda x=600, y=600).
	var name_l: Label = _label(_tr(str(def.get("name", ""))), 96, _ht.get("ACCENT"), 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(800, 110)
	name_l.position = Vector2(600 - 400, float(OS.get_environment("KK_NAME_Y")) if OS.get_environment("KK_NAME_Y") != "" else 600.0 - 24.0 * _zoom - 110.0)
	name_l.modulate.a = 0.0
	ui.add_child(name_l)
	var tw: Tween = name_l.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(name_l, "modulate:a", 1.0, 0.45)

	## Sağ sütun: ikon kuyusu + ad. Q/E/R 48 px ikon x3, pasif x2 (çizimdeki küçük kutu).
	var x0: float = 1040.0
	var y: float = 180.0
	var i: int = 0
	for r in rows:
		var passive: bool = r[3]
		var k: float = 2.0 if passive else 3.0
		var icon_px: float = 48.0 * k
		var row := Control.new()
		row.position = Vector2(x0 + (24.0 if passive else 0.0), y)
		row.modulate.a = 0.0
		ui.add_child(row)
		var well := Panel.new()
		well.add_theme_stylebox_override("panel", _box(_ht.get("INSET"), _ht.get("RIM"), 6, 6))
		well.size = Vector2(icon_px + 12, icon_px + 12)
		row.add_child(well)
		if ResourceLoader.exists(r[1]):
			var tr_ := TextureRect.new()
			tr_.texture = load(r[1])
			tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_SCALE
			tr_.size = Vector2(icon_px, icon_px)
			tr_.position = Vector2(6, 6)
			well.add_child(tr_)
		var mid: float = (icon_px + 12) * 0.5
		if not passive:
			var key: Label = _label(r[2], 48, _ht.get("TEXT"), 9)
			key.position = Vector2(icon_px - 22.0, icon_px - 30.0)
			key.size = Vector2(40, 40)
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			well.add_child(key)
		elif r[2] != "":
			var sub: Label = _label(r[2], 32, _ht.get("DIM"), 9)
			sub.position = Vector2(icon_px + 46, mid + 14)
			sub.size = Vector2(600, 40)
			row.add_child(sub)
			mid -= 14.0
		var nl: Label = _label(r[0], 64, _ht.get("TEXT"), 15)
		nl.position = Vector2(icon_px + 44, mid - 40)
		nl.size = Vector2(800, 80)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nl)
		var tw2: Tween = row.create_tween()
		## Sıralı giriş: her satır kendi gecikmesiyle (set_parallel + aralık birlikte kullanılınca aralık da paralel sayılıyordu).
		var d: float = 0.45 + 0.14 * i
		tw2.set_parallel(true)
		tw2.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(d)
		tw2.tween_property(row, "position:x", row.position.x, 0.35).from(row.position.x + 60.0).set_delay(d) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		y += icon_px + 12 + 36.0
		i += 1
	return ui


## ------------------------------------------------------------------ silah klipleri (KK_MODE=weapon)
## Her silaha havuzundan karakter: en az kullanılanlar arasından rastgele, bir önceki klibin karakteri olmadan (tohumlu -> tekrarlanabilir).
func _weapon_plan() -> Array:
	## Her karakter en az bir kez görünsün: tohumu ilerleterek 14 karakterin hepsini kapsayan ilk planı al.
	var base: int = int(OS.get_environment("KK_SEED")) if OS.get_environment("KK_SEED") != "" else 20261114
	var plan: Array = []
	for t in 500:
		plan = _weapon_plan_seed(base + t)
		var seen: Dictionary = {}
		for it in plan:
			seen[it[1]] = true
		if seen.size() >= SPOTS.size():
			print("PLAN SEED ", base + t)
			break
	return plan


func _weapon_plan_seed(seed_value: int) -> Array:
	var keys: Array = (load("res://scripts/weapon_catalog.gd") as GDScript).get("KEYS")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var used: Dictionary = {}
	var prev: int = -1
	var plan: Array = []
	for k in keys:
		var pool: Array = (WEAPON_POOLS.get(k, [1]) as Array).duplicate()
		if pool.size() > 1:
			pool.erase(prev)
		var least: int = 1 << 30
		for c in pool:
			least = mini(least, int(used.get(c, 0)))
		var cands: Array = pool.filter(func(c: int) -> bool: return int(used.get(c, 0)) == least)
		var cid: int = cands[rng.randi_range(0, cands.size() - 1)]
		used[cid] = int(used.get(cid, 0)) + 1
		prev = cid
		plan.append([k, cid])
	return plan


func _spawn_creature(scene_path: String, pos: Vector2) -> Node2D:
	var e: Node2D = (load(scene_path) as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	_keep.append(e)
	return e


## Haritanın kendi yaratıkları (zindan odaları, kamplar...) kadraja girip oyuncuya saldırmasın: bizimkiler dışındakiler silinir.
func _clear_others() -> void:
	for e in get_nodes_in_group("enemies"):
		if not _keep.has(e):
			e.queue_free()


func _fire_at_player(from: Vector2) -> void:
	var p: Node2D = (load("res://scenes/enemy_projectile.tscn") as PackedScene).instantiate()
	var to: Vector2 = _player.global_position + Vector2(0, -8)
	p.set("direction", (to - from).normalized().rotated(randf_range(-0.06, 0.06)))
	p.set("damage", 5.0)
	_main.add_child(p)
	p.global_position = from


func _weapons() -> void:
	var cat: GDScript = load("res://scripts/weapon_catalog.gd")
	var only: PackedStringArray = OS.get_environment("KK_ONLY").split(",", false)
	var still: bool = OS.get_environment("KK_STILL") == "1"
	_zoom = WEAPON_ZOOM
	var plan: Array = _weapon_plan()
	print("PLAN ", plan)
	var idx: int = 0
	for item in plan:
		idx += 1
		var key: String = item[0]
		var cid: int = item[1]
		if not only.is_empty() and not only.has(key):
			continue
		var s: Array = WEAPON_SPOT_OVERRIDE.get(cid, SPOTS[cid])
		if not await _boot(cid, s[0], s[3], s[4], key):
			print("BOOT FAIL ", key)
			continue
		TranslationServer.set_locale("en")
		_clear_world()
		if float(s[1]) >= 0.0:
			_player.global_position = Vector2(s[1], s[2])
		_hide_hud()
		_pose_player(cid, true)
		_pscreen = PLAYER_SCREEN_KALKAN if key == "kalkan" else PLAYER_SCREEN
		## Kendi kameramız (oyuncunun kamerası sarsıntı/harita sınırıyla oynar; sarsıntı delta eklediği için bunda da çalışır).
		var cam := Camera2D.new()
		cam.zoom = Vector2(_zoom, _zoom)
		cam.position_smoothing_enabled = false
		_main.add_child(cam)
		cam.global_position = _player.global_position + (SCREEN * 0.5 - _pscreen) / _zoom
		cam.make_current()
		var kalkan: bool = key == "kalkan"
		var shooter: Node2D = null
		var shooter_pos := Vector2.ZERO
		_keep.clear()
		if kalkan:
			shooter = _spawn_creature("res://scenes/creatures/enemy_iskelet1.tscn", _player.global_position + Vector2(-50, -106)) ## sol üst, kalkan menzilinin (110) DIŞINDA -> kalkan saldırmaz, siper duruşunda bloklar
		else:
			for o in TARGET_OFFSETS:
				_spawn_creature("res://scenes/creatures/enemy_slime1.tscn", _player.global_position + o)
		for k in 4:
			await _frames(15)
			_hide_hud()
			_clear_others()
		var wname: String = _tr(str(cat.call("display_name", key)))
		var cname: String = _tr(str((load("res://scripts/characters.gd") as GDScript).get_def(cid).get("name", "")))
		var ui: CanvasLayer = _build_weapon_ui(cid, key, wname)
		var dirname: String = "%02d_%s_%s" % [idx, wname.replace(" ", ""), cname]
		print("WEAPON ", dirname)
		var n: int = int((KALKAN_SEC if kalkan else WEAPON_SEC) * FPS)
		var dir: String = _out.path_join(dirname)
		if not still:
			DirAccess.make_dir_recursive_absolute(dir)
		for f in n:
			if f % 10 == 0:
				_hide_hud()
			if f % 5 == 0:
				_clear_others()
			if kalkan and OS.get_environment("KK_DIAG") == "1" and f % 30 == 0:
				print("DIAG f=", f, " valid=", is_instance_valid(shooter), " ", (str(shooter.global_position) + " vis=" + str(shooter.is_visible_in_tree()) + " mod=" + str(shooter.modulate) + " hp=" + str(shooter.get("health")) + " st=" + str(shooter.get("_state")) + " kids=" + str(shooter.get_children().map(func(c: Node) -> String: return c.name + ":" + str(c.visible if c is CanvasItem else "-")))) if is_instance_valid(shooter) else "")
			if kalkan and is_instance_valid(shooter):
				if shooter_pos == Vector2.ZERO:
					shooter_pos = shooter.global_position
				shooter.global_position = shooter_pos ## geri tepme / itilme kadrajdan çıkarmasın
			if kalkan and is_instance_valid(shooter) and f % 13 == 0 and f < n - 20:
				_fire_at_player(shooter.global_position + Vector2(8, -14))
			if kalkan and f == 140:
				_spawn_creature("res://scenes/creatures/enemy_slime1.tscn", _player.global_position + Vector2(-26, -44)) ## kalkan şimdi döver (atışla aynı yönde)
			if still and f == 52:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.path_join("wstill_%s.png" % key))
				print("SHOT wstill_", key)
				if not kalkan:
					break
			if still and kalkan and f == 175:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.path_join("wstill_%s_b.png" % key))
				break
			if not still:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(dir.path_join("f_%04d.jpg" % f), 0.95)
			await process_frame
		if not still:
			print("CLIP ", dirname, " frames=", n)
		ui.queue_free()


## Sağ panel: silah ikonu (menü ikonu, x3 kuyuda) + İngilizce adı + Melee/Ranged; karakter adı başının üstünde.
func _build_weapon_ui(cid: int, key: String, wname: String) -> CanvasLayer:
	var cat: GDScript = load("res://scripts/weapon_catalog.gd")
	var def: Dictionary = (load("res://scripts/characters.gd") as GDScript).get_def(cid)
	var ui := CanvasLayer.new()
	ui.layer = 120
	ui.set_meta("kk_ui", true)
	root.add_child(ui)
	var name_l: Label = _label(_tr(str(def.get("name", ""))), 64, _ht.get("ACCENT"), 15)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(600, 80)
	name_l.position = Vector2(_pscreen.x - 300, _pscreen.y - 24.0 * _zoom - 92.0)
	name_l.modulate.a = 0.0
	ui.add_child(name_l)
	name_l.create_tween().tween_property(name_l, "modulate:a", 1.0, 0.4).set_delay(0.1)

	var row := Control.new()
	row.position = Vector2(1180, 540 - 90)
	row.modulate.a = 0.0
	ui.add_child(row)
	var icon_px: float = 144.0
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", _box(_ht.get("INSET"), _ht.get("RIM"), 6, 6))
	well.size = Vector2(icon_px + 12, icon_px + 12)
	row.add_child(well)
	var tex: Texture2D = cat.call("menu_icon", key)
	if tex != null:
		var tr_ := TextureRect.new()
		tr_.texture = tex
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_.size = Vector2(icon_px, icon_px)
		tr_.position = Vector2(6, 6)
		well.add_child(tr_)
	var nl: Label = _label(wname, 64, _ht.get("TEXT"), 15)
	nl.position = Vector2(icon_px + 44, (icon_px + 12) * 0.5 - 58)
	nl.size = Vector2(700, 80)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nl)
	var sub: Label = _label(_tr(str(cat.call("category_label", key))), 32, _ht.get("DIM"), 9)
	sub.position = Vector2(icon_px + 46, (icon_px + 12) * 0.5 + 18)
	sub.size = Vector2(600, 40)
	row.add_child(sub)
	var tw: Tween = row.create_tween()
	tw.set_parallel(true)
	tw.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(0.35)
	tw.tween_property(row, "position:x", row.position.x, 0.35).from(row.position.x + 60.0).set_delay(0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return ui
