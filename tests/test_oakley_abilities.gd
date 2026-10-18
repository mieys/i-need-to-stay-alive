extends Node

## Kullanıcı isteği doğrulaması: Oakley'nin TAM kit değişikliği - "Oakleyin
## pasifi silinecek ve Q su bundan sonra pasifi olacak... otomatik olarak
## yakınlarına çiçek bırakacak... Oakleyin R yeteneği artık boşta kalan Q
## yeteneği olacak... Yeni R yeteneği ise canı en az olan arkadaşına
## koruyucu bir büyü yapar".
##
## NOT: bu dosya eskiden Oakley'nin ÇOK DAHA ÖNCEKİ bir kitini (Can Basma/
## Kalkan Yenileme - "Oakley yeni yetenekleri" reworkundan ÖNCEKİ, Melek'le
## paylaşılan kit) test ediyordu; o fonksiyonlar (_skill_heal/_passive_oakley/
## _process_oakley_heal_tick vb.) hâlâ var ama artık SADECE Melek'e ait
## ("oakley_" adlandırması tarihsel bir kalıntı, bkz. player.gd _process_
## character_passive'teki roster id ayrımı) - bu test dosyası ÇOKTAN bayattı,
## bugünkü rework onu daha da alakasız hale getirdiği için TAMAMEN
## yenilendi.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func _make_oakley_player() -> Node:
	GameManager.selected_char_id = 2 ## Oakley (roster id)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


## characters.gd DEFS'in yeni kiti doğru taşıdığını doğrular - id'ler
## KODUN gerçekte okuduğu değerlerle (player.gd match blokları) birebir
## eşleşmeli, aksi halde tuşlar sessizce hiçbir şey yapmaz.
func test_defs_reflect_new_kit() -> void:
	var def: Dictionary = Characters.get_def(2)
	assert(def.get("name", "") == "Oakley", "roster id 2 Oakley olmalı")
	assert(int(def.get("skill", 0)) == 33,
		"Oakley'nin Q'su artık Arı Sürüsü (id 33) olmalı, bulunan: %s" % def.get("skill"))
	assert(int(def.get("skill3", 0)) == 39 and def.get("skill3_name", "") == "Hayat Ağacı",
		"Oakley'nin R'si Hayat Ağacı (id 39, madde 266) olmalı, bulunan: %s %s" % [def.get("skill3"), def.get("skill3_name")])
	assert(int(def.get("skill2", 0)) == 10,
		"Oakley'nin E'si (Sarmaşıklar) değişmemeli, bulunan: %s" % def.get("skill2"))
	assert(def.get("passive", "").find("çiçek") != -1,
		"Oakley'nin yeni pasifi çiçek bırakmaktan bahsetmeli, bulunan: %s" % def.get("passive"))


## Kullanıcı isteği: "oakleyin ultisinin ikonunu 1-2 gün önce yüklediğimiz ve sonra kaldırdığımız
## pasif ikonu olarak göster" + "saldırı gücü oranlarını 2 kat arttır" - ikon dosyası gerçekten
## yüklenebilmeli, pasif ikonu (Çiçek) değişmemeli, açıklama metni sabitlerle tutarlı olmalı.
func test_ultimate_uses_the_old_passive_icon_and_text_matches_the_doubled_ratios() -> void:
	var def: Dictionary = Characters.get_def(2)
	assert(def.get("skill3_icon", "") == "res://assets/skills/oakley_passive_icon.png",
		"Koruyucu Büyü ikonu eski pasif ikonu olmalı, bulunan: %s" % def.get("skill3_icon"))
	assert(ResourceLoader.exists("res://assets/skills/oakley_passive_icon.png"), "İkon dosyası bulunmalı")
	assert(load("res://assets/skills/oakley_passive_icon.png") is Texture2D, "İkon yüklenebilmeli")
	assert(def.get("passive_icon", "") == "res://assets/skills/oakley_cicek_icon.png", "Pasif ikonu (Çiçek) değişmemeli")
	## 2026-10-18: R artık Hayat Ağacı - metin oakley_tree.gd sabitleriyle tutarlı olmalı (bkz. test_tree_description_matches_constants).


## Eski 2-yük/18sn şarj sistemi tamamen kaldırılmış olmalı - Çiçek artık bir
## tuş yeteneği değil, tamamen otomatik bir pasif.
func test_old_flower_charge_system_removed() -> void:
	var player: Node = _make_oakley_player()
	assert(not player.has_method("_try_oakley_flower"),
		"_try_oakley_flower kaldırılmış olmalı - Çiçek artık pasif")
	assert(not ("oakley_flower_charges" in player),
		"oakley_flower_charges kaldırılmış olmalı - yük sistemi yok")
	player.queue_free()


