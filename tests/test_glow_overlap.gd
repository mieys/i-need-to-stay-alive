extends Node

## Üst üste binen parıltılar (2026-11-08, kullanıcı: "parlaklığı olan şeyler üst üste binince çok parlak oluyor"):
##  - zindan fenerleri gücü paylaşır: tam üst üste n fener = tek fener, uzaktakiler tam güç,
##  - gece ışık haritası kısık çizilir, shader aynı oranla geri açar (8 bit kırpılma payı) + toplamın yumuşak tavanı var,
##  - toplamalı efekt sprite'ları paylaşılan yumuşak parıltı materyalini kullanır (premul, alfa = en güçlü kanal).

const DungeonLight := preload("res://scripts/dungeon/dungeon_light.gd")
const AtmosphereOverlay := preload("res://scripts/atmosphere_overlay.gd")
const SoftGlow := preload("res://scripts/soft_glow_blend.gd")
const GradeShader: Shader = preload("res://shaders/atmosphere_grade.gdshader")


func _uniform_default(code: String, name: String) -> float:
	var re := RegEx.new()
	re.compile("uniform float " + name + "\\s*=\\s*([0-9.]+)")
	var m: RegExMatch = re.search(code)
	assert(m != null, "uniform yok: " + name)
	return float(m.get_string(1))


func test_lone_and_distant_lanterns_keep_full_energy() -> void:
	var p1: Array[Vector2] = [Vector2.ZERO]
	var one: PackedFloat32Array = DungeonLight.lantern_share(p1)
	assert(is_equal_approx(one[0], 1.0))
	var far: float = DungeonLight.LANTERN_SHARE_RANGE + 1.0
	var p2: Array[Vector2] = [Vector2.ZERO, Vector2(far, 0.0)]
	var two: PackedFloat32Array = DungeonLight.lantern_share(p2)
	assert(is_equal_approx(two[0], 1.0) and is_equal_approx(two[1], 1.0))


func test_stacked_lanterns_sum_to_one_lantern() -> void:
	for n in [2, 3, 4, 5]:
		var pos: Array[Vector2] = []
		for i in range(n):
			pos.append(Vector2.ZERO)
		var share: PackedFloat32Array = DungeonLight.lantern_share(pos)
		var total: float = 0.0
		for s in share:
			total += s
		assert(is_equal_approx(total, 1.0), "%d fener üst üste toplam %f" % [n, total])


func test_partial_overlap_is_between() -> void:
	var p: Array[Vector2] = [Vector2.ZERO, Vector2(DungeonLight.LANTERN_SHARE_RANGE * 0.5, 0.0)]
	var share: PackedFloat32Array = DungeonLight.lantern_share(p)
	assert(share[0] > 0.5 and share[0] < 1.0)
	assert(is_equal_approx(share[0], share[1]))


func test_light_map_headroom_matches_shader() -> void:
	var scale: float = _uniform_default(GradeShader.code, "light_map_scale")
	assert(is_equal_approx(scale * AtmosphereOverlay.LIGHT_MAP_HEADROOM, 1.0))
	assert(AtmosphereOverlay.LIGHT_MAP_HEADROOM < 1.0)


func test_soft_cap_leaves_single_lights_alone() -> void:
	var knee: float = _uniform_default(GradeShader.code, "light_knee")
	var ceiling: float = _uniform_default(GradeShader.code, "light_ceiling")
	assert(ceiling > knee)
	## Gece light_gain en çok AtmosphereMath LIGHT_STRENGTH (0,8); sıradan tek ışık GLOW_ENERGY_CAP'te -> dizin altında kalmalı.
	assert(AtmosphereOverlay.GLOW_ENERGY_CAP * 0.8 <= knee)
	## Tavan, eski kırpılmış hâlin (harita 1 x 0,8) altında: üst üste binme eskisinden parlak olamaz.
	assert(ceiling < 0.8)


func test_soft_glow_material_is_shared_premul() -> void:
	var a: Material = SoftGlow.material()
	assert(a != null and a == SoftGlow.material())
	assert((a as ShaderMaterial).shader.code.contains("blend_premul_alpha"))
