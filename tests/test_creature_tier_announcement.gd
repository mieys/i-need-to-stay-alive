extends Node

## Kullanıcı isteği (2026-10-04): "Bundan sonra yaratıkların kademesi arttığında insanlara bildirim gelsin kademe numarası yazsın."
## Host Kademe saatinin (boss kapısı dahil) yeni Kademe'ye geçtiğini enemy_spawner.gd _check_tier_announcement ile yakalar ve
## NetworkManager.creature_tier_reached ile numarayı herkese yollar (main.gd toast gösterir).

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const TIER_SECONDS := 100.0


## Kademe kapısını tutan "boss" taklidi (sadece is_dead okunuyor).
class FakeBoss extends Node:
	var is_dead: bool = false


var _made: Array[Node] = []
var _heard: Array = []


func _on_tier(tier: int) -> void:
	_heard.append(tier)


func _spawner() -> Node:
	_cleanup()
	GameManager.game_time = 0.0
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	_made.append(sp)
	_heard.clear()
	NetworkManager.creature_tier_reached.connect(_on_tier)
	return sp


func _cleanup() -> void:
	if NetworkManager.creature_tier_reached.is_connected(_on_tier):
		NetworkManager.creature_tier_reached.disconnect(_on_tier)
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


func test_announces_each_new_tier_once() -> void:
	var sp: Node = _spawner()
	sp._check_tier_announcement()
	assert(_heard.is_empty(), "Oyun başında (Kademe 1) bildirim gelmemeli: %s" % str(_heard))
	GameManager.game_time = TIER_SECONDS - 1.0
	sp._check_tier_announcement()
	assert(_heard.is_empty(), "Kademe 1 bitmeden bildirim gelmemeli: %s" % str(_heard))
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	sp._check_tier_announcement()
	assert(_heard == [2], "Kademe 2'ye geçişte TEK bildirim (numara 2) gelmeli: %s" % str(_heard))
	GameManager.game_time = TIER_SECONDS * 2.0 + 1.0
	sp._check_tier_announcement()
	assert(_heard == [2, 3], "Kademe 3 de bildirilmeli: %s" % str(_heard))
	_cleanup()


func test_tier_held_by_a_living_boss_is_not_announced_until_it_dies() -> void:
	var sp: Node = _spawner()
	var boss := FakeBoss.new()
	add_child(boss)
	_made.append(boss)
	sp._tier_bosses[2] = [boss] ## Kademe 2'nin bossu sağ: saat Kademe 2'nin bitiş sınırında bekler
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	GameManager.game_time = TIER_SECONDS * 2.0 + 50.0
	sp._check_tier_announcement()
	assert(_heard == [2], "Boss sağken Kademe 3 bildirilmemeli (kademe gerçekten değişmedi): %s" % str(_heard))
	boss.is_dead = true
	sp._check_tier_announcement()
	assert(_heard == [2], "Boss öldüğü an saat kaldığı yerden devam eder, Kademe 3 henüz başlamadı: %s" % str(_heard))
	GameManager.game_time += 2.0 ## saat akmaya devam etti -> Kademe 3 başladı
	sp._check_tier_announcement()
	assert(_heard == [2, 3], "Boss öldükten sonra saat Kademe 3'e geçince bildirilmeli: %s" % str(_heard))
	_cleanup()


func test_final_tier_announces_its_own_number_and_stops() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = TIER_SECONDS * 15.0 + 1.0 ## Final Kademe (16)
	sp._check_tier_announcement()
	assert(_heard == [16], "Final Kademe tek bildirimle 16 olarak gelmeli: %s" % str(_heard))
	GameManager.game_time = TIER_SECONDS * 20.0
	sp._check_tier_announcement()
	assert(_heard == [16], "Final'den sonra yeni bildirim gelmemeli: %s" % str(_heard))
	_cleanup()


func test_new_game_resets_the_announcement_counter() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = TIER_SECONDS * 3.0 + 1.0
	sp._check_tier_announcement()
	assert(_heard == [4], "Kademe 4'e atlanınca 4 bildirilmeli: %s" % str(_heard))
	GameManager.game_time = 0.0 ## yeni oyun
	sp._check_tier_announcement()
	assert(sp._announced_tier == 1, "Yeni oyunda sayaç 1'e dönmeli (bulunan: %d)" % sp._announced_tier)
	GameManager.game_time = TIER_SECONDS + 1.0
	sp._check_tier_announcement()
	assert(_heard == [4, 2], "Yeni oyunda Kademe 2 tekrar bildirilmeli: %s" % str(_heard))
	_cleanup()
