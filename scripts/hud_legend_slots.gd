extends Control

## Oyuncu panelinin (hud.gd dock) sağına yapışık küçük panel: 5 efsanevi eşya yuvası (Items.LEGENDARY_SLOT_LIMIT) + sağ alt
## köşede KALKAN TÜRÜ yuvası (2 sütun, 2-2-2). Kullanıcı isteği (2026-10-14): "panelin tam sağında kendisiyle yapışık daha
## küçük bir panel... içi boş slotlar olacak, efsanevi eşya alınca dolacak içleri onların ikonlarıyla" - prototip 1'deki
## görünüş seçildi; ardından "1 ikonluk yer daha var, oraya aldığımız kalkan türü görünsün, çerçevesi onlardan farklı olmalı".
## Efsanevi yuva: kare, koyu kahve levha; boşken silik elmas, doluyken eşyanın 32 px ikonu 1:1 + envanterdeki efsanevi rengi.
## Kalkan yuvası: köşeleri kesik (sekizgen), lacivert zemin, çelik mavisi çerçeve - sahip olunan kalkan türünün ikonu
## (ShieldEnchantDefs.owned_type; herkes Standart ile başlar, kalkan efsunu seçilince onun ikonuna döner).
## Ana panel bu düğümün SOL 12 px'ini örter (hud.gd DOCK_LEGEND_OVERLAP) - yuva konumları buna göre.

const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const PANEL_SIZE := Vector2(116, 140)
const SLOT := 40.0
const CELLS: Array[Vector2] = [Vector2(22, 8), Vector2(66, 8), Vector2(22, 50), Vector2(66, 50), Vector2(22, 92)]
const SHIELD_CELL := Vector2(66, 92)
const HudTheme := preload("res://scripts/hud_theme.gd")
const SLOT_UNDER := HudTheme.INSET
const EMPTY_RING := HudTheme.RIM_LO
const EMPTY_MARK := HudTheme.MARK
const EMPTY_TIP := "Efsanevi Eşya Yuvası (Boş)"
const SHIELD_UNDER := Color(0.06, 0.1, 0.17)
const SHIELD_RING := Color(0.36, 0.66, 0.95)
const SHIELD_RING_EMPTY := Color(0.2, 0.28, 0.38)
const SHIELD_MARK := Color(0.14, 0.2, 0.29)
const SHIELD_EMPTY_TIP := "Mana Kalkanı Yuvası (Boş)"
const ICON_PX := 32
const REFRESH_INTERVAL := 0.25

var _keys: Array[String] = []
var _icons: Array[Texture2D] = []
var _areas: Array[Control] = []
var _shield_area: Control = null
var _shield_key: String = ""
var _shield_sig: String = "?"
var _shield_tex: Texture2D = null
var _timer: float = 0.0
var _panel_box: StyleBox = null
var _ring: Color = Color.WHITE
## Kalkan ikonları 48x48 gerçek piksel sanatı - 32 px yuvaya bir kez yumuşak küçültülüp saklanır (en yakın komşu satır atlıyor).
static var _shield_icon_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel_box = UIKit.panel_style("status_badge")
	_ring = (TierSystem.COLORS[Items.KADEME_EFSANEVI - 1] as Color).lightened(0.25)
	## İpucu için yuva başına görünmez alan (çizim bu düğümün _draw'ında).
	for i in CELLS.size():
		_areas.append(_make_area("Slot%d" % i, CELLS[i], EMPTY_TIP))
	_shield_area = _make_area("ShieldSlot", SHIELD_CELL, SHIELD_EMPTY_TIP)
	_refresh()


func _make_area(node_name: String, pos: Vector2, tip: String) -> Control:
	var a := Control.new()
	a.name = node_name
	a.position = pos
	a.size = Vector2(SLOT, SLOT)
	a.mouse_filter = Control.MOUSE_FILTER_PASS
	a.tooltip_text = tip
	add_child(a)
	return a


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_refresh()


func _refresh() -> void:
	var keys: Array[String] = []
	for it in GameManager.owned_items:
		var key: String = str((it as Dictionary).get("key", ""))
		if Items.kademe(key) == Items.KADEME_EFSANEVI and keys.size() < CELLS.size():
			keys.append(key)
	var dirty: bool = false
	if keys != _keys:
		_keys = keys
		## İkonlar _draw içinde İLK kez yüklenirse o karede beyaz kare çıkıyor (yeniden çizim de gelmiyor) - burada, çizimden önce yüklenir.
		_icons.clear()
		for k in keys:
			_icons.append(Items.icon(k))
		for i in _areas.size():
			_areas[i].tooltip_text = ("%s\n%s" % [Items.item_name(_keys[i]), Items.describe(_keys[i])]) if i < _keys.size() else EMPTY_TIP
		dirty = true
	## Kalkan: tür ya da geliştirme sayısı değişince ipucu (güncel değerler) + ikon yenilenir.
	var shield_key: String = ShieldEnchantDefs.owned_type()
	var shield_sig: String = shield_key + ":" + str(GameManager.shield_enchant_ups)
	if shield_sig != _shield_sig:
		_shield_sig = shield_sig
		_shield_key = shield_key
		_shield_tex = _shield_icon(shield_key)
		_shield_area.tooltip_text = _shield_tip()
		dirty = true
	if dirty:
		queue_redraw()


