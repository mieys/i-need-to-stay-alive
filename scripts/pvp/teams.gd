extends RefCounted

## TAKIMLAR (PvPvE, madde 607): peer id -> takım (0 / 1). Host yetkili: lobi değiştikçe yeni gelen oyuncu az kişili takıma girer, var olanların
## takımı kendiliğinden değişmez (pvp_net.gd yayınlar); oyuncu seçim ekranında istediği takıma geçebilir (`try_move`, madde 608).
## Co-op'ta (ya da PvP kapalıyken) herkes 0. takımdadır: müttefik soruları bugünkü cevabı verir.
## TEK OYUNCULU + MOD=pvp (geliştirme): yerel oyuncu 0. takım.

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")

const TEAM_COUNT := 2
## Takım adları (kamp sancağı / bildirim). Renkler hud_theme.gd TEAM_* rollerinde.
const NAMES: Array[String] = ["Mavi", "Kızıl"]
## Seçim ekranı takım başlıkları (büyük harf: Türkçe İ yüzünden to_upper() kullanılmaz).
const TITLES: Array[String] = ["MAVİ TAKIM", "KIZIL TAKIM"]

static var by_peer: Dictionary = {}


static func team_of(peer: int) -> int:
	if not GameModeScript.is_pvp():
		return 0
	return int(by_peer.get(peer, 0))


static func local_peer() -> int:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root.multiplayer.has_multiplayer_peer():
		return (loop as SceneTree).root.multiplayer.get_unique_id()
	return 1


static func local_team() -> int:
	return team_of(local_peer())


static func is_ally(a: int, b: int) -> bool:
	return team_of(a) == team_of(b)


static func is_enemy(a: int, b: int) -> bool:
	return not is_ally(a, b)


static func members(team: int) -> Array:
	var out: Array = []
	for p in by_peer:
		if int(by_peer[p]) == team:
			out.append(int(p))
	return out


## Saf kural (test edilir): var olan atamalar korunur, artık olmayan eşler düşer, yeni eş az kişili takıma (eşitse 0'a) girer.
## Sıra: peers listesinin sırası (lobi = katılma sırası) -> host 0, ikinci gelen 1, üçüncü 0, dördüncü 1.
static func balanced_assign(current: Dictionary, peers: Array) -> Dictionary:
	var out: Dictionary = {}
	var counts: Array[int] = [0, 0]
	for p in peers:
		var pid: int = int(p)
		if current.has(pid):
			var t: int = clampi(int(current[pid]), 0, TEAM_COUNT - 1)
			out[pid] = t
			counts[t] += 1
	for p in peers:
		var pid: int = int(p)
		if out.has(pid):
			continue
		var t: int = 0 if counts[0] <= counts[1] else 1
		out[pid] = t
		counts[t] += 1
	return out


## Bir takımın alabileceği en çok oyuncu: odanın yarısı (yukarı yuvarlanır). 8 kişilik odada 4, 4 kişilikte 2.
static func team_capacity(room_max: int) -> int:
	return maxi(1, ceili(float(room_max) / float(TEAM_COUNT)))


static func count_in(assign: Dictionary, team: int) -> int:
	var n: int = 0
	for p in assign:
		if int(assign[p]) == team:
			n += 1
	return n


## Saf kural (test edilir): oyuncu kendi isteğiyle takım değiştirir. Geçersiz takım, zaten orada olmak, odada olmayan eş ya da dolu hedef takım
## = değişmez. Dönen sözlük hep `balanced_assign` çıktısıdır (yeni gelenler de yerleşmiş olur), böylece çağıran tek sözlüğü uygular.
static func try_move(current: Dictionary, peers: Array, peer: int, team: int, capacity: int) -> Dictionary:
	var out: Dictionary = balanced_assign(current, peers)
	if not out.has(peer) or team < 0 or team >= TEAM_COUNT or int(out[peer]) == team:
		return out
	if count_in(out, team) >= capacity:
		return out
	out[peer] = team
	return out


## Başlatma kuralı: PvP'de iki takımda da en az bir oyuncu olmalı (serbest takım seçimiyle herkes aynı takıma geçebilir; boş takımın üssü
## ve rakibi olmazdı). Boş string = başlatılabilir. Saf: atamayı ve mod bilgisini dışarıdan alır.
static func start_block_reason(pvp: bool, assign: Dictionary, peers: Array) -> String:
	if not pvp or peers.size() < 2:
		return ""
	var counts: Array[int] = [0, 0]
	for p in peers:
		counts[clampi(int(assign.get(int(p), 0)), 0, TEAM_COUNT - 1)] += 1
	if counts[0] == 0 or counts[1] == 0:
		return "Her iki takımda da en az 1 oyuncu olmalı"
	return ""


## Seçim ekranı / host başlat düğmesi için kısayol: odanın güncel oyuncuları + takımlarıyla `start_block_reason`.
static func lobby_start_block() -> String:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return ""
	var nm: Node = (loop as SceneTree).root.get_node_or_null("NetworkManager")
	if nm == null:
		return ""
	return start_block_reason(GameModeScript.is_pvp(), by_peer, (nm.get("lobby_players") as Dictionary).keys())


static func set_all(d: Dictionary) -> void:
	by_peer = {}
	for p in d:
		by_peer[int(p)] = clampi(int(d[p]), 0, TEAM_COUNT - 1)


static func reset() -> void:
	by_peer = {}
