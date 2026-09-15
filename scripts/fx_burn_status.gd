extends Node2D

## Yaratıklar yanarken (Shaman pasifi/Totem Auraları, ateşli silahlar v.s -
## bkz. enemy.gd apply_burn/_spawn_burn_status_fx) gövdelerinde beliren efekt.
##
## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Ateş özel klasörü): eskiden
## TEK bir sabit alev animasyonu vardı (fx_burn_flames.png, 6 kare, tek
## katman). Artık 4 ateş + 3 duman varyantından rastgele biri seçilip İKİ
## KATMAN olarak gösteriliyor. Kullanıcı isteği: "layer sıralamaları düşman
## bedeni-duman-ateş olacak" - duman ARKADA (düşük z_index), ateş ÖNDE
## (yüksek z_index); "duman efekti yukarıya doğru gidecek uzunluğu fazla
## olduğu için" - duman kendi kare boyu (96-128px) ateşinkinden (48px) fazla
## olduğu için alt kenarları hizalanınca doğal olarak ateşin üstüne taşıyor.

const FIRE_VARIANTS := [
	preload("res://assets/generated/fx_burn_fire_a_frames.tres"),
	preload("res://assets/generated/fx_burn_fire_b_frames.tres"),
	preload("res://assets/generated/fx_burn_fire_c_frames.tres"),
	preload("res://assets/generated/fx_burn_fire_d_frames.tres"),
]
const SMOKE_VARIANTS := [
	preload("res://assets/generated/fx_burn_smoke_a_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_b_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_c_frames.tres"),
]

## DÜZELTME (kullanıcı isteği: "yangının opaklığı %100 de kalsın duman
## aynı kalsın ama opaklık olarak") - ateş tekrar tam opak, duman %30'da
## kalıyor (önceki "ikisi de indir" isteğinin ateş kısmı geri alındı).
const FIRE_OPACITY := 1.0
const SMOKE_OPACITY := 0.3

## DÜZELTME (kullanıcı isteği: "yanma efektini dumanla beraber %10 küçült",
## sonra "yangını efekti %10 daha küçült dumanı da") - ateş VE duman
## birlikte, aynı oranda küçülsün diye kök Node2D'ye uygulanıyor (alt kenar
## hizalaması _ready() sonunda doku piksel boyutlarından hesaplandığı için
## bu ölçeklemeden etkilenmiyor, orantı korunuyor). İki ardışık %10 küçültme
## kümülatif: 0.9 * 0.9 = 0.81.
const EFFECT_SCALE := 0.81

## DÜZELTME (kullanıcı isteği: "yangın ve dumanı biraz yukarı taşı") - kök
## Node2D'nin Y konumu (enemy.gd tarafında hep Vector2.ZERO'ya sabitlenen
## position'ın ÜZERİNE, kendi negatif Y'siyle) - ikisini BİRLİKTE (aralarındaki
## alt-kenar hizalamasını bozmadan) yukarı kaydırır.
const VERTICAL_OFFSET := -12.0

@onready var _smoke: AnimatedSprite2D = $Smoke
@onready var _fire: AnimatedSprite2D = $Fire


func _ready() -> void:
	position = Vector2(0.0, VERTICAL_OFFSET)
	scale = Vector2(EFFECT_SCALE, EFFECT_SCALE)

	_smoke.sprite_frames = SMOKE_VARIANTS[randi() % SMOKE_VARIANTS.size()]
	_smoke.modulate.a = SMOKE_OPACITY
	_smoke.play("burn")
	_fire.sprite_frames = FIRE_VARIANTS[randi() % FIRE_VARIANTS.size()]
	_fire.modulate.a = FIRE_OPACITY
	_fire.play("burn")

	## Alt kenarları hizala (ikisi de centered=true varsayılanıyla merkezden
	## çizilir) - duman böylece ateşin TABANINDAN yükselip onu geride/üstte
	## kalacak şekilde sarar, konumu yanlışsa yaratığın dışında/içinde kalırdı.
	var smoke_tex: Texture2D = _smoke.sprite_frames.get_frame_texture("burn", 0)
	var fire_tex: Texture2D = _fire.sprite_frames.get_frame_texture("burn", 0)
	if smoke_tex and fire_tex:
		var smoke_h: float = smoke_tex.get_size().y
		var fire_h: float = fire_tex.get_size().y
		_smoke.position.y = (fire_h - smoke_h) * 0.5
