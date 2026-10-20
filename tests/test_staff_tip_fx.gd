extends Node

## Asa ucu partikülleri (madde 299, scripts/staff_tip_fx.gd): sadece asalara bağlanır, yürüyen uçtan dünyaya iz bırakır (dururken
## az), gizli ikondan doğurmaz, ikon silinince kendini siler; yerel weapon.gd + uzak kukla (remote_player.gd) aynı yayıcıyı bağlar;
## Yıldırım: uçta cızırtı + ışın hedefinde isabet kıvılcımı. Gökkuşağı (madde 309): ışın paletinden tanecik başına rastgele renk.

const StaffTipFx := preload("res://scripts/staff_tip_fx.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const FireStaffScene: PackedScene = preload("res://scenes/weapon_fire.tscn")
const RainbowStaffScene: PackedScene = preload("res://scenes/weapon_gokkusagi.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for fx: Node in _all_fx():
		fx.free()


class FakeOwner extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


class FakeEnemy extends Node2D:
	var is_dead: bool = false


func _scene() -> Node:
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func _all_fx() -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in _scene().get_children():
		if c.get_script() == StaffTipFx:
			out.append(c)
	return out


func _fx_for(icon: Node) -> Node2D:
	for fx: Node in _all_fx():
		if fx.get("source") == icon:
			return fx as Node2D
	return null


func _icon(key: String, pos: Vector2) -> Sprite2D:
	var holder := Node2D.new()
	add_child(holder)
	_track(holder)
	var s := Sprite2D.new()
	holder.add_child(s)
	WeaponTierArt.set_art(s, key, 1)
	s.global_position = pos
	return s


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _spread(fx: Node2D) -> Rect2:
	var pts: PackedVector2Array = fx.call("alive_positions")
	var r := Rect2()
	for i in pts.size():
		r = Rect2(pts[i], Vector2.ZERO) if i == 0 else r.expand(pts[i])
	return r


## Gerçek süre boyunca her karede `step` çağırır (başsız koşuda kare süresi çok kısa olabilir).
func _run_for(sec: float, step: Callable) -> void:
	var t0: int = Time.get_ticks_msec()
	var last: int = t0
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		step.call(float(now - last) / 1000.0)
		last = now


func test_attaches_only_to_staffs() -> void:
	var gun: Sprite2D = _icon("tabanca", Vector2(100, 100))
	assert(StaffTipFx.attach(gun, "tabanca") == null, "tabancaya yayıcı bağlanmaz")
	for key: String in ["fire_staff", "buz_asasi", "arcane", "lightning_staff", "gokkusagi"]:
		var st: Sprite2D = _icon(key, Vector2(100, 100))
		assert(StaffTipFx.attach(st, key) != null, "%s asasına yayıcı bağlanır" % key)
	await _frames(2)
	assert(_all_fx().size() == 5, "5 asa = 5 yayıcı: %d" % _all_fx().size())
	_cleanup()


func test_moving_tip_leaves_a_trail_and_standing_drips_a_little() -> void:
	var walk: Sprite2D = _icon("fire_staff", Vector2(100, 100))
	var stand: Sprite2D = _icon("fire_staff", Vector2(100, 300))
	StaffTipFx.attach(walk, "fire_staff")
	StaffTipFx.attach(stand, "fire_staff")
	await _frames(2)
	var fw: Node2D = _fx_for(walk)
	var fs: Node2D = _fx_for(stand)
	assert(fw != null and fs != null, "yayıcılar sahnede")
	await _run_for(0.4, func(dt: float) -> void: walk.global_position.x += 82.0 * dt) ## 82 px/sn yürüyüş
	var nw: int = int(fw.get("_spawned"))
	var ns: int = int(fs.get("_spawned"))
	assert(nw > ns + 4, "yürüyen uç daha çok doğurur: %d / %d" % [nw, ns])
	assert(ns >= 1, "dururken uçta hafif damla: %d" % ns)
	assert(_spread(fw).size.x > 18.0, "partiküller yol boyunca dünyada kalır (iz): %s" % str(_spread(fw)))
	assert(_spread(fs).size.x < 6.0, "duran uçta küme: %s" % str(_spread(fs)))
	_cleanup()


func test_hidden_icon_emits_nothing_and_freed_icon_frees_the_emitter() -> void:
	var st: Sprite2D = _icon("buz_asasi", Vector2(100, 100))
	(st.get_parent() as Node2D).modulate.a = 0.0 ## HÜCUM çekilmesi / saklanma: ata zincirinde saydam
	StaffTipFx.attach(st, "buz_asasi")
	await _frames(2)
	var fx: Node2D = _fx_for(st)
	await _run_for(0.3, func(dt: float) -> void: st.global_position.x += 82.0 * dt)
	assert(int(fx.get("_spawned")) == 0, "gizli ikon doğurmaz: %d" % int(fx.get("_spawned")))
	(st.get_parent() as Node2D).modulate.a = 1.0
	await _run_for(0.3, func(_dt: float) -> void: pass)
	assert(int(fx.get("_spawned")) > 0, "görününce doğurur")
	st.get_parent().free()
	await get_tree().create_timer(float(StaffTipFx.STYLES["ice"]["life"]) + 0.3).timeout
	assert(not is_instance_valid(fx), "ikon silinince kalanlar söner, yayıcı kendini siler")
	_cleanup()


func test_lightning_crackles_at_the_tip_and_hit_sparks_release() -> void:
	var st: Sprite2D = _icon("lightning_staff", Vector2(100, 100))
	StaffTipFx.attach(st, "lightning_staff")
	await _frames(2)
	var fx: Node2D = _fx_for(st)
	var cr: Sprite2D = fx.get("_crackle")
	assert(cr != null, "yıldırım ucunda cızırtı sprite'ı")
	var seen: bool = false
	for i in 40:
		await get_tree().create_timer(0.02).timeout
		if cr.visible:
			seen = true
			assert(cr.global_position.distance_to(StaffTipFx.WeaponTipScript.tip_global(st, float(fx.get("forward_deg")))) < 0.5, "cızırtı uçta")
	assert(seen, "cızırtı yanıp söner (en az bir kare görünür)")
	var hit: Node2D = StaffTipFx.make_hit_emitter(self)
	await _frames(2)
	await _run_for(0.5, func(dt: float) -> void: hit.emit_hit(Vector2(400, 200), dt))
	var n: int = int(hit.get("_spawned"))
	assert(n >= 3 and n <= 9, "isabet kıvılcımı hafif (~10/sn): %d" % n)
	for p: Vector2 in hit.call("alive_positions"):
		var d: float = p.distance_to(Vector2(400, 200))
		assert(d >= StaffTipFx.HIT_RY - 1.0 and d <= StaffTipFx.HIT_RX + 1.0, "gövde elipsinin kenarından doğar: %.2f" % d)
	hit.release()
	await get_tree().create_timer(float(StaffTipFx.STYLES["elec_hit"]["life"]) + 0.3).timeout
	assert(not is_instance_valid(hit), "ışın bitince isabet yayıcısı söner")
	_cleanup()


func test_local_weapon_and_remote_puppet_both_attach() -> void:
	## Yerel: Ateş Asası sahnesi (weapon.gd) ikonuna bağlanır.
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	_track(o)
	o.global_position = Vector2(300, 300)
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	_track(e)
	e.global_position = o.global_position + Vector2(0, 240) ## görüşte, menzil dışı -> asa görünür
	var w: Node2D = FireStaffScene.instantiate()
	o.add_child(w)
	await _frames(3)
	var icon: Node = w.get("icon_sprite")
	assert(_fx_for(icon) != null, "yerel asa ikonunda yayıcı (weapon.gd)")
	## Uzak kukla: update_weapon_visuals kendi ikonuna aynı yayıcıyı bağlar (iki-yer kuralı).
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	_scene().add_child(puppet)
	_track(puppet)
	puppet.call("update_weapon_visuals", ["dagger", "arcane"])
	await _frames(2)
	var info: Array = puppet.call("get_weapon_icon_info", 1)
	assert(_fx_for(info[0]) != null and String(_fx_for(info[0]).get("style")) == "arc", "kukla Arcane ikonunda yayıcı")
	var dagger_info: Array = puppet.call("get_weapon_icon_info", 0)
	assert(_fx_for(dagger_info[0]) == null, "bıçakta yayıcı yok")
	_cleanup()


## Gökkuşağı Asası (madde 309): sayfa yalnız ışın paletinden (shaders/gokkusagi_isin.gdshader RB + krem + ikisinin yarı karışımı),
## dither yok (saydamlık 4 adım), tanecik 1-2 px (parıltı en çok 3x3 artı), satır 3k..3k+2 = RB[k]; yürürken tanecikler farklı
## renklerde doğar; yerel weapon.gd + kukla aynı "rainbow" yayıcısını bağlar.
func test_rainbow_staff_sheds_beam_palette_dust() -> void:
	var cfg: Dictionary = StaffTipFx.STYLES["rainbow"]
	var rb: Array[Color] = [Color("#f06a5a"), Color("#f7a24a"), Color("#f4d85a"), Color("#86d26e"), Color("#62b2ec"), Color("#a87ae6")]
	var cream := Color("#fffaf0")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fx/staff_tip/prism_sheet.png"))
	var cell: int = int(cfg["cell"])
	var per: int = StaffTipFx.RAINBOW_ROWS_PER_COLOR
	assert(img.get_width() == cell * StaffTipFx.FRAMES and img.get_height() == cell * int(cfg["rows"]), "sayfa düzeni = STYLES: %s" % str(img.get_size()))
	assert(int(cfg["rows"]) == rb.size() * per, "her renk %d satır" % per)
	var seen_twinkle: bool = false
	for r in int(cfg["rows"]):
		var col: Color = rb[r / per]
		var allowed: Array[Color] = [col, col.lerp(cream, 0.5), cream]
		for k in StaffTipFx.FRAMES:
			var n: int = 0
			var box := Rect2i()
			for y in cell:
				for x in cell:
					var p: Color = img.get_pixel(k * cell + x, r * cell + y)
					if p.a8 == 0:
						continue
					assert(p.a8 in [127, 191, 255], "dither yok, saydamlık adımlı: satır %d kare %d a=%d" % [r, k, p.a8])
					var ok: bool = false
					for c: Color in allowed:
						ok = ok or (absi(p.r8 - c.r8) <= 1 and absi(p.g8 - c.g8) <= 1 and absi(p.b8 - c.b8) <= 1)
					assert(ok, "satır %d kare %d renk ışın paletinde değil: %s" % [r, k, p.to_html(false)])
					box = Rect2i(x, y, 1, 1) if n == 0 else box.merge(Rect2i(x, y, 1, 1))
					n += 1
			if n > 2:
				seen_twinkle = true
				assert(n == 5 and box.size == Vector2i(3, 3), "parıltı 1 px kollu artı: satır %d kare %d n=%d" % [r, k, n])
	assert(seen_twinkle, "krem merkezli kısa parıltı var")
	## yürürken: tanecik başına rastgele renk
	var st: Sprite2D = _icon("gokkusagi", Vector2(100, 100))
	StaffTipFx.attach(st, "gokkusagi")
	await _frames(2)
	var fx: Node2D = _fx_for(st)
	assert(fx != null and String(fx.get("style")) == "rainbow", "gokkusagi -> rainbow")
	await _run_for(0.45, func(dt: float) -> void: st.global_position.x += 82.0 * dt)
	var colors := {}
	for row: int in fx.call("alive_rows"):
		colors[row / per] = true
	assert(colors.size() >= 4, "tanecikler farklı renklerde: %d renk" % colors.size())
	assert(_spread(fx).size.x > 18.0, "yol boyunca iz: %s" % str(_spread(fx)))
	## iki yer: yerel weapon.gd sahnesi + kukla ikonu
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	_track(o)
	o.global_position = Vector2(300, 300)
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	_track(e)
	e.global_position = o.global_position + Vector2(0, 240)
	var w: Node2D = RainbowStaffScene.instantiate()
	o.add_child(w)
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	_scene().add_child(puppet)
	_track(puppet)
	puppet.call("update_weapon_visuals", ["gokkusagi"])
	await _frames(3)
	var lf: Node2D = _fx_for(w.get("icon_sprite"))
	assert(lf != null and String(lf.get("style")) == "rainbow", "yerel Gökkuşağı Asası ikonunda yayıcı (weapon.gd)")
	var info: Array = puppet.call("get_weapon_icon_info", 0)
	assert(_fx_for(info[0]) != null and String(_fx_for(info[0]).get("style")) == "rainbow", "kukla Gökkuşağı ikonunda yayıcı")
	_cleanup()
