extends Node

## Kullanıcı isteği doğrulaması: "4 yürüme sesi ekledim bu sesler rastgele bir
## şekilde çalacak karakter hareket ederken. Ayrıca her seferinde fark
## edilmeyecek derecede çok az pitch farkı eklemeni istiyorum. seslerini %75
## azaltmayı unutma".
##
## Doğrulananlar:
##  1) player.tscn'de 4 AYRI adım sesi var (WalkSound1..4), hepsi farklı dosya,
##  2) ses seviyeleri %75 azaltılmış (lineer 0.25 => ~-12.04 dB),
##  3) karakter dururken hiç adım sesi çalınmıyor, hareket edince hemen çalıyor,
##  4) adımlar belli bir aralıkla geliyor (her karede değil),
##  5) hız arttıkça adımlar SIKLAŞIYOR ve sesler TİZLEŞİYOR,
##  6) her adımda pitch'e çok küçük RASTGELE bir sapma ekleniyor,
##  7) ses seçimi gerçekten rastgele (hep aynı ses çalmıyor),
##  8) üst üste binen adımlar birbirini kesmiyor (çalıcı havuzu),
##  9) gerçek oyunda _physics_process tarafından, ölüm/düşme dallarında da
##     doğru şekilde çağrılıyor (kaynak metinden, bkz. son test).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const WALK_SOUND_COUNT := 4
## Fizik karesi başına gelen küçük delta ile YENİ adım gelmemeli; aralıktan
## belirgin şekilde uzun bir delta ile gelmeli (normal hızda aralık 0.536sn).
const ALMOST_NO_TIME := 0.02
const LONGER_THAN_INTERVAL := 0.7


func _make_player() -> Node:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


func _playing_count(player: Node) -> int:
	var count: int = 0
	for step_sound in player._walk_sounds:
		if step_sound.playing:
			count += 1
	return count


func _first_playing(player: Node) -> AudioStreamPlayer2D:
	for step_sound in player._walk_sounds:
		if step_sound.playing:
			return step_sound
	return null


## Adım aralığı ve pitch artık karakterin GERÇEK hareket hızından (velocity)
## hesaplandığı için testlerde "şu hızda yürüyor" durumunu bu yardımcı kurar:
## ratio 1.0 = normal yürüyüş hızı (velocity = speed).
func _walk_at(player: Node, ratio: float) -> void:
	player.velocity = Vector2(player.speed * ratio, 0.0)


func test_four_distinct_walk_sounds_at_reduced_volume() -> void:
	var player: Node = _make_player()
	var sounds: Array = player._walk_sounds
	assert(sounds.size() == WALK_SOUND_COUNT,
		"Sahnede %d adım sesi olmalı, bulunan: %d" % [WALK_SOUND_COUNT, sounds.size()])

	var paths: Array[String] = []
	for step_sound in sounds:
		assert(step_sound.stream != null, "%s'e stream atanmamış" % step_sound.name)
		paths.append(step_sound.stream.resource_path)
		## %75 azaltma => genlik 0.25 katı => 20*log10(0.25) = -12.04 dB
		assert(absf(step_sound.volume_db - linear_to_db(0.25)) < 0.05,
			"%s sesi %%75 azaltılmamış, volume_db: %s (beklenen ~-12.04)" % [step_sound.name, step_sound.volume_db])

	var unique_paths: Dictionary = {}
	for path in paths:
		unique_paths[path] = true
	assert(unique_paths.size() == WALK_SOUND_COUNT,
		"Adım sesleri farklı dosyalar değil (rastgelelik işe yaramaz): %s" % [paths])
	player.queue_free()


func test_no_step_when_standing_still() -> void:
	var player: Node = _make_player()
	for i in range(10):
		player._update_walk_sound(false, 0.1)
	assert(_playing_count(player) == 0, "Karakter dururken adım sesi çalındı")
	player.queue_free()


func test_first_step_plays_immediately_when_starting_to_move() -> void:
	var player: Node = _make_player()
	player._update_walk_sound(true, 0.0)
	assert(_playing_count(player) == 1,
		"Hareket etmeye başlar başlamaz ilk adım gecikmesiz duyulmalı, çalan: %d" % _playing_count(player))
	player.queue_free()


