extends Node

## MAKİNELİ (madde 652): hızlanan 30 mermilik şarjör (gun_mag_math.gd "ramp"), "Kızışan Namlu" özelliği (weapon_traits.gd +
## weapon_traits/kizisan_namlu.gd), kayıt tabloları, doldurma görseli/sesleri (gun_reload_math.gd), namlu kızarması + 2 atışta 1 kovan
## (gun_reload_fx.gd on_shot, makineli_heat_fx.gd). Kullanıcı tasarımı (2026-11-13): "ilk sıkışlarda yavaş başlıyor, giderek hızlanıyor
## şarjör bitene kadar, sonra şarjör yenileniyor ve sıfırlanıyor; geliştirmeler şarjör boyu + ekstra".

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const GunReloadMath := preload("res://scripts/gun_reload_math.gd")
const GunReloadFx := preload("res://scripts/gun_reload_fx.gd")
const WeaponTraitsScript: GDScript = preload("res://scripts/weapon_traits/weapon_traits.gd")
const WeaponCatalogScript: GDScript = preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const ProjectileArt := preload("res://scripts/projectile_art.gd")
const PlayerScript: GDScript = preload("res://scripts/player.gd")
const ChestMenuScript: GDScript = preload("res://scripts/chest_menu.gd")
const MakineliScene: PackedScene = preload("res://scenes/weapon_makineli.tscn")
const W := 0.3 ## sahne fire_rate 0,21 / genel silah yavaşlatması 0,7

const COUNTING_SRC := "extends \"res://scripts/weapon.gd\"\nvar shots: int = 0\nvar fake_target: Node2D = null\n" \
		+ "func _fire_at(_t: Node2D) -> void:\n\tshots += 1\nfunc _get_target_enemy() -> Node2D:\n\treturn fake_target\n"

var _spawned: Array[Node] = []


class FakeOwner extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


class FakeEnemy extends Node2D:
	var is_dead: bool = false


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _weapon() -> Node2D:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	o.global_position = Vector2(9000.0, 9000.0)
	_spawned.append(o)
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = o.global_position + Vector2(80.0, 0.0)
	_spawned.append(e)
	var s := GDScript.new()
	s.source_code = COUNTING_SRC
	s.reload()
	var w: Node2D = MakineliScene.instantiate()
	w.set_script(s)
	w.set("fire_rate", 0.21)
	w.set("fake_target", e)
	o.add_child(w)
	return w


## ---------- kural ----------
func test_ramp_starts_slow_speeds_up_and_keeps_dps() -> void:
	assert(GunMagMath.has_ramp("makineli") and GunMagMath.mag_size("makineli") == 30, "30 mermilik hızlanan şarjör")
	assert(not GunMagMath.has_ramp("tabanca") and not GunMagMath.has_ramp("pompali"), "diğer şarjörler sabit aralıklı")
	var prev: float = INF
	for k in 29:
		var g: float = GunMagMath.ramp_gap("makineli", W, k)
		assert(g <= prev + 0.00001, "aralık hiç uzamaz (k=%d)" % k)
		prev = g
	var first: float = GunMagMath.ramp_gap("makineli", W, 0)
	var last: float = GunMagMath.ramp_gap("makineli", W, 28)
	assert(first > W * 1.5, "ilk atışlar yavaş (%f sn, saniyede %.1f)" % [first, 1.0 / first])
	assert(last < W * 0.3, "son atışlar çok hızlı (%f sn, saniyede %.1f)" % [last, 1.0 / last])
	assert(1.0 / first < 2.5 and 1.0 / last > 11.0, "~2/sn -> ~12/sn (metindeki sayılar)")
	assert(GunMagMath.ramp_at_top("makineli", 23) and not GunMagMath.ramp_at_top("makineli", 10), "23. aralıktan sonra tavan")
	## Dakikadaki hasar: şarjör + doldurma döngüsü = N * W (şarjörsüzle aynı), saldırı hızıyla ölçeklenir.
	for w in [0.2, 0.3, 0.5, 1.0, 2.0]:
		var cyc: float = GunMagMath.cycle_time("makineli", w)
		assert(absf(cyc - 30.0 * w) < 0.0001, "W=%f: döngü %f, şarjörsüz %f" % [w, cyc, 30.0 * w])
	var r: float = GunMagMath.reload_time("makineli", W)
	assert(r > 3.0 and r < 3.8, "doldurma ~3,4 sn (metindeki sayı; bulundu %f)" % r)
	## Çok yüksek saldırı hızında aralık 0,05 sn'nin altına inmez (kare başına bir tetik).
	assert(is_equal_approx(GunMagMath.ramp_gap("makineli", 0.04, 28), GunMagMath.RAMP_MIN_GAP), "en kısa aralık sınırı")
	assert(GunMagMath.ramp_heat("makineli", 0) < 0.01 and GunMagMath.ramp_heat("makineli", 28) > 0.99, "ısı 0 -> 1")


