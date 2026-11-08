extends Node

## POMPALI TÜFEK (madde 448): saçma düzeni (pompali_math.gd), "Dip Atış" tanımı + davranışı, kayıt tabloları, saçma mermisi.
## Kullanıcı isteği (2026-11-07): "pompalı tüfek ekle, mermi saçma özelliği olan efsun" -> Dip Atış (mesafeye göre isabet eden koni).

const PompaliMath := preload("res://scripts/pompali_math.gd")
const WeaponTraitsScript: GDScript = preload("res://scripts/weapon_traits/weapon_traits.gd")
const WeaponCatalogScript: GDScript = preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const ProjectileArt := preload("res://scripts/projectile_art.gd")
const WeaponScene: PackedScene = preload("res://scenes/weapon_pompali.tscn")
const PlayerScript: GDScript = preload("res://scripts/player.gd")
const ChestMenuScript: GDScript = preload("res://scripts/chest_menu.gd")


func test_angles_fill_the_cone_symmetrically() -> void:
	var a: Array = PompaliMath.angles(6, 24.0)
	assert(a.size() == 6, "6 saçma 6 açı")
	assert(is_equal_approx(float(a[0]), -deg_to_rad(12.0)) and is_equal_approx(float(a[5]), deg_to_rad(12.0)), "koni her yana 12 derece")
	for i in 3:
		assert(is_equal_approx(float(a[i]), -float(a[5 - i])), "açılar sıfıra göre simetrik")
	assert(PompaliMath.angles(1, 24.0) == [0.0], "tek saçma doğrudan hedefe")


func test_extra_angles_leave_the_main_shot_out() -> void:
	for n in [2, 5, 6, 8, 12]:
		var extras: Array = PompaliMath.extra_angles(n, 24.0)
		assert(extras.size() == n - 1, "%d saçma: asıl atış dışında %d ek (bulundu %d)" % [n, n - 1, extras.size()])
	## Tek sayıda saçmada ortadaki (tam 0) asıl atıştır: ekler arasında 0 yok.
	for a in PompaliMath.extra_angles(5, 24.0):
		assert(absf(float(a)) > 0.001, "ortadaki saçma ekler arasında olmamalı")
	## Sapma: her açı jitter payının dışına çıkmaz.
	var j: float = deg_to_rad(PompaliMath.JITTER_DEG)
	var base: Array = PompaliMath.extra_angles(6, 24.0)
	for k in 20:
		var noisy: Array = PompaliMath.extra_angles(6, 24.0, PompaliMath.JITTER_DEG)
		for i in noisy.size():
			assert(absf(float(noisy[i]) - float(base[i])) <= j + 0.0001, "sapma sınırı aşıldı")


func test_dip_atis_closer_hits_more_pellets() -> void:
	var r: float = 14.0 ## yaratık gövdesi (~10) + saçma yarıçapı (sahne 9 x sahip ölçeği 0,5)
	var near: int = PompaliMath.pellets_on_target(6, PompaliMath.CONE_DEG, 90.0, r)
	var mid: int = PompaliMath.pellets_on_target(6, PompaliMath.CONE_DEG, 170.0, r)
	var far: int = PompaliMath.pellets_on_target(6, PompaliMath.CONE_DEG, 300.0, r)
	## Kullanıcı 2026-11-07 "çok az vuruyor": yakında hepsi, ORTA mesafede de çoğu (ortaya yoğun koni).
	assert(near == 6, "yakında (90 px) 6 saçmanın hepsi isabet eder (bulundu %d)" % near)
	assert(mid == 4, "orta mesafede (170 px) 4 saçma isabet eder (bulundu %d)" % mid)
	assert(far == 2, "menzil ucunda (300 px) asıl atış + bir saçma (bulundu %d)" % far)
	## Sıkı Demet uzakta daha çok saçma vurdurur.
	var tight: int = PompaliMath.pellets_on_target(6, PompaliMath.CONE_DEG * 0.65, 300.0, r)
	assert(tight > far, "Sıkı Demet uzakta daha çok isabet: %d > %d" % [tight, far])


func test_trait_definition_is_complete() -> void:
	assert(WeaponTraitsScript.trait_of("pompali") == "dip_atis", "Pompalı Tüfek'in özelliği Dip Atış")
	var d: Dictionary = WeaponTraitsScript.DEFS["dip_atis"]
	assert(d["weapons"] == ["pompali"] and str(d["name"]) == "Dip Atış", "tanım silaha ve ada bağlı")
	assert((d["upgrades"] as Array).size() == 4 and d.has("final"), "4 geliştirme + final")
	assert(ResourceLoader.exists(WeaponTraitsScript.script_path("dip_atis")), "davranış scripti var")
	var set_base: Dictionary = (d["base"] as Dictionary)["set"]
	assert(int(set_base["pellets"]) == 6 and int(set_base["full_every"]) == 0, "temel: 6 saçma, Tam Yük kapalı")


