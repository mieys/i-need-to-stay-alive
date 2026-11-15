extends Node

## PvPvE Aşama 2 (madde 615, docs/pvp/PLAN.md): rakip oyuncuya hasar. Kurallar (pvp_rules.gd), üs yarıçapı, rakip vekili (pvp_target.gd +
## pvp_targets.gd), kurban doğrulaması (pvp_net.gd victim_check). Co-op güvencesi: mod kapalıyken hiçbir vekil kurulmaz, hiçbir şey değişmez.

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const PvpRulesScript := preload("res://scripts/pvp/pvp_rules.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const PvpTargetsScript := preload("res://scripts/pvp/pvp_targets.gd")
const BalanceLogScript := preload("res://scripts/balance_log.gd")
const WeaponTargetPriorityScript := preload("res://scripts/weapon_target_priority.gd")

const RIVAL_PEER := 77
const ALLY_PEER := 55


class FakeRival extends Node2D:
	var peer_id: int = 0
	var health: float = 100.0
	var max_health: float = 100.0
	var is_dead: bool = false
	var is_downed: bool = false
	var in_limbo: bool = false
	var is_indoors: bool = false
	var is_invisible: bool = false


class FakeMe extends Node2D:
	var is_dead: bool = false
	var max_health: float = 200.0
	var item_shield_max: float = 0.0
	var got: Array = []

	func take_pvp_damage(amount: float, attacker: int, _crit: bool = false) -> void:
		got.append([amount, attacker])


var _nodes: Array[Node] = []
var _hits: Array = []
var _age_sec: float = 0.0


func _restore() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	_hits.clear()
	GameModeScript.set_room_mode(GameModeScript.COOP)
	TeamsScript.reset()
	BaseZonesScript.active = []
	BaseZonesScript.radius = BaseZonesScript.RADIUS
	PvpRulesScript.end_match()
	NetworkManager.is_multiplayer_active = false


func _enter_pvp(match_age_sec: float) -> void:
	NetworkManager.is_multiplayer_active = true ## PvP yalnız çok oyunculuda (game_mode.gd); eş yok, RPC gitmez (PvpNet._mp_active)
	GameModeScript.set_room_mode(GameModeScript.PVP)
	TeamsScript.set_all({TeamsScript.local_peer(): 0, ALLY_PEER: 0, RIVAL_PEER: 1})
	_age_sec = match_age_sec
	PvpRulesScript.match_running = true
	PvpRulesScript.match_start_msec = Time.get_ticks_msec() - int(match_age_sec * 1000.0)


func _rival(at: Vector2, peer: int = RIVAL_PEER) -> FakeRival:
	var r := FakeRival.new()
	r.peer_id = peer
	r.name = "FakeRival%d" % peer
	add_child(r)
	r.global_position = at
	r.add_to_group("remote_players")
	_nodes.append(r)
	return r


func _manager() -> Node:
	var m: Node = PvpTargetsScript.new()
	add_child(m)
	_nodes.append(m)
	## yönetici _ready'de maçı şimdi başlatır; testin istediği maç yaşını geri yaz
	PvpRulesScript.match_start_msec = Time.get_ticks_msec() - int(_age_sec * 1000.0)
	return m


func _on_hit(victim: int, amount: float, crit: bool) -> void:
	_hits.append([victim, amount, crit])


func test_rules_categories_cap_and_prep() -> void:
	assert(is_equal_approx(PvpRulesScript.outgoing(100.0, "w:tabanca", false, false), 40.0), "silah x0,4")
	assert(is_equal_approx(PvpRulesScript.outgoing(100.0, "s:talon_q", false, false), 100.0), "yetenek x1")
	assert(is_equal_approx(PvpRulesScript.outgoing(100.0, "s:matthew_q", true, false), 70.0), "alan x0,7")
	assert(is_equal_approx(PvpRulesScript.outgoing(100.0, "", false, true), 50.0), "süreli x0,5 (etiketsiz = yetenek sınıfı)")
	assert(is_equal_approx(PvpRulesScript.outgoing(100.0, "w:topuz", true, true), 20.0), "süreli silah hasarı 0,4 x 0,5 (alan sayılmaz)")
	assert(PvpRulesScript.outgoing(-5.0, "", false, false) == 0.0 and PvpRulesScript.outgoing(NAN, "", false, false) == 0.0, "geçersiz hasar 0")
	assert(is_equal_approx(PvpRulesScript.incoming_cap(1000.0, 100.0, 50.0), 37.5), "tek vuruş tavanı = (can + kalkan) x %25")
	assert(is_equal_approx(PvpRulesScript.incoming_cap(10.0, 100.0, 50.0), 10.0), "tavanın altı aynen")
	assert(is_equal_approx(PvpRulesScript.incoming_cap(80.0, 0.0, 0.0), 80.0), "azami bilinmiyorsa tavan yok")
	assert(is_equal_approx(PvpRulesScript.cc_seconds(1.0), 0.5) and is_equal_approx(PvpRulesScript.cc_seconds(10.0), PvpRulesScript.CC_MAX_SECONDS), "kontrol yarı + üst sınır")
	assert(PvpRulesScript.prep_left_now() == 0.0 and not PvpRulesScript.fighting(), "maç çalışmıyorken PvP hasarı geçerli değil")
	assert(is_equal_approx(PvpRulesScript.prep_left(11000, 1000), PvpRulesScript.PREP_SECONDS - 10.0), "hazırlıktan kalan")
	assert(PvpRulesScript.prep_left(1000 + int(PvpRulesScript.PREP_SECONDS * 1000.0) + 5, 1000) == 0.0, "hazırlık bitti")


## Kullanıcı 2026-11-12: "üs koruma alanları çok büyük yolları kapatıyor, küçülmeli" (280 -> 160; dar yerde kampla birlikte daha küçük).
func test_base_radius_is_small_and_shrinks_with_a_narrow_camp() -> void:
	assert(BaseZonesScript.RADIUS <= 170.0, "koruma alanı küçük: %s" % BaseZonesScript.RADIUS)
	assert(is_equal_approx(BaseZonesScript.radius_for_camp(0.0), BaseZonesScript.RADIUS), "tam kamp = tam yarıçap")
	assert(is_equal_approx(BaseZonesScript.radius_for_camp(80.0), 80.0 + BaseZonesScript.CAMP_PAD), "dar kamp: kamp + pay")
	assert(is_equal_approx(BaseZonesScript.radius_for_camp(20.0), BaseZonesScript.MIN_RADIUS), "en küçük sınır")
	assert(is_equal_approx(BaseZonesScript.radius_for_camp(900.0), BaseZonesScript.RADIUS), "büyük kamp RADIUS'u aşmaz")
	BaseZonesScript.active = [{"center": Vector2(1000, 1000), "team": 0}]
	BaseZonesScript.set_camp_radius(80.0)
	assert(BaseZonesScript.shelters(Vector2(1090, 1000)) and not BaseZonesScript.shelters(Vector2(1110, 1000)), "dar yerde alan küçülür")
	_restore()


func test_coop_builds_no_proxies() -> void:
	TeamsScript.set_all({TeamsScript.local_peer(): 0, RIVAL_PEER: 1}) ## mod kapalı: team_of hep 0
	var rival: FakeRival = _rival(Vector2(300, 300))
	var mgr: Node = _manager()
	mgr.call("_sync_proxies")
	assert(get_tree().get_nodes_in_group("pvp_targets").is_empty(), "co-op: vekil yok")
	assert(rival.visible, "co-op: kukla görünür")
	_restore()


func test_rival_gets_a_proxy_ally_does_not_and_proxy_follows() -> void:
	_enter_pvp(120.0)
	var rival: FakeRival = _rival(Vector2(300, 300))
	var ally: FakeRival = _rival(Vector2(100, 100), ALLY_PEER)
	var mgr: Node = _manager()
	mgr.call("_sync_proxies")
	var proxies: Array = get_tree().get_nodes_in_group("pvp_targets")
	assert(proxies.size() == 1, "yalnız rakibe vekil: %d" % proxies.size())
	var proxy: Node2D = proxies[0] as Node2D
	assert(proxy.is_in_group("enemies") and proxy.is_in_group("mission_copies"), "hedef sözleşmesi: enemies + mission_copies")
	assert(int(proxy.get("peer")) == RIVAL_PEER and proxy.get("rival") == rival, "rakibe bağlı")
	assert(proxy.has_meta(&"hide_on_minimap"), "minimapte ayrı nokta yok")
	_nodes.append(proxy)
	rival.global_position = Vector2(500, 420)
	proxy.call("_sync_from_rival")
	assert(proxy.global_position.is_equal_approx(Vector2(500, 420)), "vekil kuklayı izler")
	## takım arkadaşı rakip takıma geçince vekil kurulur, rakip gidince silinir
	rival.remove_from_group("remote_players")
	mgr.call("_sync_proxies")
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("pvp_targets").is_empty(), "kukla gidince vekil silinir")
	ally.free()
	_nodes.erase(ally)
	_restore()


