extends Node

## ORMAN ÜST KATMANI (2026-10-14, kullanıcı: "haritada orman parçaları 2 layerının üstümüzde görünmesi gerekiyor, fakat duvarların içinden geçilebilen bir
## yetenek aktifken altımızda olabilir"): "Orman parçaları/Orman parçaları 2" katmanı karakterlerin ÜSTÜNDE çizilir (z 2; oyuncular/kuklalar z 1).
## Duvar geçen karakter (Vampir Gece Uçuşu yarasa formu, Cadı Yüksek Uçuş süpürgesi ve onun yolcuları) katmanın ÜSTÜNE çıkar (z 4) - karakter başına, o
## karaktere ait z_index değişir; katman her bakış açısında aynıdır, yani uzak oyuncunun uçuşu da doğru görünür (ağ gerekmez, durum zaten senkron:
## yarasa klibi + `cadi` durumu). Kopya derinlik katmanları z 3 (depth_occluders.gd FRONT_Z): uçan karakter ağaç kopyalarının da üstünde kalır.
## Tuzak: Tiled'da katman adı değişirse CANOPY_LAYERS güncellenmeli; bulunamayan katman sessizce atlanır (test_forest_canopy bulunduğunu sınar).

const CadiMathScript := preload("res://scripts/cadi_math.gd")

const CANOPY_LAYERS: Array = ["Orman parçaları/Orman parçaları 2"]
const CANOPY_Z := 2 ## katman: karakterlerin (z 1) üstünde
const FLYER_Z := 4 ## duvar geçen karakter: katmanın ve derinlik kopyalarının (z 3) üstünde
const META_BASE_Z := "_canopy_base_z"

var layers: Array[TileMapLayer] = []


## main.gd çağırır. Harita/katman yoksa sessizce hiçbir şey yapmaz.
func setup(harita: Node) -> void:
	if harita == null:
		return
	name = "ForestCanopy"
	for path: String in CANOPY_LAYERS:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer != null:
			layer.z_index = CANOPY_Z
			layers.append(layer)
	harita.add_child(self)


func _process(_delta: float) -> void:
	if layers.is_empty():
		return
	apply(get_tree())


## Yerel oyuncu + uzak kuklalar: duvar geçiyorsa FLYER_Z, değilse eski z'ye dön. Testler doğrudan çağırır.
static func apply(tree: SceneTree) -> void:
	for group_name: String in ["player", "remote_players"]:
		for n: Node in tree.get_nodes_in_group(group_name):
			if n is Node2D and is_instance_valid(n):
				_set_flying(n as Node2D, flies_over_walls(tree, n))


## Karakter duvar/orman üstünden uçuyor mu: kendi yeteneği ya da duvar geçen bir süpürgenin yolcusu.
static func flies_over_walls(tree: SceneTree, n: Node) -> bool:
	if n.has_method("passes_walls") and bool(n.call("passes_walls")):
		return true
	var host_peer: int = int(n.get("cadi_ride_host_peer")) if n.get("cadi_ride_host_peer") != null else 0
	if host_peer != 0:
		var host: Node = CadiMathScript.player_node(tree, host_peer)
		return host != null and host != n and host.has_method("passes_walls") and bool(host.call("passes_walls"))
	return false


static func _set_flying(n: Node2D, flying: bool) -> void:
	if flying:
		if not n.has_meta(META_BASE_Z):
			n.set_meta(META_BASE_Z, n.z_index)
		n.z_index = FLYER_Z
	elif n.has_meta(META_BASE_Z):
		n.z_index = int(n.get_meta(META_BASE_Z))
		n.remove_meta(META_BASE_Z)
