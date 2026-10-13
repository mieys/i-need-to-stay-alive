extends Node

## Kalp efekti (diriltme / Anka Mührü / arkadaştan altın hediyesi): döngüde oynar, 3 sn sonra solarak biter (kullanıcı 2026-10-13).

const HeartScene: PackedScene = preload("res://scenes/fx_revive_heart.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func test_heart_animation_loops_and_keeps_playing() -> void:
	var h: AnimatedSprite2D = HeartScene.instantiate()
	add_child(h)
	assert(h.sprite_frames.get_animation_loop("appear"), "kalp animasyonu döngüde olmalı")
	h.set_frame_and_progress(h.sprite_frames.get_frame_count("appear") - 1, 0.99)
	assert(h.is_playing(), "son kareye gelince durmaz")
	h.queue_free()


func test_player_play_heart_fx_adds_looping_heart() -> void:
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	var before: int = p.get_child_count()
	p.play_heart_fx()
	assert(p.get_child_count() == before + 1, "kalp efekti sahibin çocuğu olarak eklenir")
	var heart: Node = p.get_child(p.get_child_count() - 1)
	assert(heart is AnimatedSprite2D and (heart as AnimatedSprite2D).is_playing() and (heart as AnimatedSprite2D).sprite_frames.get_animation_loop("appear"))
	p.queue_free()
