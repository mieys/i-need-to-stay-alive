extends SceneTree

## TEK OYUNCULU + ODA LİSTESİ/ODA KUR + ÇOK OYUNCULU SEÇİM ekranlarının PANEL RENGİ prototipleri (2026-10-17, oyuna bağlı DEĞİL).
## Kullanıcı: "tek oyuncu ve çok oyunculu + oda kurma panelinin rengini ana menüyle uyumlu bir renkte olacak şekilde 4 prototip hazırla (tasarımı değiştirme)".
## Yerleşim AYNI: gerçek ekran betikleri (lobby_select_desktop / character_select / room_browser / menu_hearth_bg) kopyalanır, sadece koyu kitin
## (menu_dark_kit.gd) renk sabitleri + iki sabit renk (hazır kilidi örtüsü, arka plan örtüsü) palete göre değiştirilir; kopyalar
## out/panel_renk/kod/ altına yazılıp yüklenir (gerçek dosyalara dokunulmaz). Gerçek çizici, 1920x1080:
##   Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/panel_renk_proto.gd
## Çıktı tools/proto_20261017/out/panel_renk/<palet>_{tek,oda,cok}.png + ana_menu.png (özetleri panel_renk_ozet.py çizer).
## PR_ONLY=a,b (isteğe bağlı) sadece o paletleri çeker.

const OUT := "res://tools/proto_20261017/out/panel_renk/"
const KOD := OUT + "kod/"

const KIT := "res://scripts/menu_dark_kit.gd"
const LSD := "res://scripts/lobby_select_desktop.gd"
const CS := "res://scripts/character_select.gd"
const RB := "res://scripts/room_browser.gd"
const HB := "res://scripts/menu_hearth_bg.gd"

## Palet = koyu kit sabitleri (+ LOCK: hazır kilidi örtüsü, DIM: arka plan örtüsünün rengi). "simdi" = koddaki güncel renkler (karşılaştırma).
## C SEÇİLDİ ve oyunda (madde 248): LOCK/DIM yer değiştirmeleri eski renk metnini arar, artık eşleşmez (o iki renk koddakiyle kalır).
const PALETTES := {
	"simdi": {},
	## A - Kehribar Ocak: ana menünün KENDİ yazı paleti (altın başlık, krem yazı, kum alt yazı, menü düğmesi kenarı #45372a) + koyu ceviz paneller.
	"a": {
		"C_PANEL": "#1b130ddb", "C_PANEL2": "#251a12", "C_PANEL3": "#35261a", "C_INSET": "#120c08",
		"C_LINE": "#45372a", "C_LINE_HI": "#6b5541", "C_TEXT": "#efe2c6", "C_DIM": "#b09878",
		"C_ACCENT": "#f4c56e", "C_ACCENT_DK": "#6e4c1c", "C_ACCENT_TEXT": "#2a1806", "C_GOOD": "#b4d67e",
		"C_BAD": "#dc7f60", "C_PRICE": "#f0da94", "C_SPOT": "#c0803a",
		"LOCK": "Color(0.07, 0.04, 0.02, 0.45)", "DIM": "Color(0.05, 0.03, 0.02)",
	},
	## B - Ceviz Tahta: odanın tahta zemini gibi daha açık kızıl-kahve paneller, şömine ateşi turuncusu vurgu.
	"b": {
		"C_PANEL": "#362317e6", "C_PANEL2": "#432c1d", "C_PANEL3": "#573924", "C_INSET": "#20140c",
		"C_LINE": "#684528", "C_LINE_HI": "#9a6b44", "C_TEXT": "#f6e7cf", "C_DIM": "#c4a283",
		"C_ACCENT": "#f29c4c", "C_ACCENT_DK": "#7a3814", "C_ACCENT_TEXT": "#2b1004", "C_GOOD": "#c2d27a",
		"C_BAD": "#e2705a", "C_PRICE": "#f6d58a", "C_SPOT": "#d27a36",
		"LOCK": "Color(0.09, 0.04, 0.02, 0.45)", "DIM": "Color(0.06, 0.03, 0.02)",
	},
	## C - Gece Sıvası: odanın mavi-mor sıva duvarı paneller, ana menünün altın + krem yazısı vurgu (soğuk zemin, sıcak ışık).
	"c": {
		"C_PANEL": "#1a1a2ce0", "C_PANEL2": "#23233a", "C_PANEL3": "#302f4c", "C_INSET": "#12121f",
		"C_LINE": "#3b3a5a", "C_LINE_HI": "#5f5c86", "C_TEXT": "#efe6d6", "C_DIM": "#a7a2c0",
		"C_ACCENT": "#f4c56e", "C_ACCENT_DK": "#6a5226", "C_ACCENT_TEXT": "#231a0a", "C_GOOD": "#a8d69a",
		"C_BAD": "#e38c7c", "C_PRICE": "#f0da94", "C_SPOT": "#b98a4a",
		"LOCK": "Color(0.04, 0.04, 0.08, 0.45)", "DIM": "Color(0.03, 0.03, 0.06)",
	},
	## D - Kızıl Kor: közün koyu şarap kırmızısı paneller, bakır vurgu.
	"d": {
		"C_PANEL": "#2a100ddb", "C_PANEL2": "#371713", "C_PANEL3": "#4d201a", "C_INSET": "#1a0807",
		"C_LINE": "#62291f", "C_LINE_HI": "#964536", "C_TEXT": "#f4e2cf", "C_DIM": "#c39a8a",
		"C_ACCENT": "#f0a46a", "C_ACCENT_DK": "#7a3418", "C_ACCENT_TEXT": "#2a0e06", "C_GOOD": "#b9d282",
		"C_BAD": "#ff7f6e", "C_PRICE": "#f4d08a", "C_SPOT": "#c8603a",
		"LOCK": "Color(0.08, 0.02, 0.02, 0.45)", "DIM": "Color(0.06, 0.02, 0.02)",
	},
}

