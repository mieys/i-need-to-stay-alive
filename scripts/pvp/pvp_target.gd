extends "res://scripts/mission_target.gd"

## RAKİP OYUNCUNUN VURULABİLİR VEKİLİ (PvPvE Aşama 2, madde 615; plan docs/pvp/PLAN.md 4.5). Rakip takımdaki her RemotePlayer kuklası için bu
## makinede bir tane (pvp_targets.gd kurar). Hedef sözleşmesi görev hedefleriyle (mission_target.gd) AYNI: "enemies" + "mission_copies" grubunda,
## yaratıkla aynı take_damage / apply_* imzaları, collision_layer 4 - silahlar (en yakın hedef, mermi çarpışması, yakın dövüş alanı), yetenekler,
## efsunlar, alan hasarları, evcil / çağrılanlar hiçbir şey bilmeden kuklaya vurur. Farkı: can / ölüm burada DEĞİL, kurbanın makinesinde
## (hasar `PvpNet.send_hit` ile kurbana gider, kurban doğrular ve uygular); vekil yalnız kuklanın konumunu izler ve vuruşu iletir.
## Görünmez (kukla zaten çizili), minimapte işaret yok (kukla noktası var), kendi can çubuğu yok (kuklanın çubuğu var).
## Hedeflenebilir değil (meta "untargetable": silahlar bakmaz, mermi / alan hasarı `_send` içinde düşer): hazırlık süresi, kukla ölü / yerde / ruh
## hâlinde / görünmez / ev içinde, kukla ya da ben takım üssündeyiz (üste PvP yok).

