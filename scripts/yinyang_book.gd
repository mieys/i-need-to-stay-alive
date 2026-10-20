extends RefCounted

## YİN YANG KİTABI (madde 334) - kitabın ortak kuralları TEK yerde: kara küre (yinyang_projectile.gd, kaster + uzak kopya), ak küre
## (yinyang_light.gd, kaster + uzak kopya) ve Denge özelliği (weapon_traits/denge.gd) buradan okur.
## Mekanik: menzilli tek hedef; isabet başına saldırı gücünün %10'u (Denge "ys_shield") mana kalkanı. Alıcı MENZİLSİZ = kalkanı ORAN olarak
## en boş canlı oyuncu (sahibi dahil, eşitlikte sahibi; tek kişilikte hep sahibi). Kimse alamıyorsa (hepsi dolu / kalkan türü yok) Denge'nin
## Yin kuralı: kalkan hasara döner. Görsel (prototip yinyang_proto.py B v2, kullanıcı: "atıldığı anda ikiye bölünsün, kitaptan havaya
## yükselip ayrılsın"): iki küre kitaptan sarmal çizerek RISE sn yükselir, tepede ayrılır - kara hedefe, ak kalkanı alana (Yin'de o da düşmana).

const KEY := "yinyang"
const SRC := &"w:yinyang" ## balans kaydı / Shift ipucu: silah kaynağı (BalanceLog "w:<anahtar>")
const SHIELD_AP := 0.10
const RISE := 0.2 ## kitaptan yükselme (sn) - bu sırada kara küre çarpmaz
const RISE_H := 13.0 ## yükselme (dünya px)
const SPIN_R := 3.6 ## sarmal yarıçapı (dünya px, yere yatık elips y x0,6)
const SPIN_TURNS := 1.6
const DRIFT := 4.0 ## yükselirken hedef yönüne kayma (dünya px)
const LIGHT_SPEED := 230.0
const LIGHT_MIN := 0.22 ## ak kürenin uçuş süresi sınırları (menzilsiz: uzaktaki dosta da en geç LIGHT_MAX sn'de varır)
const LIGHT_MAX := 0.9
const WORLD_PX := 0.575 ## küre dokusu pikseli (WeaponTierArt.WORLD_PX ile aynı yoğunluk)
const WAIST := Vector2(0.0, 1.0) ## karakter kökü bel hizasında (fx_talon_chains.gd BELT_OFFSET)
const FULL_RATIO := 0.999
const Z_FRONT := 60

const ORB_DARK: Texture2D = preload("res://assets/fx/yinyang/orb_dark.png")
const ORB_LIGHT: Texture2D = preload("res://assets/fx/yinyang/orb_light.png")
const STAR: Texture2D = preload("res://assets/fx/yinyang/star.png")

## ElaraFx.Trail paleti: [0] kullanılmaz, [1] dış kontur -> [4] çekirdek (prototip INK / CREAM).
const TRAIL_DARK: Array[Color] = [Color(0, 0, 0, 0), Color(0.024, 0.02, 0.035, 0.5), Color(0.18, 0.165, 0.227, 0.7),
	Color(0.18, 0.165, 0.227, 0.8), Color(0.29, 0.267, 0.345, 0.85)]
const TRAIL_LIGHT: Array[Color] = [Color(0, 0, 0, 0), Color(0.431, 0.392, 0.314, 0.45), Color(0.847, 0.8, 0.682, 0.7),
	Color(0.949, 0.918, 0.839, 0.85), Color(1.0, 0.992, 0.965, 0.95)]
const TRAIL_LEN_PX := 11.0 ## ElaraFx sanat pikseli (0,903)
const TRAIL_WIDTH_PX := 3.4


## Yükselme anında iki kürenin çıkış noktasına göre konumu: [kara, ak, kara önde mi (> 0)].
static func rise_offsets(t: float, drift_dir: Vector2) -> Array:
	var tau: float = clampf(t / RISE, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - tau, 3.0)
	var c := Vector2(drift_dir.x * DRIFT * e, -RISE_H * e)
	var r: float = SPIN_R * e
	var ph: float = TAU * SPIN_TURNS * tau + 0.6
	var o := Vector2(cos(ph) * r, sin(ph) * r * 0.6)
	return [c + o, c - o, sin(ph)]


