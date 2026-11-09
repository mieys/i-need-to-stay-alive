extends CharacterBody2D

## VURULABİLEN GÖREV HEDEFİ (madde 496, 2026-11-08): Yuvaları Kapat'ın yuvaları, Ritüeli Boz'un kristalleri, Kaçan Hazine'nin altın slime'ı.
## "Kopyanı Öldür" kopyasının (mission_player_copy.gd) hedef sözleşmesi aynen: "enemies" + "mission_copies" grubu (C++'ta kayıtlı olmayan
## vurulabilir hedef - EnemyQuery.candidates / silah en yakın hedef / sis / yaratık gövde itişi / derinlik / minimap aynı yoldan görür; ayrıca
## weapon_target_priority.gd: menzildeki görev hedefine silahlar odaklanır), yaratıkla AYNI take_damage / apply_* imzaları (silah özellikleri,
## yetenekler, eşyalar hiçbir şey bilmeden vurur), collision_layer 4.
## AĞ: SADECE host simüle eder (can/kalkan/ölüm, hareket eden hedefte hareket). İstemcide aynı sınıf kozmetik kurulur (simulated = false):
##  - istemcinin vuruşu host'a gider (request_world_event_target_damage), vuran tarafın işleri (hasar sayısı, maç istatistiği, balans, can çalma)
##    vuranın makinesinde yapılır - kopyayla aynı;
##  - host durum yayını (broadcast_world_event_target_state, güvenilmez): değişince en sık STATE_INTERVAL'da bir + her STATE_HEARTBEAT'te bir
##    (kayıp paketler/geri katılan için), hareket edende sürekli; ölüm ayrı GÜVENİLİR yayın (broadcast_world_event_target_dead).
## Ölüm/yok olma görseli `_on_death_fx` iki yerde de (host + istemci) çağrılır (CLAUDE.md "iki yer" kuralı).
## Alt sınıflar: `_build_visual()` (görsel), `_host_tick(delta)` (host'ta kare işi; hareket), `_on_death_fx()`, `_body_radius`, `bar_offset`.

signal died(target: Node)

const BalanceLogScript := preload("res://scripts/balance_log.gd")
const DamageNumbersScript := preload("res://scripts/damage_numbers.gd")
const OverheadBarScript := preload("res://scripts/overhead_bar.gd")

const STATE_INTERVAL := 0.15
const STATE_HEARTBEAT := 1.0
const ELEMENT_DOT_TICK := 1.0
const BLEED_FOREVER := 9999.0
const DMG_MAX_LIVE := 5
## Kalkanın bir isabetten emdiği pay (kopya / ağaç ile aynı kural): %80 kalkana, %20 doğrudan cana.
const SHIELD_ABSORB_RATIO := 0.8
const NET_SMOOTHING := 12.0
const NET_SNAP_DISTANCE := 200.0

var mission_id: int = 0
var target_index: int = 0
var is_dead: bool = false
var is_boss: bool = false ## silah özellikleri "boss değilse it/sersemlet" kuralına bakar (sabit hedefi itmek zaten bir şey yapmaz)
var health: float = 100.0
var max_health: float = 100.0
var shield: float = 0.0
var max_shield: float = 0.0
var damage_bonus: float = 0.0 ## kopyayla aynı alan (okuyan kod varsa)
var block_radius: float = 0.0 ## > 0: "move_blockers" sözleşmesi (player.gd _block_movement_into_blockers) - oyuncu içinden geçemez
var bar_offset: float = -30.0
var dmg_spawn_offset: Vector2 = Vector2(0, -36)
var _body_radius: float = 16.0 ## enemy_world_bridge.gd _build_extra_bodies okur (yaratıklar içine girmesin)
var _is_host_simulated: bool = true
var _overhead_bar: Node2D = null
var _state_acc: float = 0.0
var _heartbeat_acc: float = 0.0
var _state_dirty: bool = true
var _moving: bool = false ## alt sınıf (hareket eden hedef) true yapar: durum her STATE_INTERVAL'da gider
var _net_pos: Vector2 = Vector2.ZERO
var _has_net_pos: bool = false
var _dmg_ids: Array[int] = []
## Element / durum (kopyanın sade sistemi: yanma / zehir / kanama saniyede bir hasar; sersem / donma / yavaşlama hareket edende işler).
var _dots: Dictionary = {}
var _dot_timer: float = ELEMENT_DOT_TICK
var _stun_until_msec: int = 0
var _frozen_until_msec: int = 0
var _slow_pct: float = 0.0
var _slow_until_msec: int = 0
var mark_stacks: int = 0 ## enemy.gd ile aynı ad: element_reactions.gd doğrudan okur
var _mark_until_msec: int = 0


