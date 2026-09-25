extends RefCounted

## EFSUN ELEMENT TEPKİMELERİ (tasarım belgesi "Element sistemi" bölümü). SADECE host'ta (ya da tek oyunculuda) çalışır:
## düşmanın durumları (yanma/donma/zehir/kanama/şok) host'ta tutulur, enemy.gd bir element uygulanmadan ÖNCE hangi
## durumların aktif olduğunu (_element_snapshot) alır, uygulamadan SONRA buraya gelir. Yeni gelen element, zaten aktif
## olan her farklı elementle bir tepkime üretir. Hasar, tepkimeyi tetikleyen oyuncunun SG'sinden (enemy._reaction_ap)
## hesaplanır ve ona atfedilir (enemy._reaction_peer -> last_attacker_peer_id, bkz. _take_dot_damage).
## Görseller EnchantFx.play ile herkese yayınlanır (host yerel oynatır + RPC).

const EnchantFx := preload("res://scripts/enchant_fx.gd")
const EnchantArea := preload("res://scripts/enchant_area.gd")

const COOLDOWN_MSEC := 1000 ## aynı düşmanda aynı tepkime saniyede en fazla 1 kez
const MARK_AMP_PER_STACK := 0.03 ## İşaret güçlendirmesi (yük başına)

## Çift anahtarı alfabetik: "a+b".
const REACTIONS := {
	"donma+yanma": {"name": "Buhar Patlaması", "color": Color("#dfe9f0")},
	"yanma+zehir": {"name": "Zehirli Duman", "color": Color("#9fd65a")},
	"kanama+yanma": {"name": "Dağlama", "color": Color("#ff7a4a")},
	"sok+yanma": {"name": "Aşırı Yük", "color": Color("#ffd35a")},
	"donma+zehir": {"name": "Donmuş Zehir", "color": Color("#8fe0c8")},
	"donma+kanama": {"name": "Kristal Kan", "color": Color("#c8a0ff")},
	"donma+sok": {"name": "Parçalanma", "color": Color("#bfe6ff")},
	"kanama+zehir": {"name": "Enfeksiyon", "color": Color("#b8c24a")},
	"sok+zehir": {"name": "İletken Zehir", "color": Color("#d6f05a")},
	"kanama+sok": {"name": "Kan Akımı", "color": Color("#ff6a8a")},
}


static func pair_key(a: String, b: String) -> String:
	return (a + "+" + b) if a < b else (b + "+" + a)


## enemy.gd'den: incoming = yeni uygulanan element, had = uygulamadan ÖNCEKİ aktif durumlar.
static func resolve(e: Node, incoming: String, had: Dictionary) -> void:
	if not is_instance_valid(e) or e.get("is_dead") == true:
		return
	for other: String in had:
		if other == incoming or not bool(had[other]):
			continue
		trigger(e, pair_key(incoming, other))


