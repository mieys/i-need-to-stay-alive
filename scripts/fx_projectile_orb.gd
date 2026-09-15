extends Node2D

## Small procedurally-drawn glowing orb used as the visual for enemy_projectile.gd
## (ranged casters' bolts) - tinted per-family so Lich/Demon/Röntgen/İblis bolts
## read as distinct at a glance without needing bespoke art per creature.
@export var glow_color: Color = Color(1.0, 0.55, 0.15, 1.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.3))
	draw_circle(Vector2.ZERO, 6.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.65))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.9))
