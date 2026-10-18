extends Node

## Yağmur (scripts/weather_rain.gd) - FPS turu (2026-10-18): animasyon GPU'ya taşındı (shaders/weather_rain.gdshader), CPU sadece yere değen damlayı bulup
## yeniden doğurur / görüş alanından çıkanı taşır / sıçrama-halka doğurur. Bu test o CPU mantığının eski davranışla aynı kurallarını sınar.

const RainScript := preload("res://scripts/weather_rain.gd")

var _nodes: Array = []


func _rain() -> Node2D:
	var r := Node2D.new()
	r.set_script(RainScript)
	add_child(r)
	r.set_process(false) ## süre testte elle ilerletilir
	_nodes.append(r)
	return r


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _step(r: Node2D, seconds: float, dt: float = 1.0 / 60.0) -> void:
	var t: float = 0.0
	while t < seconds:
		r.call("_process", dt)
		t += dt


func test_drop_count_follows_intensity_and_respects_the_capacity() -> void:
	var r := _rain()
	r.call("set_intensity", 1.0, 1.0, 0.0)
	_step(r, 3.0)
	var n: int = int(r.get("_n"))
	var view: Rect2 = r.get("_view")
	var expect: int = int(round(RainScript.MAX_DROPS * 1.0 * clampf(view.get_area() / RainScript.REFERENCE_AREA, 0.5, 2.5)))
	assert(absi(n - expect) <= 2, "damla sayısı hedefe (%d) yaklaşmalı: %d" % [expect, n])
	assert(n <= RainScript.DROP_CAP)
	## sağanak: daha çok damla
	r.call("set_intensity", 1.6, 1.0, 1.0)
	_step(r, 4.0)
	assert(int(r.get("_n")) > n, "şiddet artınca damla sayısı artmalı: %d -> %d" % [n, int(r.get("_n"))])
	assert((r.get("_drops_mm") as MultiMesh).visible_instance_count == int(r.get("_n")), "çizilen örnek sayısı etkin damla sayısı olmalı")
	_cleanup()


func test_every_drop_keeps_old_parameter_ranges_and_lands_on_time() -> void:
	var r := _rain()
	r.call("set_intensity", 1.0, -1.0, 0.0)
	_step(r, 2.0)
	var speed: PackedFloat32Array = r.get("_speed")
	var h0: PackedFloat32Array = r.get("_h0")
	var land: PackedFloat32Array = r.get("_land")
	var t0: PackedFloat32Array = r.get("_t0")
	var ln: PackedFloat32Array = r.get("_len")
	for i in range(int(r.get("_n"))):
		assert(speed[i] >= RainScript.DROP_MIN_SPEED - 0.01 and speed[i] <= RainScript.DROP_MAX_SPEED + 0.01, "hız aralığı: %f" % speed[i])
		assert(ln[i] >= RainScript.DROP_MIN_LEN - 0.01 and ln[i] <= RainScript.DROP_MAX_LEN + 0.01, "boy aralığı: %f" % ln[i])
		assert(h0[i] > 0.0 and h0[i] <= RainScript.DROP_MAX_HEIGHT + 0.01, "yükseklik: %f" % h0[i])
		assert(absf(land[i] - (t0[i] + h0[i] / speed[i])) < 0.0001, "iniş saati = doğuş + yükseklik / hız")
	_cleanup()


func test_landing_spawns_splashes_and_respawns_the_drop() -> void:
	var r := _rain()
	r.call("set_intensity", 1.0, 1.0, 0.0)
	_step(r, 4.0)
	assert(float(r.get("_splash_last")) > -100.0, "yere değen damlalar sıçrama bırakmalı")
	assert(int(r.get("_splash_next")) > 0 or float(r.get("_splash_last")) > 0.0)
	var n_before: int = int(r.get("_n"))
	_step(r, 2.0)
	assert(absi(int(r.get("_n")) - n_before) <= 2, "yeniden doğma damla sayısını korumalı (hedefte): %d -> %d" % [n_before, int(r.get("_n"))])
	## hepsi hâlâ yaşıyor: iniş saati şimdiden SONRA ya da bu karede (yeniden doğanlar)
	var land: PackedFloat32Array = r.get("_land")
	var clock: float = float(r.get("_clock"))
	for i in range(int(r.get("_n"))):
		assert(land[i] > clock - 0.0001 - 1.0 / 60.0, "inmiş damla yerinde bırakılmamalı: iniş %f saat %f" % [land[i], clock])
	_cleanup()


func test_rain_stops_and_node_hides_after_the_drops_finish() -> void:
	var r := _rain()
	r.call("set_intensity", 1.0, 1.0, 0.0)
	_step(r, 3.0)
	assert(r.visible)
	r.call("set_intensity", 0.0, 1.0, 0.0)
	_step(r, 2.5) ## en uzun düşüş ~0,5 sn + sıçrama/halka ömrü
	assert(int(r.get("_n")) == 0, "şiddet 0: damlalar inince kalkmalı: %d" % int(r.get("_n")))
	assert(not r.visible, "yağmur bitip sıçramalar sönünce düğüm gizlenmeli")
	_cleanup()


func test_camera_jump_moves_out_of_view_drops_without_losing_height() -> void:
	var r := _rain()
	r.call("set_intensity", 1.0, 1.0, 0.0)
	_step(r, 2.0)
	var before: int = int(r.get("_n"))
	var vp := get_viewport()
	vp.canvas_transform = Transform2D(0.0, Vector2(-5000.0, -5000.0)) ## kamera çok uzağa atladı
	_step(r, 0.2)
	var expanded: Rect2 = (r.get("_view") as Rect2).grow(60.0)
	var ground: PackedVector2Array = r.get("_ground")
	var out: int = 0
	for i in range(int(r.get("_n"))):
		if not expanded.has_point(ground[i]):
			out += 1
	assert(out <= 2, "görünür alanın dışında kalan damla taşınmalı: %d" % out)
	assert(absi(int(r.get("_n")) - before) <= 3)
	vp.canvas_transform = Transform2D.IDENTITY
	_cleanup()


func test_multimeshes_cover_the_world_and_use_the_shared_shader() -> void:
	var r := _rain()
	for mmi in r.get_children():
		assert(mmi is MultiMeshInstance2D)
		var mm: MultiMesh = (mmi as MultiMeshInstance2D).multimesh
		assert(mm.use_custom_data and mm.transform_format == MultiMesh.TRANSFORM_2D)
		assert(mm.custom_aabb.size.x > 1.0e5, "örnekler orijinde değil: kamera uzakken çizim atılmasın diye custom_aabb büyük olmalı")
		assert(((mmi as MultiMeshInstance2D).material as ShaderMaterial).shader == RainScript.RainShader)
	_cleanup()
