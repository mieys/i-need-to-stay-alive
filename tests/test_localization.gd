extends Node

## Madde 446: dil desteği altyapısı. Ayar dosyasına YAZMAMAK için UISound.set_language değil Localization.apply kullanılır.

const L := preload("res://scripts/localization.gd")
const WeaponCatalog := preload("res://scripts/weapon_catalog.gd")
const POT := "res://localization/oyun.pot"
const EN_PO := "res://localization/en.po"
## Tamamen çevrilmiş sayılan dosyalar: bunlardaki her aday metnin en.po'da çevirisi olmalı (aynı kalan = msgid'in aynısı).
const DONE_FILES := ["scripts/main_menu.gd", "scripts/settings_screen.gd", "scripts/ui_sound.gd", "scripts/fire_menu_kit.gd",
	## 2. parti: HUD + level kartları + pazar
	"scripts/level_up_screen.gd", "scripts/level_market.gd", "scripts/level_market_view.gd", "scripts/level_special_cards.gd",
	"scripts/tier_system.gd", "scripts/hud_stat_panel.gd", "scripts/hud_legend_slots.gd", "scripts/hud_pet_slot.gd",
	"scripts/skill_icon.gd", "scripts/party_panel.gd", "scripts/wait_overlay.gd", "scripts/game_notice.gd", "scripts/recipe_tree.gd",
	"scripts/kill_gold.gd", "scenes/hud.tscn", "scenes/level_up_screen.tscn",
	## 3. parti: açıklamalar
	"scripts/characters.gd", "scripts/skill_evolutions.gd", "scripts/items.gd", "scripts/weapon_catalog.gd",
	"scripts/weapon_traits/weapon_traits.gd", "scripts/enchant_defs.gd", "scripts/shield_enchant_defs.gd", "scripts/damage_stats.gd",
	"scripts/spiritual_skills.gd",
	## 4. parti: kalan ekranlar (tamamı çevrili olanlar)
	"scenes/chest_menu.tscn",
	"scenes/inventory_panel.tscn",
	"scenes/loading_screen.tscn",
	"scenes/shop_panel.tscn",
	"scenes/stats_panel.tscn",
	"scripts/achievements.gd",
	"scripts/atmosphere.gd",
	"scripts/atmosphere_math.gd",
	"scripts/babaanne_npc.gd",
	"scripts/blacksmith_npc.gd",
	"scripts/cadi_math.gd",
	"scripts/character_select.gd",
	"scripts/chest_menu.gd",
	"scripts/downed_spectate.gd",
	"scripts/dungeon/dungeon_defs.gd",
	"scripts/enchant_pool.gd",
	"scripts/game_manager.gd",
	"scripts/hide_brush.gd",
	"scripts/house_hp_bar.gd",
	"scripts/house_intro.gd",
	"scripts/hud_tooltip.gd",
	"scripts/kirpi_pet.gd",
	"scripts/last_loadout.gd",
	"scripts/lobby_menu.gd",
	"scripts/lobby_select_desktop.gd",
	"scripts/localization.gd",
	"scripts/magnet_drop.gd",
	"scripts/menu_character_details.gd",
	"scripts/menu_lobby_chat.gd",
	"scripts/menu_lobby_ui.gd",
	"scripts/menu_pet_picker.gd",
	"scripts/menu_weapon_picker.gd",
	"scripts/merchant_arrow.gd",
	"scripts/merchant_npc.gd",
	"scripts/merchant_shop_screen.gd",
	"scripts/meta_progress.gd",
	"scripts/meta_upgrades.gd",
	"scripts/mine_world.gd",
	"scripts/mobile_quick_chat.gd",
	"scripts/net/host_migration.gd",
	"scripts/pause_menu.gd",
	"scripts/peri_pet.gd",
	"scripts/pet_catalog.gd",
	"scripts/production_button.gd",
	"scripts/room_lobby.gd",
	"scripts/run_records.gd",
	"scripts/run_summary_ui.gd",
	"scripts/shop_panel.gd",
	"scripts/spiritual_picker.gd",
	"scripts/status_effect_badge.gd",
	"scripts/tier_display.gd",
	"scripts/victory_overlay.gd",
	"scripts/weapon_shop_logic.gd",
	"scripts/weapon_traits/seri_parmak.gd",
	"scripts/world_event_banner.gd"]

var _keep: String = "tr"


func _begin() -> void:
	_keep = L.current()


func _end() -> void:
	L.apply(UISound.language)


func test_source_language_ignores_english_catalog() -> void:
	_begin()
	L.apply("en")
	assert(TranslationServer.translate("Tam Ekran") == "Fullscreen", "en: çeviri gelmeli")
	L.apply("tr")
	## yedek dil tuzağı: en kataloğu yüklü kalsaydı tr'de de "Fullscreen" çıkardı
	assert(TranslationServer.translate("Tam Ekran") == "Tam Ekran", "tr: katalog çıkarılmalı, Türkçe kalmalı")
	assert(L.current() == "tr")
	_end()