## add_child'dan SONRA çağrılır (kopyayla aynı sıra): alt sınıf görseli _ready'de kurar, setup değerleri yazar.
func setup(mid: int, idx: int, p_max_health: float, p_max_shield: float, simulated: bool) -> void:
	mission_id = mid
	target_index = idx
	_is_host_simulated = simulated
	max_health = maxf(1.0, p_max_health)
	health = max_health
	max_shield = maxf(0.0, p_max_shield)
	shield = max_shield
	_refresh_bar()


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("mission_copies") ## bkz. dosya başı: C++ dışı vurulabilir görev hedefi grubu (adı kopyadan kaldı)
	add_to_group("mission_targets")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _body_radius
	shape.shape = circle
	add_child(shape)
	_build_visual()
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(OverheadBarScript)
	add_child(_overhead_bar)
	_overhead_bar.visible = true
	_overhead_bar.call("set_offset", bar_offset)
	_refresh_bar()
	if block_radius > 0.0:
		add_to_group("move_blockers")
	NetworkManager.world_event_target_state.connect(_on_net_state)
	NetworkManager.world_event_target_dead.connect(_on_net_dead)
	NetworkManager.world_event_target_damage_requested.connect(_on_remote_damage)


## Alt sınıflar ezer.
func _build_visual() -> void:
	pass


func _host_tick(_delta: float) -> void:
	pass


func _on_death_fx() -> void:
	pass


func is_host_simulated() -> bool:
	return _is_host_simulated


func block_center() -> Vector2:
	return global_position


func get_overhead_bar_offset() -> float:
	return bar_offset


func _refresh_bar() -> void:
	if _overhead_bar:
		_overhead_bar.call("set_health", health, max_health)
		_overhead_bar.call("set_shield", shield, max_shield)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_process_dots(delta)
	if not _is_host_simulated:
		if _moving and _has_net_pos:
			if global_position.distance_to(_net_pos) > NET_SNAP_DISTANCE:
				global_position = _net_pos
			else:
				global_position = global_position.lerp(_net_pos, 1.0 - exp(-NET_SMOOTHING * delta))
		return
	_host_tick(delta)
	if is_dead:
		return
	_sync_state(delta)


func _sync_state(delta: float) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	_state_acc += delta
	_heartbeat_acc += delta
	var due: bool = (_state_dirty or _moving) and _state_acc >= STATE_INTERVAL
	if not due and _heartbeat_acc < STATE_HEARTBEAT:
		return
	_state_acc = 0.0
	_heartbeat_acc = 0.0
	_state_dirty = false
	NetworkManager.broadcast_world_event_target_state.rpc(mission_id, target_index, global_position,
			health / maxf(max_health, 1.0), (shield / max_shield) if max_shield > 0.0 else 0.0)


## Enemy.gd ile AYNI imza: gerçek oyuncu silahları/yetenekleri bunu çağırır. Vuran tarafın işleri bu makinenin yerel oyuncusu için burada,
## hasarın kendisi host'ta (_apply_hit); istemcideki kozmetik hedef miktarı host'a iletir.
func take_damage(amount: float, is_crit: bool = false, _shield_pen_percent: float = 0.0, is_area: bool = false) -> void:
	var bl_src: String = BalanceLogScript.take_src() ## balans etiketi erken dönüşte de silinsin
	if is_dead or amount <= 0.0:
		return
	_credit_local_dealer(amount, is_crit, is_area, bl_src)
	if not _is_host_simulated:
		if NetworkManager.is_multiplayer_active:
			NetworkManager.request_world_event_target_damage.rpc_id(NetworkManager._host_peer_id(), mission_id, target_index, amount)
		return
	_apply_hit(amount)