func test_proxy_hit_goes_to_the_victim_with_the_category_multiplier() -> void:
	_enter_pvp(120.0)
	var rival: FakeRival = _rival(Vector2(400, 0))
	var mgr: Node = _manager()
	mgr.call("_sync_proxies")
	var proxy: Node2D = get_tree().get_nodes_in_group("pvp_targets")[0] as Node2D
	_nodes.append(proxy)
	var net: Node = PvpNetScript.instance()
	assert(net != null, "PvpNet düğümü (NetworkManager çocuğu)")
	net.hit_sent.connect(_on_hit)
	assert(not proxy.has_meta(&"untargetable"), "hazırlık bitti: hedeflenebilir")
	## silah vuruşu (etiket "w:") x0,4, kritik bilgisi gider
	BalanceLogScript.tag(&"w:tabanca")
	proxy.call("take_damage", 100.0, true, 0.0, false)
	assert(_hits.size() == 1 and _hits[0][0] == RIVAL_PEER and is_equal_approx(float(_hits[0][1]), 40.0) and _hits[0][2] == true, "silah x0,4: %s" % str(_hits))
	## etiketsiz (yetenek / evrim) x1; etiket tek isabette tüketilir
	proxy.call("take_damage", 100.0)
	assert(_hits.size() == 2 and is_equal_approx(float(_hits[1][1]), 100.0), "etiket sızmaz, yetenek x1: %s" % str(_hits))
	## süreli hasar (yanma tiki) kurbana x0,5 gider
	proxy.call("apply_burn", 20.0, 3.0)
	proxy.set("_dot_timer", 0.0)
	proxy.call("_process_dots", 0.016)
	assert(_hits.size() == 3 and is_equal_approx(float(_hits[2][1]), 10.0), "süreli x0,5: %s" % str(_hits))
	## ölü / yerdeki rakibe hasar gitmez
	rival.is_downed = true
	proxy.call("_sync_from_rival")
	proxy.call("take_damage", 100.0)
	assert(_hits.size() == 3, "yerdeki rakibe hasar yok")
	rival.is_downed = false
	proxy.call("_sync_from_rival")
	## rakip kendi üssünde: üste PvP yok, silahlar da hedef almaz
	BaseZonesScript.active = [{"center": rival.global_position, "team": 1}]
	proxy.call("_sync_from_rival")
	proxy.call("take_damage", 100.0)
	assert(_hits.size() == 3 and proxy.has_meta(&"untargetable"), "rakibin üssünde hasar yok + hedeflenemez")
	## ben kendi üssümdeyken de saldıramam
	BaseZonesScript.active = [{"center": Vector2(5000, 5000), "team": 1}]
	var me := FakeMe.new()
	me.add_to_group("player")
	add_child(me)
	_nodes.append(me)
	me.global_position = Vector2(0, 0)
	BaseZonesScript.active = [{"center": Vector2(0, 0), "team": 0}]
	proxy.call("_sync_from_rival")
	proxy.call("take_damage", 100.0)
	assert(_hits.size() == 3 and proxy.has_meta(&"untargetable"), "kendi üssümden saldırı yok")
	net.hit_sent.disconnect(_on_hit)
	_restore()


