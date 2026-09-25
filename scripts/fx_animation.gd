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
	_release_flash_glow()
	var s: AudioStreamPlayer2D = get_node_or_null("Sound")
	if s and is_instance_valid(s) and s.playing:
		visible = false
		await s.finished
	if is_instance_valid(self):
		queue_free()


## Kullanıcı bildirimi (2026-09-25, ikinci kez): "ateş asasının patlama efekti ışık saçmıyor". Kök neden: gece ışığı
## (night_glow.gd, atmosphere.gd bu efekte çocuk olarak takıyor) sahibi GİZLENİNCE sönüyor - ateş patlaması 0,5 sn'de
## biter ve sesi beklemek için visible=false olur, yani ışık katalogdaki flaş süresinin ("d", 0,75 sn) ortasında,
## henüz güçlüyken kesiliyordu (ölçüldü: 0,5 sn'de güç 0,33 -> 0). Flaş ışığı (decay > 0) artık aynı dünya noktasında
## ebeveyne taşınır ve kendi süresi dolunca kendiliğinden söner (night_glow.gd _process -> queue_free). Sürekli ışıklar
## (decay 0) taşınmaz - sahipsiz kalıp sonsuza dek yanarlardı.
func _release_flash_glow() -> void:
	var glow: Node2D = get_node_or_null("NightGlow") as Node2D
	if glow == null or float(glow.get("decay")) <= 0.0:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	glow.reparent(parent)
