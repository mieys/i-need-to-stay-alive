extends Node

## TAKILMA (hitch) KAYDEDİCİ (2026-10-06): kullanıcı "bazen dükkana girince (ETKİLEŞİM) tüm oyun birkaç saniye donuyor, çok oyunculu odada"
## dedi; ekransız/tek oyunculu ölçümlerde (150 yaratıkla bile) tekrar üretilemedi. Bu düğüm, bir kare THRESHOLD_MS'den uzun sürerse
## NEDENİNİ ayırt etmeye yarayan bağlamı user://hitch_log.txt'ye yazar (Windows: %APPDATA%\Godot\app_userdata\<proje>\hitch_log.txt;
## godot.log her açılışta döndüğü için ayrı dosya): sahne, çok oyunculu durum, yaratık sayısı, kare içinde script (process) ve fizik
## süreleri, nesne/çizim sayıları ve son birkaç olay işareti (HitchLog.mark - ör. "shop_open", "shop_setup 94 ms").
## Nasıl okunur: proc/phys büyükse (kare süresine yakın) takılma oyun kodunda; ikisi de küçükken kare uzunsa kare kodun DIŞINDA bekledi
## (ekran kartı/sürücü, disk, ses, ağ). Başsız çalışmada (testler) hiç çalışmaz, kullanıcının kayıtlarını kirletmez.

const THRESHOLD_MS := 300.0
const MAX_ENTRIES := 60 ## oturum başına
const MAX_FILE_BYTES := 300000
const MAX_MARKS := 12
const MARK_WINDOW_MS := 15000

static var log_path: String = "user://hitch_log.txt" ## testler set_log_path ile değiştirir
static var _marks: Array = [] ## [Time.get_ticks_msec(), metin]

var _last_usec: int = 0
var _entries: int = 0


## (const preload referansı üzerinden statik değişkene atanamaz - bkz. testler.)
static func set_log_path(path: String) -> void:
	log_path = path


## Olay işareti: takılma kaydına "ne zamandan beri" ile eklenir.
static func mark(text: String) -> void:
	_marks.append([Time.get_ticks_msec(), text])
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()


## SAF: bu kare uzunluğu kaydedilmeli mi?
static func should_record(frame_ms: float, entries_so_far: int) -> bool:
	return frame_ms >= THRESHOLD_MS and entries_so_far < MAX_ENTRIES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_usec != 0:
		var ms: float = float(now - _last_usec) / 1000.0
		if should_record(ms, _entries):
			_entries += 1
			write_entry(ms, describe())
	_last_usec = now


## Bağlam satırı (tek satır).
func describe() -> String:
	var tree: SceneTree = get_tree()
	var parts: PackedStringArray = []
	parts.append("scene=%s" % (tree.current_scene.name if tree.current_scene else "-"))
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm != null:
		parts.append("mp=%s host=%s peers=%d" % [str(nm.get("is_multiplayer_active")), str(nm.get("is_host")), tree.get_nodes_in_group("remote_players").size()])
	parts.append("enemies=%d" % tree.get_nodes_in_group("enemies").size())
	parts.append("proc=%.1fms phys=%.1fms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	parts.append("nodes=%d orphans=%d draw=%d vram=%dMB" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])
	var gm: Node = get_node_or_null("/root/GameManager")
	var panel: bool = gm != null and gm.has_method("is_any_blocking_panel_open") and bool(gm.call("is_any_blocking_panel_open"))
	parts.append("panel=%s paused=%s focus=%s" % [str(panel), str(tree.paused), str(DisplayServer.window_is_focused())])
	parts.append("marks=[%s]" % ", ".join(recent_marks()))
	return " | ".join(parts)


static func recent_marks() -> PackedStringArray:
	var out: PackedStringArray = []
	var now: int = Time.get_ticks_msec()
	for m in _marks:
		var age: int = now - int(m[0])
		if age <= MARK_WINDOW_MS:
			out.append("%s (-%.1fs)" % [str(m[1]), age / 1000.0])
	return out


static func write_entry(frame_ms: float, context: String) -> void:
	var line: String = "[%s] HITCH %.0f ms | %s\n" % [Time.get_datetime_string_from_system(false, true), frame_ms, context]
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		return
	if f.get_length() > MAX_FILE_BYTES:
		f.close()
		f = FileAccess.open(log_path, FileAccess.WRITE) ## dosya şişmesin: baştan başla
		if f == null:
			return
	else:
		f.seek_end()
	f.store_string(line)
	f.close()
