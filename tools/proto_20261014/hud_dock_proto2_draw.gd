extends "res://tools/proto_20261014/hud_dock_proto_draw.gd"

## 2. tur (2026-10-14): A ve B beğenildi -> ikisinin türevleri + ruhani yetenek (F) yuvası + evcil hayvan yuvası + panelin
## sağına yapışık 5 yuvalı efsanevi eşya paneli (Items.LEGENDARY_SLOT_LIMIT). Sol sütun: 2 efsanevi; sağ sütun: 5 efsanevi.

const LEGEND_KEYS: Array[String] = ["anka_kusunun_kalbi", "ilidaricin_kilici", "son_felaket_pencesi", "kralin_kadehi", "zaman_kiran"]
const SLOT_UNDER := Color(0.13, 0.08, 0.05)
const SLOT_EMPTY_RING := Color(0.37, 0.26, 0.16)
const SLOT_EMPTY_MARK := Color(0.27, 0.18, 0.11)
const DIAMOND: Array[String] = ["..X..", ".XXX.", "XXXXX", ".XXX.", "..X.."]

var t_spirit_frame: Texture2D = load("res://assets/ui/kit/hud_skill_frame_spirit.png")
var t_spirit: Texture2D
var t_pet: Texture2D
var t_items: Array = []
var c_legend: Color


func _ready() -> void:
	super._ready()
	states[0]["legend"] = 2
	states[1]["legend"] = 5
	t_spirit = load("res://assets/skills/spirit_can_icon.png")
	t_pet = (load("res://scripts/pet_catalog.gd") as GDScript).call("icon", "peri")
	for k: String in LEGEND_KEYS:
		t_items.append(Items.icon(k))
	c_legend = (TierSystem.COLORS[Items.KADEME_EFSANEVI - 1] as Color).lightened(0.25) ## envanterdeki efsanevi çerçeve rengi
	queue_redraw()


func _spirit(r: Rect2) -> void:
	var b: float = r.size.x * 8.0 / 52.0
	draw_texture_rect(t_spirit, r.grow(-b + 1.0), false)
	draw_texture_rect(t_spirit_frame, r, false)
	_txt(f_m, r.end.x - 15.0, r.end.y - 11.0, "F", 32, Color("#ffe9a8"), 3)


## Evcil hayvan: küçük çerçeve, hayvanın kendi sprite karesi tam sayı ölçekle ortada.
func _pet(r: Rect2) -> void:
	draw_rect(r.grow(-4.0), Color(0.2, 0.13, 0.09))
	if t_pet:
		var ts: Vector2 = t_pet.get_size()
		var s: float = maxf(1.0, floorf(minf((r.size.x - 8.0) / ts.x, (r.size.y - 8.0) / ts.y)))
		draw_texture_rect(t_pet, Rect2((r.get_center() - ts * s * 0.5).round(), ts * s), false)
	draw_texture_rect(t_small, r, false)


func _legend_slot(p: Vector2, tex: Texture2D) -> void:
	var r := Rect2(p, Vector2(40, 40))
	_plate(r, SLOT_UNDER)
	var ring: Color = c_legend if tex else SLOT_EMPTY_RING
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(36, 2)), ring)
	draw_rect(Rect2(p + Vector2(2, 36), Vector2(36, 2)), ring.darkened(0.25))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 36)), ring)
	draw_rect(Rect2(p + Vector2(36, 2), Vector2(2, 36)), ring.darkened(0.25))
	if tex:
		draw_texture_rect(tex, Rect2(p + Vector2(4, 4), Vector2(32, 32)), false)
	else:
		for y in DIAMOND.size():
			for x in DIAMOND[y].length():
				if DIAMOND[y][x] == "X":
					draw_rect(Rect2(p + Vector2(15 + x * 2, 15 + y * 2), Vector2(2, 2)), SLOT_EMPTY_MARK)


