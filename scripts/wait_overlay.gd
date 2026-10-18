extends CanvasLayer

## OYUNCULAR BEKLENİYOR ekranı - "B Ateş Işığı Şeridi" (kullanıcı seçimi 2026-10-18, madde 264; prototip
## tools/proto_20261018/bildirim_proto.gd bekleme_B, madde 260). Çok oyunculuda üç bekleme aynı ekranı kullanır (main.gd):
##  "level_up" (kart/silah/kalkan seçimi), "chest" (sandık ödülü), "shop" (mini dükkan). Eskiden %55 karartma + 720x220 bej pencere
##  + "Seçim yapılıyor: X / Lütfen bekleyin" + "25s" idi.
## Kutu yok (ESC/Ayarlar "Ateş Işığı" dili): kenarları kararan vinyet + ekranı yatay kesen yumuşak koyu şerit, altın başlık + elmaslı
## süs çizgileri, herkesin 2x portresi (kutusuz) + isim + durum (hazır = yeşil tik, bekleniyor = sırayla yanan "..." balonu), büyük
## geri sayım + ortadan kısalan çizgi. Veri her karede NetworkManager'dan okunur (ek RPC yok): kim meşgul (level_up_busy_peers /
## chest_busy_peers / mini_shop_pending_peers), isim + karakter (lobby_players), sayaç. Tıklamayı yutar (eski karartma da öyleydi).

const HT := preload("res://scripts/hud_theme.gd")
const FONT := preload("res://assets/fonts/m5x7.ttf")

const LAYER := 90
const MODES := {
	"level_up": {"title": "KART SEÇİMİ BEKLENİYOR", "busy": "seçiyor", "total": 25.0},
	"chest": {"title": "SANDIK ÖDÜLÜ BEKLENİYOR", "busy": "sandık açıyor", "total": 25.0},
	"shop": {"title": "ALIŞVERİŞ BEKLENİYOR", "busy": "dükkanda", "total": 30.0},
}
## fire_menu_kit.gd (Ateş Işığı) renkleri
const C_GOLD := Color("#f4c56e")
const C_GOLD_DIM := Color("#e2c08a")
const C_CREAM := Color("#efe2c6")
const C_SUB := Color("#b09878")
const C_DARK := Color("#140e09")
const BAND_W := 1440.0
const BAND_H := 348.0
const BAND_CY := 330.0
const FADE_IN := 0.25

