extends Node

## Test amaçlı, oyun içinden ayarlanabilir saldırı efekti ince ayarları.
## F9 ile açılan debug panelinden (debug_tuning_panel.gd) her karakterin
## saldırı efektinin rotasyonunu ve boyutunu canlı olarak değiştirebilir,
## "Kaydet" ile diske yazıp kalıcı hale getirebilirsin - Characters.DEFS'teki
## sabit değerlerin ÜZERİNE gelir, onları silmez. Kayıt dosyasını silmek
## (user://combat_tuning.json) tüm karakterleri koddaki varsayılanlara
## döndürür.

const SAVE_PATH := "user://combat_tuning.json"

## char_id (String) -> {"rotation_offset_deg": float, "scale_mult": float}
var overrides: Dictionary = {}


func _ready() -> void:
	load_overrides()


func load_overrides() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		overrides = data


func save_overrides() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(overrides))


func get_value(char_id: int, key: String, default_value: float) -> float:
	var cid := str(char_id)
	if overrides.has(cid) and overrides[cid].has(key):
		return float(overrides[cid][key])
	return default_value


func set_value(char_id: int, key: String, value: float) -> void:
	var cid := str(char_id)
	if not overrides.has(cid):
		overrides[cid] = {}
	overrides[cid][key] = value


func clear_char(char_id: int) -> void:
	overrides.erase(str(char_id))
	save_overrides()
