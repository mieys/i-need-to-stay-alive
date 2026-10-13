extends RefCounted

## Yerdeki XP küresi / altın BİRLEŞTİRME + ÜST SINIR (kullanıcı isteği 2026-10-12: "yere düşen şeyler FPS düşürüyor" - seçenek B ve C;
## A = uyuyan düşmenin görsel işlerini durdurma, bkz. drop_attraction.gd).
##
## Sorun: her ölüm ayrı bir düğüm (+ 300 sn sayaç + çok oyunculuda ayrı ağ mesajı) bırakıyordu; kalabalık savaşta yerde yüzlerce
## düşme birikiyordu (ölçüm: 1500 altın +12,5 ms). Çözüm (TOPLAM XP/ALTIN KORUNUR, denge sabitleri DEĞİŞMEZ):
##  B) Yeni düşme, yakınında (MERGE_RADIUS) aynı kademede duran, henüz çekilmeye başlamamış bir düşme varsa YENİ DÜĞÜM AÇMAZ,
##     değerini ona ekler (`merge_in`). Çok oyunculuda birleştirme SADECE host'ta, doğuştan önce: yeni kimlik/ağ mesajı yok;
##     istemcilerin görsel kopyası aynı kalır (değer yalnız host'un gerçek düşmesinde işe yarar, bkz. request_drop_pickup).
##  C) Düşme sayısı XP_CAP / GOLD_CAP'i aşınca birleştirme yarıçapı OVERFLOW_RADIUS'a genişler; orada da hedef yoksa değer doğrudan en
##     yakın canlı oyuncuya yazılır (`credit_xp`/`credit_gold`) - hiçbir şey kaybolmaz.
## Küre başına tetiklenen eşya etkileri (Ruhların Akışı, XP can şansı) birleşen küre sayısı kadar tekrarlanır (xp_orb.gd merged_count,
## player.gd on_xp_collected_extra) - birleştirme eşyaları zayıflatmasın. Boss altını (paylaşımlı) ASLA birleşmez.
##
## Izgara: yalnız GERÇEK (host/tek oyunculu, "network_spawned" olmayan) düşmeler kayıtlıdır; hücre doğuş konumundan hesaplanır ve
## düşme çekilmeye başlayınca hareket eder - bu yüzden adayın CANLI konumu ayrıca denetlenir, çekilen/toplanan düşme aday sayılmaz.

const DropAttraction := preload("res://scripts/drop_attraction.gd")
const FloatingText := preload("res://scenes/floating_text.tscn")

const KIND_XP := "xp"
const KIND_GOLD := "gold"
const CELL := 56.0
const MERGE_RADIUS := 56.0
const OVERFLOW_RADIUS := 260.0
const XP_MERGE_MAX := 8 ## bir küre en çok bu kadar öldürmenin değerini taşır (normal durum)
const GOLD_MERGE_MAX := 12
const OVERFLOW_MERGE_MAX := 40 ## sınır aşılınca
static var xp_cap: int = 300 ## testler değiştirir
static var gold_cap: int = 200

static var _grids: Dictionary = {KIND_XP: {}, KIND_GOLD: {}} ## tür -> {Vector2i hücre: {instance_id: düğüm}}
static var _cells: Dictionary = {} ## instance_id -> [tür, hücre]
static var _counts: Dictionary = {KIND_XP: 0, KIND_GOLD: 0}


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


## Düğümün _enter_tree'sinde (yalnız gerçek/host düşmesi). Tekrar çağrı zararsız.
static func register(kind: String, node: Node2D) -> void:
	var id: int = node.get_instance_id()
	if _cells.has(id):
		return
	var cell: Vector2i = cell_of(node.global_position)
	var grid: Dictionary = _grids[kind]
	if not grid.has(cell):
		grid[cell] = {}
	(grid[cell] as Dictionary)[id] = node
	_cells[id] = [kind, cell]
	_counts[kind] = int(_counts[kind]) + 1


static func unregister(node: Node2D) -> void:
	var id: int = node.get_instance_id()
	if not _cells.has(id):
		return
	var info: Array = _cells[id]
	_cells.erase(id)
	var grid: Dictionary = _grids[info[0]]
	var bucket: Variant = grid.get(info[1])
	if bucket is Dictionary:
		(bucket as Dictionary).erase(id)
		if (bucket as Dictionary).is_empty():
			grid.erase(info[1])
	_counts[info[0]] = maxi(0, int(_counts[info[0]]) - 1)


