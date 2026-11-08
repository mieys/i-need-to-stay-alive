extends Node

## Madde 406 (cila: ekrandaki yazı kalabalığı): Ayarlar > Hasar Sayıları = Hepsi / Yalnız Kritik / Kapalı (UISound.damage_numbers_mode).
## Ayar dosyasına YAZMAMAK için değer doğrudan atanır (set_damage_numbers_mode kaydeder).


func test_modes_gate_numbers() -> void:
	var keep: int = UISound.damage_numbers_mode
	UISound.damage_numbers_mode = 0
	assert(UISound.damage_number_allowed(false) and UISound.damage_number_allowed(true), "Hepsi: normal + kritik")
	UISound.damage_numbers_mode = 1
	assert(not UISound.damage_number_allowed(false) and UISound.damage_number_allowed(true), "Yalnız Kritik")
	UISound.damage_numbers_mode = 2
	assert(not UISound.damage_number_allowed(false) and not UISound.damage_number_allowed(true), "Kapalı")
	UISound.damage_numbers_mode = keep


func test_mode_names_match_settings_row() -> void:
	assert(UISound.DAMAGE_NUMBER_MODES.size() == 3 and str(UISound.DAMAGE_NUMBER_MODES[1]) == "Yalnız Kritik", "üç seçenek")
	var src: String = FileAccess.get_file_as_string("res://scripts/settings_screen.gd")
	assert(src.count("\"dmg_numbers\"") == 2, "Ayarlar'da masaüstü + telefon satırı")
