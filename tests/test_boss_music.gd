extends Node

## Kullanıcı isteği (2026-10-13): boss gelince masaüstündeki ParagonX9 müziği çalsın. scripts/boss_music.gd

const MusicScript: GDScript = preload("res://scripts/boss_music.gd")


class FakeBoss extends Node2D:
	var is_dead: bool = false


var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func _music() -> AudioStreamPlayer:
	var m := AudioStreamPlayer.new()
	m.set_script(MusicScript)
	add_child(m)
	_made.append(m)
	return m


func _boss() -> FakeBoss:
	var b := FakeBoss.new()
	b.add_to_group("boss")
	add_child(b)
	_made.append(b)
	return b


func test_music_file_loads_and_loops() -> void:
	var m := _music()
	assert(m.stream != null, "müzik dosyası yüklenmeli")
	assert(m.stream is AudioStreamWAV and (m.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "müzik (WAV) ileri döngüde olmalı")
	_cleanup()


## 2026-10-19: boss müziği %20 kısıldı (genlik x0,8) ve Ayarlar > Müzik Sesi'nin "Music" bus'ından çalar.
func test_boss_music_is_20_percent_quieter_and_on_music_bus() -> void:
	var m := _music()
	assert(absf(MusicScript.PLAY_DB - (-8.0 + linear_to_db(0.8))) < 0.01, "PLAY_DB: %s" % str(MusicScript.PLAY_DB))
	assert(m.bus == &"Music", "müzik bus'ı: %s" % str(m.bus))
	_cleanup()


func test_plays_only_while_a_boss_is_alive() -> void:
	var m := _music()
	m._process(1.0)
	assert(not m.playing, "boss yokken çalmamalı")
	var b := _boss()
	m._process(0.3)
	assert(m.playing, "boss gelince çalmalı")
	for i in range(10):
		m._process(0.3)
	assert(m.volume_db >= MusicScript.PLAY_DB - 0.01, "tam ses: %s" % m.volume_db)
	b.is_dead = true
	for i in range(30):
		m._process(0.3)
	assert(not m.playing, "boss ölünce müzik sönüp durmalı")
	_cleanup()
