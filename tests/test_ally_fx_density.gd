extends Node

## Madde 425 (kullanıcı kuralları 2026-11-06): müttefik efekt yoğunluğu - YALNIZ başkasının KİŞİSEL efektleri soluklaşır; TAKIM / ÇAĞRILAN /
## FORM efektleri hiçbir modda ve otomatik yoğunlukta saydamlaşmaz, sayaca girmez. Ayar dosyasına YAZMAMAK için mod doğrudan atanır.

const D := preload("res://scripts/ally_fx_density.gd")

var _keep_mode: int = 1
var _nodes: Array = []


func _begin(mode: int) -> void:
	_keep_mode = UISound.ally_fx_mode
	UISound.ally_fx_mode = mode


func _end() -> void:
	UISound.ally_fx_mode = _keep_mode
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _fx() -> Node2D:
	var n := Node2D.new()
	add_child(n)
	_nodes.append(n)
	return n


## is_in_form() true/false dönen sahte kukla.
func _caster(in_form: bool) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nfunc is_in_form() -> bool:\n\treturn %s\n" % ("true" if in_form else "false")
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	add_child(n)
	_nodes.append(n)
	return n


func test_full_mode_never_touches_effects() -> void:
	_begin(0)
	var fx := _fx()
	D.soften(fx, null)
	D.soften(fx, null, "proj")
	assert(is_equal_approx(fx.modulate.a, 1.0), "Tam: alfa değişmez")
	assert(not fx.is_in_group(D.GROUP), "Tam: sayaca girmez")
	assert(is_equal_approx(D.tip_alpha(null), 1.0) and D.casing_allowed(null), "Tam: asa ucu + kovan tam")
	_end()


func test_reduced_and_minimal_soften_personal_effects() -> void:
	_begin(1)
	var fx := _fx()
	D.soften(fx, null)
	assert(is_equal_approx(fx.modulate.a, float(D.FX_ALPHA[1])), "Azaltılmış: efekt %%60: %f" % fx.modulate.a)
	assert(fx.is_in_group(D.GROUP), "KİŞİSEL birim sayaca girer")
	var proj := _fx()
	D.soften(proj, null, "proj")
	assert(is_equal_approx(proj.modulate.a, float(D.PROJ_ALPHA[1])), "Azaltılmış: mermi yalnız hafif soluk: %f" % proj.modulate.a)
	assert(proj.modulate.a > fx.modulate.a, "mermi efektten daha az soluklaşır (oyun bilgisi)")
	assert(is_equal_approx(D.tip_alpha(null), 0.5) and not D.casing_allowed(null), "Azaltılmış: asa ucu yarı, kovan yok")
	_end()
	_begin(2)
	var fx2 := _fx()
	D.soften(fx2, null)
	assert(is_equal_approx(fx2.modulate.a, float(D.FX_ALPHA[2])), "Minimal: efekt %%35")
	assert(D.tip_alpha(null) == 0.0 and not D.casing_allowed(null), "Minimal: asa ucu kurulmaz")
	assert(float(D.FX_ALPHA[0]) > float(D.FX_ALPHA[1]) and float(D.FX_ALPHA[1]) > float(D.FX_ALPHA[2]), "mod arttıkça soluk")
	_end()


func test_caster_in_form_is_never_reduced_or_counted() -> void:
	for m in [1, 2]:
		_begin(m)
		var fx := _fx()
		D.soften(fx, _caster(true))
		assert(is_equal_approx(fx.modulate.a, 1.0), "formdaki kaster: alfa değişmez (mod %d)" % m)
		assert(not fx.is_in_group(D.GROUP), "FORM sayaca girmez (mod %d)" % m)
		assert(is_equal_approx(D.tip_alpha(_caster(true)), 1.0) and D.casing_allowed(_caster(true)), "formda asa ucu + kovan tam")
		var fx2 := _fx()
		D.soften(fx2, _caster(false)) ## formda DEĞİL -> azalır
		assert(fx2.modulate.a < 1.0, "formda olmayan kaster azalır (mod %d)" % m)
		_end()


