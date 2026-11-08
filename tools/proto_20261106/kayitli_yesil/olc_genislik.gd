extends SceneTree
## Geliştirme satırı yazılarının m5x7 32 genişliği (madde 433 ek; tek seferlik ölçüm, oyuna bağlı DEĞİL).
func _initialize() -> void:
	var f: Font = load("res://assets/fonts/m5x7.ttf")
	for s in ["Gökkuşağı Asası", "Uzunkılıç", "Yıldırım Asası", "Kale Mana Kalkanı", "III → IV", "IV → V", "+12", "3/3", "+%10 hasar, +%5 saldırı hızı", "+20 Mana Kalkanı, +0,5 Yenilenme/sn"]:
		print("W %4d %s" % [f.get_string_size(s, 0, -1, 32).x, s])
	quit()
