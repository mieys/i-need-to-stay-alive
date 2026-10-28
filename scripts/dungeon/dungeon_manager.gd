extends Node2D
class_name DungeonManager

## ZİNDAN YÖNETİCİSİ (madde 373). main.gd her peer'e "DungeonManager" adıyla ekler (RPC yolu herkeste aynı: Main/DungeonManager).
## - GİRİŞ: derin orman bölgelerindeki zindan kapısının (DeepForestPlaces.GATES, madde 361) ağzına yaklaşan yerel oyuncu etkileşim tuşuyla iner
##   (kararma -> zindanın "Doğuş" noktası). ÇIKIŞ: zindandaki her çıkış (merdiven oyuğu / kapak) üstüne basınca KENDİLİĞİNDEN yüzeye (kapının önü):
##   kovalanırken tuşa gerek yok. Zindan görselleri ilk girişte yüklenir (scenes/zindan/<id>_baked.tscn), kamera zindandayken görünür.
## - ETKİLEŞİMLER (host yetkili, durum herkese RPC): kapanan kapı (parmaklık / diken bariyeri: GATE_CLOSED_SEC kapalı, sonra açılır, bekleme),
##   kaynak düğümü (toplayana 1-2 kaynak, NODE_RESPAWN_SEC sonra yeniden), sandık (bir kez: oyunun normal sandık düşüşü), tuzak (eşitlenen saatle
##   zamanlanan dikenler: üstündeki oyuncu kendi istemcisinde hasar alır, yaratıklar host'ta). SUNAK: kişisel kaynak harcanır, kart statı verir
##   (player.apply_upgrade, ağ gerekmez - level kartı gibi).
## - Zindandaki yaratıklar guard_camps.gd'nin zindan kampları (gördüğünü kovalar, kaybedince arar, döner) + her zindanın AVCISI.

const DungeonDefsScript := preload("res://scripts/dungeon/dungeon_defs.gd")
const DungeonWorldScript := preload("res://scripts/dungeon/dungeon_world.gd")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const DungeonLightScript := preload("res://scripts/dungeon/dungeon_light.gd")
const DungeonPropsScript := preload("res://scripts/dungeon/dungeon_props.gd")
const DeepForestFxScript := preload("res://scripts/deep_forest_fx.gd")
const PlacesScript := preload("res://scripts/deep_forest_places.gd")
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const ChestDropScene := preload("res://scenes/chest_drop.tscn")

const ENTER_RADIUS := 64.0 ## kapı ağzına bu kadar yakın (px) -> "inmek için tuşa bas"
const INTERACT_RADIUS := 30.0 ## zindan içi etkileşim (nesne dikdörtgenine uzaklık)
const FADE_DURATION := 0.28
const GATE_CLOSED_SEC := 9.0
const GATE_COOLDOWN_SEC := 14.0
const NODE_RESPAWN_SEC := 210.0
const TRAP_CYCLE := 3.6 ## sn: dikenler bu aralıkla bir kez kalkar
const TRAP_RISE := [2.2, 2.45, 3.05, 3.3] ## evre (sn): kalkmaya başlar, tam yukarı, inmeye başlar, içeride
const TRAP_PLAYER_DAMAGE := 0.14 ## oyuncuya: azami canın oranı (yukarıdayken bir kez)
const TRAP_CREATURE_DAMAGE := 0.35 ## yaratığa: azami canın oranı (bossa / avcıya x0,25)
const EMISSIVE: Dictionary = {
	"kemik_mahzeni": ["candles.png", "torches.png", "Statue_fire.png", "scull_bas-relief.png"],
	"et_kuyusu": ["Fire_animation.png", "Flasks_monsters.png"],
	"boynuzlu_kapi": ["fire_animation.png", "fire_animation2.png", "Shinies_animation.png", "Wisps.png", "Totem_animation.png", "Walls_shinies.png", "scull.png"],
}
const KanShader: Shader = preload("res://shaders/zindan_kan.gdshader")
## Pişmiş sahneler main.gd'nin preload zinciriyle YÜKLEME EKRANINDA okunur (girişte 70-90 ms disk/ayrıştırma takılması vardı, madde 376).
const BAKED_SCENES: Dictionary = {
	"kemik_mahzeni": preload("res://scenes/zindan/kemik_mahzeni_baked.tscn"),
	"et_kuyusu": preload("res://scenes/zindan/et_kuyusu_baked.tscn"),
	"boynuzlu_kapi": preload("res://scenes/zindan/boynuzlu_kapi_baked.tscn"),
}
const WARM_START := 1.5 ## sn: oyun başladıktan sonra gizli kurulum başlar (açılış sahnesi sakin anı)
const WARM_GAP := 0.7 ## sn: iki zindan kurulumu arası (her biri ~30 ms + ilk iç güncelleme)
## Sunak teklifleri (kaynak -> kart): sunak dikdörtgeninin sol yarısı A, sağ yarısı B. Her alımda bedel +2.
const ALTAR_OFFERS: Dictionary = {
	"kemik_mahzeni": [
		{"name": "Ruh Akışı", "upgrade": "cooldown_reduction", "tier": 3, "cost": 5, "desc": "yetenek beklemesi"},
		{"name": "Kemik Zırhı", "upgrade": "max_health", "tier": 4, "cost": 8, "desc": "azami can"},
	],
	"et_kuyusu": [
		{"name": "Kan İksiri", "upgrade": "lifesteal", "tier": 3, "cost": 4, "desc": "can çalma"},
		{"name": "Kızıl Tentür", "upgrade": "damage", "tier": 4, "cost": 7, "desc": "saldırı gücü"},
	],
	"boynuzlu_kapi": [
		{"name": "Kristal Parçacık", "shards": 1, "cost": 4, "desc": "silah parçacığı"},
		{"name": "Işık Hızı", "upgrade": "fire_rate", "tier": 4, "cost": 7, "desc": "saldırı hızı"},
	],
}

