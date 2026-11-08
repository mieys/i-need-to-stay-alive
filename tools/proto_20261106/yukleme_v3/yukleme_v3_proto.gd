extends SceneTree

## YÜKLEME EKRANI v3 PROTOTİPLERİ (2026-11-06, madde 408; oyuna BAĞLI DEĞİL).
## Kullanıcı: "yeni prototip hazırlar mısın hepsi berbat. ama ai olmasın." (Eski: Kaçış / Eve Dönüş / Mühürlü Kapı + madde 366 B/C/D.)
## "AI olmasın" = hafızadaki dersler: oyunun KENDİ sanatı ve kiti (gerçek çizici, gerçek karakter sayfaları, hud_theme paleti, m5x7
## 16/32/48 + PixeloidSans sayılar), hale/parıltı/dither/kenar karartması YOK, uydurma "lore" yazısı YOK, ışık sadece görünen kaynaktan.
## Stil rehberi bölüm 5: sıcak, kırsal, ocak başı; karanlık bölge ana renk olmaz (derin orman kapısı bu yüzden elendi).
##  A Evde      : gerçek ev içi (koşu burada başlar), akşam lambaları, tam ekran + altta koyu şerit (YÜKLENİYOR + çubuk + ipucu)
##  B Kartlar   : düz koyu zemin, oyuncu başına ahşap kart (büyük karakter, silah + evcil, KENDİ yükleme çubuğu / HAZIR)
##  C Sade      : düz koyu zemin, parti tek sıra yürür, altında ince çubuk + ipucu (Terraria/Stardew sadeliği)
##  D Çayır     : gerçek gündüz, evin önündeki çayır çerçeveli resim gibi, altında çubuk + ipucu
## Kullanım: tools/proto_20261106/yukleme_v3/yukleme_v3_run.ps1 [-Only "A,B"] ; birleştirme python .../yukleme_v3_ozet.py
## Çıktı out/raw/<x>_<kk>.png (FRAMES kare, ilerleme 0,06 -> 1,0).

const OUT_RAW := "res://tools/proto_20261106/yukleme_v3/out/raw/"
const FRAMES := 16
const FRAME_DT := 0.12
const W := 1920.0
const H := 1080.0

## Sahte parti (ilk = yerel oyuncu). "lag" = yüklemede ne kadar geride (B kartlarındaki çubuklar).
const PARTY: Array = [
	{"name": "Perva", "char": 2, "weapon": "fire_staff", "pet": "kirpi", "lag": 0.0},
	{"name": "Mieys", "char": 3, "weapon": "uzunkilic", "pet": "peri", "lag": 0.2},
	{"name": "Kuzgun", "char": 7, "weapon": "kalkan", "pet": "", "lag": 0.45},
	{"name": "Demir", "char": 4, "weapon": "gokkusagi", "pet": "papagan", "lag": 0.7},
]
const TIP := "Bir kademenin boss'u yaşadıkça yeni kademe başlamaz."

## Kamera: A ev içi oda merkezi (house_interior.gd yerel koordinatı; oda 16..624 x 48..336, şeridin üstü tam oda), D evin önü.
const A_INTERIOR_ORIGIN := Vector2(20000.0, 0.0) ## house_interior.gd INTERIOR_OFFSET (ev kökü 0,0'da)
const A_ROOM_CENTER := Vector2(320.0, 212.0)
const A_ZOOM := 3.0
const D_ZOOM := 3.0
const D_CAM_SHIFT := Vector2(0.0, -34.0) ## oyuncunun (kapı önü) üstüne: ev resmin üst yarısında
const D_PARTY_OFFS: Array = [Vector2(-54.0, 8.0), Vector2(50.0, 4.0), Vector2(98.0, 14.0)]

var HT = null
var Chars = null
var WTA = null
var PetCat = null
var F_M: Font = null
var F_N: Font = null
var _only: Array = []
var _upd: Callable = Callable()
var _main: Node = null
var _player: Node2D = null
var _cam: Camera2D = null


func _initialize() -> void:
	var env: String = OS.get_environment("YUKLEME_ONLY")
	if env != "":
		_only = Array(env.split(","))
	_run.call_deferred()


