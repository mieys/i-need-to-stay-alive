extends Node

## Madde 756: yetenek / ruhani açıklamaları iki katmanlı (kısa varsayılan, uzun = Shift / AYRINTILI). Veri tutarlılığı, çeviri yedeği
## (kısa metnin çevirisi olmayan dilde çevrilmiş UZUN metin), karakter seçimi orta panelinin sığması ve AYRINTILI penceresi.

const L := preload("res://scripts/localization.gd")
const SS := preload("res://scripts/spiritual_skills.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const KEYS := ["skill", "skill2", "skill3", "passive", "golem_skill", "golem_skill2"]
const MID := Rect2(488, 24, 760, 1024)


static func _kind(t: String) -> String:
	var re := RegEx.new()
	re.compile("^\\s*(\\p{Lu}+)")
	var m: RegExMatch = re.search(t)
	return m.get_string(1) if m != null and m.get_string(1).length() > 1 else ""


func test_short_texts_are_shorter_and_keep_kind() -> void:
	for cid in Characters.DEFS:
		var d: Dictionary = Characters.DEFS[cid]
		for key: String in KEYS:
			var sk: String = key + "_short_desc"
			if not d.has(sk):
				continue
			var s: String = str(d[sk])
			var l: String = Characters.long_desc(d, key)
			assert(l != "", "%s %s: kısa var, uzun yok" % [cid, key])
			assert(s.length() < l.length(), "%s %s: kısa metin uzundan kısa olmalı" % [cid, key])
			assert(_kind(s) == _kind(l), "%s %s: tür öneki farklı (%s / %s)" % [cid, key, _kind(s), _kind(l)])
			assert(not s.contains("bekleme)"), "%s %s: kısa metinde bekleme notu olmaz (ipucu başlığında canlı)" % [cid, key])
			assert(Characters.short_desc(d, key) == s)
		assert(Characters.short_desc(d, "skill") != "", "%s: kısa ya da uzun Q metni yok" % cid)
	for id in SS.DEFS:
		var sd: Dictionary = SS.DEFS[id]
		if sd.has("short_desc"):
			assert(str(sd["short_desc"]).length() < str(sd["desc"]).length(), "ruhani %s kısa metni uzun" % id)
		assert(SS.short_desc(id) != "")


func test_passive_short_keeps_name_prefix() -> void:
	## skill_icon başlığı uzun metindeki addan çıkar; kısa metin aynı adla başlamazsa gövdeye ad sızar.
	var icon_script: GDScript = load("res://scripts/skill_icon.gd")
	for cid in Characters.DEFS:
		var d: Dictionary = Characters.DEFS[cid]
		if not d.has("passive_short_desc"):
			continue
		var ln: Array = icon_script.call("_split_passive_name", str(d["passive"]))
		var sn: Array = icon_script.call("_split_passive_name", str(d["passive_short_desc"]))
		assert(str(ln[0]) == str(sn[0]), "%s pasif adı: uzun '%s' kısa '%s'" % [cid, ln[0], sn[0]])


func test_untranslated_short_falls_back_to_translated_long() -> void:
	var keep: String = L.current()
	L.apply("en")
	var d: Dictionary = Characters.get_def(1)
	assert(str(d.get("skill_short_desc")).begins_with("ABILITY:"), "en kısa çevirisi: %s" % d.get("skill_short_desc"))
	L.apply("de")
	var dd: Dictionary = Characters.get_def(1)
	assert(str(dd.get("skill_short_desc")).begins_with("FÄHIGKEIT:"), "de kısa çevirisi: %s" % dd.get("skill_short_desc"))
	assert(L.t_short("TEMEL (Arcane Lanet): %d kez seken büyü, her sekişte saldırı gücünün %%%d'ü kadar hasar.") != "", "de: kısa kalıp çevrili")
	## Çevirisi OLMAYAN kısa metin -> çevrilmiş uzun metin (yeni kısa metin eklenip henüz çevrilmediğinde yarı Türkçe ekran olmasın).
	var fake: Dictionary = L.localized("test:kisa_yedek", {"skill_desc": "Tam Ekran", "skill_short_desc": "çevirisi olmayan kısa metin 756",
		"passive": "Tam Ekran", "passive_short_desc": "çevirisi olmayan pasif 756"})
	assert(str(fake["skill_short_desc"]) == str(fake["skill_desc"]) and str(fake["skill_desc"]) != "Tam Ekran", "de: kısa yoksa uzun çeviri: %s" % fake)
	assert(str(fake["passive_short_desc"]) == str(fake["passive"]), "de: pasif kısa -> uzun pasif")
	assert(L.t_short("çevirisi olmayan kalıp 756 %d") == "", "de: çevrilmemiş kalıp boş döner")
	L.apply("tr")
	assert(str(Characters.get_def(1).get("skill_short_desc")) == str(Characters.DEFS[1]["skill_short_desc"]))
	L.apply(UISound.language if keep == "" else keep)


func test_short_line_strips_kind_and_cooldown() -> void:
	var desk_script: GDScript = load("res://scripts/lobby_select_desktop.gd")
	assert(desk_script.call("short_line", "ULTİ: Bir şey yapar. (20sn bekleme)") == "Bir şey yapar.")
	assert(desk_script.call("short_line", "TEMEL (Q ile değişir):\n1) A\n2) B") == "1) A 2) B")
	assert(desk_script.call("short_line", "Yıldırım Hızı: hız kazanırsın") == "Yıldırım Hızı: hız kazanırsın", "pasif adı korunur")
	## Madde 759: Çincede tür öneki (Han kelime + parantez) da silinir; parantezsiz Han pasif adı korunur.
	assert(desk_script.call("short_line", "终极 (用 Q 切换):\n1) A\n2) B") == "1) A 2) B")
	assert(desk_script.call("short_line", "闪电速度：移动") == "闪电速度：移动", "Çince pasif adı korunur")


## Madde 759: orta paneldeki yetenek kısa metni (en çok SKILL_ROW_LINES satır, fazlası "…") HER DİLDE sığmalı. Lyra'nın "1) ... 2) ..."
## metinleri 10 dilin 9'unda, Matthew pasifi fr / pt'de, Hazel Q fr'de kırpılıyordu (ikon 48 -> 56 metin sütununu 658 -> 648 daralttı).
## Hatalar toplanıp sonda tek assert: yarıda kesilip dil / sahne temizliği atlanmasın.
func test_skill_rows_fit_in_every_language() -> void:
	MetaProgressScript.set_unlock_all(true)
	var prev: String = L.current()
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var desk: Node = scene.get("_desk")
	var skills: VBoxContainer = desk.get("_skills")
	var bad: Array = []
	var checked: int = 0
	var max_lines: int = 0
	for code in L.codes():
		L.apply(str(code))
		for id in Characters.DEFS.keys():
			desk.call("show_character", int(id), false)
			await get_tree().process_frame
			await get_tree().process_frame
			for lb: Label in skills.find_children("*", "Label", true, false):
				if lb.max_lines_visible <= 0:
					continue
				checked += 1
				max_lines = maxi(max_lines, lb.get_line_count())
				if lb.get_line_count() > lb.max_lines_visible:
					bad.append("%s %s '%s' (%d satır)" % [code, id, lb.text.left(30), lb.get_line_count()])
	L.apply(prev)
	scene.queue_free()
	MetaProgressScript.set_unlock_all(false)
	await get_tree().process_frame
	print("yetenek kısa metni denetimi: %d etiket, en çok %d satır, %d kırpık" % [checked, max_lines, bad.size()])
	assert(max_lines >= 2, "satır kırılımı ölçülemiyor (hep tek satır) - denetim boş geçer")
	assert(checked > 100, "denetlenen etiket çok az (%d)" % checked)
	assert(bad.is_empty(), "kırpılan yetenek kısa metni: %s" % ", ".join(bad))


func test_character_select_skills_fit_and_details_popup() -> void:
	MetaProgressScript.set_unlock_all(true)
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var desk: Node = scene.get("_desk")
	assert(desk != null)
	var skills: VBoxContainer = desk.get("_skills")
	var ids: Array = Characters.DEFS.keys()
	ids.sort()
	for id in ids:
		desk.call("show_character", int(id), false)
		await get_tree().process_frame
		await get_tree().process_frame
		var r: Rect2 = skills.get_global_rect()
		assert(r.end.y <= MID.end.y - 16.0, "%s: yetenek listesi orta panele sığmıyor (alt %d, sınır %d)" % [id, r.end.y, MID.end.y - 16.0])
		var mid_panel: Control = skills.get_parent().get_parent() as Control
		assert(mid_panel.size.y <= MID.size.y + 0.5, "%s: orta panel taştı (%d > %d)" % [id, mid_panel.size.y, MID.size.y])
		## 2026-11-16: 2 satırlık açıklamada ikon çerçevesi satır boyu gerilip ikon altında/üstünde siyah bant kalıyordu.
		for row: Node in skills.get_children():
			var frame: Control = row.get_child(0) as Control
			assert(absf(frame.size.y - frame.size.x) < 0.5, "%s: yetenek ikon çerçevesi kare değil (%s)" % [id, frame.size])
	desk.call("open_skill_details")
	await get_tree().process_frame
	var ov: Control = desk.get("_details_ov")
	assert(is_instance_valid(ov) and ov.visible, "AYRINTILI penceresi açılmadı")
	var labels: Array = ov.find_children("*", "Label", true, false)
	var d: Dictionary = Characters.get_def(int(ids[ids.size() - 1])) ## pencere son gösterilen karakteri açar
	var found: bool = false
	for lb: Label in labels:
		if lb.text == str(d.get("skill3_desc", "")):
			found = true
	assert(found, "pencerede R'nin uzun metni yok")
	desk.call("close_skill_details")
	await get_tree().process_frame
	assert(not is_instance_valid(ov) or ov.is_queued_for_deletion(), "KAPAT çalışmadı")
	scene.queue_free()
	MetaProgressScript.set_unlock_all(false)
