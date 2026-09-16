extends Node

## Shaman yetenek efektleri - AŞAMA 2 doğrulaması: TOTEM DİKİLME / SÖNME /
## CAST (yetenek atma) efektlerinin pixel-art dönüşümü.
##
## Kullanıcı istekleri:
##   "Shaman adlı karakterin skill efektlerini skil uygun şekilde tasarla"
##   "pixel sanatında yapıyorsun dimi efektleri, oyunum pixel çünkü?"
##
## Dönüştürülenler: eskiden tüm totem 0.25 ölçeğinden 1.0'a YUMUŞAK bir
## tween'le (TRANS_BACK) büyütülüyordu + toprak tozu ondalıklı ölçekli
## CPUParticles2D idi. Artık: piksel adımlı yükselme + piksel-art toz
## sprite'ları + yetenek renginde rün parlaması.

const PLANT_SCENE := "res://scenes/fx_totem_plant_dust.tscn"
const COLLAPSE_SCENE := "res://scenes/fx_totem_collapse_dust.tscn"
const RUNE_SCENE := "res://scenes/fx_totem_rune_flash.tscn"
const CAST_SCENES := {
	"res://scenes/fx_shaman_cast_shield.tscn": Color(0.35, 0.65, 1),
	"res://scenes/fx_shaman_cast_attack.tscn": Color(1, 0.55, 0.25),
	"res://scenes/fx_shaman_cast_area.tscn": Color(0.65, 0.35, 0.85),
}
const TOTEM_BASE_PATH := "res://scripts/totem_base.gd"
const PLAYER_PATH := "res://scripts/player.gd"


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Yorumları soyar - "şu kod YOK olmalı" tipi kontroller kodun kendisini
## görmeli, o kodu AÇIKLAYAN yorumları değil (yoksa bir düzeltmeyi anlatan
## yorum, düzeltmenin kendisiyle karıştırılır).
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var idx: int = line.find("#")
		out.append(line.substr(0, idx) if idx != -1 else line)
	return "\n".join(out)


func _assert_pixel_art_fx_scene(path: String) -> AnimatedSprite2D:
	var packed: PackedScene = load(path)
	assert(packed != null, "%s yüklenebilmeli" % path)
	var inst: Node = packed.instantiate()
	assert(inst is AnimatedSprite2D, "%s kökü AnimatedSprite2D olmalı" % path)
	var spr: AnimatedSprite2D = inst
	assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s pixel-art olmalı (texture_filter NEAREST), bulunan: %s" % [path, spr.texture_filter])
	assert(spr.sprite_frames != null, "%s SpriteFrames taşımalı" % path)
	assert(spr.sprite_frames.get_animation_names().size() == 1,
		"%s tek animasyon taşımalı" % path)
	var anim: StringName = spr.sprite_frames.get_animation_names()[0]
	assert(spr.sprite_frames.get_frame_count(anim) == 6,
		"%s 6 kare olmalı" % path)
	## Bunlar TEK SEFERLİK patlamalar - döngülü olurlarsa animation_finished
	## hiç gelmez ve efekt sahnede sonsuza kadar asılı kalırdı.
	assert(not spr.sprite_frames.get_animation_loop(anim),
		"%s DÖNGÜSÜZ olmalı (tek seferlik patlama)" % path)
	return spr


func test_totem_plant_and_collapse_dust_are_pixel_art() -> void:
	var plant: AnimatedSprite2D = _assert_pixel_art_fx_scene(PLANT_SCENE)
	plant.free()
	var collapse: AnimatedSprite2D = _assert_pixel_art_fx_scene(COLLAPSE_SCENE)
	collapse.free()


func test_rune_flash_is_pixel_art() -> void:
	var rune: AnimatedSprite2D = _assert_pixel_art_fx_scene(RUNE_SCENE)
	rune.free()


## Cast parlamaları: her yeteneğin rengi SAHNEYE GÖMÜLÜ olmalı - ağ yayını
## yalnızca sahne yolunu taşıdığı için renk kodda verilirse diğer
## oyuncularda renksiz görünürdü (projenin bilinen hata sınıfı).
func test_cast_flashes_are_pixel_art_with_baked_colours() -> void:
	for path: String in CAST_SCENES.keys():
		var spr: AnimatedSprite2D = _assert_pixel_art_fx_scene(path)
		var expected: Color = CAST_SCENES[path]
		assert(spr.modulate.r > 0.0 or spr.modulate.g > 0.0 or spr.modulate.b > 0.0,
			"%s renk tonu taşımalı" % path)
		assert(absf(spr.modulate.r - expected.r) < 0.02
			and absf(spr.modulate.g - expected.g) < 0.02
			and absf(spr.modulate.b - expected.b) < 0.02,
			"%s beklenen yetenek rengini taşımalı (bulunan %s, beklenen %s)" % [path, spr.modulate, expected])
		spr.free()


