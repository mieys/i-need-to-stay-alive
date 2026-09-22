extends Node

## Kullanıcı isteği doğrulaması: "Elara, büyücü kız, vampir çocuk, talon, melek ve
## korsan adlı karakterlerin boyutunu %25 arttır ve gölge yoksa altlarına gölge ekle."
##
## SONRAKİ İSTEK: "Vampir çocuğa yaptığın büyüklük değişimini geri al, diğerlerine
## dokunma" - bu yüzden Vampir aşağıdaki "büyütülmüş" listede DEĞİL; kendi geri
## alma testiyle (test_vampir_size_change_was_reverted) eski değerlerinde sabit.
##
## Doğrulananlar:
##  1) 6 karakterin de DEFS ölçeği tam %25 büyütülmüş (yeni baştan yazılmasın, çarpım olsun),
##  2) 6 karakterin de piksel elips ayak gölgesi (ground_shadow.gd) tanımlı,
##  3) gölge yarıçapı da karakterle orantılı büyümüş (x1.25),
##  4) ölçek büyürken ayaklar AYNI zemin çizgisinde kalıyor (offset.y telafisi) -
##     yani karakter büyüyünce yere gömülmüyor/ havada durmuyor,
##  5) bu istekte yer almayan karakterler etkilenmemiş.

## id -> büyütmeden ÖNCEKİ ölçek (hepsi x1.25 olacak).
const BEFORE := {
	1: 1.78947, ## Talon
	4: 1.78947, ## Büyücü Kız
	8: 1.78947, ## Elara
	9: 1.78947, ## Korsan
	10: 1.78947, ## Melek
}
const GROWTH := 1.25

## Gölge yarıçapının büyütmeden önceki hâli (x1.25 ile büyümeli).
const SHADOW_BEFORE := {
	1: 14.0,
	4: 15.0,
	8: 14.0,
	9: 17.0,
	10: 16.0,
}

## Karakter kareleri 48x48 sanat pikseli ve ayak hizası 41. satır (bkz.
## characters.gd Vampir notu: "(41 - 24 + offset.y) x ölçek"); görsel ölçek
## ayrıca EntityScale.SIZE (0.95) ile çarpılıyor (bkz. player.gd _load_character_frames).
const FRAME_H := 48.0
const FEET_ROW := 41.0


## Ayakların orijinden uzaklığı (px) - player.gd/remote_player.gd'nin
## anim.scale + anim.offset uygulamasının birebir matematiksel karşılığı.
func _feet_px(def: Dictionary) -> float:
	return (FEET_ROW - FRAME_H * 0.5 + float(def["offset"].y)) * float(def["scale"].x) * EntityScale.SIZE


func test_each_character_is_exactly_25_percent_bigger() -> void:
	for id in BEFORE.keys():
		var def: Dictionary = Characters.get_def(int(id))
		var expected: float = float(BEFORE[id]) * GROWTH
		assert(absf(float(def["scale"].x) - expected) < 0.001,
			"%s ölçeği %%25 büyümemiş: %s (beklenen %s)" % [str(def["name"]), def["scale"].x, expected])
		assert(absf(float(def["scale"].y) - float(def["scale"].x)) < 0.001,
			"%s ölçeği kare olmalı (x = y): %s" % [str(def["name"]), def["scale"]])


func test_each_character_has_a_shadow() -> void:
	for id in BEFORE.keys():
		var def: Dictionary = Characters.get_def(int(id))
		assert(def.has("ground_shadow"), "%s: ayak gölgesi (ground_shadow) tanımlı değil" % str(def["name"]))
		assert(def.has("ground_shadow_y"), "%s: ground_shadow_y tanımlı değil" % str(def["name"]))
		var radius: Vector2 = def["ground_shadow"]
		assert(radius.x > 0.0 and radius.y > 0.0,
			"%s: gölge yarıçapı geçersiz: %s" % [str(def["name"]), radius])


func test_shadow_radius_grew_with_the_character() -> void:
	for id in SHADOW_BEFORE.keys():
		var def: Dictionary = Characters.get_def(int(id))
		var expected: float = float(SHADOW_BEFORE[id]) * GROWTH
		assert(absf(float(def["ground_shadow"].x) - expected) < 0.01,
			"%s gölge yarıçapı orantılı büyümemiş: %s (beklenen %s)" % [str(def["name"]), def["ground_shadow"].x, expected])


