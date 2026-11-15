extends Node

## Yaratık yakın dövüş hasarı saldırı klibinin VURUŞ KARESİNDE iner (madde 571, creature_attack_timing.gd).

const EnemyScript = preload("res://scripts/enemy.gd")
const Timing = preload("res://scripts/creature_attack_timing.gd")
const ZombieScene: PackedScene = preload("res://scenes/creatures/enemy_zombie1.tscn")


class FakeTarget extends Node2D:
	var hits: int = 0
	func take_damage(_amount: float, _src: Node = null) -> void:
		hits += 1


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()


func _spawn(scene: PackedScene) -> Node2D:
	var e: Node2D = scene.instantiate() as Node2D
	add_child(e)
	e.global_position = Vector2(300, 300)
	e.set_physics_process(false)
	return e


func _target_at(pos: Vector2) -> FakeTarget:
	var t := FakeTarget.new()
	add_child(t)
	t.global_position = pos
	return t


## Her yaratık sahnesi tabloda (yedek oran yok), kare klibin içinde; yakın dövüşçüde klip vuruş aralığına sığar,
## vuruş aralıktan önce ve en geç MAX_WINDUP'ta iner.
func test_every_creature_scene_has_a_hit_frame() -> void:
	var dir := DirAccess.open("res://scenes/creatures")
	assert(dir != null)
	var checked: int = 0
	for f: String in dir.get_files():
		if not (f.begins_with("enemy_") and f.ends_with(".tscn")):
			continue
		var path: String = "res://scenes/creatures/" + f
		var e: Node = (load(path) as PackedScene).instantiate()
		var tex: Texture2D = e.get("attack_texture") as Texture2D
		if tex == null:
			e.free()
			continue
		var key: String = f.get_basename()
		var fam: String = key.rstrip("0123456789")
		assert(Timing.HIT_FRAME.has(key) or Timing.HIT_FRAME.has(fam), "%s vuruş karesi tabloda olmalı" % key)
		var cols: int = maxi(int(tex.get_width() / float(int(e.get("cell_size")))), 1)
		var fps: float = float(e.get("sprite_fps"))
		var interval: float = float(e.get("contact_interval"))
		var ranged: bool = bool(e.get("is_ranged"))
		var start: int = preload("res://scripts/lich_soul_flame.gd").FLASH_FRAME if key.begins_with("enemy_lich") else 0
		var hit: int = Timing.hit_frame(path, cols)
		assert(hit >= 0 and hit < cols, "%s: kare %d / %d" % [key, hit, cols])
		var s: float = Timing.attack_speed(cols, fps, hit, start, interval, ranged)
		var delay: float = Timing.hit_delay(hit, start, fps, s)
		assert(delay < interval, "%s: vuruş (%.2f sn) bir sonraki saldırıdan (%.2f sn) önce inmeli" % [key, delay, interval])
		if not ranged and cols > 1:
			assert(float(cols) / (fps * s) <= interval + 0.001 or is_equal_approx(s, Timing.MAX_SPEED),
					"%s: bütün klip vuruş aralığına sığmalı" % key)
			assert(delay <= Timing.MAX_WINDUP + 0.001 or is_equal_approx(s, Timing.MAX_SPEED), "%s: kurulma %.2f sn" % [key, delay])
		e.free()
		checked += 1
	assert(checked >= 50, "yaratık sahneleri taranmalı (%d)" % checked)


func test_family_fallback_and_unknown() -> void:
	assert(Timing.hit_frame("res://scenes/creatures/enemy_iskelet3.tscn", 9) == 4, "aile adı (rakamsız) yedeği")
	assert(Timing.hit_frame("res://scenes/creatures/enemy_slime4.tscn", 10) == 5, "slime sahneleri ayrı ayrı")
	assert(Timing.hit_frame("res://x/enemy_yeni9.tscn", 10) == 4, "tabloda yoksa klibin %40'ı")
	assert(Timing.hit_frame("", 1) == 0)


## Gerçek zombi: saldırı başında hasar YOK, vuruş karesi ekrana geldiğinde VAR; klip o anda vuruş karesinde.
func test_zombie_hits_on_the_hit_frame_not_at_attack_start() -> void:
	_clear_enemies()
	var e: Node2D = _spawn(ZombieScene)
	var hit: int = Timing.hit_frame(ZombieScene.resource_path, int(e.attack_texture.get_width() / float(e.cell_size)))
	assert(e._melee_hit_delay > 0.1 and e._attack_anim_mult >= 1.0, "zombinin kurulması var (%.2f sn)" % e._melee_hit_delay)
	var clip_cols: int = int(e.attack_texture.get_width() / float(e.cell_size))
	assert(float(clip_cols) / (e.sprite_fps * e._attack_anim_mult) <= e.contact_interval + 0.001, "klip vuruş aralığına sığar")
	assert(e._anim_length_for(EnemyScript.State.ATTACK) >= e.contact_interval, "saldırı duruşu bir sonraki vuruşa kadar sürer (arada yürüme pozu yok)")
	var tgt := _target_at(e.global_position)
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	assert(e._state == EnemyScript.State.ATTACK, "saldırı klibi başladı")
	## klip karesi: vuruş gecikmesi kadar ilerletilince vuruş karesinde
	var cols: int = e.frame_sprite.hframes
	var t: float = 0.0
	var dt: float = 1.0 / 240.0
	while t + dt <= e._melee_hit_delay + 0.0001:
		e._advance_frame_sprite(dt)
		t += dt
	e._advance_frame_sprite(0.002)
	assert(e.frame_sprite.frame % cols == hit, "vuruş anında klip vuruş karesinde (%d, beklenen %d)" % [e.frame_sprite.frame % cols, hit])
	e._enter_state(EnemyScript.State.ATTACK, e._anim_length_for(EnemyScript.State.ATTACK)) ## kareyi baştan al (yalnız görsel)
	await get_tree().create_timer(e._melee_hit_delay * 0.5).timeout
	assert(tgt.hits == 0, "saldırı başında hasar inmemeli")
	## ikinci olay kurulma sırasında yeni vuruş başlatmaz
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	await get_tree().create_timer(e._melee_hit_delay * 0.5 + 0.1).timeout
	assert(tgt.hits == 1, "vuruş karesinde tek vuruş inmeli (%d)" % tgt.hits)
	_clear_enemies()
	tgt.queue_free()