## DÖNÜŞÜM: yumuşak ölçek tween'i ve ondalıklı-ölçekli partikül GİTMELİ;
## yerine piksel adımlı yükselme + sprite tabanlı toz gelmeli.
func test_totem_base_no_longer_uses_smooth_scaling() -> void:
	var src: String = _strip_comments(_read(TOTEM_BASE_PATH))
	assert(not src.is_empty(), "totem_base.gd okunabilmeli")
	assert(not src.contains("TRANS_BACK"),
		"yumuşak ölçek tween'i (TRANS_BACK) kaldırılmış olmalı - piksel sprite'ı yamuk gösteriyordu")
	assert(src.contains("roundf"),
		"yükselme tam piksele sabitlenmeli (roundf) - pixel-art netliği için")
	assert(src.contains("func _spawn_dust_child("), "dikilme tozu (çocuk) fonksiyonu olmalı")
	assert(src.contains("func _spawn_dust_sibling("), "sönme tozu (kardeş) fonksiyonu olmalı")
	assert(src.contains("func _spawn_rune_flash("), "yetenek renginde rün parlaması olmalı")
	assert(src.contains("preload(\"res://scenes/fx_totem_plant_dust.tscn\")"), "dikilme tozu sahnesi bağlı olmalı")
	assert(src.contains("preload(\"res://scenes/fx_totem_collapse_dust.tscn\")"), "sönme tozu sahnesi bağlı olmalı")
	assert(src.contains("preload(\"res://scenes/fx_totem_rune_flash.tscn\")"), "rün parlaması sahnesi bağlı olmalı")


## GÖRÜNMEZLİK REGRESYONU KORUMASI: bu projede z_index = -1 daha önce
## totemi/partikülü zemin katmanlarının ALTINA atıp tamamen görünmez
## yapmıştı (bkz. totem_base.gd dosya başı notu). Bir daha girmemeli.
func test_totem_base_has_no_negative_z_index() -> void:
	var src: String = _strip_comments(_read(TOTEM_BASE_PATH))
	assert(not src.contains("z_index = -1"),
		"totem_base.gd'de z_index = -1 OLMAMALI - zemin katmanlarının altına düşürüp görünmez yapıyor")


## Sönme efekti totemle birlikte YOK OLMAMALI: totem queue_free edilirken
## efekti çocuk olarak bırakmak onu da siliyordu (pratikte hiç görünmüyordu).
func test_expire_spawns_dust_as_sibling() -> void:
	var src: String = _strip_comments(_read(TOTEM_BASE_PATH))
	var idx: int = src.find("func _on_expire()")
	assert(idx != -1, "_on_expire bulunmalı")
	var end: int = src.find("func _process(", idx)
	if end == -1:
		end = src.length()
	var body: String = src.substr(idx, end - idx)
	assert(body.contains("_spawn_dust_sibling(CollapseDustScene)"),
		"sönme tozu KARDEŞ olarak eklenmeli (çocuk olursa totemle birlikte silinir)")


## Oyuncu tarafı: cast efekti kanonik ağ-yardımcısıyla oynatılmalı ki
## diğer oyuncularda da AYNI efekt görünsün.
func test_player_uses_broadcast_helper_for_shaman_cast() -> void:
	var src: String = _read(PLAYER_PATH)
	assert(src.contains("ShamanCastShieldScene := preload(\"res://scenes/fx_shaman_cast_shield.tscn\")"), "kalkan cast sahnesi bağlı olmalı")
	assert(src.contains("ShamanCastAttackScene := preload(\"res://scenes/fx_shaman_cast_attack.tscn\")"), "saldırı cast sahnesi bağlı olmalı")
	assert(src.contains("ShamanCastAreaScene := preload(\"res://scenes/fx_shaman_cast_area.tscn\")"), "alan cast sahnesi bağlı olmalı")
	assert(src.contains("_play_and_broadcast_skill_fx(ShamanCastShieldScene)"), "kalkan cast ağ-yardımcısıyla oynatılmalı")
	assert(src.contains("_play_and_broadcast_skill_fx(ShamanCastAttackScene)"), "saldırı cast ağ-yardımcısıyla oynatılmalı")
	assert(src.contains("_play_and_broadcast_skill_fx(ShamanCastAreaScene)"), "alan cast ağ-yardımcısıyla oynatılmalı")
	## Eski jenerik patlama artık Shaman yeteneklerinde KULLANILMAMALI.
	assert(not src.contains("_spawn_burst(Color(0.35, 0.65, 1.0))"), "eski jenerik kalkan patlaması kaldırılmalı")
	assert(not src.contains("_spawn_burst(Color(1.0, 0.55, 0.25))"), "eski jenerik saldırı patlaması kaldırılmalı")
	assert(not src.contains("_spawn_burst(Color(0.65, 0.35, 0.85))"), "eski jenerik alan patlaması kaldırılmalı")
