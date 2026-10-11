extends RefCounted

## Çok oyunculu menülerin ORTAK parçaları (2026-10-11 lobi sistemi): oda listesi (room_browser.gd), oda lobisi (room_lobby.gd)
## ve karakter seçimi (lobby_menu.gd) aynı oyuncu satırını, yüz portresini ve sohbet kutusunu kullanır. Eskiden bunlar
## lobby_menu.gd'nin içindeydi.

const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const PreviewScript: GDScript = preload("res://scripts/menu_character_preview.gd")

## Portreler (characters.gd "portrait") 48x48 TAM BOY çizimler - yüz o boyutta seçilmiyor. Çizili alanın üst-ortasından
## FACE_ART x FACE_ART sanat pikseli (baş + şapka) kesilir, tam sayı katında büyütülür - piksel sanatı bozulmaz.
const FACE_ART := 24
static var _face_cache: Dictionary = {}


## Portrenin baş kısmı: çizili alanın yatay ortası, üst kenarından bir piksel yukarısı. Kesimler önbellekte.
static func face_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if _face_cache.has(path):
		return _face_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	var size: int = mini(FACE_ART, mini(img.get_width(), img.get_height()))
	var x: int = clampi(used.position.x + used.size.x / 2 - size / 2, 0, img.get_width() - size)
	var y: int = clampi(used.position.y - 1, 0, img.get_height() - size)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x, y, size, size)
	_face_cache[path] = at
	return at


static func face_rect(char_id: int, px: float) -> Control:
	var cdef: Dictionary = Characters.get_def(char_id)
	var face_tex: Texture2D = face_texture(str(cdef.get("portrait", "")))
	if face_tex == null:
		var mini: Control = PreviewScript.new()
		mini.custom_minimum_size = Vector2(px, px)
		mini.setup(cdef, maxi(1, roundi(px / 48.0)), px - 2.0)
		return mini
	var face := TextureRect.new()
	face.texture = face_tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(px, px)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


## Odadaki bir oyuncu satırı: YÜZ + 1. satır isim [HOST] (+ hazır rozeti), 2. satır karakter adı + başlangıç silahı ve ruhani
## yetenek ikonu (lobby_players "weapon"/"spirit"). opts: fs_body, fs_small, k (portre katı), ready_badge (bool), extra (Control:
## satırın sonuna, ör. "At" düğmesi).
static func make_player_row(pinfo: Dictionary, opts: Dictionary) -> Control:
	var fs_body: int = int(opts.get("fs_body", MenuKit.FS_BODY))
	var fs_small: int = int(opts.get("fs_small", MenuKit.FS_SMALL))
	var k: int = int(opts.get("k", 1))
	var cdef: Dictionary = Characters.get_def(pinfo.get("char_id", 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var slot := MenuKit.make_panel("slot_normal")
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	slot.add_child(face_rect(int(pinfo.get("char_id", 1)), float(FACE_ART * 2 * k)))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var host_tag: String = "  [HOST]" if pinfo.get("is_host", false) else ""
	var name_lbl := MenuKit.make_label("%s%s" % [pinfo.get("name", "Oyuncu"), host_tag], fs_body, MenuKit.C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_lbl)
	if bool(opts.get("ready_badge", true)):
		var is_ready: bool = pinfo.get("is_ready", false)
		var badge := MenuKit.make_panel("tag_pasif" if is_ready else "tag_ulti")
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(MenuKit.make_label("HAZIR" if is_ready else "SEÇİYOR", fs_small, MenuKit.C_CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		top.add_child(badge)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	col.add_child(bottom)
	var char_lbl := MenuKit.make_label(str(cdef.get("name", "Karakter")), fs_small, MenuKit.C_TEXT_DIM)
	char_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_lbl.clip_text = true
	char_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(char_lbl)
	var icon_px: float = 32.0 * k
	var weapon_key: String = str(pinfo.get("weapon", ""))
	if WeaponCatalog.is_valid(weapon_key):
		bottom.add_child(_loadout_icon(WeaponCatalog.icon(weapon_key), icon_px, "Silah: " + WeaponCatalog.display_name(weapon_key)))
	var spirit_id: String = str(pinfo.get("spirit", ""))
	if SpiritualSkillsScript.is_valid(spirit_id):
		var sdef: Dictionary = SpiritualSkillsScript.get_def(spirit_id)
		var sicon: String = str(sdef.get("icon", ""))
		var stex: Texture2D = load(sicon) as Texture2D if sicon != "" and ResourceLoader.exists(sicon) else null
		bottom.add_child(_loadout_icon(stex, icon_px, "Ruhani yetenek: " + str(sdef.get("name", spirit_id))))

	var extra: Control = opts.get("extra", null)
	if extra != null:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(extra)
	return row


## Boş oda yeri satırı (oda lobisi: sınıra kadar).
static func make_empty_row(fs_body: int, k: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var slot := MenuKit.make_panel("slot_normal")
	slot.custom_minimum_size = Vector2(FACE_ART * 2 * k + 12, FACE_ART * 2 * k + 12)
	row.add_child(slot)
	var lbl := MenuKit.make_label("Boş yer", fs_body, MenuKit.C_TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row


static func _loadout_icon(tex: Texture2D, px: float, tip: String) -> Control:
	var frame := MenuKit.make_panel("slot_normal")
	frame.tooltip_text = tip
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame


## Bağlantı koptuysa (host kapattı, atıldım, ağ gitti) oda listesine döner; sebep NetworkManager.last_status_message'ta.
## Oda lobisi ve karakter seçimi her karede çağırır.
static func leave_if_disconnected(node: Node) -> bool:
	if NetworkManager.is_multiplayer_active:
		return false
	node.get_tree().change_scene_to_file("res://scenes/room_browser.tscn")
	return true


## Ekran ölçüleri (masaüstü / telefon): fs_body, fs_small, ctl_h, k + oda ekranlarının İÇERİK ölçüleri (2026-10-11, kullanıcı:
## "oda kurma arayüzlerinin içindeki şeyler çok ufak ve arayüzün kendisi çok büyük - butonlar hariç"): fs_label (etiket/liste/sohbet
## yazısı), fs_input + input_h (yazı kutuları). Piksel yazı tipi (m5x7) 16'nın katlarında net: 32 / 48. Düğmeler fs_body + ctl_h ile aynı kalır.
static func sizes(mobile: bool) -> Dictionary:
	if mobile:
		return {"fs_body": 40, "fs_small": 32, "ctl_h": 96.0, "k": 2, "fs_label": 40, "fs_input": 48, "input_h": 96.0}
	return {"fs_body": MenuKit.FS_BODY, "fs_small": MenuKit.FS_SMALL, "ctl_h": 48.0, "k": 1, "fs_label": MenuKit.FS_BODY, "fs_input": 48, "input_h": 64.0}


## Ekranın kullanılabilir alanı (telefonda güvenli kenar payı düşülmüş).
static func safe_rect(node: Control, mobile: bool) -> Rect2:
	var view: Vector2 = node.get_viewport().get_visible_rect().size
	if not mobile:
		return Rect2(Vector2.ZERO, view)
	var safe: Rect2 = preload("res://scripts/mobile_ui.gd").safe_margins(node.get_viewport())
	return Rect2(safe.position, view - safe.position - safe.size)