## Ölçek büyürken sprite ortadan büyüdüğü için ayaklar aşağı kayar; offset.y
## negatife çekilerek ESKİ zemin çizgisi korunmalı (yoksa karakter yere gömülür
## ya da gölgesi ayaklarının altından kayar).
func test_feet_stay_on_the_same_ground_line() -> void:
	for id in BEFORE.keys():
		var def: Dictionary = Characters.get_def(int(id))
		var feet: float = _feet_px(def)
		var shadow_y: float = float(def["ground_shadow_y"])
		assert(absf(feet - shadow_y) < 2.0,
			"%s: ayaklar %s px'de ama gölge %s px'de - offset.y telafisi hatalı" % [str(def["name"]), feet, shadow_y])


## Büyütmeden sonra da ayaklar eskisi gibi ~32-34 px'de olmalı (yani sadece
## yukarı doğru büyüme; aşağı kayma YOK).
func test_growth_did_not_push_the_character_downwards() -> void:
	var expected_feet := {1: 32.3, 4: 32.3, 8: 32.3, 9: 32.3, 10: 32.3}
	for id in expected_feet.keys():
		var def: Dictionary = Characters.get_def(int(id))
		assert(absf(_feet_px(def) - float(expected_feet[id])) < 0.5,
			"%s ayak çizgisi kaymış: %s px (beklenen %s)" % [str(def["name"]), _feet_px(def), expected_feet[id]])


func test_other_characters_are_untouched() -> void:
	for id in [2, 3, 5, 7, 11, 12]:
		var def: Dictionary = Characters.get_def(int(id))
		assert(not def.has("scale"),
			"%s bu istekte yoktu, ölçek eklenmemeli" % str(def["name"]))


## DEFS değerleri TEK BAŞINA yeterli değil - player.gd bunları sprite'a
## (anim.scale/anim.offset) ve gölge düğümüne (ground_shadow.gd) gerçekten
## uyguluyor mu? Bu test gerçek bir oyuncu sahnesi kurup bakıyor.
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func test_player_really_applies_the_new_size_offset_and_shadow() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	for id in BEFORE.keys():
		var def: Dictionary = Characters.get_def(int(id))
		GameManager.selected_char_id = int(id)
		GameManager.selected_character = int(def.get("skill", 1))

		var player: Node = PlayerScene.instantiate()
		add_child(player)
		var name: String = str(def["name"])

		assert(player.anim.scale.is_equal_approx(def["scale"] * EntityScale.SIZE),
			"%s: sprite ölçeği uygulanmamış: %s" % [name, player.anim.scale])
		assert(player.anim.offset == def["offset"],
			"%s: sprite offset'i uygulanmamış: %s" % [name, player.anim.offset])

		var shadow_node: Node2D = player.get_node_or_null("Shadow")
		assert(shadow_node != null, "%s: Shadow düğümü yok" % name)
		assert(shadow_node.visible, "%s: gölge görünür değil" % name)
		assert(str(shadow_node.get_script().resource_path).ends_with("ground_shadow.gd"),
			"%s: gölge piksel-elips script'ine geçmemiş" % name)
		assert(is_equal_approx(shadow_node.position.y, float(def["ground_shadow_y"])),
			"%s: gölge ayak çizgisine oturmamış: %s" % [name, shadow_node.position.y])
		var applied_radius: Vector2 = shadow_node.get("radius")
		assert(applied_radius.distance_to(def["ground_shadow"]) < 0.01,
			"%s: gölge yarıçapı DEFS ile aynı değil: %s" % [name, applied_radius])

		player.queue_free()
	get_tree().current_scene = previous_scene


## Kullanıcı isteği: "Vampir çocuğa yaptığın büyüklük değişimini geri al,
## diğerlerine dokunma" - Vampir bu büyütmeden ÖNCEKİ hâlinde kalmalı
## (gölgesi yine de tanımlı kalır).
func test_vampir_size_change_was_reverted() -> void:
	var def: Dictionary = Characters.get_def(13)
	assert(str(def["name"]) == "Vampir Çocuk", "id 13 Vampir Çocuk olmalı, bulunan: %s" % str(def["name"]))
	assert(absf(float(def["scale"].x) - 2.09797) < 0.001,
		"Vampir ölçeği eski hâline dönmemiş: %s (beklenen 2.09797)" % def["scale"].x)
	assert(def["offset"] == Vector2(0, 0),
		"Vampir offset'i eski hâline dönmemiş: %s (beklenen (0, 0))" % str(def["offset"]))
	assert(absf(float(def["ground_shadow"].x) - 19.0) < 0.01
		and absf(float(def["ground_shadow"].y) - 7.0) < 0.01,
		"Vampir gölge yarıçapı eski hâline dönmemiş: %s (beklenen (19, 7))" % str(def["ground_shadow"]))
	assert(is_equal_approx(float(def["ground_shadow_y"]), 33.4),
		"Vampir gölge çizgisi değişmemeli: %s" % def["ground_shadow_y"])
	assert(def.has("ground_shadow"), "Vampir'in ayak gölgesi hâlâ tanımlı olmalı")