const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const PvpRulesScript := preload("res://scripts/pvp/pvp_rules.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const HideBrushScript := preload("res://scripts/hide_brush.gd")

const BODY_RADIUS := 14.0

var peer: int = 0
var rival: Node2D = null


## add_child'dan ÖNCE.
func bind(p_rival: Node2D, p_peer: int) -> void:
	rival = p_rival
	peer = p_peer
	name = "PvpTarget_%d" % p_peer
	_body_radius = BODY_RADIUS
	dmg_spawn_offset = Vector2(0, -34)
	bar_offset = -30.0
	_is_host_simulated = false


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("mission_copies") ## aday sorgusu (EnemyQuery), silah en yakın hedef, gövde itişi, doğurucu tavanı muafiyeti bu grubu okur
	add_to_group("pvp_targets")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	visible = false ## kuklanın kendi çizimi var; derinlik taraması da görünmez düğümü atlar
	set_meta(&"hide_on_minimap", true) ## minimapte kukla noktası zaten var
	_sync_from_rival()


func _physics_process(delta: float) -> void:
	if rival == null or not is_instance_valid(rival):
		queue_free()
		return
	_sync_from_rival()
	_apply_fog_to_rival()
	_process_dots(delta)


func _sync_from_rival() -> void:
	if rival == null or not is_instance_valid(rival):
		return
	global_position = rival.global_position
	var mh: Variant = rival.get("max_health")
	max_health = maxf(1.0, float(mh) if mh != null else 100.0)
	var h: Variant = rival.get("health")
	health = clampf(float(h) if h != null else max_health, 0.0, max_health)
	is_dead = rival.get("is_dead") == true or rival.get("is_downed") == true
	if _hittable():
		if has_meta(&"untargetable"):
			remove_meta(&"untargetable")
	elif not has_meta(&"untargetable"):
		set_meta(&"untargetable", true)


## Görüş TAKIM görüşü (plan K7): rakip kukla benim takımımın görüşünün dışındaysa çizilmez (sis ağacı gizlemeyi kendisi yapmaz - kukla "enemies" değil).
## Yalnız BU sınıfın gizlediği kuklaya dokunur (meta): başka sistemin (ev içi, görünmezlik) gizlediği kukla açılmaz.
const FOG_HIDDEN_META := &"pvp_fog_hidden"


func _apply_fog_to_rival() -> void:
	if rival == null or not is_instance_valid(rival) or not is_inside_tree():
		return
	var fog: Node = get_tree().get_first_node_in_group("vision_fog")
	var seen: bool = true
	if fog != null and fog.has_method("is_world_pos_visible"):
		seen = bool(fog.call("is_world_pos_visible", global_position))
	if seen and _brush_concealed():
		seen = false ## çalıda saklı rakip: algı halkası içindeki biri yoksa görünmez (madde 617)
	if not seen and rival.visible:
		rival.visible = false
		rival.set_meta(FOG_HIDDEN_META, true)
	elif seen and rival.has_meta(FOG_HIDDEN_META):
		rival.remove_meta(FOG_HIDDEN_META)
		rival.visible = true


func _exit_tree() -> void:
	if rival != null and is_instance_valid(rival) and rival.has_meta(FOG_HIDDEN_META):
		rival.remove_meta(FOG_HIDDEN_META)
		rival.visible = true


## SAKLANMA ÇALILIĞI rakibe karşı da çalışır (plan K7): çalıda SAKLI (host durumu kukladaki `brush_state`) rakip, benim ya da takım arkadaşımın
## algı halkası (`HideBrush.RING_RADIUS`, yaratıkların gördüğü aynı yarıçap) içindeyse görünür ve vurulur; değilse görünmez ve vurulamaz.
func _brush_concealed() -> bool:
	if rival == null or not is_instance_valid(rival) or not is_inside_tree():
		return false
	var brush_state: Variant = rival.get("brush_state")
	if brush_state == null or int(brush_state) != HideBrushScript.STATE_HIDDEN:
		return false
	var feet: Vector2 = rival.global_position
	var tree: SceneTree = get_tree()
	var me: Node2D = tree.get_first_node_in_group("player") as Node2D
	if me != null and me.global_position.distance_to(feet) <= HideBrushScript.RING_RADIUS:
		return false
	for n: Node in tree.get_nodes_in_group("remote_allies"):
		if n is Node2D and is_instance_valid(n) and (n as Node2D).global_position.distance_to(feet) <= HideBrushScript.RING_RADIUS:
			return false
	return true


## Bu an rakibe hasar / kontrol gidebilir mi (vuran tarafın ön süzgeci; kurban aynısını kendi tarafında yeniden doğrular).
func _hittable() -> bool:
	if peer <= 0 or rival == null or not is_instance_valid(rival):
		return false
	if not PvpRulesScript.fighting():
		return false
	if is_dead or rival.get("in_limbo") == true or rival.get("is_indoors") == true or rival.get("is_invisible") == true:
		return false
	if _brush_concealed():
		return false
	if BaseZonesScript.shelters(global_position):
		return false
	var me: Node2D = get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if me != null and (BaseZonesScript.shelters(me.global_position) or me.get("is_dead") == true):
		return false
	return true


## Yaratıkla AYNI imza. Vuran tarafın işleri (hasar sayısı, maç istatistiği, balans) bu makinede, hasarın kendisi kurbanda.
func take_damage(amount: float, is_crit: bool = false, _shield_pen_percent: float = 0.0, is_area: bool = false) -> void:
	var bl_src: String = BalanceLogScript.take_src() ## balans etiketi erken dönüşte de silinsin
	_send(amount, is_crit, is_area, bl_src, false)


func _send(amount: float, is_crit: bool, is_area: bool, bl_src: String, is_dot: bool) -> void:
	if amount <= 0.0 or not _hittable():
		return
	var out: float = PvpRulesScript.outgoing(amount, bl_src, is_area, is_dot)
	if out <= 0.0:
		return
	_credit_local_dealer(out, is_crit, is_area, bl_src)
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.send_hit(peer, out, is_crit)


## Süreli hasar (yanma / zehir / kanama): saniyelik toplam kurbana DOT çarpanıyla gider (mission_target.gd'nin sürümü take_damage'e düşüp alan sayardı).
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
		_send(total, false, false, "", true)


## Süreli hasar kayıtları vekilde; sersemletme / dondurma / yavaşlatma / kök / korku / itme kurbana gider (kurban süreyi yarıya indirir + azalan etki uygular).
func apply_element(kind: String, p: Dictionary) -> void:
	if is_dead:
		return
	match kind:
		"stun":
			_send_cc("stun", float(p.get("dur", 0.5)))
		"freeze":
			_send_cc("stun", float(p.get("dur", 1.5)))
		"slow": ## yavaşlatma / buz yavaşı / kök (kök = %90 yavaş, kurban %60'a kısar)
			_send_cc("slow", float(p.get("dur", 1.5)), Vector2.ZERO, float(p.get("pct", 0.3)))
		"burn", "poison", "bleed":
			super.apply_element(kind, p)


func apply_knockback_force(dir: Vector2, force: float) -> void:
	_send_cc("knock", 0.0, dir, force)


## Mesafeli itiş (Melek itmesi, yetenek savurmaları): oyuncudaki sönümle (800 / sn^2) bu mesafeyi kat edecek hıza çevrilir (v^2 = 2 a d); kurban yarıya indirir.
func apply_skill_push(dir: Vector2, distance: float, _ult: bool = false) -> void:
	apply_knockback_distance(dir, distance)


func apply_knockback_distance(dir: Vector2, distance: float) -> void:
	if distance <= 0.0:
		return
	_send_cc("knock", 0.0, dir, minf(sqrt(2.0 * 800.0 * distance), 400.0))


## Korku: oyuncu kontrolsüz kaçırılmaz; yavaşlatma olarak işler (kurban süreyi yarıya indirir).
func apply_fear(_source_pos: Vector2, duration: float = 0.0) -> void:
	_send_cc("slow", maxf(duration, 1.0), Vector2.ZERO, 0.5)


func apply_fear_wander(duration: float, _affect_boss: bool = false) -> void:
	_send_cc("slow", maxf(duration, 1.0), Vector2.ZERO, 0.5)


func _send_cc(kind: String, duration: float, dir: Vector2 = Vector2.ZERO, force: float = 0.0) -> void:
	if not _hittable():
		return
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.send_cc(peer, kind, duration, dir, force)


## Host'a hiçbir şey gitmez (görev hedefi ağ kancaları bu sınıfta yok).
func take_damage_host(_amount: float, _is_crit: bool = false, _shield_pen_percent: float = 0.0, _attacker_id: int = 0) -> void:
	pass