func test_auto_density_deepens_only_with_many_personal_units() -> void:
	_begin(1)
	var base: float = D.alpha_for("fx", get_tree())
	assert(is_equal_approx(base, float(D.FX_ALPHA[1])), "boş ekranda taban alfa")
	var crowd: Array = []
	for i in range(D.AUTO_FULL + 5):
		var n := _fx()
		n.add_to_group(D.GROUP)
		crowd.append(n)
	var busy: float = D.alpha_for("fx", get_tree())
	assert(busy < base, "kalabalıkta biraz daha soluk: %f < %f" % [busy, base])
	assert(is_equal_approx(busy, float(D.FX_ALPHA[1]) * D.AUTO_EXTRA_FX), "tam yoğunlukta ek çarpan")
	assert(busy > 0.0, "asla görünmez olmaz")
	UISound.ally_fx_mode = 0
	assert(is_equal_approx(D.alpha_for("fx", get_tree()), 1.0), "Tam modda otomatik yoğunluk da etkisiz")
	_end()


func test_table_keeps_team_summon_form_scenes_full() -> void:
	## kullanıcı kuralı: bunlardan HİÇBİRİ KİŞİSEL listede olmamalı (olursa saydamlaşırdı)
	var must_stay_full: Array = [
		"fx_melek_halo", "fx_melek_holy", "fx_melek_ascend", "fx_melek_heal_sparkle", ## TAKIM: Melek
		"fx_sovalye_taunt", "fx_sovalye_guard", "fx_paladin_cast", "fx_paladin_barrier", "fx_paladin_shatter", ## TAKIM: Şovalye
		"fx_oakley_ward_cast", "fx_oakley_bee_guard", "fx_oakley_leaf_barrier", ## TAKIM / ÇAĞRILAN: Oakley
		"fx_revive_heart", "fx_revive_rewind", "fx_shield_active", "fx_kalkan_yenileme",
		"fx_shaman_cast_shield", "fx_shaman_cast_attack", "fx_necro_summon", ## ÇAĞRILAN: Shaman / Necro
		"fx_talon_form", "fx_matthew_ball", "fx_matthew_form_burst", "fx_evo_vanish", "fx_assasin_stealth", ## FORM
		"fx_korsan_zone", "fx_buyucu_tornado", "fx_spirit_adc", "fx_spirit_tank", "fx_spirit_taktik", "fx_spirit_dukkan",
		"fx_hadime_nightmare_burst", "fx_evo_loop", "fx_enemy_burn_status",
	]
	for name in must_stay_full:
		assert(not D.PERSONAL_SCENES.has(name), "%s KİŞİSEL listede olmamalı (tam görünür kalmalı)" % name)
		assert(not D.is_personal_scene("res://scenes/%s.tscn" % name), "%s yoldan da KİŞİSEL sayılmamalı" % name)
	assert(not D.is_personal_scene(""), "boş yol tam görünür")
	assert(not D.is_personal_scene("res://scenes/fx_yepyeni_efekt.tscn"), "tabloda olmayan yeni efekt TAM görünür (güvenli varsayılan)")
	assert(D.is_personal_scene("res://scenes/fx_matthew_fox_strike.tscn"), "kişisel örnek")


func test_personal_scenes_exist_and_do_not_override_root_alpha() -> void:
	for name in D.PERSONAL_SCENES.keys():
		assert(ResourceLoader.exists("res://scenes/%s.tscn" % name), "%s sahnesi yok (tablo eskimiş)" % name)


func test_form_flag_and_wiring() -> void:
	var rp: GDScript = load("res://scripts/remote_player.gd")
	var has_form: bool = false
	for m in rp.get_script_method_list():
		if str(m["name"]) == "is_in_form":
			has_form = true
	assert(has_form, "remote_player.gd is_in_form() olmalı")
	var rsrc: String = FileAccess.get_file_as_string("res://scripts/remote_player.gd")
	for flag in ["_shaman_golem_form", "_matthew_ball > 0", "_vampir_bat_form", "_talon_form_active", "_cadi_broom"]:
		assert(rsrc.find(flag) >= 0, "form bayrağı kullanılmalı: %s" % flag)
	var nsrc: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	assert(nsrc.count("AllyFxDensity.soften(") >= 8, "uzak efekt dalları bağlı olmalı (skill_scene, hitscan_impact, muzzle, melee_hit, chain, kafatası, savuruş, mermi)")
	var ssrc: String = FileAccess.get_file_as_string("res://scripts/settings_screen.gd")
	assert(ssrc.count("\"ally_fx\"") == 2, "Ayarlar'da masaüstü + telefon satırı")
	assert(UISound.ALLY_FX_MODES.size() == 3 and str(UISound.ALLY_FX_MODES[1]) == "Azaltılmış", "üç seçenek, ortası Azaltılmış")


