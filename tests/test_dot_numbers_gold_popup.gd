extends Node

## 2026-11-06 (kullanıcı): (1) zehir/yanma/kanama gibi süreli hasar sayıları saniyede 3 küçük sayıya bölünür (toplam korunur, yalnız görsel);
## (2) altın kazancı "+N" yazısı karakterin üstünde değil HUD altın çerçevesinin yanında (gold_gain_popup.gd) - peş peşe kazançlar toplanır,
## harcama yazı çıkarmaz, süre dolunca söner.

const EnemyScript := preload("res://scripts/enemy.gd")
const DamageNumbersScript := preload("res://scripts/damage_numbers.gd")
const PopupScript := preload("res://scripts/gold_gain_popup.gd")


func test_dot_parts_split_three_per_second_and_keep_the_total() -> void:
	var p: Array[int] = EnemyScript.dot_number_parts(10.0, 1.0)
	assert(p == [4, 3, 3], "10 hasar 1 sn'lik tikte 3 parça: %s" % [p])
	p = EnemyScript.dot_number_parts(120.0, 1.0)
	assert(p == [40, 40, 40], "120 -> 40/40/40: %s" % [p])
	p = EnemyScript.dot_number_parts(100.0, 1.0)
	var sum: int = 0
	for v in p:
		sum += v
	assert(p.size() == 3 and sum == 100, "100 -> toplam korunur: %s" % [p])


func test_dot_parts_never_exceed_the_visible_amount_or_interval() -> void:
	assert(EnemyScript.dot_number_parts(2.0, 1.0) == [1, 1], "2 hasar en çok 2 parça")
	assert(EnemyScript.dot_number_parts(1.0, 1.0) == [1], "1 hasar bölünmez")
	assert(EnemyScript.dot_number_parts(0.2, 1.0) == [1], "ondalıklı küçük hasar en az 1")
	## 0,5 sn'lik kanama: 1,5 parça aşağı yuvarlanır -> tek sayı (saniyede 2 sayı zaten sık).
	assert(EnemyScript.dot_number_parts(30.0, 0.5) == [30], "0,5 sn'lik tik bölünmez")
	assert(EnemyScript.dot_number_parts(30.0, 0.0) == [30], "tek seferlik hasar bölünmez")


func test_call_later_runs_after_the_delay_and_skips_freed_targets() -> void:
	var dn: Node2D = Node2D.new()
	dn.set_script(DamageNumbersScript)
	add_child(dn)
	var hits: Array = []
	dn.call_later(0.3, func() -> void: hits.append("a"))
	dn.call_later(0.1, func() -> void: hits.append("b"))
	var doomed := Node.new()
	dn.call_later(0.2, Callable(doomed, "queue_free")) ## geçerli bir çağrı: düğüm silinir
	var dead := Node.new()
	var dead_call := Callable(dead, "queue_free")
	dead.free()
	dn.call_later(0.1, dead_call) ## silinmiş nesne: sessizce atlanır, hata yok
	dn._process(0.15)
	assert(hits == ["b"], "0,1 sn'lik çalıştı, 0,3 sn'lik bekliyor: %s" % [hits])
	dn._process(0.2)
	assert(hits == ["b", "a"], "sıra gecikmeye göre: %s" % [hits])
	assert(dn._delayed.is_empty(), "kuyruk boşalır")
	if is_instance_valid(doomed):
		doomed.free()
	dn.free()


func test_gold_popup_shows_gains_merges_them_and_ignores_spending() -> void:
	var anchor := Control.new()
	anchor.size = Vector2(200, 50)
	add_child(anchor)
	var pop: Label = Label.new()
	pop.set_script(PopupScript)
	pop.anchor = anchor
	add_child(pop)
	pop.note_value(100) ## ilk değer taban: yazı yok
	assert(pop.text == "" and not pop.visible, "başlangıç değeri kazanç sayılmaz")
	pop.note_value(103)
	assert(pop.text == "+3", "kazanç yazılır: %s" % pop.text)
	pop._age = 0.0
	pop.visible = true
	pop.note_value(105)
	assert(pop.text == "+5", "kısa sürede gelen kazanç toplanır: %s" % pop.text)
	pop.note_value(90)
	assert(pop.text == "+5", "harcama yazıyı değiştirmez: %s" % pop.text)
	pop._age = PopupScript.MERGE_WINDOW + 0.1
	pop.note_value(92)
	assert(pop.text == "+2", "süre geçince yeni yazı baştan başlar: %s" % pop.text)
	assert(PopupScript.alpha_at(0.0) == 1.0 and PopupScript.alpha_at(PopupScript.HOLD) == 1.0, "bekleme boyunca tam görünür")
	assert(PopupScript.alpha_at(PopupScript.HOLD + PopupScript.FADE) <= 0.001, "süre sonunda görünmez")
	pop.free()
	anchor.free()


