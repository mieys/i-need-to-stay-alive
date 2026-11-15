extends SceneTree
## PANEL DOKUSU prototip yakalaması (2026-11-13, oyuna bağlı DEĞİL). Oda listesi ekranını (room_browser) gerçek çizicide açar; büyük pencere
## kutularının (PanelContainer "panel" PixelBox'ı, zemin WIN_PANEL/2/3) yerine aynı ayarlı bir alt sınıf koyar: kutu AYNEN çizilir, sonra
## 9 dilimin ORTA bölgesine (kenar + kabartma + köşe basamağının içi) karo doku x3 en yakın komşu döşenir. Oyun kodu değişmez.
## CAP_OUT = PNG klasörü, CAP_TILES = doku_*.png klasörü. Çalıştır: run.ps1 (gizli masaüstü).

const PB := preload("res://scripts/pixel_box.gd")
const HT := preload("res://scripts/hud_theme.gd")
const PX := 3

var _out: String = OS.get_environment("CAP_OUT")
var _tiles: String = OS.get_environment("CAP_TILES")


class DokuBox extends "res://scripts/pixel_box.gd":
	var doku: Texture2D = null ## x3 büyütülmüş karo
	var doku_alpha := 1.0 ## karo saydamlık çarpanı (H: zemin damarı yarım)
	var edge_shade := false ## D: kenara doğru bantlı kararma
	var corners: Dictionary = {} ## H: K -> {"tl": Texture2D, ...} (x3), boş = çerçeve yok
	var frame_big_only := false ## çerçeve yalnız büyük pencerede (K=10), iç kartlarda yok
	const FRAME_IN := 1 ## H: oyma çizgi orta bölgenin kaç sanat px içinde (3'te içerik yazısıyla çakıştı)

	func _draw(ci: RID, rect: Rect2) -> void:
		super(ci, rect)
		if doku == null or not draw_center:
			return
		var r: Rect2 = _get_draw_rect(rect)
		var small: bool = minf(r.size.x, r.size.y) < SMALL
		var info: Array = texture_for(bg_color, border_color,
			[border_width_left, border_width_top, border_width_right, border_width_bottom],
			[corner_radius_top_left, corner_radius_top_right, corner_radius_bottom_right, corner_radius_bottom_left], small, bevel_hi)
		var m: Array = info[1]
		var inner := Rect2(r.position + Vector2(m[0], m[1]), r.size - Vector2(m[0] + m[2], m[1] + m[3]))
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			return
		var ts: Vector2 = doku.get_size()
		## kutudan kutuya farklı başlangıç (aynı karonun kopya gibi durmaması için), sanat pikseline oturur
		var h: int = absi(hash(Vector2i(int(r.size.x), int(r.size.y))))
		var off := Vector2(float((h % int(ts.x / PX)) * PX), float(((h / 7) % int(ts.y / PX)) * PX))
		var y: float = -off.y
		while y < inner.size.y:
			var x: float = -off.x
			while x < inner.size.x:
				var tr := Rect2(inner.position + Vector2(x, y), ts)
				var cl: Rect2 = tr.intersection(inner)
				if cl.size.x > 0.0 and cl.size.y > 0.0:
					RenderingServer.canvas_item_add_texture_rect_region(ci, cl, doku.get_rid(), Rect2(cl.position - tr.position, cl.size),
						Color(1, 1, 1, doku_alpha))
				x += ts.x
			y += ts.y
		if edge_shade:
			## 3 bant x 2 sanat px: kenarda DEEP %18 -> %11 -> %5
			var alphas: Array = [0.18, 0.11, 0.05]
			for k in alphas.size():
				var b := inner.grow(-float(k * 2 * PX))
				var w := float(2 * PX)
				var c := Color(HT.DEEP, alphas[k])
				RenderingServer.canvas_item_add_rect(ci, Rect2(b.position, Vector2(b.size.x, w)), c)
				RenderingServer.canvas_item_add_rect(ci, Rect2(b.position + Vector2(0, b.size.y - w), Vector2(b.size.x, w)), c)
				RenderingServer.canvas_item_add_rect(ci, Rect2(b.position + Vector2(0, w), Vector2(w, b.size.y - 2 * w)), c)
				RenderingServer.canvas_item_add_rect(ci, Rect2(b.position + Vector2(b.size.x - w, w), Vector2(w, b.size.y - 2 * w)), c)
		if not corners.is_empty():
			_draw_frame(ci, inner)

	## H: oyma çerçeve. Çizgi = 1 sanat px DEEP oluk + sağ altında 1 sanat px RIM_HI ışık (gen_panel_doku2 ile aynı tonlar);
	## köşelerde içe dönen yay (hazır doku). Köşe hücresinin koyu pikseli P (sanat px) = çerçeve köşe noktası.
	func _draw_frame(ci: RID, inner: Rect2) -> void:
		var mind: float = minf(inner.size.x, inner.size.y)
		var K: int = 10 if mind >= 240.0 else 5
		if frame_big_only and K != 10:
			return
		if not corners.has(K) or mind < float(2 * (K + FRAME_IN + 2) * PX):
			return
		var S: int = K + 3
		var o: float = float(FRAME_IN * PX)
		var tl: Vector2 = inner.position + Vector2(o, o)
		var br: Vector2 = inner.end - Vector2(o, o) - Vector2(PX, PX)
		var pts := {"tl": [tl, Vector2i(1, 1)], "tr": [Vector2(br.x, tl.y), Vector2i(S - 2, 1)],
			"bl": [Vector2(tl.x, br.y), Vector2i(1, S - 2)], "br": [br, Vector2i(S - 2, S - 2)]}
		var cset: Dictionary = corners[K]
		for key: String in pts:
			var p: Vector2 = pts[key][0] - Vector2(pts[key][1]) * PX
			var t: Texture2D = cset[key]
			RenderingServer.canvas_item_add_texture_rect(ci, Rect2(p, t.get_size()), t.get_rid())
		var dk := Color(HT.DEEP, 0.70)
		var lt := Color(HT.RIM_HI, 0.28)
		var a: float = float((K + 1) * PX)
		var e: float = float(K * PX)
		## yatay çizgiler (üst, alt) ve dikey çizgiler (sol, sağ): koyu, sonra (+1, +1) ışık
		for yy: float in [tl.y, br.y]:
			RenderingServer.canvas_item_add_rect(ci, Rect2(tl.x + a, yy, br.x - e - (tl.x + a), PX), dk)
			RenderingServer.canvas_item_add_rect(ci, Rect2(tl.x + a + PX, yy + PX, br.x - e - (tl.x + a), PX), lt)
		for xx: float in [tl.x, br.x]:
			RenderingServer.canvas_item_add_rect(ci, Rect2(xx, tl.y + a, PX, br.y - e - (tl.y + a)), dk)
			RenderingServer.canvas_item_add_rect(ci, Rect2(xx + PX, tl.y + a + PX, PX, br.y - e - (tl.y + a)), lt)


