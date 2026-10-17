extends Node

## Orman üst katmanı (forest_canopy.gd): "Orman parçaları 2" karakterlerin üstünde, duvar geçen (uçan) karakter katmanın üstünde.
## Pikselin gerçekten örtülmesi GPU'da çözülür; burada z kuralları, geri dönüş ve yolcu kuralı sınanır.

const CanopyScript := preload("res://scripts/forest_canopy.gd")

var _spawned: Array = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## passes_walls() ve cadi_ride_host_peer taşıyan sahte karakter (Player/RemotePlayer'ın yerine).
class FakeChar:
	extends Node2D
	var flying: bool = false
	var cadi_ride_host_peer: int = 0
	var peer_id: int = 0

	func passes_walls() -> bool:
		return flying


func _char(group: String, flying: bool) -> FakeChar:
	var c := FakeChar.new()
	c.z_index = 1
	c.flying = flying
	c.add_to_group(group)
	_track(c)
	add_child(c)
	return c


func test_layer_goes_above_characters() -> void:
	var harita := Node2D.new()
	_track(harita)
	var parent := Node2D.new()
	parent.name = "Orman parçaları"
	harita.add_child(parent)
	var layer := TileMapLayer.new()
	layer.name = "Orman parçaları 2"
	parent.add_child(layer)
	var other := TileMapLayer.new()
	other.name = "Orman parçaları"
	parent.add_child(other)
	add_child(harita)
	var canopy: Node = CanopyScript.new()
	canopy.setup(harita)
	assert(layer.z_index == CanopyScript.CANOPY_Z, "Orman parçaları 2 karakterlerin (z 1) üstüne alınır")
	assert(layer.z_index > 1, "katman z'si oyuncu z'sinden büyük")
	assert(other.z_index == 0, "diğer orman katmanlarına dokunulmaz")
	assert(canopy.layers.size() == 1)
	_cleanup()


func test_flying_character_rises_above_layer_and_returns() -> void:
	var p: FakeChar = _char("player", false)
	var rp: FakeChar = _char("remote_players", false)
	CanopyScript.apply(get_tree())
	assert(p.z_index == 1 and rp.z_index == 1, "uçmayan karakter z 1'de kalır")
	p.flying = true
	rp.flying = true
	CanopyScript.apply(get_tree())
	assert(p.z_index == CanopyScript.FLYER_Z and rp.z_index == CanopyScript.FLYER_Z, "uçan karakter katmanın üstüne çıkar")
	assert(CanopyScript.FLYER_Z > CanopyScript.CANOPY_Z, "uçan z > katman z")
	assert(CanopyScript.FLYER_Z > 3, "uçan karakter derinlik kopyalarının (z 3) da üstünde")
	CanopyScript.apply(get_tree())
	assert(p.z_index == CanopyScript.FLYER_Z, "tekrar çağrı z'yi bozmaz (taban z ezilmez)")
	p.flying = false
	rp.flying = false
	CanopyScript.apply(get_tree())
	assert(p.z_index == 1 and rp.z_index == 1, "uçuş bitince eski z'ye dönülür")
	assert(not p.has_meta(CanopyScript.META_BASE_Z), "taban z kaydı temizlenir")
	_cleanup()


func test_passenger_follows_host_flight() -> void:
	var host: FakeChar = _char("remote_players", true)
	host.peer_id = 77
	var rider: FakeChar = _char("player", false)
	rider.cadi_ride_host_peer = 77
	assert(CanopyScript.flies_over_walls(get_tree(), rider), "duvar geçen süpürgenin yolcusu da uçar")
	host.flying = false
	assert(not CanopyScript.flies_over_walls(get_tree(), rider), "süpürge duvar geçmiyorsa yolcu da geçmez")
	_cleanup()


func test_real_rules_match() -> void:
	var rp_script: GDScript = load("res://scripts/remote_player.gd")
	var pl_script: GDScript = load("res://scripts/player.gd")
	assert(rp_script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "passes_walls"), "RemotePlayer.passes_walls var")
	assert(pl_script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "passes_walls"), "Player.passes_walls var")
