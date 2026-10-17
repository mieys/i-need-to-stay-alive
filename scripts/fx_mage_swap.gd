extends Node2D

## Büyücü Kız her Q ile set değiştirdiğinde (player.gd _skill_buyucu_switch_variation) karakterin üstünde bir kez oynayan efekt.
## 2026-10-16 (madde 188, onaylanan prototip): göğsünün önünde havada büyü kitabı açılır, sayfalar çevrilir, eski setin iki zerresi
## kitaba girer, kitap parlar, yeni setin zerreleri çıkıp belin çevresinde bir tur döner; yerde yeni setin renginde rün halkası.
## target_set (props - _play_and_broadcast_skill_fx uzak kopyaya aynen gönderir): 0 = Set 1'e (soğuk), 1 = Set 2'ye (sıcak) geçiş.
## Arka katman (halka + arkadaki zerreler) karakterin altında, ön katman (kitap + öndeki zerreler) üstünde. Sola bakarken aynalanır.
## (Eski hali: gökkuşağı yıldızlı fx_mage_swap_frames.tres - artık kullanılmıyor.)

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const FPS := 15.0

var target_set: int = 0


func _ready() -> void:
	var p: Node = get_parent()
	var flip: bool = BuyucuFxScript.facing_left(p)
	var n: int = clampi(target_set, 0, 1)
	BuyucuFxScript.char_layer(self, p, "q_back_%d" % n, -1, FPS, flip)
	var front: Node = BuyucuFxScript.char_layer(self, p, "q_front_%d" % n, 2, FPS, flip)
	front.tree_exited.connect(queue_free)