func test_step_cadence_waits_for_interval() -> void:
	var player: Node = _make_player()
	_walk_at(player, 1.0) ## normal hızda yürüyor
	player._update_walk_sound(true, 0.0) ## ilk adım hemen
	assert(_playing_count(player) == 1, "İlk adım çalınmadı")

	player._update_walk_sound(true, ALMOST_NO_TIME)
	assert(_playing_count(player) == 1,
		"Adım aralığı dolmadan yeni adım sesi çalındı (her karede adım atılıyor)")

	player._update_walk_sound(true, LONGER_THAN_INTERVAL)
	assert(_playing_count(player) == 2,
		"Adım aralığı dolduğu hâlde yeni adım sesi çalınmadı, çalan: %d" % _playing_count(player))
	player.queue_free()


## Kullanıcı geri bildirimleri: "adım sesleri çok hızlı" (0.375sn) -> %30
## yavaşlatıldı (0.536sn) -> "bu kez de çok yavaş oldu, biraz arttır". Bu
## yüzden aralık ikisinin ARASINDA olmalı: eski "çok hızlı" değerden yavaş,
## son "çok yavaş" değerden hızlı.
func test_step_interval_sits_between_fast_and_slow_settings() -> void:
	var player: Node = _make_player()
	assert(player.WALK_STEP_INTERVAL > 0.375,
		"Adım aralığı 'çok hızlı' bulunan 0.375sn değerine geri dönmüş: %s" % player.WALK_STEP_INTERVAL)
	assert(player.WALK_STEP_INTERVAL < 0.536,
		"Adım aralığı 'çok yavaş' bulunan 0.536sn değerinde kalmış: %s" % player.WALK_STEP_INTERVAL)
	var steps_per_second: float = 1.0 / player.WALK_STEP_INTERVAL
	assert(steps_per_second > 2.0 and steps_per_second < 2.5,
		"Saniyedeki adım sayısı beklenen aralıkta değil: %s" % steps_per_second)
	player.queue_free()


func test_steps_get_faster_and_higher_pitched_with_move_speed() -> void:
	var player: Node = _make_player()
	## %80 daha hızlı yürüyor - hız kartı/yeteneği/buff'ı ne olursa olsun sonuç
	## velocity'ye yansır ve adım aralığı/pitch oradan okunur.
	_walk_at(player, 1.8)
	player._update_walk_sound(true, 0.0)
	var first: AudioStreamPlayer2D = _first_playing(player)
	assert(first != null, "Hızlı hareket ederken adım sesi çalınmadı")
	assert(first.pitch_scale > 1.6 and first.pitch_scale < 1.95,
		"Yüksek hızda pitch tavan civarında (~1.8) olmalı, bulunan: %s" % first.pitch_scale)

	## Yüksek hızda aralık 0.536/1.8 ≈ 0.30sn'ye iner - normal hızda aynı süre
	## (0.35sn) yeni bir adım için YETMEZDİ, burada yetmeli.
	player._update_walk_sound(true, 0.35)
	assert(_playing_count(player) == 2,
		"Hız artınca adımlar sıklaşmadı, çalan: %d" % _playing_count(player))
	player.queue_free()


## Kullanıcı isteği ("karakterin hareket hızıyla eşitlememiz gerek"): adım hızı
## karakterin O ANKİ gerçek hızından (velocity) okunmalı.
func test_step_rate_follows_actual_move_speed() -> void:
	var player: Node = _make_player()
	var pitches: Array[float] = []
	for ratio in [0.5, 1.0, 1.5]:
		for step_sound in player._walk_sounds:
			step_sound.stop()
		_walk_at(player, ratio)
		## 1sn delta: her hız sınıfının aralığından uzun olduğu için, sayaç
		## önceki örneklemden kalmış olsa da adım KESİN çalınır.
		player._update_walk_sound(true, 1.0)
		var playing: AudioStreamPlayer2D = _first_playing(player)
		assert(playing != null, "%%%s hızda adım sesi çalınmadı" % [ratio])
		pitches.append(playing.pitch_scale)
	## 0.5 -> alt sınıra (0.85) kırpılır, 1.0 -> ~1.0, 1.5 -> ~1.5 (hepsi ±%4 sapma)
	assert(pitches[0] < pitches[1] and pitches[1] < pitches[2],
		"Adım hızı karakterin hareket hızını izlemiyor: %s" % [pitches])
	player.queue_free()