static func can_receive(n: Variant) -> bool:
	if n == null or not (n is Node2D) or not is_instance_valid(n):
		return false
	var mx: Variant = (n as Node).get("item_shield_max")
	return (n as Node).get("is_dead") != true and (n as Node).get("is_downed") != true and mx != null and float(mx) > 0.0


static func shield_ratio(n: Node) -> float:
	var mx: float = float(n.get("item_shield_max"))
	return clampf(float(n.get("item_shield_hp")) / mx, 0.0, 1.0) if mx > 0.0 else 1.0


## Kalkanı oransal en boş canlı oyuncu (sahibi + kuklalar, menzil yok). null = kimse alamıyor (Yin).
static func pick_recipient(owner: Node) -> Node2D:
	var best: Node2D = null
	var best_r: float = FULL_RATIO
	if can_receive(owner):
		var r0: float = shield_ratio(owner)
		if r0 < best_r:
			best = owner as Node2D
			best_r = r0
	if owner != null and is_instance_valid(owner) and owner.is_inside_tree():
		for rp in owner.get_tree().get_nodes_in_group("remote_players"):
			if not can_receive(rp):
				continue
			var r: float = shield_ratio(rp)
			if r < best_r - 0.0001: ## eşitlikte sahibi
				best = rp as Node2D
				best_r = r
	return best


static func my_peer(tree: SceneTree) -> int:
	if NetworkManager.is_multiplayer_active and tree.get_multiplayer().has_multiplayer_peer():
		return tree.get_multiplayer().get_unique_id()
	return 1


## Ağ kimliği: kukla peer_id'si, yerel oyuncu bu makinenin kimliği (tek kişilikte 1).
static func peer_of(n: Node) -> int:
	if n == null or not is_instance_valid(n):
		return 0
	if "peer_id" in n and int(n.get("peer_id")) > 0:
		return int(n.get("peer_id"))
	return my_peer(n.get_tree()) if n.is_inside_tree() else 1


## Uzak kopyada peer -> düğüm: bu makinenin oyuncusu, kitabın sahibinin kuklası ya da başka bir kukla.
static func node_for_peer(tree: SceneTree, peer: int) -> Node2D:
	if peer <= 0 or tree == null:
		return null
	if peer == my_peer(tree):
		return tree.get_first_node_in_group("player") as Node2D
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and int(rp.get("peer_id")) == peer:
			return rp as Node2D
	return null


## Kitabın sahibi (yerel Player) kalkanı verir: kendine heal_shield, dosta player.gd _apply_shield_heal_to_ally (RPC + asist + mavi sayı).
## İkisi de İyileştirme ve Kalkan Gücü (heal_power_mult) ile çarpar.
static func give_shield(owner: Node, rcp: Node, amount: float) -> void:
	if amount <= 0.0 or owner == null or not is_instance_valid(rcp):
		return
	if rcp == owner:
		if owner.has_method("heal_shield"):
			owner.call("heal_shield", amount, true, true, SRC)
	elif owner.has_method("_apply_shield_heal_to_ally"):
		owner.call("_apply_shield_heal_to_ally", rcp, amount, SRC)


## Silahın Denge özelliği sayısı (özellik yoksa temel değer).
static func stat(weapon: Node, key: String, d: float) -> float:
	if weapon == null or not is_instance_valid(weapon):
		return d
	var b: Variant = weapon.get("enchant_behavior")
	if b is Node and is_instance_valid(b):
		return float(((b as Node).get("stats") as Dictionary).get(key, d))
	return d


