extends RefCounted

## SON TEK OYUNCULU SEÇİM (2026-10-19; telefon ana menüsü "Son seçim" kartı + HIZLI BAŞLA, prototip S): karakter, evcil, başlangıç
## silahı, ruhani yetenek. Tek oyunculu karakter seçiminde OYUNU BAŞLAT'ta yazılır (character_select.gd); okurken kilitli / geçersiz
## olanlar varsayılana çekilir (lobby_select_desktop.gd _validate_loadout ile aynı kural). Dosya yoksa o anki GameManager seçimi.

const PATH := "user://last_loadout.cfg"
const MP := preload("res://scripts/meta_progress.gd")
const WC := preload("res://scripts/weapon_catalog.gd")
const PC := preload("res://scripts/pet_catalog.gd")
const SS := preload("res://scripts/spiritual_skills.gd")


static func save() -> void:
	var c := ConfigFile.new()
	c.set_value("last", "char", GameManager.selected_char_id)
	c.set_value("last", "pet", GameManager.selected_pet)
	c.set_value("last", "weapon", GameManager.selected_start_weapon)
	c.set_value("last", "spirit", GameManager.selected_spiritual)
	c.save(PATH)


## {char, pet, weapon, spirit} - hepsi geçerli ve açık.
static func load_valid() -> Dictionary:
	var c := ConfigFile.new()
	var ok: bool = c.load(PATH) == OK
	var cid: int = int(c.get_value("last", "char", GameManager.selected_char_id)) if ok else GameManager.selected_char_id
	if not Characters.DEFS.has(cid) or not MP.is_unlocked(MP.CHAR, cid):
		cid = 1
	var w: String = str(c.get_value("last", "weapon", "")) if ok else GameManager.selected_start_weapon
	if not WC.is_valid(w) or not MP.is_unlocked(MP.WEAPON, w):
		w = WC.DEFAULT_KEY
	var p: String = str(c.get_value("last", "pet", "")) if ok else GameManager.selected_pet
	if not PC.is_valid(p) or not MP.is_unlocked(MP.PET, p):
		p = PC.DEFAULT_KEY
	var s: String = str(c.get_value("last", "spirit", "")) if ok else GameManager.selected_spiritual
	if not SS.is_valid(s) or not MP.is_unlocked(MP.SPIRIT, s):
		s = SS.DEFAULT_ID
	return {"char": cid, "pet": p, "weapon": w, "spirit": s}


## Kartta gösterilen kısa özet: "Oakley, Peri, Tüfek".
static func summary(lo: Dictionary) -> String:
	return "%s, %s, %s" % [str(Characters.get_def(int(lo["char"])).get("name", "")), PC.display_name(str(lo["pet"])),
			WC.display_name(str(lo["weapon"]))]


## Seçimi GameManager'a yazar (oyuna başlamadan önce).
static func apply(lo: Dictionary) -> void:
	var cid: int = int(lo["char"])
	GameManager.selected_char_id = cid
	GameManager.selected_character = Characters.get_def(cid)["skill"]
	GameManager.selected_pet = str(lo["pet"])
	GameManager.selected_start_weapon = str(lo["weapon"])
	GameManager.selected_spiritual = str(lo["spirit"])