func test_registered_in_every_table() -> void:
	assert(WeaponCatalogScript.KEYS.has("pompali"), "katalogda")
	assert(WeaponCatalogScript.NAMES.has("pompali") and WeaponCatalogScript.ICONS.has("pompali") and WeaponCatalogScript.DESCRIPTIONS.has("pompali"), "katalog tabloları")
	assert(PlayerScript.WEAPON_SCENES_BY_KEY.has("pompali"), "oyuncu sahne tablosu")
	assert(ChestMenuScript.WEAPON_KEYS.has("pompali") and ChestMenuScript.WEAPON_COST_BASE.has("pompali"), "sandık menüsü")
	assert(WeaponTierArt.has_art("pompali") and WeaponTierArt.key_from_scene("res://scenes/weapon_pompali.tscn") == "pompali", "sabit sanat + sahne anahtarı")
	assert(WeaponTierArt.texture("pompali") != null, "ikon dokusu yükleniyor")
	assert(ProjectileArt.has_art("pompali_projectile"), "saçma mermisi sanatı")
	assert(ResourceLoader.exists("res://assets/weapons/mermi/pompali_govde.png"), "saçma dokusu")


func test_pellet_projectile_loads_and_has_no_trail() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var p: Node2D = (load("res://scenes/pompali_projectile.tscn") as PackedScene).instantiate()
	p.set("impact_sounds", [] as Array[AudioStream])
	get_tree().current_scene.add_child(p)
	assert(p.get("_art_body") != null, "gövde sanatı uygulandı")
	assert(p.get("_trail") == null, "saçmada iz şeridi yok")
	assert(float(p.get("max_travel")) > 330.0, "saçma menzilin biraz ötesinde söner")
	p.free()


func test_shotgun_has_pump_magazine_and_red_shell() -> void:
	var GunMagMath := preload("res://scripts/gun_mag_math.gd")
	assert(GunMagMath.has_mag("pompali") and GunMagMath.mag_size("pompali") == 5, "5 fişeklik pompa")
	var c: Dictionary = GunMagMath.cfg("pompali")
	assert(int(c["casing_row"]) == 4 and int(c["mag_row"]) < 0, "kırmızı fişek kovanı, düşen şarjör yok")
	var tex: Texture2D = load("res://assets/fx/gun/casings.png")
	assert(tex.get_height() == 12 * 5, "kovan sayfası 5 satır")
	var w: Node2D = WeaponScene.instantiate()
	assert(float(w.get("attack_range")) >= 330.0 and is_equal_approx(float(w.get("card_damage_bonus_ratio")), 0.34), "menzil 330, saçma %34")
	assert(str((w.get("muzzle_flash_scene") as PackedScene).resource_path).ends_with("fx_pompali_muzzle.tscn"), "kendi namlu patlaması")
	w.free()


func test_fire_pellets_spawns_one_projectile_per_angle_with_shot_damage() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var holder := Node2D.new()
	get_tree().current_scene.add_child(holder)
	var w: Node2D = WeaponScene.instantiate()
	holder.add_child(w)
	var target := Node2D.new()
	target.global_position = Vector2(80, 0)
	get_tree().current_scene.add_child(target)
	w.set("_last_shot_damage", 7.5)
	w.set("_last_shot_crit", true)
	w.set("_last_shot_shield_pen", 0.2)
	var before: Array = _projectiles()
	w.call("fire_pellets", target, PompaliMath.extra_angles(6, 24.0))
	var spawned: Array = []
	for pr in _projectiles():
		if not before.has(pr):
			spawned.append(pr)
	assert(spawned.size() == 5, "6 saçmanın 5'i ek mermi olarak çıkar (bulundu %d)" % spawned.size())
	var dirs: Array = []
	for pr in spawned:
		assert(is_equal_approx(float(pr.get("damage")), 7.5) and pr.get("is_crit") == true, "hasar + kritik asıl atıştan")
		assert(is_equal_approx(float(pr.get("shield_pen_percent")), 0.2), "kalkan delme asıl atıştan")
		assert(pr.get("source_weapon") == w, "kaynak silah bağlı (isabet kancaları)")
		dirs.append(snappedf((pr.get("direction") as Vector2).angle(), 0.001))
	for i in dirs.size():
		for k in range(i + 1, dirs.size()):
			assert(dirs[i] != dirs[k], "saçmalar farklı yönlere gider")
	## Hasarsız (hiç atış yapılmamış) silah saçma çıkarmaz.
	w.set("_last_shot_damage", 0.0)
	var n0: int = _projectiles().size()
	w.call("fire_pellets", target, [0.1, -0.1])
	assert(_projectiles().size() == n0, "atış yapılmadan saçma çıkmaz")
	for pr in _projectiles():
		if not before.has(pr):
			pr.free()
	holder.free()
	target.free()