func test_unknown_code_falls_back_to_source() -> void:
	_begin()
	L.apply("xx")
	assert(L.current() == "tr", "bilinmeyen dil Türkçe")
	assert(TranslationServer.translate("Tam Ekran") == "Tam Ekran")
	_end()


func test_label_auto_translates_and_follows_language_change() -> void:
	_begin()
	L.apply("en")
	var l := Label.new()
	l.text = "Ekran Sarsıntısı"
	add_child(l)
	assert(l.atr(l.text) == "Screen Shake", "düz metinli Label kendiliğinden çevrilmeli")
	L.apply("tr")
	assert(l.atr(l.text) == "Ekran Sarsıntısı")
	l.free()
	_end()


func test_untranslated_text_stays_turkish() -> void:
	_begin()
	L.apply("en")
	assert(TranslationServer.translate("Bu metin hiçbir yerde yok 123") == "Bu metin hiçbir yerde yok 123")
	_end()


func test_percent_pattern() -> void:
	_begin()
	L.apply("en")
	assert(TranslationServer.translate("%%%d") % 50 == "50%", "İngilizce yüzde sonda")
	L.apply("tr")
	assert(TranslationServer.translate("%%%d") % 50 == "%50")
	_end()


func test_german_catalog_and_kind_parsing() -> void:
	_begin()
	L.apply("de")
	assert(TranslationServer.translate("Tam Ekran") == "Vollbild", "de: çeviri gelmeli")
	L.apply("en")
	assert(TranslationServer.translate("Tam Ekran") == "Fullscreen", "de -> en: yalnız en kataloğu")
	L.apply("tr")
	## Almanca tür öneki (Ä) ipucunda ayrılmalı
	var SI = preload("res://scripts/skill_icon.gd")
	var parts: Array = SI._split_kind("FÄHIGKEIT (an/aus): Text")
	assert(parts[0] == "FÄHIGKEIT" and parts[1] == "an/aus", "FÄHIGKEIT öneki ayrılmalı: %s" % str(parts))
	_end()


## 2026-11-09 yeni diller: her dilde, Türkçesinde tür öneki ("YETENEK:") olan her yetenek açıklamasının çevirisinde de öneki
## ipucu ayrıştırıcısı bulmalı; Türkçesinde "(N sn bekleme)" notu atılan her açıklamanın çevirisinde de not atılmalı.
func test_tooltip_parsing_every_language() -> void:
	_begin()
	var SI = preload("res://scripts/skill_icon.gd")
	var si = SI.new()
	var bad: Array = []
	for code in L.codes():
		L.apply(code)
		for id in Characters.DEFS:
			var raw: Dictionary = Characters.get_def_raw(id)
			var loc: Dictionary = Characters.get_def(id)
			for key in ["skill_desc", "skill2_desc", "skill3_desc"]:
				var tr_text: String = str(raw.get(key, ""))
				if tr_text == "":
					continue
				var shown: String = str(loc.get(key, ""))
				if SI._split_kind(tr_text)[0] != "" and SI._split_kind(shown)[0] == "":
					bad.append("%s %s.%s: tür öneki yok: %s" % [code, id, key, shown.left(40)])
				if si._strip_cooldown_note(tr_text) != tr_text and si._strip_cooldown_note(shown) == shown:
					bad.append("%s %s.%s: bekleme notu kalmış: %s" % [code, id, key, shown.right(40)])
	si.free()
	L.apply("tr")
	assert(bad.is_empty(), "ipucu ayrıştırma: %s" % str(bad))
	_end()


## m5x7 Kiril çizmez, hiçbir arayüz fontu Çince çizmez -> yedek fontlar (Localization.setup_font_fallbacks).
func test_font_fallbacks_cover_new_scripts() -> void:
	L.setup_font_fallbacks()
	var m5: FontFile = load("res://assets/fonts/m5x7.ttf")
	var ok_ru: bool = false
	var ok_zh: bool = false
	for f in m5.fallbacks:
		if (f as FontFile).has_char("Ж".unicode_at(0)):
			ok_ru = true
		if (f as FontFile).has_char("技".unicode_at(0)):
			ok_zh = true
	assert(ok_ru and ok_zh, "m5x7 yedekleri Kiril + Çince çizmeli")


func test_language_list_has_catalogs() -> void:
	for code in L.codes():
		if code == L.SOURCE:
			continue
		assert(ResourceLoader.exists(L.PO_DIR + code + ".po"), "%s.po yok" % code)
	assert(L.names().size() == L.codes().size())


static func _placeholders(s: String) -> Array:
	var re := RegEx.new()
	re.compile("%(%|[-+0#]*[0-9]*(?:\\.[0-9]+)?[dsfxXcv])") ## boşluk bayrağı yok: İngilizce "50% damage" yer tutucu sanılmasın
	var out: Array = []
	for m in re.search_all(s):
		out.append(m.get_string())
	return out


