extends Node2D

## Kubbe/baloncuk içindeyken dışarıdaki sesleri BOĞUK duyurma - TEK kaynak (2026-09-25).
## Kullananlar: Şovalye R kubbesi (fx_paladin_barrier.gd) ve seyyar satıcının güvenli baloncuğu (fx_merchant_bubble.gd,
## kullanıcı isteği: "bunun içindeyken de dışardaki hava durumunu sesleri vb tıpkı şovalye adamın bariyerinin içindeykenki
## gibi boğuk ve daha az duyalım"). Eskiden bu mantık fx_paladin_barrier.gd'nin içindeydi - satıcı ayrı bir baloncuk
## betiğine geçince iki kopya olmasın diye buraya çıkarıldı.
##
## NASIL (2026-10-17, madde 218): yerel oyuncu `radius` içindeyken kubbe dome_sound_router.gd'ye bildirilir (her kare - kubbe
## Yürüyen Kale ile hareket edebilir); yönlendirici kubbenin DIŞINDA çalan her AudioStreamPlayer2D'yi alçak geçiren + yankılı
## MUFFLE bus'ına alır, içindekiler normal kalır. ESKİDEN kubbenin dışını kaplayan audio_bus_override'lı halka Area2D kuruluyordu -
## Godot 4.7.2'de AudioStreamPlayer2D'yi hiç yönlendirmediği ölçüldü (dış sesler hiç boğulmuyordu). Konumsuz ortam sesleri (yağmur/
## rüzgar/fırtına/orman - AudioStreamPlayer, AMBIENT bus) de aynı anda boğulur (audio_buses.gd set_ambient_muffled).
## UI sesleri etkilenmez.

const AudioBuses := preload("res://scripts/audio_buses.gd")
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const DomeSoundRouter := preload("res://scripts/dome_sound_router.gd")

## Baloncuğun yarıçapı (dünya birimi) - sahibi add_child'dan önce atar (değişirse güncelleyebilir).
var radius: float = 126.0
## Şovalye'nin izometrik kubbesi (2026-10-14): alan `radius` eşdeğer yarıçaplı 2:1 ELİPS (paladin_dome.gd). Satıcı baloncuğu daire kalır.
var elliptic: bool = false
var _registered: bool = false

## Yerel oyuncunun şu an içinde olduğu kubbeler - biri bile varsa ortam sesleri boğuk kalır.
static var _domes_with_player_inside: Dictionary = {}


func _process(_delta: float) -> void:
	var local_player := get_tree().get_first_node_in_group("player") as Node2D
	var inside: bool = local_player != null and is_instance_valid(local_player) and local_player.get("is_dead") != true 		and (PaladinDome.contains(global_position, radius, local_player.global_position) if elliptic 			else local_player.global_position.distance_to(global_position) <= radius)
	if inside:
		if not _registered:
			_registered = true
			_domes_with_player_inside[get_instance_id()] = true
			AudioBuses.set_ambient_muffled(true)
		DomeSoundRouter.set_dome(get_tree(), get_instance_id(), global_position, radius, elliptic)
	elif _registered:
		_unregister()


func _exit_tree() -> void:
	_unregister()


func _unregister() -> void:
	if not _registered:
		return
	_registered = false
	DomeSoundRouter.clear_dome(get_instance_id())
	if _domes_with_player_inside.erase(get_instance_id()) and _domes_with_player_inside.is_empty():
		AudioBuses.set_ambient_muffled(false)