## Kullanıcı isteği: "2 yük olayı falan yok bunda dolduğu anda oakleyin
## yakınında rasgele yerlere bıraksın" - yeni pasif tek, sabit bir
## zamanlayıcı kullanmalı.
func test_flower_passive_is_automatic_timer() -> void:
	var player: Node = _make_oakley_player()
	assert(player.has_method("_process_oakley_passive"), "_process_oakley_passive olmalı")
	assert(player.has_method("_spawn_oakley_flower_auto"), "_spawn_oakley_flower_auto olmalı")
	assert(is_equal_approx(player._oakley_flower_auto_timer, player.OAKLEY_FLOWER_AUTO_INTERVAL),
		"Zamanlayıcı tam aralıkla başlamalı")
	player._process_oakley_passive(1.0)
	assert(is_equal_approx(player._oakley_flower_auto_timer, player.OAKLEY_FLOWER_AUTO_INTERVAL - 1.0),
		"Zamanlayıcı her karede azalmalı, bulunan: %s" % player._oakley_flower_auto_timer)
	player.queue_free()


## Arı Sürüsü Q'da; 2026-09-25'te sabit alandan takip eden koruyucu sürüye dönüştü (fx_oakley_bee_guard.gd) - süre/bekleme
## ve zehir yükü kuralı (yük başına saldırı gücünün %20'si, 4 sn) aynı kaldı.
func test_bee_swarm_function_unchanged_on_q() -> void:
	var player: Node = _make_oakley_player()
	assert(player.has_method("_skill_oakley_bee_swarm"), "_skill_oakley_bee_swarm hâlâ olmalı (artık Q)")
	assert(is_equal_approx(player.SKILL_TIMING[33]["cooldown"], 20.0),
		"Arı Sürüsü'nün 20sn bekleme süresi Q'ya taşınırken değişmemeli")
	assert(is_equal_approx(player.SKILL_TIMING[33]["duration"], 10.0),
		"Arı Sürüsü'nün 10sn süresi Q'ya taşınırken değişmemeli")
	assert(is_equal_approx(OakleyBeeGuard.DURATION, player.SKILL_TIMING[33]["duration"]), "sürünün süresi yeteneğin süresiyle aynı")
	assert(is_equal_approx(OakleyBeeGuard.DAMAGE_RATIO_PER_STACK, 0.20), "zehir yükü kuralı değişmedi")
	player.queue_free()


## ---------------------------------------------------------------- R: HAYAT AĞACI (madde 266)
## Kullanıcı: "oakleyin ultisini komple değiştirmeyi düşünüyorum" -> prototip C (madde 265) + "ağaç ve aurası %30 büyüsün".
## Eski Koruyucu Büyü testleri kaldırıldı (kod duruyor ama R'ye bağlı değil; yaprak bariyeri görseli
## test_spiritual_skills_and_rewards.gd'de sınanıyor).

## Sahte yaratık: kök/hasar/itme çağrılarını sayar (oakley_tree.gd sadece bu yöntemleri çağırır).
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var roots: Array = []
	var slows: int = 0
	var damage: float = 0.0
	var pushes: int = 0

	func apply_root(duration: float, style: int = 0) -> void:
		roots.append([duration, style])

	func apply_slow(_p: float, _d: float, _b: bool = false) -> void:
		slows += 1

	func take_damage(amount: float, _c: bool = false, _s: float = 0.0, _a: bool = false) -> void:
		damage += amount

	func apply_knockback_distance(_dir: Vector2, _dist: float) -> void:
		pushes += 1


func _fake_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	e.set_meta(preload("res://scripts/vision_fog.gd").VIS_META, 1.0)
	return e


func test_r_is_life_tree_with_tree_lifetime_and_60s_cooldown() -> void:
	var player: Node = _make_oakley_player()
	assert(is_equal_approx(player.SKILL3_TIMING[39]["duration"], OakleyTree.DURATION),
		"R ikonunun 'aktif' süresi ağacın ömrüyle AYNI olmalı (bulunan %s)" % player.SKILL3_TIMING[39]["duration"])
	assert(is_equal_approx(OakleyTree.DURATION, 12.0), "ağaç 12 sn ayakta kalmalı")
	assert(is_equal_approx(player.SKILL3_TIMING[39]["cooldown"], 60.0), "bekleme 60 sn")
	player.queue_free()


