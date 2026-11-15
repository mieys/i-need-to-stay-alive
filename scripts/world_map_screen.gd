extends Control
## DÜNYA HARİTASI SEÇİM EKRANI (madde 606, prototip "B - Atlas Defteri", madde 603).
## OYUNU BAŞLAT'tan sonra açılır: harita seçilir, YOLA ÇIK o haritayı başlatır. Tek oyunculuda character_select.gd, çok oyunculuda
## lobby_menu.gd açar. Odada 2+ oyuncu varsa ekran HERKESTE açılır ve `voting` kipindedir (madde 620): bir haritaya tıklamak = o haritaya
## oy (değiştirilebilir), satırlarda oy verenlerin yüzleri, sağ üstte kalan süre + "N / M oy"; süre dolunca ya da herkes oy verince
## NetworkManager kazananı bildirir (`show_winner`: kazanan satır vurgulanır, ekran birkaç sn açık kalır). YOLA ÇIK yok; GERİ / ESC yalnız
## host'ta (oylamayı iptal eder). Tek kişilikte eski akış (seç + YOLA ÇIK).
## Görünüş pazar B3 dili (çift ahşap çerçeve, solda liste kuyusu, sağda önizleme): solda seçilebilir haritalar (küçük resim + ad + tür),
## sağda seçili haritanın 1 px = 4 dünya px GERÇEK çizici görüntüsü + ad / tür / açıklama / kademe satırı + YOLA ÇIK tabelası.
## Arkada kısık kıta (haritaların kendi pikselleri). Dokular tools/dunya_haritasi/uret.py (assets/ui/dunya_haritasi/).
## Fare: satır tıklaması seçer, çift tık YOLA ÇIK. Klavye/kumanda: yukarı/aşağı satır değiştirir, ui_accept YOLA ÇIK (oylamada: oy ver), ui_cancel GERİ.

signal chosen(map_id: String)
signal cancelled
signal pick_changed(map_id: String) ## kullanıcı seçimi değiştirdi (tek kişilik akışta; oylamada `voted`)
signal voted(map_id: String) ## oylama: kullanıcı bu haritaya oy verdi (NetworkManager.cast_world_map_vote)