## ---------- gerçek silah ----------
func test_weapon_timer_gap_shrinks_and_reload_resets_it() -> void:
	var w: Node2D = _weapon()
	await get_tree().process_frame
	assert(int(w.get("max_ammo")) == 30 and int(w.get("current_ammo")) == 30, "30 mermiyle başlar")
	var timer: Timer = w.get("fire_timer")
	assert(timer != null)
	w.call("_on_fire_timer_timeout")
	var gap1: float = timer.wait_time
	for i in 24:
		w.call("_on_fire_timer_timeout")
	var gap25: float = timer.wait_time
	assert(int(w.get("shots")) == 25 and int(w.get("current_ammo")) == 5, "tetik başına bir mermi")
	assert(gap1 > 0.4 and gap25 < 0.1, "aralık şarjör içinde kısalır: %f -> %f" % [gap1, gap25])
	assert(bool(w.call("ramp_at_top")), "25. atış tavan hızda")
	for i in 5:
		w.call("_on_fire_timer_timeout")
	assert(bool(w.get("is_reloading")), "30. mermi -> doldurma")
	var wait: float = float(w.call("_effective_fire_wait"))
	w.call("_mag_process", GunMagMath.reload_time("makineli", wait) + 0.001, wait)
	assert(not bool(w.get("is_reloading")) and int(w.get("current_ammo")) == 29, "dolunca hemen ateş")
	assert(int(w.get("_ramp_shots")) == 1 and not bool(w.call("ramp_at_top")), "hızlanma sıfırlandı")
	assert(timer.wait_time > 0.4, "yeni şarjör yine yavaş başlar (%f)" % timer.wait_time)
	_cleanup()


func test_trait_upgrades_grow_magazine_hot_start_and_hot_damage() -> void:
	var w: Node2D = _weapon()
	await get_tree().process_frame
	w.call("set_enchant", {"id": "kizisan_namlu", "ups": [0, 1], "final": false})
	assert(int(w.get("max_ammo")) == 50 and int(w.get("current_ammo")) == 50, "Uzatılmış + Tamburlu: 30 -> 50, yeni yuvalar dolu")
	var r30: float = GunMagMath.reload_time("makineli", W)
	assert(is_equal_approx(GunMagMath.reload_time("makineli", W), r30), "doldurma süresi büyük şarjörle uzamaz (temel 30'dan)")
	## Sıcak Namlu: doldurmadan sonra ilk aralık daha kısa.
	var cold: float = float(w.call("_mag_next_gap", W))
	w.call("set_enchant", {"id": "kizisan_namlu", "ups": [2], "final": false})
	var hot: float = float(w.call("_mag_next_gap", W))
	assert(int(w.get("max_ammo")) == 30, "şarjör geliştirmesi kaldırılınca 30'a döner")
	assert(hot < cold * 0.5, "Sıcak Namlu ısınmış başlar: %f < %f" % [hot, cold])
	## Kızgın Mermiler: yalnız tavan hızdaki mermi +%25.
	w.call("set_enchant", {"id": "kizisan_namlu", "ups": [3], "final": false})
	var b: Node = w.get("enchant_behavior")
	w.set("_ramp_shots", 2)
	assert(is_equal_approx(float(b.call("damage_extra", 100.0, null)), 100.0), "yavaşken ek hasar yok")
	w.set("_ramp_shots", 26)
	assert(is_equal_approx(float(b.call("damage_extra", 100.0, null)), 125.0), "tavan hızda +%25")
	## Final: tavan daha hızlı + tavandaki mermi 1 düşman deler (tam hasar).
	w.call("set_enchant", {"id": "kizisan_namlu", "ups": [0, 1, 2, 3], "final": true})
	w.set("_ramp_shots", 40)
	var fast: float = float(w.call("_mag_next_gap", W))
	assert(fast < GunMagMath.ramp_gap("makineli", W, 40) * 0.8, "Kurşun Fırtınası tavanı %33 hızlı")
	var proj := Area2D.new()
	proj.set_script(load("res://scripts/projectile.gd"))
	var pierce0: int = int(proj.get("pierce_count"))
	b = w.get("enchant_behavior")
	b.call("projectile_extra", proj, null, false)
	assert(int(proj.get("pierce_count")) == pierce0 + 1 and is_equal_approx(float(proj.get("pierce_damage_percent")), 1.0), "tavanda 1 delme, tam hasar")
	proj.free()
	_cleanup()


