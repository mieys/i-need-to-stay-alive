extends Node2D

@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	if anim:
		anim.animation_finished.connect(queue_free)
	else:
		get_tree().create_timer(1.0).timeout.connect(queue_free)