static func trigger(e: Node, key: String) -> void:
	if not REACTIONS.has(key) or not is_instance_valid(e) or e.is_dead:
		return
	var now: int = Time.get_ticks_msec()
	if int(e._reaction_cd.get(key, 0)) > now:
		return
	e._reaction_cd[key] = now + COOLDOWN_MSEC
	var ap: float = e._reaction_attack_power()
	var mult: float = 1.0 + e._reaction_power
	## İşaret güçlendirmesi: işaretli düşmanda tepkime olursa yükler tükenir, tepkime yük başına +%3 güçlenir.
	if e.mark_stacks > 0:
		mult *= 1.0 + MARK_AMP_PER_STACK * float(e.mark_stacks)
		e.mark_stacks = 0
	var info: Dictionary = REACTIONS[key]
	var tree: SceneTree = e.get_tree()
	var pos: Vector2 = e.global_position
	EnchantFx.play(tree, "text", pos, {"text": str(info["name"]), "color": info["color"]})
	## Kaos Büyüsü IV (tepkime başına güçlenme) gibi efsunlar için tetikleyen oyuncuya haber.
	if e._reaction_peer > 0 or not NetworkManager.is_multiplayer_active:
		e._notify_enchant_owner(e._reaction_peer, "reaction", {"key": key})
	match key:
		"donma+yanma": ## Buhar Patlaması (Buhar Ustası seçenekleri: alan/yavaşlatma/yakma/sis - enemy._enchant_flags "steam")
			var so: Dictionary = e._enchant_flags.get("steam", {})
			var r: float = 80.0 * float(so.get("radius", 1.0))
			e._end_freeze_now()
			_area_damage(e, pos, r, ap * 0.6 * mult, true)
			for v in Enemy.get_enemies_near(tree, pos, r):
				if is_instance_valid(v) and not v.is_dead:
					v.apply_slow(float(so.get("slow", 0.3)), 1.0)
					if bool(so.get("burn", false)):
						v.apply_element_host("burn", {"tick": ap * 0.1, "dur": 3.0, "ap": ap, "quiet": true}, int(so.get("peer", e._reaction_peer)))
			if bool(so.get("fog", false)):
				EnchantArea.spawn(tree, "steam_fog", pos, {"radius": r, "duration": 4.0, "dps": ap * 0.3 * mult,
					"peer": int(so.get("peer", e._reaction_peer))}, true)
			EnchantFx.play(tree, "burst", pos, {"palette": "smoke", "count": 22, "speed": 170.0, "life": 0.6})
			EnchantFx.play(tree, "ring", pos, {"radius": r, "color": Color(0.9, 0.95, 1.0, 0.9)})
		"yanma+zehir": ## Zehirli Duman
			var dps: float = maxf(e._poison_dps_average(), ap * 0.02)
			EnchantArea.spawn(tree, "poison_cloud", pos, {"radius": 80.0, "duration": 3.0, "dps": dps * mult,
				"peer": e._reaction_peer, "ap": ap}, true)
		"kanama+yanma": ## Dağlama
			var burst: float = float(e.bleed_stacks) * e.bleed_tick_damage_per_stack * 3.0 * 1.5 * mult
			e.bleed_stacks = 0
			if burst > 0.0:
				e._reaction_damage(burst)
			EnchantFx.play(tree, "burst", pos, {"palette": "fire", "count": 16, "speed": 120.0, "life": 0.45})
		"sok+yanma": ## Aşırı Yük
			_area_damage(e, pos, 60.0, ap * 0.4 * mult, true)
			EnchantFx.play(tree, "explosion", pos, {"radius": 60.0, "color": Color(1.0, 0.85, 0.3)})
			for v in _nearest(tree, e, pos, 160.0, 2):
				v._apply_shock_from(e)
				EnchantFx.play(tree, "chain", pos, {"to": v.global_position})
		"donma+zehir": ## Donmuş Zehir
			var hold: float = maxf(0.0, e._freeze_timer)
			e._extend_poison(hold)
			var burst_p: float = e._poison_dps_total() * 2.0 * mult
			if burst_p > 0.0:
				e._reaction_damage(burst_p)
			EnchantFx.play(tree, "burst", pos, {"palette": "spark", "count": 10, "speed": 90.0, "life": 0.4})
		"donma+kanama": ## Kristal Kan
			e._bleed_double_until_msec = now + int(maxf(1.0, e._freeze_timer) * 1000.0)
			for v in _nearest(tree, e, pos, 140.0, 3):
				v.last_attacker_peer_id = e._reaction_peer if e._reaction_peer > 0 else v.last_attacker_peer_id
				v._take_dot_damage(ap * 0.3 * mult)
				EnchantFx.play(tree, "chain", pos, {"to": v.global_position, "color": Color(0.75, 0.55, 1.0)})
		"donma+sok": ## Parçalanma
			e._end_freeze_now()
			var shatter: float = ap * (0.6 if e.is_boss else 1.2) * mult
			e._reaction_damage(shatter)
			EnchantFx.play(tree, "burst", pos, {"palette": "spark", "count": 24, "speed": 200.0, "life": 0.5})
			EnchantFx.play(tree, "ring", pos, {"radius": 50.0, "color": Color(0.75, 0.9, 1.0)})
		"kanama+zehir": ## Enfeksiyon - ölünce yükler yayılır (bkz. enemy.gd _on_death_elements)
			e._infected = true
		"sok+zehir": ## İletken Zehir - şok sıçraması zehir kopyalar (bkz. enemy.gd _shock_on_direct_hit)
			e._conductive = true
		"kanama+sok": ## Kan Akımı - şok sıçraması kanamayla güçlenir (bkz. enemy.gd _shock_on_direct_hit)
			e._blood_current = true


## Merkezdeki düşman DAHİL alandaki herkese tepkime hasarı (tetikleyene atfedilir).
static func _area_damage(e: Node, pos: Vector2, radius: float, amount: float, include_center: bool) -> void:
	if amount <= 0.0:
		return
	for v in Enemy.get_enemies_near(e.get_tree(), pos, radius):
		if not is_instance_valid(v) or v.is_dead:
			continue
		if v == e and not include_center:
			continue
		if e._reaction_peer > 0:
			v.last_attacker_peer_id = e._reaction_peer
		v._take_dot_damage(amount)


static func _nearest(tree: SceneTree, exclude: Node, pos: Vector2, radius: float, count: int) -> Array:
	var cands: Array = []
	for v in Enemy.get_enemies_near(tree, pos, radius):
		if is_instance_valid(v) and v != exclude and not v.is_dead:
			cands.append(v)
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return cands.slice(0, count)