func test_proxy_is_untargetable_during_prep() -> void:
	_enter_pvp(10.0) ## maçın 10. saniyesi
	var rival: FakeRival = _rival(Vector2(300, 0))
	var mgr: Node = _manager()
	mgr.call("_sync_proxies")
	var proxy: Node2D = get_tree().get_nodes_in_group("pvp_targets")[0] as Node2D
	_nodes.append(proxy)
	var net: Node = PvpNetScript.instance()
	net.hit_sent.connect(_on_hit)
	proxy.call("_sync_from_rival")
	assert(proxy.has_meta(&"untargetable"), "hazırlıkta hedeflenemez")
	proxy.call("take_damage", 100.0)
	assert(_hits.is_empty(), "hazırlıkta hasar gitmez")
	PvpRulesScript.match_start_msec = Time.get_ticks_msec() - int((PvpRulesScript.PREP_SECONDS + 1.0) * 1000.0)
	proxy.call("_sync_from_rival")
	assert(not proxy.has_meta(&"untargetable"), "hazırlık bitince hedeflenir")
	assert(rival.visible, "kukla")
	net.hit_sent.disconnect(_on_hit)
	_restore()


func test_weapon_priority_ignores_pvp_proxies() -> void:
	_enter_pvp(120.0)
	var rival: FakeRival = _rival(Vector2(100, 0))
	var mgr: Node = _manager()
	mgr.call("_sync_proxies")
	var proxy: Node2D = get_tree().get_nodes_in_group("pvp_targets")[0] as Node2D
	_nodes.append(proxy)
	var picked: Node2D = WeaponTargetPriorityScript.nearest_priority_target(get_tree(), Vector2.ZERO, 800.0)
	assert(picked == null, "rakip öncelikli hedef değil (normal en yakın hedef adayı): %s" % str(picked))
	assert(rival != null)
	_restore()