var _player: Node2D = null
var _roots: Dictionary = {} ## id -> Node2D (pişmiş sahne örneği)
var _lights: Dictionary = {} ## id -> DungeonLight
var _props: Dictionary = {} ## id -> DungeonProps
var _shown: String = "" ## görünür zindan (kamera)
var _prompt: Label = null
var _fade_layer: CanvasLayer = null
var _fade: ColorRect = null
var _transitioning: bool = false
var _lore_shown: Dictionary = {}
var _altar_buys: Dictionary = {} ## "<id>:<teklif>" -> alım sayısı (kişisel)
var _wind_layer: CanvasLayer = null
var _ambient_player: AudioStreamPlayer = null
## host durumu (herkeste ayna)
var gate_until: Dictionary = {} ## kapı anahtarı -> kapalı kalacağı game_time (yoksa açık)
var gate_ready_at: Dictionary = {} ## kapı anahtarı -> yeniden kapatılabileceği game_time
var node_until: Dictionary = {} ## kaynak anahtarı -> yeniden doğacağı game_time (yoksa hazır)
var chest_opened: Dictionary = {} ## sandık anahtarı -> true
var _trap_hit: Dictionary = {} ## tuzak anahtarı -> son vurduğu döngü (oyuncuya döngü başına bir kez)
var _trap_creature_cycle: Dictionary = {}
var _sync_requested: bool = false
var _res_label: Label = null
var _warm_clock: float = 0.0


func _ready() -> void:
	name = "DungeonManager"
	add_to_group(&"dungeon_manager")
	DungeonWorldScript.ensure()
	_create_prompt()


func _process(delta: float) -> void:
	if not DungeonWorldScript.ensure():
		return
	if not _sync_requested and NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_sync_requested = true
		_rpc_request_sync.rpc_id(1)
	_warm_tick(delta)
	_update_visible()
	if NetworkManager.is_host or not NetworkManager.is_multiplayer_active:
		_host_tick()
	_tick_traps()
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null or _transitioning:
		_prompt.visible = false
		return
	_tick_minimap(delta)
	_local_interactions()


# ================================================================== görünürlük (kamera hangi zindandaysa o çizilir, CanvasModulate'ı dahil)
func _update_visible() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var want: String = ""
	if cam != null:
		want = DungeonWorldScript.dungeon_at(cam.get_screen_center_position())
		if want == "":
			want = DungeonWorldScript.dungeon_at(cam.global_position)
	if want != "" and not _roots.has(want):
		_load_dungeon(want)
	if want == _shown:
		return
	for id: String in _roots.keys():
		_set_root_shown(id, id == want)
	_shown = want
	_set_outdoor_atmosphere(want == "")


func _load_dungeon(id: String) -> void:
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		return
	var path: String = DungeonDefsScript.SCENE_PATH % id
	if not ResourceLoader.exists(path):
		push_warning("Zindan sahnesi yok: " + path)
		return
	var t_prof: int = Time.get_ticks_usec()
	var scene: PackedScene = BAKED_SCENES.get(id) if BAKED_SCENES.has(id) else load(path)
	var t_load: int = Time.get_ticks_usec()
	var root := scene.instantiate() as Node2D
	var t_inst: int = Time.get_ticks_usec()
	root.position = (e["rect"] as Rect2).position
	root.visible = false
	add_child(root)
	_roots[id] = root
	## derinlik: eşya katmanları (lahit, heykel, sütun...) arkasındaki karakteri örter
	DepthOccludersScript.new().setup_interior(root, ["Eşya", "Eşya alt"])
	var t_depth: int = Time.get_ticks_usec()
	var kan := root.get_node_or_null("Kan") as TileMapLayer
	if kan != null:
		var mat := ShaderMaterial.new()
		mat.shader = KanShader
		kan.material = mat
	var props := DungeonPropsScript.new()
	props.setup(id, e["data"])
	root.add_child(props)
	_props[id] = props
	var light := DungeonLightScript.new()
	root.add_child(light)
	light.setup(root, e["def"], e["data"], e["rect"], EMISSIVE.get(id, []))
	props.light = light
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get("type", "")) == "kaynak":
			var res: String = str(e["def"].get("resource", ""))
			var col: Color = DungeonDefsScript.RESOURCES.get(res, {}).get("color", Color.WHITE)
			var r: Rect2 = o["rect"]
			light.add_keyed_light(str(o.get("node_key", "")), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.35), 84.0, col, 0.95)
	_apply_all_state(id)
	_set_root_shown(id, id == _shown)
	if OS.get_environment("DUNGEON_PROF") == "1":
		var t_end: int = Time.get_ticks_usec()
		print("DUNGEON_PROF %s load=%.1f inst=%.1f depth=%.1f rest=%.1f ms" % [id, (t_load - t_prof) / 1000.0, (t_inst - t_load) / 1000.0,
				(t_depth - t_inst) / 1000.0, (t_end - t_depth) / 1000.0])


