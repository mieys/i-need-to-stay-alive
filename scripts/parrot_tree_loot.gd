extends RefCounted

## Papağan ağaç gagalama ödülü (kullanıcı isteği 2026-10-17): "papağan yerdeki altınları toplamak yerine ağaçların üstüne gidip 3-4 saniye
## gagalayarak ağaçtan yere eşya düşürsün (yiyecek, kalkan, mıknatıs, silah parçacığı; değersizden değerliye), değerliler nadiren,
## yiyecek ve kalkan orbları çoğunlukla düşük seviyeden". Zar + sahneleme TEK yerde; sadece host / tek oyunculu çağırır
## (istemci papağanı NetworkManager.request_parrot_tree_drop ile host'tan ister). Drop sözleşmesi enemy.gd _drop_food ile aynı (id + broadcast_drop).

## Tür ağırlıkları (değersiz -> değerli).
const KIND_WEIGHTS := {"food": 64.0, "shield_orb": 27.0, "magnet": 6.0, "weapon_shard": 3.0}
## Yemek kademesi (1-5) ağırlıkları: ağırlıkla düşük kademe.
const FOOD_TIER_WEIGHTS := [48.0, 27.0, 14.0, 7.0, 4.0]
## Büyük (kademe 2) kalkan orbu şansı - yaratık düşmesinde %30 (shield_orb_drop.gd LARGE_CHANCE), burada daha seyrek.
const LARGE_ORB_CHANCE := 0.15


## roll_a: tür zarı, roll_b: kademe zarı (0..1; testler sabitleyebilsin). Dönüş: {"kind": String, "tier": int}.
static func roll(roll_a: float = -1.0, roll_b: float = -1.0) -> Dictionary:
	if roll_a < 0.0:
		roll_a = randf()
	if roll_b < 0.0:
		roll_b = randf()
	var kind: String = _pick(KIND_WEIGHTS.keys(), KIND_WEIGHTS.values(), roll_a)
	var tier: int = 0
	if kind == "food":
		tier = 1 + _pick_index(FOOD_TIER_WEIGHTS, roll_b)
	elif kind == "shield_orb":
		tier = 2 if roll_b < LARGE_ORB_CHANCE else 1
	return {"kind": kind, "tier": tier}


static func _pick(keys: Array, weights: Array, r: float) -> String:
	return String(keys[_pick_index(weights, r)])


static func _pick_index(weights: Array, r: float) -> int:
	var total: float = 0.0
	for w in weights:
		total += float(w)
	var target: float = clampf(r, 0.0, 0.999999) * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if target < acc:
			return i
	return weights.size() - 1


## Host / tek oyunculu: yerde world_pos'ta ödülü yaratır (çok oyunculuda istemcilere görsel kopyasını da yayınlar).
static func spawn(tree: SceneTree, world_pos: Vector2, loot: Dictionary) -> void:
	var root: Node = tree.current_scene if tree != null else null
	if root == null:
		return
	var kind: String = String(loot.get("kind", "food"))
	var tier: int = int(loot.get("tier", 0))
	if kind == "weapon_shard":
		load("res://scripts/weapon_shard_drop.gd").spawn(tree, world_pos, 1)
		return
	var scene_path: String = {"food": "res://scenes/food_drop.tscn", "shield_orb": "res://scenes/shield_orb_drop.tscn", "magnet": "res://scenes/magnet_drop.tscn"}.get(kind, "")
	if scene_path.is_empty():
		return
	var drop: Node2D = (load(scene_path) as PackedScene).instantiate() as Node2D
	if kind != "magnet":
		drop.set("tier", tier)
	drop.global_position = world_pos
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = NetworkManager._gen_drop_id()
		drop.set_meta("drop_network_id", drop_id)
		NetworkManager.broadcast_drop.rpc(kind, world_pos, tier, drop_id)
	root.call_deferred("add_child", drop)
