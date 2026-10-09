extends "res://scripts/enemy.gd"

## YERALTI CANAVARI'NIN SOLUCAN UZVU (Kademe 5 bossu, bkz. worm_boss_math.gd ve underground_boss.gd). Yeryüzüne çıkan, YERİNDEN OYNAMAYAN dev solucan:
## delikten çıkar -> (YAKIN DÖVÜŞ: yanına gelen oyuncuyu savurur, 130 / ASİT ATAN: uzaktan yeşil damla fırlatır, 110) -> hasar eşiği dolunca parçalanır ya da
## deliğine geri döner; ömrü dolunca da döner. UZVUN YEDİĞİ HER HASAR bossun kalkan/can havuzundan düşer (_apply_damage -> boss.absorb_limb_damage).
## Normal bir Enemy'dir (C++ EnemyWorld'e kayıtlı: silahlar hedefler, mermiler vurur, kalabalık sorguları görür) ama: hareketsiz (ability_move_lock + hız 0),
## C++ temas saldırısı kapalı (_ew_on_event), ödülsüz (ölüm = dismiss_without_reward: drop yok, öldürme sayılmaz), kendi hasar eşiği = max_health.
##
## ÇOK OYUNCULU: karar + hasar + atış SADECE host'ta. Her peer'de AYNI görsel işlevler (host yerelde, istemci broadcast_enemy_vfx ile çalıştırır):
## "worm_setup" (tür: asit atan mı -> yeşilimsi ton), "worm_pose" (çıkış/savurma/tükürme/gömülme sayfası), "worm_strike" (toz + sarsıntı). Uzuv hiç hareket etmediği için
## konum paketleri sadece doğuş konumunu doğrular; ölüm "death_state" (enemy.gd die -> bu dosyanın die()'ı) ile, geri dönüş poz mesajıyla (her peer gömülme süresi sonra kendi siler).

const MathScript := preload("res://scripts/worm_boss_math.gd")
const SoundScript := preload("res://scripts/underground_sound.gd")

@export var emerge_texture: Texture2D
@export var lash_texture: Texture2D
@export var spit_texture: Texture2D
@export var hide_texture: Texture2D

enum WS { EMERGING, ACTIVE, ATTACKING, RETREATING }

## player.gd _block_movement_into_enemies: yumuşak gövde bloğu yerine bu SERT yarıçap (oyuncu bu kadar yaklaşamaz) - uzuv sıraları yolu gerçekten keser.
var hard_block_radius: float = MathScript.HARD_BLOCK_RADIUS
var kind: int = MathScript.KIND_LASHER
var fate: int = MathScript.FATE_BURST
var boss: Node = null ## SADECE host
var _ws: int = WS.EMERGING
var _t: float = 0.0
var _life: float = 12.0
var _cd: float = 0.0
var _atk: int = 0 ## 1 savurma, 2 tükürme
var _fired: bool = false
var _aim: Vector2 = Vector2.DOWN
var _warn_t: float = 0.0 ## >0: savurma uyarısı (kırmızı parlama) sürüyor
var _base_tint: Color = Color.WHITE
var _retreating_visual: bool = false


# ---------------------------------------------------------------------------------------------------- kurulum
## Doğuşta bir kez ağ kimliği/ağ yayınından SONRA host çağırır (underground_boss.gd _spawn_limb).
func begin_limb(owner_boss: Node, limb_kind: int, limb_fate: int, lifetime: float) -> void:
	boss = owner_boss
	kind = limb_kind
	fate = limb_fate
	_life = lifetime
	_ws = WS.EMERGING
	_t = 0.0
	emit_ability_vfx("worm_setup", {"kind": limb_kind})
	emit_ability_vfx("worm_pose", {"pose": MathScript.POSE_EMERGE})


