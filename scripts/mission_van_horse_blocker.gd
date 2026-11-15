extends Node2D

## Konvoy atının çarpışma çemberi ("move_blockers" sözleşmesi, player.gd _block_movement_into_blockers). Konumunu mission_van.gd
## _update_facing verir (atın gövdesi, arabanın önünde; yön değişince aynalanır). Ayrı düğüm: tek çember uzun at+arabayı kaplayamaz.

var block_radius: float = 11.0


func _ready() -> void:
	add_to_group("move_blockers")


func block_center() -> Vector2:
	return global_position
