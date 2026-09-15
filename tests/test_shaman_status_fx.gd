extends Node

## Shaman yetenek efektleri - AŞAMA 1 doğrulaması: DURUM EFEKTLERİ
## (yakma = Totem Auraları pasifi, yavaşlatma = Alan Totemi).
##
## Kullanıcı istekleri:
##   "Shaman adlı karakterin skill efektlerini skil uygun şekilde tasarla"
##   "pixel sanatında yapıyorsun dimi efektleri, oyunum pixel çünkü?"
##
## Bu testler iki şeyi garanti eder:
##   1) Efektler GERÇEKTEN pixel-art (texture_filter = NEAREST) ve durum
##      efektleri oldukları için DÖNGÜLÜ animasyon kullanıyor.
##   2) Bu görsel eklemeler oyun mantığına DOKUNMUYOR - hasar/yavaşlatma
##      değerleri birebir aynı kalıyor (kozmetik katman ayrımı).

const BURN_SCENE := "res://scenes/fx_burn_status.tscn"
const SLOW_SCENE := "res://scenes/fx_void_slow_status.tscn"
const SLOW_ANIM := "swirling_rotating_vortex_with_motes_orbiting_around_it"
const ENEMY_PATH := "res://scripts/enemy.gd"
const NET_PATH := "res://scripts/network_manager.gd"


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Pixel-art kuralı: NEAREST filtre + döngülü animasyon + beklenen kare sayısı.
func _assert_pixel_art_status_scene(path: String, anim_name: String) -> void:
	var packed: PackedScene = load(path)
	assert(packed != null, "%s yüklenebilmeli" % path)
	var inst: Node = packed.instantiate()
	assert(inst is AnimatedSprite2D, "%s kökü AnimatedSprite2D olmalı" % path)
	var spr: AnimatedSprite2D = inst
	assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"%s pixel-art olmalı (texture_filter NEAREST), bulunan: %s" % [path, spr.texture_filter])
	assert(spr.sprite_frames != null, "%s SpriteFrames taşımalı" % path)
	assert(spr.sprite_frames.has_animation(anim_name),
		"%s '%s' animasyonunu taşımalı" % [path, anim_name])
	assert(spr.sprite_frames.get_frame_count(anim_name) == 6,
		"%s 6 kare olmalı, bulunan: %s" % [path, spr.sprite_frames.get_frame_count(anim_name)])
	assert(spr.sprite_frames.get_animation_loop(anim_name),
		"%s DÖNGÜLÜ olmalı (durum efekti sürekli oynar)" % path)
	inst.free()


## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Ateş özel klasörü, kan.png
## v.b. paketiyle birlikte gelen 4 ateş + 3 duman sprite sheeti): yakma
## efekti artık TEK bir AnimatedSprite2D (BURN_ANIM) değil, İKİ KATMANLI
## (bkz. fx_burn_status.gd) bir Node2D kökü - "Smoke" (arkada) + "Fire"
## (önde) çocukları, her biri kendi rastgele seçilen varyantını 14 karelik
## döngüde oynatıyor. Kök tipi/kare sayısı buna göre güncellendi, ama
## pixel-art (NEAREST) + döngü + doğru layer sıralaması ilkeleri AYNI
## şekilde doğrulanıyor.
func test_burn_status_fx_is_pixel_art_loop() -> void:
	var packed: PackedScene = load(BURN_SCENE)
	assert(packed != null, "%s yüklenebilmeli" % BURN_SCENE)
	var inst: Node = packed.instantiate()
	assert(inst is Node2D, "%s kökü Node2D olmalı" % BURN_SCENE)
	## fx_burn_status.gd, Smoke/Fire varyantlarını (rastgele) ve hizalamayı
	## _ready()'de kuruyor - _ready()'nin çalışması için node GERÇEKTEN
	## sahne ağacına girmiş olmalı. add_child() SceneTree'ye YENİ eklenen bir
	## dalda bunu senkron yapmayabilir (headless test bağlamında bir kare
	## gecikebilir) - bu yüzden bir process_frame bekleniyor.
	add_child(inst)
	await get_tree().process_frame
	var smoke: AnimatedSprite2D = inst.get_node_or_null("Smoke")
	var fire: AnimatedSprite2D = inst.get_node_or_null("Fire")
	assert(smoke != null, "%s bir 'Smoke' AnimatedSprite2D çocuğu taşımalı" % BURN_SCENE)
	assert(fire != null, "%s bir 'Fire' AnimatedSprite2D çocuğu taşımalı" % BURN_SCENE)
	for spr: AnimatedSprite2D in [smoke, fire]:
		assert(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"%s pixel-art olmalı (texture_filter NEAREST), bulunan: %s" % [spr.name, spr.texture_filter])
		assert(spr.sprite_frames != null, "%s SpriteFrames taşımalı" % spr.name)
		assert(spr.sprite_frames.has_animation("burn"), "%s 'burn' animasyonunu taşımalı" % spr.name)
		assert(spr.sprite_frames.get_frame_count("burn") == 14,
			"%s 14 kare olmalı, bulunan: %s" % [spr.name, spr.sprite_frames.get_frame_count("burn")])
		assert(spr.sprite_frames.get_animation_loop("burn"), "%s DÖNGÜLÜ olmalı" % spr.name)
	## Kullanıcı isteği: "layer sıralamaları düşman bedeni-duman-ateş olacak" -
	## duman arkada, ateş önde.
	assert(fire.z_index > smoke.z_index,
		"Ateş dumanın ÖNÜNDE olmalı (z_index), bulunan fire=%s smoke=%s" % [fire.z_index, smoke.z_index])
	inst.queue_free()
	inst.free()


