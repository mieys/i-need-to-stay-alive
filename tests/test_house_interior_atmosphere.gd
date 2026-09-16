extends Node

## Kullanıcı isteği doğrulaması: "oyunda evin içindeyken ortam müziğinin
## çalmasını istemiyorum ve rüzgar efektinin olduğu canvaslayer'ın
## gözükmesini istemiyorum."
##
## Doğrulananlar:
##  - dışarıdayken rüzgar katmanı görünür + ortam müziği çalıyor,
##  - eve girince rüzgar katmanı gizleniyor + ortam müziği duraklatılıyor,
##  - çıkınca ikisi de geri geliyor,
##  - OYUN BAŞLANGICINDA evin içinde başlanıyorsa (house_interior._ready()
##    oyuncuyu içeri alıyor) atmosfer daha ilk kareden kapalı oluyor.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const HouseInteriorScript: GDScript = preload("res://scripts/house_interior.gd")


## Gerçek oyundaki kök yapıyı taklit eder: Main kökünün altında
## "Harita/CanvasLayer" (rüzgar efekti katmanı) ve "WindBreezeAmbient"
## (main.gd'nin oluşturduğu ortam müziği düğümü).
func _make_fake_world() -> Dictionary:
	var map_node := Node2D.new()
	map_node.name = "Harita"
	var wind := CanvasLayer.new()
	wind.name = "CanvasLayer"
	map_node.add_child(wind)
	add_child(map_node)
	var ambient := AudioStreamPlayer.new()
	ambient.name = "WindBreezeAmbient"
	## NOT: stream_paused, stream'i/çalması olmayan bir çalıcıda tutmuyor
	## (motor duraklatılacak bir çalma olmadığı için değeri sıfırlıyor) -
	## gerçek oyundaki düğüm de bir stream'e sahip ve çalıyor, o yüzden
	## testte de aynısı kuruluyor.
	ambient.stream = load("res://assets/audio/forest_ambient.mp3") as AudioStream
	add_child(ambient)
	ambient.play()
	return {"wind": wind, "ambient": ambient}


func _make_player() -> Node:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	return p


func test_indoors_hides_wind_layer_and_mutes_ambient() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## _find_outdoor_atmosphere() bunu kök kabul ediyor
	var world: Dictionary = _make_fake_world()
	var wind: CanvasLayer = world["wind"]
	var ambient: AudioStreamPlayer = world["ambient"]
	var player: Node = _make_player()

	## house_interior._ready() oyuncuyu bulup OTOMATİK olarak eve alır (oyun
	## başlangıcı senaryosu) - bu yüzden ilk karede atmosfer kapalı olmalı.
	var house: Node2D = HouseInteriorScript.new()
	add_child(house)
	assert(bool(player.get("is_indoors")), "Oyun başlangıcında oyuncu evin içinde olmalı (mevcut davranış)")
	assert(not wind.visible,
		"Evin içindeyken rüzgar efekt katmanı hâlâ görünüyor")
	assert(ambient.stream_paused,
		"Evin içindeyken ortam müziği hâlâ çalıyor")

	## Dışarı çıkınca ikisi de geri gelmeli.
	house._do_exit_house()
	assert(not bool(player.get("is_indoors")), "Çıkınca is_indoors false olmalı")
	assert(wind.visible, "Dışarıdayken rüzgar katmanı görünmüyor")
	assert(not ambient.stream_paused, "Dışarıdayken ortam müziği hâlâ duraklatılmış")

	## Tekrar içeri girince yine kapanmalı (F ile gerçek giriş yolu).
	house._do_enter_house()
	assert(not wind.visible, "Tekrar eve girince rüzgar katmanı gizlenmedi")
	assert(ambient.stream_paused, "Tekrar eve girince ortam müziği susmadı")

	_cleanup(house, player, world)
	get_tree().current_scene = previous_scene


## Testler aynı düğüm üzerinde (current_scene olarak kullanılan bu test node'u)
## art arda çalıştığı için sahte dünya düğümleri HEMEN (free ile, queue_free
## DEĞİL - o bir sonraki karede siler ve sonraki test eski "Harita" düğümünü
## bulup yanlış hedefi gizlerdi) serbest bırakılır.
func _cleanup(house: Node, player: Node, world: Dictionary) -> void:
	house.queue_free()
	player.queue_free()
	var map_node: Node = (world["wind"] as Node).get_parent()
	if map_node and is_instance_valid(map_node):
		map_node.free()
	if world["ambient"] and is_instance_valid(world["ambient"]):
		(world["ambient"] as Node).free()


## Atmospheric düğümler house_interior'un _ready()'sinden SONRA oluşturulursa
## (main.gd ambient düğümünü kendi _ready()'sinde ekliyor) _process içindeki
## telafi kontrolü devreye girmeli.
func test_late_created_atmosphere_is_still_muted_indoors() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Node = _make_player()
	var house: Node2D = HouseInteriorScript.new()
	add_child(house)
	## NOT: house_interior._ready() oyuncuyu "player" grubundan bulur; önceki
	## testten queue_free() ile serbest bırakılmış (henüz silinmemiş) bir düğüm
	## grubu hâlâ tutuyor olabilir. Bu testin konusu "sonradan oluşan atmosfer"
	## olduğu için oyuncuyu burada açıkça atayıp içeri alıyoruz.
	if not bool(player.get("is_indoors")):
		house._player = player
		house._do_enter_house()
	assert(bool(player.get("is_indoors")), "Oyuncu evin içinde olmalı")

	## Atmosfer düğümleri ŞİMDİ oluşturuluyor (house._ready() çoktan çalıştı).
	var world: Dictionary = _make_fake_world()
	var wind: CanvasLayer = world["wind"]
	var ambient: AudioStreamPlayer = world["ambient"]
	assert(wind.visible, "Yeni oluşan katman başlangıçta görünür olmalı (test kurulumu)")

	## _process bir kare çalışınca telafi kontrolü atmosferi kapatmalı.
	house._process(0.016)
	assert(not wind.visible, "Sonradan oluşan rüzgar katmanı içerideyken gizlenmedi")
	assert(ambient.stream_paused, "Sonradan oluşan ortam müziği içerideyken susmadı")

	_cleanup(house, player, world)
	get_tree().current_scene = previous_scene


## Giriş/çıkış fonksiyonlarının atmosfer çağrılarını içerdiği kaynak düzeyinde
## de doğrulanır (fonksiyon adı değişirse test kırılıp haber verir).
func test_enter_and_exit_wire_the_atmosphere() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/house_interior.gd")
	assert(src.length() > 0, "house_interior.gd okunamadı")
	assert(src.find("_set_outdoor_atmosphere_enabled(false)") != -1,
		"Eve giriş atmosferi (müzik + rüzgar) kapatmıyor")
	assert(src.find("_set_outdoor_atmosphere_enabled(true)") != -1,
		"Evden çıkış atmosferi geri açmıyor")