## Kullanıcı isteği: "ağaç ve aurası %30 büyüsün" - prototipteki 130x65 elips ve 1:1 ağaç x1,3.
func test_tree_and_aura_are_30_percent_bigger() -> void:
	assert(is_equal_approx(OakleyTree.TREE_SCALE, 1.3), "ağaç ölçeği 1,3")
	assert(is_equal_approx(OakleyTree.ZONE_RX, 130.0 * 1.3) and is_equal_approx(OakleyTree.ZONE_RY, 65.0 * 1.3), "alan 169 x 84,5")
	var tree := OakleyTree.new()
	tree.position = Vector2(100.0, 100.0)
	assert(tree.in_zone(Vector2(100.0 + 168.0, 100.0)) and not tree.in_zone(Vector2(100.0 + 171.0, 100.0)), "yatay kenar 169")
	assert(tree.in_zone(Vector2(100.0, 100.0 + 84.0)) and not tree.in_zone(Vector2(100.0, 100.0 + 86.0)), "dikey kenar 84,5 (2:1)")
	tree.free()


func test_tree_timeline_grows_in_three_sizes_and_sinks() -> void:
	assert(int(OakleyTree.tree_state(0.2)[0]) == -1, "tohum anında ağaç yok")
	var rising: Array = OakleyTree.tree_state(0.55)
	assert(int(rising[0]) == 0 and float(rising[1]) > 0.0 and not bool(rising[2]), "küçük ağaç topraktan çıkar (gölgesiz)")
	assert(int(OakleyTree.tree_state(0.9)[0]) == 1, "orta")
	assert(int(OakleyTree.tree_state(5.0)[0]) == 2, "büyük")
	assert(int(OakleyTree.tree_state(OakleyTree.DURATION + 0.2)[0]) == 1, "solarken orta")
	var sinking: Array = OakleyTree.tree_state(OakleyTree.DURATION + 0.45)
	assert(int(sinking[0]) == 0 and float(sinking[1]) > 0.0, "küçülüp toprağa çekilir")
	assert(int(OakleyTree.tree_state(OakleyTree.LIFE)[0]) == -1, "sonunda ağaç yok")
	assert(OakleyTree.zone_alpha(0.5) == 0.0 and is_equal_approx(OakleyTree.zone_alpha(5.0), 1.0), "alan büyüyünce açılır")
	assert(OakleyTree.zone_alpha(OakleyTree.DURATION + 0.5) == 0.0, "ağaç solarken alan kapanır")


func test_tree_description_matches_constants() -> void:
	var desc: String = str(Characters.get_def(2).get("skill3_desc", ""))
	for part in [
		"%dsn ayakta" % int(OakleyTree.DURATION),
		"saldırı gücünün %%%d'i + azami canın %%%d'i kadar can" % [int(round(OakleyTree.HEAL_AP_RATIO * 100.0)), int(round(OakleyTree.HEAL_MAX_HP_PERCENT * 100.0))],
		"saldırı gücünün %%%d'i kadar mana kalkanı" % int(round(OakleyTree.SHIELD_AP_RATIO * 100.0)),
		"Her %dsn'de kökleri en yakın %d yaratığa" % [int(OakleyTree.ROOT_INTERVAL), OakleyTree.ROOT_TARGETS],
		"saldırı gücünün %%%d'ı kadar hasar verip %dsn yere sabitler" % [int(round(OakleyTree.ROOT_DAMAGE_RATIO * 100.0)), int(OakleyTree.ROOT_DURATION)],
		"%%%d yavaşlar" % int(round(OakleyTree.BOSS_SLOW_PERCENT * 100.0)),
		"%d çiçek" % OakleyTree.FLOWER_OFFSETS.size(),
		"(60sn bekleme)",
	]:
		assert(desc.contains(part), "açıklama '%s' içermeli: %s" % [part, desc])


