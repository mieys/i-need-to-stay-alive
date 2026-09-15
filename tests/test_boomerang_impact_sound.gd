extends Node

## Kullanıcı isteği doğrulaması: "'boomerang isabet' adında bir ses efekti
## yükledim. bu ses efektini boomerang bir yaratığa çarpınca çıkacak, ufak
## pitch değişimleri de ekle yoksa aynı ses sıkıcılığı olur. ayrıca boomerangın
## spin sesini %50 arttır."
##
## Doğrulananlar:
##  1) boomerang_projectile.tscn'de isabet sesi TANIMLI ve doğru dosya,
##  2) yaratığa çarpınca ses gerçekten çalınıyor (mermi ölse de kesilmemesi
##     için sahne köküne bağlı ayrı bir çalıcı olarak),
##  3) her isabette pitch'e KÜÇÜK rastgele sapma uygulanıyor (sapma aralığı
##     içinde ve gerçekten değişken),
##  4) aynı bacakta aynı düşmana iki kez vurulmuyor (ses spam'i olmaması),
##  5) spin sesi %50 artmış (genlik x1.5 = +3.52 dB).

const BoomerangScene: PackedScene = preload("res://scenes/boomerang_projectile.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const IMPACT_SOUND_PATH := "res://assets/audio/boomerang isabet.mp3"
## Eski/yeni spin sesi seviyesi (boomerang_projectile.tscn "Sound" node)
const SPIN_VOLUME_BEFORE_DB := -14.0


func _impact_players_on(parent: Node) -> Array:
	var found: Array = []
	for child in parent.get_children():
		if child is AudioStreamPlayer2D and child.stream \
				and child.stream.resource_path == IMPACT_SOUND_PATH:
			found.append(child)
	return found


## Testler aynı düğümü (current_scene olarak kullanılan bu test node'unu)
## paylaştığı için önceki testten kalan geçici ses çalıcıları temizlenir -
## yoksa sayım assert'leri birikir (test ortamında ses "bitmiş" sayılmadığı
## için kendini serbest bırakmıyorlar).
func _clear_impact_players() -> void:
	for player in _impact_players_on(self):
		player.free()


## _play_impact_sound() sesi get_tree().current_scene'e ekliyor (mermi yok
## olsa da çalabilsin diye) - test ortamında current_scene boş olabildiği için
## geçici olarak bu test düğümünü gösteriyoruz, sonunda geri alıyoruz.
func _use_self_as_current_scene() -> Node:
	var previous: Node = get_tree().current_scene
	get_tree().current_scene = self
	return previous


func test_impact_sound_is_configured() -> void:
	var proj: Node = BoomerangScene.instantiate()
	assert(proj.impact_sounds.size() == 1,
		"boomerang_projectile.tscn'de isabet sesi tanımlı değil (impact_sounds boş)")
	assert(proj.impact_sounds[0].resource_path == IMPACT_SOUND_PATH,
		"Yanlış ses atanmış: %s" % proj.impact_sounds[0].resource_path)
	proj.free()


func test_hitting_enemy_plays_impact_sound() -> void:
	var previous: Node = _use_self_as_current_scene()
	_clear_impact_players()
	var proj: Node = BoomerangScene.instantiate()
	add_child(proj)
	var enemy: Node = EnemyScene.instantiate()
	enemy.max_health = 100000.0
	enemy.health = 100000.0 ## test sırasında ölüp XP/efekt üretmesin
	add_child(enemy)

	proj._on_body_entered(enemy)
	var players: Array = _impact_players_on(self)
	assert(players.size() == 1,
		"Yaratığa çarpınca isabet sesi çalınmadı (bulunan çalıcı: %d)" % players.size())
	var player: AudioStreamPlayer2D = players[0]
	assert(player.playing, "İsabet sesi oluşturuldu ama çalmıyor")
	assert(absf(player.volume_db - proj.impact_sound_volume_db) < 0.01,
		"İsabet sesi seviyesi sahnedeki değeri kullanmıyor: %s" % player.volume_db)

	## Aynı bacakta aynı düşmana iki kez vurulmaz - ses üst üste binmesin.
	proj._on_body_entered(enemy)
	assert(_impact_players_on(self).size() == 1,
		"Aynı düşmana aynı bacakta iki kez çarpınca ses tekrar çalındı")

	proj.queue_free()
	enemy.queue_free()
	get_tree().current_scene = previous


func test_impact_sound_has_small_random_pitch_jitter() -> void:
	var previous: Node = _use_self_as_current_scene()
	_clear_impact_players()
	var proj: Node = BoomerangScene.instantiate()
	add_child(proj)

	## Doğrudan _play_impact_sound() çağrılıyor ki tek testte çok örneklem
	## toplanabilsin (aynı düşmana tekrar vurmak kasıtlı olarak engelli).
	var pitches: Array[float] = []
	for i in range(12):
		proj._play_impact_sound()
	var players: Array = _impact_players_on(self)
	assert(players.size() == 12, "Beklenen sayıda isabet sesi üretilmedi: %d" % players.size())
	for player in players:
		pitches.append(player.pitch_scale)
		assert(player.pitch_scale >= 1.0 - proj.impact_pitch_jitter - 0.001
				and player.pitch_scale <= 1.0 + proj.impact_pitch_jitter + 0.001,
			"Pitch sapması izin verilen 'ufak' aralığın dışında: %s" % player.pitch_scale)
	assert(proj.impact_pitch_jitter <= 0.12,
		"Pitch sapması 'ufak' değil: %s (kullanıcı küçük sapma istedi)" % proj.impact_pitch_jitter)

	var distinct: Dictionary = {}
	for pitch in pitches:
		distinct[snappedf(pitch, 0.0001)] = true
	assert(distinct.size() > 1,
		"Her isabette aynı pitch çalınıyor - ses yine tekdüze olurdu: %s" % pitches[0])

	proj.queue_free()
	get_tree().current_scene = previous


func test_spin_sound_increased_by_50_percent() -> void:
	var proj: Node = BoomerangScene.instantiate()
	var sound: AudioStreamPlayer2D = proj.get_node_or_null("Sound")
	assert(sound != null, "Spin ses çalıcısı (Sound) bulunamadı")
	assert(sound.stream != null and sound.stream.resource_path.ends_with("boomerang_spin.mp3"),
		"Sound node'u spin sesini değil başka bir sesi çalıyor")
	## %50 artış = genlik x1.5 = +20*log10(1.5) = +3.52 dB
	var expected: float = SPIN_VOLUME_BEFORE_DB + linear_to_db(1.5)
	assert(absf(sound.volume_db - expected) < 0.02,
		"Spin sesi %%50 artmamış: %s dB (beklenen ~%s)" % [sound.volume_db, expected])
	assert(sound.volume_db > SPIN_VOLUME_BEFORE_DB,
		"Spin sesi eskisinden daha kısık görünüyor")
	proj.free()