const VIGNETTE := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(0.05, 0.03, 0.02, mix(0.18, 0.66, smoothstep(0.15, 0.85, d)));
}
"""
const CHECK := [
	"  OOOOO  ",
	" OGGGGGO ",
	"OGGGGGWGO",
	"OGGGGWWGO",
	"OGWGWWGGO",
	"OGWWWGGGO",
	"OGGWGGGGO",
	" OGGGGGO ",
	"  OOOOO  ",
]
## "..." balonu; D = nokta (sırayla yanar)
const BUBBLE := [
	" OOOOOOOOO ",
	"OWWWWWWWWWO",
	"OW1WW2WW3WO",
	"OWWWWWWWWWO",
	" OOWOOOOOO ",
	"  OWO      ",
	"  OO       ",
]

static var _band_tex: ImageTexture = null
static var _portraits: Dictionary = {} ## yol -> Texture2D

var mode: String = "level_up"
var _board: Control = null
var _vignette: ColorRect = null
var _t: float = 0.0
var _rows: Array = [] ## [{name, tex, ready, me}]
var _remaining: float = -1.0


## Bekleme ekranını açar (parent'a eklenmiş CanvasLayer döner). mode: "level_up" / "chest" / "shop".
static func open(parent: Node, mode_: String) -> CanvasLayer:
	var w: CanvasLayer = (load("res://scripts/wait_overlay.gd") as GDScript).new()
	w.set("mode", mode_)
	parent.add_child(w)
	return w


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette = ColorRect.new()
	var sh := Shader.new()
	sh.code = VIGNETTE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_vignette.material = mat
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_vignette)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_board.draw.connect(_draw_board)
	add_child(_board)
	_vignette.modulate.a = 0.0
	_board.modulate.a = 0.0
	_poll()


func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / FADE_IN, 0.0, 1.0)
	_vignette.modulate.a = k
	_board.modulate.a = k
	_poll()
	_board.queue_redraw()


## Kim meşgul + sayaç (NetworkManager'dan, her karede - birkaç sözlük okuması).
func _poll() -> void:
	var me: int = multiplayer.get_unique_id() if multiplayer and multiplayer.has_multiplayer_peer() else 1
	var lobby: Dictionary = NetworkManager.lobby_players
	var ids: Array = []
	match mode:
		"shop":
			ids = NetworkManager.mini_shop_pending_peers.keys()
			if ids.is_empty():
				ids = lobby.keys()
			_remaining = NetworkManager.mini_shop_countdown if NetworkManager.mini_shop_timer_active else -1.0
		"chest":
			ids = lobby.keys()
			_remaining = NetworkManager.chest_countdown if NetworkManager.chest_countdown_active else -1.0
		_:
			ids = lobby.keys()
			_remaining = NetworkManager.level_up_countdown if NetworkManager.level_up_timer_active else -1.0
	ids.sort()
	if ids.has(me):
		ids.erase(me)
		ids.push_front(me)
	_rows.clear()
	for pid in ids:
		var info: Dictionary = lobby.get(pid, {})
		var busy: bool
		match mode:
			"shop":
				busy = not bool(NetworkManager.mini_shop_pending_peers.get(pid, true))
			"chest":
				busy = NetworkManager.chest_busy_peers.has(pid)
			_:
				busy = NetworkManager.level_up_busy_peers.has(pid)
		_rows.append({
			"name": "Sen" if int(pid) == me else str(info.get("name", "Oyuncu")),
			"tex": _portrait(int(info.get("char_id", -1))),
			"ready": not busy,
		})


static func _portrait(char_id: int) -> Texture2D:
	if char_id < 0:
		return null
	var path: String = str(Characters.get_def(char_id).get("portrait", ""))
	if path == "":
		return null
	if not _portraits.has(path):
		_portraits[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _portraits[path]


# ------------------------------------------------------------ çizim
func _draw_board() -> void:
	var def: Dictionary = MODES.get(mode, MODES["level_up"])
	var vp: Vector2 = _board.size
	var cx: float = roundf(vp.x * 0.5)
	var cy: float = BAND_CY
	_board.draw_texture_rect(_band(), Rect2(roundf(cx - BAND_W * 0.5), roundf(cy - BAND_H * 0.5), BAND_W, BAND_H), false)
	var title: String = def["title"]
	var tl: float = _tw(title, 48)
	_txt(title, Vector2(roundf(cx - tl * 0.5), cy - 150.0), 48, C_GOLD)
	_orn(cx - tl * 0.5 - 28.0, cx - tl * 0.5 - 250.0, cy - 125.0, C_GOLD_DIM)
	_orn(cx + tl * 0.5 + 28.0, cx + tl * 0.5 + 250.0, cy - 125.0, C_GOLD_DIM)
	## portreler 2x (96 px), kutusuz; altında isim + durum
	var n: int = _rows.size()
	var step: float = minf(190.0, 1300.0 / maxf(1.0, n))
	var x0: float = cx - step * (n - 1) * 0.5
	var dot: int = int(_t / 0.3) % 3 + 1
	for i in n:
		var p: Dictionary = _rows[i]
		var px: float = roundf(x0 + i * step)
		var ready: bool = p["ready"]
		var py: float = cy - 96.0
		var tex: Texture2D = p["tex"]
		if tex != null:
			_board.draw_texture_rect(tex, Rect2(px - 48.0, py, 96.0, 96.0), false, Color(1, 1, 1, 0.8) if ready else Color.WHITE)
		if ready:
			_sprite(CHECK, Vector2(px + 22.0, py + 66.0), 3.0, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})
		else:
			var cols := {"O": HT.OUTLINE, "W": HT.TEXT, "1": Color("#4b3320"), "2": Color("#4b3320"), "3": Color("#4b3320")}
			cols[str(dot)] = Color("#c9963e")
			_sprite(BUBBLE, Vector2(px + 18.0, py - 12.0), 3.0, cols)
		_r(px - 45.0, py + 98.0, 90.0, 3.0, Color(HT.GOOD if ready else C_GOLD, 0.7))
		var name_fit: String = _fit(p["name"], 24, step - 12.0)
		_txt_c(name_fit, px, py + 106.0, 24, C_CREAM if ready else C_GOLD)
		_txt_c("hazır" if ready else String(def["busy"]), px, py + 130.0, 24, HT.GOOD if ready else C_SUB)
	if _remaining >= 0.0:
		var num := "%d" % int(ceil(_remaining))
		var total_w: float = _tw(num, 48) + _tw(" sn", 48)
		var tx: float = roundf(cx - total_w * 0.5)
		_txt(num, Vector2(tx, cy + 70.0), 48, HT.PRICE)
		_txt(" sn", Vector2(tx + _tw(num, 48), cy + 70.0), 48, C_SUB)
		var lw: float = roundf(700.0 * clampf(_remaining / float(def["total"]), 0.0, 1.0) / 3.0) * 3.0
		_r(cx - lw * 0.5, cy + 132.0, lw, 3.0, C_GOLD_DIM)
		_diamond(Vector2(cx - lw * 0.5 - 6.0, cy + 133.5), 3.0, C_GOLD_DIM)
		_diamond(Vector2(cx + lw * 0.5 + 6.0, cy + 133.5), 3.0, C_GOLD_DIM)


## Yumuşak koyu şerit dokusu (3 px piksellik, bir kez üretilir): dikeyde ortası koyu kenarlara söner, yatayda iki uçtan söner.
static func _band() -> ImageTexture:
	if _band_tex != null:
		return _band_tex
	var w: int = int(BAND_W / 3.0)
	var h: int = int(BAND_H / 3.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		var dv: float = absf((j + 0.5) / h - 0.5) * 2.0
		var av: float = 0.86 * (1.0 - smoothstep(0.65, 1.0, dv))
		for i in w:
			var u: float = (i + 0.5) / w
			var ah: float = minf(smoothstep(0.0, 0.28, u), smoothstep(0.0, 0.28, 1.0 - u))
			img.set_pixel(i, j, Color(C_DARK, av * ah))
	_band_tex = ImageTexture.create_from_image(img)
	return _band_tex


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	_board.draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)


func _sprite(rows: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var ch: String = row[i]
			if cols.has(ch):
				_r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])


func _diamond(c: Vector2, cell: float, col: Color) -> void:
	_r(c.x - cell * 0.5, c.y - cell * 1.5, cell, cell, col)
	_r(c.x - cell * 1.5, c.y - cell * 0.5, cell * 3.0, cell, col)
	_r(c.x - cell * 0.5, c.y + cell * 0.5, cell, cell, col)


## Süs çizgisi: başlığa yakın uçta elmas, dışa doğru solan çizgi.
func _orn(x_from: float, x_to: float, y: float, col: Color) -> void:
	var dir: float = signf(x_to - x_from)
	_diamond(Vector2(x_from, y + 1.5), 3.0, col)
	var n := 12
	var ln: float = absf(x_to - x_from) - 12.0
	for i in n:
		var a: float = 1.0 - float(i) / n
		var xa: float = x_from + dir * (12.0 + ln * i / n)
		var xb: float = x_from + dir * (12.0 + ln * (i + 1) / n)
		_r(minf(xa, xb), y, absf(xb - xa), 3.0, Color(col, a * 0.9))


func _tw(s: String, size: int) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _txt(s: String, pos: Vector2, size: int, c: Color) -> void:
	var u: float = minf(size / 8.0, 3.0)
	var base := Vector2(roundf(pos.x), roundf(pos.y + FONT.get_ascent(size)))
	_board.draw_string(FONT, base + Vector2(u, u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(HT.OUTLINE, 0.9))
	_board.draw_string(FONT, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _txt_c(s: String, cx: float, y: float, size: int, c: Color) -> void:
	_txt(s, Vector2(roundf(cx - _tw(s, size) * 0.5), y), size, c)


func _fit(s: String, size: int, width: float) -> String:
	if _tw(s, size) <= width:
		return s
	var out := s
	while out.length() > 1 and _tw(out + "..", size) > width:
		out = out.substr(0, out.length() - 1)
	return out + ".."
