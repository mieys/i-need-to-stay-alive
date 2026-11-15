extends Node

## Madde 586: Shaman E (Kalkan Totemi) AURA SINIRI "C Işık Perdesi" (scripts/totem_aura_border.gd + shaders/shaman_aura_perde.gdshader).
## Sınır yalnız Kalkan Totemi'nde, totemin KENDİ totem_radius'unu izler (Geniş Alan dahil), totem gidince söner, ruh hâlinde durur;
## haritada zemin katmanlarının hemen arkasına girer (GroundSlot.floor_index: zindan "Duvar" önü / yüzey "Yer"+"Su" arkası).

const AttackTotemScene: PackedScene = preload("res://scenes/totem_attack.tscn")
const ShieldTotemScene: PackedScene = preload("res://scenes/totem_shield.tscn")
const BorderScript: GDScript = preload("res://scripts/totem_aura_border.gd")
const GroundSlot: GDScript = preload("res://scripts/ground_slot.gd")
const LimboScript: GDScript = preload("res://scripts/limbo.gd")
const FxWarmup: GDScript = preload("res://scripts/fx_warmup.gd")

var _spawned: Array = []


class FakeCaster extends Node2D:
	func has_evo(_evo_id: String) -> bool:
		return false


func _cleanup() -> void:
	for n in get_tree().get_nodes_in_group(BorderScript.GROUP):
		if is_instance_valid(n):
			n.free()
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _make_totem(scene: PackedScene) -> Node2D:
	var caster := FakeCaster.new()
	add_child(caster)
	_spawned.append(caster)
	var totem: Node2D = scene.instantiate()
	totem.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(totem)
	_spawned.append(totem)
	totem.set("caster", caster)
	totem.global_position = Vector2(300, 200)
	return totem


func _border_of(totem: Node2D) -> Node2D:
	return totem.call("aura_border") as Node2D


func test_only_shield_totem_has_border() -> void:
	_cleanup()
	var before: int = get_tree().get_nodes_in_group(BorderScript.GROUP).size()
	_make_totem(AttackTotemScene)
	assert(get_tree().get_nodes_in_group(BorderScript.GROUP).size() == before, "Q (Saldırı Totemi) sınır çizmemeli")
	var shield: Node2D = _make_totem(ShieldTotemScene)
	var b: Node2D = _border_of(shield)
	assert(b != null and b.is_in_group(BorderScript.GROUP), "E sınır kurmalı")
	assert(b.get_parent() != shield, "sınır totemin çocuğu değil (haritada zemin katmanında olmalı)")
	assert(b.material is ShaderMaterial and (b.material as ShaderMaterial).shader.resource_path == "res://shaders/shaman_aura_perde.gdshader", "Işık Perdesi shader'ı")
	assert(not b.top_level, "top_level çizim sırasını en üste taşır - kullanılmamalı")
	_cleanup()


func test_border_follows_totem_radius() -> void:
	_cleanup()
	var shield: Node2D = _make_totem(ShieldTotemScene)
	var b: Node2D = _border_of(shield)
	assert(not b.visible, "totem konumunu okumadan (ilk _process) gizli - yoksa bir kare (0,0)'da çizilir")
	b.call("_process", 0.1)
	assert(b.visible, "ilk _process'te görünür")
	assert(b.call("drawn_radius") > 0.0 and b.call("drawn_radius") < 220.0, "açılışta yarıçap taştan dışa büyür")
	b.call("_process", 1.0)
	assert(is_equal_approx(float(b.call("drawn_radius")), float(shield.get("totem_radius"))), "açılış bitince sınır = totem_radius")
	var mat: ShaderMaterial = b.material as ShaderMaterial
	assert((mat.get_shader_parameter("center") as Vector2).is_equal_approx(shield.global_position), "merkez totemde")
	shield.set("totem_radius", 286.0) ## Geniş Alan x1,3
	b.call("_process", 0.016)
	assert(is_equal_approx(float(b.call("drawn_radius")), 286.0), "evrimle büyüyen yarıçapı izlemeli")
	assert(is_equal_approx(float(mat.get_shader_parameter("alpha_mult")), 1.0), "açıkken tam görünür")
	_cleanup()