## Geç katılan oyuncuya (host, enemy_spawner.gd _on_peer_needs_game_catchup) uzvun türü + görünen pozu.
func send_catchup_to_peer(peer_id: int) -> void:
	var net_id: int = int(get_meta("network_enemy_id", 0))
	if net_id <= 0 or is_dead:
		return
	NetworkManager.broadcast_enemy_vfx.rpc_id(peer_id, net_id, "worm_setup", {"kind": kind})
	if _pose_override != MathScript.POSE_NONE:
		NetworkManager.broadcast_enemy_vfx.rpc_id(peer_id, net_id, "worm_pose", {"pose": _pose_override})


func _apply_worm_setup(limb_kind: int) -> void:
	kind = limb_kind
	_base_tint = Color(0.8, 1.0, 0.7) if kind == MathScript.KIND_SPITTER else Color.WHITE ## asit atanlar yeşilimsi: tehdidi okunur
	if frame_sprite:
		frame_sprite.self_modulate = _base_tint


func _apply_difficulty_scaling() -> void:
	pass ## uzvun eşiği SABİT (zamanla büyümez)


## Uzuv bossun görünen gövdesi: bosslar yaratıkların %15'i yerine %20 küçülür (EntityScale.BOSS_REL).
func _size_extra() -> float:
	return EntityScale.BOSS_EXTRA


# ---------------------------------------------------------------------------------------------------- host tiki
func _is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _ew_still_active() -> bool:
	return not is_dead ## uzuv her karede tiklenir (kendi zamanlayıcıları var)


## C++ temas olayları kapalı: uzvun saldırıları kendi durum makinesinde.
func _ew_on_event(_type: int, _target: Node2D) -> void:
	return


func _ew_tick(delta: float) -> void:
	if not is_dead and _is_authority() and not _ew_puppet:
		_limb_tick(delta)
	if not is_dead:
		ability_move_lock = maxf(ability_move_lock, 0.3) ## C++ hareket/itilme kapalı (yerinden oynamaz)
	super._ew_tick(delta)


func _limb_tick(delta: float) -> void:
	_t += delta
	var target: Node2D = _nearest_target()
	if target != null and _ws != WS.RETREATING and (_ws != WS.ATTACKING):
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length() > 1.0:
			_update_facing(to_t.normalized())
	match _ws:
		WS.EMERGING:
			if _t >= MathScript.EMERGE_TIME:
				_ws = WS.ACTIVE
				_t = 0.0
				_cd = MathScript.FIRST_ATTACK_DELAY
				_emit_pose(MathScript.POSE_NONE)
		WS.ACTIVE:
			_life -= delta
			if _life <= 0.0:
				_begin_retreat()
				return
			_cd -= delta
			if _cd <= 0.0 and target != null:
				_try_attack(target)
		WS.ATTACKING:
			_life -= delta
			_attack_tick(target)
		WS.RETREATING:
			pass


## En yakın canlı, dışarıdaki oyuncu (yerel + uzak kukla).
func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for p: Node in EnemyAbilitiesScript.damageable_players(get_tree()):
		if not (p is Node2D) or p.get("is_indoors") == true or p.get("is_in_merchant_zone") == true or p.get("is_downed") == true:
			continue
		var d: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = p as Node2D
	return best


func _try_attack(target: Node2D) -> void:
	var d: float = global_position.distance_to(target.global_position)
	if kind == MathScript.KIND_LASHER:
		if d <= MathScript.LASH_RANGE:
			_start_attack(1, target)
	elif d >= MathScript.SPIT_RANGE_MIN and d <= MathScript.SPIT_RANGE_MAX and _has_line_of_sight(target):
		_start_attack(2, target)


func _start_attack(which: int, target: Node2D) -> void:
	_ws = WS.ATTACKING
	_t = 0.0
	_atk = which
	_fired = false
	_aim = (target.global_position - global_position).normalized()
	_update_facing(_aim)
	_emit_pose(MathScript.POSE_LASH if which == 1 else MathScript.POSE_SPIT)


