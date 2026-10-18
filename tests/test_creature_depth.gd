extends Node

## Yaratık - oyuncu derinliği (kullanıcı isteği 2026-10-08, y-sıralama): oyuncunun ÖNÜNDE (ayağı daha aşağıda) ve onunla örtüşen yaratık oyuncunun üstüne
## çizilir (z 2), ARKASINDA kalan/uzak/ölü yaratık eski z'de kalır; ayrılınca z geri döner. Gerçek çizimin sonucu pencereli ekran görüntüsüyle bakıldı.

const CreatureDepthScript := preload("res://scripts/creature_depth.gd")
const PaladinDomeScript := preload("res://scripts/paladin_dome.gd")
const ForestCanopyScript := preload("res://scripts/forest_canopy.gd")

var _spawned: Array = []


class DeadCreature extends Node2D:
	var is_dead: bool = true


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _creature(pos: Vector2, dead: bool = false, width: int = 32) -> Node2D:
	var e: Node2D = DeadCreature.new() if dead else Node2D.new()
	e.add_to_group("enemies")
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = ImageTexture.create_from_image(Image.create(width, 48, false, Image.FORMAT_RGBA8))
	e.add_child(spr)
	_track(e)
	add_child(e)
	e.global_position = pos
	return e


func test_cover_rule_table() -> void:
	var H: float = CreatureDepthScript.HYSTERESIS
	## oyuncunun ayağı y=100, yaratık 48 px boyunda, aynı x
	assert(CreatureDepthScript.should_cover(130.0, 48.0, 0.0, 100.0, false), "ayağı aşağıda + örtüşüyor -> oyuncunun üstüne")
	assert(not CreatureDepthScript.should_cover(90.0, 48.0, 0.0, 100.0, false), "ayağı yukarıda: yaratık arkada, oyuncu üstte")
	assert(not CreatureDepthScript.should_cover(100.0, 48.0, 0.0, 100.0, false), "aynı hizada: yükselmez (titreme koruması)")
	assert(not CreatureDepthScript.should_cover(100.0 + H, 48.0, 0.0, 100.0, false), "tam eşikte yükselmez")
	assert(CreatureDepthScript.should_cover(100.0 + H + 0.5, 48.0, 0.0, 100.0, false), "eşiği geçince yükselir")
	assert(CreatureDepthScript.should_cover(100.0 - H + 0.5, 48.0, 0.0, 100.0, true), "yükselmişse biraz yukarı çıkana kadar yerinde kalır (histerezis)")
	assert(not CreatureDepthScript.should_cover(100.0 - H - 0.5, 48.0, 0.0, 100.0, true), "histerezis eşiğini geçince iner")
	assert(not CreatureDepthScript.should_cover(200.0, 48.0, 0.0, 100.0, false), "görselin tamamı oyuncunun ayağından aşağıda: örtüşme yok")
	assert(not CreatureDepthScript.should_cover(130.0, 48.0, 90.0, 100.0, false), "yatayda uzak: örtüşme yok")
	assert(CreatureDepthScript.should_cover(180.0, 140.0, 0.0, 100.0, false), "büyük (boss) yaratık uzaktan da örter")


func test_creature_in_front_is_raised_and_restored_when_it_moves_behind() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	player.global_position = Vector2(100, 100) ## ayak = 115
	var overlapping: Node2D = _creature(Vector2(105, 135)) ## ayağı 135, görsel boyu 48 -> üst kenarı 135-48 = 87 < 115: örtüşür
	var behind: Node2D = _creature(Vector2(100, 70))
	var far: Node2D = _creature(Vector2(100, 400))
	var dead: Node2D = _creature(Vector2(100, 140), true)
	var cd: Node = CreatureDepthScript.new()
	_track(cd)
	add_child(cd)
	cd.update_now()
	assert(overlapping.z_index == CreatureDepthScript.FRONT_Z, "oyuncunun önünde ve örtüşen yaratık oyuncunun (z 1) üstüne çıkmalı: z=%d" % overlapping.z_index)
	assert(behind.z_index == 0, "arkada kalan yaratık dokunulmaz")
	assert(far.z_index == 0, "uzak yaratık dokunulmaz")
	assert(dead.z_index == 0, "ölüm animasyonundaki (yerde yatan) yaratık hep oyuncunun altında kalır")
	## yaratık oyuncunun arkasına geçince (ayağı yukarı) eski z'ye döner
	overlapping.global_position = Vector2(105, 60)
	cd.update_now()
	assert(overlapping.z_index == 0, "arkaya geçince z eski haline dönmeli: z=%d" % overlapping.z_index)
	## oyuncu yoksa (ölünce/gizlenince) yükselenler geri döner
	overlapping.global_position = Vector2(105, 135)
	cd.update_now()
	assert(overlapping.z_index == CreatureDepthScript.FRONT_Z)
	player.visible = false
	cd.update_now()
	assert(overlapping.z_index == 0, "karakter listede yoksa yaratık z'si geri alınmalı")
	cd.free()
	_spawned.erase(cd)
	_cleanup()