## ---------- tanım + kayıt ----------
func test_trait_definition_is_complete() -> void:
	assert(WeaponTraitsScript.trait_of("makineli") == "kizisan_namlu", "Makineli'nin özelliği Kızışan Namlu")
	var d: Dictionary = WeaponTraitsScript.DEFS["kizisan_namlu"]
	assert(d["weapons"] == ["makineli"] and str(d["name"]) == "Kızışan Namlu", "tanım silaha ve ada bağlı")
	assert((d["upgrades"] as Array).size() == 4 and d.has("final"), "4 geliştirme + final")
	assert(ResourceLoader.exists(WeaponTraitsScript.script_path("kizisan_namlu")), "davranış scripti var")


func test_registered_in_every_table() -> void:
	assert(WeaponCatalogScript.KEYS.has("makineli"), "katalogda")
	assert(WeaponCatalogScript.NAMES.has("makineli") and WeaponCatalogScript.ICONS.has("makineli") and WeaponCatalogScript.DESCRIPTIONS.has("makineli"), "katalog tabloları")
	assert(WeaponCatalogScript.MENU_ICONS.has("makineli"), "menü ikonu")
	assert(PlayerScript.WEAPON_SCENES_BY_KEY.has("makineli"), "oyuncu sahne tablosu")
	assert(ChestMenuScript.WEAPON_KEYS.has("makineli") and ChestMenuScript.WEAPON_COST_BASE.has("makineli"), "sandık menüsü")
	assert(WeaponTierArt.has_art("makineli") and WeaponTierArt.key_from_scene("res://scenes/weapon_makineli.tscn") == "makineli", "sabit sanat + sahne anahtarı")
	assert(WeaponTierArt.texture("makineli") != null and WeaponTierArt.texture("makineli").get_size() == Vector2(64, 64), "64x64 ikon")
	assert(ProjectileArt.has_art("makineli_projectile"), "mermi sanatı (Tabanca'nınki)")
	var rp: GDScript = load("res://scripts/remote_player.gd")
	assert((rp.get_script_constant_map()["WEAPON_SCENES"] as Dictionary).has("makineli"), "uzak oyuncu sahne tablosu")