const MapProfiles := preload("res://scripts/map_profiles.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const HT := preload("res://scripts/hud_theme.gd")
const Signpost := preload("res://scripts/pixel_signpost.gd")
const Skull := preload("res://scripts/skull_icon.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd") ## oy verenin yüzü (madde 464)
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t (madde 446)
const ART_DIR := "res://assets/ui/dunya_haritasi/"
const WORLD_TEX: Texture2D = preload("res://assets/ui/dunya_haritasi/dunya.png")
const SEA := Color("#49678a") ## kıta dokusunun dışı (geniş ekranda yanlar): kıyı denizinin rengi
const WORLD_PX := 2.0 ## arka plandaki kıta: 1 piksel = 1 hücre = 2 ekran pikseli
const SHADE := 0.72 ## arka planı kısan DEEP örtüsü
const WIN_SIZE := Vector2(1620, 900)
const LIST_W := 470.0
const ROW_SIZE := Vector2(444, 116)
const THUMB := 96.0
const ROW_PAD := 12.0 ## harita satırında küçük görselin sol kenar boşluğu (satırlar sola hizalı)
const PREVIEW_SIZE := Vector2(1050, 494) ## uret.py PREVIEW_SIZE ile aynı
const GO_SIZE := Vector2(300, 57)

const FACE_BOX := 26.0 ## oy veren yüzü: 24x24 yüz tam kat (PortraitFace.face_icon)
const VOTE_FACES_MAX := 6

var voting: bool = false ## çok oyunculu oylama kipi: herkes oy verir (NetworkManager.world_map_*)
var can_cancel: bool = true ## GERİ düğmesi + ESC; oylamada yalnız host'ta true
var initial_map: String = ""

var _k = null
var _ph: bool = false
var _sel: String = ""
var _votes: Dictionary = {} ## oylama: peer_id -> harita kimliği
var _me: int = 0
var _total: int = 0 ## oylamada oy verecek oyuncu sayısı
var _winner: String = "" ## oylama sonuçlandıysa kazanan
var _tie: bool = false
var _last_sec: int = -1
var _rows: Dictionary = {} ## kimlik -> [Button, ad Label, oy yüzleri HBoxContainer (yalnız oylamada)]
var _preview: TextureRect = null
var _name_l: Label = null
var _kind_l: Label = null
var _desc_l: Label = null
var _go_btn: Button = null
var _vote_head_l: Label = null
var _vote_sub_l: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ph = MobileUIScript.enabled
	_k = DarkKit.new(DarkKit.PAL_NIGHT)
	theme = _k.theme()
	_build()
	var first: String = initial_map if _selectable(initial_map) else str(GameManager.selected_map)
	if not _selectable(first):
		first = MapProfiles.DEFAULT_ID
	_select(first, false)
	_refresh_vote_texts()
	if _go_btn:
		_go_btn.grab_focus.call_deferred()


## Bu ekranda seçilebilen haritalar (seçilebilir + önizlemesi üretilmiş), profil sırasıyla (yüzey önce, yeraltı sonra).
static func map_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in MapProfiles.selectable_ids():
		if ResourceLoader.exists(ART_DIR + "onizleme_%s.png" % id):
			out.append(id)
	return out


func _selectable(id: String) -> bool:
	return id != "" and map_ids().has(id)


func get_pick() -> String:
	return _sel


## OYLAMA: güncel oy listesi (peer_id -> harita) + bu eşin kimliği + oy verecek oyuncu sayısı. Satırlardaki yüzler ve sayaç yenilenir.
func set_votes(votes: Dictionary, me: int, total: int) -> void:
	_votes = votes.duplicate()
	_me = me
	_total = total
	_refresh_rows()
	_refresh_vote_texts()


## OYLAMA: kalan süre (sn). Her karede çağrılır; metin yalnız saniye değişince yazılır.
func set_time_left(sec: float) -> void:
	var s: int = ceili(maxf(sec, 0.0))
	if s == _last_sec:
		return
	_last_sec = s
	_refresh_vote_texts()


## OYLAMA: kazanan belli. Kazanan satır vurgulanır (diğerleri solar), önizleme kazananı gösterir, oy verme kapanır.
func show_winner(id: String, tie: bool) -> void:
	if not _selectable(id):
		return
	_winner = id
	_tie = tie
	_select(id, false)
	_refresh_vote_texts()


func get_winner() -> String:
	return _winner


func _process(_delta: float) -> void:
	if voting and _winner == "":
		set_time_left(NetworkManager.world_map_vote_time_left)


func _fs(n: int) -> int:
	return n + 16 if _ph else n


## Türkçe büyük harf (i -> İ) çeviriden sonra.
func _up(s: String) -> String:
	var t: String = tr(s)
	if TranslationServer.get_locale().begins_with("tr"):
		t = t.replace("i", "İ")
	return t.to_upper()


func _kind(id: String) -> String:
	return "YERALTI" if str(MapProfiles.get_profile(id).get("tur", "")) == MapProfiles.KIND_ZINDAN else "YÜZEY"


func _build() -> void:
	var vs: Vector2 = get_viewport_rect().size
	## arka plan: kısık kıta
	## (ağaca eklenmeden önce kurulan çocukta tam ekran çapası boyut 0 bırakıyordu: boyut açıkça)
	var bg := ColorRect.new()
	bg.color = SEA
	bg.size = vs
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var world := TextureRect.new()
	world.texture = WORLD_TEX
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world.stretch_mode = TextureRect.STRETCH_SCALE
	world.size = Vector2(WORLD_TEX.get_size()) * WORLD_PX
	world.position = ((vs - world.size) * 0.5).round()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	var shade := ColorRect.new()
	shade.color = Color(HT.DEEP, SHADE)
	shade.size = vs
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	## pencere: envanter / pazar çift ahşap çerçevesi
	var rim: PanelContainer = _k.box(HT.RIM, HT.OUTLINE, 8.0, 4, 6)
	rim.name = "Window"
	rim.position = ((vs - WIN_SIZE) * 0.5).round()
	rim.size = WIN_SIZE
	rim.custom_minimum_size = WIN_SIZE
	add_child(rim)
	var win: PanelContainer = _k.box(_k.c("panel"), HT.RIM_LO, 16.0, 3, 4)
	rim.add_child(win)
	var body: HBoxContainer = _k.h(18)
	win.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_detail())


