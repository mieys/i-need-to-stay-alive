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


## Madde 406: Bıçak/Pençe/Mızrak kombo zinciri (melee_swing_sound.gd) adımlarını döner -> weapon.gd tek "weapon_sound" mesajında "chain"
## olarak yollar (eskiden bu üç silah arkadaşın ekranında sessizdi). İlk adım hemen, sonrakiler artan gecikmeyle; her adımda dosya yolu.
func test_melee_chain_returns_steps_for_network() -> void:
	## Sahne tek başına açılınca AttackSound kurulmaz (configure_melee'yi sahibi çağırır) -> çalıcı doğrudan kurulur, aynı script.
	var snd := Node2D.new()
	snd.set_script(load("res://scripts/melee_swing_sound.gd"))
	add_child(snd)
	var p := "res://assets/audio/claw_slash.mp3"
	snd.setup([p, p, p], -12.0)
	var steps: Variant = snd.play_swing()
	assert(steps is Array and (steps as Array).size() == 3, "zincir adımları döner (%s)" % str(steps))
	var last: float = -1.0
	for st: Variant in steps:
		assert(st is Dictionary and str(st.get("sound_path", "")) == p, "adımda dosya yolu")
		assert(float(st.get("volume_db", 0.0)) == -12.0, "adımda ses seviyesi")
		var d: float = float(st.get("delay", -1.0))
		assert(d > last, "gecikmeler artan sırada")
		last = d
	assert(float((steps as Array)[0].get("delay", 1.0)) == 0.0, "ilk ses hemen")
	snd.free()


## Alıcı tarafı: zincir mesajı kuklaya her adım için bir çalıcı ekler (gecikmesi 0 olan hemen).
func test_remote_chain_plays_on_puppet() -> void:
	var rp := Node2D.new()
	add_child(rp)
	NetworkManager._play_remote_weapon_sound(rp, "res://assets/audio/claw_slash.mp3", 1.0, -12.0, false, Vector2.ZERO)
	var n: int = 0
	for c in rp.get_children():
		if c is AudioStreamPlayer2D:
			n += 1
	assert(n == 1, "uzak ses çalıcısı kuklaya eklendi (%d)" % n)
	rp.free()
