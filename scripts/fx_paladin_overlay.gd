extends Node2D

func _draw() -> void:
	var p = get_parent()
	if p and p.has_method("_draw_overlay"):
		p._draw_overlay(self)
