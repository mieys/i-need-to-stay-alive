extends RefCounted

## ASİST sistemi (kullanıcı isteği 2026-10-15, LoL tarzı): bir yaratığı birden fazla oyuncu öldürürken öldürmeyen ama katkı veren oyuncu
## yaratığın altınından pay alır. Katkı iki türlü:
##  - HASAR: yaratığa öldürmeden önceki son WINDOW_SEC içinde vurmuş (enemy.gd _assist_damage; payı hasar oranı kadar).
##  - DESTEK: öldüren/hasar veren bir oyuncuya can/kalkan bastı, buff verdi, bağ kurdu (note_support) ya da Şovalye E (Koruma Bariyeri) /
##    R (kubbe) ile onu korudu (poll_paladins saniyede bir kaydeder).
## TÜM asistler etki veren şeyden SONRAKİ WINDOW_SEC (8) saniye boyunca sürer (kullanıcı 2026-10-15): süreli etkilerde (buff, bariyer, bağ)
## pencere etkinin BİTİŞİNDEN sonra başlar.
## Altın bölüşümü compute(): toplam MIN_GOLD_TO_SPLIT'ten azsa bölünmez (öldürene tam). Aksi halde öldüren en az KILLER_MIN_FRAC alır;
## kalanı asist yapanlar ağırlıklarıyla (hasar payı; destek = en az SUPPORT_WEIGHT) paylaşır, 1 altına yetmeyen pay öldürende kalır.
## Hepsi SADECE host'ta çalışır (altını host dağıtır). class_name YOK (headless'ta global sınıf önbelleği güncellenmiyor).

const WINDOW_SEC := 8.0
const MIN_GOLD_TO_SPLIT := 4
const KILLER_MIN_FRAC := 0.5
const SUPPORT_WEIGHT := 0.2
const PALADIN_GUARD_RANGE := 400.0 ## player.gd PALADIN_BARRIER_BREAK_RANGE (E bariyeri bu mesafede kopar)
const PALADIN_ZONE_RADIUS := 126.0 ## player.gd PALADIN_ULTI_ZONE_RADIUS (kuklada paladin_zone_radius yoksa)
## Asist türü bayrakları (KillGold.award/grant_kill_gold + balans kaydı): 1 = hasar asisti, 2 = destek asisti, 3 = ikisi.
const KIND_DAMAGE := 1
const KIND_SUPPORT := 2
const MAX_HOLD := 15.0 ## uzak oyuncunun bildirdiği süreli buff etkisi en çok bu kadar sürer (taşan/sahte değer sınırı)

## "destekleyen:hedef" -> {"sup", "tgt", "until"} (msec). Süresi dolanlar active_support'ta temizlenir.
static var _support: Dictionary = {}


static func reset() -> void:
	_support.clear()


## supporter, target'a destek verdi (hold = etkisi sürüyorsa kalan süre: bariyer, bağ, süreli buff). Pencere hold'un BİTİŞİNDEN sonra başlar.
static func note_support(supporter: int, target: int, hold: float = 0.0, now_msec: int = -1) -> void:
	if supporter <= 0 or target <= 0 or supporter == target:
		return
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var until: int = now_msec + int((clampf(hold, 0.0, MAX_HOLD) + WINDOW_SEC) * 1000.0)
	var key: String = "%d:%d" % [supporter, target]
	var cur: Dictionary = _support.get(key, {})
	if int(cur.get("until", 0)) < until:
		_support[key] = {"sup": supporter, "tgt": target, "until": until}


## Destekleyen -> hedef listesi (süresi dolmamış kayıtlar).
static func active_support(now_msec: int = -1) -> Dictionary:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var out: Dictionary = {}
	for key in _support.keys():
		var e: Dictionary = _support[key]
		if int(e["until"]) < now_msec:
			_support.erase(key)
			continue
		var list: Array = out.get(int(e["sup"]), [])
		list.append(int(e["tgt"]))
		out[int(e["sup"])] = list
	return out