const FAKE_ROOMS := [
	{"host_id": "p1", "room_name": "Gece avı", "host_name": "Ali", "players": 2, "max_players": 4, "locked": true, "in_game": false},
	{"host_id": "p2", "room_name": "Herkes gelsin", "host_name": "Mert", "players": 1, "max_players": 8, "locked": false, "in_game": false},
	{"host_id": "p3", "room_name": "Dolu oda", "host_name": "Veli", "players": 3, "max_players": 3, "locked": false, "in_game": false},
	{"host_id": "p4", "room_name": "Kademe 10 koşusu", "host_name": "Ayşe", "players": 4, "max_players": 6, "locked": false, "in_game": true},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KOD))
	create_timer(300.0).timeout.connect(func() -> void: print("PANEL_RENK_TIMEOUT"); quit(1))
	for i in 10:
		await process_frame
	## Ayar autoload'u kayıtlı tam ekranı uygular -> pencereli 1920x1080'e zorla (yakalama 1:1, masaüstünü kaplamasın).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _settle(0.5)
	var only: PackedStringArray = OS.get_environment("PR_ONLY").split(",", false)
	var nm: Node = root.get_node("NetworkManager")
	## Ana menü (karşılaştırma için bir kez).
	if only.is_empty():
		var mm: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(mm)
		current_scene = mm
		await _settle(2.0)
		_save("ana_menu.png")
		mm.queue_free()
		await _settle(0.2)
	for key: String in PALETTES:
		if not only.is_empty() and not only.has(key):
			continue
		var paths: Dictionary = _write_variants(key, PALETTES[key])
		## 1) Tek oyunculu (character_select.gd masaüstü = lobby_select_desktop solo kipi).
		var cs: Control = _screen(paths["cs"])
		await _settle(1.6)
		_save("%s_tek.png" % key)
		cs.queue_free()
		await _settle(0.2)
		## 2) Oda listesi + oda kur (sahte 4 oda, şifreli odanın şifre satırı açık).
		var rb: Control = _screen(paths["rb"])
		await _settle(0.4)
		var t: Variant = rb.get("_online_timer")
		if t is Timer:
			(t as Timer).stop()
		var rooms: Array = []
		for r: Dictionary in FAKE_ROOMS:
			rooms.append(r.duplicate())
		rb.set("_online_rooms", rooms)
		rb.set("_online_searched", true)
		rb.set("_pw_key", "eos:p1")
		rb.call("_rebuild_list")
		await _settle(1.6)
		_save("%s_oda.png" % key)
		rb.queue_free()
		await _settle(0.2)
		## 3) Çok oyunculu seçim (lobby_select_desktop, sahte 2 oyuncu: sen = host + hazır, Ali seçiyor).
		var saved_players: Dictionary = nm.get("lobby_players")
		var w: String = str(root.get_node("GameManager").get("selected_start_weapon"))
		nm.set("lobby_players", {
			0: {"name": str(nm.get("local_player_name")), "char_id": 1, "weapon": w, "spirit": "", "is_host": true, "is_ready": true},
			7: {"name": "Ali", "char_id": 4, "weapon": "dagger", "spirit": "", "is_host": false, "is_ready": false},
		})
		nm.set("room_name", "Test odası")
		nm.set("room_code", "192.168.1.105:7791")
		nm.set("room_max_players", 4)
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.size = Vector2(1920, 1080)
		root.add_child(holder)
		current_scene = holder
		holder.theme = load(paths["kit"]).theme()
		load(paths["hb"]).add_to(holder, load(paths["hb"]).DIM_DESKTOP)
		var desk: Control = load(paths["lsd"]).new()
		holder.add_child(desk)
		desk.call("build")
		desk.call("show_character", 1, false)
		desk.call("refresh")
		await _settle(1.6)
		_save("%s_cok.png" % key)
		holder.queue_free()
		nm.set("lobby_players", saved_players)
		await _settle(0.2)
	print("PANEL_RENK_DONE")
	quit()


