extends Node

## Elara Q/E/R efektleri (2026-10-16, madde 178, scripts/elara_fx.gd): sayfalar, kaster/uzak ortak Driver'ın bayrak kenarları, silah ikizi /
## parıltısı, mermi görünümü (E kehribar, R ikinci tetik turkuaz ikiz) ve uzak kopyanın E bayrağı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemoteScene: PackedScene = preload("res://scenes/remote_player.tscn")
const EnchantFxScript := preload("res://scripts/enchant_fx.gd")

var _spawned: Array[Node] = []


func _make(scene: PackedScene) -> Node2D:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var n: Node2D = scene.instantiate()
	add_child(n)
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _frames(k: int) -> void:
	for i in range(k):
		await get_tree().process_frame


func _anims(driver: Node) -> Array:
	var out: Array = []
	for c in driver.get_children():
		if c is ElaraFx.SheetAnim and not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_sheets_match_frame_counts() -> void:
	for sheet: String in ElaraFx.SHEETS:
		var t: Texture2D = ElaraFx.tex(sheet)
		assert(t != null, "sayfa yok: " + sheet)
		var n: int = int(ElaraFx.SHEETS[sheet])
		assert(int(t.get_width()) % n == 0, "%s genişliği %d kareye bölünmüyor (%d)" % [sheet, n, t.get_width()])


func test_driver_q_lifecycle_ghosts_and_end_gust() -> void:
	var p: Node2D = _make(PlayerScene)
	p._elara_evasion_timer = 3.0
	var d: Node = ElaraFx.ensure_driver(p)
	assert(ElaraFx.ensure_driver(p) == d, "ikinci çağrı aynı Driver'ı döndürmeli")
	await _frames(2)
	var world: Array = _anims(d).filter(func(a): return a.top_level)
	assert(world.size() == 1, "Q başında dünyada sabit girdap sayfası olmalı: %d" % world.size())
	## hareket: ardıl görüntüler doğmalı
	for i in range(12):
		p.global_position += Vector2(6.0, 0.0)
		await get_tree().process_frame
	var ghosts: int = 0
	for c in d.get_children():
		if c is ElaraFx.Ghost:
			ghosts += 1
	assert(ghosts >= 1, "koşarken ardıl görüntü doğmalı")
	p._elara_evasion_timer = 0.0
	await _frames(2)
	var ends: Array = _anims(d).filter(func(a): return a.top_level and a.hframes == int(ElaraFx.SHEETS["q_end"]))
	assert(ends.size() >= 1, "Q bitince bitiş esintisi doğmalı")
	_cleanup()


func test_driver_e_and_r_start_and_finish() -> void:
	var p: Node2D = _make(PlayerScene)
	var d: Node = ElaraFx.ensure_driver(p)
	p.elara_true_damage_active = true
	p.elara_double_fire_active = true
	await _frames(2)
	assert(is_instance_valid(d._e_ground) and is_instance_valid(d._e_top), "E halkası + nişangâh başlamalı")
	assert(is_instance_valid(d._r_back) and is_instance_valid(d._r_front), "R ikiz okları başlamalı")
	assert(d._e_ground.z_index < 0 and d._r_back.z_index < 0 and d._r_front.z_index > 0, "zemin/arka katman Elara'nın altında, ön katman üstünde")
	p.elara_true_damage_active = false
	p.elara_double_fire_active = false
	await _frames(2)
	assert(not is_instance_valid(d._e_top) or d._e_top.is_queued_for_deletion(), "E bitince üst katman silinmeli")
	## R ikiz okları döngü başa dönünce çıkışa geçer ve biter (en fazla 15 + 6 kare)
	await get_tree().create_timer(1.6).timeout
	assert(not is_instance_valid(d._r_back), "R çıkışı bitince arka katman silinmeli")
	_cleanup()


func test_dead_player_turns_everything_off() -> void:
	var p: Node2D = _make(PlayerScene)
	p.elara_double_fire_active = true
	p.is_dead = true
	assert(ElaraFx.flags(p) == [false, false, false], "ölüyken efekt bayrakları kapalı sayılmalı")
	_cleanup()