## KAPANIŞ (2026-10-09, "yeraltı canavarı yan yana dizilince birbirinin üzerinde görünüyor"): oyuncunun önünde yükseltilen yaratığın ÖNÜNDEKİ (ayağı daha aşağıdaki) ve onunla örtüşen komşusu
## yükseltilmezse (oyuncuyla örtüşmüyor), arkadaki yaratık öndekinin üstüne çiziliyordu (z 2 > z 0). Yükseltilen küme ayak sırasında aşağıya doğru kapalı kalmalı.
func test_raised_set_is_closed_downwards_so_creature_order_is_not_inverted() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	player.global_position = Vector2(100, 100) ## ayak = 115
	var a: Node2D = _creature(Vector2(105, 135), false, 96) ## oyuncuyla örtüşüyor: doğrudan yükselir
	var b: Node2D = _creature(Vector2(170, 150), false, 96) ## oyuncudan yatayda uzak (doğrudan yükselmez) AMA a'nın önünde ve a ile örtüşüyor
	var c: Node2D = _creature(Vector2(500, 150), false, 96) ## a'dan yatayda çok uzak: örtüşmez, dokunulmaz
	var d: Node2D = _creature(Vector2(105, 400), false, 96) ## a'nın tamamen altında (görsel örtüşmesi yok)
	var cd: Node = CreatureDepthScript.new()
	_track(cd)
	add_child(cd)
	cd.update_now()
	assert(a.z_index == CreatureDepthScript.FRONT_Z, "oyuncuyla örtüşen yükselir")
	assert(b.z_index == CreatureDepthScript.FRONT_Z, "yükselen yaratığın önündeki örtüşen komşu da yükselir (yoksa arkadaki öndekinin üstüne çizilirdi): z=%d" % b.z_index)
	assert(c.z_index == 0 and d.z_index == 0, "örtüşmeyenlere dokunulmaz: %d %d" % [c.z_index, d.z_index])
	## komşu yukarı (arkaya) çıkınca (ayağı a'nınkinden küçük) kapanışa girmez
	b.global_position = Vector2(170, 120)
	cd.update_now()
	assert(b.z_index == 0, "a'nın ARKASINDAKİ yaratık yükselmez (a zaten öne çıktı, b altta kalmalı): z=%d" % b.z_index)
	cd.free()
	_spawned.erase(cd)
	_cleanup()


func test_close_over_pure_rule() -> void:
	var n1 := Node2D.new()
	var n2 := Node2D.new()
	var n3 := Node2D.new()
	var n4 := Node2D.new()
	for n in [n1, n2, n3, n4]:
		_track(n)
	## pool: düğüm -> [ayak y, x, yarım genişlik, boy]
	var pool: Dictionary = {n1: [100.0, 0.0, 30.0, 40.0], n2: [120.0, 50.0, 30.0, 40.0], n3: [140.0, 100.0, 30.0, 40.0], n4: [400.0, 0.0, 30.0, 40.0]}
	var want: Dictionary = {n1: true}
	var added: int = CreatureDepthScript.close_over(want, pool)
	assert(want.has(n2) and want.has(n3), "zincir: n1 -> n2 (örtüşür) -> n3 (n2 ile örtüşür)")
	assert(not want.has(n4), "yatay/dikey örtüşmeyen alttaki dokunulmaz")
	assert(added == 2)
	assert(CreatureDepthScript.close_over({}, pool) == 0, "yükseltilen yoksa bir şey yapmaz")
	## yukarıdaki (ayağı küçük) komşu kapanışa girmez
	var pool2: Dictionary = {n1: [100.0, 0.0, 30.0, 40.0], n2: [80.0, 20.0, 30.0, 40.0]}
	var want2: Dictionary = {n1: true}
	assert(CreatureDepthScript.close_over(want2, pool2) == 0 and not want2.has(n2), "arkadaki yaratık yükseltilmez")
	for n in [n1, n2, n3, n4]:
		n.free()
		_spawned.erase(n)


