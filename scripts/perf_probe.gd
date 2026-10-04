extends CanvasLayer

## Cihaz üstü performans testi (Debug menüsü > "Perf") - kullanıcı bildirimi (2026-10-03): telefonda "evden çıkınca 30 fps
## civarı", evin içinde 60. Masaüstünde ölçülen GPU payları (çimen/toprak/güneş-bulut) düzeltildiği halde telefonda FPS
## değişmedi -> masaüstü ölçümü telefonu temsil etmiyor (masaüstü GPU'su bant genişliği bol, telefon tam tersi). Bu test
## TELEFONUN KENDİSİNDE her sistemi sırayla birkaç saniye kapatıp ölçer ve sonucu ekranda tablo olarak gösterir; kullanıcı
## ekran görüntüsünü gönderir, darboğaz tahmin yerine ölçümle bulunur.
##
## Ölçülenler (adım başına ortalama):
##  - kare ms   : iki kare arası gerçek süre (vsync açıksa 16.7 / 33.3'e yapışır - bu yüzden test sırasında vsync KAPATILMAYA
##                çalışılır; telefon izin vermezse başlıkta "vsync: açık kaldı" yazar, o zaman GPU/mantık sütunlarına bak).
##  - mantık ms : karenin ilk fizik/işlem sinyalinden çizim başlangıcına kadar (oyun kodu, CPU).
##  - GPU ms    : ana ekran + tüm SubViewport'ların ölçülen GPU süresi toplamı.
##  - rCPU ms   : aynı görünümlerin çizim komutlarını hazırlama (render thread CPU) süresi toplamı - çok karo katmanı/çizim
##                komutu telefonda burada pahalı olabilir (masaüstünde harita gizlenince GPU değil bu düşüyordu).
##  - çizim     : karedeki toplam çizim komutu sayısı.
## Tamamen yerel; oyun durumunu değiştirmez (sadece görünürlük/işlem açılıp geri kapanır). Ölümsüzlük açmak önerilir.

const SETTLE_S := 1.0
const MEASURE_S := 2.5
const FS := 28
const GROUND_LAYERS: Array[String] = ["Zemin Toprak", "Zemin Çimen"]

var _main: Node = null
var _saved: Array = [] ## [obj, prop, eski değer]
var _status: Label = null
var _panel: PanelContainer = null
var _rows: Array = []
var _t_start: int = -1
var _logic_sum: float = 0.0
var _logic_n: int = 0
var _measuring: bool = false


static func start(tree: SceneTree) -> void:
	var old: Node = tree.root.get_node_or_null("PerfProbe")
	if old:
		return
	var p: CanvasLayer = load("res://scripts/perf_probe.gd").new()
	p.name = "PerfProbe"
	tree.root.add_child(p)


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status = Label.new()
	UIKit.style_label(_status, FS, UIKit.C_TEXT)
	_status.position = Vector2(24, 24)
	add_child(_status)
	get_tree().physics_frame.connect(_on_frame_start)
	get_tree().process_frame.connect(_on_frame_start)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_run.call_deferred()


func _on_frame_start() -> void:
	if _t_start < 0:
		_t_start = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	if _t_start >= 0 and _measuring:
		_logic_sum += float(Time.get_ticks_usec() - _t_start) / 1000.0
		_logic_n += 1
	_t_start = -1


func _exit_tree() -> void:
	_restore()
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)


## ------------------------------------------------------------------ adımlar
func _put(obj: Object, prop: StringName, value: Variant) -> void:
	if obj == null or not is_instance_valid(obj) or not (prop in obj):
		return
	_saved.append([obj, prop, obj.get(prop)])
	obj.set(prop, value)


func _off(n: Node) -> void:
	if n == null:
		return
	_put(n, &"visible", false)
	_put(n, &"process_mode", Node.PROCESS_MODE_DISABLED)


func _restore() -> void:
	for i in range(_saved.size() - 1, -1, -1):
		var e: Array = _saved[i]
		if is_instance_valid(e[0]):
			(e[0] as Object).set(e[1], e[2])
	_saved.clear()


func _n(path: String) -> Node:
	return _main.get_node_or_null(path) if _main else null


func _fog() -> void: _off(get_tree().get_first_node_in_group("vision_fog"))
func _grade() -> void: _off(_n("AtmosphereOverlay"))
func _sun() -> void:
	_off(_n("SunClouds"))
	_off(_n("SunLight"))
func _weather() -> void:
	_off(_n("Atmosphere/Rain"))
	_off(_n("Atmosphere/Wind"))
func _vignette() -> void: _off(_n("VignetteOverlay"))
func _ground_plain() -> void:
	for nm: String in GROUND_LAYERS:
		_put(_n("Harita/Yer/" + nm), &"material", null)
func _ground_old() -> void: _put(_n("Harita/Yer/ZeminDunyaPikseli"), &"enabled", false)
func _map_objects() -> void:
	var h: Node = _n("Harita")
	if h:
		for c in h.get_children():
			if c is CanvasItem and c.name != "Yer" and c.name != "Su":
				_put(c, &"visible", false)
func _map_all() -> void: _put(_n("Harita"), &"visible", false)
func _enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		_put(e, &"visible", false)
func _hud() -> void:
	_off(_n("HUD"))
	_off(_n("TouchControls"))
