extends Node

## PvPvE AĞI (madde 607): NetworkManager'ın çocuğu "PvpNet" (her makinede aynı yol /root/NetworkManager/PvpNet -> RPC çalışır; kod
## network_manager.gd'ye yığılmasın diye ayrı). Host yetkili:
## - Lobi her değiştiğinde mod + takımlar herkese (_rpc_state). Yeni gelen az kişili takıma girer; takımı kendiliğinden kimse değiştirmez,
##   oyuncu seçim ekranında istediği takıma kendisi geçer (request_team -> host doğrular -> _rpc_state, madde 608; oyun başlayınca kilitli).
## - Oyun başlayınca host'un Main'i üs konumlarını seçer (team_bases.gd) ve herkese yollar (_rpc_bases, mod + takımlarla birlikte).
##   Main'i geç kurulan / geri katılan istemci _rpc_request_bases ile ister.
## İstemci aldığını static alanlarda saklar; Main'deki TeamBases bases_received sinyalini bekler.

signal bases_received
## Mod / takım dağılımı değişti (istemcide host'tan gelince, host'ta bir oyuncu takım seçince): seçim ekranı oyuncu kartlarını yeniler.
signal teams_changed
## Vuran tarafta bir PvP vuruşu gönderilirken (ağ olmasa da; test / günlük kancası, madde 615).
signal hit_sent(victim_peer: int, amount: float, is_crit: bool)
## Skor / seviye durumu değişti (öldürme, takım seviyesi): üst orta skor şeridi yenilenir (madde 617).
signal score_changed
## Bir oyuncu bir rakibi ya da bir şey öldürdü (killer 0 = oyuncu öldürmedi): öldürme bildirimi; gold = öldürenin kazandığı altın.
signal kill_feed(killer: int, victim: int, gold: int)
## Maç bitti: winner 0 / 1 takım, -2 berabere; reason "eliminated" / "boss" / "surrender" / "left".
signal match_ended(winner: int, reason: String)
## Bir takım K5 bossunu aldı (üç dakikalık güç): `own` = bu makinenin takımı mı.
signal boss_buff(team: int, own: bool)

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const PvpRulesScript := preload("res://scripts/pvp/pvp_rules.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")

const NODE_NAME := "PvpNet"

## Takım sırasıyla üs merkezleri (dünya). Boş = bu oyunda henüz seçilmedi.
static var bases: Array = []
## Skor durumu (host yazar, `_rpc_score` herkese yayar): takım öldürmeleri / takım seviyeleri, oyuncu öldürme + ölme sayıları (madde 617).
static var team_kills: Array = [0, 0]
static var team_levels: Array = [1, 1]
static var peer_kills: Dictionary = {}
static var peer_deaths: Dictionary = {}
## Maç sonucu (-1 = sürüyor, 0 / 1 = kazanan takım, -2 = berabere) + nedeni.
static var winner_team: int = -1
static var end_reason: String = ""
## Kurban tarafında son alınan PvP vuruşları [gönderen, miktar, kabul]; yalnız denetim / hata ayıklama (madde 617).
static var hit_log: Array = []
## Kampın sığdığı boş yarıçap (0 = tam kamp; dar zindanda küçük kamp, team_camp.gd).
static var camp_radius: float = 0.0


static func instance() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("NetworkManager/" + NODE_NAME)


func _ready() -> void:
	var nm: Node = get_parent()
	if nm != null and nm.has_signal("lobby_updated"):
		nm.lobby_updated.connect(_on_lobby_updated)


func _nm() -> Node:
	return get_parent()


func _is_mp_host() -> bool:
	var nm: Node = _nm()
	return nm != null and bool(nm.get("is_multiplayer_active")) and bool(nm.get("is_host"))


func _sender_is_host() -> bool:
	var nm: Node = _nm()
	return nm != null and nm.has_method("_from_host") and bool(nm.call("_from_host"))