## Host'ta başka bir oyuncunun vuruşu (vuranın işleri onun makinesinde yapıldı).
func take_damage_host(amount: float, _is_crit: bool = false, _shield_pen_percent: float = 0.0, _attacker_id: int = 0) -> void:
	if _is_host_simulated:
		_apply_hit(amount)


func _apply_hit(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var dmg: float = amount
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg * SHIELD_ABSORB_RATIO)
		shield -= absorbed
		dmg -= absorbed
	health = maxf(0.0, health - dmg)
	_state_dirty = true
	_refresh_bar()
	_on_hit_host(amount)
	if health <= 0.0:
		_die()


## Host'ta her isabetten sonra (alt sınıf: Kaçan Hazine altın düşürür).
func _on_hit_host(_amount: float) -> void:
	pass


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if _is_host_simulated and NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_target_dead.rpc(mission_id, target_index, false)
	died.emit(self)
	_on_death_fx()
	queue_free()


## Görev bitince ölümsüz kaldırma (başarısızlık / süre): görsel söner, ödül/ölüm sayılmaz. Host çağırırsa istemcilerdeki kopya da söner
## (görev tamamlandı yayını da main.gd'de görselleri temizler; bu, sönme görselinin iki yerde aynı olması için).
func vanish() -> void:
	if is_dead:
		return
	if _is_host_simulated and NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_world_event_target_dead.rpc(mission_id, target_index, true)
	is_dead = true
	_on_vanish_fx()
	queue_free()


func _on_vanish_fx() -> void:
	pass


## Yaşayan SIRADAN yaratıkların (boss / minyon / bekçi / görev hedefi değil) ortalama azami canı - görev hedeflerinin canı bunun katı
## (kademeye ve oyuncu sayısına kendiliğinden uyar; mission_tree.gd _calibrate ile aynı süzgeç). Ölçülecek yaratık yoksa 0.
static func calibrate_hp(tree: SceneTree) -> float:
	if tree == null:
		return 0.0
	var hp_sum: float = 0.0
	var n: int = 0
	for e: Node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or e.get("is_boss") == true or e.is_in_group("summons") \
				or e.is_in_group("guards") or e.is_in_group("mission_copies"):
			continue
		var mh: float = float(e.get("max_health")) if e.get("max_health") != null else 0.0
		if mh <= 0.0:
			continue
		hp_sum += mh
		n += 1
		if n >= 60:
			break
	return hp_sum / float(n) if n > 0 else 0.0


const BURST_FRAMES := preload("res://assets/fx/enchant/crystal_burst_frames.tres")


## Ölüm / kırılma patlaması (kristal kırılma halkası, renk alt sınıftan): sahneye bağlı tek seferlik sprite, bitince kendini siler.
static func spawn_burst(tree: SceneTree, pos: Vector2, tint: Color, scale_k: float = 1.0) -> void:
	if tree == null or tree.current_scene == null:
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = BURST_FRAMES
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.modulate = tint
	a.scale = Vector2.ONE * scale_k
	a.z_index = 5
	a.position = pos
	tree.current_scene.add_child(a)
	a.animation_finished.connect(a.queue_free)
	a.play(&"play")


## Sönerek kaybolan kalıntı (çökmüş yuva vb.): hold sn bekler, fade sn'de saydamlaşır.
static func spawn_fading_sprite(tree: SceneTree, pos: Vector2, tex: Texture2D, hframes: int, frame: int, offset: Vector2, hold: float, fade: float) -> void:
	if tree == null or tree.current_scene == null or tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	s.frame = frame
	s.offset = offset
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	tree.current_scene.add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(s, "modulate:a", 0.0, fade)
	tw.tween_callback(s.queue_free)


func _credit_local_dealer(shown: float, is_crit: bool, is_area: bool, bl_src: String) -> void:
	if shown <= 0.0:
		return
	var dealer: Node = get_tree().get_first_node_in_group("player")
	if dealer:
		if "match_damage_dealt" in dealer:
			dealer.match_damage_dealt += shown
			BalanceLogScript.on_hit(bl_src, shown, is_crit)
		if dealer.has_method("on_dealer_hit"):
			dealer.on_dealer_hit(shown, is_area)
	if not UISound.damage_number_allowed(is_crit): ## Ayarlar > Hasar Sayıları (madde 406)
		return
	var dn = DamageNumbersScript.get_instance(get_tree())
	if dn == null:
		return
	var kind: int = DamageNumbersScript.KIND_CRIT if is_crit else DamageNumbersScript.KIND_HIT
	dn.spawn_hit(self, global_position + dmg_spawn_offset, int(round(shown)), kind, _dmg_ids, DMG_MAX_LIVE, max_health)


