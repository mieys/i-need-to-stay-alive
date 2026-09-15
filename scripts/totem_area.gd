extends TotemBase
class_name TotemArea

## Alan Saldırı Totemi (Shaman R, skill3 id 28): "Totem etrafına bir alan
## açar, o alanın içine giren düşmanlar %20 + shaman'ın saldırı gücünün
## %20'si kadar yavaşlar (10 saldırı gücü = %2 yavaşlatma, en fazla %80).
## Ayrıca alanın içinde duran düşmanlar her saniye shaman'ın saldırı
## gücünün %20'si kadar hasar alır."
##
## Yavaşlatma enemy.gd'nin GENEL apply_slow(percent, duration) fonksiyonuna
## (bkz. orada - "aynı vuruşta en güçlüsü kalır" deseni, zaten var olan bir
## mekanizma, ikinci bir kopya yazılmadı) kısa bir süreyle (bu totem'in kendi
## TICK_INTERVAL'inden biraz uzun) her tik yeniden uygulanıyor - düşman
## alanda durduğu sürece sürekli tazelenir, çıkınca kendiliğinden biter.
## NOT: apply_slow() kendi içinde %75 ile sınırlıyor - kullanıcının istediği
## %80 tavanı bu yüzden pratikte %75'te kalıyor (mevcut genel mekanizmaya
## ikinci bir paralel sistem eklemek yerine kabul edilen küçük bir sapma).
const BASE_SLOW_PERCENT := 0.20
const SLOW_PER_ATTACK_POWER := 0.002 ## 10 saldırı gücü = %2 (0.002*10=0.02)
const MAX_SLOW_PERCENT := 0.80
const DAMAGE_ATTACK_POWER_RATIO := 0.20
const SLOW_REFRESH_DURATION := 1.5 ## TICK_INTERVAL'den (1.0sn) biraz uzun - alanda duran düşmanda hiç boşluk kalmaz

## Yeteneğe özgü efekt (KOZMETİK - yavaşlatma/hasar hesaplarıyla ilgisi yok):
## alanın içinde dönen boşluk girdabı (_draw) + alandaki düşmanların her tik
## hasarında üstlerine kısa birer boşluk perisi (_spawn_void_wisp).
const WISP_PARTICLES := 5


func _init() -> void:
	totem_color = Color(0.65, 0.35, 0.85)
	totem_radius = 180.0
	## Yavaşlatma bölgesinin İÇİ hafif mor dolgun görünsün (TotemBase._draw).
	aura_fill_alpha = 0.07


func _ready() -> void:
	super()
	## Alandan yükselen boşluk parçacıkları - yavaşlatma bölgesinin "yaşayan
	## bir boşluk" olduğunu hissettirir. Salt görsel, ağ kopyalarında da çalışır.
	var motes := CPUParticles2D.new()
	motes.amount = 14
	motes.lifetime = 2.2
	motes.preprocess = 2.2
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = totem_radius * 0.8
	motes.direction = Vector2.UP
	motes.spread = 20.0
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 30.0
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.0
	motes.color = Color(totem_color.r, totem_color.g, totem_color.b, 0.55)
	motes.z_index = -1
	add_child(motes)


## Alan Totemi'nin girdabı - yavaşlatma alanının içinde yavaşça dönen 3
## sarmal kol. TotemBase._draw (aura + dolgu) ÇİZİLMEYE DEVAM EDER, bu ekstra
## katman onun üstüne biner (super._draw() çağrısıyla).
func _draw() -> void:
	super()
	var spiral_alpha: float = 0.35
	for arm in 3:
		var start_angle: float = visual_time * 1.1 + float(arm) * TAU / 3.0
		var points := PackedVector2Array()
		var steps := 22
		for i in steps + 1:
			var t: float = float(i) / float(steps)
			var r: float = lerpf(22.0, totem_radius * 0.9, t)
			var angle: float = start_angle + t * 2.4 ## sarmal burulması
			points.append(Vector2.from_angle(angle) * r)
		var arm_color := Color(totem_color.r, totem_color.g, totem_color.b, spiral_alpha * (1.0 - 0.3 * float(arm) / 3.0))
		draw_polyline(points, arm_color, 2.0, true)


## Hasar tikinde düşmanın üstünde kısa süreli boşluk perisi - "bu düşman şu
## an alan hasarı yiyor" sinyali. Salt kozmetik, hasar hesabı _tick'te bitti.
func _spawn_void_wisp(enemy_pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	var wisp := CPUParticles2D.new()
	wisp.position = enemy_pos + Vector2(0, -10)
	wisp.one_shot = true
	wisp.emitting = true
	wisp.explosiveness = 0.9
	wisp.amount = WISP_PARTICLES
	wisp.lifetime = 0.45
	wisp.direction = Vector2.UP
	wisp.spread = 40.0
	wisp.initial_velocity_min = 30.0
	wisp.initial_velocity_max = 80.0
	wisp.gravity = Vector2(0, -40) ## hafif yukarı süzülme
	wisp.scale_amount_min = 1.5
	wisp.scale_amount_max = 3.0
	wisp.color = Color(totem_color.r, totem_color.g, totem_color.b, 0.8)
	wisp.z_index = 5
	scene.add_child(wisp)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(wisp):
			wisp.queue_free()
	)


func _tick() -> void:
	if not ("damage_bonus" in caster):
		return
	var attack_power: float = float(caster.damage_bonus)
	var slow_percent: float = clamp(BASE_SLOW_PERCENT + attack_power * SLOW_PER_ATTACK_POWER, 0.0, MAX_SLOW_PERCENT)
	var dmg: float = attack_power * DAMAGE_ATTACK_POWER_RATIO
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		if global_position.distance_to((e as Node2D).global_position) > totem_radius:
			continue
		if e.has_method("apply_slow"):
			e.apply_slow(slow_percent, SLOW_REFRESH_DURATION)
		if dmg > 0.0 and e.has_method("take_damage"):
			var is_crit: bool = false
			if caster.has_method("_roll_ability_crit"):
				is_crit = caster._roll_ability_crit()
			var hit_dmg: float = dmg
			if caster.has_method("_apply_ability_crit"):
				hit_dmg = caster._apply_ability_crit(dmg, is_crit)
			e.call("take_damage", hit_dmg, is_crit)
			## Yetenek efekti: hasar yiyen düşmanın üstünde boşluk perisi.
			_spawn_void_wisp((e as Node2D).global_position)
