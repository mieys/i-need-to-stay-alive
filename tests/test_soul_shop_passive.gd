extends Node

## Ruh Mağazası KARAKTER ayrıntısı (madde 604, "A - Yetenek Sekmeleri"; soul_shop_screen.gd _char_detail):
## - pasifli karakterde ilk sekme PASİF, her sekmenin açıklaması KESİLMEDEN tam görünür (eski düzen 2-3 satırda "..." ile kesiyordu);
## - en uzun metin de (Cadı R 552 harf) kuyuda kaydırmasız sığar, anahtar notu (madde 605) varken AÇ düğmesi ekrandan taşmaz;
## - sekmeye basmak / üstüne gelmek seçer, başka karakter seçilince pasife döner.

const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SoulShopScript: GDScript = preload("res://scripts/soul_shop_screen.gd")
const SETTLE := 1.6

var _tmp: String = ""


func _begin() -> void:
	_tmp = "user://test_soul_passive_%d.cfg" % Time.get_ticks_usec()
	MetaProgressScript.set_path_override(_tmp)
	MetaProgressScript.set_unlock_all(false)


func _end(shop: Node) -> void:
	if is_instance_valid(shop):
		shop.queue_free()
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	MetaProgressScript.set_path_override("")
	_tmp = ""


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _by_sid(root: Node, sid: String, type: String = "Control") -> Node:
	for n: Node in root.find_children("*", type, true, false):
		if n.has_meta("sid") and str(n.get_meta("sid")) == sid:
			return n
	return null


## Kuyudaki RichTextLabel'ların düz metni (boyama etiketleri atılmış).
func _well_text(shop: Node) -> String:
	var sc: Node = _by_sid(shop, "sk_scroll", "ScrollContainer")
	if sc == null:
		return ""
	var out: String = ""
	for r: Node in sc.find_children("*", "RichTextLabel", true, false):
		out += (r as RichTextLabel).get_parsed_text() + "\n"
	return out


func test_character_detail_full_text_fits() -> void:
	_begin()
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	await _wait(SETTLE)
	var vp_h: float = shop.get_viewport().get_visible_rect().size.y
	var checked: int = 0
	var worst: float = -9999.0
	var worst_at: String = ""
	for it: Dictionary in shop.call("_items"):
		if it["kind"] != MetaProgressScript.CHAR:
			continue
		shop.call("_select", it)
		await _frames()
		var ents: Array = shop.call("_sk_entries", it)
		var def: Dictionary = Characters.get_def(int(it["key"]))
		if str(def.get("passive", "")) != "":
			assert(str(ents[0]["key"]) == "P", "%s: ilk sekme pasif değil" % it["name"])
			assert(str(def["passive"]).ends_with(str(ents[0]["body"]).substr(1)), "%s: pasif metni eksik" % it["name"]) ## ilk harf büyütülür (_sk_cap_first)
		for i in ents.size():
			shop.call("_on_sk_tab", i)
			await _frames()
			var e: Dictionary = ents[i]
			var shown: String = _well_text(shop)
			assert(shown.contains(str(e["body"])), "%s %s: açıklama tam görünmüyor" % [it["name"], e["key"]])
			var sc: ScrollContainer = _by_sid(shop, "sk_scroll", "ScrollContainer") as ScrollContainer
			var over: float = (sc.get_child(0) as Control).size.y - sc.size.y
			if over > worst:
				worst = over
				worst_at = "%s %s" % [it["name"], e["key"]]
			assert(over <= 0.5, "%s %s: açıklama kuyuya sığmıyor (%.0f px kayıyor)" % [it["name"], e["key"], over])
			var bb: Button = _by_sid(shop, "buy", "Button") as Button
			if bb != null:
				var bottom: float = bb.get_global_rect().end.y
				assert(bottom + 32.0 <= vp_h + 0.5, "%s: AÇ düğmesi ekrandan taşıyor (alt %.0f + 32 pay > %.0f)" % [it["name"], bottom, vp_h])
			checked += 1
	print("karakter ayrıntısı: %d sekme, en dar kuyu payı %.0f px (%s)" % [checked, -worst, worst_at])
	assert(checked >= 30, "denetlenen sekme sayısı beklenenden az: %d" % checked)
	_end(shop)


func test_tab_select_and_reset() -> void:
	_begin()
	var shop: CanvasLayer = SoulShopScript.new()
	add_child(shop)
	await _wait(SETTLE)
	var chars: Array = []
	for it: Dictionary in shop.call("_items"):
		if it["kind"] == MetaProgressScript.CHAR:
			chars.append(it)
	assert(chars.size() >= 2, "en az iki karakter gerekli")
	shop.call("_select", chars[0])
	await _frames()
	var tab: Button = _by_sid(shop, "sk:2", "Button") as Button
	assert(tab != null, "üçüncü sekme düğmesi yok")
	tab.pressed.emit()
	await _frames()
	assert(int(shop.get("_sk_sel")) == 2, "sekmeye basınca seçilmedi")
	var e2: Dictionary = (shop.call("_sk_entries", chars[0]) as Array)[2]
	assert(_well_text(shop).contains(str(e2["body"])), "kuyu seçilen sekmeyi göstermiyor")
	(_by_sid(shop, "sk:1", "Button") as Button).mouse_entered.emit()
	await _frames()
	assert(int(shop.get("_sk_sel")) == 1, "üstüne gelince seçilmedi")
	shop.call("_select", chars[1])
	await _frames()
	assert(int(shop.get("_sk_sel")) == 0, "başka karakterde ilk sekmeye dönmedi")
	_end(shop)