func _all_off() -> void:
	_fog(); _grade(); _sun(); _weather(); _vignette(); _map_all(); _enemies(); _hud()


func _steps() -> Array:
	return [
		["Temel (her şey açık)", Callable()],
		["Sis kapalı", _fog],
		["Gün-gece rengi kapalı", _grade],
		["Güneş/bulut kapalı", _sun],
		["Yağmur/rüzgar kapalı", _weather],
		["Vinyet kapalı", _vignette],
		["Zemin shader'sız", _ground_plain],
		["Zemin eski yol", _ground_old],
		["Harita objeleri gizli", _map_objects],
		["Harita tamamen gizli", _map_all],
		["Yaratıklar gizli", _enemies],
		["Arayüz gizli", _hud],
		["Hepsi kapalı", _all_off],
		["Temel (tekrar)", Callable()],
	]


## ------------------------------------------------------------------ ölçüm
func _viewports() -> Array[RID]:
	var out: Array[RID] = [get_tree().root.get_viewport_rid()]
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is SubViewport:
				out.append((c as SubViewport).get_viewport_rid())
	return out


func _wait(s: float) -> void:
	var end: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _measure() -> Dictionary:
	await _wait(SETTLE_S)
	var vps: Array[RID] = _viewports()
	for r in vps:
		RenderingServer.viewport_set_measure_render_time(r, true)
	await get_tree().process_frame
	_logic_sum = 0.0
	_logic_n = 0
	_measuring = true
	var gpu: float = 0.0
	var rcpu: float = 0.0
	var draws: float = 0.0
	var frames: int = 0
	var worst: float = 0.0
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var end: int = Time.get_ticks_msec() + int(MEASURE_S * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		for r in vps:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(r)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(r)
	_measuring = false
	var frame_ms: float = float(last - t0) / 1000.0 / maxf(1.0, float(frames))
	return {
		"fps": 1000.0 / maxf(frame_ms, 0.001),
		"frame": frame_ms,
		"worst": worst,
		"logic": _logic_sum / maxf(1.0, float(_logic_n)),
		"gpu": gpu / maxf(1.0, float(frames)),
		"rcpu": rcpu / maxf(1.0, float(frames)),
		"draws": draws / maxf(1.0, float(frames)),
	}


func _run() -> void:
	_main = get_tree().current_scene
	var old_vsync: int = DisplayServer.window_get_vsync_mode()
	var old_max_fps: int = Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vsync_off: bool = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED
	var steps: Array = _steps()
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	for i in range(steps.size()):
		var step: Array = steps[i]
		_status.text = "Performans testi %d/%d: %s  (telefonu oynatma, ~%d sn)" % [i + 1, steps.size(), step[0],
			int((steps.size() - i) * (SETTLE_S + MEASURE_S))]
		var fn: Callable = step[1]
		if fn.is_valid():
			fn.call()
		var r: Dictionary = await _measure()
		_restore()
		r["name"] = step[0]
		_rows.append(r)
		print("PERF %-24s fps %5.1f | kare %6.2f ms (en kötü %6.2f) | mantik %6.2f ms | gpu %6.2f ms | rcpu %6.2f ms | cizim %d" % [
			r["name"], r["fps"], r["frame"], r["worst"], r["logic"], r["gpu"], r["rcpu"], int(r["draws"])])
	DisplayServer.window_set_vsync_mode(old_vsync)
	Engine.max_fps = old_max_fps
	_status.text = ""
	var info: String = "%s | %s | %s %s | ekran %s | çekirdek %d | yaratık %d | vsync: %s" % [
		OS.get_model_name(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method(),
		str(DisplayServer.window_get_size()), OS.get_processor_count(), enemies,
		"kapatıldı" if vsync_off else "açık kaldı"]
	print("PERF INFO ", info)
	_show_results(info)


func _show_results(info: String) -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var head := Label.new()
	UIKit.style_label(head, FS, UIKit.C_TEXT)
	head.text = info
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.custom_minimum_size = Vector2(1500, 0)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	var cells: Array = ["Durum", "FPS", "kare ms", "en kötü", "mantık ms", "GPU ms", "rCPU ms", "çizim"]
	for r: Dictionary in _rows:
		cells.append_array([r["name"], "%.1f" % r["fps"], "%.2f" % r["frame"], "%.1f" % r["worst"], "%.2f" % r["logic"],
			"%.2f" % r["gpu"], "%.2f" % r["rcpu"], "%d" % int(r["draws"])])
	for i in range(cells.size()):
		var l := Label.new()
		UIKit.style_label(l, FS, UIKit.C_TEXT if i >= 8 else UIKit.C_TEXT_DIM)
		l.text = String(cells[i])
		grid.add_child(l)
	var close_btn := Button.new()
	close_btn.text = "Kapat"
	UIKit.style_button(close_btn, "wood", false, FS)
	close_btn.custom_minimum_size = Vector2(240, 64)
	close_btn.pressed.connect(queue_free)
	box.add_child(close_btn)
	await get_tree().process_frame
	var vp: Vector2 = _panel.get_viewport_rect().size
	_panel.position = ((vp - _panel.size) * 0.5).floor()