## ------------------------------------------------------------------ AĞ
func _on_remote_damage(mid: int, idx: int, amount: float) -> void:
	if not _is_host_simulated or mid != mission_id or idx != target_index:
		return
	_apply_hit(amount)


func _on_net_state(mid: int, idx: int, pos: Vector2, health_ratio: float, shield_ratio: float) -> void:
	if _is_host_simulated or is_dead or mid != mission_id or idx != target_index:
		return
	if not _has_net_pos or (not _moving and global_position.distance_to(pos) > 0.5):
		global_position = pos
	_net_pos = pos
	_has_net_pos = true
	health = max_health * clampf(health_ratio, 0.0, 1.0)
	shield = max_shield * clampf(shield_ratio, 0.0, 1.0)
	_refresh_bar()


func _on_net_dead(mid: int, idx: int, vanished: bool) -> void:
	if _is_host_simulated or is_dead or mid != mission_id or idx != target_index:
		return
	if vanished:
		vanish()
		return
	is_dead = true
	died.emit(self)
	_on_death_fx()
	queue_free()


## ------------------------------------------------------------------ ELEMENT / YARATIK API UYUMU (mission_player_copy.gd ile aynı imzalar)
func apply_element(kind: String, p: Dictionary) -> void:
	if is_dead:
		return
	var now: int = Time.get_ticks_msec()
	match kind:
		"burn":
			_add_dot("burn", float(p.get("tick", 1.0)), 1, maxi(1, int(p.get("max_stacks", 1))), float(p.get("dur", 3.0)), now)
		"poison":
			_add_dot("poison", float(p.get("dps", 1.0)), clampi(int(p.get("stacks", 1)), 1, 50), 50, float(p.get("dur", 10.0)), now)
		"bleed":
			_add_dot("bleed", float(p.get("tick", 1.0)), maxi(1, int(p.get("stacks", 1))), maxi(1, int(p.get("cap", 10))), BLEED_FOREVER, now)
		"freeze":
			_frozen_until_msec = maxi(_frozen_until_msec, now + int(float(p.get("dur", 1.5)) * 1000.0))
		"stun":
			_stun_until_msec = maxi(_stun_until_msec, now + int(float(p.get("dur", 0.5)) * 1000.0))
		"slow":
			_slow_pct = clampf(float(p.get("pct", 0.3)), 0.0, 0.9)
			_slow_until_msec = now + int(float(p.get("dur", 1.5)) * 1000.0)


func _add_dot(kind: String, per: float, add: int, cap: int, dur: float, now: int) -> void:
	var d: Dictionary = _dots.get(kind, {"per": per, "stacks": 0, "until": 0})
	if int(d["until"]) < now:
		d["stacks"] = 0
	d["per"] = maxf(float(d["per"]), per)
	d["stacks"] = mini(cap, int(d["stacks"]) + add)
	d["until"] = maxi(int(d["until"]), now + int(dur * 1000.0))
	_dots[kind] = d


func _process_dots(delta: float) -> void:
	if _dots.is_empty():
		return
	_dot_timer -= delta
	if _dot_timer > 0.0:
		return
	_dot_timer = ELEMENT_DOT_TICK
	var now: int = Time.get_ticks_msec()
	var total: float = 0.0
	for kind in _dots.keys():
		var d: Dictionary = _dots[kind]
		if int(d["until"]) < now:
			_dots.erase(kind)
			continue
		total += float(d["per"]) * int(d["stacks"])
	if total > 0.0:
		take_damage(total, false, 0.0, true)


func is_disabled_now() -> bool:
	var now: int = Time.get_ticks_msec()
	return now < _stun_until_msec or now < _frozen_until_msec