## Dışarıdan itilme (knockback) karakterin KENDİ yürüyüşü değildir - adım
## hızını fırlatmamalı, yoksa geri itilirken bir anda adım yağmuru olurdu.
func test_knockback_does_not_speed_up_steps() -> void:
	var player: Node = _make_player()
	var push: Vector2 = Vector2(player.speed * 3.0, 0.0)
	player._knockback_velocity = push
	player.velocity = push ## sadece itiliyor, kendi yürüyüşü yok
	player._update_walk_sound(true, 0.0)
	var playing: AudioStreamPlayer2D = _first_playing(player)
	assert(playing != null, "Adım sesi çalınmadı")
	assert(playing.pitch_scale < 1.0,
		"Sadece knockback varken adım hızı fırladı: %s" % playing.pitch_scale)
	player.queue_free()


func test_pitch_jitter_is_tiny_and_random() -> void:
	var player: Node = _make_player()
	var pitches: Array[float] = []
	for i in range(12):
		for step_sound in player._walk_sounds:
			step_sound.stop() ## her örneklemi bağımsız yapabilmek için
		player._play_walk_step(1.0)
		var playing: AudioStreamPlayer2D = _first_playing(player)
		assert(playing != null, "Adım sesi çalınmadı")
		pitches.append(playing.pitch_scale)

	assert(player.WALK_SOUND_PITCH_JITTER <= 0.05,
		"Pitch sapması çok büyük - kullanıcı 'fark edilmeyecek derecede çok az' istedi")
	for pitch in pitches:
		assert(absf(pitch - 1.0) <= player.WALK_SOUND_PITCH_JITTER + 0.001,
			"Adım pitch sapması izin verilen sınırı aşıyor: %s" % pitch)

	var distinct: Dictionary = {}
	for pitch in pitches:
		distinct[snappedf(pitch, 0.0001)] = true
	assert(distinct.size() > 1,
		"Her adımda rastgele pitch sapması uygulanmıyor (hep aynı: %s)" % pitches[0])
	player.queue_free()


func test_sound_selection_is_random() -> void:
	var player: Node = _make_player()
	var used: Dictionary = {}
	for i in range(24):
		for step_sound in player._walk_sounds:
			step_sound.stop()
		player._play_walk_step(1.0)
		var playing: AudioStreamPlayer2D = _first_playing(player)
		if playing:
			used[String(playing.name)] = true
	assert(used.size() > 1,
		"Adım sesleri rastgele seçilmiyor, hep aynısı çalıyor: %s" % [used.keys()])
	player.queue_free()


func test_overlapping_steps_do_not_cut_each_other() -> void:
	var player: Node = _make_player()
	for i in range(WALK_SOUND_COUNT):
		player._play_walk_step(1.0)
	assert(_playing_count(player) == WALK_SOUND_COUNT,
		"Üst üste gelen adımlar birbirini kesiyor (çalıcı havuzu çalışmıyor), çalan: %d" % _playing_count(player))
	player.queue_free()


## _physics_process gerçek oyunda tek çağrı yeridir - kablolama kaynak metinden
## doğrulanıyor (test ortamında get_tree() null olduğu için canlı
## _physics_process çalıştırılamıyor, bkz. diğer testlerdeki aynı kısıt).
func test_physics_process_wiring() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(source.length() > 0, "player.gd okunamadı")
	assert(source.find("_update_walk_sound(effective_direction.length() > 0.1, delta)") != -1,
		"_physics_process adım seslerini hareket durumuna (ve delta'ya) göre güncellemiyor")
	assert(source.find("_update_walk_sound(false, delta)\n\t\t_process_downed(delta)") != -1,
		"Downed (düşme) dalında adım planlaması durdurulmuyor")
	assert(source.find("if is_dead:\n\t\t_update_walk_sound(false, delta)") != -1,
		"Ölüm dalında adım planlaması durdurulmuyor")