func _on_lobby_updated() -> void:
	if not _is_mp_host():
		return
	var peers: Array = (_nm().get("lobby_players") as Dictionary).keys()
	TeamsScript.set_all(TeamsScript.balanced_assign(TeamsScript.by_peer, peers))
	_rpc_state.rpc(GameModeScript.room_mode, TeamsScript.by_peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_state(mode: String, teams: Dictionary) -> void:
	if not _sender_is_host():
		return
	var before_mode: String = GameModeScript.room_mode
	var before_teams: Dictionary = TeamsScript.by_peer.duplicate()
	GameModeScript.set_room_mode(mode)
	TeamsScript.set_all(teams)
	if before_mode != GameModeScript.room_mode or before_teams != TeamsScript.by_peer:
		teams_changed.emit()


## Yerel oyuncu seçim ekranında bir takıma geçmek ister (madde 608). Host kendi isteğini doğrudan uygular, istemci host'a yollar; host
## kuralı (`TeamsScript.try_move`: geçerli takım, yer var, oyun başlamamış) doğrular ve yeni atamayı herkese yayınlar.
func request_team(team: int) -> void:
	var nm: Node = _nm()
	if nm == null or not bool(nm.get("is_multiplayer_active")):
		return
	if _is_mp_host():
		_apply_team_request(TeamsScript.local_peer(), team)
		return
	var host_id: int = int(nm.call("_host_peer_id"))
	if host_id > 0:
		_rpc_request_team.rpc_id(host_id, team)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_team(team: int) -> void:
	if not _is_mp_host():
		return
	_apply_team_request(multiplayer.get_remote_sender_id(), team)


func _apply_team_request(peer: int, team: int) -> void:
	var nm: Node = _nm()
	if nm == null or not GameModeScript.is_pvp() or bool(nm.get("_is_game_in_progress")):
		return ## takımlar oyun başlayınca kilitli: üsler / doğuşlar o atamayla kuruldu
	var lobby: Dictionary = nm.get("lobby_players")
	if not lobby.has(peer):
		return
	var before: int = TeamsScript.team_of(peer)
	var next: Dictionary = TeamsScript.try_move(TeamsScript.by_peer, lobby.keys(), peer, team,
		TeamsScript.team_capacity(int(nm.get("room_max_players"))))
	if int(next.get(peer, before)) == before:
		return
	TeamsScript.set_all(next)
	_rpc_state.rpc(GameModeScript.room_mode, TeamsScript.by_peer)
	teams_changed.emit()


## host (ya da tek oyunculu MOD=pvp): seçilen üsleri yayınla.
func publish_bases(arr: Array, camp_r: float = 0.0) -> void:
	bases = arr.duplicate()
	camp_radius = camp_r
	if _is_mp_host():
		_rpc_bases.rpc(bases, camp_radius, GameModeScript.room_mode, TeamsScript.by_peer)
	bases_received.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_bases(arr: Array, camp_r: float, mode: String, teams: Dictionary) -> void:
	if not _sender_is_host():
		return
	GameModeScript.set_room_mode(mode)
	TeamsScript.set_all(teams)
	bases = arr.duplicate()
	camp_radius = camp_r
	bases_received.emit()


## istemci: Main'i kuruldu ama üsler henüz gelmedi (geç yükleme / geri katılım) -> host'tan iste.
func request_bases() -> void:
	var nm: Node = _nm()
	if nm == null or not bool(nm.get("is_multiplayer_active")) or bool(nm.get("is_host")):
		return
	var host_id: int = int(nm.call("_host_peer_id"))
	if host_id > 0:
		_rpc_request_bases.rpc_id(host_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_bases() -> void:
	if not _is_mp_host() or bases.is_empty():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_rpc_bases.rpc_id(sender, bases, camp_radius, GameModeScript.room_mode, TeamsScript.by_peer)


## ---------------------------------------------------------------- PvP HASARI (Aşama 2, madde 615)
## Yetki KURBANDA: vuran makine rakip kuklanın vekilinden (pvp_target.gd) hasarı / kontrolü kurbana yollar, kurban doğrular ve kendi
## oyuncusuna uygular (host yolda değil: gecikme eklemez, host avantajı yok). Kanal 1 = NetworkManager.CH_COMBAT (hasar / vuruş).

## Vuran: rakip peer'e `amount` hasar (kategori çarpanı zaten uygulanmış, pvp_rules.gd outgoing).
func send_hit(victim_peer: int, amount: float, is_crit: bool) -> void:
	if victim_peer <= 0 or amount <= 0.0:
		return
	hit_sent.emit(victim_peer, amount, is_crit)
	PvpRulesScript.note_combat()
	if _mp_active():
		_rpc_hit.rpc_id(victim_peer, amount, is_crit)


## Vuran: rakip peer'e kontrol (kind "stun" sersemletme, "knock" geri itme).
func send_cc(victim_peer: int, kind: String, duration: float, dir: Vector2 = Vector2.ZERO, force: float = 0.0) -> void:
	if victim_peer <= 0 or not _mp_active():
		return
	_rpc_cc.rpc_id(victim_peer, kind, duration, dir, force)


func _mp_active() -> bool:
	var nm: Node = _nm()
	return nm != null and bool(nm.get("is_multiplayer_active")) and multiplayer.has_multiplayer_peer()


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_hit(amount: float, is_crit: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var p: Node2D = victim_check(sender)
	hit_log.append([sender, snappedf(amount, 0.01), p != null]) ## denetim / hata ayıklama: son alınan vuruşlar ve kabul edilip edilmediği
	if hit_log.size() > 12:
		hit_log.pop_front()
	if p == null or is_nan(amount) or amount <= 0.0:
		return
	var capped: float = PvpRulesScript.incoming_cap(amount, float(p.get("max_health")), float(p.get("item_shield_max")))
	PvpRulesScript.note_combat()
	if p.has_method("take_pvp_damage"):
		p.call("take_pvp_damage", capped, sender, is_crit)


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_cc(kind: String, duration: float, dir: Vector2, force: float) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	var p: Node2D = victim_check(sender)
	if p == null or is_nan(duration) or is_nan(force):
		return
	match kind:
		"stun":
			if p.has_method("apply_stun"):
				var stun_secs: float = PvpRulesScript.cc_register(duration)
				if stun_secs > 0.0:
					p.call("apply_stun", stun_secs)
		"slow": ## force = yavaşlatma oranı (0-1): yavaşlatma / kök / korku / buz (madde 617)
			if p.has_method("apply_pvp_slow"):
				var slow_secs: float = PvpRulesScript.cc_register(duration)
				if slow_secs > 0.0:
					p.call("apply_pvp_slow", clampf(force, 0.0, 0.9), slow_secs)
		"knock":
			if p.has_method("apply_knockback_force"):
				p.call("apply_knockback_force", dir, clampf(force * PvpRulesScript.CC_MULT, 0.0, 400.0))


## Kurban tarafı doğrulaması (hasar + kontrol ortak): gönderen RAKİP takımdan, hazırlık bitti, ikisi de üste değil, kurban canlı, mesafe makul.
## Geçerliyse yerel oyuncu, değilse null. Statik değil: kuklayı sahne ağacından bulur.
func victim_check(sender: int) -> Node2D:
	if sender <= 0 or not GameModeScript.is_pvp() or not TeamsScript.is_enemy(sender, TeamsScript.local_peer()):
		return null
	var nm: Node = _nm()
	if nm != null and nm.has_method("_from_unadmitted_peer") and bool(nm.call("_from_unadmitted_peer")):
		return null ## doğrulanmamış eş (madde 613) oyuncuya hasar yazamaz
	if not PvpRulesScript.fighting():
		return null
	var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p) or p.get("is_dead") == true:
		return null
	var attacker: Node2D = null
	for rp: Node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and int(rp.get("peer_id")) == sender:
			attacker = rp as Node2D
			break
	if attacker == null or attacker.global_position.distance_to(p.global_position) > PvpRulesScript.MAX_HIT_RANGE:
		return null
	if BaseZonesScript.shelters(p.global_position) or BaseZonesScript.shelters(attacker.global_position):
		return null ## üste PvP yok (plan 2.2): ne içeriden ne dışarıdan
	if PvpRulesScript.respawn_protected(BaseZonesScript.in_own_base(p.global_position, TeamsScript.local_team())):
		return null ## üste doğduktan sonra ilk çıkışta 3 sn dokunulmaz (plan 2.1)
	return p


## ---------------------------------------------------------------- ÖLÜM / SKOR / ZAFER (Aşama 4, madde 617)
## Host yetkili: kurban kendi ölümünü bildirir (öldüren = son 8 sn içinde ona en son oyuncu hasarı vuran; 0 = yaratık / çevre), host skoru + altını +
## eleme kararını verir, herkese `_rpc_score` (öldürme bildirimi dahil) ve gerekirse `_rpc_match_end` yayınlar.
var _streaks: Dictionary = {} ## host: peer -> ölmeden önceki öldürme serisi
var _xp_states: Array = [] ## host: takım -> {"xp","needed","level"} (takım başına ayrı XP / seviye, plan K3)
var _xp_dirty: Array = [false, false]
var _xp_sync_t: float = 0.0
const XP_SYNC_EVERY := 0.25


func _process(delta: float) -> void:
	if _xp_states.is_empty() or not _is_mp_host():
		return
	_xp_sync_t += delta
	if _xp_sync_t < XP_SYNC_EVERY:
		return
	_xp_sync_t = 0.0
	for t in 2:
		if _xp_dirty[t]:
			_xp_dirty[t] = false
			_push_xp(t)


## Kurban: bu makinedeki oyuncu öldü (kalp harcandı ya da kalıcı); killer_peer 0 = oyuncu öldürmedi.
func report_death(killer_peer: int) -> void:
	if not GameModeScript.is_pvp():
		return
	if _is_mp_host() or not _mp_active():
		_host_register_death(TeamsScript.local_peer(), killer_peer)
		return
	var nm: Node = _nm()
	var host_id: int = int(nm.call("_host_peer_id"))
	if host_id > 0:
		_rpc_report_death.rpc_id(host_id, killer_peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_death(killer_peer: int) -> void:
	var nm: Node = _nm()
	if not _is_mp_host() or (nm.has_method("_from_unadmitted_peer") and bool(nm.call("_from_unadmitted_peer"))):
		return
	_host_register_death(multiplayer.get_remote_sender_id(), killer_peer)


func _host_register_death(victim: int, killer: int) -> void:
	if GameManager.is_game_over or victim <= 0:
		return
	var nm: Node = _nm()
	var lobby: Dictionary = (nm.get("lobby_players") as Dictionary) if nm != null else {}
	if _mp_active() and not lobby.has(victim):
		return
	peer_deaths[victim] = int(peer_deaths.get(victim, 0)) + 1
	var victim_streak: int = int(_streaks.get(victim, 0))
	_streaks[victim] = 0
	var credited: int = 0
	var gold: int = 0
	if killer > 0 and killer != victim and TeamsScript.is_enemy(killer, victim) and (not _mp_active() or lobby.has(killer)):
		credited = killer
		peer_kills[killer] = int(peer_kills.get(killer, 0)) + 1
		var kt: int = clampi(TeamsScript.team_of(killer), 0, 1)
		team_kills[kt] = int(team_kills[kt]) + 1
		_streaks[killer] = int(_streaks.get(killer, 0)) + 1
		gold = PvpRulesScript.kill_gold(GameManager.run_max_tier, victim_streak)
		_pay(killer, gold)
	_broadcast_score(credited, victim, gold)


## Host: peer'in kişisel altınına ekler (host'un kendisi yerel yoldan, altın karakterin üstünde "+N" olarak görünür).
func _pay(peer: int, amount: int) -> void:
	if amount <= 0:
		return
	if peer == TeamsScript.local_peer() or not _mp_active():
		var p: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			preload("res://scripts/kill_gold.gd").credit(get_tree(), amount, p.global_position)
		else:
			GameManager.gold += amount
		return
	_nm().grant_personal_gold.rpc_id(peer, amount)


func _broadcast_score(killer: int, victim: int, gold: int) -> void:
	if _mp_active():
		_rpc_score.rpc(team_kills, team_levels, peer_kills, peer_deaths, killer, victim, gold)
	else:
		_apply_score(team_kills, team_levels, peer_kills, peer_deaths, killer, victim, gold)


@rpc("any_peer", "call_local", "reliable")
func _rpc_score(kills: Array, levels: Array, pk: Dictionary, pd: Dictionary, killer: int, victim: int, gold: int) -> void:
	if not _sender_is_host():
		return
	_apply_score(kills, levels, pk, pd, killer, victim, gold)


func _apply_score(kills: Array, levels: Array, pk: Dictionary, pd: Dictionary, killer: int, victim: int, gold: int) -> void:
	team_kills = [int(kills[0]), int(kills[1])] if kills.size() >= 2 else [0, 0]
	team_levels = [int(levels[0]), int(levels[1])] if levels.size() >= 2 else [1, 1]
	peer_kills = pk.duplicate()
	peer_deaths = pd.duplicate()
	score_changed.emit()
	if victim > 0:
		kill_feed.emit(killer, victim, gold)


## Host: ölen / kopan oyuncudan sonra bir takım tamamen elendi mi (NetworkManager._check_all_players_dead PvP'de buraya yönlenir).
func host_check_elimination() -> void:
	if GameManager.is_game_over:
		return
	var nm: Node = _nm()
	if nm == null:
		return
	var lobby: Dictionary = nm.get("lobby_players")
	var winner: int = PvpRulesScript.eliminated_winner(TeamsScript.by_peer, lobby.keys(), nm.get("_confirmed_dead_peers"))
	if winner != -1:
		var left: bool = false ## bir takımın bütün oyuncuları odadan ayrıldı (ölmedi): "left"
		for t in 2:
			var any_in_lobby: bool = false
			for p in lobby.keys():
				if TeamsScript.team_of(int(p)) == t:
					any_in_lobby = true
			if not any_in_lobby:
				left = true
		host_end_match(winner, "left" if left else "eliminated")


## Host: maçı bitirir (eleme / K10 bossu / teslim / takım kopması). Herkese `_rpc_match_end`; tek oyunculu geliştirme kipinde yerelde uygular.
func host_end_match(winner: int, reason: String) -> void:
	if GameManager.is_game_over:
		return
	if _mp_active():
		if _is_mp_host():
			_rpc_match_end.rpc(winner, reason)
	else:
		_apply_match_end(winner, reason)


@rpc("any_peer", "call_local", "reliable")
func _rpc_match_end(winner: int, reason: String) -> void:
	if not _sender_is_host():
		return
	_apply_match_end(winner, reason)


func _apply_match_end(winner: int, reason: String) -> void:
	if winner_team != -1 and GameManager.is_game_over:
		return
	winner_team = winner
	end_reason = reason
	GameManager.is_game_over = true
	match_ended.emit(winner, reason)
	var nm: Node = _nm()
	if nm != null and nm.has_signal("game_over_synced"):
		nm.game_over_synced.emit() ## oyun bitti ekranı + istatistik yayını (main.gd _on_game_over_synced) PvP başlığını winner_team'den okur


## Host: K10 bossu (haritanın son bossu) öldü -> son vuruşu yapan takım kazanır (plan K1 b). Vuran bilinmezse çok öldüren takım, eşitse 0.
func host_final_boss_killed(attacker_peer: int) -> void:
	var winner: int
	if attacker_peer > 0:
		winner = TeamsScript.team_of(attacker_peer)
	else:
		winner = 1 if int(team_kills[1]) > int(team_kills[0]) else 0
	host_end_match(winner, "boss")


## Host: K5 bossu öldü -> son vuruşu yapan takım üç dakika güç kazanır (plan K8, saldırı hızı).
func host_boss_defeated(attacker_peer: int) -> void:
	if attacker_peer <= 0 or not GameModeScript.is_pvp():
		return
	var team: int = TeamsScript.team_of(attacker_peer)
	if _mp_active():
		_rpc_boss_buff.rpc(team)
	else:
		_apply_boss_buff(team)


@rpc("any_peer", "call_local", "reliable")
func _rpc_boss_buff(team: int) -> void:
	if not _sender_is_host():
		return
	_apply_boss_buff(team)


func _apply_boss_buff(team: int) -> void:
	var own: bool = team == TeamsScript.local_team()
	if own:
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("apply_evo_buff"):
			p.call("apply_evo_buff", "atk_speed", PvpRulesScript.BOSS_BUFF_ATTACK_SPEED, PvpRulesScript.BOSS_BUFF_SECONDS)
	boss_buff.emit(team, own)


## ---------- Takım başına XP / seviye (plan K3): host iki takımın durumunu ayrı tutar, her takıma yalnız kendi durumunu yollar.
func _ensure_xp_states() -> void:
	if _xp_states.is_empty():
		for t in 2:
			_xp_states.append({"xp": 0.0, "needed": GameManager._xp_needed_for_level(1), "level": 1})


## Host: `collector` takımının XP'sine ekler (NetworkManager.host_collect_xp PvP'de buraya yönlenir).
func host_collect_xp(amount: float, collector: int) -> void:
	if amount <= 0.0 or GameManager.is_game_over:
		return
	_ensure_xp_states()
	var t: int = clampi(TeamsScript.team_of(collector if collector > 0 else TeamsScript.local_peer()), 0, 1)
	var st: Dictionary = _xp_states[t]
	st["xp"] = float(st["xp"]) + amount
	var leveled: bool = false
	while float(st["xp"]) >= float(st["needed"]):
		st["xp"] = float(st["xp"]) - float(st["needed"])
		st["level"] = int(st["level"]) + 1
		st["needed"] = GameManager._xp_needed_for_level(int(st["level"]))
		leveled = true
	team_levels[t] = int(st["level"])
	if leveled:
		_xp_dirty[t] = false
		_push_xp(t)
		_broadcast_score(0, 0, 0)
	else:
		_xp_dirty[t] = true


func _push_xp(t: int) -> void:
	var st: Dictionary = _xp_states[t]
	var local: int = TeamsScript.local_peer()
	if not _mp_active():
		if t == TeamsScript.local_team():
			GameManager.set_team_xp_state(float(st["xp"]), float(st["needed"]), int(st["level"]))
		return
	for peer in TeamsScript.members(t):
		if int(peer) == local or not _mp_active():
			GameManager.set_team_xp_state(float(st["xp"]), float(st["needed"]), int(st["level"]))
		else:
			_nm().sync_team_xp.rpc_id(int(peer), float(st["xp"]), float(st["needed"]), int(st["level"]))


## Host: bu peer'in takımının XP durumu [seviye, xp, gereken] (geri katılım anlık görüntüsü); PvP değilse boş.
func xp_triplet_for(peer: int) -> Array:
	if not GameModeScript.is_pvp() or _xp_states.is_empty():
		return []
	var st: Dictionary = _xp_states[clampi(TeamsScript.team_of(peer), 0, 1)]
	return [int(st["level"]), float(st["xp"]), float(st["needed"])]


## İki takımın en yüksek seviyesi (yaratık zorluk ölçeği takım seviyesine bakar: PvP'de ikisinin yükseği).
static func top_team_level() -> int:
	return maxi(int(team_levels[0]), int(team_levels[1]))


static func clear_match() -> void:
	bases = []
	camp_radius = 0.0
	team_kills = [0, 0]
	team_levels = [1, 1]
	peer_kills = {}
	peer_deaths = {}
	winner_team = -1
	end_reason = ""
	PvpRulesScript.end_match()
