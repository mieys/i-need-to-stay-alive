extends RefCounted

## TOPLAYICI ruhani yeteneğinin (spiritual_skills.gd TOPLAYICI, madde 625) çekiş kuralları - TEK kaynak.
## Kim çağırır: player.gd _process_toplayici (sahibin makinesi) -> NetworkManager.request_toplayici_pull / tek oyunculuda doğrudan
## apply(); host pick() ile seçer, apply() ile kendi GERÇEK kürelerini çeker ve kimlik listesini yayınlar (sync_toplayici_pull),
## istemciler kendi GÖRSEL kopyalarını aynı oyuncuya çeker (apply_ids). Kesme (2v2, rakipten hasar) release() / release_ids yolu.
##
## Kurallar (kullanıcı 2026-11-12: "diğer oyunculara haksızlık olmaz mı" / "pvpde nasıl dengelenecek"):
## - YALNIZ XP kristali (altın/yiyecek toplayanın kişisel kazancı, çekilmez).
## - Çekilen kürede toplayanın XP bonusu işlemez (PULLED_META -> xp_orb.gd gain_mult_for 1.0).
## - 2v2: küre öldürenin takımını taşır (KILL_TEAM_META, yalnız host'un gerçek küresinde); yalnız kendi takımının küresi çekilir.

const ProjectileRange := preload("res://scripts/projectile_range.gd")
const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const BalanceLogScript := preload("res://scripts/balance_log.gd")

const PULLED_META := &"toplayici_pulled" ## küre Toplayıcı çekişiyle geliyor: XP bonusu işlemez
const PULL_PEER_META := &"toplayici_peer" ## çeken oyuncunun peer'i (kesmede yalnız onun küreleri bırakılır)
const KILL_TEAM_META := &"kill_team" ## 2v2: küreyi düşüren öldürmenin takımı (host)


## 2v2'de öldüren peer'in takımı (küreye yazılır); ortak modda -1 (etiket yok). peer <= 0 = host'un kendi öldürmesi.
static func kill_team_of(killer_peer: int) -> int:
	if not GameModeScript.is_pvp():
		return -1
	return TeamsScript.team_of(killer_peer if killer_peer > 0 else TeamsScript.local_peer())


## Bu küre bu takımın çekişine uygun mu (ortak modda hep; 2v2'de etiket aynı takım olmalı, etiketsiz küre çekilmez).
static func team_allows(orb: Node, collector_team: int) -> bool:
	if not GameModeScript.is_pvp():
		return true
	return int(orb.get_meta(KILL_TEAM_META, -1)) == collector_team


## Çekilebilecek küreler: center'daki oyuncunun görüş elipsinde, alınmamış, başka bir mıknatısa bağlanmamış (host/tek oyunculu: GERÇEK küre).
static func pick(tree: SceneTree, center: Vector2, collector_team: int) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for orb: Node in tree.get_nodes_in_group("xp_orbs"):
		if not is_instance_valid(orb) or not (orb is Node2D) or orb.is_queued_for_deletion():
			continue
		if orb.get_meta("network_spawned", false) or orb.get_meta("claimed", false) or orb.get("is_magnetized") == true:
			continue
		if not team_allows(orb, collector_team):
			continue
		out.append(orb) ## 2026-11-15: görüş sınırı kalktı - haritadaki HER XP kristali çekilir
	return out


## Sahibin makinesinde: haritada çekilecek bir şey var mı (istemci görsel kopyalara bakar - takım etiketi host'ta, son söz host'un).
static func any_visible(tree: SceneTree, _center: Vector2) -> bool:
	if tree == null:
		return false
	for orb: Node in tree.get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb) and orb is Node2D and orb.get("is_magnetized") != true and not orb.get_meta("claimed", false):
			return true
	return false


## collector_peer -1 = tek oyunculu (yerel oyuncu). Sayaç ("BU OYUNDA", madde 531) yalnız çekenin kendi makinesinde yazılır.
static func apply(orbs: Array, collector_peer: int) -> void:
	var n: int = 0
	var xp: float = 0.0
	for orb in orbs:
		if is_instance_valid(orb) and orb.has_method("attract_to_player"):
			(orb as Node).set_meta(PULLED_META, true)
			(orb as Node).set_meta(PULL_PEER_META, collector_peer)
			orb.call("attract_to_player", collector_peer)
			n += 1
			xp += float(orb.get("xp_value"))
	if n > 0 and (collector_peer < 0 or collector_peer == TeamsScript.local_peer()):
		BalanceLogScript.on_util("s:ruhani_toplayici", "orbs", n)
		BalanceLogScript.on_util("s:ruhani_toplayici", "xp_pulled", int(round(xp)))


static func ids_of(orbs: Array) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for orb in orbs:
		if is_instance_valid(orb):
			var id: int = int((orb as Node).get_meta("drop_network_id", 0))
			if id > 0:
				ids.append(id)
	return ids


## Kesme: bu peer'e Toplayıcı çekişiyle giden küreler olduğu yerde kalır (normal toplama menzili yine çalışır).
static func release(tree: SceneTree, collector_peer: int) -> int:
	var n: int = 0
	if tree == null:
		return n
	for orb: Node in tree.get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb) and orb.has_meta(PULL_PEER_META) and int(orb.get_meta(PULL_PEER_META)) == collector_peer \
				and orb.has_method("release_pull"):
			orb.call("release_pull")
			n += 1
	return n
