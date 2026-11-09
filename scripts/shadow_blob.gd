extends Node2D

## Silah gölgesi (weapon.gd shadow_sprite + remote_player.gd kukla silah gölgesi). ShadowsFlag.entities kapalıyken hiçbir şey çizmez (madde 484: açık)
## (görünürlük/saydamlık kodlarına dokunulmadı; geri açmak shadows_flag.gd `entities`).
const ShadowsFlag := preload("res://scripts/shadows_flag.gd")


func _draw() -> void:
	if not ShadowsFlag.entities:
		return
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.32))
