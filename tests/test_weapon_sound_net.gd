extends Node

## Silah sesleri (2026-10-20, madde 344): Kılıç/Yay/Arbalet'in çok sesli çalıcısı (random_sfx_player.gd) çaldığı çalıcıyı döner -> weapon.gd
## onu diğer oyunculara "weapon_sound" olarak yollar (eskiden bu üç silah arkadaşın ekranında sessizdi); Yıldırım vuruş tiki kısıldı.

const LightningBeam := preload("res://scripts/fx_lightning_beam.gd")


func test_multi_sound_weapons_return_what_they_played() -> void:
	for path in ["res://scenes/weapon_uzunkilic.tscn", "res://scenes/weapon_yay.tscn", "res://scenes/weapon_crossbow.tscn"]:
		var w: Node = (load(path) as PackedScene).instantiate()
		add_child(w)
		var snd: Node = w.get_node_or_null("AttackSound")
		assert(snd != null and snd.has_method("play_swing") and snd.has_method("set_rim_muffled"), "%s: çok sesli çalıcı" % path)
		var played: Variant = snd.play_swing()
		assert(played is AudioStreamPlayer2D and (played as AudioStreamPlayer2D).stream != null
			and (played as AudioStreamPlayer2D).stream.resource_path != "", "%s: çalınan çalıcı döner (ağa yayın için dosya yolu)" % path)
		w.free()


func test_lightning_tick_is_quieter() -> void:
	assert(LightningBeam.HIT_DB <= -1.9 and LightningBeam.CRIT_DB <= -2.2, "Yıldırım vuruş tiki kısıldı (madde 344)")