## Oyunun ilk sakin saniyelerinde (açılış sahnesi) zindanları GİZLİ kurar: girişte yalnız görünürlük değişir (madde 376).
func _warm_tick(delta: float) -> void:
	if _roots.size() >= BAKED_SCENES.size() or _transitioning:
		return
	_warm_clock += delta
	if _warm_clock < WARM_START + WARM_GAP * _roots.size():
		return
	for id: String in BAKED_SCENES.keys():
		if not _roots.has(id) and not DungeonWorldScript.entry(id).is_empty():
			_load_dungeon(id)
			return


## Gizli zindan çizilmez ve işlemez (ışık ayıklama, kapı/tuzak görselleri durur).
func _set_root_shown(id: String, on: bool) -> void:
	var root: Node2D = _roots.get(id)
	if root == null:
		return
	root.visible = on
	root.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _apply_all_state(id: String) -> void:
	var props: Node = _props.get(id)
	if props == null:
		return
	for k: String in gate_until.keys():
		if k.begins_with(id + ":"):
			props.set_gate_closed(k, true)
	for k: String in node_until.keys():
		if k.begins_with(id + ":"):
			props.set_node_available(k, false)
	for k: String in chest_opened.keys():
		if k.begins_with(id + ":"):
			props.set_chest_open(k, true)


## Ev içiyle aynı: dış rüzgar katmanı + rüzgar ortam sesi zindanda kapalı (gün-gece/bulut/yağmur kendi betiklerinde is_underground_now).
func _set_outdoor_atmosphere(enabled: bool) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	if _wind_layer == null or not is_instance_valid(_wind_layer):
		var map_node: Node = root.get_node_or_null("Harita")
		if map_node:
			_wind_layer = map_node.get_node_or_null("CanvasLayer") as CanvasLayer
	if _ambient_player == null or not is_instance_valid(_ambient_player):
		_ambient_player = root.get_node_or_null("WindBreezeAmbient") as AudioStreamPlayer
	if _wind_layer:
		_wind_layer.visible = enabled
	if _ambient_player:
		_ambient_player.stream_paused = not enabled


# ================================================================== yerel oyuncu: istem + giriş/çıkış + etkileşim
func _local_interactions() -> void:
	var alive: bool = _player.get("is_dead") != true
	var pressed: bool = Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing")) \
			and not GameManager.is_skill_input_blocked() if GameManager.has_method("is_skill_input_blocked") else \
			Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing"))
	var id: String = str(_player.get("in_dungeon"))
	var feet: Vector2 = _player.global_position
	if id == "":
		## dışarıda: kapı ağzı
		var gi: int = _nearest_gate(feet)
		if gi >= 0 and alive:
			var d: Dictionary = DungeonDefsScript.DUNGEONS[gi]
			_show_prompt("%s'na inmek için %s" % [d["title"], _key()] if not str(d["title"]).ends_with("Kapı") else "%s'dan girmek için %s" % [d["title"], _key()])
			if pressed:
				enter(str(d["id"]))
			return
		_prompt.visible = false
		return
	if not alive:
		_prompt.visible = false
		return
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		_prompt.visible = false
		return
	var data: Resource = e["data"]
	var local: Vector2 = feet - (e["rect"] as Rect2).position
	## çıkış: üstüne basınca
	for o: Dictionary in data.objects:
		if str(o.get("type", "")) == "cikis" and (o["rect"] as Rect2).grow(2.0).has_point(local):
			exit_dungeon()
			return
	var best: Dictionary = {}
	var best_d: float = INTERACT_RADIUS
	for o: Dictionary in data.objects:
		var t: String = str(o.get("type", ""))
		if not ["kapi", "kaynak", "sandik", "sunak"].has(t):
			continue
		var r: Rect2 = o["rect"]
		var d2: float = _rect_dist(r, local)
		if d2 < best_d:
			best_d = d2
			best = o
	if best.is_empty():
		_prompt.visible = false
		return
	match str(best["type"]):
		"kapi":
			var key: String = str(best.get("gate_key", ""))
			if gate_until.has(key):
				_show_prompt("%s indi" % best["name"], false)
			elif float(gate_ready_at.get(key, 0.0)) > GameManager.game_time:
				_show_prompt("%s hazırlanıyor (%d sn)" % [best["name"], int(ceil(float(gate_ready_at[key]) - GameManager.game_time))], false)
			else:
				_show_prompt("%s indirmek için %s" % [_accusative(str(best["name"])), _key()])
				if pressed:
					request_gate(key)
		"kaynak":
			var key2: String = str(best.get("node_key", ""))
			var res: String = str(e["def"].get("resource", ""))
			var rname: String = str(DungeonDefsScript.RESOURCES.get(res, {}).get("name", res))
			if node_until.has(key2):
				_show_prompt("Tükendi - %s yeniden birikiyor" % rname, false)
			else:
				_show_prompt("%s toplamak için %s" % [rname, _key()])
				if pressed:
					request_harvest(key2)
		"sandik":
			var key3: String = str(best.get("chest_key", ""))
			if chest_opened.has(key3):
				_show_prompt("Boş sandık", false)
			else:
				_show_prompt("Sandığı açmak için %s" % _key())
				if pressed:
					request_chest(key3)
		"sunak":
			_altar_prompt(id, e, best, local, pressed)


