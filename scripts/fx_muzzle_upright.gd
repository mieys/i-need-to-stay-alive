extends "res://scripts/fx_animation.gd"

## Yönlü namlu efekti (Pompalı, madde 448): sayfa ucu +x çizildi, duman -y'ye (yukarı) süzülür. Sola ateşte 180 derece dönünce duman
## aşağı akmasın diye dikey aynalanır. Döndürme add_child'dan SONRA yazılıyor (weapon.gd _spawn_muzzle_flash, network_manager
## "muzzle_flash") -> bir kare ertelenir.


func _ready() -> void:
	super()
	call_deferred("_upright")


func _upright() -> void:
	if is_instance_valid(self) and cos(global_rotation) < 0.0:
		flip_v = true
