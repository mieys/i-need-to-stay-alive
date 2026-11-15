extends CanvasLayer

## 2v2 SKOR ŞERİDİ (PvPvE Aşama 4, madde 617): üst ortada iki takımın öldürme sayısı + seviyesi. Kendi takımın solda (renk hep takımın: mavi / kızıl).
## "MAVİ  Sv 5  3  -  2  Sv 4  KIZIL". Veri PvpNet'in statik skor alanlarından (host yazar, `score_changed` ile yenilenir): ağ yok, tek çizim.
## Boss barının (y 50) üstünde, FPS göstergesinin (sol üst) sağında durur; F3 (arayüzü gizle) bu katmanı da kapatır. Yalnız PvP'de Main'e eklenir (pvp_targets.gd).

const HT := preload("res://scripts/hud_theme.gd")
const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const UiHideScript := preload("res://scripts/ui_hide.gd")
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const NUM_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")

const TOP_Y := 6.0
const FS := 32
const NUM_FS := 18


class Strip extends Control:
	var parts: Array = [] ## [{"text", "color", "font", "size"}]
	var well: StyleBox = null

	func refresh(p_parts: Array) -> void:
		parts = p_parts
		var w: float = PAD2 * 2.0
		for part in parts:
			w += _width(part) + GAP2
		w -= GAP2
		custom_minimum_size = Vector2(maxf(w, 120.0), H2)
		size = custom_minimum_size
		queue_redraw()

	const PAD2 := 15.0
	const GAP2 := 12.0
	const H2 := 42.0

	func _width(part: Dictionary) -> float:
		var f: Font = part["font"]
		return f.get_string_size(String(part["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(part["size"])).x

	func _draw() -> void:
		if well != null:
			draw_style_box(well, Rect2(Vector2.ZERO, size))
		var x: float = PAD2
		for part in parts:
			var f: Font = part["font"]
			var fs: int = int(part["size"])
			var base_y: float = size.y * 0.5 + f.get_ascent(fs) * 0.5 - 2.0
			draw_string(f, Vector2(roundf(x), roundf(base_y)), String(part["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, part["color"])
			x += _width(part) + GAP2


## TAB'a basılı tutunca açılan ayrıntı tablosu: iki takımın oyuncuları, öldürme / ölme sayıları (madde 617). Kendi takım üstte.
class Board extends Control:
	var rows: Array = [] ## [{"left": String, "right": String, "color": Color, "head": bool}]
	var well: StyleBox = null
	const ROW_H := 36.0
	const PAD := 18.0
	const WIDTH := 420.0

	func refresh(p_rows: Array) -> void:
		rows = p_rows
		size = Vector2(WIDTH, PAD * 2.0 + ROW_H * float(rows.size()))
		queue_redraw()

	func _draw() -> void:
		if well != null:
			draw_style_box(well, Rect2(Vector2.ZERO, size))
		var y: float = PAD
		for row in rows:
			var head: bool = bool(row["head"])
			var base_y: float = y + ROW_H * 0.5 + 8.0
			draw_string(FONT, Vector2(PAD + (0.0 if head else 18.0), roundf(base_y)), String(row["left"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, row["color"])
			var right: String = String(row["right"])
			var w: float = NUM_FONT.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(NUM_FONT, Vector2(roundf(size.x - PAD - w), roundf(base_y - 2.0)), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, HT.PRICE if head else HT.TEXT)
			y += ROW_H


var _strip: Strip = null
var _board: Board = null
var _board_t: float = 0.0


func _ready() -> void:
	layer = 12
	UiHideScript.mark_layer(self)
	_strip = Strip.new()
	_strip.well = HudTrayKit.well(0.0, 0.0)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_board = Board.new()
	_board.well = HudTrayKit.well(0.0, 0.0)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	add_child(_board)
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.score_changed.connect(_update)
	get_viewport().size_changed.connect(_place)
	_update()


func _update() -> void:
	if _strip == null:
		return
	var own: int = clampi(TeamsScript.local_team(), 0, 1)
	var other: int = 1 - own
	var parts: Array = []
	parts.append(_part(_team_name(own), HT.TEAM_COLORS[own], FONT, FS))
	parts.append(_part("Sv %d" % int(PvpNetScript.team_levels[own]), HT.DIM, NUM_FONT, NUM_FS))
	parts.append(_part(str(int(PvpNetScript.team_kills[own])), HT.PRICE, NUM_FONT, NUM_FS + 9))
	parts.append(_part("-", HT.DIM, FONT, FS))
	parts.append(_part(str(int(PvpNetScript.team_kills[other])), HT.PRICE, NUM_FONT, NUM_FS + 9))
	parts.append(_part("Sv %d" % int(PvpNetScript.team_levels[other]), HT.DIM, NUM_FONT, NUM_FS))
	parts.append(_part(_team_name(other), HT.TEAM_COLORS[other], FONT, FS))
	_strip.refresh(parts)
	_place()


func _process(delta: float) -> void:
	if _board == null:
		return
	var want: bool = Input.is_physical_key_pressed(KEY_TAB)
	if want != _board.visible:
		_board.visible = want
		_board_t = 0.0
	if not want:
		return
	_board_t -= delta
	if _board_t > 0.0:
		return
	_board_t = 0.25
	_board.refresh(_board_rows())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_board.position = Vector2(roundf((vp.x - _board.size.x) * 0.5), TOP_Y + 54.0)


func _board_rows() -> Array:
	var rows: Array = []
	var own: int = clampi(TeamsScript.local_team(), 0, 1)
	var nm: Node = get_node_or_null("/root/NetworkManager")
	var lobby: Dictionary = nm.get("lobby_players") if nm != null else {}
	for t in [own, 1 - own]:
		rows.append({"left": _team_name(t), "right": "%d" % int(PvpNetScript.team_kills[t]), "color": HT.TEAM_COLORS[t], "head": true})
		var members: Array = TeamsScript.members(t)
		members.sort()
		for pid in members:
			var info: Dictionary = lobby.get(int(pid), {}) if lobby.has(int(pid)) else {}
			var pname: String = str(info.get("name", "Oyuncu %d" % int(pid)))
			rows.append({"left": pname, "right": tr("K %d  Ö %d") % [int(PvpNetScript.peer_kills.get(int(pid), 0)), int(PvpNetScript.peer_deaths.get(int(pid), 0))],
					"color": HT.TEXT, "head": false})
	return rows


## Takım adı kısa (şerit): "MAVİ" / "KIZIL" (draw_string çizdiği için çeviri elle).
func _team_name(team: int) -> String:
	return tr("MAVİ") if team == 0 else tr("KIZIL")


func _part(text: String, color: Color, font: Font, size: int) -> Dictionary:
	return {"text": text, "color": color, "font": font, "size": size}


func _place() -> void:
	if _strip == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_strip.position = Vector2(roundf((vp.x - _strip.size.x) * 0.5), TOP_Y)