func _want(k: String) -> bool:
	return _only.is_empty() or _only.has(k)


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


## ---------------------------------------------------------------- akış
func _run() -> void:
	await process_frame
	HT = load("res://scripts/hud_theme.gd")
	Chars = load("res://scripts/characters.gd")
	WTA = load("res://scripts/weapon_tier_art.gd")
	PetCat = load("res://scripts/pet_catalog.gd")
	F_M = load("res://assets/fonts/m5x7.ttf")
	F_N = load("res://assets/fonts/PixeloidSans-Bold.ttf")
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_RAW))
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	var p0: Dictionary = PARTY[0]
	gm.set("selected_char_id", int(p0["char"]))
	gm.set("selected_character", Chars.get_def(int(p0["char"])).get("skill", 1))
	gm.set("selected_start_weapon", str(p0["weapon"]))
	gm.set("selected_pet", str(p0["pet"]))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(1.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = current_scene
	## Açılış sahnesi (deprem + geri sayım) dursun: çekim boyunca huzur evresi.
	var intro: Node = _main.find_child("HouseIntro", true, false)
	if intro:
		intro.set_process(false)
		print("DATA intro durduruldu ", intro.get_path())
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	_player = _main.get_node_or_null("Player") as Node2D
	for n: String in ["NameLabel", "OverheadBar", "DownedTimerLabel", "ShieldVisual"]:
		var ch: Node = _player.get_node_or_null(n)
		if ch is CanvasItem:
			(ch as CanvasItem).visible = false
	_cam = root.get_viewport().get_camera_2d()
	print("DATA player=", _player.global_position, " cam=", _cam.get_path(), " zoom=", _cam.zoom, " win=", root.get_visible_rect().size)
	await _wait(0.8)
	_hide_overlays()
	var atmo: Node = _main.get_node_or_null("Atmosphere")

	if _want("A"):
		if atmo:
			atmo.set("cycle_time", 384.0) ## gün batımı sonu: ev lambaları yanık, pencere gece camı
		_frame_cam(A_INTERIOR_ORIGIN + A_ROOM_CENTER, A_ZOOM)
		await _wait(1.2)
		var host: Control = _overlay_host()
		_build_a(host)
		await _capture("a")
		host.get_parent().queue_free()
		_upd = Callable()

	if _want("D"):
		var house: Node = _main.get_node_or_null("HouseInterior")
		if house and house.has_method("_do_exit_house"):
			house.call("_do_exit_house")
		await _wait(1.5)
		if atmo:
			atmo.set("cycle_time", 300.0) ## ikindi: tam gündüz, hafif sıcak
		_hide_overlays()
		_spawn_party_world()
		print("DATA disari player=", _player.global_position)
		_frame_cam(_player.global_position + D_CAM_SHIFT, D_ZOOM)
		await _wait(1.2)
		var host2: Control = _overlay_host()
		_build_d(host2)
		await _capture("d")
		host2.get_parent().queue_free()
		_upd = Callable()

	if _want("B"):
		var host3: Control = _overlay_host()
		_build_b(host3)
		await _wait(0.3)
		await _capture("b")
		host3.get_parent().queue_free()
		_upd = Callable()

	if _want("C"):
		var host4: Control = _overlay_host()
		_build_c(host4)
		await _wait(0.3)
		await _capture("c")
		host4.get_parent().queue_free()
		_upd = Callable()
	quit()


func _capture(prefix: String) -> void:
	for k in range(FRAMES):
		var t: float = lerpf(0.06, 1.0, float(k) / float(FRAMES - 1))
		if _upd.is_valid():
			_upd.call(t)
		_hide_overlays(true) ## sonradan açılan duyuru katmanları da
		await _wait(FRAME_DT)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img.get_size() != Vector2i(1920, 1080):
			img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img.save_png(ProjectSettings.globalize_path(OUT_RAW + "%s_%02d.png" % [prefix, k]))
	print("SHOT ", prefix)


## HUD / sis / sohbet gibi arayüz katmanları gizlenir; gün-gece renk katmanı, güneş/bulut ve ışık katmanları kalır.
func _hide_overlays(quiet: bool = false) -> void:
	var keep: Array = []
	var atmo: Node = _main.get_node_or_null("Atmosphere")
	if atmo and atmo.get("_overlay") != null:
		keep.append(atmo.get("_overlay"))
	for cl: Node in _all_layers(root):
		var l := cl as CanvasLayer
		if l.is_in_group("yv3") or keep.has(l):
			continue
		var nm: String = String(l.name).to_lower()
		var world_fx: bool = nm.contains("sun") or nm.contains("glow") or nm.contains("night") or nm.contains("light") \
			or nm.contains("grade") or nm.contains("atmos") or nm.contains("rain") or nm.contains("weather")
		if l.layer >= 1 and not world_fx or nm.contains("visionfog") or nm.contains("vignette"):
			if l.visible and not quiet:
				print("HIDE ", l.get_path(), " layer=", l.layer)
			l.visible = false
		elif not quiet:
			print("KEEP ", l.get_path(), " layer=", l.layer)


func _all_layers(n: Node) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is CanvasLayer:
			out.append(c)
		out.append_array(_all_layers(c))
	return out


func _frame_cam(center: Vector2, zoom: float) -> void:
	_cam.top_level = true
	_cam.position_smoothing_enabled = false
	_cam.limit_left = -10000000
	_cam.limit_top = -10000000
	_cam.limit_right = 10000000
	_cam.limit_bottom = 10000000
	_cam.zoom = Vector2.ONE * zoom
	_cam.global_position = center.round()
	_cam.offset = Vector2.ZERO
	_cam.force_update_scroll()


## D: yerel oyuncunun yanına diğer üç parti üyesi (gerçek karakter sayfası + oyuncunun kendi gölgesi/malzemesi).
func _spawn_party_world() -> void:
	var spr0: AnimatedSprite2D = null
	for c: Node in _player.get_children():
		if c is AnimatedSprite2D:
			spr0 = c
			break
	if spr0 == null:
		print("!! oyuncu sprite yok")
		return
	var shadow0: Node = _player.get_node_or_null("Shadow")
	var def0: Dictionary = Chars.get_def(int(PARTY[0]["char"]))
	var base0: float = (def0.get("scale", Vector2.ONE * 2.2368375) as Vector2).x
	spr0.play("idle_down")
	for i in range(1, PARTY.size()):
		var p: Dictionary = PARTY[i]
		var def: Dictionary = Chars.get_def(int(p["char"]))
		var holder := Node2D.new()
		holder.scale = _player.scale
		holder.z_index = _player.z_index
		_player.get_parent().add_child(holder)
		holder.global_position = _player.global_position + (D_PARTY_OFFS[i - 1] as Vector2)
		if shadow0:
			holder.add_child(shadow0.duplicate(0))
		var s: AnimatedSprite2D = spr0.duplicate(0) as AnimatedSprite2D
		s.sprite_frames = load(str(def["frames"])) as SpriteFrames
		var ratio: float = (def.get("scale", Vector2.ONE * 2.2368375) as Vector2).x / base0
		s.scale = spr0.scale * ratio
		holder.add_child(s)
		s.play("idle_down")
		s.frame = i * 2


## ---------------------------------------------------------------- yardımcılar
func _overlay_host() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.add_to_group("yv3")
	root.add_child(layer)
	var host := Control.new()
	host.size = Vector2(W, H)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	return host


func _rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _box(parent: Control, r: Rect2, bg: Color, line: Color, w: int = 3) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(w)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


## m5x7 boyları 16/32/48 (yazı pikseli = boy/16), PixeloidSans 9/18/27 (= boy/9). Gölge = 1 yazı pikseli, DEEP.
func _lbl(parent: Control, text: String, size: int, col: Color, pos: Vector2, w: float = 0.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, font: Font = null, shadow: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var f: Font = font if font else F_M
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if shadow:
		var o: int = maxi(1, size / (9 if f == F_N else 16))
		l.add_theme_color_override("font_shadow_color", HT.DEEP)
		l.add_theme_constant_override("shadow_offset_x", o)
		l.add_theme_constant_override("shadow_offset_y", o)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if w > 0.0:
		l.horizontal_alignment = align
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0.0)
	parent.add_child(l)
	l.position = pos
	if w > 0.0:
		l.size = Vector2(w, 0.0)
	return l


## "İPUCU" (vurgu) + ipucu metni tek satırda; x = -1 ise ortalanır.
func _tip_line(parent: Control, y: float, x: float, shadow: bool = false, tip_col: Color = Color(0, 0, 0, 0)) -> void:
	var head := "İPUCU  "
	var w1: float = F_M.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var w2: float = F_M.get_string_size(TIP, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var x0: float = x if x >= 0.0 else snappedf((W - w1 - w2) * 0.5, 3.0)
	_lbl(parent, head, 32, HT.ACCENT, Vector2(x0, y), 0.0, HORIZONTAL_ALIGNMENT_LEFT, null, shadow)
	_lbl(parent, TIP, 32, tip_col if tip_col.a > 0.0 else HT.DIM, Vector2(x0 + w1, y), 0.0, HORIZONTAL_ALIGNMENT_LEFT, null, shadow)


## Çubuk: kuyu (WIN_INSET + 3 px WIN_LINE) + 3 px boşluk + dolgu; genişlik 3 px adımla.
func _bar(parent: Control, r: Rect2, fill: Color) -> Dictionary:
	_box(parent, r, HT.WIN_INSET, HT.WIN_LINE, 3)
	var inner := Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12))
	var f: ColorRect = _rect(parent, Rect2(inner.position, Vector2(0.0, inner.size.y)), fill)
	return {"fill": f, "w": inner.size.x}