## Pasif altın (2026-11-14): sayaç artar ama "+1" yazısı çıkmaz - sayaç aynı karede de bir kare sonra da güncellense.
func test_gold_popup_ignores_silent_passive_gold() -> void:
	var anchor := Control.new()
	add_child(anchor)
	var pop: Label = Label.new()
	pop.set_script(PopupScript)
	pop.anchor = anchor
	pop.note_value(100, 7)
	pop.note_value(101, 8) ## aynı karede
	assert(pop.text == "", "sessiz altın yazı çıkarmaz: %s" % pop.text)
	pop.note_value(101, 9) ## sayaç henüz görmedi
	pop.note_value(102, 9) ## bir kare sonra gördü
	assert(pop.text == "", "gecikmeli sessiz altın da yazı çıkarmaz: %s" % pop.text)
	pop.note_value(111, 10) ## 8 gerçek kazanç + 1 sessiz
	assert(pop.text == "+8", "gerçek kazanç sessiz pay düşülerek yazılır: %s" % pop.text)
	pop.free()
	anchor.free()


func test_passive_gold_one_per_interval_only_with_a_player() -> void:
	var old_gold: int = GameManager.gold
	var old_total: int = GameManager.passive_gold_total
	var old_enabled: bool = GameManager.passive_gold_enabled
	GameManager.passive_gold_enabled = true ## test çalıştırıcısı kapatır (run_tests.gd)
	GameManager._passive_gold_left = GameManager.PASSIVE_GOLD_INTERVAL
	var iv: float = GameManager.PASSIVE_GOLD_INTERVAL
	assert(is_equal_approx(iv, 5.0), "2026-11-15: 5 sn'de 1 altın (eskiden 2 sn)")
	GameManager._process_passive_gold(iv + 0.1)
	assert(GameManager.gold == old_gold, "oyuncu sahnede yokken (menü) altın verilmez")
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	GameManager._process_passive_gold(iv * 0.5)
	assert(GameManager.gold == old_gold, "süre dolmadan altın yok")
	GameManager._process_passive_gold(iv * 0.5)
	assert(GameManager.gold == old_gold + 1, "aralık başına 1 altın: %d" % (GameManager.gold - old_gold))
	assert(GameManager.passive_gold_total == old_total + 1, "sessiz toplam artar")
	for i in range(10):
		GameManager._process_passive_gold(iv * 0.25)
	assert(GameManager.gold == old_gold + 3, "2,5 aralık daha -> toplam 3: %d" % (GameManager.gold - old_gold))
	p.free()
	GameManager.gold = old_gold
	GameManager._passive_gold_left = GameManager.PASSIVE_GOLD_INTERVAL
	GameManager.passive_gold_enabled = old_enabled


func test_gold_popup_sits_beside_the_frame() -> void:
	var anchor := Control.new()
	anchor.position = Vector2(20, 100)
	anchor.size = Vector2(200, 50)
	add_child(anchor)
	var pop: Label = Label.new()
	pop.set_script(PopupScript)
	pop.anchor = anchor
	add_child(pop)
	pop.text = "+7"
	pop.reset_size()
	pop._place_beside_anchor()
	var r: Rect2 = anchor.get_global_rect()
	assert(pop.global_position.x >= r.end.x, "çerçeve soldaysa yazı sağında: %s" % pop.global_position)
	assert(absf(pop.global_position.y + pop.size.y * 0.5 - r.get_center().y) < 1.0, "dikey ortalı")
	pop.free()
	anchor.free()