func _build_list() -> PanelContainer:
	var lb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12.0, 3, 6)
	lb.name = "MapList"
	lb.custom_minimum_size.x = LIST_W + (60.0 if _ph else 0.0)
	var lv: VBoxContainer = _k.v(10)
	lb.add_child(lv)
	lv.add_child(_k.lbl("HARİTAYA OY VER" if voting else "HARİTALAR", _fs(32), HT.ACCENT_SOFT))
	for id: String in map_ids():
		var row: HBoxContainer = _k.h(14)
		var tr_img := TextureRect.new()
		tr_img.texture = load(ART_DIR + "kucuk_%s.png" % id) as Texture2D
		tr_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR ## küçültülmüş harita görüntüsü (piksel sanatı değil): 1440p ölçeğinde pürüzsüz
		tr_img.custom_minimum_size = Vector2(THUMB, THUMB)
		tr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr_img)
		var tv: VBoxContainer = _k.v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		var nl: Label = _k.lbl(_up(str(MapProfiles.get_profile(id).get("ad", id))), _fs(32), HT.TEXT)
		nl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tv.add_child(nl)
		var faces: HBoxContainer = null
		if voting:
			## ikinci satır: tür + (sağda) bu haritaya oy verenlerin yüzleri
			var sub: HBoxContainer = _k.h(8)
			sub.add_child(_k.lbl(_kind(id), _fs(24), HT.DIM))
			sub.add_child(_k.sp(0, 0, true))
			faces = _k.h(2)
			faces.name = "Votes_" + id
			faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
			faces.custom_minimum_size.y = FACE_BOX
			sub.add_child(faces)
			tv.add_child(sub)
		else:
			tv.add_child(_k.lbl(_kind(id), _fs(24), HT.DIM))
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		## hata defteri 2026-11-14: row_btn satırı ortalar; içerik genişliği ada göre değişince küçük görsel her satırda başka x'teydi.
		## Satır düğme genişliğinin tamamını (iki yanda ROW_PAD) kaplar -> görseller ve adlar tek sütunda.
		var row_w: float = ROW_SIZE.x + (60.0 if _ph else 0.0)
		row.custom_minimum_size.x = row_w - 2.0 * ROW_PAD
		var b: Button = _k.row_btn(row, "ghost", ROW_SIZE.y + (16.0 if _ph else 0.0), row_w)
		b.name = "Row_" + id
		b.focus_mode = Control.FOCUS_NONE
		if voting:
			b.pressed.connect(_vote_for.bind(id, false))
		else:
			b.pressed.connect(_select.bind(id, true))
			b.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and (ev as InputEventMouseButton).double_click \
						and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
					_select(id, true)
					_confirm())
		lv.add_child(b)
		_rows[id] = [b, nl, faces]
	lv.add_child(_k.sp(0, 0, false, true))
	if can_cancel:
		var back: Button = _k.btn("GERİ", "ghost", _fs(32), 57.0 + (16.0 if _ph else 0.0), 0.0)
		back.name = "Back"
		back.pressed.connect(func() -> void: cancelled.emit())
		lv.add_child(back)
	return lb


