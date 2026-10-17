extends Node

## Mana Kalkanı görseli "B - Mühür" (mana_shield_fx.gd, madde 148): darbe yönünde mühür (kuzey darbesi arka katmanda),
## kalkanı bitiren darbede her taraftan kırılma, artışta yer mührü + doldu taraması, azalmada (yetenek bedeli/kazma) ve
## Savaş kalkanında yenilenme görseli YOK, Kale mor / Enerji sarı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const FxScript: GDScript = preload("res://scripts/mana_shield_fx.gd")
const DT := 1.0 / 60.0

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	return player


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _step(fx: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		fx._process(DT)
		t += DT


func _shield(player: Node, hp: float, mx: float) -> void:
	player.item_shield_max = mx
	player.item_shield_hp = hp


func test_layers_and_palettes() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node_or_null("ManaShieldFx")
	var back: Node2D = p.get_node_or_null("ManaShieldBack")
	assert(fx != null and back != null, "oyuncuya mana kalkanı katmanları eklenmeli")
	assert(back.show_behind_parent, "arka katman karakterin ardında çizilir")
	assert(fx.get_index() > p.get_node("AnimatedSprite2D").get_index(), "ön katman karakter sprite'ından sonra")
	fx.set_shield_type("shield_kale")
	var kale: Color = fx._mat.get_shader_parameter("c2")
	assert(kale.is_equal_approx(FxScript.PALETTES["shield_kale"][2]))
	assert(kale.b > kale.g and kale.r > kale.g, "Kale mor olmalı")
	fx.set_shield_type("shield_enerji")
	var en: Color = fx._ground_mat.get_shader_parameter("c2")
	assert(en.r > en.b and en.g > en.b, "Enerji sarı olmalı")
	var kc: Color = ShieldEnchantDefs.TYPES["shield_kale"]["color"]
	var ec: Color = ShieldEnchantDefs.TYPES["shield_enerji"]["color"]
	assert(kc.b > kc.g and ec.r > ec.b and ec.g > ec.b, "kart renkleri de mor / sarı")
	fx.set_shield_type("")
	assert((fx._mat.get_shader_parameter("c2") as Color).is_equal_approx(FxScript.PALETTES["shield_standart"][2]), "bilinmeyen tür = Standart")
	_cleanup()


func test_hit_disc_side_and_back() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	var back: Node2D = p.get_node("ManaShieldBack")
	fx.hit(PI, false) ## soldan
	assert(fx.disc_count() == 1)
	var side: Sprite2D = fx._discs[0]["spr"]
	assert(side.get_parent() == fx, "yandan gelen darbenin mührü önde")
	assert(int(fx._discs[0]["row"]) == 0, "yan darbe = en dar oval")
	fx.hit(-PI / 2.0, false) ## kuzeyden
	var north: Sprite2D = fx._discs[1]["spr"]
	assert(north.get_parent() == back, "kuzeyden gelen darbenin mührü karakterin ardında")
	assert(int(fx._discs[1]["row"]) == FxScript.DISC_ROWS - 1, "kuzey darbesi = tam daire")
	assert(north.position.y < side.position.y, "kuzey mührü daha yukarıda")
	_step(fx, FxScript.DISC_LIFE + 0.05)
	assert(fx.disc_count() == 0, "mühürler söner")
	_cleanup()


func test_break_from_all_sides() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	fx.hit_only = false ## oyuncuda kapalı (madde 151); kırılma/yenilenme görseli hâlâ kodda, burada doğrudan sınanır
	fx.hit(0.4, false)
	fx.hit(0.0, true)
	assert(fx.disc_count() == 0, "kırılma darbe mühürlerini kaldırır")
	assert(fx._break_back.visible and fx._break_front.visible, "kırılma: ön + arka katman birlikte")
	_step(fx, FxScript.BREAK_DURATION * 0.5)
	assert(fx._break_front.frame > 0, "kırılma ilerler")
	var before: Vector2 = fx._break_front.global_position
	p.global_position += Vector2(40.0, 0.0) ## oyuncu yürüdü
	_step(fx, DT)
	assert(fx._break_front.global_position.distance_to(before) < 0.5, "parçalar dünyada sabit, oyuncuyla kaymaz")
	_step(fx, FxScript.BREAK_DURATION)
	assert(not fx.is_anything_visible(), "kırılma bitince oyuncunun üstünde hiçbir şey kalmaz")
	var debris: Node2D = get_tree().current_scene.get_node_or_null("ManaShieldDebris")
	assert(debris != null, "kırıklar yere düşer (dünyada ayrı düğüm)")
	_spawned.append(debris)
	assert(debris.global_position.distance_to(p.global_position) > 10.0, "kırıklar kırıldığı yerde kalır")
	_cleanup()


func test_regen_progress_then_full() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	fx.hit_only = false ## oyuncuda kapalı (madde 151); kırılma/yenilenme görseli hâlâ kodda, burada doğrudan sınanır
	fx.set_shield_type("shield_standart")
	_shield(p, 0.0, 150.0)
	_step(fx, 0.05)
	assert(not fx.is_anything_visible(), "boş + bekleme: görsel yok")
	_shield(p, 10.0, 150.0) ## ilk tik
	_step(fx, 0.5)
	assert(fx.is_regen_shown() and fx._ground.visible, "artış yer mührünü açar")
	var prog: float = fx._ground_mat.get_shader_parameter("progress")
	assert(absf(prog - 10.0 / 150.0) < 0.01, "dolan kısım = kalkan / azami (%f)" % prog)
	_step(fx, FxScript.REGEN_HOLD + 0.3)
	assert(not fx._ground.visible, "tik gelmeyince yer mührü söner")
	_shield(p, 140.0, 150.0)
	_step(fx, 0.05)
	assert(fx.is_regen_shown())
	_shield(p, 150.0, 150.0) ## doldu
	_step(fx, 0.05)
	assert(fx._rise_front.visible and fx._rise_back.visible, "doldu: ayaktan başa tarama")
	assert(not fx.is_regen_shown())
	_step(fx, FxScript.RISE_DURATION + 0.1)
	assert(not fx.is_anything_visible(), "doldu animasyonu biter, kalkan dolu = görünmez")
	_cleanup()


func test_no_visual_on_spend_max_change_or_savas() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	fx.hit_only = false ## oyuncuda kapalı (madde 151); kırılma/yenilenme görseli hâlâ kodda, burada doğrudan sınanır
	_shield(p, 150.0, 150.0)
	_step(fx, 0.05)
	_shield(p, 110.0, 150.0) ## yetenek bedeli / kazma vuruşu: azalma
	_step(fx, 0.3)
	assert(not fx.is_anything_visible(), "azalma görsel üretmez (çatlak yok)")
	_shield(p, 250.0, 250.0) ## kart/eşya azami kalkanı büyüttü
	_step(fx, 0.05)
	assert(not fx.is_anything_visible(), "azami değişince artış yenilenme sayılmaz")
	fx.set_shield_type("shield_savas")
	_shield(p, 100.0, 250.0)
	_step(fx, 0.05)
	_shield(p, 104.0, 250.0)
	_step(fx, 0.05)
	assert(not fx.is_regen_shown(), "Savaş kalkanı yenilenmede yer mührü göstermez")
	fx.hit(PI, false)
	assert(fx.disc_count() == 1, "Savaş kalkanı darbede mühür gösterir")
	_cleanup()


func test_suppressed_hides_and_ignores() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	fx.hit_only = false ## oyuncuda kapalı (madde 151); kırılma/yenilenme görseli hâlâ kodda, burada doğrudan sınanır
	_shield(p, 20.0, 150.0)
	_step(fx, 0.05)
	_shield(p, 30.0, 150.0)
	_step(fx, 0.05)
	fx.hit(PI, false)
	assert(fx.is_anything_visible())
	fx.suppress()
	assert(not fx.is_anything_visible(), "ölü/düşmüş: anında gizlenir")
	fx.hit(0.0, true)
	assert(not fx.is_anything_visible(), "gizliyken darbe görsel üretmez")
	_cleanup()


func test_take_damage_uses_mana_seal_not_old_crack() -> void:
	var p: Node = _make_player()
	var fx: Node2D = p.get_node("ManaShieldFx")
	assert(fx.hit_only, "oyuncuda sadece darbe mührü açık (madde 151: gerisi eski kalkan)")
	_shield(p, 150.0, 150.0)
	p.shield_protection = 0.65
	p._last_damage_taken_at_msec = -100000
	p.take_damage(40.0, null)
	assert(p.item_shield_hp < 150.0, "kalkan hasarın bir kısmını soğurdu")
	assert(fx.disc_count() == 1, "darbe mührü doğdu")
	for c: Node in p.get_children():
		assert(c.get_script() != load("res://scripts/fx_shield_hit.gd"), "eski çatlak efekti artık doğmamalı")
	assert(p._damage_flash_timer <= 0.0, "eski baloncuk hasar flaşı da yok")
	_shield(p, 5.0, 150.0)
	p._last_damage_taken_at_msec = -100000
	p.take_damage(40.0, null)
	assert(p.item_shield_hp <= 0.0)
	assert(not fx._break_front.visible, "hit_only: kırılma görseli oynamaz (eski baloncuğun kırılması gösterilir)")
	assert(fx.disc_count() == 1, "kalkanı bitiren darbe mühür bırakmaz (sadece önceki darbenin mührü kalır)")
	## Yenilenme (artış) görseli de kapalı: eski baloncuk yenilenmeyi gösterir.
	_shield(p, 0.0, 150.0)
	_step(fx, 0.05)
	_shield(p, 30.0, 150.0)
	_step(fx, 0.2)
	assert(not fx.is_regen_shown(), "hit_only: yenilenme yer mührü yok")
	_cleanup()
