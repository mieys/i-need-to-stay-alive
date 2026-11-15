extends Node

## PvPvE Aşama 3 + 4 (madde 617, docs/pvp/PLAN.md): destek yeteneklerinin rakibi dışarıda bırakması, oyuncuda yavaşlatma + azalan etki, ölüm / üste doğuş,
## öldürme ödülü + skor, eleme, takım başına XP. Kurallar saf (pvp_rules.gd); oyuncu / kukla gerçek sahnelerle.
## PvP kipi: yalnız editörde geçerli MOD ortam değişkeniyle (game_mode.gd; ağ yok, RPC gitmez).

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const PvpRulesScript := preload("res://scripts/pvp/pvp_rules.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

const ALLY_PEER := 55
const RIVAL_PEER := 77
const RIVAL2_PEER := 78

var _spawned: Array[Node] = []
var _saved_gold: int = 0
var _saved_team: Array = []


func _ensure_scene() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self


func _enter_pvp() -> void:
	OS.set_environment("MOD", "pvp")
	GameModeScript.set_room_mode(GameModeScript.COOP) ## MOD ortam değişkeni ezer
	TeamsScript.set_all({TeamsScript.local_peer(): 0, ALLY_PEER: 0, RIVAL_PEER: 1, RIVAL2_PEER: 1})
	PvpRulesScript.end_match()
	_saved_gold = GameManager.gold
	_saved_team = [GameManager.team_level, GameManager.team_xp, GameManager.team_xp_needed]


func _restore() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	OS.unset_environment("MOD")
	TeamsScript.reset()
	BaseZonesScript.active = []
	PvpRulesScript.end_match()
	PvpNetScript.clear_match()
	var net: Node = PvpNetScript.instance()
	if net != null:
		net._xp_states = []
		net._streaks = {}
	GameManager.is_game_over = false
	if not _saved_team.is_empty():
		GameManager.team_level = int(_saved_team[0])
		GameManager.team_xp = float(_saved_team[1])
		GameManager.team_xp_needed = float(_saved_team[2])
		GameManager.gold = _saved_gold
	NetworkManager.lobby_players = {}
	NetworkManager._confirmed_dead_peers = {}
	NetworkManager.is_multiplayer_active = false


func _player() -> Node2D:
	_ensure_scene()
	NetworkManager.is_multiplayer_active = false
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(100.0, 100.0)
	p.max_health = 200.0
	p.health = 200.0
	return p


func _puppet(peer: int) -> Node2D:
	_ensure_scene()
	var rp: Node2D = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.call("setup", peer, 1, "Kukla%d" % peer)
	return rp


func test_death_time_and_kill_gold_rules() -> void:
	assert(is_equal_approx(PvpRulesScript.death_seconds(1), 12.0) and is_equal_approx(PvpRulesScript.death_seconds(10), 30.0), "ölüm süresi 10 + 2 x kademe")
	assert(is_equal_approx(PvpRulesScript.death_seconds(99), 30.0) and is_equal_approx(PvpRulesScript.death_seconds(0), 12.0), "kademe 1-10 arasına kırpılır")
	assert(PvpRulesScript.kill_gold(1, 0) == 80 and PvpRulesScript.kill_gold(5, 0) == 160, "öldürme altını: taban + kademe")
	assert(PvpRulesScript.kill_gold(5, 3) == 160 + 45 and PvpRulesScript.kill_gold(5, 99) == 160 + 75, "seri bozma eki en çok 5 seri")


func test_elimination_rule() -> void:
	var team := {1: 0, 2: 0, 3: 1, 4: 1}
	var peers: Array = [1, 2, 3, 4]
	assert(PvpRulesScript.eliminated_winner(team, peers, {}) == -1, "kimse ölmedi: sürüyor")
	assert(PvpRulesScript.eliminated_winner(team, peers, {1: true, 3: true}) == -1, "her takımdan biri ölü: sürüyor")
	assert(PvpRulesScript.eliminated_winner(team, peers, {1: true, 2: true}) == 1, "0. takımın ikisi de kalıcı ölü: 1. kazanır")
	assert(PvpRulesScript.eliminated_winner(team, peers, {3: true, 4: true}) == 0, "1. takım elendi: 0. kazanır")
	assert(PvpRulesScript.eliminated_winner(team, peers, {1: true, 2: true, 3: true, 4: true}) == -2, "ikisi de elendi: berabere")
	assert(PvpRulesScript.eliminated_winner(team, [1, 2], {}) == 0, "bir takımın bütün oyuncuları ayrıldı: öbürü kazanır")
	assert(PvpRulesScript.eliminated_winner({1: 0}, [1], {}) == 0 and PvpRulesScript.eliminated_winner({}, [], {}) == -1, "tek kişilik / boş oda eleme sayılmaz kuralı bozmaz")


func test_cc_diminishing_returns_and_immunity() -> void:
	PvpRulesScript.cc_reset()
	var t: int = 1000000
	assert(is_equal_approx(PvpRulesScript.cc_register(2.0, t), 1.0), "1. kontrol: yarı süre")
	assert(is_equal_approx(PvpRulesScript.cc_register(2.0, t + 300), 1.0), "1 sn içindeki tekrar AYNI uygulama (alan tiki): sayaç tükenmez")
	assert(is_equal_approx(PvpRulesScript.cc_register(2.0, t + 3000), 0.5), "2. kontrol yarım")
	assert(is_equal_approx(PvpRulesScript.cc_register(2.0, t + 6000), 0.25), "3. kontrol çeyrek")
	assert(PvpRulesScript.cc_register(2.0, t + 7000) == 0.0, "3. sonrası kısa bağışıklık")
	assert(PvpRulesScript.cc_register(2.0, t + 9000) == 0.0, "bağışıklık sürüyor (3. süre + 3 sn)")
	assert(is_equal_approx(PvpRulesScript.cc_register(2.0, t + 60000), 1.0), "15 sn sonra sayaç sıfırlanır")
	PvpRulesScript.cc_reset()


func test_respawn_protection_ends_three_seconds_after_leaving_the_base() -> void:
	PvpRulesScript.end_match()
	PvpRulesScript.begin_respawn_protection()
	assert(PvpRulesScript.respawn_protected(true, 5000), "üstteyken korunur")
	assert(PvpRulesScript.respawn_protected(false, 6000), "çıkış anı: 3 sn başlar")
	assert(PvpRulesScript.respawn_protected(false, 8900), "çıkıştan 3 sn dolmadan korunur")
	assert(not PvpRulesScript.respawn_protected(false, 9100), "3 sn sonra koruma biter")
	PvpRulesScript.end_match()
	assert(not PvpRulesScript.respawn_protected(true, 100), "maç bitince koruma sıfırlanır")


func test_combat_window() -> void:
	PvpRulesScript.end_match()
	PvpRulesScript.match_running = true
	PvpRulesScript.note_combat(10000)
	assert(PvpRulesScript.in_combat(12000) and not PvpRulesScript.in_combat(17000), "savaş 6 sn sürer")
	PvpRulesScript.end_match()
	assert(not PvpRulesScript.in_combat(10001), "maç yokken savaş yok")


func test_rival_puppet_leaves_support_groups_ally_stays() -> void:
	_enter_pvp()
	var ally: Node2D = _puppet(ALLY_PEER)
	var rival: Node2D = _puppet(RIVAL_PEER)
	assert(ally.is_in_group("remote_allies") and ally.is_in_group("player_ally") and not ally.is_in_group("pvp_rivals"), "takım arkadaşı destek gruplarında")
	assert(not rival.is_in_group("remote_allies") and not rival.is_in_group("player_ally") and rival.is_in_group("pvp_rivals"), "rakip destek gruplarından çıkar")
	assert(rival.is_in_group("remote_players") and ally.is_in_group("remote_players"), "ikisi de 'herhangi bir oyuncu' grubunda (yaratık hedefi, doğuş...)")
	_restore()
	var coop_rp: Node2D = _puppet(RIVAL_PEER)
	assert(coop_rp.is_in_group("remote_allies") and coop_rp.is_in_group("player_ally") and not coop_rp.is_in_group("pvp_rivals"), "co-op: herkes müttefik, hiçbir şey değişmez")
	_restore()


func test_player_pvp_slow_is_capped_and_expires() -> void:
	_enter_pvp()
	var p: Node2D = _player()
	var base: float = p.get_effective_move_speed()
	p.apply_pvp_slow(0.4, 2.0)
	assert(is_equal_approx(p.get_effective_move_speed(), base * 0.6), "yüzde 40 yavaşlatma")
	p.apply_pvp_slow(0.9, 1.0)
	assert(is_equal_approx(p.get_effective_move_speed(), base * 0.4), "en güçlü kalır ama oyuncuda en çok yüzde 60: %s" % p.get_effective_move_speed())
	p._process_pvp_slow(5.0)
	assert(is_equal_approx(p.get_effective_move_speed(), base), "süre bitince hız geri gelir")
	_restore()


func test_pvp_death_timer_then_respawn_with_full_health_and_protection() -> void:
	_enter_pvp()
	GameManager.run_max_tier = 3
	var p: Node2D = _player()
	p.health = 0.0
	p._go_down()
	assert(p.is_downed and p.is_dead, "ölünce cesette yatar")
	assert(is_equal_approx(p.get_downed_remaining_seconds(), PvpRulesScript.death_seconds(3)), "ölüm süresi kademeye göre: %s" % p.get_downed_remaining_seconds())
	p._process_downed(4.0)
	assert(p.is_downed and is_equal_approx(p.get_downed_remaining_seconds(), PvpRulesScript.death_seconds(3) - 4.0), "süre azalır, diriltme yok")
	p._process_downed(100.0)
	assert(not p.is_downed and not p.is_dead, "süre bitince doğar")
	assert(is_equal_approx(p.health, p.max_health), "TAM canla doğar")
	assert(PvpRulesScript.respawn_protect_pending, "doğuş koruması başladı")
	GameManager.run_max_tier = 1
	_restore()


func test_coop_downed_flow_unchanged() -> void:
	NetworkManager.is_multiplayer_active = false
	var p: Node2D = _player()
	p._go_down()
	assert(p.is_downed and p._pvp_death_left == 0.0, "co-op: PvP ölüm süresi kurulmaz")
	assert(p.get_downed_remaining_seconds() == 0.0, "co-op: kurtarıcı gelmeyince sayaç eski kural (başlamamış)")
	_restore()


func test_kill_score_gold_and_feed() -> void:
	_enter_pvp()
	GameManager.run_max_tier = 2
	var net: Node = PvpNetScript.instance()
	var feed: Array = []
	net.kill_feed.connect(func(k: int, v: int, g: int) -> void: feed.append([k, v, g]))
	var start_gold: int = GameManager.gold
	net.call("_host_register_death", RIVAL_PEER, TeamsScript.local_peer())
	var want: int = PvpRulesScript.kill_gold(2, 0)
	assert(int(PvpNetScript.team_kills[0]) == 1 and int(PvpNetScript.team_kills[1]) == 0, "öldüren takımın sayacı artar")
	assert(int(PvpNetScript.peer_kills.get(TeamsScript.local_peer(), 0)) == 1 and int(PvpNetScript.peer_deaths.get(RIVAL_PEER, 0)) == 1, "kişisel sayaçlar")
	assert(GameManager.gold == start_gold + want, "öldüren altını alır: %d / %d" % [GameManager.gold - start_gold, want])
	assert(feed.size() == 1 and int(feed[0][0]) == TeamsScript.local_peer() and int(feed[0][1]) == RIVAL_PEER and int(feed[0][2]) == want, "öldürme bildirimi")
	## takım arkadaşı ölümü / yaratık ölümü öldürme sayılmaz
	net.call("_host_register_death", ALLY_PEER, TeamsScript.local_peer())
	assert(int(PvpNetScript.team_kills[0]) == 1, "dost öldürme sayılmaz (dost ateşi yok)")
	net.call("_host_register_death", RIVAL_PEER, 0)
	assert(int(PvpNetScript.team_kills[0]) == 1 and int(PvpNetScript.peer_deaths.get(RIVAL_PEER, 0)) == 2, "yaratık öldürürse kimseye sayılmaz ama ölüm kaydı tutulur")
	## seri: rakip bir öldürme yapıp sonra öldürülürse seri bozma eki öldürene gider
	net.call("_host_register_death", TeamsScript.local_peer(), RIVAL_PEER)
	net.call("_host_register_death", RIVAL_PEER, TeamsScript.local_peer())
	assert(int(PvpNetScript.team_kills[1]) == 1 and int(PvpNetScript.team_kills[0]) == 2, "skor iki takım için de işler")
	GameManager.run_max_tier = 1
	_restore()


func test_elimination_ends_match_with_winner() -> void:
	_enter_pvp()
	var net: Node = PvpNetScript.instance()
	NetworkManager.lobby_players = {TeamsScript.local_peer(): {}, ALLY_PEER: {}, RIVAL_PEER: {}, RIVAL2_PEER: {}}
	var ended: Array = []
	net.match_ended.connect(func(w: int, r: String) -> void: ended.append([w, r]))
	NetworkManager._confirmed_dead_peers = {RIVAL_PEER: true}
	net.call("host_check_elimination")
	assert(ended.is_empty() and not GameManager.is_game_over, "bir takımın bir oyuncusu hayatta: oyun sürer")
	NetworkManager._confirmed_dead_peers = {TeamsScript.local_peer(): true, ALLY_PEER: true}
	net.call("host_check_elimination")
	assert(ended.size() == 1 and int(ended[0][0]) == 1 and str(ended[0][1]) == "eliminated", "0. takım elendi: 1. takım kazandı")
	assert(GameManager.is_game_over and PvpNetScript.winner_team == 1, "oyun bitti + kazanan kaydı")
	net.call("host_end_match", 0, "surrender")
	assert(ended.size() == 1, "bitmiş maç ikinci kez bitmez")
	_restore()


func test_final_boss_last_hit_decides_winner() -> void:
	_enter_pvp()
	var net: Node = PvpNetScript.instance()
	var ended: Array = []
	net.match_ended.connect(func(w: int, r: String) -> void: ended.append([w, r]))
	net.call("host_final_boss_killed", RIVAL_PEER)
	assert(ended.size() == 1 and int(ended[0][0]) == 1 and str(ended[0][1]) == "boss", "son vuruşu yapan takım kazanır")
	_restore()


func test_per_team_xp_levels_independently() -> void:
	_enter_pvp()
	var net: Node = PvpNetScript.instance()
	var need1: float = GameManager._xp_needed_for_level(1)
	GameManager.team_level = 1
	GameManager.team_xp = 0.0
	GameManager.team_xp_needed = need1
	net.call("host_collect_xp", need1 + 1.0, RIVAL_PEER) ## rakip takım seviye atlar
	assert(int(PvpNetScript.team_levels[1]) == 2 and int(PvpNetScript.team_levels[0]) == 1, "XP toplayanın takımına yazılır")
	assert(GameManager.team_level == 1, "benim takımımın seviyesi değişmez (rakibin XP'si bana gelmez)")
	net.call("host_collect_xp", need1 + 1.0, TeamsScript.local_peer())
	assert(GameManager.team_level == 2 and int(PvpNetScript.team_levels[0]) == 2, "kendi takımım seviye atlar")
	assert(PvpNetScript.top_team_level() == 2, "zorluk ölçeği iki takımın yükseğine bakar")
	var triplet: Array = net.call("xp_triplet_for", RIVAL_PEER)
	assert(not triplet.is_empty() and int(triplet[0]) == 2, "geri katılım: kendi takımının durumu")
	_restore()
