extends AnimatedSprite2D

## Pençe (claw) savuruş efekti - kullanıcı isteği (2026-09-24): "pençenin saldırı efektini saldırı animasyonuyla uyumlu
## olacak şekilde yeniden tasarlayıp sıfırdan daha iyi bir pençe efekti tasarla pixel tarzda ... spritesheete dönüştür
## ... (2-3 varyasonu daha olsun spam gibi olmaması için)". Görseller tools/gen_claw_slash_fx.py (3 varyant x 12 kare).
##
## Varyant: her vuruşta rastgele, ama AYNI varyant art arda iki kez gelmez (hızlı saldırıda tekrar eden damga hissi
## olmasın). Hizalama: weapon.gd _spawn_slash_fx efekti savuruşun SON noktasına koyar; bu script align_to_swing ile
## sprite'ı savuruşun MERKEZİNE kaydırır - izler pençe ikonunun süpürdüğü yol boyunca, aynı yönde yırtılır.
## weapon.gd _fx_playback_duration o an oynayan animasyonun süresini okur (ikon efekt bitene kadar bekler).

const VARIANT_COUNT := 3
static var _last_variant: int = -1


func _ready() -> void:
	var v: int = randi() % VARIANT_COUNT
	if v == _last_variant:
		v = (v + 1 + randi() % (VARIANT_COUNT - 1)) % VARIANT_COUNT
	_last_variant = v
	animation_finished.connect(queue_free)
	play(StringName("v%d" % v))
	## Güvenlik: animasyon bir sebeple bitmezse asılı kalmasın (bkz. fx_animation.gd aynı not).
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


## to_center_world: efektin düğüm konumundan savuruş merkezine dünya vektörü (bkz. weapon.gd _spawn_slash_fx).
func align_to_swing(to_center_world: Vector2) -> void:
	var s: float = maxf(absf(global_scale.x), 0.0001)
	offset = to_center_world.rotated(-global_rotation) / s