func slow_factor() -> float:
	return (1.0 - _slow_pct) if Time.get_ticks_msec() < _slow_until_msec else 1.0


func is_burning() -> bool:
	return _dots.has("burn") and int(_dots["burn"]["until"]) >= Time.get_ticks_msec()


func is_poisoned() -> bool:
	return _dots.has("poison") and int(_dots["poison"]["until"]) >= Time.get_ticks_msec()


func is_frozen_now() -> bool:
	return Time.get_ticks_msec() < _frozen_until_msec


func is_shocked() -> bool:
	return false


func apply_burn(tick_damage: float, duration: float) -> void:
	apply_element("burn", {"tick": tick_damage, "dur": duration})


func apply_poison(dps_per_stack: float, _max_stacks: float, duration: float) -> void:
	apply_element("poison", {"dps": dps_per_stack, "dur": duration, "stacks": 1})


func apply_bee_poison(tick_damage_per_stack: float) -> void:
	apply_element("poison", {"dps": tick_damage_per_stack, "dur": 5.0, "stacks": 1})


func apply_bleed(tick_damage_per_stack: float, stacks_to_add: int, max_stacks: int) -> void:
	apply_element("bleed", {"tick": tick_damage_per_stack, "stacks": stacks_to_add, "cap": max_stacks})


func apply_slow(percent: float, duration: float, _allow_boss: bool = false) -> void:
	apply_element("slow", {"pct": minf(percent, 0.8), "dur": duration})


func apply_frost_slow(percent: float, duration: float) -> void:
	apply_element("slow", {"pct": minf(percent, 0.8), "dur": duration})


func apply_chill(_stacks_to_add: int) -> void:
	apply_element("slow", {"pct": 0.15, "dur": Enemy.CHILL_DURATION})


func apply_stun(duration: float) -> void:
	apply_element("stun", {"dur": duration})


func apply_freeze_full(duration: float, _allow_boss: bool = false) -> void:
	apply_element("freeze", {"dur": duration})


func apply_madness(_duration: float) -> void:
	pass


func apply_root(duration: float, _style: int = 0) -> void:
	apply_element("slow", {"pct": 0.9, "dur": duration})


func apply_skill_push(_dir: Vector2, _distance: float, _ult: bool = false) -> void:
	pass


func apply_knockback_distance(_dir: Vector2, _distance: float) -> void:
	pass


func apply_knockback_force(_dir: Vector2, _force: float) -> void:
	pass


func apply_element_host(kind: String, p: Dictionary, _attacker_peer: int) -> void:
	apply_element(kind, p)


func apply_fear(_source_pos: Vector2, _duration: float = 0.0) -> void:
	pass


func apply_fear_wander(_duration: float, _affect_boss: bool = false) -> void:
	pass


func apply_taunt(_duration: float, _taunter: Node2D = null) -> void:
	pass


func set_ability_invisible(_on: bool) -> void:
	pass


func apply_mark_stack(max_stacks: int) -> void:
	if is_dead:
		return
	if Time.get_ticks_msec() > _mark_until_msec:
		mark_stacks = 0
	mark_stacks = mini(mark_stacks + Enemy.MARK_STACKS_PER_HIT, max_stacks)
	_mark_until_msec = Time.get_ticks_msec() + int(Enemy.MARK_DURATION * 1000.0)


func get_mark_damage_mult() -> float:
	if Time.get_ticks_msec() > _mark_until_msec:
		mark_stacks = 0
	return 1.0 + mark_stacks * Enemy.MARK_PERCENT_PER_STACK


## Şaman totemi içindeki hedefe silah vuruşunda yanma (enemy.gd / kopya ile aynı kural).
func try_shaman_weapon_burn() -> bool:
	var dealer: Node = get_tree().get_first_node_in_group("player")
	if not (dealer and "damage_bonus" in dealer and dealer is Node2D):
		return false
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if not is_instance_valid(totem) or not (totem is Node2D):
			continue
		var totem_r: float = float(totem.get("totem_radius")) if "totem_radius" in totem else 0.0
		if totem_r > 0.0 and (totem as Node2D).global_position.distance_to((dealer as Node2D).global_position) <= totem_r:
			apply_burn(float(dealer.damage_bonus) * 0.10, 3.0)
			return true
	return false