func _build_detail() -> PanelContainer:
	var dbox: PanelContainer = _k.box(_k.c("panel2"), _k.c("line_hi"), 18.0, 3, 6)
	dbox.name = "Detail"
	dbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dv: VBoxContainer = _k.v(12)
	dbox.add_child(dv)
	## haritanın gerçek görüntüsü (1 px = 4 dünya px); telefonda yazı büyüdüğü için alçak, ortası görünür
	var ph_h: float = 400.0 if _ph else PREVIEW_SIZE.y
	var pic: PanelContainer = _k.box(HT.DEEP, HT.OUTLINE, 0.0, 3, 0)
	pic.custom_minimum_size = Vector2(PREVIEW_SIZE.x + 6.0, ph_h + 6.0)
	dv.add_child(pic)
	var view := Control.new()
	view.clip_contents = true
	view.custom_minimum_size = Vector2(PREVIEW_SIZE.x, ph_h)
	pic.add_child(view)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR ## kutu filtreli harita görüntüsü: ekran ölçeğinde (1,33 kat) testere dişi olmasın
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_preview.size = Vector2(PREVIEW_SIZE.x, ph_h)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_preview)
	## ad + tür | YOLA ÇIK
	var hr: HBoxContainer = _k.h(20)
	var hv: VBoxContainer = _k.v(0)
	_name_l = _k.lbl("", _fs(48), HT.ACCENT)
	_name_l.name = "MapName"
	_name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hv.add_child(_name_l)
	_kind_l = _k.lbl("", _fs(32), HT.DIM)
	_kind_l.name = "MapKind"
	hv.add_child(_kind_l)
	hr.add_child(hv)
	hr.add_child(_k.sp(0, 0, true))
	var gv: VBoxContainer = _k.v(0)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	if voting:
		## YOLA ÇIK yok: kalan süre + oy sayısı (kazanan belli olunca "KAZANAN" + beraberlik notu)
		_vote_head_l = _k.lbl("", _fs(48), HT.ACCENT)
		_vote_head_l.name = "VoteHead"
		_vote_head_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_vote_sub_l = _k.lbl("", _fs(32), HT.DIM)
		_vote_sub_l.name = "VoteSub"
		_vote_sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		gv.add_child(_vote_head_l)
		gv.add_child(_vote_sub_l)
	else:
		_go_btn = _go_button()
		gv.add_child(_go_btn)
	hr.add_child(gv)
	dv.add_child(hr)
	_desc_l = _k.wrap("", _fs(32), HT.TEXT, PREVIEW_SIZE.x - 10.0)
	_desc_l.name = "MapDesc"
	dv.add_child(_desc_l)
	dv.add_child(_facts())
	return dbox


## Kademe/boss satırı (her haritada aynı, madde 599): kafatası + yazı.
func _facts() -> VBoxContainer:
	var v: VBoxContainer = _k.v(6)
	var r1: HBoxContainer = _k.h(12)
	var sk := TextureRect.new()
	sk.texture = Skull.tex()
	sk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sk.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sk.custom_minimum_size = Vector2(30, 32)
	r1.add_child(sk)
	r1.add_child(_k.lbl("BOSS: KADEME 5 VE 10", _fs(32), HT.TEXT))
	v.add_child(r1)
	v.add_child(_k.lbl("10 kademe, son boss ölünce zafer", _fs(32), HT.DIM))
	return v


## Pazarın DEVAM ET tabelası (pixel_signpost.gd, madde 532) - "YOLA ÇIK".
func _go_button() -> Button:
	var w: int = int(GO_SIZE.x) / Signpost.PX
	var h: int = int(GO_SIZE.y) / Signpost.PX
	var b := Button.new()
	b.name = "Go"
	b.custom_minimum_size = GO_SIZE
	b.add_theme_stylebox_override("normal", Signpost.box(w, h, HT.RIM, HT.OUTLINE))
	b.add_theme_stylebox_override("hover", Signpost.box(w, h, HT.RIM_HI, HT.OUTLINE))
	for st: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Signpost.box(w, h, HT.RIM_LO, HT.OUTLINE))
	b.add_theme_stylebox_override("focus", Signpost.box(w, h, HT.RIM, HT.ACCENT, true))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_right = -float(Signpost.tip_px(h))
	cc.offset_bottom = -float(Signpost.PX)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_k.lbl("YOLA ÇIK", 40, HT.TEXT))
	b.add_child(cc)
	b.pressed.connect(_confirm)
	return b


func _confirm() -> void:
	if voting or not _selectable(_sel):
		return
	chosen.emit(_sel)


# ---------------------------------------------------------------- seçim

## `_sel` = önizlemede gösterilen (odaktaki) harita. Oylamada ayrıca: oyum + kazanan (aşağıdaki _refresh_rows).
func _select(id: String, user: bool, sound: bool = false) -> void:
	if not _selectable(id):
		return
	var changed: bool = id != _sel
	_sel = id
	_refresh_rows()
	var p: Dictionary = MapProfiles.get_profile(id)
	_preview.texture = load(ART_DIR + "onizleme_%s.png" % id) as Texture2D
	_name_l.text = _up(str(p.get("ad", id)))
	_kind_l.text = _kind(id)
	_desc_l.text = str(p.get("aciklama", ""))
	if changed and user:
		if sound:
			UISound.play_click()
		if not voting:
			pick_changed.emit(id)