func _screen(path: String) -> Control:
	var c: Control = load(path).new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.size = Vector2(1920, 1080)
	root.add_child(c)
	current_scene = c
	return c


## Arayüz animasyonları (ui_anim.gd: pencere açılışı, liste girişi, sahne geçişi) ZAMANA bağlı - kare sayısıyla değil saniyeyle bekle.
func _settle(sec: float) -> void:
	await create_timer(sec).timeout
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("kaydedildi ", name, " ", img.get_size())


## Palet kopyaları: kit sabitleri değişir; ekran betikleri kopyalanıp preload yolları kopyalara çevrilir.
func _write_variants(key: String, pal: Dictionary) -> Dictionary:
	var kit_src: String = FileAccess.get_file_as_string(KIT)
	for c: String in pal:
		if not c.begins_with("C_"):
			continue
		var re := RegEx.new()
		re.compile("const %s := Color\\(\"[^\"]*\"\\)" % c)
		if re.search(kit_src) == null:
			push_error("sabit bulunamadı: " + c)
		kit_src = re.sub(kit_src, "const %s := Color(\"%s\")" % [c, pal[c]])
	var p := {
		"kit": KOD + "kit_%s.gd" % key, "lsd": KOD + "lsd_%s.gd" % key, "cs": KOD + "cs_%s.gd" % key,
		"rb": KOD + "rb_%s.gd" % key, "hb": KOD + "hb_%s.gd" % key,
	}
	_put(p["kit"], kit_src)
	var swap := {
		"preload(\"%s\")" % KIT: "preload(\"%s\")" % p["kit"],
		"preload(\"%s\")" % LSD: "preload(\"%s\")" % p["lsd"],
		"preload(\"%s\")" % HB: "preload(\"%s\")" % p["hb"],
	}
	var hb_src: String = FileAccess.get_file_as_string(HB)
	if pal.has("DIM"):
		hb_src = hb_src.replace("const DIM_COLOR := Color(0.02, 0.03, 0.04)", "const DIM_COLOR := " + str(pal["DIM"]))
	_put(p["hb"], _swap(hb_src, swap))
	var lsd_src: String = FileAccess.get_file_as_string(LSD)
	if pal.has("LOCK"):
		lsd_src = lsd_src.replace("Color(0.02, 0.05, 0.05, 0.45)", str(pal["LOCK"]))
	_put(p["lsd"], _swap(lsd_src, swap))
	_put(p["cs"], _swap(FileAccess.get_file_as_string(CS), swap))
	_put(p["rb"], _swap(FileAccess.get_file_as_string(RB), swap))
	return p


func _swap(src: String, swap: Dictionary) -> String:
	for k: String in swap:
		src = src.replace(k, swap[k])
	return src


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
