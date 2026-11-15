extends SceneTree
## PvPvE takım üssü duman testi (madde 607). Kullanım (başsız, depo kökünden):
##   $env:MOD="pvp"; $env:HARITA="bataklik"; Godot --headless --path . -s res://tools/pvp/pvp_duman.gd   (HARITA boşsa ana harita)
## Main'i açar (harita_duman.gd gibi), üslerin kurulmasını bekler; üs konumu / ayrımı / kamp parça sayısı / oyuncunun kampa taşınması /
## açılış evinin kalkması / üs içindeki yaratık sayısı / üste iyileşme yazdırılır. Sonda "PVP_DUMAN TAMAM" ya da "PVP_DUMAN HATA ...".

const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const LayoutScript := preload("res://scripts/pvp/kamp_yerlesim.gd")

var _gm: Node = null
var _fail: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail.append(msg)


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	var t_load: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("PVP_DUMAN HATA main açılmadı")
		quit(1)
		return
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	print("PVP_DUMAN main %d ms, harita=%s" % [Time.get_ticks_msec() - t_load, OS.get_environment("HARITA")])
	await _wait(3.0)
	var tb: Node = main.get_node_or_null("TeamBases")
	_check(tb != null, "TeamBases yok")
	_check(BaseZonesScript.active.size() == 2, "üs sayısı %d" % BaseZonesScript.active.size())
	_check(main.get_node_or_null("HouseInterior") == null, "açılış evi kalkmadı")
	if BaseZonesScript.active.size() == 2:
		var a: Vector2 = BaseZonesScript.active[0]["center"]
		var b: Vector2 = BaseZonesScript.active[1]["center"]
		var rect: Rect2 = _gm.call("get_map_world_rect")
		print("PVP_DUMAN üsler %s %s ayrım=%.0f (alan köşegeni %.0f)" % [a, b, a.distance_to(b), rect.size.length()])
		_check(a.distance_to(b) > rect.size.length() * 0.35, "üsler yakın: %.0f" % a.distance_to(b))
		for c: Vector2 in [a, b]:
			_check(not bool(_gm.call("is_position_blocked_by_walls", c)), "üs merkezi engelde: %s" % str(c))
		## bekçi kamplarından uzak (team_bases.gd _avoid_list, sabit CAMPS)
		var forest: TileMapLayer = _gm.call("get_forest_layer")
		var mp: GDScript = load("res://scripts/map_profiles.gd")
		if forest != null and bool(mp.call("feature", "kenar_bekcileri")):
			var gcs: GDScript = load("res://scripts/guard_camps.gd")
			var tbs: GDScript = load("res://scripts/pvp/team_bases.gd")
			var nearest: float = INF
			for def: Dictionary in gcs.get("CAMPS"):
				var gc: Vector2 = forest.to_global(forest.map_to_local(def["cell"]))
				for c: Vector2 in [a, b]:
					nearest = minf(nearest, c.distance_to(gc))
			print("PVP_DUMAN en yakın bekçi kampı %.0f" % nearest)
			_check(nearest >= float(tbs.get("AVOID_GUARD_CAMP")), "üs bekçi kampına yakın: %.0f" % nearest)
	var pieces: int = 0
	for n: Node in main.get_children():
		if str(n.name).begins_with("Kamp_"):
			pieces += 1
	var full: int = LayoutScript.PARCALAR.size() * 2
	print("PVP_DUMAN kamp parçası=%d (tam kamp %d; dar yerde küçük kamp)" % [pieces, full])
	_check(pieces >= 2 and pieces <= full, "kamp parçası %d" % pieces)
	var p: Node2D = main.get_node_or_null("Player") as Node2D
	if p != null and BaseZonesScript.active.size() == 2:
		var home: Vector2 = BaseZonesScript.center_of(0)
		print("PVP_DUMAN oyuncu=%s kampa uzaklık=%.0f" % [p.global_position, p.global_position.distance_to(home)])
		_check(BaseZonesScript.in_own_base(p.global_position, 0), "oyuncu kendi üssünde değil")
		var feet: Vector2 = p.global_position + Vector2(0.0, 12.75)
		for b: Node in get_nodes_in_group("move_blockers"):
			if b.has_method("block_center") and float(b.get("block_radius")) < 100.0:
				_check(feet.distance_to(b.call("block_center")) > float(b.get("block_radius")), "oyuncu çadırın içinde doğdu: %s" % b.name)
		## iyileşme: canı yarıya indir, 3 sn bekle -> ~%6 artmalı (yavaş)
		var mh: float = float(p.get("max_health"))
		p.set("health", mh * 0.5)
		await _wait(3.0)
		var gained: float = (float(p.get("health")) - mh * 0.5) / mh
		print("PVP_DUMAN 3 sn iyileşme=%.1f%% azami can" % (gained * 100.0))
		_check(gained > 0.03 and gained < 0.2, "iyileşme oranı %.3f" % gained)
	await _wait(14.0)
	var inside: int = 0
	var near: int = 0
	for e: Node in get_nodes_in_group("enemies"):
		if not (e is Node2D) or e.get("is_dead") == true:
			continue
		for bz: Dictionary in BaseZonesScript.active:
			var d: float = (e as Node2D).global_position.distance_to(bz["center"])
			if d < BaseZonesScript.RADIUS:
				inside += 1
			elif d < BaseZonesScript.RADIUS + 400.0:
				near += 1
	print("PVP_DUMAN 20 sn: yaratık=%d üste=%d üs çevresinde(400)=%d" % [get_nodes_in_group("enemies").size(), inside, near])
	_check(inside == 0, "üste yaratık var: %d" % inside)
	if _fail.is_empty():
		print("PVP_DUMAN TAMAM")
	else:
		print("PVP_DUMAN HATA ", "; ".join(_fail))
	quit(0)
