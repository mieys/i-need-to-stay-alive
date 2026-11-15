extends Node

## Madde 563: Shaman Q "Kor Topu" ateş topu (fx_totem_fire_bolt.gd) + E SÜREKLİ kalkan şeridi (totem_link_ribbon.gd +
## shaders/totem_shield_link.gdshader, totem_shield.gd _update_links) + bağlıyken kalkan baloncuğu açık (player.gd set_shaman_link).

const ShieldTotemScene: PackedScene = preload("res://scenes/totem_shield.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const FireBolt: GDScript = preload("res://scripts/fx_totem_fire_bolt.gd")
const Ribbon: GDScript = preload("res://scripts/totem_link_ribbon.gd")
const Warmup: GDScript = preload("res://scripts/fx_warmup.gd")
const LINK_SHADER := "res://shaders/totem_shield_link.gdshader"

var _spawned: Array = []


class FakeCaster extends Node2D:
	func has_evo(_evo_id: String) -> bool:
		return false

	func is_safe_zone_frozen() -> bool:
		return false


## Kalkan alabilen hedef: item_shield_max + kalkan baloncuğu düğümü (ShieldVisual/BubbleSprite) + yerel oyuncu kancası.
class FakeTarget extends Node2D:
	var item_shield_max: float = 100.0
	var links: int = 0

	func set_shaman_link() -> void:
		links += 1


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _make_target(pos: Vector2, frames_path: String) -> FakeTarget:
	var t := FakeTarget.new()
	var sv := Node2D.new()
	sv.name = "ShieldVisual"
	t.add_child(sv)
	var b := AnimatedSprite2D.new()
	b.name = "BubbleSprite"
	b.sprite_frames = load(frames_path)
	b.scale = Vector2(1.905, 1.905)
	sv.add_child(b)
	add_child(t)
	t.add_to_group("player")
	t.global_position = pos
	_spawned.append(t)
	return t


func _make_totem(pos: Vector2) -> Node2D:
	var caster := FakeCaster.new()
	add_child(caster)
	_spawned.append(caster)
	var totem: Node2D = ShieldTotemScene.instantiate()
	totem.process_mode = Node.PROCESS_MODE_DISABLED ## elle ilerletilir
	add_child(totem)
	totem.set("caster", caster)
	totem.call("mark_as_network_visual") ## yalnız görsel yol (tik/kalkan hesabı yok)
	totem.global_position = pos
	_spawned.append(totem)
	return totem


func _ribbons(totem: Node) -> Array:
	var out: Array = []
	for c in totem.get_children():
		if c.get_script() == Ribbon:
			out.append(c)
	return out


func test_fire_bolt_is_kor_topu() -> void:
	for p in ["kor_bas_0", "kor_bas_1", "kor_kuyruk_0", "kor_kuyruk_1", "kor_kuyruk_2", "kor_merkez", "kor_yildiz", "kor_yildiz_k"]:
		assert(load("res://assets/fx/shaman_kor/%s.png" % p) is Texture2D, "%s dokusu yüklenmeli" % p)
	assert(not ResourceLoader.exists("res://shaders/totem_bolt.gdshader"), "eski ateş topu shader'ı silinmiş olmalı")
	assert(not ResourceLoader.exists("res://assets/fx/baked/totem_bolt_impact_frames.tres"), "eski pişmiş isabet sayfası silinmiş olmalı")
	var target := Node2D.new()
	add_child(target)
	_spawned.append(target)
	target.global_position = Vector2(400, 300)
	FireBolt.spawn(self, Vector2(200, 300), target, Color(1, 0.5, 0.2))
	var bolt: Node2D = null
	for c in get_children():
		if c.get_script() == FireBolt:
			bolt = c
	assert(bolt != null, "ateş topu doğmalı")
	## gövdesi okunamayan hedefte ayağın biraz üstüne nişan
	assert(Vector2(bolt.get("end_pos")).is_equal_approx(Vector2(400, 290)), "nişan ayağın 10 birim üstü (bulunan %s)" % bolt.get("end_pos"))
	## atış anı efekti (madde 570): namlu alevi / kıvılcım hedef yönüne
	assert(Vector2(bolt.get("_launch_dir")).is_equal_approx((Vector2(400, 290) - Vector2(200, 300)).normalized()), "atış efekti hedef yönüne")
	assert(bolt.has_method("_draw_launch"), "atış anı efekti çizilmeli")
	var t: float = 0.0
	while is_instance_valid(bolt) and t < 1.0:
		bolt.call("_process", 0.05)
		t += 0.05
	assert(not is_instance_valid(bolt) or bolt.is_queued_for_deletion(), "uçuş + isabet (~0,62 sn) sonunda silinmeli")
	_cleanup()


func test_ribbon_links_to_bubble_surface_and_releases() -> void:
	var totem: Node2D = _make_totem(Vector2(1000, 1000))
	var ally: FakeTarget = _make_target(Vector2(1100, 990), "res://assets/fx/shield_bubble_enerji/bubble_frames.tres")
	totem.call("_update_links", 0.016)
	assert(int(totem.call("link_count")) == 1, "menzildeki hedefe bir şerit")
	assert(ally.links == 1, "bağlı hedefin baloncuğu tazelenmeli (set_shaman_link)")
	var ribbon: Node2D = _ribbons(totem)[0]
	var mat: ShaderMaterial = ribbon.material
	assert(mat != null and mat.shader.resource_path == LINK_SHADER, "şerit kendi shader'ıyla çizilmeli")
	var src: Vector2 = totem.global_position + Vector2(totem.get_script().get_script_constant_map()["ORB_ORIGIN_OFFSET"])
	assert(Vector2(mat.get_shader_parameter("p0")).is_equal_approx(src), "şerit E taşının rün merkezinden çıkmalı")
	var p1: Vector2 = mat.get_shader_parameter("p1")
	var bub_c: Vector2 = mat.get_shader_parameter("bub_c")
	var r: float = mat.get_shader_parameter("bub_r")
	assert(is_equal_approx(r, 24.0 * 0.46 * 1.905), "görünen baloncuk yarıçapı (bulunan %s)" % r)
	assert(absf(p1.distance_to(bub_c) - r) < 0.01, "şerit baloncuğun YÜZEYİNDE bitmeli")
	assert((p1 - bub_c).dot(src - bub_c) > 0.0, "baloncuğun taşa BAKAN yüzünde")
	assert(Color(mat.get_shader_parameter("col_outer_b")).is_equal_approx(Color8(0x89, 0xff, 0x39)), "Enerji baloncuğunun limon rengiyle bitmeli")
	## menzilden çıkınca söner ve silinir
	ally.global_position = Vector2(1400, 1000)
	totem.call("_update_links", 0.016)
	assert(int(totem.call("link_count")) == 0, "menzil dışındaki hedefe şerit kalmamalı")
	for i in range(20):
		if is_instance_valid(ribbon):
			ribbon.call("_process", 0.05)
	assert(not is_instance_valid(ribbon) or ribbon.is_queued_for_deletion(), "sönen şerit silinmeli")
	_cleanup()


func test_ribbon_skips_too_close_and_colors_by_bubble() -> void:
	var totem: Node2D = _make_totem(Vector2(2000, 2000))
	var near: FakeTarget = _make_target(Vector2(2020, 2000), "res://assets/fx/shield_bubble_savas/bubble_frames.tres")
	var mid: FakeTarget = _make_target(Vector2(2150, 2000), "res://assets/fx/shield_bubble_savas/bubble_frames.tres")
	totem.call("_update_links", 0.016)
	assert(int(totem.call("link_count")) == 1, "totemin dibindekine şerit yok, ortadakine var")
	assert(near.links == 0 and mid.links == 1, "yalnız bağlı olanın baloncuğu açılır")
	var mat: ShaderMaterial = _ribbons(totem)[0].material
	assert(Color(mat.get_shader_parameter("col_outer_b")).is_equal_approx(Color8(0xce, 0x39, 0x39)), "Savaş baloncuğunun kırmızısıyla bitmeli")
	_cleanup()


## Yerel oyuncu: şeride bağlıyken kalkan baloncuğu açık (ağda shield_bubble_visible = _bubble_active), bağ bitince kapanır.
func test_local_player_bubble_held_while_linked() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.set_physics_process(false)
	player.set("_shield_regenerating", false)
	player.set("_damage_flash_timer", 0.0)
	player.set("is_shielded", false)
	player.call("_update_shield_bubble", 0.016)
	assert(not bool(player.get("_bubble_active")), "bağ yokken (yenilenme/hasar yok) baloncuk kapalı")
	player.call("set_shaman_link")
	player.call("_update_shield_bubble", 0.016)
	assert(bool(player.get("_bubble_active")), "şeride bağlıyken baloncuk açık")
	for i in range(30):
		player.call("_update_shield_bubble", 0.02)
	assert(not bool(player.get("_bubble_active")), "bağ tazelenmeyince baloncuk kapanır")
	_cleanup()


func test_warmup_and_cleanup() -> void:
	assert(load(LINK_SHADER) is Shader, "şerit shader'ı yüklenmeli")
	assert(Warmup.EXTRA_SHADERS.has(LINK_SHADER), "şerit shader'ı ısınma listesinde olmalı (ilk E'de derleme takılması)")
	assert(not ResourceLoader.exists("res://scripts/totem_shield_wave.gd"), "eski uçan kalkan simgesi silinmiş olmalı")
	var src: String = FileAccess.get_file_as_string("res://scripts/totem_shield.gd")
	assert(not src.contains("TotemShieldWave"), "Kalkan Totemi eski dalgayı çağırmamalı")