func _altar_prompt(id: String, e: Dictionary, o: Dictionary, local: Vector2, pressed: bool) -> void:
	var offers: Array = ALTAR_OFFERS.get(id, [])
	if offers.is_empty():
		return
	var r: Rect2 = o["rect"]
	var idx: int = 0 if local.x < r.position.x + r.size.x * 0.5 or offers.size() < 2 else 1
	var off: Dictionary = offers[idx]
	var res: String = str(e["def"].get("resource", ""))
	var rname: String = str(DungeonDefsScript.RESOURCES.get(res, {}).get("name", res))
	var cost: int = altar_cost(id, idx)
	var have: int = GameManager.get_dungeon_resource(res)
	var other: String = ""
	if offers.size() > 1:
		other = "  (%s: diğer yanda)" % (offers[1 - idx] as Dictionary)["name"]
	_show_prompt("%s - %s +  [%d/%d %s]  %s%s" % [o["name"], off["name"], have, cost, rname, _key() if have >= cost else "", other], have >= cost)
	if pressed and have >= cost:
		buy_altar(id, idx)


func altar_cost(id: String, idx: int) -> int:
	var offers: Array = ALTAR_OFFERS.get(id, [])
	if idx < 0 or idx >= offers.size():
		return 999
	return int((offers[idx] as Dictionary)["cost"]) + 2 * int(_altar_buys.get("%s:%d" % [id, idx], 0))


## Sunaktan al (kişisel: kaynak düşer, kart statı / parçacık verilir). Testler doğrudan çağırır.
func buy_altar(id: String, idx: int) -> bool:
	var offers: Array = ALTAR_OFFERS.get(id, [])
	if idx < 0 or idx >= offers.size():
		return false
	var def: Dictionary = DungeonDefsScript.by_id(id)
	var res: String = str(def.get("resource", ""))
	var cost: int = altar_cost(id, idx)
	if GameManager.get_dungeon_resource(res) < cost:
		return false
	var off: Dictionary = offers[idx]
	GameManager.add_dungeon_resource(res, -cost)
	_altar_buys["%s:%d" % [id, idx]] = int(_altar_buys.get("%s:%d" % [id, idx], 0)) + 1
	var p: Node = get_tree().get_first_node_in_group("player")
	if off.has("upgrade") and p != null and p.has_method("apply_upgrade"):
		p.apply_upgrade(str(off["upgrade"]), int(off.get("tier", 1)))
	if off.has("shards"):
		GameManager.add_weapon_shards(int(off["shards"]))
	_notice("info", str(off["name"]).to_upper(), "+%s" % off["desc"])
	return true


func _rect_dist(r: Rect2, p: Vector2) -> float:
	var cx: float = clampf(p.x, r.position.x, r.end.x)
	var cy: float = clampf(p.y, r.position.y, r.end.y)
	return Vector2(cx, cy).distance_to(p)


const ACCUSATIVE: Dictionary = {"Parmaklık": "Parmaklığı", "Diken Bariyeri": "Diken Bariyerini", "Kafes Kapı": "Kafes Kapıyı",
		"Tahta Barikat": "Tahta Barikatı", "Demir Kapı": "Demir Kapıyı", "Kristal Duvar": "Kristal Duvarı"}


func _accusative(name_s: String) -> String:
	return str(ACCUSATIVE.get(name_s, name_s))


func _nearest_gate(p: Vector2) -> int:
	var best: int = -1
	var best_d: float = ENTER_RADIUS
	for i in range(DungeonDefsScript.DUNGEONS.size()):
		var gi: int = int(DungeonDefsScript.DUNGEONS[i]["gate"])
		if gi < 0 or gi >= PlacesScript.GATES.size():
			continue
		if DungeonWorldScript.entry(str(DungeonDefsScript.DUNGEONS[i]["id"])).is_empty():
			continue
		var d: float = p.distance_to(DeepForestFxScript.gate_mouth(gi))
		if d < best_d:
			best_d = d
			best = i
	return best


func _key() -> String:
	return GameManager.get_action_key_label("interact")


func _show_prompt(text: String, actionable: bool = true) -> void:
	_prompt.text = text
	_prompt.visible = true
	if actionable:
		_prompt.add_to_group(&"interact_prompt") ## telefonda ETKİLEŞİM düğmesi (touch_controls.gd)
	elif _prompt.is_in_group(&"interact_prompt"):
		_prompt.remove_from_group(&"interact_prompt")


