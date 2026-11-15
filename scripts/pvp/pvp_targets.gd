extends Node

## PvP HEDEFLERİ YÖNETİCİSİ (PvPvE Aşama 2, madde 615). Yalnız PvP modunda Main'e eklenir (main.gd, TeamBases'in yanında). Görevleri:
## - Rakip takımdaki her RemotePlayer kuklası için bir vekil (pvp_target.gd) kurar, kukla gidince / takım değişince siler (0,25 sn'de bir denetim).
##   Takım arkadaşı için vekil YOK: dost ateşi yok (plan K6), müttefik süzgeci hiçbir şey bilmeden çalışır.
## - Hazırlık süresi (K2): maç başlangıcını PvpRules.match_start_msec'e yazar, başta "HAZIRLIK" / bitince "PVP BAŞLADI" bildirimi.
## Co-op'ta kurulmaz, hiçbir şey değişmez.

const PvpTargetScript := preload("res://scripts/pvp/pvp_target.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const PvpRulesScript := preload("res://scripts/pvp/pvp_rules.gd")
const PvpNetScript := preload("res://scripts/pvp/pvp_net.gd")
const PvpScoreStripScript := preload("res://scripts/pvp/pvp_score_strip.gd")

const CHECK_EVERY := 0.25

var _proxies: Dictionary = {} ## peer -> vekil
var _check_t: float = 0.0
var _announced_prep: bool = false
var _announced_start: bool = false


func _ready() -> void:
	PvpRulesScript.begin_match()
	var strip: CanvasLayer = PvpScoreStripScript.new() ## üst orta skor şeridi (madde 617)
	strip.name = "PvpScoreStrip"
	add_child(strip)
	var net: Node = PvpNetScript.instance()
	if net != null:
		net.kill_feed.connect(_on_kill_feed)
		net.boss_buff.connect(_on_boss_buff)


## Öldürme bildirimi (sağ sütun levhası): öldüren ben / öldürülen ben / üçüncü kişiler. killer 0 = oyuncu öldürmedi (yaratık / çevre): yalnız arkadaşın ölümü.
func _on_kill_feed(killer: int, victim: int, gold: int) -> void:
	var main: Node = get_parent()
	if main == null or not main.has_method("_show_notice"):
		return
	var me: int = TeamsScript.local_peer()
	var nm: Node = get_node_or_null("/root/NetworkManager")
	var victim_name: String = str(nm.call("get_player_names", [victim])) if nm != null else str(victim)
	if killer <= 0:
		if victim != me and TeamsScript.is_ally(victim, me):
			main.call("_show_notice", "left", tr("%s düştü") % victim_name, "", 2.6)
		return
	var killer_name: String = str(nm.call("get_player_names", [killer])) if nm != null else str(killer)
	if killer == me:
		main.call("_show_notice", "info", tr("RAKİP ELENDİ"), "%s  +%d" % [victim_name, gold], 3.0)
	elif victim == me:
		main.call("_show_notice", "fail", tr("%s seni öldürdü") % killer_name, "", 3.0)
	else:
		main.call("_show_notice", "info", "%s  >  %s" % [killer_name, victim_name], "", 2.6)


## K5 bossunu bir takım aldı (üç dakikalık güç).
func _on_boss_buff(_team: int, own: bool) -> void:
	var main: Node = get_parent()
	if main == null or not main.has_method("_show_notice"):
		return
	if own:
		main.call("_show_notice", "info", tr("BOSS YIKILDI"), tr("Takımın 3 dk güçlendi"), 4.0)
	else:
		main.call("_show_notice", "fail", tr("RAKİP TAKIM BOSSU ALDI"), tr("3 dk güçlendiler"), 4.0)


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	_sync_proxies()
	_announce()


func _sync_proxies() -> void:
	var tree: SceneTree = get_tree()
	var local_team: int = TeamsScript.local_team()
	var seen: Dictionary = {}
	for rp: Node in tree.get_nodes_in_group("remote_players"):
		if not is_instance_valid(rp) or not (rp is Node2D):
			continue
		var pid: int = int(rp.get("peer_id"))
		if pid <= 0 or TeamsScript.team_of(pid) == local_team:
			continue
		seen[pid] = true
		var existing: Node = _proxies.get(pid)
		if existing != null and is_instance_valid(existing) and existing.get("rival") == rp:
			continue
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		var proxy: Node = PvpTargetScript.new()
		(proxy as Object).call("bind", rp, pid)
		get_parent().add_child(proxy)
		_proxies[pid] = proxy
	for pid in _proxies.keys():
		if not seen.has(pid):
			var gone: Node = _proxies[pid]
			if is_instance_valid(gone):
				gone.queue_free()
			_proxies.erase(pid)


func _announce() -> void:
	var main: Node = get_parent()
	if main == null or not main.has_method("_show_notice"):
		return
	var left: float = PvpRulesScript.prep_left_now()
	if not _announced_prep and left > 0.0:
		_announced_prep = true
		main.call("_show_notice", "left", "HAZIRLIK SÜRESİ", tr("PvP %d sn sonra açılır") % int(ceil(left)), 3.0)
	elif not _announced_start and _announced_prep and left <= 0.0:
		_announced_start = true
		main.call("_show_notice", "tier", "PVP BAŞLADI", "Rakip takıma saldırabilirsin", 3.0)


func _exit_tree() -> void:
	for pid in _proxies.keys():
		var p: Node = _proxies[pid]
		if is_instance_valid(p):
			p.queue_free()
	_proxies.clear()