## Diğer oyuncuların ekranındaki ağ görsel kopyası (remote_player.gd) da aynı _ready yolundan sınır kurar - ek RPC yok.
func test_network_visual_copy_has_border() -> void:
	_cleanup()
	var totem: Node2D = ShieldTotemScene.instantiate()
	totem.process_mode = Node.PROCESS_MODE_DISABLED
	totem.call("mark_as_network_visual")
	add_child(totem)
	_spawned.append(totem)
	assert(totem.call("aura_border") != null, "ağ kopyası da sınır çizmeli")
	_cleanup()


func test_border_fades_when_totem_gone() -> void:
	_cleanup()
	var shield: Node2D = _make_totem(ShieldTotemScene)
	var b: Node2D = _border_of(shield)
	b.call("_process", 1.0)
	shield.free()
	_spawned.erase(shield)
	b.call("_process", 0.1)
	assert(bool(b.call("is_fading")), "totem gidince sönmeye başlamalı")
	var a: float = float((b.material as ShaderMaterial).get_shader_parameter("alpha_mult"))
	assert(a > 0.0 and a < 1.0, "sönerken yarı saydam")
	b.call("_process", BorderScript.FADE_TIME)
	assert(b.is_queued_for_deletion(), "söndükten sonra kendini silmeli")
	_cleanup()


func test_border_freezes_with_limbo() -> void:
	_cleanup()
	var shield: Node2D = _make_totem(ShieldTotemScene)
	var b: Node2D = _border_of(shield)
	b.call("_process", 1.0)
	var mat: ShaderMaterial = b.material as ShaderMaterial
	var t0: float = float(mat.get_shader_parameter("time_s"))
	LimboScript.freeze(shield)
	b.call("_process", 0.5)
	assert(is_equal_approx(float(mat.get_shader_parameter("time_s")), t0), "ruh hâlinde donan totemin perdesi de durmalı")
	LimboScript.thaw(shield)
	b.call("_process", 0.5)
	assert(float(mat.get_shader_parameter("time_s")) > t0, "çözülünce akmalı")
	_cleanup()


func _fake_map(names: Array) -> Node2D:
	var m := Node2D.new()
	for n: String in names:
		var c := Node2D.new()
		c.name = n
		m.add_child(c)
	return m


func test_floor_index_rules() -> void:
	## Yüzey haritası (ana harita / Kara Bataklık / Altın Kumlar): Yer + Su gruplarının hemen arkası.
	var surface: Node2D = _fake_map(["Yer", "Su", "Orman parçaları", "ev", "Shader Eklenecek"])
	assert(GroundSlot.floor_index(surface) == 2, "yüzeyde Su'nun hemen arkası")
	## Zindan haritası: düz katman listesi, zemin/su Duvar'dan önce -> Duvar'ın hemen önü (Su başta olsa da!).
	var dungeon: Node2D = _fake_map(["Su", "Su ayrıntı", "Zemin", "Zemin süsü", "Yer süsü", "Duvar", "Eşya"])
	assert(GroundSlot.floor_index(dungeon) == 5, "zindanda Duvar'ın önü")
	var unknown: Node2D = _fake_map(["A", "B"])
	assert(GroundSlot.floor_index(unknown) == -1, "bilinmeyen haritada -1 (yedek kural)")
	## Yerleşim: haritaya eklenince doğru sıraya girer.
	for pair in [[surface, 2, "Orman parçaları"], [dungeon, 5, "Duvar"]]:
		var m: Node2D = pair[0]
		var n := Node2D.new()
		m.add_child(n)
		m.move_child(n, GroundSlot.floor_index(m))
		assert(n.get_index() == int(pair[1]) and m.get_child(n.get_index() + 1).name == pair[2], "sınır %s'ten önce" % pair[2])
	for m in [surface, dungeon, unknown]:
		m.free()


func test_shader_is_warmed() -> void:
	assert(FxWarmup.EXTRA_SHADERS.has("res://shaders/shaman_aura_perde.gdshader"), "ilk Kalkan Totemi'nde derleme takılmasın")