func test_slow_status_fx_is_pixel_art_loop() -> void:
	_assert_pixel_art_status_scene(SLOW_SCENE, SLOW_ANIM)


## enemy.gd görsel sahneleri + sarmalayıcı API'yi taşımalı.
func test_enemy_wires_burn_and_slow_visuals() -> void:
	var src: String = _read(ENEMY_PATH)
	assert(not src.is_empty(), "enemy.gd okunabilmeli")
	assert(src.contains('preload("res://scenes/fx_burn_status.tscn")'),
		"yakma görsel sahnesi enemy.gd'ye bağlı olmalı")
	assert(src.contains('preload("res://scenes/fx_void_slow_status.tscn")'),
		"yavaşlatma görsel sahnesi enemy.gd'ye bağlı olmalı")
	assert(src.contains("func _spawn_burn_status_fx()"), "_spawn_burn_status_fx bulunmalı")
	assert(src.contains("func _remove_burn_status_fx()"), "_remove_burn_status_fx bulunmalı")
	assert(src.contains("func _spawn_slow_status_fx("), "_spawn_slow_status_fx bulunmalı")
	assert(src.contains("func _remove_slow_status_fx()"), "_remove_slow_status_fx bulunmalı")


## Çok oyunculu: görselin HER client'ta görünmesi için ağ dalları olmalı
## (projenin bilinen hata sınıfı: "kastın ekranında var, diğerinde yok").
func test_network_routes_burn_and_slow_vfx() -> void:
	var src: String = _read(NET_PATH)
	assert(not src.is_empty(), "network_manager.gd okunabilmeli")
	for vfx: String in ['"burn_start"', '"burn_stop"', '"slow_start"', '"slow_stop"']:
		assert(src.contains(vfx), "broadcast_enemy_vfx '%s' dalını içermeli" % vfx)
	assert(src.contains("_spawn_burn_status_fx"), "burn görseli enemy API'sine yönlenmeli")
	assert(src.contains("_spawn_slow_status_fx"), "slow görseli enemy API'sine yönlenmeli")


## GÖRSEL eklemeler oyun mantığını DEĞİŞTİRMEMELİ - sayılar birebir aynı.
func test_status_gameplay_numbers_unchanged() -> void:
	var src: String = _read(ENEMY_PATH)
	assert(src.contains("const BURN_TICK_INTERVAL := 1.0"), "yakma tik aralığı (1sn) değişmemeli")
	assert(src.contains("burn_tick_damage = max(burn_tick_damage, tick_damage)"),
		"yakma 'en güçlüsü kalır' kuralı korunmalı")
	assert(src.contains("burn_time_left = max(burn_time_left, duration)"),
		"yakma süre tazeleme davranışı korunmalı")
	assert(src.contains("_slow_percent = max(_slow_percent, min(percent, 0.75))"),
		"yavaşlatma tavanı (%75) korunmalı")
	assert(src.contains("_slow_timer = duration"),
		"yavaşlatma süre tazeleme davranışı korunmalı")
	## Görsel ömür ayrı bir değişkende tutulmalı - yavaşlatma simülasyonuna
	## karışmamalı (istemcide _slow_timer hiç dolmaz, gösterge yine de yaşar).
	assert(src.contains("var _slow_fx_time_left: float = 0.0"),
		"görsel ömür ayrı değişkende olmalı")