func _attack_tick(target: Node2D) -> void:
	if _atk == 1:
		if not _fired and _t >= MathScript.LASH_STRIKE_AT:
			_fired = true
			_lash_strike()
		if _t >= MathScript.LASH_ANIM:
			_end_attack(MathScript.LASH_COOLDOWN)
	else:
		if not _fired and _t >= MathScript.SPIT_FIRE_AT:
			_fired = true
			_fire_acid(target)
		if _t >= MathScript.SPIT_ANIM:
			_end_attack(randf_range(MathScript.SPIT_COOLDOWN_MIN, MathScript.SPIT_COOLDOWN_MAX))


func _end_attack(cooldown: float) -> void:
	_ws = WS.ACTIVE
	_t = 0.0
	_cd = cooldown
	_emit_pose(MathScript.POSE_NONE)


## SAVURMA: isabet anında menzildeki (ve savurma yönünün önündeki) her oyuncu BİR kez vurulur.
func _lash_strike() -> void:
	emit_ability_vfx("worm_strike", {"pos": global_position + _aim * 64.0, "dir": _aim, "power": 0.2})
	for p: Node in EnemyAbilitiesScript.damageable_players(get_tree()):
		if not (p is Node2D) or p.get("is_indoors") == true or p.get("is_in_merchant_zone") == true or p.get("is_downed") == true:
			continue
		if MathScript.lash_hits(global_position, _aim, (p as Node2D).global_position):
			EnemyAbilitiesScript.deal_special_damage(p, MathScript.LASH_DAMAGE, self, "worm")


## TÜKÜRME: ağızdan hedefin o anki konumuna doğru düz bir asit damlası (kaçınılabilir: hızı 240 px/sn).
func _fire_acid(target: Node2D) -> void:
	var muzzle: Vector2 = global_position + Vector2(0.0, -34.0) + _aim * 26.0
	var dir: Vector2 = (target.global_position - muzzle).normalized() if is_instance_valid(target) else _aim
	var data: Dictionary = {"dir": dir, "speed": MathScript.ACID_SPEED, "range": MathScript.ACID_RANGE, "damage": MathScript.ACID_DAMAGE}
	EnemyAbilitiesScript.spawn_synced_world_fx(get_tree(), "worm_acid", muzzle, data, self)


# ---------------------------------------------------------------------------------------------------- geri dönüş / ölüm
func _begin_retreat() -> void:
	if _ws == WS.RETREATING or is_dead:
		return
	_ws = WS.RETREATING
	_t = 0.0
	if is_instance_valid(boss) and boss.has_method("on_limb_gone"):
		boss.on_limb_gone(self)
	_emit_pose(MathScript.POSE_HIDE)


## Hasar: önce uzvun kendi eşiğine yazılır (base), uzvun YEDİĞİ miktar bossun havuzundan düşer; retreat kaderli uzuv eşiğinin RETREAT_FRACTION'ında geri döner.
func _apply_damage(amount: float, is_crit: bool, shield_pen_percent: float) -> void:
	if _ws == WS.RETREATING or is_dead:
		return ## gömülürken dokunulmaz
	var before: float = health
	super._apply_damage(amount, is_crit, shield_pen_percent)
	var dealt: float = clampf(before - health, 0.0, before)
	if dealt > 0.0 and is_instance_valid(boss) and boss.has_method("absorb_limb_damage"):
		boss.absorb_limb_damage(dealt, last_attacker_peer_id)
	if not is_dead and fate == MathScript.FATE_RETREAT and health <= max_health * (1.0 - MathScript.RETREAT_FRACTION):
		_begin_retreat()


