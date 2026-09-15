extends AnimatedSprite2D

## Shaman totem efektleri için TEK SEFERLİK piksel-art patlama: dikilme tozu,
## sönme tozu ve cast parlaması - üçü de aynı "bir kez oynat, sonra kendini
## serbest bırak" davranışını paylaşır.
##
## neden fx_animation.gd kullanılmadı: o script "play" adlı bir animasyon
## bekliyor, burada animasyon adları üretilen atlasın meta verisinden geliyor
## (ör. "dirt_clumps_and_roots_bursting_upward_then_falling_back_down").
## Bu yüzden ilk animasyon adı ne olursa olsun o oynatılır.
##
## Döngü KAPATILIR: bunlar tek seferlik patlamalar (durum efekti değiller) -
## kapanmazsa animation_finished hiç gelmez ve efekt sonsuza kadar kalırdı
## (bkz. fx_animation.gd üstündeki AYNI "kaçak VFX" notu).


func _ready() -> void:
	if sprite_frames == null or sprite_frames.get_animation_names().is_empty():
		queue_free()
		return
	var anim: StringName = sprite_frames.get_animation_names()[0]
	sprite_frames.set_animation_loop(anim, false)
	animation_finished.connect(queue_free)
	play(anim)
	## Güvenlik zamanlayıcısı - herhangi bir aksilikte efekt sahnede asılı
	## kalmasın (fx_animation.gd/fx_shield_hit.gd'deki AYNI desen).
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


## Totem rengiyle (yetenek başına) renklendirme - cast parlaması beyaz
## üretildiği için tint ile her totem kendi rengini alır.
func setup_tint(tint: Color) -> void:
	modulate = tint