func _create_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DungeonPromptLayer"
	layer.layer = 50
	add_child(layer)
	_prompt = Label.new()
	_prompt.name = "InteractPrompt"
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -420.0
	_prompt.offset_right = 420.0
	_prompt.offset_top = -262.0
	_prompt.offset_bottom = -222.0
	_prompt.visible = false
	layer.add_child(_prompt)
	## zindandayken üst ortada: zindanın adı + bu zindanın kaynağından kaç tane taşındığı (sunakta harcanır)
	_res_label = Label.new()
	_res_label.name = "DungeonResource"
	_res_label.add_theme_font_size_override("font_size", 22)
	_res_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_res_label.add_theme_constant_override("outline_size", 6)
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_res_label.offset_left = -300.0
	_res_label.offset_right = 300.0
	_res_label.offset_top = 6.0
	_res_label.offset_bottom = 36.0
	_res_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_label.visible = false
	layer.add_child(_res_label)


# ================================================================== giriş / çıkış
func enter(id: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_transition(func() -> void: _do_enter(id))
	_transitioning = false


func exit_dungeon() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_transition(_do_exit)
	_transitioning = false


## Işınlama çekirdeği (fade yok; testler doğrudan çağırır).
func _do_enter(id: String) -> void:
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty() or _player == null:
		return
	if not _roots.has(id):
		_load_dungeon(id)
	var spawn: Vector2 = spawn_point(id)
	_player.set("in_dungeon", id)
	_player.global_position = spawn
	if _player.has_method("reset_physics_interpolation"):
		_player.reset_physics_interpolation()
	_update_visible()
	if not _lore_shown.has(id):
		_lore_shown[id] = true
		_banner("tier", str(e["def"]["title"]).to_upper(), str(e["def"].get("lore", "")))
	get_tree().call_group(&"guard_camps", "notify_dungeon_entered", id)


func _do_exit() -> void:
	if _player == null:
		return
	var id: String = str(_player.get("in_dungeon"))
	_player.set("in_dungeon", "")
	_player.global_position = surface_point(id)
	if _player.has_method("reset_physics_interpolation"):
		_player.reset_physics_interpolation()
	_update_visible()


## Zindanın doğuş noktası (TMX "dogus" nesnesinin ortası).
func spawn_point(id: String) -> Vector2:
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		return Vector2.ZERO
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get("type", "")) == "dogus":
			return (e["rect"] as Rect2).position + (o["rect"] as Rect2).get_center()
	return (e["rect"] as Rect2).get_center()


## Yüzeye çıkış: kapının ağzının güneyinde engelsiz ilk nokta.
func surface_point(id: String) -> Vector2:
	var def: Dictionary = DungeonDefsScript.by_id(id)
	var gi: int = int(def.get("gate", -1))
	if gi < 0 or gi >= PlacesScript.GATES.size():
		return GameManager.get_map_world_rect().get_center()
	var mouth: Vector2 = DeepForestFxScript.gate_mouth(gi)
	for dist: float in [40.0, 56.0, 72.0, 90.0, 110.0]:
		for ang: float in [PI * 0.5, PI * 0.35, PI * 0.65, 0.0, PI, PI * 0.2, PI * 0.8]:
			var p: Vector2 = mouth + Vector2.from_angle(ang) * dist
			if not GameManager.is_position_blocked_by_walls(p) and not GameManager.is_position_blocked_by_walls(p + Vector2(0, 10)):
				return p
	return mouth + Vector2(0, 48)


func _fade_transition(apply_change: Callable) -> void:
	if _fade_layer == null or not is_instance_valid(_fade_layer):
		_fade_layer = CanvasLayer.new()
		_fade_layer.layer = 95
		_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_fade_layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	await tw.finished
	apply_change.call()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	await tw2.finished


func _banner(kind: String, ribbon: String, body: String) -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_show_banner_notice"):
		main.call("_show_banner_notice", kind, ribbon, body, 4.5)


func _notice(kind: String, title: String, body: String) -> void:
	var main: Node = get_tree().current_scene
	if main != null and main.has_method("_show_notice"):
		main.call("_show_notice", kind, title, body, 2.6)


# ================================================================== etkileşim istekleri (host'a)
func request_gate(key: String) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_rpc_req_gate.rpc_id(1, key)
	else:
		host_close_gate(key)


func request_harvest(key: String) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_rpc_req_harvest.rpc_id(1, key)
	else:
		host_harvest(key, multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active else 1)


