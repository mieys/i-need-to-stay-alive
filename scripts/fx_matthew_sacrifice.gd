extends Node2D
class_name MatthewSacrificeFx

## Matthew fedası (turuncu ruh halkası). Madde 215: kare kare `_draw` + parçacık benzetimi SPRITE SAYFASINA pişirildi (assets/fx/baked/matthew_sacrifice_*,
## `tools/fx_bake.ps1`; özgün kod `tools/fx_bake_src/fx_matthew_sacrifice.gd` - görünümü değiştirirsen oradan yeniden pişir).
## Tek AnimatedSprite2D oynar, kare başı GDScript/çizim yok. Çok oyunculu: sahne aynı, ek RPC yok.

const BakedFx := preload("res://scripts/baked_fx.gd")
const FRAMES := preload("res://assets/fx/baked/matthew_sacrifice_frames.tres")

var duration: float = 1.5
var elapsed: float = 0.0


func _ready() -> void:
	position = Vector2.ZERO
	BakedFx.attach(self, FRAMES)
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.95, 1.05)
		s.play()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
