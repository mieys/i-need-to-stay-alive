extends PanelContainer

## Seçili karakterin bilgi paneli (tek/çok oyunculu ekranların ORTAK bileşeni): üstte isim (temel istatistikler vitrinde -
## menu_character_showcase.gd), altında her yetenek kendi satırında: [ikon] [tuş rozeti + yetenek adı + tür etiketi (ULTİ/TEMEL/PASİF)] + açıklama.
## Tuş harfi artık GERÇEK tuş atamasından okunuyor (GameManager.get_action_key_label) - eski lobi ekranı Q yeteneğine
## "(R tuşu)" yazıyordu ve 3. yetenek (R) satırı hiç yoktu; ikisi de bu ortak panelle düzeldi.
## Açıklama metinleri "ULTİ: ..." / "TEMEL: ..." / "YETENEK: ..." ön ekiyle başlıyor (bkz. characters.gd) - ön ek ayrı
## bir renkli etikete taşınır, metin tekrarlanmaz.

const SkillIconScript: GDScript = preload("res://scripts/skill_icon.gd")
## 96 = 48x48 piksel ikonların TAM 2x katı (72 = 1.5x idi, pikseller eşit çizilmiyordu - bkz. tools/gen_elara_korsan_icons.py).
## Kullanıcı isteği (2026-09-25, 13. karakter Suriyeli Hadime ile kart ızgarası 3. satıra çıktı): "alttaki yetenek
## açıklamalarındaki çoğu şey gereksiz büyük, okunurluğunu kolay bırakarak boyunu kısalt" - ikon 1x (48 = sanatın kendisi,
## yine tam sayı kat), tüm yazılar FS_SMALL, boşluklar ve panel payı sıkı. Panel ~280 px'e indi; uzun açıklamalar kayar.
const ICON_SIZE := 48

var _name_label: Label
var _rows_box: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	add_theme_stylebox_override("panel", MenuKit.style("panel_tight"))
	clip_contents = true

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	_name_label = MenuKit.make_label("", MenuKit.FS_BODY, MenuKit.C_TEXT)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name_label)
	var caption := MenuKit.make_label("Yetenekler", MenuKit.FS_SMALL, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(caption)

	var rule := ColorRect.new()
	rule.color = MenuKit.C_LINE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_rows_box)


func show_character(char_id: int) -> void:
	var def: Dictionary = Characters.get_def(char_id)
	_name_label.text = str(def.get("name", ""))
	for c in _rows_box.get_children():
		c.queue_free()
	_add_skill_row(def.get("skill", 1), def.get("skill_icon", ""), "skill", str(def.get("skill_name", "Ulti")), str(def.get("skill_desc", "")))
	if def.has("skill2"):
		_add_skill_row(def.get("skill2", 1), _icon_path(def, "skill2"), "skill2", str(def.get("skill2_name", "Temel")), str(def.get("skill2_desc", "")))
	if def.has("skill3"):
		_add_skill_row(def.get("skill3", 1), _icon_path(def, "skill3"), "skill3", str(def.get("skill3_name", "3. Yetenek")), str(def.get("skill3_desc", "")))
	## Pasif satırı: hud.gd _setup_ability_icons() ile aynı mantık (gerçek ikon yoksa passive_vector_id vektör ikonu).
	if def.has("passive") and not str(def["passive"]).is_empty():
		_add_skill_row(def.get("passive_vector_id", -1), def.get("passive_icon", ""), "", "", "PASİF: " + str(def["passive"]))
	_scroll.scroll_vertical = 0


## "<key>_icon" yoksa 2 setli yeteneklerin (Büyücü Kız) ilk set ikonu - HUD da oyun başında 1. seti gösterir
## (bkz. hud.gd skill2/skill3_variation_icons).
static func _icon_path(def: Dictionary, key: String) -> String:
	if def.has(key + "_icon"):
		return str(def[key + "_icon"])
	var variations: Array = def.get(key + "_variation_icons", [])
	return str(variations[0]) if variations.size() > 0 else ""


## desc başındaki ön eki ayırır -> [tür, not, metin]. characters.gd'deki biçimler: "ULTİ: ...", "3. YETENEK: ...",
## "ULTİ (kalkan harcamaz): ...", "TEMEL (E, 2 setli - ULTİ ile değiştirilir): ...", "R: ..." (tek harf = tuş adı;
## tuş rozeti zaten gösterdiği için etiket olmaz, yalnızca ön ek atılır). Ön ek yoksa tür/not boş döner.
static func _split_kind(desc: String) -> Array:
	var re := RegEx.new()
	re.compile("^\\s*((?:\\d+\\.\\s*)?[A-ZÇĞİÖŞÜ]+)\\s*(?:\\(([^)]*)\\))?\\s*:\\s*")
	var m: RegExMatch = re.search(desc)
	if m == null:
		return ["", "", desc]
	var kind: String = m.get_string(1)
	if kind.length() <= 1:
		kind = ""
	return [kind, m.get_string(2), desc.substr(m.get_end())]


func _add_skill_row(skill_id: int, icon_path: String, action: String, skill_name: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_rows_box.add_child(row)

	var slot := MenuKit.make_panel("slot_normal")
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(slot)
	var icon: Control = SkillIconScript.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	icon.set("frame_border", 0.0)
	icon.set("skill_id", skill_id)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.set("custom_texture", load(icon_path))
	icon.queue_redraw()

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	if action != "":
		var key := MenuKit.make_panel("keycap")
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_child(MenuKit.make_label(GameManager.get_action_key_label(action), MenuKit.FS_SMALL, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		head.add_child(key)
	## Pasif satırında başlık yok - yalnızca PASİF etiketi (başlık + etiket aynı kelimeyi tekrar ediyordu).
	if skill_name != "":
		var title := MenuKit.make_label(skill_name, MenuKit.FS_SMALL, MenuKit.C_TEXT)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(title)

	var parts: Array = _split_kind(desc)
	var kind: String = parts[0]
	if kind != "":
		var tag_style: String = "tag_ulti" if kind.begins_with("ULT") else ("tag_pasif" if kind.begins_with("PAS") else "tag_temel")
		var tag := MenuKit.make_panel(tag_style)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(MenuKit.make_label(kind, MenuKit.FS_SMALL, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		head.add_child(tag)
	var note: String = parts[1]
	if note != "":
		var note_lbl := MenuKit.make_label("(%s)" % note, MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
		note_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(note_lbl)

	var body := MenuKit.make_label(parts[2], MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(body)