func request_chest(key: String) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_rpc_req_chest.rpc_id(1, key)
	else:
		host_open_chest(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_gate(key: String) -> void:
	if NetworkManager.is_host:
		host_close_gate(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_harvest(key: String) -> void:
	if NetworkManager.is_host:
		host_harvest(key, multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_chest(key: String) -> void:
	if NetworkManager.is_host:
		host_open_chest(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_sync() -> void:
	if not NetworkManager.is_host:
		return
	var now: float = GameManager.game_time
	var gates: Dictionary = {}
	for k: String in gate_until.keys():
		gates[k] = float(gate_until[k]) - now
	var nodes: Dictionary = {}
	for k: String in node_until.keys():
		nodes[k] = float(node_until[k]) - now
	_rpc_full_state.rpc_id(multiplayer.get_remote_sender_id(), gates, nodes, chest_opened.keys())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_full_state(gates: Dictionary, nodes: Dictionary, chests: Array) -> void:
	if not NetworkManager._from_host():
		return
	var now: float = GameManager.game_time
	for k: String in gates.keys():
		_apply_gate(k, true, now + float(gates[k]))
	for k: String in nodes.keys():
		_apply_node(k, false, now + float(nodes[k]))
	for k: Variant in chests:
		_apply_chest(str(k))


# ================================================================== host mantığı
func host_close_gate(key: String) -> bool:
	if gate_until.has(key) or float(gate_ready_at.get(key, 0.0)) > GameManager.game_time:
		return false
	if DungeonWorldScript.gate_cells(key).is_empty():
		return false
	var until: float = GameManager.game_time + GATE_CLOSED_SEC
	_apply_gate(key, true, until)
	if NetworkManager.is_multiplayer_active:
		_rpc_gate.rpc(key, true, GATE_CLOSED_SEC)
	return true


func host_harvest(key: String, peer_id: int) -> bool:
	if node_until.has(key) or not _node_exists(key):
		return false
	var until: float = GameManager.game_time + NODE_RESPAWN_SEC
	_apply_node(key, false, until)
	var amount: int = 1 + (1 if randf() < 0.5 else 0)
	var id: String = key.get_slice(":", 0)
	var res: String = str(DungeonDefsScript.by_id(id).get("resource", ""))
	if NetworkManager.is_multiplayer_active:
		_rpc_node.rpc(key, false, NODE_RESPAWN_SEC)
		if peer_id != multiplayer.get_unique_id():
			_rpc_grant.rpc_id(peer_id, res, amount)
		else:
			_grant(res, amount)
	else:
		_grant(res, amount)
	return true


func host_open_chest(key: String) -> bool:
	if chest_opened.has(key):
		return false
	var o: Dictionary = _object_by_key("chest_key", key)
	if o.is_empty():
		return false
	_apply_chest(key)
	if NetworkManager.is_multiplayer_active:
		_rpc_chest.rpc(key)
	var id: String = key.get_slice(":", 0)
	var pos: Vector2 = DungeonWorldScript.local_to_world(id, (o["rect"] as Rect2).get_center() + Vector2(0, 22))
	var elite: bool = bool(int((o.get("props", {}) as Dictionary).get("elit", 0)))
	var chest = ChestDropScene.instantiate()
	chest.chest_tier = clampi((GameManager.run_max_tier - 1) / 2, 0, 5)
	chest.is_elite = elite
	chest.global_position = pos
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = NetworkManager._gen_drop_id()
		chest.set_meta("drop_network_id", drop_id)
		NetworkManager.broadcast_drop.rpc("elite_chest" if elite else "chest", pos, chest.chest_tier, drop_id)
	get_tree().current_scene.call_deferred("add_child", chest)
	return true


func _host_tick() -> void:
	var now: float = GameManager.game_time
	for k: String in gate_until.keys():
		if now >= float(gate_until[k]):
			_apply_gate(k, false, 0.0)
			if NetworkManager.is_multiplayer_active:
				_rpc_gate.rpc(k, false, 0.0)
	for k: String in node_until.keys():
		if now >= float(node_until[k]):
			_apply_node(k, true, 0.0)
			if NetworkManager.is_multiplayer_active:
				_rpc_node.rpc(k, true, 0.0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_gate(key: String, closed: bool, seconds: float) -> void:
	if not NetworkManager._from_host():
		return
	_apply_gate(key, closed, GameManager.game_time + seconds)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_node(key: String, available: bool, seconds: float) -> void:
	if not NetworkManager._from_host():
		return
	_apply_node(key, available, GameManager.game_time + seconds)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_chest(key: String) -> void:
	if not NetworkManager._from_host():
		return
	_apply_chest(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_grant(res: String, amount: int) -> void:
	if not NetworkManager._from_host():
		return
	_grant(res, amount)


func _grant(res: String, amount: int) -> void:
	GameManager.add_dungeon_resource(res, amount)
	var info: Dictionary = DungeonDefsScript.RESOURCES.get(res, {})
	_notice("info", "+%d %s" % [amount, info.get("name", res)], "Toplam %d" % GameManager.get_dungeon_resource(res))


## Durum uygulama (herkes): yol ızgarası + görsel.
func _apply_gate(key: String, closed: bool, until: float) -> void:
	if closed:
		gate_until[key] = until
	else:
		gate_until.erase(key)
		gate_ready_at[key] = GameManager.game_time + GATE_COOLDOWN_SEC - GATE_CLOSED_SEC
	var cells: Array = DungeonWorldScript.set_gate_closed(key, closed)
	if not cells.is_empty():
		EnemyPathingScript.sync_cells(cells)
		var bridge: Node = get_tree().current_scene.get_node_or_null("EnemyWorldBridge") if get_tree().current_scene != null else null
		if bridge != null and bridge.has_method("reload_grid"):
			bridge.reload_grid()
	var props: Node = _props.get(key.get_slice(":", 0))
	if props != null:
		props.set_gate_closed(key, closed)


func _apply_node(key: String, available: bool, until: float) -> void:
	if available:
		node_until.erase(key)
	else:
		node_until[key] = until
	var props: Node = _props.get(key.get_slice(":", 0))
	if props != null:
		props.set_node_available(key, available)


func _apply_chest(key: String) -> void:
	chest_opened[key] = true
	var props: Node = _props.get(key.get_slice(":", 0))
	if props != null:
		props.set_chest_open(key)


func _node_exists(key: String) -> bool:
	return not _object_by_key("node_key", key).is_empty()


func _object_by_key(field: String, key: String) -> Dictionary:
	var e: Dictionary = DungeonWorldScript.entry(key.get_slice(":", 0))
	if e.is_empty():
		return {}
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get(field, "")) == key:
			return o
	return {}


# ================================================================== tuzaklar (eşitlenen game_time ile)
func trap_level(key: String, t: float) -> float:
	var ph: float = fposmod(t + float(hash(key) % 1000) * 0.0036, TRAP_CYCLE)
	if ph < TRAP_RISE[0]:
		return 0.0
	if ph < TRAP_RISE[1]:
		return (ph - TRAP_RISE[0]) / (TRAP_RISE[1] - TRAP_RISE[0])
	if ph < TRAP_RISE[2]:
		return 1.0
	if ph < TRAP_RISE[3]:
		return 1.0 - (ph - TRAP_RISE[2]) / (TRAP_RISE[3] - TRAP_RISE[2])
	return 0.0


func _tick_traps() -> void:
	var t: float = GameManager.game_time
	var cycle: int = int(floor(t / TRAP_CYCLE))
	var host: bool = NetworkManager.is_host or not NetworkManager.is_multiplayer_active
	for e: Dictionary in DungeonWorldScript.dungeons():
		var id: String = str(e["id"])
		var props: Node = _props.get(id)
		var rect: Rect2 = e["rect"]
		var local_in: bool = _player != null and str(_player.get("in_dungeon")) == id
		if not local_in and not host and props == null:
			continue
		for o: Dictionary in (e["data"] as Resource).objects:
			if str(o.get("type", "")) != "tuzak":
				continue
			var key: String = str(o.get("trap_key", ""))
			var lv: float = trap_level(key, t)
			if props != null and props.is_visible_in_tree():
				props.set_trap_level(key, lv)
			if lv < 0.99:
				continue
			var wr := Rect2(rect.position + (o["rect"] as Rect2).position, (o["rect"] as Rect2).size)
			if local_in and int(_trap_hit.get(key, -1)) != cycle and _player.get("is_dead") != true and wr.has_point(_player.global_position + Vector2(0, 6)):
				_trap_hit[key] = cycle
				if _player.has_method("take_damage"):
					_player.take_damage(float(_player.get("max_health")) * TRAP_PLAYER_DAMAGE)
			if host and int(_trap_creature_cycle.get(key, -1)) != cycle:
				_trap_creature_cycle[key] = cycle
				for c: Variant in EnemyQueryScript.candidates(get_tree(), wr.get_center(), wr.size.length() * 0.5 + 6.0):
					var en := c as Node2D
					if en == null or not is_instance_valid(en) or en.get("is_dead") == true or not wr.grow(4.0).has_point(en.global_position):
						continue
					var mult: float = 0.25 if (en.is_in_group("boss") or en.has_meta("dungeon_hunter")) else 1.0
					if en.has_method("take_damage_host"):
						en.take_damage_host(float(en.get("max_health")) * TRAP_CREATURE_DAMAGE * mult, false, 1.0, 0)


# ================================================================== minimap (keşif dokusu)
const MINIMAP_REVEAL := 10 ## hücre: yerel oyuncunun çevresi açılır
const MM_UNSEEN := Color(0.07, 0.065, 0.085)
const MM_FLOOR := Color(0.62, 0.55, 0.43)
const MM_WALL := Color(0.22, 0.18, 0.16)
const MM_SOLID := Color(0.42, 0.35, 0.29)
const MM_GATE := Color(0.78, 0.8, 0.86)
const MM_HIDE := Color(0.38, 0.5, 0.34)
const MM_WATER := Color(0.2, 0.42, 0.52)
const MM_BLOOD := Color(0.45, 0.1, 0.1)
const EXIT_MARKER_BASE := -9000
var _mm: Dictionary = {} ## id -> {"image", "texture", "seen": PackedByteArray}
var _mm_acc: float = 0.0
var _mm_markers_for: String = ""


## minimap.gd: {"texture", "origin" (dünya), "size" (dünya)} - doku zindanın hücre ızgarası (1 doku pikseli = 1 hücre).
func minimap_info(id: String) -> Dictionary:
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		return {}
	if not _mm.has(id):
		var data: Resource = e["data"]
		var img := Image.create(data.size.x, data.size.y, false, Image.FORMAT_RGBA8)
		img.fill(MM_UNSEEN)
		var seen := PackedByteArray()
		seen.resize(data.size.x * data.size.y)
		_mm[id] = {"image": img, "texture": ImageTexture.create_from_image(img), "seen": seen}
		_reveal(id, true)
	return {"texture": (_mm[id] as Dictionary)["texture"], "origin": (e["rect"] as Rect2).position, "size": (e["rect"] as Rect2).size}


func _reveal(id: String, force: bool = false) -> void:
	if not _mm.has(id) or _player == null:
		return
	var e: Dictionary = DungeonWorldScript.entry(id)
	var data: Resource = e["data"]
	var m: Dictionary = _mm[id]
	var img: Image = m["image"]
	var seen: PackedByteArray = m["seen"]
	var w: int = data.size.x
	var hgt: int = data.size.y
	var c: Vector2i = Vector2i(((_player.global_position - (e["rect"] as Rect2).position) / 16.0).floor())
	var changed: bool = force
	for y in range(maxi(0, c.y - MINIMAP_REVEAL), mini(hgt, c.y + MINIMAP_REVEAL + 1)):
		for x in range(maxi(0, c.x - MINIMAP_REVEAL), mini(w, c.x + MINIMAP_REVEAL + 1)):
			var i: int = y * w + x
			if seen[i] != 0 or Vector2(x - c.x, y - c.y).length() > float(MINIMAP_REVEAL):
				continue
			seen[i] = 1
			changed = true
			img.set_pixel(x, y, _mm_color(data, x, y))
	m["seen"] = seen
	if changed:
		(m["texture"] as ImageTexture).update(img)


static func _mm_color(data: Resource, x: int, y: int) -> Color:
	var code: int = data.cell_at(Vector2i(x, y))
	match code:
		DungeonDataScript.CELL_WALL:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: int = data.cell_at(Vector2i(x, y) + d)
				if n != DungeonDataScript.CELL_WALL:
					return MM_WALL
			return MM_UNSEEN
		DungeonDataScript.CELL_SOLID:
			return MM_SOLID
		DungeonDataScript.CELL_WATER:
			return MM_BLOOD if str(data.get("id")) == "et_kuyusu" else MM_WATER
		DungeonDataScript.CELL_GATE:
			return MM_GATE
		DungeonDataScript.CELL_HIDE:
			return MM_HIDE
	return MM_FLOOR


func _tick_minimap(delta: float) -> void:
	var id: String = str(_player.get("in_dungeon")) if _player != null else ""
	if id != _mm_markers_for:
		_set_exit_markers(_mm_markers_for, false)
		_mm_markers_for = id
		_set_exit_markers(id, true)
	if _res_label != null:
		_res_label.visible = id != ""
	if id == "":
		return
	_mm_acc -= delta
	if _mm_acc > 0.0:
		return
	_mm_acc = 0.25
	if _mm.has(id):
		_reveal(id)
	var def: Dictionary = DungeonDefsScript.by_id(id)
	var res: String = str(def.get("resource", ""))
	var info: Dictionary = DungeonDefsScript.RESOURCES.get(res, {})
	_res_label.text = "%s      %s: %d" % [def.get("title", id), info.get("name", res), GameManager.get_dungeon_resource(res)]
	_res_label.add_theme_color_override("font_color", info.get("color", Color.WHITE))


func _minimap_node() -> Node:
	var hud: Node = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene != null else null
	return hud.get_node_or_null("MinimapControl") if hud != null else null


func _set_exit_markers(id: String, on: bool) -> void:
	if id == "":
		return
	var mm: Node = _minimap_node()
	if mm == null or not mm.has_method("set_mission_marker"):
		return
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		return
	var n: int = 0
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get("type", "")) != "cikis":
			continue
		if on:
			mm.call("set_mission_marker", EXIT_MARKER_BASE - n, (e["rect"] as Rect2).position + (o["rect"] as Rect2).get_center(), Color(0.45, 1.0, 0.55), "Ç")
		else:
			mm.call("clear_mission_marker", EXIT_MARKER_BASE - n)
		n += 1


# ================================================================== avcı uyarısı + sakin silme (host -> istemci)
## guard_camps.gd: avcı bir oyuncuyu GÖRDÜ -> o oyuncunun ekranında kırmızı uyarı.
func hunter_alert(seen: Node2D, title: String) -> void:
	if seen == null or not is_instance_valid(seen):
		return
	if seen.is_in_group("player"):
		_show_hunter_alert(title)
	elif NetworkManager.is_multiplayer_active and "peer_id" in seen:
		_rpc_hunter_alert.rpc_id(int(seen.get("peer_id")), title)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hunter_alert(title: String) -> void:
	if not NetworkManager._from_host():
		return
	_show_hunter_alert(title)


var _hunter_alert_until: float = -100.0


func _show_hunter_alert(title: String) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now < _hunter_alert_until:
		return
	_hunter_alert_until = now + 12.0
	_notice("fail", "%s SENİ GÖRDÜ!" % title.to_upper(), "Kaç! Kapıları indir, gölgelere saklan, çıkışa koş.")
	var cs: Script = load("res://scripts/camera_shake.gd")
	if cs != null and cs.has_method("add_limited"):
		cs.call("add_limited", "dungeon_hunter", 0.35, 1.0)


## Oyuncusuz kalan zindanın sakinleri (guard_camps.gd): host'ta silinir, istemcilerdeki kuklalar da (konum paketi silinme taşımaz).
func despawn_enemy(e: Node) -> void:
	if e == null or not is_instance_valid(e):
		return
	var nid: int = int(e.get_meta("network_enemy_id", 0))
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host and nid > 0:
		_rpc_despawn.rpc(nid)
	e.queue_free()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_despawn(nid: int) -> void:
	if not NetworkManager._from_host():
		return
	var e: Node = NetworkManager.find_enemy_by_net_id(nid)
	if e != null and is_instance_valid(e):
		e.queue_free()


## Test / hata ayıklama.
func debug_state() -> Dictionary:
	return {"shown": _shown, "loaded": _roots.keys(), "gates_closed": gate_until.keys(), "nodes_down": node_until.keys(),
			"chests": chest_opened.keys(), "prompt": _prompt.text if _prompt.visible else ""}
