extends Control

## POTPOURRI piksel logosu, harfler hafifçe aşağı yukarı dalgalanır (madde 660; kullanıcı 2026-11-13: "potpourri başlığı animasyonlu olsun
## harfler aşağı yukarı hareket etsin hafifçe ve oyun yükleme ekranında da gösterilsin"). Ana menü tabelası (main_menu.gd _title_sign) +
## yükleme ekranı (loading_screen.gd) bunu kullanır.
## Doku: assets/ui/ana_menu/logo_potpourri.png (zıplamasız, 84x15 sanat px; tools/proto_20261113/menu_baslik/gen_logo.py --oyun). Harfler
## dokunun SÜTUN DİLİMLERİ: harf i = yüzü + iki yanındaki 1 px dış hat (harf arası 2 px = iki harfin dış hattı, dilimler çakışmaz).
## LETTER_W / GAP / PAD gen_logo.py ile AYNI olmalı (doku genişliği tutmazsa logo dalgasız, tek parça çizilir).
## Hareket: konum (ölçek değil, stil rehberi 3. bölüm); her harf sinüs dalgasında, faz harften harfe kayar; ofset 3 ekran px'e (arayüz ızgarası,
## yarım sanat pikseli) yuvarlanır, yalnız değişince yeniden çizilir. "Arayüz animasyonları" kapalıysa (UISound.ui_anim_enabled) dalganın
## t=0 pozu sabit kalır (hafif dalgalı durağan logo).

const TEX: Texture2D = preload("res://assets/ui/ana_menu/logo_potpourri.png")
const K := 6.0 ## 1 sanat px = 6 ekran px (eski m5x7 96 başlıkla aynı yoğunluk)
const LETTER_W: Array[int] = [8, 8, 8, 8, 8, 8, 8, 8, 2] ## P O T P O U R R I (gen_logo.py G)
const GAP := 2
const PAD := 1
const AMP_ART := 1.0 ## genlik, sanat px ("hafifçe")
const STEP_PX := 3.0
const PERIOD := 2.6 ## sn
const PHASE := 0.65 ## harfler arası faz (rad): soldan sağa ilerleyen dalga

var _t: float = 0.0
var _cols: Array[Vector2i] = [] ## (x0, genişlik) sanat px
var _offs: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var x := PAD
	var total := PAD * 2 + GAP * (LETTER_W.size() - 1)
	for w: int in LETTER_W:
		total += w
	if total == TEX.get_width():
		for w: int in LETTER_W:
			_cols.append(Vector2i(x - 1, w + 2))
			x += w + GAP
	else:
		push_warning("potpourri_logo: doku genişliği %d, beklenen %d - harf dilimleri devre dışı" % [TEX.get_width(), total])
		_cols.append(Vector2i(0, TEX.get_width()))
	_offs.resize(_cols.size())
	_update_offsets()
	custom_minimum_size = Vector2(TEX.get_width(), TEX.get_height() + AMP_ART * 2.0) * K


## Logonun dokusunun (dalgasız) kontrol içindeki üst kenarı: harfler bunun AMP_ART*K altına / üstüne oynar.
static func art_top() -> float:
	return AMP_ART * K


func _anim_on() -> bool:
	var ui: Node = get_node_or_null("/root/UISound") if is_inside_tree() else null
	return ui == null or bool(ui.get("ui_anim_enabled"))


func _update_offsets() -> bool:
	var changed := false
	for i in _cols.size():
		var o: float = snappedf(sin(TAU * _t / PERIOD - float(i) * PHASE) * AMP_ART * K, STEP_PX) if _cols.size() > 1 else 0.0
		if o != _offs[i]:
			_offs[i] = o
			changed = true
	return changed


func _process(delta: float) -> void:
	if not _anim_on():
		if _t != 0.0:
			_t = 0.0
			if _update_offsets():
				queue_redraw()
		return
	_t = fmod(_t + delta, PERIOD)
	if _update_offsets():
		queue_redraw()


func _draw() -> void:
	var h: float = TEX.get_height()
	for i in _cols.size():
		var c: Vector2i = _cols[i]
		draw_texture_rect_region(TEX, Rect2(c.x * K, art_top() + _offs[i], c.y * K, h * K), Rect2(c.x, 0, c.y, h))
