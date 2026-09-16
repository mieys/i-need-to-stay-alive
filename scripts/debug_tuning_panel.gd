extends CanvasLayer

## Test/geliştirme paneli: F9 ile açılır, ortak "ana silah"ın (bkz.
## Characters.MAIN_WEAPON, herkes artık bununla başlıyor) savuruş efekti
## rotasyonunu ve boyutunu canlı gösterip ayarlamana izin verir. "Kaydet"
## değerleri CombatTuning üzerinden user://combat_tuning.json'a MAIN_WEAPON_
## TUNING_ID sabit kimliğiyle yazar - karakterden bağımsız, tek paylaşılan
## silah için geçerlidir. "Sıfırla" bu kaydı siler, koddaki (Characters.
## MAIN_WEAPON) varsayılana döner. Sadece bu oturumda denemek istiyorsan
## Kaydet'e basmadan kapatman yeterli - sahne değişince canlı değişiklik
## zaten sıfırlanır.

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var rot_slider: HSlider = $Panel/VBox/RotRow/RotSlider
@onready var rot_value_label: Label = $Panel/VBox/RotRow/RotValue
@onready var scale_slider: HSlider = $Panel/VBox/ScaleRow/ScaleSlider
@onready var scale_value_label: Label = $Panel/VBox/ScaleRow/ScaleValue
@onready var save_button: Button = $Panel/VBox/Buttons/SaveButton
@onready var reset_button: Button = $Panel/VBox/Buttons/ResetButton
@onready var saved_label: Label = $Panel/VBox/SavedLabel

## Artık tek bir paylaşılan ana silah var, karaktere göre değil - tüm
## CombatTuning kayıtları bu sabit kimlik altında tutulur (bkz. player.gd'deki
## MAIN_WEAPON_TUNING_ID, aynı değer burada da sabit tutuluyor).
const MAIN_WEAPON_TUNING_ID := 0


func _ready() -> void:
	visible = false
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self) ## bkz. ui_sound.gd - tüm butonları ahşap stile çevirir
	rot_slider.value_changed.connect(_on_rot_changed)
	scale_slider.value_changed.connect(_on_scale_changed)
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_tuning"):
		if visible:
			_hide_panel()
		else:
			_show_panel()
		get_viewport().set_input_as_handled()


func _show_panel() -> void:
	var mw: Dictionary = Characters.MAIN_WEAPON
	title_label.text = "Ana Silah — Yakın Dövüş Efekti"

	var default_rot_deg: float = rad_to_deg(mw.get("slash_fx_rotation_offset", 0.0))
	var rot_deg: float = CombatTuning.get_value(MAIN_WEAPON_TUNING_ID, "rotation_offset_deg", default_rot_deg)
	var scl: float = CombatTuning.get_value(MAIN_WEAPON_TUNING_ID, "scale_mult", 1.0)

	rot_slider.set_value_no_signal(rot_deg)
	scale_slider.set_value_no_signal(scl)
	rot_value_label.text = "%.0f°" % rot_deg
	scale_value_label.text = "%.2fx" % scl
	saved_label.text = ""
	visible = true


func _hide_panel() -> void:
	visible = false


func _on_rot_changed(value: float) -> void:
	rot_value_label.text = "%.0f°" % value
	saved_label.text = ""
	_apply_live(value, scale_slider.value)


func _on_scale_changed(value: float) -> void:
	scale_value_label.text = "%.2fx" % value
	saved_label.text = ""
	_apply_live(rot_slider.value, value)


## Hiçbir karakterin ayrı bir "ana silahı" yok artık - bu panel bıçağı
## (owned_weapon_nodes içindeki "dagger" anahtarlı kopyayı, varsa) canlı
## ayarlıyor. Oakley/Matthew gibi bıçaksız başlayan karakterlerde bu bulunamaz,
## panel o an hiçbir şey yapmaz (zararsız).
func _apply_live(rot_deg: float, scl: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var w = null
	for candidate in player.owned_weapon_nodes:
		if is_instance_valid(candidate) and candidate.get_meta("shop_key", "") == "dagger":
			w = candidate
			break
	if not w:
		return
	w.melee_slash_fx_rotation_offset = deg_to_rad(rot_deg)
	w.melee_slash_fx_scale_mult = scl


func _on_save_pressed() -> void:
	CombatTuning.set_value(MAIN_WEAPON_TUNING_ID, "rotation_offset_deg", rot_slider.value)
	CombatTuning.set_value(MAIN_WEAPON_TUNING_ID, "scale_mult", scale_slider.value)
	CombatTuning.save_overrides()
	saved_label.text = "Kaydedildi."


func _on_reset_pressed() -> void:
	CombatTuning.clear_char(MAIN_WEAPON_TUNING_ID)
	_show_panel()
	_apply_live(rot_slider.value, scale_slider.value)
	saved_label.text = "Varsayılana döndürüldü."