## Şovalye kubbesi (2026-10-17, kullanıcı: "şovalye adamın bariyerinin altında gibi görünüyor yaratıklar. y eksenine tabi değil bu bariyer"): kubbenin ön kabuğu
## z 20'de; elipsin DIŞINDA ve merkezin GÜNEYİNDE duran, kabukla örtüşen varlık kabuğun önündedir (üstüne çizilmeli), içerideki/kuzeydeki altında kalır.
func test_dome_front_shell_rule_table() -> void:
	var c := Vector2(0, 0)
	var r: float = 126.0 ## elips 126 x 63
	var H: float = CreatureDepthScript.HYSTERESIS
	assert(PaladinDomeScript.in_front_of_shell(c, r, 0.0, 80.0, 16.0, 48.0, H), "güneyde, elipsin dışında, kabukla örtüşüyor -> önde")
	assert(not PaladinDomeScript.in_front_of_shell(c, r, 0.0, 40.0, 16.0, 48.0, H), "elipsin içinde -> camın içinde, kabuğun altında")
	assert(not PaladinDomeScript.in_front_of_shell(c, r, 0.0, -80.0, 16.0, 48.0, H), "kuzeyde -> kubbenin arkasında")
	assert(not PaladinDomeScript.in_front_of_shell(c, r, 0.0, 200.0, 16.0, 48.0, H), "görseli tamamen kubbenin altında -> örtüşme yok")
	assert(not PaladinDomeScript.in_front_of_shell(c, r, 300.0, 20.0, 16.0, 48.0, H), "yatayda uzak -> örtüşme yok")
	assert(PaladinDomeScript.in_front_of_shell(c, r, 130.0, 10.0, 16.0, 48.0, H), "yanda, merkezin hemen güneyinde ve dışarıda -> önde")
	assert(not PaladinDomeScript.in_front_of_shell(c, r, 0.0, 64.0, 16.0, 48.0, H), "kenarın 1 px dışı: yükselmek için yetmez (titreme koruması)")
	assert(PaladinDomeScript.in_front_of_shell(c, r, 0.0, 64.0, 16.0, 48.0, -H), "zaten öndeyse kenarda kalır")


class FakeKnight extends Node2D:
	var is_dead: bool = false
	var paladin_zone_active: bool = true
	var paladin_zone_radius: float = 126.0


func test_creatures_and_players_in_front_of_the_dome_are_drawn_over_its_shell() -> void:
	var knight := FakeKnight.new()
	knight.add_to_group("remote_players")
	_track(knight)
	add_child(knight)
	knight.global_position = Vector2(500, 500) ## elips: x 374..626, y 437..563
	var front: Node2D = _creature(Vector2(500, 580)) ## ayağı elipsin dışında (alt uç 563), üstü (532) kabukla örtüşür -> kabuğun önünde
	var behind: Node2D = _creature(Vector2(500, 420)) ## kuzeyde
	var inside: Node2D = _creature(Vector2(520, 505)) ## camın içinde (Şovalye'nin ayağının arkasında: oyuncu kuralına da girmez)
	var cd: Node = CreatureDepthScript.new()
	_track(cd)
	add_child(cd)
	cd.update_now()
	assert(front.z_index == CreatureDepthScript.DOME_FRONT_Z and front.z_index > PaladinDomeScript.SHELL_Z, "kabuğun önündeki yaratık kabuğun üstüne: z=%d" % front.z_index)
	assert(behind.z_index == 0 and inside.z_index == 0, "arkadaki/içerideki kabuğun altında kalır: %d %d" % [behind.z_index, inside.z_index])
	## kabuğun önündeki oyuncu kabuğun üstüne, onun da önündeki yaratık oyuncunun üstüne (kubbeyle örtüşmese bile)
	var player := Node2D.new()
	player.add_to_group("player")
	_track(player)
	add_child(player)
	player.global_position = Vector2(500, 572) ## ayak 584,75: elipsin dışında, gövdesi kabukla örtüşür
	var before_player: Node2D = _creature(Vector2(505, 630)) ## oyuncunun önünde ve onunla örtüşüyor; kabuğun tamamen altında (üstü 582)
	cd.update_now()
	assert(player.z_index == CreatureDepthScript.DOME_FRONT_CHAR_Z, "kabuğun önündeki oyuncu: z=%d" % player.z_index)
	assert(front.z_index == CreatureDepthScript.DOME_FRONT_Z and front.z_index < player.z_index, "oyuncunun arkasındaki yaratık oyuncunun altında: z=%d" % front.z_index)
	assert(before_player.z_index == CreatureDepthScript.DOME_FRONT_Z + CreatureDepthScript.FRONT_Z, "kabuğun önündeki oyuncunun önündeki yaratık en üstte: z=%d" % before_player.z_index)
	## kubbe kapanınca hepsi eski düzenine döner
	knight.paladin_zone_active = false
	cd.update_now()
	assert(front.z_index == 0 and player.z_index == 0, "kubbe yokken eski z: %d %d" % [front.z_index, player.z_index])
	assert(before_player.z_index == CreatureDepthScript.FRONT_Z, "oyuncunun önündeki yaratık normal kurala döner: z=%d" % before_player.z_index)
	## duvar geçen (uçan) oyuncunun z'si forest_canopy'nin: dokunulmaz
	knight.paladin_zone_active = true
	player.set_meta(ForestCanopyScript.META_BASE_Z, 0)
	player.z_index = ForestCanopyScript.FLYER_Z
	cd.update_now()
	assert(player.z_index == ForestCanopyScript.FLYER_Z, "uçan oyuncuya dokunulmaz: z=%d" % player.z_index)
	cd.free()
	_spawned.erase(cd)
	_cleanup()