## Kara kürenin GERÇEK isabeti (yalnız kasterde, ana hasardan SONRA): kalkan ya da Yin hasarı + Denge kancası (Kara Mühür, final sayacı).
## decided_yin: atışta kimse kalkan alamıyordu (ak küre de düşmana uçtu). Atıştaki alıcı artık alamıyorsa (öldü / doldu) yeniden seçilir.
static func resolve_hit(weapon: Node, body: Node, rcp: Node2D, decided_yin: bool) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var owner: Node = weapon.get_parent()
	if owner == null:
		return
	var ap: float = float(owner.get("damage_bonus")) if "damage_bonus" in owner else 10.0
	var beh: Variant = weapon.get("enchant_behavior")
	var has_beh: bool = beh is Node and is_instance_valid(beh)
	if not decided_yin and (not can_receive(rcp) or shield_ratio(rcp) >= FULL_RATIO):
		rcp = pick_recipient(owner)
	if decided_yin or rcp == null:
		var amt: float = ap * stat(weapon, "yin_ap", 0.2)
		if has_beh:
			(beh as Node).call("hit", body, amt)
		elif is_instance_valid(body) and body.has_method("take_damage") and body.get("is_dead") != true:
			preload("res://scripts/balance_log.gd").tag_weapon(weapon)
			body.take_damage(amt, false, 0.0, true)
	else:
		var amount: float = ap * stat(weapon, "ys_shield", SHIELD_AP)
		if shield_ratio(rcp) < stat(weapon, "yang_th", 0.3):
			amount *= stat(weapon, "yang_mult", 1.5)
		give_shield(owner, rcp, amount)
	if has_beh and (beh as Node).has_method("on_yinyang_hit"):
		(beh as Node).call("on_yinyang_hit", body)


## Saldıracak düşman yokken (weapon.gd _on_fire_timer_timeout hedefsiz dalı; kullanıcı: "saldırması gerekmediğinde de kalkan verebilsin"):
## atış aralığında YALNIZ ak küre kitaptan yükselip kalkanı en boş oyuncuya taşır - isabetteki kalkanla aynı sayı (Kalın Sayfa / Yang dahil),
## hasar yok, Yin yok, Denge sayacı ilerlemez. Kimse eksik değilse hiçbir şey olmaz. Kalkan hemen verilir (isabet yolu gibi), küre görseldir;
## diğer oyunculara "yinyang_idle" (NetworkManager.broadcast_player_vfx -> spawn_idle_light). true = kalkan verildi.
static func idle_shot(weapon: Node2D) -> bool:
	if weapon == null or not is_instance_valid(weapon) or not weapon.is_inside_tree():
		return false
	var owner: Node = weapon.get_parent()
	var rcp: Node2D = pick_recipient(owner)
	if rcp == null:
		return false
	var ap: float = float(owner.get("damage_bonus")) if "damage_bonus" in owner else 10.0
	var amount: float = ap * stat(weapon, "ys_shield", SHIELD_AP)
	if shield_ratio(rcp) < stat(weapon, "yang_th", 0.3):
		amount *= stat(weapon, "yang_mult", 1.5)
	give_shield(owner, rcp, amount)
	var from: Vector2 = weapon.global_position
	spawn_idle_light(weapon.get_tree(), from, rcp, owner as Node2D)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.send_player_vfx(my_peer(weapon.get_tree()), "yinyang_idle", from, {"rcp": peer_of(rcp)})
	return true


## Yalnız ak küre (kaster + uzak kopya aynı yoldan): kitaptan tek başına sarmal çizerek yükselir, alıcıya uçar, belinde tur atıp söner.
static func spawn_idle_light(tree: SceneTree, from: Vector2, rcp: Node2D, owner: Node2D) -> Node2D:
	if tree == null or tree.current_scene == null or not is_instance_valid(rcp):
		return null
	var light: Node2D = (load("res://scripts/yinyang_light.gd") as GDScript).new()
	light.set("start", from)
	light.set("drift", Vector2.ZERO)
	light.set("rcp", rcp)
	light.set("owner_node", owner)
	tree.current_scene.add_child(light)
	return light


static func make_trail(parent: Node, pal: Array[Color]) -> Sprite2D:
	var tr = ElaraFx.Trail.new()
	tr.pal = pal
	tr.len_px = TRAIL_LEN_PX
	tr.width_px = TRAIL_WIDTH_PX
	parent.add_child(tr)
	return tr
