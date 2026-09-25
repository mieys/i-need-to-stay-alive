extends Node2D
class_name SkillBurstFx

## Uzaktaki oyuncu kuklalarında (RemotePlayer) yetenek anındaki parçacık
## patlamasını gösterir - player.gd _spawn_burst()'ün YERELDE yaptığı
## CPUParticles2D efektinin ağ üzerinden tetiklenen eşdeğeri (bkz.
## network_manager.gd broadcast_player_vfx "skill_burst" -> remote_player.gd
## _spawn_burst_vfx). Bu sahne dosyası eskiden HİÇ YOKTU - remote_player.gd
## onu load() ile yüklemeye çalışıp null dönünce .instantiate() çağırıyor,
## sonra add_child(null) ile host'un motorunu çöktürüyordu (kullanıcı
## bildirimi: "hostun oyunu kapanıyor bianda").

## Gece ışığının rengi (bkz. night_glow_catalog.gd "cp": "glow_color") - parçacıklarla aynı.
var glow_color: Color = Color(1.0, 0.9, 0.7)


func setup(radius: float, color: Color) -> void:
	glow_color = color
	var p := CPUParticles2D.new()
	add_child(p)
	var scale_ratio: float = clamp(radius / 100.0, 0.3, 3.0)
	p.amount = 28
	p.lifetime = 0.7
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 70.0 * scale_ratio
	p.initial_velocity_max = 170.0 * scale_ratio
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = color
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