## OYLAMA: bu haritaya oy ver (satır tıklaması / ui_accept). Önizleme de bu haritaya geçer; oy NetworkManager'a `voted` ile gider.
func _vote_for(id: String, sound: bool) -> void:
	if not voting or _winner != "" or not _selectable(id):
		return
	_select(id, false)
	if sound:
		UISound.play_click()
	voted.emit(id)


## Satır görünümü + oy yüzleri. Normal kipte vurgulu satır = odaktaki; oylamada vurgulu satır = OYUM (kazanan belliyse kazanan, diğerleri solar),
## oy vermeden odaktaki (önizlemedeki) satır yalnız ince açık kenarla işaretlenir.
func _refresh_rows() -> void:
	var marked: String = _sel
	if voting:
		marked = _winner if _winner != "" else str(_votes.get(_me, ""))
	for rid: String in _rows:
		var on: bool = rid == marked
		var focus_only: bool = voting and not on and rid == _sel and _winner == ""
		var b: Button = _rows[rid][0]
		var edge: Color = HT.ACCENT if on else (_k.c("line_hi") if focus_only else _k.c("line"))
		var st: StyleBox = _k.sb(HT.PLATE_ON if on else _k.c("panel3"), edge, 3, 6)
		b.add_theme_stylebox_override("normal", st)
		if on or _winner != "":
			b.add_theme_stylebox_override("hover", st)
		else:
			b.remove_theme_stylebox_override("hover")
		b.modulate = Color(1, 1, 1, 0.5) if _winner != "" and not on else Color.WHITE
		(_rows[rid][1] as Label).add_theme_color_override("font_color", HT.ACCENT if on else HT.TEXT)
	if voting:
		_refresh_faces()


## Her satırda o haritaya oy verenlerin yüzleri (peer id sırasıyla, en çok VOTE_FACES_MAX).
func _refresh_faces() -> void:
	var by_map: Dictionary = {}
	var pids: Array = _votes.keys()
	pids.sort()
	for pid in pids:
		var mid: String = str(_votes[pid])
		if not by_map.has(mid):
			by_map[mid] = []
		(by_map[mid] as Array).append(int(pid))
	for rid: String in _rows:
		var box: HBoxContainer = _rows[rid][2]
		if box == null:
			continue
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
		var list: Array = by_map.get(rid, [])
		for i in mini(list.size(), VOTE_FACES_MAX):
			var cid: int = int(NetworkManager.lobby_players.get(list[i], {}).get("char_id", 1))
			box.add_child(PortraitFace.face_icon(cid, FACE_BOX))


## Sağ üst: kalan süre + oy sayısı; kazanan belli olunca "KAZANAN" + oy sayısı / beraberlik notu.
func _refresh_vote_texts() -> void:
	if not voting or _vote_head_l == null:
		return
	if _winner != "":
		var n: int = 0
		for pid in _votes.keys():
			if str(_votes[pid]) == _winner:
				n += 1
		_vote_head_l.text = tr("KAZANAN")
		if _tie:
			_vote_sub_l.text = tr("Beraberlik: rastgele seçildi")
		else:
			_vote_sub_l.text = (Loc.t("%d oy") % n) if n > 0 else ""
		return
	_vote_head_l.text = Loc.t("%d sn") % maxi(_last_sec, 0)
	_vote_sub_l.text = Loc.t("%d / %d oy") % [_votes.size(), maxi(_total, _votes.size())]


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or ev.is_echo():
		return
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if can_cancel:
			cancelled.emit()
		return
	if voting and _winner != "":
		return
	var step: int = 0
	if ev.is_action_pressed("ui_up"):
		step = -1
	elif ev.is_action_pressed("ui_down"):
		step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		var ids: Array[String] = map_ids()
		var i: int = clampi(ids.find(_sel) + step, 0, ids.size() - 1)
		_select(ids[i], true, true) ## oylamada yalnız odak/önizleme değişir; oy ui_accept ile (yanlışlıkla son oy olmasın)
	elif ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if voting:
			_vote_for(_sel, true)
		else:
			_confirm()