## Gerçek akış: R -> önüne ağaç (kaster kopyası), Oakley gölgesinde; meyve düşünce can + mana kalkanı; kök dalgası en yakın 3
## yaratığa ağaç kökü stiliyle (1) sabitleme + hasar; açılışta alandaki yaratık itilir; solarken 3 çiçek.
func test_full_cast_plants_tree_that_heals_roots_pushes_and_drops_flowers() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self ## ağaç + efektleri current_scene'e ekleniyor
	var player: Node = _make_oakley_player()
	player.global_position = Vector2(500.0, 500.0)
	player.max_health = 200.0
	player.health = 50.0
	player.item_shield_max = 1000.0 ## ULTİ tarifesi kalkan bedeli ister
	player.item_shield_hp = 1000.0
	player.damage_bonus = 50.0
	player.facing = "right"
	player._activate_skill3()
	assert(player.skill3_state == "active" and is_equal_approx(player.skill3_timer, OakleyTree.DURATION), "R aktif, 12 sn")
	var tree: OakleyTree = null
	for n in get_tree().get_nodes_in_group("oakley_trees"):
		if n.get("caster") == player:
			tree = n
	assert(tree != null, "kasterin gerçek ağacı kurulmalı")
	assert(tree.global_position.x > player.global_position.x, "sağa bakarken ağaç önüne (sağına) ekilir")
	assert(player in tree._players_in_zone(), "Oakley kendi ağacının gölgesinde olmalı")

	var hp_before: float = player.health
	tree._heal_target(player)
	assert(player.health >= hp_before + 50.0 * OakleyTree.HEAL_AP_RATIO + 200.0 * OakleyTree.HEAL_MAX_HP_PERCENT - 0.01,
		"meyve: saldırı gücü x %%15 + azami can x %%1 can (bulunan +%s)" % (player.health - hp_before))

	var near := _fake_enemy(tree.global_position + Vector2(60.0, 0.0))
	var far := _fake_enemy(tree.global_position + Vector2(OakleyTree.ROOT_RANGE + 40.0, 0.0))
	tree._t = OakleyTree.T_LARGE
	tree._on_open()
	assert(near.pushes == 1 and far.pushes == 0, "açılış darbesi sadece alandakini iter")
	tree._root_wave()
	var trails: Array = get_children().filter(func(c: Node) -> bool: return c is OakleyTree.RootTrail)
	assert(trails.size() == 1, "menzildeki tek yaratığa bir kök gider (bulunan %d)" % trails.size())
	(trails[0] as Node)._process(1.0) ## 60 px / 330 px/sn: bir adımda varır
	assert(near.roots.size() == 1 and int(near.roots[0][1]) == OakleyTree.ROOT_STYLE, "ağaç kökü stiliyle sabitlenmeli")
	assert(is_equal_approx(float(near.roots[0][0]), OakleyTree.ROOT_DURATION), "4 sn")
	assert(is_equal_approx(near.damage, 50.0 * OakleyTree.ROOT_DAMAGE_RATIO), "kök hasarı saldırı gücü x %40")
	tree._root_wave()
	assert(get_children().filter(func(c: Node) -> bool: return c is OakleyTree.RootTrail).size() == 1,
		"sabitlenen yaratığa süre bitmeden yeni kök gitmez")

	var flowers_before: int = get_children().filter(func(c: Node) -> bool: return c.get_script() == preload("res://scripts/oakley_flower.gd")).size()
	tree._t = OakleyTree.DURATION + OakleyTree.FLOWER_DELAY
	tree._process(0.01)
	var flowers: int = get_children().filter(func(c: Node) -> bool: return c.get_script() == preload("res://scripts/oakley_flower.gd")).size()
	assert(flowers - flowers_before == 3, "ağaç solarken 3 çiçek bırakmalı (bulunan %d)" % (flowers - flowers_before))
	for c in get_children():
		if c != player:
			c.queue_free()
	get_tree().current_scene = previous_scene
	player.queue_free()


## Kozmetik kopya (diğer istemciler): hedef seçmez/iyileştirmez/çiçek bırakmaz - sadece görsel.
func test_cosmetic_tree_never_applies_effects() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var tree: OakleyTree = OakleyTree.spawn(self, Vector2(300.0, 300.0))
	assert(tree.is_cosmetic(), "caster yoksa kozmetik")
	var e := _fake_enemy(Vector2(330.0, 300.0))
	tree._t = OakleyTree.T_LARGE
	tree._on_open()
	tree._t = OakleyTree.DURATION + OakleyTree.FLOWER_DELAY
	tree._process(0.01)
	assert(e.pushes == 0 and e.roots.is_empty() and e.damage == 0.0, "kozmetik kopya yaratığa dokunmaz")
	for c in get_children():
		c.queue_free()
	get_tree().current_scene = previous_scene


## E (madde 266, kullanıcı: "solarak yok olmasın azalarak yok olsun"): yaratığa sarılan dikenler bırakınca büyümenin TERSİYLE toprağa
## çekilir (eski "break" saydamlaşıyordu); gövde parçaları saydamlaşmaz, adım adım küçülür.
func test_vine_entangle_release_retracts_instead_of_fading() -> void:
	var host := Node2D.new()
	add_child(host)
	var fx: Node2D = (load("res://scenes/fx_oakley_entangle.tscn") as PackedScene).instantiate()
	host.add_child(fx)
	fx.setup(4.0, 10.0)
	fx.release()
	assert(fx._back.animation == &"grow" and fx._back.get_playing_speed() < 0.0, "bırakınca 'grow' TERSİNE oynamalı")
	host.queue_free()


func test_vine_segments_shrink_instead_of_fading() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/oakley_vine_visual.gd")
	assert(not src.contains("\"modulate:a\""), "gövde parçası saydamlaşarak gitmemeli")
	var s := Sprite2D.new()
	add_child(s)
	s.scale = Vector2.ONE * 1.212
	preload("res://scripts/oakley_vine_visual.gd").shrink_away(s, 0.0)
	assert(s.get_tree() != null, "küçülme tween'i kendi düğümünde koşar")
	s.queue_free()