static func _named_tokens(s: String) -> Array:
	var re := RegEx.new()
	re.compile("\\{[a-zA-Z_]+\\}")
	var out: Array = []
	for m in re.search_all(s):
		out.append(m.get_string())
	out.sort()
	return out


## Her çeviri dili (tr hariç): % yer tutucuları AYNI SIRADA, {stat}/{HEAL} gibi adlı olanlar aynı kümede.
func test_po_placeholders_match() -> void:
	var L = preload("res://scripts/localization.gd")
	var bad: Array = []
	for code in L.codes():
		if code == "tr":
			continue
		var t: Translation = load(L.PO_DIR + code + ".po") as Translation
		assert(t != null, "%s.po yüklenmeli" % code)
		for id in t.get_message_list():
			var tr_: String = t.get_message(id)
			if tr_ == "":
				continue
			## Sıra ÖNEMLİ (Godot % biçimi konumlu argüman "%2$d" bilmez); yalnız "%%" (düz yüzde işareti) yer değiştirebilir.
			var a: Array = _placeholders(String(id)).filter(func(x: String) -> bool: return x != "%%")
			var b: Array = _placeholders(tr_).filter(func(x: String) -> bool: return x != "%%")
			if a != b or tr_.contains("$") or _named_tokens(String(id)) != _named_tokens(tr_):
				bad.append("%s: %s -> %s" % [code, id, tr_])
	assert(bad.is_empty(), "yer tutucu uyuşmuyor: %s" % str(bad))


## oyun.pot'u okur: {msgid: [dosya, ...]}
static func _pot_refs() -> Dictionary:
	var out: Dictionary = {}
	var files: Array = []
	for raw in FileAccess.get_file_as_string(POT).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#: "):
			var ref: String = line.substr(3)
			files.append(ref.substr(0, ref.rfind(":")))
		elif line.begins_with("msgid \""):
			var id: String = line.substr(7, line.length() - 8).replace("\\\"", "\"").replace("\\n", "\n").replace("\\\\", "\\")
			if id != "":
				out[id] = files
			files = []
	return out


func test_done_files_fully_translated() -> void:
	assert(FileAccess.file_exists(POT), "önce: python -I tools/dil/dil_cikar.py")
	var t: Translation = load(EN_PO) as Translation
	var refs: Dictionary = _pot_refs()
	var missing: Array = []
	for id in refs:
		for f in refs[id]:
			if DONE_FILES.has(f) and t.get_message(id) == "":
				missing.append("%s (%s)" % [id, f])
				break
	assert(missing.is_empty(), "çevrilmemiş: %s" % str(missing))


func test_pseudo_env_off_by_default() -> void:
	if OS.get_environment("DIL_SAHTE") == "1":
		return
	assert(not TranslationServer.pseudolocalization_enabled, "sahte yerelleştirme yalnız DIL_SAHTE=1 ile")


## 3. parti: tanım tabloları kaynakta çevrilir (Localization.localized). Kaynak dilde AYNI sözlük, İngilizcede metin alanları çevrili kopya;
## mantık alanları ve ham tablo (balans kaydı) dokunulmaz.
func test_definition_tables_localized_at_source() -> void:
	_begin()
	L.apply("tr")
	assert(str(Characters.get_def(9).get("name")) == "Korsan" and Characters.get_def(9) == Characters.DEFS[9], "tr: tablo olduğu gibi")
	L.apply("en")
	var d: Dictionary = Characters.get_def(9) ## Korsan
	assert(str(d.get("name")) == "Pirate", "karakter adı çevrilmeli: %s" % d.get("name"))
	assert(str(d.get("skill2_name")) == "Time Bomb")
	assert(str(d.get("skill_desc")).begins_with("ABILITY:"), "açıklama çevrilmeli")
	assert(d.get("skill") == Characters.DEFS[9].get("skill"), "mantık alanı aynı")
	assert(str(Characters.get_def_raw(9).get("name")) == "Korsan", "ham tablo Türkçe kalır (balans kaydı)")
	assert(is_same(Characters.get_def(9), d), "dil başına önbellek")
	var desc: String = Items.describe("kiyamet_bicagi") if Items.DEFS.has("kiyamet_bicagi") else ""
	if desc != "":
		assert(desc.find("Pasif") < 0 and desc.find("Saldırı") < 0, "eşya açıklaması İngilizce: %s" % desc)
	var any_trait: String = ""
	for k in WeaponCatalog.KEYS:
		any_trait = WeaponCatalog.trait_text(k)
		if any_trait != "":
			break
	assert(not any_trait.contains("saldırı gücü"), "silah özelliği İngilizce: %s" % any_trait)
	L.apply("tr")
	assert(str(Characters.get_def(9).get("name")) == "Korsan", "tr'ye dönünce Türkçe")
	_end()