static func count(kind: String) -> int:
	return int(_counts.get(kind, 0))


static func reset() -> void:
	_grids = {KIND_XP: {}, KIND_GOLD: {}}
	_cells.clear()
	_counts = {KIND_XP: 0, KIND_GOLD: 0}


static func xp_over_cap() -> bool:
	return count(KIND_XP) >= xp_cap


static func gold_over_cap() -> bool:
	return count(KIND_GOLD) >= gold_cap


## Yarıçap içinde birleşmeye uygun en yakın düşme (yoksa null). tier: XP için kademe (altında -1 = önemsiz).
static func find_target(kind: String, pos: Vector2, tier: int, radius: float, max_merged: int) -> Node2D:
	var grid: Dictionary = _grids[kind]
	if grid.is_empty():
		return null
	var c0: Vector2i = cell_of(pos)
	var span: int = ceili(radius / CELL)
	var r2: float = radius * radius
	var best: Node2D = null
	var best_d: float = INF
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var bucket: Variant = grid.get(Vector2i(c0.x + dx, c0.y + dy))
			if bucket == null:
				continue
			for n: Variant in (bucket as Dictionary).values():
				if not is_instance_valid(n):
					continue
				var node: Node2D = n as Node2D
				if not node.has_method("can_merge") or not bool(node.call("can_merge", tier, max_merged)):
					continue
				var d: float = pos.distance_squared_to(node.global_position)
				if d <= r2 and d < best_d:
					best_d = d
					best = node
	return best


## XP: yeni küre YERİNE mevcut bir küreye ekle. true = emildi (çağıran yeni düğüm açmaz).
static func absorb_xp(pos: Vector2, tier: int, value: float) -> bool:
	var over: bool = xp_over_cap()
	var target: Node2D = find_target(KIND_XP, pos, tier, OVERFLOW_RADIUS if over else MERGE_RADIUS, OVERFLOW_MERGE_MAX if over else XP_MERGE_MAX)
	if target == null:
		return false
	target.call("merge_in", value)
	return true


static func absorb_gold(pos: Vector2, amount: int) -> bool:
	var over: bool = gold_over_cap()
	var target: Node2D = find_target(KIND_GOLD, pos, -1, OVERFLOW_RADIUS if over else MERGE_RADIUS, OVERFLOW_MERGE_MAX if over else GOLD_MERGE_MAX)
	if target == null:
		return false
	target.call("merge_in", amount)
	return true


## Sınır aşıldı ve birleşecek küre yok: değer en yakın canlı oyuncuya doğrudan yazılır (false = oyuncu yok, çağıran normal düşürür).
static func credit_xp(tree: SceneTree, pos: Vector2, value: float) -> bool:
	var p: Node2D = DropAttraction.nearest_collector(tree, pos)
	if p == null:
		return false
	var v: float = value * (load("res://scripts/xp_orb.gd") as GDScript).call("xp_gain_mult_for", p) ## load: xp_orb.gd bu dosyayı preload eder (döngüsel preload olmasın)
	if NetworkManager.is_multiplayer_active:
		NetworkManager.host_collect_xp(v)
	else:
		GameManager.add_team_xp(v)
	if p.is_in_group("player") and p.has_method("on_xp_collected_extra"):
		p.on_xp_collected_extra(1) ## ses yok, yalnız küre başına eşya etkileri
	return true


static func credit_gold(tree: SceneTree, pos: Vector2, amount: int) -> bool:
	var p: Node2D = DropAttraction.nearest_collector(tree, pos)
	if p == null:
		return false
	if p.is_in_group("player"):
		GameManager.gold += amount
		var scene: Node = tree.current_scene
		if scene != null:
			var ft = FloatingText.instantiate()
			scene.add_child(ft)
			ft.global_position = p.global_position + Vector2(14, -34)
			ft.setup("+%d altın" % amount, Color(1.0, 0.85, 0.25))
	elif p.has_method("collect_gold"):
		p.collect_gold(amount)
	else:
		return false
	return true