func test_weapon_fx_brackets_glint_and_echo() -> void:
	var holder := Node2D.new()
	add_child(holder)
	_spawned.append(holder)
	var icon := Sprite2D.new()
	icon.texture = load("res://assets/weapons/tabanca/icon_v2.png")
	icon.scale = Vector2(0.11, 0.11)
	holder.add_child(icon)
	var w = ElaraFx.WeaponFx.new()
	icon.add_child(w)
	assert(w.update_state(true, false, 0), "E açıkken düğüm yaşamalı")
	var r: Rect2 = w._world_rect()
	assert(r.size.x > 10.0 and r.size.x < 30.0, "ikon kutusu tabancanın dolu bölgesi olmalı (dünya ~21): %s" % r)
	assert(w._echo != null and w._glint != null, "ikiz + parıltı sprite'ları kurulmalı")
	assert(w._echo.show_behind_parent and not w._glint.show_behind_parent, "ikiz ikonun arkasında, parıltı önünde")
	## R: ikiz gecikmeden sonra belirir
	w.update_state(false, true, 0)
	w._echo_t = ElaraFx.WeaponFx.ECHO_DELAY + 1.0
	w.update_state(false, true, 0)
	assert(w._echo.visible and is_equal_approx(w._echo_level, 0.85), "ikiz tam belirmeli: %f" % w._echo_level)
	var world_off: Vector2 = icon.get_global_transform().basis_xform(w._echo.position)
	assert(world_off.distance_to(ElaraFx.ECHO_OFFSET) < 0.01, "ikiz dünya kayması ECHO_OFFSET olmalı: %s" % world_off)
	## kapanınca söner ve düğüm kendini siler
	var alive: bool = true
	for i in range(20):
		w._echo_t += 1.0 / ElaraFx.FPS
		alive = w.update_state(false, false, 0)
		if not alive:
			break
	assert(not alive, "E/R kapalıyken ikiz sönüp düğüm bitmeli")
	_cleanup()


func test_style_projectile_modes_and_mode_pick() -> void:
	var p: Node2D = _make(PlayerScene)
	var weapon_like := Node2D.new()
	p.add_child(weapon_like)
	assert(ElaraFx.projectile_mode(weapon_like, true) == 2, "ikinci tetik = ikiz")
	assert(ElaraFx.projectile_mode(weapon_like, false) == 0, "E kapalı = normal")
	p.elara_true_damage_active = true
	assert(ElaraFx.projectile_mode(weapon_like, false) == 1, "E açık = kehribar")
	for mode in [1, 2]:
		var proj := Node2D.new()
		var spr := Sprite2D.new()
		proj.add_child(spr)
		add_child(proj)
		_spawned.append(proj)
		ElaraFx.style_projectile(proj, mode)
		var trails: int = 0
		for c in proj.get_children():
			if c is ElaraFx.Trail:
				trails += 1
		assert(trails == 1, "mod %d: tek iz olmalı" % mode)
		assert((spr.material != null) == (mode == 2), "yalnız ikiz mermi turkuaz silüet olmalı (mod %d)" % mode)
	## uzak kopya yolu: look anahtarı aynı fonksiyona gider
	var proj2 := Node2D.new()
	add_child(proj2)
	_spawned.append(proj2)
	EnchantFxScript.apply_projectile_look(proj2, {"elara": 1})
	assert(proj2.get_child_count() == 1 and proj2.get_child(0) is ElaraFx.Trail, "apply_projectile_look elara anahtarını uygulamalı")
	_cleanup()


func test_remote_focus_flag_attaches_driver() -> void:
	var rp: Node2D = _make(RemoteScene)
	rp.update_extra_state_from_net(100.0, 100.0, 0.0, 0.0, false, false, [], {"elara_focus": true})
	assert(rp._elara_focus, "uzak kopya E bayrağını okumalı")
	assert(rp.get_node_or_null("ElaraFxDriver") != null, "uzak kopyada Driver takılmalı")
	assert(ElaraFx.flags(rp) == [false, true, false], "uzak bayraklar Driver'a doğru gitmeli: %s" % [ElaraFx.flags(rp)])
	_cleanup()
