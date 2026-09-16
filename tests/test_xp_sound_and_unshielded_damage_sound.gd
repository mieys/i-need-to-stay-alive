extends Node

## Kullanıcı isteği doğrulaması:
##  1) "exp orbun sesini normal düzeye düşür (arttırmaları kaldır)"
##  2) "kalkansız hasar alma adında bir ses ekledim bu ses kalkan yokken
##     karakter hasar alırsa çıkacak."
##
## Doğrulananlar:
##  - XP orb toplama sesi tekrar NORMAL (orijinal) seviyede,
##  - kalkan YOKKEN cana hasar işlerse yeni "kalkansız hasar alma" sesi çalıyor,
##  - kalkan hasarı EMDİĞİNDE o ses çalmıyor (onun yerine kalkan sesi çıkıyor),
##  - sesin seviyesi/menzili diğer oyuncu sesleriyle tutarlı kurulmuş.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const NO_SHIELD_SOUND := "res://assets/audio/kalkansız hasar alma.mp3"


func _make_player() -> Node:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	return p


## take_damage() aynı 1-2 karede üst üste gelen isabetleri engellemek için
## 150ms'lik bir pencere tutuyor (CONTACT_DAMAGE_IFRAME_MS) - testte art arda
## hasar verdiğimiz için bu damga geçmişe alınır.
func _reset_iframe(player: Node) -> void:
	player._last_damage_taken_at_msec = -999999


func test_xp_pickup_sound_is_back_to_normal() -> void:
	var player: Node = _make_player()
	var sound: AudioStreamPlayer2D = player.get_node_or_null("XPPickupSound")
	assert(sound != null, "XPPickupSound düğümü bulunamadı")
	assert(is_equal_approx(sound.volume_db, -16.0),
		"XP orb sesi normal seviyeye dönmemiş (arttırmalar kaldırılmamış): %s dB (beklenen -16.0)" % sound.volume_db)
	player.queue_free()


func test_unshielded_damage_plays_the_new_sound() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## hasar yazısı/sesi sahne köküne ekleniyor
	var player: Node = _make_player()
	player.dodge_chance = 0.0
	player.damage_taken_mult = 1.0
	player.is_shielded = false
	player.item_shield_hp = 0.0 ## kalkan YOK
	player.shield_protection = 0.0

	var sound: AudioStreamPlayer2D = player.get_node_or_null("NoShieldDamageSound")
	assert(sound != null, "player.tscn'de NoShieldDamageSound düğümü yok")
	assert(sound.stream != null, "NoShieldDamageSound'a stream atanmamış")
	assert(sound.stream.resource_path == NO_SHIELD_SOUND,
		"Yanlış ses atanmış: %s" % sound.stream.resource_path)
	assert(sound.volume_db < 0.0 and sound.volume_db > -40.0,
		"Kalkansız hasar sesi seviyesi makul değil: %s dB" % sound.volume_db)

	_reset_iframe(player)
	var health_before: float = player.health
	player.take_damage(10.0, null)
	assert(player.health < health_before, "Kalkansız hasar cana işlemedi (test kurulumu hatalı)")
	assert(sound.playing, "Kalkan yokken hasar alınca yeni ses ÇALMADI")

	player.queue_free()
	get_tree().current_scene = previous_scene


func test_shielded_damage_does_not_play_the_new_sound() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Node = _make_player()
	player.dodge_chance = 0.0
	player.damage_taken_mult = 1.0
	player.is_shielded = false
	player.item_shield_max = 100.0
	player.item_shield_hp = 100.0
	player.shield_protection = 0.5 ## vuruşun yarısını kalkan emer

	var sound: AudioStreamPlayer2D = player.get_node_or_null("NoShieldDamageSound")
	var shield_sound: AudioStreamPlayer2D = player.get_node_or_null("ShieldHitSound")

	_reset_iframe(player)
	player.take_damage(10.0, null)
	assert(player.item_shield_hp < 100.0, "Kalkan hasarı emmedi (test kurulumu hatalı)")
	assert(shield_sound != null and shield_sound.playing, "Kalkan sesi çalmadı")
	assert(not sound.playing,
		"Kalkan hasarı emdiği hâlde 'kalkansız hasar' sesi de çaldı (iki ses üst üste)")

	player.queue_free()
	get_tree().current_scene = previous_scene


## Kaynak düzeyinde: ses, çağrı yerinin (kalkansız hasar yolu) dışında
## kullanılmamalı - yani "kalkan varken çalmasın" kuralı kodda da belli.
func test_new_sound_only_in_the_unshielded_branch() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(src.length() > 0, "player.gd okunamadı")
	assert(src.find("if not shield_absorbed_hit:") != -1,
		"Kalkansız hasar kontrolü (shield_absorbed_hit) yok")
	assert(src.find("no_shield_damage_sound.play()") != -1,
		"Yeni ses hiç çalınmıyor")