## Prototip ayarları: anahtar -> [karo, karo alfası, kenar gölgesi, çerçeve, opak zemin, çerçeve yalnız büyük pencerede]
const VARIANTS := {
	"a": ["a", 1.0, false, false, false, false], "b": ["b", 1.0, false, false, false, false],
	"c": ["c", 1.0, false, false, false, false], "d": ["d", 1.0, true, false, false, false],
	"e": ["e", 1.0, false, false, false, false], "f": ["f", 1.0, false, false, false, false],
	"g": ["g", 1.0, false, false, false, false], "h": ["e", 0.5, false, true, false, false],
	## saydamlık sorusu: E opak (pencere zemini %88 -> %100) ve E + oyma çerçeve yalnız büyük pencerelerde, opak
	"e_opak": ["e", 1.0, false, false, true, false], "eh_opak": ["e", 1.0, false, true, true, true],
}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("SHOT ", name, " ", img.get_size())


func _load_tile(key: String) -> Texture2D:
	var img := Image.load_from_file(_tiles.path_join("doku_%s.png" % key))
	img.resize(img.get_width() * PX, img.get_height() * PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _is_window_fill(c: Color) -> bool:
	for ref: Color in [HT.WIN_PANEL, HT.WIN_PANEL2, HT.WIN_PANEL3]:
		if absf(c.r - ref.r) + absf(c.g - ref.g) + absf(c.b - ref.b) < 0.02:
			return true
	return false


func _swap_boxes(n: Node, boxes: Array) -> void:
	if n is PanelContainer or n is Panel:
		var c := n as Control
		if c.has_theme_stylebox_override("panel"):
			var sb: StyleBox = c.get_theme_stylebox("panel")
			if sb.get_script() == PB and _is_window_fill(sb.bg_color) and minf(c.size.x, c.size.y) >= 90.0:
				var nb := DokuBox.new()
				for p: Dictionary in sb.get_property_list():
					if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) and not String(p["name"]).begins_with("resource_") and p["name"] != "script":
						nb.set(p["name"], sb.get(p["name"]))
				for side in 4:
					nb.set_content_margin(side, sb.get_content_margin(side))
				c.add_theme_stylebox_override("panel", nb)
				boxes.append([c, nb, sb.bg_color.a])
	for ch in n.get_children():
		_swap_boxes(ch, boxes)


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	change_scene_to_file("res://scenes/room_browser.tscn")
	await _wait(3.0)
	await _shot("simdi")
	var boxes: Array = []
	_swap_boxes(current_scene, boxes)
	print("KUTU ", boxes.size(), " ", boxes.map(func(b: Array) -> String: return "%s %s" % [b[0].name, b[0].size]))
	var set_env: String = OS.get_environment("CAP_SET")
	var keys: PackedStringArray = (set_env if set_env != "" else "a,b,c,d").split(",")
	var all_opaque: bool = OS.get_environment("CAP_OPAK") == "1" ## hepsi opak zeminle, çıktı adı "_opak" ekli
	var frame_corners := {}
	for K: int in [10, 5]:
		var d := {}
		for c: String in ["tl", "tr", "bl", "br"]:
			d[c] = _load_tile("h_k%d_%s" % [K, c])
		frame_corners[K] = d
	for key: String in keys:
		var cfg: Array = VARIANTS[key]
		var t: Texture2D = _load_tile(cfg[0])
		for b: Array in boxes:
			b[1].doku = t
			b[1].doku_alpha = cfg[1]
			b[1].edge_shade = cfg[2]
			b[1].corners = frame_corners if cfg[3] else {}
			b[1].frame_big_only = cfg[5]
			b[1].bg_color = Color(b[1].bg_color, 1.0 if (cfg[4] or all_opaque) else float(b[2]))
			(b[0] as Control).queue_redraw()
		await _wait(0.3)
		await _shot("doku_" + key + ("_opak" if all_opaque and not key.ends_with("_opak") else ""))
	quit(0)