## FPS (2026-10-18): close_over ikili aramalı çekirdeğe geçti. Eski kural ("her düğüm x tüm yükseltilenler" çift döngüsü, burada referans) ile rastgele havuzlarda BİREBİR aynı küme.
static func _naive_close_over(want: Dictionary, pool: Dictionary) -> int:
	if want.is_empty() or pool.size() <= want.size():
		return 0
	var keys: Array = []
	var nodes: Array = pool.keys()
	for i in range(nodes.size()):
		keys.append(Vector2(float((pool[nodes[i]] as Array)[0]), float(i)))
	keys.sort()
	var raised: Array = []
	var added: int = 0
	for k: Vector2 in keys:
		var n: Variant = nodes[int(k.y)]
		var info: Array = pool[n]
		if want.has(n):
			raised.append(info)
			continue
		for a: Array in raised:
			if float(a[0]) < float(info[0]) - 0.5 and absf(float(a[1]) - float(info[1])) < float(a[2]) + float(info[2]) and float(info[0]) - float(info[3]) < float(a[0]):
				want[n] = true
				raised.append(info)
				added += 1
				break
	return added


func test_close_over_matches_the_naive_rule_on_random_pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var mismatches: int = 0
	var total_added: int = 0
	for trial in range(80):
		var nodes: Array = []
		var pool: Dictionary = {}
		for i in range(rng.randi_range(2, 90)):
			var n := Node2D.new()
			nodes.append(n)
			## ayak y'leri bilerek yakın kümelenir (0,5 px eşiği ve eşit ayaklar sınanır)
			var foot: float = float(rng.randi_range(0, 60)) * (0.5 if rng.randf() < 0.4 else 3.0) + (0.25 if rng.randf() < 0.3 else 0.0)
			pool[n] = [foot, rng.randf_range(-150.0, 150.0), rng.randf_range(8.0, 40.0), rng.randf_range(10.0, 90.0)]
		var want_a: Dictionary = {}
		var want_b: Dictionary = {}
		for n in nodes:
			if rng.randf() < 0.15:
				want_a[n] = true
				want_b[n] = true
		var add_a: int = _naive_close_over(want_a, pool)
		var add_b: int = CreatureDepthScript.close_over(want_b, pool)
		total_added += add_b
		var same: bool = add_a == add_b and want_a.size() == want_b.size()
		if same:
			for n in want_a:
				if not want_b.has(n):
					same = false
					break
		if not same:
			mismatches += 1
		for n in nodes:
			n.free()
	assert(mismatches == 0, "close_over eski kuralla %d/80 denemede farklı küme verdi" % mismatches)
	assert(total_added > 50, "deney anlamlı olsun: kapanışla eklenen yaratık sayısı çok az (%d)" % total_added)
