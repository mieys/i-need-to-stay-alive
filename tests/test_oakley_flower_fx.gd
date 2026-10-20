extends Node

## Oakley çiçeği "Yaprak Halkası" (madde 285, oakley_flower_fx.gd): kullanıcı prototip C'yi seçti, "halkada sadece yaprak olsun son formunda
## tohum da var" -> açmışta altın taç yaprağı YOK, 2/4/6 yaprak. Kapsam: aşama başına yaprak sayısı + ön/arka bölünmesi, büyüme geçişinde
## açısal kayma sıçramasız, faz birikimi (hız artınca zıplamaz), havuz dokusu kesintisiz kenar + simetri, çiçeğin geçiş durumu.

const Fx: GDScript = preload("res://scripts/oakley_flower_fx.gd")
const FlowerScript: GDScript = preload("res://scripts/oakley_flower.gd")


func test_only_leaves_and_counts_grow_per_stage() -> void:
	assert(Fx.N_LEAF == [2, 4, 6], "filiz 2 / tomurcuk 4 / açmış 6 yaprak (taç yaprağı yok)")
	var src: String = FileAccess.get_file_as_string("res://scripts/oakley_flower_fx.gd")
	assert(not src.to_lower().contains("petal"), "kullanıcı: halkada sadece yaprak - taç yaprağı (petal) çizimi olmamalı")
	for s in 3:
		var st: Array = Fx.state(5.0, 1.234, s, s, 99.0)
		var front: int = 0
		var back: int = 0
		for idx in Fx.N_LEAF[s]:
			var p: Vector4 = Fx.leaf_pos(st, idx)
			if sin(p.w) >= 0.0:
				front += 1
			else:
				back += 1
			assert(absf(p.x) <= Fx.R[s] + 0.01, "yaprak yörüngede")
			assert(p.z < p.y, "yaprak havada (gölgesinin üstünde)")
		assert(front + back == Fx.N_LEAF[s] and front > 0 and back > 0, "aşama %d: yaprakların bir kısmı önde bir kısmı arkada" % s)


func test_growth_transition_slides_without_jumps() -> void:
	## geçişin başında eski yapraklar ESKİ aralıkta (sıçrama yok), sonunda yeni aralıkta; yeni yaprak 0 alfadan belirir
	var st0: Array = Fx.state(5.0, 0.0, 0, 1, 0.0)
	var before: Array = Fx.state(5.0, 0.0, 0, 0, 99.0)
	for idx in 2:
		assert(is_equal_approx(Fx.leaf_pos(st0, idx).w, Fx.leaf_pos(before, idx).w), "geçiş başında yaprak %d yerinde" % idx)
	assert(Fx.leaf_alpha(st0, 2) == 0.0 and Fx.leaf_alpha(st0, 3) == 0.0, "yeni yapraklar görünmezden başlar")
	var st1: Array = Fx.state(5.0, 0.0, 0, 1, Fx.TRANS)
	assert(is_equal_approx(Fx.leaf_pos(st1, 1).w, TAU / 4.0), "geçiş sonunda 4'lü aralık")
	assert(Fx.leaf_alpha(st1, 3) == 1.0)
	assert(Fx.orbit_radius(Fx.state(5.0, 0.0, 0, 1, Fx.TRANS * 0.5)) > Fx.R[1], "geçişin ortasında yapraklar dışa savrulur")
	assert(is_equal_approx(Fx.orbit_radius(st1), Fx.R[1]), "sonra yerine oturur")


func test_orbit_phase_accumulates_across_speed_change() -> void:
	var f := Node2D.new()
	f.set_script(FlowerScript)
	add_child(f)
	f.call("setup", 40.0, "fx_test")
	for i in 30:
		f.call("_process_fx", 0.05)
	var ph: float = f.get("_orbit_phase")
	assert(is_equal_approx(ph, Fx.SPEED[0] * 1.5), "faz hızla birikir: %s" % ph)
	## büyüme: hız 1,3 -> 1,5 geçişte yumuşak kayar, faz geri/ileri sıçramaz
	f.set("_grow_from", 0)
	f.set("_growth_stage", 1)
	f.set("_grow_age", 0.0)
	f.call("_process_fx", 0.05)
	var ph2: float = f.get("_orbit_phase")
	assert(ph2 > ph and ph2 - ph < 0.1, "tek karede küçük adım: %s -> %s" % [ph, ph2])
	var st: Array = f.call("fx_state")
	assert(st[2] == 0 and st[3] == 1 and st[4] > 0.0 and st[4] < 1.0, "çiçek geçiş durumunu verir: %s" % str(st))
	f.free()


## FPS (2026-10-19): boyama GPU'da - çiçek başına TEK materyal, üç dörtgen (zemin kardeşte, arka sprite'tan önce, ön sonra), kare başı yalnız konumlar.
func test_shader_quads_share_one_material_and_get_leaf_positions() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var f := Node2D.new()
	f.set_script(FlowerScript)
	holder.add_child(f)
	f.call("setup", 40.0, "fx_test_2")
	await get_tree().process_frame
	var back: Sprite2D = f.get_node("FxBack")
	var front: Sprite2D = f.get_node("FxFront")
	var spr: Node = f.get_node("AnimatedSprite2D")
	assert(back.get_index() < spr.get_index() and front.get_index() > spr.get_index(), "arka yarı çiçeğin arkasında, ön yarı önünde")
	var ground: Sprite2D = (f.get("_ground_fx") as Node).get_node("FxGround")
	var mat: ShaderMaterial = back.material
	assert(mat != null and front.material == mat and ground.material == mat, "üç dörtgen tek materyali paylaşır")
	assert(mat.shader.resource_path == "res://shaders/oakley_yaprak_halkasi.gdshader")
	var reds: Array = []
	for q in [ground, back, front]:
		reds.append((q as Sprite2D).texture.get_image().get_pixel(0, 0).r)
	assert(reds[0] < 0.25 and reds[1] > 0.25 and reds[1] < 0.75 and reds[2] > 0.75, "katman kimliği dokunun kırmızısında: %s" % str(reds))
	assert(back.scale == Fx.QUAD_SIZE and back.position == Fx.QUAD_ORIGIN and not back.centered)
	## açmış: 6 yaprak konumu leaf_pos ile birebir
	f.set("_growth_stage", 2)
	f.set("_grow_from", 2)
	f.call("_process_fx", 0.1)
	var st: Array = f.call("fx_state")
	var la: PackedVector4Array = mat.get_shader_parameter("leaf_a")
	var p1: Vector4 = mat.get_shader_parameter("p1")
	assert(la.size() == Fx.MAX_LEAVES and int(p1.x) == 6, "6 yaprak yazılır: %s" % str(p1))
	for idx in 6:
		var p: Vector4 = Fx.leaf_pos(st, idx)
		assert(la[idx].x == p.x and la[idx].y == p.z and la[idx].z == p.w, "yaprak %d konumu" % idx)
	var p0: Vector4 = mat.get_shader_parameter("p0")
	assert(is_equal_approx(p0.x, Fx.R[2]) and is_equal_approx(p0.y, Fx.POOL[2]), "yörünge/havuz yarıçapı: %s" % str(p0))
	assert(not FileAccess.get_file_as_string("res://scripts/oakley_flower_fx.gd").contains("draw_rect("), "kare başı piksel çizimi (eski 0,54 ms/çiçek) geri gelmesin")
	holder.queue_free()
	await get_tree().process_frame