## Kurulma sırasında donan / uzaklaşan hedef: vuruş iptal.
func test_windup_cancels_when_frozen_or_target_escapes() -> void:
	_clear_enemies()
	var e: Node2D = _spawn(ZombieScene)
	var tgt := _target_at(e.global_position)
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	e.apply_stun(e._melee_hit_delay + 0.3)
	await get_tree().create_timer(e._melee_hit_delay + 0.1).timeout
	assert(tgt.hits == 0, "kurulmada sersemleyen yaratık vuramaz")
	await get_tree().create_timer(0.35).timeout
	assert(not e.is_frozen, "sersemlik bitti")
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	tgt.global_position = e.global_position + Vector2(200, 0)
	await get_tree().create_timer(e._melee_hit_delay + 0.1).timeout
	assert(tgt.hits == 0, "kurulmada kaçan hedefe vuruş inmez")
	assert(not e._melee_hit_pending, "bekleyen vuruş temizlendi")
	## boşa giden vuruş: saldırı duruşu bırakılır + kısa yeniden deneme (0,75 sn'lik tam aralık beklenmez)
	assert(e._state != EnemyScript.State.ATTACK, "boşa giden vuruş saldırı duruşunu bırakır (yaratık yürüyüp yetişsin)")
	if e._ew_slot >= 0 and e._ew_world != null:
		assert(e._ew_world.get_contact_timer(e._ew_slot) <= EnemyScript.MELEE_RETRY_SECONDS + 0.001, "boşa giden vuruştan sonra kısa yeniden deneme")
	_clear_enemies()
	tgt.queue_free()


## Kurulma sırasında hedef SİLİNİRSE (ağaç görevi bitince ağaç queue_free olur, müttefik ölür) vuruş sessizce iptal olur:
## serbest nesne tipli parametreye geçince "Invalid type in function '_apply_melee_hit' ... (previously freed)" hatası
## oyunu durduruyordu (kullanıcı bildirimi 2026-11-13). Hem köprü yolu (_ew_resolve_hit) hem await yolu (_schedule_melee_hit).
func test_windup_survives_target_freed_mid_hit() -> void:
	_clear_enemies()
	var e: Node2D = _spawn(ZombieScene)
	var tgt := _target_at(e.global_position)
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	assert(e._melee_hit_pending, "vuruş kuruldu")
	tgt.free() ## anında serbest bırak (queue_free'nin ertelemesi olmadan: vuruş saati gelince nesne kesin ölü)
	await get_tree().create_timer(e._melee_hit_delay + 0.1).timeout
	assert(not e._melee_hit_pending, "hedefi silinen kurulu vuruş temizlendi")
	## await yolu: gecikmesiz kurulan vuruş bir kare bekler, bu sürede hedef silinir
	var tgt2 := _target_at(e.global_position)
	e._schedule_melee_hit(0.0, tgt2)
	tgt2.free()
	await get_tree().create_timer(0.2).timeout
	assert(is_instance_valid(e), "yaratık hâlâ ayakta (hata oyunu durdurmadı)")
	## doğrudan vuruş (menzilli temas / kubbe) yolu
	var tgt3 := _target_at(e.global_position)
	tgt3.free()
	e._apply_direct_hit(tgt3, false)
	_clear_enemies()


## Kurulma (windup) sırasında yaratık kilitlenmez ve uyutulmaz (yürüyen oyuncu menzilden çıkıp vuruşu boşa çıkarmasın);
## vuruş inince kilit başlar.
func test_windup_is_not_movement_locked_and_not_dormant() -> void:
	_clear_enemies()
	var e: Node2D = _spawn(ZombieScene)
	var tgt := _target_at(e.global_position)
	e._ew_on_event(EnemyScript.EW_E_MELEE, tgt)
	assert(e._in_melee_windup(), "kurulma sürüyor")
	assert(e._ew_hard_active(), "kurulmada yaratık her karede tiklenir (uyutulamaz)")
	await get_tree().create_timer(e._melee_hit_delay + 0.1).timeout
	assert(tgt.hits == 1, "vuruş indi (%d)" % tgt.hits)
	assert(not e._in_melee_windup(), "vuruş inince kurulma bitti (hareket kilidi başlar)")
	_clear_enemies()
	tgt.queue_free()


## Boss klipleri (uzun vuruş aralığı) hızlanmaz.
func test_boss_clip_speed_unchanged() -> void:
	_clear_enemies()
	var e: Node2D = _spawn(preload("res://scenes/creatures/enemy_minotaur1.tscn"))
	assert(is_equal_approx(e._attack_anim_mult, 1.0), "Minotaur klibi aynı hızda")
	assert(e._melee_hit_delay > 0.2 and e._melee_hit_delay < e.contact_interval, "Minotaur vuruşu boynuz karesinde")
	_clear_enemies()