func _legend(o: Vector2, cells: Array, st: Dictionary) -> void:
	for i in cells.size():
		_legend_slot(o + (cells[i] as Vector2), t_items[i] if i < int(st["legend"]) else null)


func _skills4(o: Vector2, x0: float, y: float, st: Dictionary) -> void:
	_skills(o, x0, 64.0, y, st)
	_spirit(Rect2(o + Vector2(x0 + 198.0, y), Vector2(56, 56)))


func _hearts_tab(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_tab, Rect2(o + Vector2(10, -38), Vector2(100.0 + (96.0 if regen >= 0.0 else 0.0), 46)))
	for i in 3:
		_heart(o + Vector2(22 + i * 26, -28), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		_txt(f_m, o.x + 108.0, o.y - 18.0, _clock(regen), 48, TIMER, 4)


func _bars_in(o: Vector2, x: float, w: float, st: Dictionary) -> void:
	var hp := Rect2(o + Vector2(x, 78), Vector2(w, 30))
	_bar(hp, float(st["hp"]) / float(st["hpmax"]), _hp_col(st))
	_txt_c(f_m, hp, "%d/%d" % [st["hp"], st["hpmax"]], 32, CREAM, 4)
	var sh := Rect2(o + Vector2(x, 111), Vector2(w, 26))
	_bar(sh, float(st["sh"]) / float(st["shmax"]), SHIELD)
	_txt_c(f_m, sh, "%d/%d" % [st["sh"], st["shmax"]], 32, CREAM, 4)


func _bars_plate(o: Vector2, x: float, bar_w: float, plate_w: float, st: Dictionary) -> void:
	var rows: Array = [[78.0, 30.0, "hp", "hpmax"], [112.0, 26.0, "sh", "shmax"]]
	for row: Array in rows:
		var is_hp: bool = row[2] == "hp"
		var cy: float = o.y + float(row[0]) + float(row[1]) * 0.5
		if is_hp:
			_heart(Vector2(o.x + x, cy - 10), 2.0, true)
		else:
			_shield_icon(Vector2(o.x + x, cy - 10), 2.0)
		_bar(Rect2(o + Vector2(x + 28.0, row[0]), Vector2(bar_w, row[1])), float(st[row[2]]) / float(st[row[3]]), _hp_col(st) if is_hp else SHIELD)
		var pl := Rect2(o + Vector2(x + 28.0 + bar_w + 6.0, row[0]), Vector2(plate_w, row[1]))
		_plate(pl)
		var cur: String = str(st[row[2]])
		var mx: String = "/" + str(st[row[3]])
		var tx: float = pl.end.x - 8.0 - _w(f_p, cur + mx, 18)
		tx += _txt(f_p, tx, cy, cur, 18, CREAM if is_hp else Color("#bfe0ff"), 0)
		_txt(f_p, tx, cy, mx, 18, DIM, 0)


func _draw() -> void:
	for v in 4:
		var y: float = 110.0 + float(v) * 245.0
		_txt(f_m, 70.0, y + 70.0, str(v + 1), 96, CREAM, 4)
		for s in 2:
			call("_draw_p%d" % (v + 1), Vector2(170.0 + float(s) * 860.0, y), states[s])


## 1: A'nın devamı - sayılar barın içinde, kalpler üst sekmede. Efsanevi: 2 sütun (2-2-1).
func _draw_p1(o: Vector2, st: Dictionary) -> void:
	_hearts_tab(o, st)
	draw_style_box(sb_tab, Rect2(o + Vector2(468, 6), Vector2(116, 140)))
	draw_style_box(sb_panel, Rect2(o, Vector2(480, 152)))
	_legend(o, [Vector2(490, 14), Vector2(534, 14), Vector2(490, 56), Vector2(534, 56), Vector2(512, 98)], st)
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(34, 74), Vector2(44, 44)), "12")
	_slot(Rect2(o + Vector2(112, 24), Vector2(36, 36)), "passive_icon", "")
	_pet(Rect2(o + Vector2(152, 24), Vector2(36, 36)))
	_divider(o, 198, 20, 44)
	_skills4(o, 210, 14, st)
	_bars_in(o, 112, 352, st)


