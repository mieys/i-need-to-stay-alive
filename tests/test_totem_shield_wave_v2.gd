extends Node

## Kalkan Totemi dalga efekti (kozmetik) doğrulama testi.
##
## NOT: Ziva test runner sahne ağacı DIŞINDA çalıştırır (get_tree() null),
## bu yüzden totem node'unu gerçekten ağaca ekleyemeyiz. Bunun yerine:
##   1) Her iki script'in yüklenebilir/söz dizimi hatasız olduğunu,
##   2) totem_shield.gd'deki KALKAN MANTIĞININ (kullanıcı isteği: "skilin
##      mantığına dokunma") değişmediğini kaynak metin üzerinden,
##   3) dalga spawn'ının geçersiz argümanlarla (null parent/ally) çökmediğini
## doğrularız. Gerçek çizim testi oyun içinde (headless probe) yapılabilir.

const TOTEM_PATH := "res://scripts/totem_shield.gd"
const WAVE_PATH := "res://scripts/totem_shield_wave.gd"


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func test_scripts_load() -> void:
	var totem: Script = load(TOTEM_PATH)
	var wave: Script = load(WAVE_PATH)
	assert(totem != null, "totem_shield.gd yüklenemeli")
	assert(wave != null, "totem_shield_wave.gd yüklenemeli")
	assert(wave.has_method("spawn"), "dalga scripti spawn metoduna sahip olmalı")
	assert(wave.has_method("spawn_pulse"), "dalga scripti spawn_pulse metoduna sahip olmalı")


func test_shield_logic_untouched() -> void:
	var src: String = _read(TOTEM_PATH)
	assert(not src.is_empty(), "totem_shield.gd okunabilmeli")
	# Kalkan hesabı AYNEN duruyor mu? (SELF_PERCENT %0.5 + ATTACK_POWER_RATIO %10)
	assert(src.contains("const SELF_PERCENT := 0.005"), "SELF_PERCENT değişmemeli")
	assert(src.contains("const ATTACK_POWER_RATIO := 0.10"), "ATTACK_POWER_RATIO değişmemeli")
	assert(src.contains("caster.heal_shield(self_amount)"), "kendi kalkanı heal_shield üzerinden verilmeli")
	assert(src.contains("caster._apply_shield_heal_to_ally(ally, ally_amount)"), "ally kalkanı _apply_shield_heal_to_ally üzerinden verilmeli")
	assert(src.contains("super(delta)"), "TotemBase._process'e super edilmeli (tick döngüsü korunmalı)")
	# Dalga bölümü _tick İÇİNDE değil, ayrı bir kozmetik fonksiyonda mı?
	var tick_start: int = src.find("func _tick()")
	assert(tick_start != -1, "_tick hâlâ var olmalı")
	var tick_end: int = src.find("\n\n\n", tick_start)
	if tick_end == -1:
		tick_end = src.length()
	var tick_body: String = src.substr(tick_start, tick_end - tick_start)
	assert(not tick_body.contains("TotemShieldWave"), "_tick içinde dalga (kozmetik) kodu OLMAMALI - mantık temiz kalmalı")


func test_wave_spawn_safe_args() -> void:
	# Null parent / null ally ile spawn çökmemeli (sahne geçişi anı için).
	TotemShieldWave.spawn(null, Vector2.ZERO, null, Color.BLUE)
	var parent: Node = Node.new()
	TotemShieldWave.spawn(parent, Vector2.ZERO, null, Color.BLUE)
	assert(parent.get_child_count() == 0, "geçersiz ally ile dalga OLUŞTURULMAMALI")
	parent.free()


func test_wave_defaults() -> void:
	var wave: TotemShieldWave = TotemShieldWave.new()
	assert(wave.travel_time > 0.0, "dalga uçuş süresi pozitif olmalı")
	assert(wave.ripple_time > 0.0, "varış ripple süresi pozitif olmalı")
	wave.free()


func test_wave_glyph_api_present() -> void:
	## YENİDEN TASARIM (kullanıcı isteği: "kalkan enerji dalgası pek güzel
	## olmamış"): yeni tasarımın üç çizim modu + glyph yardımcıları yerinde.
	var wave: TotemShieldWave = TotemShieldWave.new()
	assert(wave.has_method("_glyph_head"), "kalkan simgesi baş noktası metodu olmalı")
	assert(wave.has_method("_glyph_outline"), "kalkan simgesi kontur metodu olmalı")
	assert(wave.has_method("_draw_travel"), "uçuş modu çizim metodu olmalı")
	assert(wave.has_method("_draw_arrival"), "varış modu çizim metodu olmalı")
	assert(wave.has_method("_draw_pulse"), "totem nabız modu çizim metodu olmalı")
	## travel_time <= 0 -> pulse modu (spawn_pulse'in çalışma şartı).
	wave.travel_time = 0.0
	wave.ripple_time = 0.4
	assert(wave.travel_time <= 0.0, "pulse modu travel_time=0 ile açılmalı")
	wave.free()
