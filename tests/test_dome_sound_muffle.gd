extends Node

## Kubbe boğuk sesi (dome_sound_muffle.gd + dome_sound_router.gd): yerel oyuncu kubbedeyken kubbenin DIŞINDA çalan her
## AudioStreamPlayer2D (özellikle taç silahları, dome_weapon_ring.gd) boğuk + yankılı bus'a gider, içindekiler normal kalır.
## 2026-10-17: eski Area2D audio_bus_override yöntemi Godot 4.7.2'de sesi hiç yönlendirmiyordu (madde 218) - bus'ı konuma göre
## değiştiren yönlendiriciye geçildi.

const MuffleScript: GDScript = preload("res://scripts/dome_sound_muffle.gd")
const RingScript: GDScript = preload("res://scripts/dome_weapon_ring.gd")
const DomeScript: GDScript = preload("res://scripts/paladin_dome.gd")
const AudioBusesScript: GDScript = preload("res://scripts/audio_buses.gd")

class FakeLocal extends Node2D:
	var is_dead: bool = false


func _sound_at(parent: Node, pos: Vector2) -> AudioStreamPlayer2D:
	var s := AudioStreamPlayer2D.new()
	parent.add_child(s)
	s.global_position = pos
	return s


func test_outside_sounds_are_muffled_inside_ones_are_not() -> void:
	var center := Vector2(500.0, 400.0)
	var p := FakeLocal.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = center
	var before := _sound_at(self, center + Vector2(0.0, 300.0)) ## kubbe açılmadan önce ağaçta olan dış ses: tarama yakalar
	var m: Node2D = MuffleScript.new()
	m.set("radius", 126.0)
	m.set("elliptic", true)
	add_child(m)
	m.global_position = center
	for i in range(3):
		await get_tree().physics_frame
	var muffle: StringName = AudioBusesScript.MUFFLE_BUS
	assert(AudioBusesScript.in_dome, "yerel oyuncu kubbede")
	assert(before.bus == muffle, "önceden var olan dış ses boğuk bus'ta: %s" % before.bus)
	var ring: Array = []
	for i in range(12):
		ring.append(_sound_at(self, RingScript.rim_point(center, 126.0, i, 12)))
	var inner: Array = []
	for i in range(12):
		inner.append(_sound_at(self, center + DomeScript.edge_offset(126.0, TAU * float(i) / 12.0) * 0.9))
	var own := _sound_at(p, center) ## oyuncunun kendi sesi (çocuğu): içeride
	var rim_weapon := _sound_at(self, RingScript.rim_point(center, 126.0, 0, 12))
	AudioBusesScript.route_rim_sound(rim_weapon, true)
	for i in range(3):
		await get_tree().physics_frame
	for s: AudioStreamPlayer2D in ring:
		assert(s.bus == muffle, "taç noktası boğuk: %s" % str(s.global_position))
	for s: AudioStreamPlayer2D in inner:
		assert(s.bus == &"Master", "kubbe içi normal: %s" % str(s.global_position))
	assert(own.bus == &"Master", "oyuncunun kendi sesi normal")
	assert(rim_weapon.bus == AudioBusesScript.RIM_WEAPON_BUS, "taç silahı kendi boğuk+yankılı yolunda (yönlendirici dokunmaz)")
	var idx: int = AudioServer.get_bus_index(muffle)
	assert(AudioServer.get_bus_effect_count(idx) >= 2 and AudioServer.get_bus_effect(idx, 1) is AudioEffectReverb, "boğuk yolda yankı var")
	var ridx: int = AudioServer.get_bus_index(AudioBusesScript.RIM_WEAPON_BUS)
	assert(AudioServer.get_bus_effect(ridx, 1) is AudioEffectReverb, "taç yolunda yankı var")
	assert(AudioServer.get_bus_volume_db(ridx) >= 0.0, "taç silahı KISILMAZ (kullanıcı: kısıktan ziyade boğuk ve yankılı)")
	## Oyuncu kubbeden çıkan sesi hemen boğuk duyar (oyuncu sesleri her kare yeniden değerlendirilir).
	var walker := FakeLocal.new()
	walker.add_to_group("remote_players")
	add_child(walker)
	walker.global_position = center
	var step := _sound_at(walker, center)
	await get_tree().physics_frame
	assert(step.bus == &"Master", "içerideki dostun sesi normal")
	walker.global_position = center + Vector2(0.0, 200.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(step.bus == muffle, "dışarı çıkan dostun sesi boğuk")
	## Kubbe kapanınca her şey eski yoluna döner.
	m.free()
	await get_tree().physics_frame
	assert(not AudioBusesScript.in_dome, "kubbe yok")
	for s: AudioStreamPlayer2D in ring:
		assert(s.bus == &"Master", "kubbe bitince dış ses normale döndü")
	assert(before.bus == &"Master" and step.bus == &"Master", "hepsi Master")
	AudioBusesScript.route_rim_sound(rim_weapon, false)
	assert(rim_weapon.bus == &"Master", "taç silahı da normale döner")
	for s in ring + inner + [own, rim_weapon, before, step, walker]:
		if is_instance_valid(s):
			s.free()
	p.free()