## UÇTAN UCA: gerçek RemotePlayer kuklası + NetworkManager.broadcast_player_vfx / broadcast_projectile (ağsız, doğrudan çağrı).
## Ana sahne yerine tek parça kök: NetworkManager._find_remote_player current_scene._get_remote_player'a bakar.
class _StubMain extends Node2D:
	var puppet: Node = null
	func _get_remote_player(_id: int) -> Node:
		return puppet


func _stage() -> Dictionary:
	var main := _StubMain.new()
	get_tree().root.add_child(main)
	var prev: Node = get_tree().current_scene
	get_tree().current_scene = main
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	main.add_child(rp)
	rp.call("setup", 7, 4, "T")
	main.puppet = rp
	return {"main": main, "rp": rp, "prev": prev}


func _unstage(st: Dictionary) -> void:
	get_tree().current_scene = st["prev"]
	(st["main"] as Node).free()


func _last_alpha(parent: Node, before: int) -> float:
	var kids: Array = parent.get_children()
	assert(kids.size() > before, "efekt doğmalı")
	return float((kids[kids.size() - 1] as CanvasItem).modulate.a)


func test_end_to_end_skill_scene_personal_vs_team_summon_form() -> void:
	_begin(1)
	var st: Dictionary = _stage()
	var rp: Node = st["rp"]
	var before: int = rp.get_child_count()
	NetworkManager.broadcast_player_vfx(7, "skill_scene", Vector2.ZERO, {"scene_path": "res://scenes/fx_matthew_fox_strike.tscn"})
	assert(_last_alpha(rp, before) < 0.99, "kişisel sahne (fx_matthew_fox_strike) soluklaşmalı")
	for team in ["res://scenes/fx_melek_halo.tscn", "res://scenes/fx_shaman_cast_shield.tscn", "res://scenes/fx_shaman_cast_attack.tscn"]:
		before = rp.get_child_count()
		NetworkManager.broadcast_player_vfx(7, "skill_scene", Vector2.ZERO, {"scene_path": team, "props": {"aura_type": "heal"} if team.ends_with("melek_halo.tscn") else {}})
		assert(_last_alpha(rp, before) > 0.999, "TAKIM/ÇAĞRILAN sahne tam opak kalmalı: %s" % team)
	## FORM: kaster Elektrik Topu formundayken kişisel sahne bile azalmaz
	rp.set("_matthew_ball", 1)
	before = rp.get_child_count()
	NetworkManager.broadcast_player_vfx(7, "skill_scene", Vector2.ZERO, {"scene_path": "res://scenes/fx_matthew_fox_strike.tscn"})
	assert(_last_alpha(rp, before) > 0.999, "formdaki kasterin efekti tam kalmalı")
	rp.set("_matthew_ball", 0)
	assert(not bool(rp.call("is_in_form")), "form bayrağı kapanınca normal")
	_unstage(st)
	_end()


func test_end_to_end_remote_projectile_is_softened_but_form_is_not() -> void:
	_begin(2)
	var st: Dictionary = _stage()
	var main: Node = st["main"]
	var n0: int = main.get_child_count()
	NetworkManager.broadcast_projectile("res://scenes/fire_projectile.tscn", Vector2(10, 10), Vector2.RIGHT, 0.0, Vector2.ZERO, Vector2.ZERO, 7, {})
	var proj: CanvasItem = main.get_child(main.get_child_count() - 1) as CanvasItem
	assert(main.get_child_count() > n0 and proj.modulate.a < 0.99, "uzak mermi (Minimal) soluklaşmalı: %f" % proj.modulate.a)
	assert(proj.modulate.a > 0.5, "mermi oyun bilgisi: efektten az soluk")
	(st["rp"] as Node).set("_shaman_golem_form", true)
	NetworkManager.broadcast_projectile("res://scenes/fire_projectile.tscn", Vector2(10, 10), Vector2.RIGHT, 0.0, Vector2.ZERO, Vector2.ZERO, 7, {})
	var proj2: CanvasItem = main.get_child(main.get_child_count() - 1) as CanvasItem
	assert(proj2.modulate.a > 0.999, "golem formundaki kasterin mermisi tam kalmalı")
	_unstage(st)
	_end()


## ---- Ateş Asası alevi (madde 426): yaratık yanma alevi kalabalık sınırı + uzak oyuncu alevi alfa çarpanı ----
const BurnScript := preload("res://scripts/fx_burn_status.gd")
const EnchantSpriteScript := preload("res://scripts/fx_enchant_sprite.gd")


