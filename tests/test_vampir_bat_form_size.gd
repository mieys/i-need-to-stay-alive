extends Node

## Kullanıcı isteği: "vampir çocuğun E yeteneğindeki yarasa formunun boyutunu %30 küçült".
##
## Yarasa Formu kareleri (96x112) insan karelerinden (48x48) büyük olduğu için tam karakter
## ölçeğinde devasa görünüyordu. Doğrulananlar:
##  1) paylaşılan çarpan tam %30 küçültme (0.7),
##  2) yerel oyuncuda form boyunca sprite küçülüyor, form bitince TAM ölçeğe dönüyor,
##  3) form sürerken başka bir ölçek sıfırlaması olsa bile bir sonraki _update_animation
##     yarasayı yine küçük ölçekte tutuyor (idempotent),
##  4) uzak oyuncu kuklası AYNI çarpanı kullanıyor (çok oyunculuda sapma yok),
##  5) başka karakterlerin kuklası bu koddan etkilenmiyor (Talon'un Ayna Formu ölçeğini ezmiyor).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
## player.gd/remote_player.gd ile aynı desen: vampir_math.gd global bir class_name DEĞİL, preload edilir.
const VampirMath := preload("res://scripts/vampir_math.gd")


func _make_vampir_player() -> Node:
	GameManager.selected_char_id = VampirMath.CHAR_ID
	GameManager.selected_character = int(Characters.get_def(VampirMath.CHAR_ID).get("skill", 1))
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


func test_shared_multiplier_is_thirty_percent_smaller() -> void:
	assert(is_equal_approx(VampirMath.BAT_FORM_SCALE_MULT, 0.7),
		"ortak çarpan %%30 küçültme (0.7) olmalı, bulunan: %s" % VampirMath.BAT_FORM_SCALE_MULT)


func test_local_bat_form_shrinks_and_returns_to_full_size() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Node = _make_vampir_player()
	var human_scale: Vector2 = player.char_base_anim_scale

	player._skill_vampir_bat_form()
	player._update_animation(false) ## yarasa dalı ölçeği burada kuruyor
	assert(player.anim.scale.is_equal_approx(human_scale * VampirMath.BAT_FORM_SCALE_MULT),
		"yarasa formu %%30 küçülmemiş: %s (beklenen %s)"
			% [player.anim.scale, human_scale * VampirMath.BAT_FORM_SCALE_MULT])

	## Form sürerken ölçek dışarıdan sıfırlansa bile (ör. _end_skill_effects'teki
	## "anim.scale = char_base_anim_scale") yarasa bir sonraki karede yine küçük kalmalı.
	player.anim.scale = human_scale
	player._update_animation(false)
	assert(player.anim.scale.is_equal_approx(human_scale * VampirMath.BAT_FORM_SCALE_MULT),
		"form sürerken ölçek sıfırlaması yarasayı eski boyutuna döndürdü: %s" % player.anim.scale)

	player._end_vampir_bat_form()
	assert(player.anim.scale.is_equal_approx(human_scale),
		"form bitince insan formu tam ölçeğe dönmeli: %s (beklenen %s)" % [player.anim.scale, human_scale])

	player.queue_free()
	get_tree().current_scene = previous_scene


func test_remote_puppet_uses_the_same_multiplier() -> void:
	var puppet: Node = RemotePlayerScene.instantiate()
	puppet.char_id = VampirMath.CHAR_ID
	add_child(puppet)
	var base: Vector2 = puppet._base_anim_scale

	puppet._vampir_bat_form = false
	puppet._apply_vampir_bat_scale()
	assert(puppet.anim.scale.is_equal_approx(base),
		"insan formundaki uzak Vampir tam ölçekte olmalı: %s" % puppet.anim.scale)

	puppet._vampir_bat_form = true
	puppet._apply_vampir_bat_scale()
	assert(puppet.anim.scale.is_equal_approx(base * VampirMath.BAT_FORM_SCALE_MULT),
		"uzak Vampir'in yarasa formu %%30 küçülmemiş: %s" % puppet.anim.scale)

	puppet.queue_free()


## Talon'un kuklası bu koddan etkilenmemeli: _apply_vampir_bat_scale SADECE Vampir'de anim.scale'e yazar
## (Talon'un Ayna Formu ölçeklemesi - _apply_talon_form_scale - ezilmemeli).
func test_other_characters_puppet_is_untouched() -> void:
	var puppet: Node = RemotePlayerScene.instantiate()
	puppet.char_id = 1 ## Talon
	add_child(puppet)
	var base: Vector2 = puppet._base_anim_scale
	var talon_form_scale: Vector2 = base * 1.15 ## Ayna Formu simülasyonu
	puppet.anim.scale = talon_form_scale
	puppet._apply_vampir_bat_scale()
	assert(puppet.anim.scale.is_equal_approx(talon_form_scale),
		"Vampir'e özel ölçek kodu başka karakterin kuklasına dokundu: %s" % puppet.anim.scale)
	puppet.queue_free()
