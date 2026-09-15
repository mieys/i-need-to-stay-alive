extends AnimatedSprite2D

## Generic one-shot VFX: plays its "play" animation once, then frees itself.
## Attach to any AnimatedSprite2D whose SpriteFrames has a non-looping
## animation named "play".
##
## Sahnesinde "Sound" adında bir AudioStreamPlayer2D varsa (ör. ateş asası
## patlaması) animasyonla birlikte çalınır; node, animasyon bitince görünmez
## olur ama ses bitmeden serbest bırakılmaz (yoksa ses yarıda kesilir).


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s:
		s.pitch_scale = randf_range(0.94, 1.06)
		s.play()
	play("play")
	## DÜZELTME (kullanıcı bildirimi: "oyun ilerleyince yaratıklar çok
	## çoğalmasa bile bir süre sonra fps aşırı düşüyor"): bu node'un tek
	## temizlenme yolu animation_finished sinyaliydi - "play" animasyonu
	## yanlışlıkla döngülü (loop) işaretlenmişse bu sinyal hiç gelmez, ya da
	## _on_animation_finished() içindeki "await s.finished" bir sebeple
	## (ör. Sound node'u dıştan durdurulmuş/serbest bırakılmışsa) asla
	## tamamlanmazsa, bu VFX kopyası SONSUZA KADAR sahnede asılı kalırdı.
	## Her ateş edilen mermi/vuruş için ayrı bir VFX oluşturulduğundan
	## (bkz. weapon.gd), uzun bir oturumda bu tür kaçak kopyalar sessizce
	## birikip zamanla FPS'i düşürebilirdi. Artık bir GÜVENLİK ZAMANLAYICISI
	## var - normal VFX'ler çok daha hızlı bittiği için bu asla erken
	## tetiklenmez, sadece yukarıdaki gibi bir aksilik olduğunda devreye girer.
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


func _on_animation_finished() -> void:
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s and is_instance_valid(s) and s.playing:
		visible = false
		await s.finished
	if is_instance_valid(self):
		queue_free()