func _shield_tip() -> String:
	var st: Dictionary = ShieldEnchantDefs.stats()
	if st.is_empty():
		return SHIELD_EMPTY_TIP
	var lines: Array[String] = [str(st["name"])]
	var desc: String = str((ShieldEnchantDefs.TYPES[_shield_key] as Dictionary).get("desc", ""))
	if desc != "":
		lines.append(desc)
	lines.append("")
	lines.append("Mana Kalkanı: %d" % int(round(float(st["power"]))))
	lines.append("Hasar soğurma: %%%d" % int(round(float(st["absorption"]) * 100.0)))
	lines.append("Yenilenme: %s/sn" % ShieldEnchantDefs._num(float(st["regen"])))
	lines.append("Bekleme: %s" % ShieldEnchantDefs._delay_text(st))
	return "\n".join(lines)


static func _shield_icon(key: String) -> Texture2D:
	if key == "" or not ShieldEnchantDefs.ICONS.has(key):
		return null
	if _shield_icon_cache.has(key):
		return _shield_icon_cache[key]
	var src: Texture2D = load(str(ShieldEnchantDefs.ICONS[key])) as Texture2D
	var result: Texture2D = src
	var img: Image = src.get_image() if src else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
		result = ImageTexture.create_from_image(img)
	_shield_icon_cache[key] = result
	return result


func _draw() -> void:
	if _panel_box:
		draw_style_box(_panel_box, Rect2(Vector2.ZERO, size))
	for i in CELLS.size():
		var p: Vector2 = CELLS[i]
		var tex: Texture2D = _icons[i] if i < _icons.size() else null
		PixelIcons.draw_plate(self, Rect2(p, Vector2(SLOT, SLOT)), SLOT_UNDER)
		var ring: Color = _ring if i < _keys.size() else EMPTY_RING
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(36, 2)), ring)
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 36)), ring)
		draw_rect(Rect2(p + Vector2(2, 36), Vector2(36, 2)), ring.darkened(0.25))
		draw_rect(Rect2(p + Vector2(36, 2), Vector2(2, 36)), ring.darkened(0.25))
		if tex:
			draw_texture_rect(tex, Rect2(p + Vector2(4, 4), Vector2(32, 32)), false)
		elif i >= _keys.size():
			PixelIcons.draw_flat(self, PixelIcons.DIAMOND, p + Vector2(15, 15), 2.0, EMPTY_MARK)
	_draw_shield_slot(SHIELD_CELL)


## Köşeleri iki basamak kesik (sekizgen) dolu biçim: inset kadar içeriden.
func _octagon(p: Vector2, inset: float, color: Color) -> void:
	var s: float = SLOT - inset * 2.0
	var o: Vector2 = p + Vector2(inset, inset)
	draw_rect(Rect2(o + Vector2(4, 0), Vector2(s - 8.0, s)), color)
	draw_rect(Rect2(o + Vector2(0, 4), Vector2(s, s - 8.0)), color)
	draw_rect(Rect2(o + Vector2(2, 2), Vector2(s - 4.0, s - 4.0)), color)


func _draw_shield_slot(p: Vector2) -> void:
	var filled: bool = _shield_tex != null
	var ring: Color = SHIELD_RING if filled else SHIELD_RING_EMPTY
	_octagon(p, 0.0, PixelIcons.OUTLINE)
	_octagon(p, 2.0, ring.darkened(0.3))
	## Üst-sol yarı açık ton: çerçeveye metal kabartma verir (alt-sağ koyu kalır).
	draw_rect(Rect2(p + Vector2(6, 2), Vector2(28, 2)), ring.lightened(0.25))
	draw_rect(Rect2(p + Vector2(2, 6), Vector2(2, 28)), ring.lightened(0.25))
	draw_rect(Rect2(p + Vector2(4, 4), Vector2(2, 2)), ring.lightened(0.25))
	_octagon(p, 4.0, SHIELD_UNDER)
	if filled:
		draw_texture_rect(_shield_tex, Rect2(p + Vector2(4, 4), Vector2(ICON_PX, ICON_PX)), false)
	else:
		PixelIcons.draw_flat(self, PixelIcons.SHIELD, p + Vector2(9, 10), 2.0, SHIELD_MARK)