func _set_bar(b: Dictionary, ratio: float, col: Color = Color(0, 0, 0, 0)) -> void:
	var f: ColorRect = b["fill"]
	f.size.x = snappedf(float(b["w"]) * clampf(ratio, 0.0, 1.0), 3.0)
	if col.a > 0.0:
		f.color = col


static func _foot_offset(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var img: Image = tex.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		return img.get_height() * 0.5
	return float(used.end.y) - img.get_height() * 0.5


## Karakter: tam katlı ölçek (sanat pikseli = px ekran pikseli; Matthew gibi küçük karakterler oranlanır), ayak = foot.
func _char(parent: Node, char_id: int, anim: String, px: int, foot: Vector2) -> AnimatedSprite2D:
	var def: Dictionary = Chars.get_def(char_id)
	var frames: SpriteFrames = load(str(def["frames"])) as SpriteFrames
	var a: String = anim
	for cand: String in [anim, anim.replace("run_", "walk_"), "idle_down"]:
		if frames.has_animation(cand):
			a = cand
			break
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ratio: float = (def.get("scale", Vector2.ONE * 2.2368375) as Vector2).x / 2.2368375
	var sc: float = maxf(1.0, roundf(px * ratio))
	s.scale = Vector2.ONE * sc
	s.play(a)
	var fo: float = _foot_offset(frames.get_frame_texture(a, 0))
	s.position = Vector2(foot.x, foot.y - fo * sc).round()
	parent.add_child(s)
	return s


## Piksel elips gölge: satır satır dikdörtgen (karakterle aynı piksel ızgarası), düz renk.
func _shadow(parent: Control, c: Vector2, rx: float, ry: float, px: float) -> void:
	var rows: int = int(ceil(ry * 2.0 / px))
	for i in range(rows):
		var yc: float = -ry + (float(i) + 0.5) * px
		var hw: float = snappedf(rx * sqrt(maxf(0.0, 1.0 - (yc * yc) / (ry * ry))), px)
		if hw <= 0.0:
			continue
		_rect(parent, Rect2(c.x - hw, c.y - ry + float(i) * px, hw * 2.0, px), Color(HT.DEEP, 0.55))


## Simge kuyusu: tam katlı ölçek, ortalı.
func _icon_well(parent: Control, r: Rect2, tex: Texture2D) -> void:
	_box(parent, r, HT.WIN_INSET, HT.WIN_LINE, 3)
	if tex == null:
		return
	## Saydam payı kırp (yeni silah çizimleri geniş tuvalde): kullanılan dikdörtgen.
	var img: Image = tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size != img.get_size():
			tex = ImageTexture.create_from_image(img.get_region(used))
	var ts: Vector2 = tex.get_size()
	var sc: float = maxf(1.0, floorf((r.size.x - 18.0) / maxf(ts.x, ts.y)))
	if maxf(ts.x, ts.y) * sc > r.size.x - 12.0:
		sc = (r.size.x - 18.0) / maxf(ts.x, ts.y)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = (ts * sc).round()
	tr.position = (r.position + (r.size - tr.size) * 0.5).round()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


func _pct(t: float) -> String:
	return "%" + str(int(round(clampf(t, 0.0, 1.0) * 100.0)))


func _player_t(t: float, lag: float) -> float:
	return clampf(t * (1.0 + lag) - lag, 0.0, 1.0)


## ---------------------------------------------------------------- A Evde
func _build_a(host: Control) -> void:
	var y0: float = 912.0
	_rect(host, Rect2(0, y0, W, H - y0), Color(HT.DEEP, 0.9))
	_rect(host, Rect2(0, y0, W, 3), HT.WIN_LINE)
	_lbl(host, "YÜKLENİYOR", 48, HT.TEXT, Vector2(96, y0 + 18))
	var pct: Label = _lbl(host, "%0", 27, HT.PRICE, Vector2(1104, y0 + 27), 180.0, HORIZONTAL_ALIGNMENT_RIGHT, F_N)
	var bar: Dictionary = _bar(host, Rect2(96, y0 + 87, 1188, 24), HT.ACCENT)
	_lbl(host, "İPUCU", 32, HT.ACCENT, Vector2(1440, y0 + 24))
	_lbl(host, TIP, 32, HT.DIM, Vector2(1440, y0 + 60), 384.0)
	_upd = func(t: float) -> void:
		_set_bar(bar, t)
		pct.text = _pct(t)


## ---------------------------------------------------------------- B Kartlar
func _build_b(host: Control) -> void:
	_rect(host, Rect2(0, 0, W, H), HT.DEEP)
	var head: Label = _lbl(host, "YÜKLENİYOR", 48, HT.TEXT, Vector2(0, 42), W, HORIZONTAL_ALIGNMENT_CENTER)
	var cw: float = 381.0
	var gap: float = 36.0
	var x0: float = snappedf((W - cw * 4.0 - gap * 3.0) * 0.5, 3.0)
	var y0: float = 126.0
	var ch: float = 690.0
	var bars: Array = []
	for i in range(PARTY.size()):
		var p: Dictionary = PARTY[i]
		var cx: float = x0 + float(i) * (cw + gap)
		_box(host, Rect2(cx, y0, cw, ch), HT.WIN_PANEL, HT.WIN_LINE if i > 0 else HT.WIN_LINE_HI, 3)
		var well := Rect2(cx + 21, y0 + 21, cw - 42, 339)
		_box(host, well, HT.WIN_INSET, HT.WIN_INSET, 0)
		var foot := Vector2(snappedf(well.get_center().x, 3.0), well.end.y - 54.0)
		_shadow(host, foot, 66.0, 15.0, 6.0)
		_char(host, int(p["char"]), "idle_down", 6, foot)
		var def: Dictionary = Chars.get_def(int(p["char"]))
		_lbl(host, str(def.get("name", "?")), 48, HT.ACCENT, Vector2(cx, y0 + 378), cw, HORIZONTAL_ALIGNMENT_CENTER)
		_lbl(host, str(p["name"]), 32, HT.TEXT, Vector2(cx, y0 + 432), cw, HORIZONTAL_ALIGNMENT_CENTER)
		var iw: float = 72.0
		var ix: float = snappedf(cx + cw * 0.5 - iw - 9.0, 3.0)
		_icon_well(host, Rect2(ix, y0 + 489, iw, iw), WTA.texture(str(p["weapon"]), 1))
		var pet_tex: Texture2D = PetCat.icon(str(p["pet"])) if str(p["pet"]) != "" else null
		_icon_well(host, Rect2(ix + iw + 18.0, y0 + 489, iw, iw), pet_tex)
		var b: Dictionary = _bar(host, Rect2(cx + 21, y0 + 591, cw - 42, 24), HT.ACCENT)
		var st: Label = _lbl(host, "%0", 18, HT.PRICE, Vector2(cx, y0 + 630), cw, HORIZONTAL_ALIGNMENT_CENTER, F_N)
		bars.append([b, st, float(p["lag"])])
	_tip_line(host, 900.0, -1.0)
	_upd = func(t: float) -> void:
		var ready: int = 0
		for e: Array in bars:
			var pt: float = _player_t(t, float(e[2]))
			var lb: Label = e[1]
			if pt >= 1.0:
				ready += 1
				_set_bar(e[0], 1.0, HT.GOOD)
				lb.text = "HAZIR"
				lb.add_theme_font_override("font", F_M)
				lb.add_theme_font_size_override("font_size", 32)
				lb.add_theme_color_override("font_color", HT.GOOD)
			else:
				_set_bar(e[0], pt, HT.ACCENT)
				lb.text = _pct(pt)
		head.text = "YÜKLENİYOR" if ready < bars.size() else "OYUN BAŞLIYOR"


## ---------------------------------------------------------------- C Sade
func _build_c(host: Control) -> void:
	_rect(host, Rect2(0, 0, W, H), HT.DEEP)
	var foot_y: float = 516.0
	var step: float = 129.0
	var n: int = PARTY.size()
	for i in range(n):
		## Yerel oyuncu en önde (sağda), diğerleri arkasında tek sıra.
		var p: Dictionary = PARTY[i]
		var x: float = snappedf(W * 0.5 + (float(n - 1) * 0.5 - float(i)) * step, 3.0)
		_shadow(host, Vector2(x, foot_y), 40.0, 8.0, 4.0)
		var s: AnimatedSprite2D = _char(host, int(p["char"]), "walk_right", 4, Vector2(x, foot_y))
		s.frame = (i * 3) % maxi(1, s.sprite_frames.get_frame_count(s.animation))
	_lbl(host, "YÜKLENİYOR", 48, HT.TEXT, Vector2(0, 576), W, HORIZONTAL_ALIGNMENT_CENTER)
	var bw: float = 600.0
	var bar: Dictionary = _bar(host, Rect2(snappedf((W - bw) * 0.5, 3.0), 642, bw, 24), HT.ACCENT)
	var pct: Label = _lbl(host, "%0", 18, HT.PRICE, Vector2(0, 681), W, HORIZONTAL_ALIGNMENT_CENTER, F_N)
	_tip_line(host, 972.0, -1.0)
	_upd = func(t: float) -> void:
		_set_bar(bar, t)
		pct.text = _pct(t)


## ---------------------------------------------------------------- D Çayır
func _build_d(host: Control) -> void:
	var pic := Rect2(192, 72, 1536, 768)
	## Resmin dışı DEEP (dünya yalnız resim penceresinden görünür).
	_rect(host, Rect2(0, 0, W, pic.position.y), HT.DEEP)
	_rect(host, Rect2(0, pic.end.y, W, H - pic.end.y), HT.DEEP)
	_rect(host, Rect2(0, pic.position.y, pic.position.x, pic.size.y), HT.DEEP)
	_rect(host, Rect2(pic.end.x, pic.position.y, W - pic.end.x, pic.size.y), HT.DEEP)
	## Ahşap çerçeve: dış hat + 9 px ahşap + 3 px parlak iç kenar.
	_box(host, pic.grow(15), Color(0, 0, 0, 0), HT.OUTLINE, 3)
	_box(host, pic.grow(12), Color(0, 0, 0, 0), HT.RIM, 9)
	_box(host, pic.grow(3), Color(0, 0, 0, 0), HT.RIM_HI, 3)
	_lbl(host, "YÜKLENİYOR", 48, HT.TEXT, Vector2(pic.position.x, 870))
	var pct: Label = _lbl(host, "%0", 27, HT.PRICE, Vector2(pic.end.x - 240, 879), 240.0, HORIZONTAL_ALIGNMENT_RIGHT, F_N)
	var bar: Dictionary = _bar(host, Rect2(pic.position.x, 933, pic.size.x, 24), HT.ACCENT)
	_tip_line(host, 984.0, pic.position.x)
	_upd = func(t: float) -> void:
		_set_bar(bar, t)
		pct.text = _pct(t)
