extends Node

## Shaman totem yetenekleri - SIFIRDAN pixel tasarım doğrulaması (2026-09-21, kullanıcı isteği: "shamanın skil totemlerinin efektlerini,
## ikonlarını ve seslerini sıfırdan tasarla, pixel tarzda 48x48"): totem sprite'ları, cast/dikilme/sönme/rün efektleri, ikonlar, sesler.
## (Eski AŞAMA 2 hali: sprite sheet'li efektler - artık prosedürel 1 texel efektler, bkz. fx_shaman_cast.gd / fx_totem_puff.gd.)
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
## Ağ yayını yalnızca sahne YOLUNU taşıdığı için yetenek türü SAHNEYE gömülü `kind` olmalı (CLAUDE.md hata sınıfı).
const CAST_SCENES := {
	"res://scenes/fx_shaman_cast_shield.tscn": "shield",
	"res://scenes/fx_shaman_cast_attack.tscn": "attack",
	"res://scenes/fx_shaman_cast_area.tscn": "area",
}
const PUFF_SCENES := {
	"res://scenes/fx_totem_plant_dust.tscn": "plant",
	"res://scenes/fx_totem_collapse_dust.tscn": "collapse",
	"res://scenes/fx_totem_rune_flash.tscn": "rune",
}
const TOTEM_SCENES := [
	"res://scenes/totem_shield.tscn",
	"res://scenes/totem_attack.tscn",
	"res://scenes/totem_area.tscn",
]
const SKILL_ICONS := [
	"res://assets/skills/shaman_kalkan_totemi_icon.png",
	"res://assets/skills/shaman_saldiri_totemi_icon.png",
	"res://assets/skills/shaman_alan_totemi_icon.png",
]
const SFX_PATH := "res://scripts/shaman_sfx.gd"
const SMOOTH_DRAW_SCRIPTS := [
	"res://scripts/fx_shaman_cast.gd", "res://scripts/fx_totem_puff.gd", "res://scripts/fx_totem_fire_bolt.gd",
	"res://scripts/totem_shield_wave.gd", "res://scripts/totem_base.gd", "res://scripts/totem_area.gd",
]
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


func _assert_procedural_fx_scene(path: String, expected_kind: String) -> Node2D:
	var packed: PackedScene = load(path)
	assert(packed != null, "%s yüklenebilmeli" % path)
	var inst: Node = packed.instantiate()
	assert(inst is Node2D, "%s kökü Node2D olmalı" % path)
	assert(inst.get_script() != null, "%s script taşımalı" % path)
	assert(String(inst.get("kind")) == expected_kind,
		"%s türü sahneye gömülü olmalı (bulunan %s, beklenen %s)" % [path, inst.get("kind"), expected_kind])
	return inst as Node2D


func test_cast_scenes_carry_their_kind() -> void:
	for path: String in CAST_SCENES.keys():
		_assert_procedural_fx_scene(path, CAST_SCENES[path]).free()


func test_plant_collapse_and_rune_puffs_carry_their_kind() -> void:
	for path: String in PUFF_SCENES.keys():
		var fx: Node2D = _assert_procedural_fx_scene(path, PUFF_SCENES[path])
		assert(fx.has_method("setup_tint"), "%s setup_tint taşımalı (rün rengi için)" % path)
		fx.free()


## Totem sahneleri: 48x64 karelik 6 kareli döngü, NEAREST, TotemSprite adıyla (TotemBase bulur).
func test_totem_scenes_use_48px_pixel_sprites() -> void:
	for path: String in TOTEM_SCENES:
		var inst: Node = (load(path) as PackedScene).instantiate()
		var spr: AnimatedSprite2D = inst.get_node_or_null("TotemSprite")
		assert(spr != null, "%s 'TotemSprite' taşımalı" % path)
		assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s NEAREST olmalı" % path)
		var anim: StringName = spr.animation
		assert(spr.sprite_frames.get_frame_count(anim) == 6, "%s 6 kare olmalı" % path)
		assert(spr.sprite_frames.get_animation_loop(anim), "%s idle döngüsü olmalı" % path)
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(anim, 0)
		assert(tex.get_width() == 48 and tex.get_height() == 64, "%s kareleri 48x64 olmalı - v2 totem tasarımı, bkz. tools/shaman_totem_art.py (bulunan %s)" % [path, tex.get_size()])
		inst.free()


func test_skill_icons_are_48px() -> void:
	for path: String in SKILL_ICONS:
		var tex: Texture2D = load(path)
		assert(tex != null, "%s yüklenebilmeli" % path)
		assert(tex.get_width() == 48 and tex.get_height() == 48, "%s 48x48 olmalı (bulunan %s)" % [path, tex.get_size()])


func test_shaman_sounds_exist() -> void:
	var sfx: Object = load(SFX_PATH)
	assert(sfx != null, "shaman_sfx.gd yüklenebilmeli")
	var paths: Array = sfx.PLANT.values() + [sfx.EXPIRE, sfx.SHIELD_PULSE, sfx.BOLT_SHOT, sfx.BOLT_HIT, sfx.AREA_PULSE]
	for path: String in paths:
		assert(load(path) is AudioStream, "%s ses dosyası yüklenebilmeli" % path)


## Sıfırdan pixel tasarım: düzgün daire/yay/çizgi çizimleri (yumuşak vektör) Shaman efekt kodunda KALMAMALI.
func test_shaman_fx_code_has_no_smooth_vector_drawing() -> void:
	for path: String in SMOOTH_DRAW_SCRIPTS:
		var src: String = _strip_comments(_read(path))
		assert(not src.is_empty(), "%s okunabilmeli" % path)
		for banned in ["draw_circle(", "draw_arc(", "draw_polyline(", "draw_line(", "draw_colored_polygon(", "CPUParticles2D"]:
			assert(not src.contains(banned), "%s içinde yumuşak çizim (%s) OLMAMALI - pixel tarzı" % [path, banned])


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
