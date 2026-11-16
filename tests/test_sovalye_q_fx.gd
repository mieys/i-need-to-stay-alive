extends Node

## Madde 740: Şovalye Q efekti "A Kalkan Darbesi" (fx_sovalye_taunt.tscn). Temel Q ve Meydan Okuma AYNI sahne; süre = Q'nun
## gerçek süresi (props "duration", Uzun Nöbet dahil), Meydan Okuma'da (props "taunt") kırmızı katman. Klip yapısı gen_sovalye_q_fx.py ile aynı.

const Scene := preload("res://scenes/fx_sovalye_taunt.tscn")


func _spawn(props: Dictionary) -> Node2D:
	var host := Node2D.new()
	add_child(host)
	var fx: Node2D = Scene.instantiate()
	for k in props:
		fx.set(k, props[k])
	host.add_child(fx)
	return fx


func test_clip_sheets_match_generator() -> void:
	var fx := _spawn({})
	var pairs: Array = [[fx.CastBack, fx.CastFront, false], [fx.LoopBack, fx.LoopFront, true]]
	for p: Array in pairs:
		var b: SpriteFrames = p[0]
		var f: SpriteFrames = p[1]
		assert(b.get_frame_count(&"play") == 20 and f.get_frame_count(&"play") == 20, "açılış/döngü 20 kare")
		assert(is_equal_approx(b.get_animation_speed(&"play"), 20.0), "20 fps (döngü = 1 sn = kalkan yenileme tiki)")
		assert(b.get_animation_loop(&"play") == bool(p[2]) and f.get_animation_loop(&"play") == bool(p[2]), "döngü bayrağı")
	assert(fx.TauntBack.get_frame_count(&"play") == 24 and not fx.TauntBack.get_animation_loop(&"play"), "kırmızı katman 1,2 sn tek sefer")
	fx.get_parent().free()


func test_base_q_layers_and_loop_switch() -> void:
	var fx := _spawn({"duration": 6.0, "taunt": false})
	assert(fx.show_behind_parent, "arka katman karakterin arkasında")
	assert(fx._back.sprite_frames == fx.CastBack and fx._back.is_playing(), "açılış klibi oynuyor")
	assert(fx._taunt == null, "temel Q'da kırmızı katman yok")
	fx._on_cast_finished()
	assert(fx._back.sprite_frames == fx.LoopBack and fx._back.is_playing(), "açılıştan sonra 1 sn'lik döngü")
	assert(is_equal_approx(fx._back.offset.y, -fx.LOOP_ORIGIN.y), "döngü klibi kendi kökenine oturur")
	fx.get_parent().free()


func test_taunt_layer_duration_and_fade() -> void:
	var fx := _spawn({"duration": 8.0, "taunt": true})
	assert(fx._taunt != null and fx._taunt.sprite_frames == fx.TauntBack, "Meydan Okuma: kırmızı katman")
	fx._process(7.0)
	assert(is_equal_approx(fx.modulate.a, 1.0), "Uzun Nöbet (8 sn): 7. saniyede hâlâ tam görünür")
	fx._process(0.75)
	var a: float = fx.modulate.a
	assert(is_equal_approx(a, 0.55) or is_equal_approx(a, 0.3) or is_equal_approx(a, 0.8), "sonda düz alfa basamağı: %f" % a)
	fx._process(0.3)
	assert(fx.is_queued_for_deletion(), "süre bitince silinir")
	fx.get_parent().free()
