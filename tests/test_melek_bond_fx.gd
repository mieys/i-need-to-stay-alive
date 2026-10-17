extends Node

## Madde 212: Melek Q/E "SİHİRLİ BAĞ + DALGA" (A Işık İpi). Çizim (_draw / shader) burada doğrulanamaz; saf hesaplar,
## halenin piksel tablosuyla hizası, bağın yaşam döngüsü (kuruluş -> paket -> varış -> çözülme) ve ağ dalları (iki-yer kuralı:
## alıcı istemci de aynı bağı kurar, tikte aynı paketi yollar) test edilir.

const BondMath := preload("res://scripts/melek_bond_math.gd")
const BondScript := preload("res://scripts/melek_bond_fx.gd")
const HaloScene: PackedScene = preload("res://scenes/fx_melek_halo.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _ensure_scene() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self


func _remote(peer: int, char_id: int, pos: Vector2) -> Node2D:
	var rp: Node2D = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(peer, char_id, "P%d" % peer)
	rp.global_position = pos
	return rp


func _count(script_suffix: String) -> int:
	var n: int = 0
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with(script_suffix) and not c.is_queued_for_deletion():
			n += 1
	return n


func _ribbon_of(bond: Node) -> Node2D:
	return bond.get("_ribbon") as Node2D


## Bağ + ipi bir adım ilerletir (ipin uzunluğu normalde _draw'da hesaplanır; burada elle).
func _step(bond: Node, dt: float = 1.0 / 60.0) -> void:
	var rib: Node2D = _ribbon_of(bond)
	if rib != null and is_instance_valid(rib):
		rib.compute()
	bond._process(dt)


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with("melek_bond_ribbon.gd"):
			c.free()


func test_ribbon_samples_shape_head_and_packet() -> void:
	var p1 := Vector2(100.0, 20.0)
	var r: Dictionary = BondMath.ribbon_samples(p1, 0.0, [], 1e9, 0.0)
	var base: PackedVector2Array = r["base"]
	var hw: PackedFloat32Array = r["hw"]
	var m: int = base.size()
	assert(base[0].is_equal_approx(Vector2.ZERO), "ip halenin pikselinden (kök) başlamalı")
	assert(base[m - 1].is_equal_approx(p1), "ip halkanın kenarında bitmeli")
	var total: float = r["total"]
	assert(absf(total - BondMath.bezier_length(p1)) < total * 0.02, "yay boyu hesapları tutarlı olmalı")
	assert(hw[0] <= 0.55, "ip haleden 1 piksel ince başlamalı: %.2f" % hw[0])
	assert(hw[m / 2] > 0.85, "ortada tam kalınlık (0,9)")
	assert(base[m / 2].y < p1.y * 0.5 - 3.0, "ip hafif yukarı kavisli olmalı")
	## kuruluş: başın ötesi çizilmez
	var forming: Dictionary = BondMath.ribbon_samples(p1, 0.0, [], 30.0, 0.0)
	var fs: PackedFloat32Array = forming["s"]
	var fhw: PackedFloat32Array = forming["hw"]
	for i in range(fs.size()):
		if fs[i] > 30.0:
			assert(fhw[i] == 0.0, "başın ötesi boş olmalı")
	## paket: merkezinde kalın + paket paleti, uzağında değil
	var pk: Dictionary = BondMath.ribbon_samples(p1, 0.0, [Vector2(50.0, 1.0)], 1e9, 0.0)
	var ps: PackedFloat32Array = pk["s"]
	var near: int = -1
	var far: int = -1
	for i in range(ps.size()):
		if near < 0 or absf(ps[i] - 50.0) < absf(ps[near] - 50.0):
			near = i
		if far < 0 or absf(ps[i] - 10.0) < absf(ps[far] - 10.0):
			far = i
	assert((pk["hw"] as PackedFloat32Array)[near] > 1.4 and (pk["hot"] as PackedByteArray)[near] == 1, "paket merkezi kalın ve parlak olmalı")
	assert((pk["hot"] as PackedByteArray)[far] == 0, "paketten uzak kısım normal renk")


func test_dissolve_keep_breaks_the_bond() -> void:
	assert(BondMath.dissolve_keep(40.0, 100.0, 0.0) == 1.0, "çözülme yokken tam")
	var alive: int = 0
	for i in range(101):
		if BondMath.dissolve_keep(float(i), 100.0, 1.0) > 0.05:
			alive += 1
	assert(alive == 0, "çözülme bitince ip tamamen kopmuş olmalı (%d örnek kaldı)" % alive)


## Bağ halenin dosta bakan ALTIN pikselinden çıkar (kullanıcı: "tam halkadan çıksın") - nokta tablodaki pikselin merkezi ve
## Melek'in piksel ızgarasına tam oturur.
func test_halo_point_uses_the_table_pixel_on_the_facing_side() -> void:
	_ensure_scene()
	var melek := _remote(81, 10, Vector2(200.0, 150.0))
	var s: AnimatedSprite2D = melek.get_node("AnimatedSprite2D")
	var tex: AtlasTexture = s.sprite_frames.get_frame_texture(s.animation, s.frame) as AtlasTexture
	assert(tex != null, "Melek kareleri AtlasTexture olmalı")
	var sheet: String = tex.atlas.resource_path.get_file().get_basename()
	var pts: Array = BondMath.HaloTable.POINTS[sheet][Vector2i(tex.region.position)]
	var right: Array = BondMath.halo_point(melek, melek.global_position + Vector2(300, 0))
	var left: Array = BondMath.halo_point(melek, melek.global_position + Vector2(-300, 0))
	var size: Vector2 = tex.region.size
	var exp_r: Vector2 = s.to_global(s.offset + (pts[1] as Vector2) - size * 0.5)
	var exp_l: Vector2 = s.to_global(s.offset + (pts[0] as Vector2) - size * 0.5)
	assert((right[0] as Vector2).is_equal_approx(exp_r), "sağdaki dosta halenin sağ pikselinden")
	assert((left[0] as Vector2).is_equal_approx(exp_l), "soldaki dosta halenin sol pikselinden")
	var cell: Vector2 = ((right[0] as Vector2) - (right[1] as Vector2)) / float(right[2]) - Vector2(0.5, 0.5)
	assert(absf(cell.x - roundf(cell.x)) < 0.01 and absf(cell.y - roundf(cell.y)) < 0.01, "nokta piksel merkezinde olmalı")
	assert(absf(float(right[2]) - BondMath.TEXEL_W) < 0.01, "Melek pikseli ~0,903 dünya: %.3f" % float(right[2]))
	_cleanup()


func test_bond_forms_pulses_arrives_and_dissolves() -> void:
	_ensure_scene()
	var melek := _remote(82, 10, Vector2(100.0, 100.0))
	var ally := _remote(83, 7, Vector2(190.0, 110.0))
	ally.start_ally_aura_fx("heal", melek)
	var bond: Node = ally._ally_aura_fx.get("heal")
	assert(bond != null and bond.get_script() == BondScript, "dostta bağ kurulmalı")
	assert(bond.caster == melek, "bağın kasteri Melek")
	assert(_count("melek_bond_ribbon.gd") == 1, "ip sahnenin çocuğu olarak kurulmalı")
	assert(bond.ring_frame_now() == -1, "halka kuruluş bitmeden görünmez")
	bond.pulse()
	assert(bond.pulse_count() == 0, "kuruluş bitmeden gelen tik yok sayılır")
	var t: float = 0.0
	while not bond.is_connected_bond() and t < 1.0:
		_step(bond)
		t += 1.0 / 60.0
	assert(absf(t - BondMath.HEAD_TIME) < 0.05, "kuruluş ~%.2f sn: %.2f" % [BondMath.HEAD_TIME, t])
	assert(bond.ring_frame_now() >= 0 and bond.glyph_count() == 1, "değince halka açılır + büyük artı")
	## ağdan gelen tik (alıcı tarafı) aynı bağa paket yollar
	NetworkManager.broadcast_wave_fx(melek.global_position, String(ally.get_path()), "heal", 82, 83)
	assert(bond.pulse_count() == 1, "tik bağın üstünden paket yollamalı")
	assert(_count("fx_wave_beam.gd") == 0, "eski dalga ışını artık kurulmaz")
	var total: float = float(_ribbon_of(bond).get("last_total"))
	var arrive_t: float = 0.0
	while bond.pulse_count() > 0 and arrive_t < 3.0:
		_step(bond)
		arrive_t += 1.0 / 60.0
	assert(absf(arrive_t - total / BondMath.WAVE_SPEED) < 0.06, "paket sabit hızla varmalı (%.2f / %.2f)" % [arrive_t, total / BondMath.WAVE_SPEED])
	assert(bond.glyph_count() >= 1, "varışta artı yükselir")
	ally.stop_ally_aura_fx("heal")
	assert(bond.is_stopping() and not ally._ally_aura_fx.has("heal"), "durdurulunca çözülür, kayıt silinir")
	var rib: Node2D = _ribbon_of(bond)
	var end_t: float = 0.0
	while is_instance_valid(bond) and not bond.is_queued_for_deletion() and end_t < 2.0:
		_step(bond)
		end_t += 1.0 / 60.0
	assert(end_t < 1.0, "çözülme + halka kapanışı kısa: %.2f" % end_t)
	if is_instance_valid(bond):
		bond.free()
	assert(not is_instance_valid(rib) or rib.is_queued_for_deletion(), "ip de silinmeli")
	_cleanup()


## İki-yer kuralı: aura başlangıç RPC'si kasteri de çözer (ip onun halesinden çıksın); kaster yoksa sadece halka.
func test_network_aura_start_resolves_caster() -> void:
	_ensure_scene()
	var melek := _remote(84, 10, Vector2(100.0, 100.0))
	var ally := _remote(85, 7, Vector2(160.0, 100.0))
	NetworkManager.broadcast_ally_aura_start(84, 85, "shield")
	var bond: Node = ally._ally_aura_fx.get("shield")
	assert(bond != null and bond.caster == melek and bond.kind == "shield", "uzak kasterli kalkan bağı")
	var lone := _remote(86, 7, Vector2(400.0, 100.0))
	NetworkManager.broadcast_ally_aura_start(4242, 86, "heal")
	var b2: Node = lone._ally_aura_fx.get("heal")
	assert(b2 != null and b2.get("_ribbon") == null, "kaster bulunamazsa ipsiz (sadece halka) bağ")
	_cleanup()


func test_halo_fx_tints_ticks_registers_and_stops() -> void:
	_ensure_scene()
	var melek := _remote(87, 10, Vector2(100.0, 100.0))
	var fx: Node = HaloScene.instantiate()
	fx.set("aura_type", "shield")
	melek.add_child(fx)
	assert(melek._ally_aura_fx.get("shield") == fx, "uzak kopya kuklanın kaydına yazılmalı (durdurma RPC'si bulsun)")
	assert(fx.is_tinting() and fx.is_bright(), "kuruluşta hale bağ renginde ve parlak")
	assert(fx.glyph_count() == 1, "E'nin ilk tiki: kristal")
	var t: float = 0.0
	while t < 0.6:
		fx._process(1.0 / 60.0)
		t += 1.0 / 60.0
	assert(not fx.is_bright() and fx.glyph_count() == 0, "parlama ve kristal kısa sürer")
	while t < 1.02:
		fx._process(1.0 / 60.0)
		t += 1.0 / 60.0
	assert(fx.is_bright() and fx.glyph_count() == 1, "her saniye tik: parlama + kristal")
	melek.stop_ally_aura_fx("shield")
	assert(not fx.is_tinting(), "durunca hale normale döner")
	var end_t: float = 0.0
	while is_instance_valid(fx) and not fx.is_queued_for_deletion() and end_t < 1.0:
		fx._process(1.0 / 60.0)
		end_t += 1.0 / 60.0
	assert(end_t < 0.7, "glifler bitince silinmeli")
	_cleanup()


## Oyuncu düzeyi: Melek Q -> kendinde bağ renkli hale, en düşük canlı dostta bağ; eski yıldız/dalga efektleri yok.
func test_player_melek_q_spawns_halo_and_bond_on_ally() -> void:
	_ensure_scene()
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 10
	GameManager.selected_character = 1 ## Q yetenek kimliği: Can Basma (tik bunu okur)
	NetworkManager.is_multiplayer_active = false
	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(100.0, 100.0)
	var ally := _remote(88, 7, Vector2(180.0, 100.0))
	ally.set("health", 20.0) ## en düşük canlı dost (oyuncunun evcil hayvanı da "player_ally" grubunda)
	player._skill_heal()
	var halo: Node = player._ally_aura_fx.get("heal")
	assert(halo != null and halo.scene_file_path == "res://scenes/fx_melek_halo.tscn", "Melek'te bağ renkli hale")
	var bond: Node = ally._ally_aura_fx.get("heal")
	assert(bond != null and bond.get_script() == BondScript and bond.caster == player, "dostta Melek'ten gelen bağ")
	for c in player.get_children():
		var sc: Variant = c.get_script()
		assert(sc == null or not str(sc.resource_path).ends_with("fx_oyku_heal.gd"), "eski altıgen yıldız efekti kalkmalı")
	## tik: bağ kurulduktan sonra paket
	var t: float = 0.0
	while not bond.is_connected_bond() and t < 1.0:
		_step(bond)
		t += 1.0 / 60.0
	player.skill_state = "active"
	player._process_healer_heal_tick(1.01)
	assert(bond.pulse_count() == 1, "Q tiki dostun bağına paket yollamalı")
	player._end_skill_effects()
	assert(not ally._ally_aura_fx.has("heal") and bond.is_stopping(), "yetenek bitince bağ çözülür")
	assert(not player._ally_aura_fx.has("heal"), "Melek'in halesi de durur")
	if is_instance_valid(bond):
		bond.free()
	_cleanup()
