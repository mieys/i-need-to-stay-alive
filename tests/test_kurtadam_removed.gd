extends Node

## Kullanıcı isteği: "Kurt adam adlı karakteri komple oyundan silmeni istiyorum".
## Karakter tanımı, yetenek kodu, FX sahneleri ve görsel dosyaları kaldırıldı; bu test hiçbir yerde
## geride kırık bir referans ya da sahipsiz yetenek kaydı kalmadığını doğrular.

const PlayerScript: GDScript = preload("res://scripts/player.gd")


func test_character_is_gone_from_the_roster() -> void:
	for id in Characters.DEFS:
		assert(str(Characters.DEFS[id].get("name", "")) != "Kurt Adam", "Kurt Adam listede kalmamalı (id %s)" % str(id))
	assert(not Characters.DEFS.has(6), "Eski id 6 (Kurt Adam) boş kalmalı - diğer karakterlerin id'leri KAYDIRILMAZ")
	## Eski kayıtlı/ağdan gelen id 6 güvenli şekilde ilk karaktere düşer (get_def yedeği).
	assert(Characters.get_def(6) == Characters.DEFS[1], "Bilinmeyen id ilk karaktere düşmeli")


func test_other_characters_keep_their_ids() -> void:
	var expected: Dictionary = {1: "Talon", 2: "Oakley", 3: "Matthew", 4: "Büyücü Kız", 5: "Assasin Çocuk", 7: "Şovalye Adam", 8: "Elara", 9: "Korsan", 10: "Melek", 11: "Necromancer", 12: "Shaman"}
	for id in expected:
		assert(str(Characters.DEFS[id].get("name", "")) == expected[id], "id %s hâlâ %s olmalı, bulunan: %s" % [str(id), expected[id], str(Characters.DEFS[id].get("name", ""))])


func test_no_character_points_to_a_missing_file() -> void:
	for id in Characters.DEFS:
		var def: Dictionary = Characters.DEFS[id]
		for key in ["skill_icon", "skill2_icon", "skill3_icon", "passive_icon", "frames", "portrait"]:
			if def.has(key):
				assert(ResourceLoader.exists(str(def[key])), "%s (%s): dosya yok -> %s" % [str(def.get("name", id)), key, str(def[key])])


func test_ability_ids_used_only_by_the_removed_character_are_gone() -> void:
	assert(not PlayerScript.SKILL_TIMING.has(14), "Kudurmuş Saldırı (skill 14) kaydı silinmeli")
	assert(not PlayerScript.SKILL2_TIMING.has(13), "Vahşi Kesik (skill2 13) kaydı silinmeli")
	for id in Characters.DEFS:
		var def: Dictionary = Characters.DEFS[id]
		assert(int(def.get("skill", 0)) != 14 and int(def.get("skill2", 0)) != 13, "%s silinen yetenek id'lerini kullanıyor" % str(def.get("name", id)))


func test_removed_scenes_and_assets_are_gone() -> void:
	for path in ["res://scenes/fx_kurtadam_rage.tscn", "res://scenes/fx_kurtadam_slash.tscn", "res://scripts/fx_kurtadam_rage.gd",
			"res://assets/characters/kurtadam_frames.tres", "res://assets/characters/kurtadam_portrait.png",
			"res://assets/skills/kurtadam_vahsi_kesik_icon.png", "res://assets/weapons/kurtadam/slash_frames.tres"]:
		assert(not ResourceLoader.exists(path), "Silinmiş olmalı: %s" % path)
