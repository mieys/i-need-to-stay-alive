extends ColorRect

## DÜZELTME (kullanıcı bildirimi: "rüzgar efekti haritayla yapışık değil,
## karakterin yürümesiyle hareket ediyor") - kök neden: shader'ın vertex()
## fonksiyonu ekran-uzayı (piksel) konumunu dünya konumuna çevirirken SADECE
## camera_pos'u (dünya ofseti) ekliyordu, kameranın zoom/ölçeğini HİÇ
## hesaba katmıyordu. Zoom 1.0 olmadığı sürece (ki bu oyunda değil) bu,
## ekranın sol üst köşesi (0,0) DIŞINDAKİ her piksel için orantısız bir hata
## üretiyordu - hata, ekran merkezine (yani genelde karakterin durduğu yere)
## yaklaştıkça büyüyordu, bu da efektin "karakteri takip ediyormuş" gibi
## görünmesine yol açıyordu. Artık ölçek de (camera_scale) shader'a
## gönderiliyor, orada ekran-uzayı konumu dünyaya çevrilirken buna bölünüyor.
func _process(_delta):
	# floor() kullanmıyoruz.
	# canvas_transform, ekranın dünyada tam nereye denk geldiğini kusursuz hesaplar.
	var canvas_transform = get_viewport().canvas_transform
	var cam_scale = canvas_transform.get_scale()
	
	# Ekranın sol üst köşesinin gerçek dünya (world) koordinatını alıyoruz
	var world_offset = -canvas_transform.origin / cam_scale
	
	material.set_shader_parameter("camera_pos", world_offset)
	material.set_shader_parameter("camera_scale", cam_scale)