## Öldürme anında Şovalye E (guard) / R (kubbe) ile birini koruyanlar: destekleyen -> [korunan peer'ler]. Host'ta yerel oyuncu + kuklalar.
static func paladin_support(tree: SceneTree) -> Dictionary:
	var out: Dictionary = {}
	if tree == null or not NetworkManager.is_multiplayer_active:
		return out
	var nodes: Array = []
	for n in tree.get_nodes_in_group("player") + tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(n) and n is Node2D and n.get("is_dead") != true:
			nodes.append(n)
	for p in nodes:
		var pid: int = _peer_of(p)
		if pid <= 0:
			continue
		var guard: bool = p.get("paladin_guard_active") == true
		var zone: bool = p.get("paladin_zone_active") == true
		if not guard and not zone:
			continue
		var zr: float = float(p.get("paladin_zone_radius")) if p.get("paladin_zone_radius") != null else PALADIN_ZONE_RADIUS
		for a in nodes:
			if a == p:
				continue
			var aid: int = _peer_of(a)
			if aid <= 0 or aid == pid:
				continue
			var d: float = (p as Node2D).global_position.distance_to((a as Node2D).global_position)
			var covered: bool = guard and d <= PALADIN_GUARD_RANGE
			if not covered and zone:
				covered = _zone_contains((p as Node2D).global_position, zr, (a as Node2D).global_position)
			if covered:
				var list: Array = out.get(pid, [])
				list.append(aid)
				out[pid] = list
	return out


## Host: Şovalye E/R'nin o an koruduğu dostları destek kaydına işler (saniyede bir çağrılır) - koruma bitince pencere WINDOW_SEC daha sürer.
static func poll_paladins(tree: SceneTree) -> void:
	var cover: Dictionary = paladin_support(tree)
	for sup in cover.keys():
		for tgt in cover[sup]:
			note_support(int(sup), int(tgt))


static func _zone_contains(center: Vector2, r: float, pos: Vector2) -> bool:
	var d: Vector2 = pos - center
	var u: float = d.length()
	if u < 0.0001:
		return true
	var n: Vector2 = d / u
	var k: float = n.x * n.x + n.y * n.y * 4.0 ## dikey yarıçap = r/2 (paladin_dome.gd Y_MULT 0.5)
	return u <= r / sqrt(k)


static func _peer_of(node: Node) -> int:
	if node.is_in_group("player"):
		return NetworkManager.multiplayer.get_unique_id() if NetworkManager.multiplayer.has_multiplayer_peer() else 1
	return int(node.get("peer_id")) if "peer_id" in node else 0


## Saf bölüşüm (test edilebilir). damage: {peer: {"dmg": float, "t": msec}}, support: {destekleyen: [hedef peer'ler]}.
## Döner: {peer: altın}; toplam her zaman `total`, öldüren (killer) her zaman en az yarısını alır.
static func compute(total: int, killer: int, damage: Dictionary, support: Dictionary, now_msec: int = -1, kinds_out: Dictionary = {}) -> Dictionary:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var solo: Dictionary = {killer: total}
	if total < MIN_GOLD_TO_SPLIT or killer <= 0:
		return solo
	var total_dmg: float = 0.0
	for pid in damage.keys():
		total_dmg += float((damage[pid] as Dictionary).get("dmg", 0.0))
	if total_dmg <= 0.0:
		return solo
	var killer_w: float = float((damage.get(killer, {}) as Dictionary).get("dmg", 0.0)) / total_dmg
	var weights: Dictionary = {}
	var participants: Array = [killer]
	for pid in damage.keys():
		if int(pid) == killer:
			continue
		var d: Dictionary = damage[pid]
		var share: float = float(d.get("dmg", 0.0)) / total_dmg
		var recent: bool = now_msec - int(d.get("t", -1000000)) <= int(WINDOW_SEC * 1000.0)
		if recent and share > 0.0:
			weights[int(pid)] = share
			kinds_out[int(pid)] = KIND_DAMAGE
			participants.append(int(pid))
	for sup in support.keys():
		var s: int = int(sup)
		if s == killer:
			continue
		for tgt in support[sup]:
			if participants.has(int(tgt)):
				weights[s] = maxf(float(weights.get(s, 0.0)), SUPPORT_WEIGHT)
				kinds_out[s] = int(kinds_out.get(s, 0)) | KIND_SUPPORT
				break
	if weights.is_empty():
		return solo
	var sum_assist: float = 0.0
	for pid in weights.keys():
		sum_assist += float(weights[pid])
	var killer_frac: float = maxf(KILLER_MIN_FRAC, killer_w / (killer_w + sum_assist))
	var pool: float = float(total) * (1.0 - killer_frac)
	var out: Dictionary = {}
	var given: int = 0
	for pid in weights.keys():
		var amt: int = int(floor(pool * float(weights[pid]) / sum_assist))
		if amt >= 1:
			out[int(pid)] = amt
			given += amt
	out[killer] = total - given
	return out