## Parçalanma: ödülsüz ölüm (drop yok, öldürme sayılmaz) + toz + ses. Her peer'de çalışır (host'ta hasardan, istemcide death_state RPC'sinden).
func die() -> void:
	if is_dead:
		return
	if is_inside_tree():
		SoundScript.play(get_tree(), &"burst", global_position)
		MinotaurDustScript.burst(get_tree(), global_position + Vector2(0.0, -20.0), Vector2.UP, 0.35)
	_broadcast_death_state()
	if is_instance_valid(boss) and boss.has_method("on_limb_gone"):
		boss.on_limb_gone(self)
	_warn_t = 0.0
	dismiss_without_reward()


# ---------------------------------------------------------------------------------------------------- görsel pozlar (her peer)
func _emit_pose(pose: int) -> void:
	emit_ability_vfx("worm_pose", {"pose": pose})


func on_ability_vfx(vfx_kind: String, data: Dictionary) -> void:
	match vfx_kind:
		"worm_setup":
			_apply_worm_setup(int(data.get("kind", 0)))
		"worm_pose":
			_apply_worm_pose(int(data.get("pose", 0)))
		"worm_strike":
			MinotaurDustScript.burst(get_tree() if is_inside_tree() else null, Vector2(data.get("pos", global_position)),
					Vector2(data.get("dir", Vector2.UP)), float(data.get("power", 0.2)))
		_:
			super.on_ability_vfx(vfx_kind, data)


func _pose_texture(pose: int) -> Texture2D:
	match pose:
		MathScript.POSE_EMERGE:
			return emerge_texture
		MathScript.POSE_LASH:
			return lash_texture
		MathScript.POSE_SPIT:
			return spit_texture
		MathScript.POSE_HIDE:
			return hide_texture
	return null


func _apply_worm_pose(pose: int) -> void:
	if is_dead:
		return
	_pose_override = pose
	if pose == MathScript.POSE_NONE:
		_warn_t = 0.0
		_restore_tint()
		if _state == State.ATTACK:
			_enter_state(State.WALK)
		return
	var tex: Texture2D = _pose_texture(pose)
	_enter_state(State.ATTACK, 0.0) ## süre 0: poz değişene kadar son karede kalır
	if frame_sprite != null and tex != null:
		frame_sprite.texture = tex
		frame_sprite.hframes = maxi(int(tex.get_width() / float(cell_size)), 1)
		frame_sprite.vframes = 4
	_ew_wake()
	if not is_inside_tree():
		return
	match pose:
		MathScript.POSE_EMERGE:
			SoundScript.play(get_tree(), &"emerge", global_position)
		MathScript.POSE_LASH:
			_warn_t = MathScript.LASH_STRIKE_AT
			SoundScript.play(get_tree(), &"hiss", global_position)
		MathScript.POSE_SPIT:
			SoundScript.play(get_tree(), &"spit", global_position)
		MathScript.POSE_HIDE:
			_retreating_visual = true
			set_meta(&"untargetable", true) ## gömülürken silahlar hedeflemesin (her peer'de)
			SoundScript.play(get_tree(), &"emerge", global_position)
			get_tree().create_timer(MathScript.HIDE_TIME + 0.2).timeout.connect(_free_after_hide)


func _free_after_hide() -> void:
	if is_instance_valid(self) and not is_dead:
		queue_free()


## Savurma uyarısı: vuruş anına kadar kırmızıya nabız atar.
func _process(delta: float) -> void:
	if _warn_t > 0.0:
		_warn_t = maxf(0.0, _warn_t - delta)
		if frame_sprite != null:
			var k: float = 1.0 - _warn_t / MathScript.LASH_STRIKE_AT
			var pulse: float = 0.5 + 0.5 * sin(k * 22.0)
			frame_sprite.self_modulate = _base_tint.lerp(Color(1.0, 0.35, 0.3), clampf(0.35 + 0.55 * pulse * k, 0.0, 1.0))
		if _warn_t <= 0.0:
			_restore_tint()


func _restore_tint() -> void:
	if frame_sprite != null:
		frame_sprite.self_modulate = _base_tint