func test_victim_check_rules() -> void:
	_enter_pvp(120.0)
	var net: Node = PvpNetScript.instance()
	var me := FakeMe.new()
	me.add_to_group("player")
	add_child(me)
	_nodes.append(me)
	me.global_position = Vector2(0, 0)
	var rival: FakeRival = _rival(Vector2(300, 0))
	var ally: FakeRival = _rival(Vector2(100, 0), ALLY_PEER)
	assert(net.call("victim_check", RIVAL_PEER) == me, "rakip + hazırlık bitti + makul mesafe = geçerli")
	assert(net.call("victim_check", ALLY_PEER) == null, "takım arkadaşından hasar kabul edilmez (dost ateşi yok)")
	assert(net.call("victim_check", 0) == null and net.call("victim_check", 4242) == null, "bilinmeyen gönderen")
	rival.global_position = Vector2(PvpRulesScript.MAX_HIT_RANGE + 200.0, 0)
	assert(net.call("victim_check", RIVAL_PEER) == null, "çok uzaktan vuruş reddedilir")
	rival.global_position = Vector2(300, 0)
	BaseZonesScript.active = [{"center": Vector2(0, 0), "team": 0}]
	assert(net.call("victim_check", RIVAL_PEER) == null, "kurban kendi üssünde: hasar yok")
	BaseZonesScript.active = [{"center": Vector2(300, 0), "team": 1}]
	assert(net.call("victim_check", RIVAL_PEER) == null, "saldıran kendi üssünden vuramaz")
	BaseZonesScript.active = []
	PvpRulesScript.match_start_msec = Time.get_ticks_msec() - 5000
	assert(net.call("victim_check", RIVAL_PEER) == null, "hazırlıkta hasar reddedilir")
	PvpRulesScript.match_start_msec = Time.get_ticks_msec() - 120000
	me.is_dead = true
	assert(net.call("victim_check", RIVAL_PEER) == null, "ölü oyuncuya hasar yok")
	me.is_dead = false
	GameModeScript.set_room_mode(GameModeScript.COOP)
	assert(net.call("victim_check", RIVAL_PEER) == null, "co-op'ta PvP hasarı kabul edilmez")
	assert(ally != null)
	_restore()