## 2: B'nin devamı - sayılar barın yanında levhada, kalpler + sayaç panelin içinde. Efsanevi: 3 + 2 kaydırmalı.
func _draw_p2(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_tab, Rect2(o + Vector2(554, 6), Vector2(116, 140)))
	draw_style_box(sb_panel, Rect2(o, Vector2(566, 152)))
	_legend(o, [Vector2(576, 14), Vector2(620, 35), Vector2(576, 56), Vector2(620, 77), Vector2(576, 98)], st)
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(34, 74), Vector2(44, 44)), "12")
	_skills4(o, 112, 14, st)
	_divider(o, 377, 20, 44)
	_slot(Rect2(o + Vector2(388, 24), Vector2(36, 36)), "passive_icon", "")
	_pet(Rect2(o + Vector2(428, 24), Vector2(36, 36)))
	for i in 3:
		_heart(o + Vector2(478 + i * 26, 14), 2.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		var tp := Rect2(o + Vector2(474, 38), Vector2(80, 34))
		_plate(tp)
		_txt_c(f_p, tp, _clock(regen), 27, TIMER, 0)
	_bars_plate(o, 112, 260, 144, st)


## 3: karışık - B'nin levhaları + A'nın kalp sekmesi; evcil portrenin köşesinde. Efsanevi: alt hizalı yatay şerit.
func _draw_p3(o: Vector2, st: Dictionary) -> void:
	_hearts_tab(o, st)
	draw_style_box(sb_tab, Rect2(o + Vector2(428, 90), Vector2(238, 62)))
	draw_style_box(sb_panel, Rect2(o, Vector2(440, 152)))
	_legend(o, [Vector2(448, 101), Vector2(490, 101), Vector2(532, 101), Vector2(574, 101), Vector2(616, 101)], st)
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(8, 76), Vector2(44, 44)), "12")
	_pet(Rect2(o + Vector2(66, 80), Vector2(36, 36)))
	_slot(Rect2(o + Vector2(112, 24), Vector2(36, 36)), "passive_icon", "")
	_divider(o, 158, 20, 44)
	_skills4(o, 170, 14, st)
	_bars_plate(o, 112, 138, 140, st)


## 4: karışık - A'nın bar içi sayıları + panel içinde büyük kalpler ve dev sayaç. Efsanevi: alt hizalı 3x2 blok.
func _draw_p4(o: Vector2, st: Dictionary) -> void:
	var regen: float = float(st["regen"])
	draw_style_box(sb_tab, Rect2(o + Vector2(468, 50), Vector2(154, 102)))
	draw_style_box(sb_panel, Rect2(o, Vector2(480, 152)))
	_legend(o, [Vector2(488, 60), Vector2(530, 60), Vector2(572, 60), Vector2(488, 102), Vector2(530, 102)], st)
	_portrait(Rect2(o + Vector2(14, 12), Vector2(84, 84)))
	_badge(Rect2(o + Vector2(34, 74), Vector2(44, 44)), "12")
	_slot(Rect2(o + Vector2(112, 24), Vector2(36, 36)), "passive_icon", "")
	_pet(Rect2(o + Vector2(152, 24), Vector2(36, 36)))
	_divider(o, 198, 20, 44)
	_skills4(o, 210, 14, st)
	_bars_in(o, 112, 224, st)
	var hy: float = 78.0 if regen >= 0.0 else 93.0
	for i in 3:
		_heart(o + Vector2(350 + i * 38, hy), 3.0, i < int(st["hearts"]), _regen_fill(i, regen))
	if regen >= 0.0:
		_txt_c(f_m, Rect2(o + Vector2(346, 110), Vector2(118, 30)), _clock(regen), 48, TIMER, 4)
