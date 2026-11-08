extends Node

## Sandık AL düğmesi kapalıyken gerçek engeli yazar (2026-11-06 oyuncu bildirimi: "slot dolu diyor ama pazarda alınıyor").
## Eskiden her engel "SLOTLAR DOLU" idi; parça/epik/efsanevi havuzları ayrı olduğundan hangisinin dolduğu görünmüyordu.

const ChestMenu := preload("res://scripts/chest_menu.gd")


func test_labels_name_the_pool_that_is_full() -> void:
	var m = ChestMenu.new()
	var owned: Array = []
	var parts: Array = []
	var epics: Array = []
	for k: String in Items.KEYS:
		if Items.kademe(k) == Items.KADEME_PARCA and parts.size() < 3:
			parts.append(k)
		elif Items.kademe(k) == Items.KADEME_EPIK and epics.size() < Items.EPIC_SLOT_LIMIT + 1:
			epics.append(k)
	## 3 parça slotu, 3 parça sahip -> yeni parça "PARÇA DOLU"
	for p in parts:
		owned.append({"key": p})
	var other_part: String = ""
	for k: String in Items.KEYS:
		if Items.kademe(k) == Items.KADEME_PARCA and not parts.has(k):
			other_part = k
			break
	var r_part: String = Items.purchase_block_reason(other_part, owned, 3, {"consume": []})
	assert(m._slot_block_label(r_part) == "PARÇA DOLU", "parça havuzu dolu: %s -> %s" % [r_part, m._slot_block_label(r_part)])
	assert(m._slot_block_sub(r_part) == "parça slotu dolu", "telefon alt satırı")
	## 10 epik sahip -> yeni epik "EPİK DOLU"
	var owned_e: Array = []
	for i in Items.EPIC_SLOT_LIMIT:
		owned_e.append({"key": epics[i]})
	var r_epic: String = Items.purchase_block_reason(epics[Items.EPIC_SLOT_LIMIT], owned_e, 3, {"consume": []})
	assert(m._slot_block_label(r_epic) == "EPİK DOLU", "epik havuzu dolu: %s" % r_epic)
	## sahip olunan epik tekrar -> "ZATEN SENDE" (eskiden SLOTLAR DOLU yazıyordu)
	var r_dup: String = Items.purchase_block_reason(epics[0], [{"key": epics[0]}], 3, {"consume": []})
	assert(m._slot_block_label(r_dup) == "ZATEN SENDE", "tekrar epik: %s" % r_dup)
	assert(m._slot_block_sub(r_dup) == "zaten sende var")
	## 6 kopya sınırı -> "KOPYA DOLU"
	var six: Array = []
	for i in Items.PART_MAX_COPIES:
		six.append({"key": parts[0]})
	var r_copy: String = Items.purchase_block_reason(parts[0], six, 99, {"consume": []})
	assert(m._slot_block_label(r_copy) == "KOPYA DOLU", "kopya sınırı: %s" % r_copy)
	## bilinmeyen / boş sebep -> eski yazı
	assert(m._slot_block_label("") == "SLOTLAR DOLU")
	assert(m._slot_block_sub("") == "yer yok")
	m.free()