func _burners(n: int) -> Array:
	var out: Array = []
	var scene: PackedScene = load("res://scenes/fx_burn_status.tscn")
	for i in range(n):
		var holder := Node2D.new()
		holder.position = Vector2(30.0 * i, 0.0) ## i büyüdükçe kamera merkezinden (0,0) uzak
		add_child(holder)
		_nodes.append(holder)
		var fx: Node2D = scene.instantiate()
		holder.add_child(fx)
		out.append(fx)
	return out


func _flames_shown(fxs: Array) -> int:
	var c: int = 0
	for fx in fxs:
		if (fx.get("_fire") as CanvasItem).visible:
			c += 1
	return c


func test_burn_flame_cap_limits_simultaneous_flames_to_nearest() -> void:
	_begin(1)
	BurnScript.reset_rank()
	var fxs: Array = _burners(20)
	for fx in fxs:
		fx.call("_budget_tick")
	assert(_flames_shown(fxs) == int(D.BURN_FLAME_CAP[1]), "Azaltılmış: en çok %d alev, gösterilen %d" % [int(D.BURN_FLAME_CAP[1]), _flames_shown(fxs)])
	assert((fxs[0].get("_fire") as CanvasItem).visible, "kamera merkezine en yakın yanan yaratığın alevi açık")
	assert(not (fxs[19].get("_fire") as CanvasItem).visible, "en uzaktakinin alevi kapalı")
	for fx in fxs:
		assert((fx.get("_smoke") as CanvasItem).visible, "sınırı aşanda bile DUMAN kalır (yanma bilgisi kaybolmaz)")
	UISound.ally_fx_mode = 2
	BurnScript.reset_rank()
	for fx in fxs:
		fx.call("_budget_tick")
	assert(_flames_shown(fxs) == int(D.BURN_FLAME_CAP[2]), "Minimal: en çok %d alev" % int(D.BURN_FLAME_CAP[2]))
	UISound.ally_fx_mode = 0
	BurnScript.reset_rank()
	for fx in fxs:
		fx.call("_budget_tick")
	assert(_flames_shown(fxs) == 20, "Tam: sınır yok, hepsi eskisi gibi")
	_end()


func test_burn_flame_cap_is_stable_and_follows_crowd_changes() -> void:
	_begin(1)
	BurnScript.reset_rank()
	var fxs: Array = _burners(14)
	for fx in fxs:
		fx.call("_budget_tick")
	assert(_flames_shown(fxs) == 12, "14 yanan, sınır 12")
	## aynı anda tekrar sorulunca kararlı (yanıp sönme yok)
	var before: Array = []
	for fx in fxs:
		before.append((fx.get("_fire") as CanvasItem).visible)
	for fx in fxs:
		fx.call("_budget_tick")
	for i in range(fxs.size()):
		assert((fxs[i].get("_fire") as CanvasItem).visible == before[i], "ikinci turda karar değişmemeli (%d)" % i)
	## kalabalık azalınca (en yakın 5'i kaldı) hepsinin alevi geri gelir
	for i in range(5, fxs.size()):
		(fxs[i].get_parent() as Node).queue_free()
	await get_tree().process_frame
	BurnScript.reset_rank()
	for i in range(5):
		fxs[i].call("_budget_tick")
	assert(_flames_shown(fxs.slice(0, 5)) == 5, "sınırın altında hepsi alevli")
	_end()


func test_remote_flame_alpha_multiplier_wins_over_self_fade() -> void:
	_begin(1)
	var st: Dictionary = _stage()
	var n: Node2D = EnchantSpriteScript.spawn(get_tree(), Vector2.ZERO, {"sheet": "flame_fire", "loop_time": 2.0, "key": "test_ally_flame", "scale": 1.0})
	assert(n != null, "alev doğmalı")
	n.set("ally_alpha", 0.6)
	n.call("_process", 0.5) ## süre ortasında: kendi solma çarpanı 1.0
	assert(is_equal_approx(n.modulate.a, 0.6), "uzak alev çarpanı kendi alfa yazımını ezmemeli: %f" % n.modulate.a)
	n.set("ally_alpha", 1.0)
	n.call("_process", 0.1)
	assert(is_equal_approx(n.modulate.a, 1.0), "yerel alev (çarpan 1) tam")
	n.free()
	var src: String = FileAccess.get_file_as_string("res://scripts/fx_enchant_sprite.gd")
	assert(src.find("AllyFxDensity.mult_for(n,") >= 0, "silaha yapışık uzak efekt çarpanı bağlı olmalı")
	_unstage(st)
	_end()
