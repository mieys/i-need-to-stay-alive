extends RefCounted

## Oyuncu panelindeki (hud.gd dock) küçük piksel ikonlar: can/kalkan çubuklarının solundaki kalp ve kalkan, boş efsanevi
## yuvasındaki silik elmas. 11x10 sanat pikseli, tam sayı ölçekle çizilir (revive_hearts_hud.gd kalbiyle aynı biçim).

const HEART: Array[String] = ["..XXX.XXX..", ".XXXXXXXXX.", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", ".XXXXXXXXX.",
	"..XXXXXXX..", "...XXXXX...", "....XXX....", ".....X....."]
const SHIELD: Array[String] = ["XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", "XXXXXXXXXXX", ".XXXXXXXXX.",
	".XXXXXXXXX.", "..XXXXXXX..", "...XXXXX...", "....XXX...."]
const DIAMOND: Array[String] = ["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."]
const OUTLINE := Color("#1e120a")
const HEART_COLOR := Color(0.9, 0.2, 0.28)
const SHIELD_COLOR := Color(0.24, 0.59, 0.91)


static func _in(rows: Array[String], x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < rows[y].length() and rows[y][x] == "X"


## Konturlu, üç tonlu (sol üst açık, sağ alt koyu) piksel biçim.
static func draw_shape(ci: CanvasItem, rows: Array[String], pos: Vector2, px: float, base: Color) -> void:
	var light: Color = base.lightened(0.4)
	var shade: Color = base.darkened(0.35)
	for y in rows.size():
		for x in rows[y].length():
			if not _in(rows, x, y):
				continue
			var c: Color = base
			if not (_in(rows, x - 1, y) and _in(rows, x + 1, y) and _in(rows, x, y - 1) and _in(rows, x, y + 1)):
				c = OUTLINE
			elif not _in(rows, x + 2, y) or not _in(rows, x, y + 2):
				c = shade
			elif x + y <= 5:
				c = light
			ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), c)


## Tek renk, kontursuz (boş yuva işareti).
static func draw_flat(ci: CanvasItem, rows: Array[String], pos: Vector2, px: float, color: Color) -> void:
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "X":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * px, Vector2(px, px)), color)


## 2 px koyu kontur, köşeleri 2 px kesik, içi dolu levha (çubuk zemini / sayaç levhası / eşya yuvası).
static func draw_plate(ci: CanvasItem, r: Rect2, fill: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(2, 0), r.size - Vector2(4, 0)), OUTLINE)
	ci.draw_rect(Rect2(r.position + Vector2(0, 2), r.size - Vector2(0, 4)), OUTLINE)
	ci.draw_rect(r.grow(-2.0), fill)