## ---------- doldurma + atış görseli ----------
func test_reload_timeline_parts_and_sounds() -> void:
	assert(GunReloadMath.has_reload("makineli"))
	var L: float = GunReloadMath.length("makineli")
	for u in [0.0, L]:
		var p: Dictionary = GunReloadMath.pose("makineli", u)
		assert(absf(float(p["tilt"])) < 0.001 and absf(float(p["kick"])) < 0.001, "uçlarda nötr poz")
	assert(GunReloadMath.parts("makineli", 0.6)["tex"] == &"makineli_nomag", "şarjör yokken gövde şarjörsüz")
	var out_p: Array = GunReloadMath.parts("makineli", 0.38)["back"]
	assert(out_p.size() == 1 and (out_p[0][1] as Vector2).y > GunReloadMath.MAK_MAG_AT.y + 5.0, "boş şarjör aşağı kayıyor")
	var in_p: Array = GunReloadMath.parts("makineli", 1.0)["back"]
	assert(in_p.size() == 1 and (in_p[0][1] as Vector2).y > GunReloadMath.MAK_MAG_AT.y, "yeni şarjör alttan geliyor")
	assert(GunReloadMath.parts("makineli", 1.5)["tex"] == &"", "oturunca gövde normal")
	assert(float(GunReloadMath.pose("makineli", 1.95 + 0.03)["kick"]) > 1.0, "kurma kolu ileri: geri tepme")
	assert(int(GunReloadMath.drop_piece("makineli")["row"]) == 2, "düşen şarjör sayfanın 3. satırı")
	var snd: Array = GunReloadMath.sounds("makineli")
	assert(snd.size() == 4, "çıkar / tak / geri / ileri")
	for s in snd:
		assert(GunReloadFx.SOUNDS.has(StringName(s[0])), "%s sesi yüklü" % s[0])
	assert(ResourceLoader.exists("res://assets/audio/makineli_atis.wav"), "atış sesi")
	var tex: Texture2D = load("res://assets/fx/gun/reload/mags_drop.png")
	assert(tex.get_size() == Vector2(24 * 8, 24 * 3), "düşen şarjör sayfası 3 satır 24 px")


func test_shot_heats_barrel_and_ejects_every_other_casing() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var icon := Sprite2D.new()
	icon.texture = WeaponTierArt.texture("makineli")
	add_child(icon)
	_spawned.append(icon)
	for i in 26:
		GunReloadFx.on_shot(icon, "makineli", Vector2.RIGHT, null)
	var heat: Node = icon.get_node_or_null("MakineliHeat")
	assert(heat != null and int(heat.get("shots")) == 26 and float(heat.get("heat")) > 0.95, "26 atışta namlu kızgın")
	assert(int(icon.get_meta(&"casing_n")) == 26, "kovan sayacı")
	GunReloadFx.begin(self, icon, "makineli", 0.5, null)
	assert(int(heat.get("shots")) == 0 and bool(heat.get("_cooling_fast")), "doldurmada soğur")
	_cleanup()
	for c in get_children():
		if c.name.begins_with("GunReloadFx"):
			c.free()


## Kullanıcı 2026-11-13 "silahın ucundaki patlama tuhaf": ateş + mermi ÇİZİLİ namlu ucundan (orta hattan değil), kendi küçük ateşi, yana dönük değil.
func test_muzzle_flash_sits_on_the_barrel_tip() -> void:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	_spawned.append(o)
	var w: Node2D = MakineliScene.instantiate() ## gerçek sahne (betik değiştirilince dışa aktarılan ayarlar sıfırlanır)
	o.add_child(w)
	await get_tree().process_frame
	assert(bool(w.get("fire_from_barrel_tip")), "namlu ucundan ateş")
	assert(is_zero_approx(float(w.get("muzzle_flash_rotation_offset"))), "ateş namlu yönünde (Tabanca'nın 90 derecesi değil)")
	assert((w.get("muzzle_flash_scene") as PackedScene).resource_path == "res://scenes/fx_makineli_muzzle.tscn", "kendi ateşi")
	var tip: Vector2 = w.call("_barrel_tip_global")
	var icon: Sprite2D = w.get("icon_sprite")
	var local: Vector2 = icon.global_transform.affine_inverse() * tip
	assert(local.y < -8.0 and local.y > -16.0, "uç namlu satırında (doku merkezinin ~12 px üstü), bulundu %s" % local)
	assert(local.x > 18.0, "uç namlunun önünde, bulundu %s" % local)
	_cleanup()
