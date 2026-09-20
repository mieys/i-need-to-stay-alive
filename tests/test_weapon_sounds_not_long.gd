extends Node

## Kullanıcı bildirimi: "arkada sürekli çalan, benim eklemediğim bir kalkan sesi var ... savaşta değilken,
## evin içindeyken ya da seyyar tüccarın kalkanındayken duyulmuyor ... yay kullanıyordum".
## Kök neden: weapon_yay.tscn'in DrawSound'u, kullanıcının sildiği yay_draw.mp3'ün yerine konmuş 8,95 sn'lik
## "Channel Power Up Loop.wav" idi; her atışta baştan başlatılıp savaş boyunca sürekli bir vızıltı gibi çalıyordu.
## Silah sesleri KISA, tek atımlık olmalı: uzun ya da "Loop" adlı bir dosya silah sahnesine konursa bu test yakalar.

const MAX_WEAPON_SOUND_SECONDS := 4.5 ## en uzun mevcut silah sesi (uzunkilic swing) ~4 sn; 9 sn'lik döngü bunun çok üstünde


func _weapon_scene_paths() -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at("res://scenes"):
		if f.begins_with("weapon_") and f.ends_with(".tscn"):
			out.append("res://scenes/" + f)
	return out


func _audio_paths_in(scene_path: String) -> Array[String]:
	var text: String = FileAccess.get_file_as_string(scene_path)
	var rx := RegEx.new()
	rx.compile("path=\"(res://[^\"]+\\.(?:mp3|wav|ogg))\"")
	var out: Array[String] = []
	for m: RegExMatch in rx.search_all(text):
		out.append(m.get_string(1))
	return out


func test_weapon_scenes_use_short_non_loop_sounds() -> void:
	var scenes: Array[String] = _weapon_scene_paths()
	assert(scenes.size() >= 10, "weapon_*.tscn sahneleri bulunamadı (%d)" % scenes.size())
	var checked: int = 0
	for scene_path: String in scenes:
		for audio_path: String in _audio_paths_in(scene_path):
			assert(not audio_path.to_lower().contains("loop"),
				"%s döngü (Loop) bir sesi silah sesi olarak kullanıyor: %s" % [scene_path, audio_path])
			var stream: AudioStream = load(audio_path) as AudioStream
			assert(stream != null, "%s ses dosyası yüklenemedi: %s" % [scene_path, audio_path])
			assert(stream.get_length() <= MAX_WEAPON_SOUND_SECONDS,
				"%s çok uzun bir ses kullanıyor (%.1f sn): %s - her atışta yeniden başlayıp sürekli çalıyormuş gibi duyulur" % [scene_path, stream.get_length(), audio_path])
			checked += 1
	assert(checked >= 5, "Hiç ses denetlenmedi (%d) - test yanlış çalışıyor olabilir" % checked)


## Yayın çekme sesi kaldırıldı (kullanıcı yay_draw.mp3'ü bilerek silmişti): sahnede DrawSound düğümü olmamalı,
## silah da (weapon.gd `if draw_sound` korumaları) sessizce çalışmalı.
func test_bow_has_no_draw_sound_stand_in() -> void:
	var source: String = FileAccess.get_file_as_string("res://scenes/weapon_yay.tscn")
	assert(not source.contains("DrawSound"), "weapon_yay.tscn'de DrawSound düğümü kalmamalı")
	assert(not source.contains("Channel Power Up"), "weapon_yay.tscn ses paketindeki güç yükleme döngüsünü kullanmamalı")
	## Atış sesi (yay_fire) durmalı - sadece çekme sesi gitti.
	assert(source.contains("yay_fire_1.mp3") and source.contains("yay_fire_2.mp3"), "Yayın atış sesleri korunmalı")
	var scene: PackedScene = load("res://scenes/weapon_yay.tscn")
	assert(scene != null, "weapon_yay.tscn yüklenebilmeli")
	var w: Node = scene.instantiate()
	assert(w.get_node_or_null("DrawSound") == null, "Örneklenen yay silahında DrawSound olmamalı")
	assert(w.get_node_or_null("AttackSound") != null, "Yayın AttackSound'u durmalı")
	w.free()
