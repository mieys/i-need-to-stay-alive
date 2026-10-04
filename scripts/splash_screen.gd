extends Control

## Açılış logosu: oyun başladığında saydamdan görünür hale gelip (fade in),
## 3 saniye tam görünür kalıp, sonra tekrar saydamlaşarak (fade out) ana
## menüye geçer. Kullanıcı isteği - bkz. assets/ui/studio_logo.png.

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN_TIME := 0.8
const HOLD_TIME := 2.5
const FADE_OUT_TIME := 1.5
## EKSİK DOSYA UYARISI (kullanıcı bildirimi 2026-10-03: "insanlar oyunumu alıp açınca çok oyunculuya bastıklarında oyundan
## atıyor"): Windows'ta oyun = .exe + yanındaki .dll'ler (Epic Online Services + C++ yaratık sistemi; .exe'ye gömülemiyor).
## Sadece .exe gönderilince bu eklentiler yüklenmiyor - yaratıklar hareket etmiyor, çok oyunculu çöküyordu. Artık açılışta
## bakılır; eksikse çökmek yerine ne yapılacağını söyleyen bir ekran çıkar (ana menüye geçilmez).
## sınıf -> eksikse kopyalanması gereken dosyalar (Windows adları; Android'de APK içinde olmalılar).
const REQUIRED_NATIVE := {
	&"EnemyWorld": "libenemyworld.windows.template_release.x86_64.dll",
	&"EOSGMultiplayerPeer": "libeosg.windows.template_release.x86_64.dll, EOSSDK-Win64-Shipping.dll, xaudio2_9redist.dll",
}

@onready var logo: TextureRect = $CenterContainer/Logo
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var background: ColorRect = $Background


func _ready() -> void:
	if _show_missing_files_if_any():
		return
	# Arkaplan rengini logonun merkezine yakın bir arka plan rengiyle aynı yapıyoruz
	background.color = Color(0.0, 0.0, 0.0, 1.0)
	
	logo.modulate.a = 0.0
	audio.play() # Logo belirmeye başladığı anda ses çalsın
	
	var tween: Tween = create_tween()
	tween.tween_property(logo, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(logo, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_go_to_main_menu)


func _show_missing_files_if_any() -> bool:
	if not (OS.has_feature("windows") or OS.has_feature("android")):
		return false ## Web vb. platformlarda bu eklentiler zaten yok (bkz. CLAUDE.md §9)
	var android: bool = OS.has_feature("android")
	var missing: Array[String] = []
	for cls: StringName in REQUIRED_NATIVE:
		if not ClassDB.class_exists(cls):
			## Android'de dosyalar APK'nın içinde (kullanıcı kopyalamaz) - Windows dosya adı yerine bileşen adı yazılır.
			missing.append(str(cls) if android else str(REQUIRED_NATIVE[cls]))
	if missing.is_empty():
		return false
	background.color = Color(0.08, 0.05, 0.03, 1.0)
	logo.visible = false
	var label := Label.new()
	if android:
		label.text = "Oyunun bazı parçaları bu telefonda yüklenemedi!\n\nOyunu güncel APK ile kaldırıp yeniden yüklemeyi dene;\n" \
				+ "düzelmezse bu ekranın görüntüsünü geliştiriciye gönder.\n\nYüklenemeyenler:\n" + "\n".join(missing)
	else:
		label.text = "Oyun dosyaları eksik!\n\nOyunun .exe dosyasını tek başına değil, yanındaki .dll dosyalarıyla birlikte\n" \
				+ "(klasörün tamamını) kopyalaman ya da indirmen gerekiyor.\n\nEksik olanlar:\n" + "\n".join(missing)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 80)
	add_child(label)
	var quit_btn := Button.new()
	quit_btn.text = "Çıkış"
	quit_btn.add_theme_font_size_override("font_size", 32)
	quit_btn.custom_minimum_size = Vector2(260, 64)
	quit_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	quit_btn.position.y -= 120.0
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit_btn)
	push_error("Eksik yerel kütüphaneler: " + ", ".join(missing))
	return true


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