## Kullanıcı 2026-11-07: "8 saçma bir düşmana vurunca her saçmanın hasarı ayrı bir hasar gibi görünmeli" - madde 429 birleştirmesi
## saçmalarda kapalı (damage_numbers.gd separate_hits), hedef başına canlı sayı sınırı da saçma sayısını yutmaz.
func test_pellet_hits_show_separate_damage_numbers() -> void:
	var DnScript := preload("res://scripts/damage_numbers.gd")
	var dn := Node2D.new()
	dn.set_script(DnScript)
	add_child(dn)
	dn.set_process(false)
	var merged: Array[int] = []
	for i in 8:
		dn.spawn_hit(null, Vector2.ZERO, 7, DnScript.KIND_HIT, merged, 5, 100.0)
	assert(merged.size() == 1, "normal vuruşlar birleşir (madde 429): %d" % merged.size())
	var sep: Array[int] = []
	DnScript.separate_hits = true
	for i in 8:
		dn.spawn_hit(null, Vector2(300, 0), 7, DnScript.KIND_HIT, sep, 5, 100.0)
	DnScript.separate_hits = false
	assert(sep.size() == 8, "8 saçma = 8 ayrı sayı (bulundu %d)" % sep.size())
	for id in sep:
		assert(int((dn.get("_entries") as Dictionary)[id].value) == 7, "her sayı kendi saçmasının hasarı")
	assert(DnScript.separate_hits == false, "bayrak kapalı kalır")
	## Saçma mermisi bayrağı taşır ve isabetten sonra kapatır.
	var p: Node = (load("res://scenes/pompali_projectile.tscn") as PackedScene).instantiate()
	assert(bool(p.get("separate_damage_numbers")), "saçma sahnesi ayrı sayı ister")
	p.free()
	dn.free()


## Kullanıcı 2026-11-08: "pompalı tüfeğin çekiş sesi de vardı attığım seste, ateşledikten sonra hemen o oynatılıyordu" - dosyadaki
## pompa tıkları ayrı sese ayrıldı (tools/gen_pompali_ses.py), AttackSound atışı hemen + pompayı gecikmeyle çalar ve ikisini de
## ağ zinciri adımı olarak döner (network_manager "weapon_sound" chain).
func test_shot_plays_fire_then_pump_and_returns_both_for_network() -> void:
	var w: Node2D = WeaponScene.instantiate()
	add_child(w)
	var snd: Node = w.get_node_or_null("AttackSound")
	assert(snd != null and snd.has_method("play_swing") and snd.has_method("set_rim_muffled"), "atış + pompa çalıcısı")
	var steps: Variant = snd.play_swing()
	assert(steps is Array and (steps as Array).size() == 2, "iki adım: atış + pompa (%s)" % str(steps))
	var fire: Dictionary = (steps as Array)[0]
	var pump: Dictionary = (steps as Array)[1]
	assert(str(fire["sound_path"]).ends_with("pompali_atis.wav") and float(fire["delay"]) == 0.0, "atış hemen")
	assert(str(pump["sound_path"]).ends_with("pompali_pompa.wav") and float(pump["delay"]) >= 0.1 and float(pump["delay"]) <= 0.5,
		"pompa atıştan hemen sonra (gecikme %.2f)" % float(pump["delay"]))
	var pump_stream: AudioStream = load(str(pump["sound_path"]))
	assert(pump_stream != null and pump_stream.get_length() > 0.15 and pump_stream.get_length() < 0.6, "pompa kısa bir çekiş")
	## Gecikme dolmadan gelen ikinci atış: eski pompa çalmaz, yalnız sonuncusu (üst üste binme yok).
	assert(int(snd.get("_shot")) == 1)
	snd.play_swing()
	snd.call("_play_pump", 1, 1.0)
	assert(not (snd.get("_pump") as AudioStreamPlayer2D).playing, "eski atışın pompası atlanır")
	snd.call("_play_pump", 2, 1.0)
	assert((snd.get("_pump") as AudioStreamPlayer2D).playing, "son atışın pompası çalar")
	w.free()


func _projectiles() -> Array:
	var out: Array = []
	for c in get_tree().current_scene.get_children():
		if c is Area2D and c.get("source_weapon") != null:
			out.append(c)
	return out
