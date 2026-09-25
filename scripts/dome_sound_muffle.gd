extends Node2D

## Kubbe/baloncuk içindeyken dışarıdaki sesleri BOĞUK duyurma - TEK kaynak (2026-09-25).
## Kullananlar: Şovalye R kubbesi (fx_paladin_barrier.gd) ve seyyar satıcının güvenli baloncuğu (fx_merchant_bubble.gd,
## kullanıcı isteği: "bunun içindeyken de dışardaki hava durumunu sesleri vb tıpkı şovalye adamın bariyerinin içindeykenki
## gibi boğuk ve daha az duyalım"). Eskiden bu mantık fx_paladin_barrier.gd'nin içindeydi - satıcı ayrı bir baloncuk
## betiğine geçince iki kopya olmasın diye buraya çıkarıldı.
##
## NASIL: yerel oyuncu `radius` içindeyken baloncuğun DIŞINI kaplayan halka biçimli bir Area2D kurulur; audio_bus_override
## ile o halkanın içinde (yani baloncuğun dışında) çalan her AudioStreamPlayer2D, alçak geçiren filtreli MUFFLE_BUS'a
## yönlenir (Godot: 2D ses çalar, bulunduğu noktadaki bus-override'lı alanın bus'ını kullanır). Baloncuğun içindeki
## sesler normal kalır. Alan, hiçbir Area2D sinyali/sorgusu olmayan oyunda çarpışma katmanı 1'de (AudioStreamPlayer2D.
## area_mask varsayılanı) ama monitorable/monitoring KAPALI durur - fiziğe etkisi yoktur. Konumsuz ortam sesleri (yağmur/
## rüzgar/fırtına/orman - AudioStreamPlayer, AMBIENT bus) de aynı anda boğulur (audio_buses.gd set_ambient_muffled).
## UI sesleri etkilenmez.

const AudioBuses := preload("res://scripts/audio_buses.gd")
const MUFFLE_OUTER_RADIUS := 4000.0
const MUFFLE_SEGMENTS := 24

## Baloncuğun yarıçapı (dünya birimi) - sahibi add_child'dan önce atar (değişirse güncelleyebilir).
var radius: float = 126.0
var _muffle_area: Area2D = null

## Yerel oyuncunun şu an içinde olduğu kubbeler - biri bile varsa ortam sesleri boğuk kalır.
static var _domes_with_player_inside: Dictionary = {}


func _process(_delta: float) -> void:
	var local_player := get_tree().get_first_node_in_group("player") as Node2D
	var inside: bool = local_player != null and is_instance_valid(local_player) and local_player.get("is_dead") != true \
		and local_player.global_position.distance_to(global_position) <= radius
	if inside and _muffle_area == null:
		_create_muffle_area()
	elif not inside and _muffle_area != null:
		_remove_muffle_area()
	if _muffle_area != null:
		_muffle_area.global_position = global_position


func _exit_tree() -> void:
	_remove_muffle_area()


func _create_muffle_area() -> void:
	_domes_with_player_inside[get_instance_id()] = true
	AudioBuses.set_ambient_muffled(true)
	var area := Area2D.new()
	area.name = "BarrierMuffleArea"
	area.top_level = true
	area.monitoring = false
	area.monitorable = false
	area.collision_layer = 1 ## AudioStreamPlayer2D.area_mask varsayılanı
	area.collision_mask = 0
	area.audio_bus_override = true
	area.audio_bus_name = AudioBuses.muffle_bus()
	## Halka: baloncuk yarıçapından dışarı, MUFFLE_SEGMENTS dışbükey dörtgen (CollisionPolygon2D delikli şekil almaz).
	var inner: float = radius
	for i in range(MUFFLE_SEGMENTS):
		var a0: float = TAU * float(i) / MUFFLE_SEGMENTS
		var a1: float = TAU * float(i + 1) / MUFFLE_SEGMENTS
		var poly := CollisionPolygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2.from_angle(a0) * inner, Vector2.from_angle(a0) * MUFFLE_OUTER_RADIUS,
			Vector2.from_angle(a1) * MUFFLE_OUTER_RADIUS, Vector2.from_angle(a1) * inner,
		])
		area.add_child(poly)
	add_child(area)
	area.global_position = global_position
	_muffle_area = area


func _remove_muffle_area() -> void:
	if _muffle_area != null and is_instance_valid(_muffle_area):
		_muffle_area.queue_free()
	_muffle_area = null
	if _domes_with_player_inside.erase(get_instance_id()) and _domes_with_player_inside.is_empty():
		AudioBuses.set_ambient_muffled(false)
