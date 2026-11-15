extends Node

## Tabanca + Tüfek ŞARJÖR (madde 296; kullanıcı 2026-10-19: "şarjör mekaniği silahın mevcut dps'ini düşürmeyecek ... 1 dakikada
## o kadar hasar verebilmeli", "saldırı hızı şarjör doldurma hızını arttıracak"). Kural gun_mag_math.gd, gerçek silah weapon.gd,
## görsel gun_reload_fx.gd (kaster + kukla), kovan shell_casing_fx.gd.

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const GunReloadFx := preload("res://scripts/gun_reload_fx.gd")
const GunReloadMath := preload("res://scripts/gun_reload_math.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const AllyFxDensity := preload("res://scripts/ally_fx_density.gd")
const ShellCasingFx := preload("res://scripts/shell_casing_fx.gd")
const TabancaScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const TufekScene: PackedScene = preload("res://scenes/weapon_tufek.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

## Gerçek weapon.gd + sayaç: atış (_fire_at) sayılır ve hiçbir şey çıkarmaz, hedef sabit sahte düşman.
const COUNTING_SRC := "extends \"res://scripts/weapon.gd\"\nvar shots: int = 0\nvar fake_target: Node2D = null\n" \
		+ "func _fire_at(_t: Node2D) -> void:\n\tshots += 1\nfunc _get_target_enemy() -> Node2D:\n\treturn fake_target\n"

var _spawned: Array[Node] = []


class FakeOwner extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


class FakeEnemy extends Node2D:
	var is_dead: bool = false


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _counting_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = COUNTING_SRC
	s.reload()
	return s


func _make_owner(pos: Vector2) -> FakeOwner:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	o.global_position = pos
	_track(o)
	return o


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_track(e)
	return e


## Sayaçlı gerçek silah: sahne (FireTimer/Icon + sahne yolu -> şarjör anahtarı) + sayaç betiği, hızlı atış (testi kısa tutmak için).
func _counting_weapon(scene: PackedScene, owner_node: Node2D, target: Node2D, rate: float) -> Node2D:
	var w: Node2D = scene.instantiate()
	w.set_script(_counting_script())
	w.set("fire_rate", rate)
	w.set("fake_target", target)
	owner_node.add_child(w)
	return w


## ---------- saf kural ----------
func test_cycle_matches_old_rate_at_every_attack_speed() -> void:
	for key in ["tabanca", "tufek"]:
		var n: int = GunMagMath.mag_size(key)
		assert(n >= 4, "%s şarjörlü" % key)
		for w in [0.12, 0.3, 0.75, 1.349, 1.857, 3.0]:
			var cyc: float = GunMagMath.cycle_time(key, w)
			assert(absf(cyc - float(n) * w) < 0.0001, "%s W=%f: döngü %f, şarjörsüz %f" % [key, w, cyc, float(n) * w])
			assert(GunMagMath.burst_wait(key, w) < w, "şarjör içinde daha sık ateş")
			assert(GunMagMath.reload_time(key, w) > w, "doldurma bir atış aralığından uzun")
		## saldırı hızı x2 -> doldurma yarıya
		assert(absf(GunMagMath.reload_time(key, 0.5) * 2.0 - GunMagMath.reload_time(key, 1.0)) < 0.0001, "doldurma saldırı hızıyla ölçeklenir")
	assert(not GunMagMath.has_mag("yay") and GunMagMath.mag_size("uzunkilic") == 0, "diğer silahlar şarjörsüz")


func test_reload_pose_is_neutral_at_both_ends() -> void:
	for key in ["tabanca", "tufek", "pompali"]:
		var L: float = GunReloadMath.length(key)
		for u in [0.0, L]:
			var p: Dictionary = GunReloadMath.pose(key, u)
			assert(absf(float(p["tilt"])) < 0.001 and absf(float(p["lift"])) < 0.001 and absf(float(p["kick"])) < 0.001, "%s u=%f nötr: %s" % [key, u, str(p)])
			assert(absf(float(p["sx"]) - 1.0) < 0.001 and absf(float(p["sy"]) - 1.0) < 0.001, "ölçek nötr")
		assert(float(GunReloadMath.pose(key, L * 0.4)["tilt"]) > 0.3, "%s: ortada namlu kalkık" % key)
	assert(float(GunReloadMath.pose("tabanca", 1.545 + 0.03)["kick"]) > 1.0, "Luger kolu çakılınca geri kayar")
	assert(float(GunReloadMath.pose("tufek", 1.955 + 0.03)["kick"]) > 1.0, "sürgü ileri itilince geri kayar")


## 2026-11-13 (kullanıcı: "şarjör doldururken mermi veya şarjör çıkarılıp eklenmiyor"): parçalar + ses anları.
func test_reload_parts_and_sound_moments() -> void:
	## Tabanca: şarjör kabzadan aşağı çıkar (arkada), yenisi aşağıdan gelip oturur, kol kalkar (gövde açık sürüm)
	var out_p: Array = GunReloadMath.parts("tabanca", 0.30)["back"]
	assert(out_p.size() == 1 and (out_p[0][1] as Vector2).y > GunReloadMath.TAB_MAG_AT.y + 5.0, "boş şarjör kabzadan çıkıyor")
	var in_p: Array = GunReloadMath.parts("tabanca", 0.75)["back"]
	assert(in_p.size() == 1 and (in_p[0][1] as Vector2).y > GunReloadMath.TAB_MAG_AT.y, "yeni şarjör aşağıdan geliyor")
	assert((GunReloadMath.parts("tabanca", 0.87)["sparks"] as Array).size() == 3, "oturunca kıvılcım")
	var tg: Dictionary = GunReloadMath.parts("tabanca", 1.35)
	assert(tg["tex"] == &"tabanca_toggle_open" and (tg["front"] as Array).size() == 1, "Luger kolu kalkık")
	assert(GunReloadMath.parts("tabanca", 1.7)["tex"] == &"" and (GunReloadMath.parts("tabanca", 1.7)["back"] as Array).is_empty(), "sonda gövde normal")
	## Tüfek: şarjör çıkınca gövde şarjörsüz, sürgü açıkken pirinç mermi
	assert(GunReloadMath.parts("tufek", 0.9)["tex"] == &"tufek_nomag", "şarjör yokken gövde şarjörsüz")
	var bolt: Dictionary = GunReloadMath.parts("tufek", 1.8)
	assert(bolt["tex"] == &"tufek_bolt_open" and (bolt["front"] as Array).size() == 1, "sürgü açık, mermi görünür")
	## Pompalı: eksik fişek kadar fişek + ses, son fişekten sonra pompa
	for n in [1, 3, 5, 7]:
		var snd: Array = GunReloadMath.sounds("pompali", n)
		assert(snd.filter(func(s: Array) -> bool: return s[0] == "pompali_shell").size() == n, "%d fişek sesi" % n)
		assert(snd[-1][0] == "pompali_pump", "sonda pompa")
	assert(GunReloadMath.length("pompali", 1) < GunReloadMath.length("pompali", 5), "az fişek kısa çizelge")
	assert(is_equal_approx(GunReloadMath.length("pompali", 5), 2.34), "5 fişek = eski temel doldurma")
	assert(GunReloadMath.parts("pompali", 2.0, 5)["tex"] == &"pompali_nofore", "pompa çekilince kundak ayrı")
	## sesler sıralı, çizelge içinde; anahtar an olaya oturacak şekilde önce başlar, hızlanınca daha da önce
	for key in ["tabanca", "tufek", "pompali"]:
		var prev: float = -1.0
		for s in GunReloadMath.sounds(key):
			assert(float(s[1]) >= prev and float(s[1]) < GunReloadMath.length(key), "%s ses sırası/aralığı" % key)
			prev = float(s[1])
			assert(ResourceLoader.exists("res://assets/audio/gun/reload/%s.wav" % s[0]), "ses dosyası var: %s" % s[0])
	assert(is_equal_approx(GunReloadMath.sound_start_u(0.86, 0.235, 1.0), 0.86 - 0.235), "temel hızda ofset aynen")
	assert(GunReloadMath.sound_start_u(0.86, 0.235, 2.0) < 0.86 - 0.235, "hızlı doldurmada daha önce başlar (u biriminde)")
	assert(GunReloadMath.drop_u("pompali") < 0.0 and GunReloadMath.drop_u("tabanca") > 0.0, "pompalıda şarjör düşmez")


## ---------- gerçek silah ----------
func test_extra_shots_do_not_spend_ammo_and_last_round_reloads_then_fires() -> void:
	var o: FakeOwner = _make_owner(Vector2(7000.0, 7000.0))
	var e: FakeEnemy = _make_enemy(o.global_position + Vector2(80.0, 0.0))
	var w: Node2D = _counting_weapon(TabancaScene, o, e, 0.9444)
	assert(int(w.get("max_ammo")) == 6 and int(w.get("current_ammo")) == 6, "tabanca 6'lık şarjörle başlar")
	w.call("_fire_at", e) ## ek atış yolu (Elara R / Kaos Kitabı / özellik ek mermisi hep _fire_at)
	assert(int(w.get("current_ammo")) == 6, "ek atış şarjör yemez")
	w.call("_on_fire_timer_timeout")
	assert(int(w.get("current_ammo")) == 5 and int(w.get("shots")) == 2, "tetik bir mermi")
	w.set("current_ammo", 1)
	w.call("_on_fire_timer_timeout")
	assert(bool(w.get("is_reloading")) and int(w.get("current_ammo")) == 0, "son mermi -> doldurma")
	var shots_before: int = int(w.get("shots"))
	w.call("_on_fire_timer_timeout")
	assert(int(w.get("shots")) == shots_before, "dolarken ateş yok")
	var wait: float = float(w.call("_effective_fire_wait"))
	w.call("_mag_process", GunMagMath.reload_time("tabanca", wait) + 0.001, wait)
	assert(not bool(w.get("is_reloading")), "doldurma bitti")
	assert(int(w.get("shots")) == shots_before + 1 and int(w.get("current_ammo")) == 5, "biter bitmez hedefe ateş (döngü N*W kalır)")
	_cleanup()


## Asıl istek: dakikadaki hasar (atış sayısı) şarjörlü ve şarjörsüz AYNI. Dört silah aynı anda gerçek zamanlayıcıyla koşar (hızlı atış).
func test_real_weapons_fire_as_many_shots_as_without_magazine() -> void:
	var rows: Array = []
	var i: int = 0
	for scene in [TabancaScene, TufekScene]:
		for use_mag in [true, false]:
			var o: FakeOwner = _make_owner(Vector2(7000.0 + 600.0 * i, 7000.0))
			var e: FakeEnemy = _make_enemy(o.global_position + Vector2(80.0, 0.0))
			var w: Node2D = _counting_weapon(scene, o, e, 0.06)
			if not use_mag:
				w.set("max_ammo", 0)
			rows.append({"w": w, "mag": use_mag, "reloads": 0, "was": false})
			i += 1
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
		for r in rows:
			var rl: bool = bool((r["w"] as Node).get("is_reloading"))
			if rl and not bool(r["was"]):
				r["reloads"] = int(r["reloads"]) + 1
			r["was"] = rl
	for k in 2:
		var with_mag: Dictionary = rows[k * 2]
		var without: Dictionary = rows[k * 2 + 1]
		var wm: Node2D = with_mag["w"]
		var n: int = int(wm.get("max_ammo"))
		var a: int = int(wm.get("shots"))
		var b: int = int((without["w"] as Node).get("shots"))
		var key: String = String(wm.get("_mag_key"))
		print("GUN_DPS %s sarjorlu=%d sarjorsuz=%d doldurma=%d N=%d" % [key, a, b, int(with_mag["reloads"]), n])
		assert(int(with_mag["reloads"]) >= 5, "%s: şarjör gerçekten devrede (%d doldurma)" % [key, int(with_mag["reloads"])])
		assert(b > 40, "%s: şarjörsüz silah ateş etti (%d)" % [key, b])
		## kısmi döngü farkı: şarjörlü silah atışlarını öne alır (en çok N), uzun vadede eşit
		assert(a >= b - 1 and a <= b + n, "%s: şarjörlü %d atış, şarjörsüz %d (N=%d)" % [key, a, b, n])
	_cleanup()


func test_reload_drives_icon_pose_and_restores_it() -> void:
	var o: FakeOwner = _make_owner(Vector2(7000.0, 7400.0))
	var e: FakeEnemy = _make_enemy(o.global_position + Vector2(80.0, 0.0))
	var w: Node2D = _counting_weapon(TufekScene, o, e, 0.9444)
	await get_tree().process_frame
	var icon: Sprite2D = w.get("icon_sprite")
	w.set("current_ammo", 1)
	w.call("_on_fire_timer_timeout")
	assert(icon.has_meta(GunReloadFx.META), "doldurma sürücüsü ikonda")
	assert(get_tree().current_scene.get_node_or_null("GunReloadPips") == null, "silahın üstünde mermi göstergesi YOK (kullanıcı 2026-10-19)")
	var start_rot: float = icon.rotation
	w.set("_reload_progress", 0.45)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(absf(wrapf(icon.rotation - start_rot, -PI, PI)) > 0.4, "doldururken namlu kalkık (%f)" % (icon.rotation - start_rot))
	## 2026-11-13: şarjör çıkmışken gövde şarjörsüz dokuda, parça katmanları ikonda, boş şarjör yere düştü
	var base_tex: Texture2D = WeaponTierArt.texture("tufek")
	assert(icon.texture == GunReloadFx.PIECES[&"tufek_nomag"], "şarjör çıkınca gövde şarjörsüz")
	assert(icon.get_node_or_null("ReloadBack") != null and icon.get_node_or_null("ReloadFront") != null, "parça katmanları ikonda")
	assert((icon.get_node("ReloadBack") as CanvasItem).show_behind_parent, "şarjör gövdenin arkasında (içinde kalan kısım gizli)")
	var wait: float = float(w.call("_effective_fire_wait"))
	w.call("_mag_process", GunMagMath.reload_time("tufek", wait), wait)
	assert(not icon.has_meta(GunReloadFx.META), "bitince sürücü bıraktı")
	assert(icon.position.is_equal_approx(Vector2.ZERO), "ikon dinlenme konumunda")
	assert(icon.texture == base_tex, "bitince asıl çizim geri geldi")
	await get_tree().process_frame
	assert(icon.get_node_or_null("ReloadBack") == null, "katmanlar silindi")
	## sahip ölünce yarıdaki doldurma iptal, poz geri
	w.set("current_ammo", 1)
	w.call("_on_fire_timer_timeout")
	assert(bool(w.get("is_reloading")))
	o.is_dead = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not bool(w.get("is_reloading")) and not icon.has_meta(GunReloadFx.META), "ölünce doldurma iptal")
	_cleanup()


func test_casing_ejects_falls_to_feet_and_lands_on_ground_layer() -> void:
	var o: FakeOwner = _make_owner(Vector2(7000.0, 7800.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	_track(w)
	_make_enemy(o.global_position + Vector2(300.0, 0.0)) ## görüşte ama menzil dışında -> silah görünür, ateş etmez
	await get_tree().create_timer(0.8).timeout
	var icon: Sprite2D = w.get("icon_sprite")
	## önceki testlerin düşürdüğü şarjörler hâlâ sönüyor olabilir - sayım göreli
	var mgr0: Node = get_tree().current_scene.get_node_or_null(ShellCasingFx.NODE_NAME)
	var before: int = int(mgr0.call("alive_count")) if mgr0 != null else 0
	var ground0: Node = get_tree().current_scene.get_node_or_null("ShellCasingGround")
	var ground_before: Array = ground0.get_children() if ground0 != null else []
	var snd_before: int = int(mgr0.call("casing_sound_count")) if mgr0 != null else 0
	ShellCasingFx.eject(icon, "tabanca", Vector2.RIGHT, o)
	var mgr: Node = get_tree().current_scene.get_node_or_null(ShellCasingFx.NODE_NAME)
	assert(mgr != null and int(mgr.call("alive_count")) == before + 1, "kovan doğdu")
	var ground: Node = get_tree().current_scene.get_node_or_null("ShellCasingGround")
	assert(ground != null, "zemin katmanı kuruldu")
	await get_tree().create_timer(1.5).timeout
	var landed: Array = ground.get_children().filter(func(n: Node) -> bool: return not ground_before.has(n))
	assert(landed.size() == 1, "kovan yere indi ve zemin katmanına geçti (%d)" % landed.size())
	var c: Node2D = landed[0]
	var gy: float = ShellCasingFx.ground_y(o)
	assert(absf(c.global_position.y - gy) < 16.0, "ayak hizasına düştü (%f / %f)" % [c.global_position.y, gy])
	assert(c.global_position.x < icon.global_position.x + 4.0, "sağa ateşte kovan geriye (sola) fırlar")
	## Yere değişte silahın kendi kovan sesi BİR kez (sekmelerde ayrı ses yok) - 2026-11-13 kullanıcı kaydı
	assert(int(mgr.call("casing_sound_count")) == snd_before + 1, "kovan düşme sesi bir kez çaldı")
	var tab_snds: Array = ShellCasingFx.CASING_SNDS["tabanca"]
	var played: bool = false
	for asp in mgr.get_children():
		if asp is AudioStreamPlayer2D and tab_snds.has((asp as AudioStreamPlayer2D).stream):
			played = true
	assert(played, "tabanca kovanı kendi listesinden çaldı")
	assert(ShellCasingFx.CASING_SNDS["tabanca"] == ShellCasingFx.CASING_SNDS["tufek"], "tabanca + tüfek kovan sesi aynı (kullanıcı 2026-11-13)")
	for k in GunMagMath.MAGS.keys():
		assert(ShellCasingFx.CASING_SNDS.has(k) and (ShellCasingFx.CASING_SNDS[k] as Array).size() > 0, "%s kovan sesi var" % k)
	_cleanup()


## Kovan yöneticisindeki pompalı (kırmızı, satır 4) kovan sayısı - diğer testlerin kovanları sönse de etkilenmez.
func _red_hulls() -> int:
	var mgr: Node = get_tree().current_scene.get_node_or_null(ShellCasingFx.NODE_NAME)
	if mgr == null:
		return 0
	return (mgr.get("_pieces") as Array).filter(func(p: Dictionary) -> bool: return int(p["row"]) == 4 and not bool(p["mag"])).size()


## Pompalı atış sonrası pompa (2026-11-13): kovan hemen değil pompanın geri vuruşunda çıkar, kundak o sırada ayrı parça.
func test_shotgun_pump_after_shot_ejects_on_back_stroke() -> void:
	## Gerçek silah hedef menzil dışındayken kendini söndürür (modulate 0 -> kovan çıkmaz): yalın ikon, oyundaki ölçekle.
	var o: FakeOwner = _make_owner(Vector2(7400.0, 7800.0))
	var w := Node2D.new()
	o.add_child(w)
	var icon := Sprite2D.new()
	var base_tex: Texture2D = WeaponTierArt.texture("pompali")
	icon.texture = base_tex
	icon.scale = Vector2.ONE * WeaponTierArt.WORLD_PX * WeaponTierArt.size_mult("pompali") / WeaponTierArt.OWNER_ROOT_SCALE
	icon.position = Vector2(0.0, -125.0)
	w.add_child(icon)
	await get_tree().process_frame
	var before: int = _red_hulls()
	GunReloadFx.on_shot(icon, "pompali", Vector2.RIGHT, o)
	assert(_red_hulls() == before, "kovan atış anında çıkmaz")
	await get_tree().create_timer(0.24).timeout
	assert(icon.texture == GunReloadFx.PIECES[&"pompali_nofore"], "pompa çekilirken kundak ayrı parça")
	await get_tree().create_timer(0.25).timeout
	assert(_red_hulls() == before + 1, "kovan geri vuruşta çıktı")
	assert(icon.texture == base_tex and not icon.has_meta(GunReloadFx.PUMP_META), "pompa bitti, gövde asıl çizimde")
	## doldurmada pompalı: eksik fişek kadar, şarjör düşmez
	var d: Node = GunReloadFx.begin(w, icon, "pompali", 1.0, o, {"shells": 2})
	assert(d != null and is_equal_approx(float(d.get("_len")), GunReloadMath.length("pompali", 2)), "2 fişeklik çizelge")
	d.call("abort")
	assert(icon.texture == base_tex, "iptalde gövde asıl çizimde")
	_cleanup()


func test_puppet_plays_the_same_reload_and_casings() -> void:
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	add_child(puppet)
	_track(puppet)
	puppet.setup(78, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(9000.0, 9000.0))
	puppet.call("update_weapon_visuals", ["tufek"])
	_make_enemy(puppet.global_position + Vector2(300.0, 0.0))
	await get_tree().create_timer(0.8).timeout
	var icon: Node2D = (puppet.get("_weapon_icons") as Array)[0]
	var rest_rot: float = icon.rotation
	puppet.call("_start_weapon_reload", 0, 0.5)
	assert(icon.has_meta(GunReloadFx.META), "kuklada da sürücü")
	await get_tree().create_timer(0.22).timeout
	assert(absf(wrapf(icon.rotation - rest_rot, -PI, PI)) > 0.3, "kuklada namlu kalkık")
	await get_tree().create_timer(0.45).timeout
	assert(not icon.has_meta(GunReloadFx.META), "kuklada bitti")
	assert(icon.position.is_equal_approx(puppet.WEAPON_ICON_SLOTS[0]), "kukla ikonu slotuna döndü")
	## iptal yayını
	puppet.call("_start_weapon_reload", 0, 2.0)
	puppet.call("_start_weapon_reload", 0, 0.0)
	await get_tree().process_frame
	assert(not icon.has_meta(GunReloadFx.META), "iptal")
	## ateş yayınında kovan
	var mgr0: Node = get_tree().current_scene.get_node_or_null(ShellCasingFx.NODE_NAME)
	var before: int = int(mgr0.call("alive_count")) if mgr0 != null else 0
	var fx_mode: int = AllyFxDensity._env_mode
	AllyFxDensity._env_mode = AllyFxDensity.MODE_FULL ## kullanıcının "dost efekt" ayarı azaltılmışsa başkasının kovanı hiç çıkmaz
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": 1.0, "direction_y": 0.0})
	AllyFxDensity._env_mode = fx_mode
	var mgr: Node = get_tree().current_scene.get_node_or_null(ShellCasingFx.NODE_NAME)
	assert(mgr != null and int(mgr.call("alive_count")) == before + 1, "kukla ateşinde kovan")
	_cleanup()


func test_network_and_sources_wired() -> void:
	var nm: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	assert(nm.find("\"weapon_reload\": true") != -1, "doldurma güvenilir kanalda")
	assert(nm.find("rp._start_weapon_reload(") != -1, "kukla doldurma yayınını karşılar")
	var ws: String = FileAccess.get_file_as_string("res://scripts/weapon.gd")
	assert(ws.find("GunReloadFx.on_shot(icon_sprite") != -1, "kasterde kovan (pompalıda pompa sonrası)")
