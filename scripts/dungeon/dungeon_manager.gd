extends Node2D
class_name DungeonManager
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## ZİNDAN YÖNETİCİSİ (madde 373; madde 463'den beri YALNIZ zindan biçimli haritalarda). main.gd her peer'e "DungeonManager" adıyla ekler
## (RPC yolu herkeste aynı: Main/DungeonManager). Madde 463 (2026-11-08, kullanıcı: "ana haritada zindanla ilgili bir şey istemiyorum, kapılar
## dahil kaldır"): ana haritadaki üç zindan (kapıdan iniş/çıkış, gizli ön kurulum, zindan minimapi, pişmiş sahneler) SİLİNDİ; üç zindanın
## tanımları (dungeon_defs.gd) ve sayfa klasörleri harita kipinin TEMALARI olarak duruyor.
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
const DungeonFloorScript := preload("res://scripts/dungeon/dungeon_floor.gd")
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
## HARİTA KİPİ (madde 444): zindan biçimli haritada (Kadim Derinlikler) bu yönetici haritanın KENDİ nesnelerini (kapı / kaynak / sandık /
## sunak / tuzak / simyacı) + ışığını sürer. Kök = sahnedeki "Harita" (yükleme yok), oyuncu "zindanda" sayılmaz (in_dungeon boş: yaratık
## doğuşu / gün-gece / minimap etkilenmez), etkileşim ve tuzaklar in_dungeon boşken haritaya bakar. Nesnenin `tema` özelliği hangi
## zindanın kaynağı / sunak teklifleri / görsel tablosu (DungeonProps STYLE + o zindanın sayfa klasörü) olduğunu seçer.
const MAP_THEME_DUNGEON := {"kemik": "kemik_mahzeni", "et": "et_kuyusu", "boynuz": "boynuzlu_kapi"}
const MAP_THEME_PREFIX := {"kemik_mahzeni": "kemik_", "et_kuyusu": "et_", "boynuzlu_kapi": "boynuz_"} ## birleşik paketteki sayfa adı öneki
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const ChestDropScene := preload("res://scenes/chest_drop.tscn")

const INTERACT_RADIUS := 30.0 ## zindan içi etkileşim (nesne dikdörtgenine uzaklık)
const GATE_CLOSED_SEC := 9.0
const GATE_COOLDOWN_SEC := 14.0
const NODE_RESPAWN_SEC := 210.0
const TRAP_CYCLE := 3.6 ## sn: dikenler bu aralıkla bir kez kalkar
const TRAP_RISE := [2.2, 2.45, 3.05, 3.3] ## evre (sn): kalkmaya başlar, tam yukarı, inmeye başlar, içeride
const TRAP_PLAYER_DAMAGE := 0.14 ## oyuncuya: azami canın oranı (yukarıdayken bir kez)
const TRAP_CREATURE_DAMAGE := 0.35 ## yaratığa: azami canın oranı (bossa / avcıya x0,25)
## GAZ FIÇISI (madde 449, Lağım Ağı): E ile ateşlenir, fitilden sonra patlar (hasar host'ta yaratığa, her istemcide kendi oyuncusuna), sonra dolar
const BARREL_FUSE_SEC := 1.4
const BARREL_RESPAWN_SEC := 75.0
const BARREL_RADIUS := 84.0 ## px
const BARREL_CREATURE_DAMAGE := 0.6 ## yaratığa azami canın oranı (boss / avcı x0,2)
const BARREL_PLAYER_DAMAGE := 0.12
const BarrelBlastScene := preload("res://scenes/fx_korsan_explosion.tscn")
const EMISSIVE: Dictionary = {
	"kemik_mahzeni": ["candles.png", "torches.png", "Statue_fire.png", "scull_bas-relief.png"],
	"et_kuyusu": ["Fire_animation.png", "Flasks_monsters.png"],
	"boynuzlu_kapi": ["fire_animation.png", "fire_animation2.png", "Shinies_animation.png", "Wisps.png", "Totem_animation.png", "Walls_shinies.png", "scull.png"],
}
const KanShader: Shader = preload("res://shaders/zindan_kan.gdshader")
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
var _prompt: Label = null
var _altar_buys: Dictionary = {} ## "<id>:<teklif>" -> alım sayısı (kişisel)
## host durumu (herkeste ayna)
var gate_until: Dictionary = {} ## kapı anahtarı -> kapalı kalacağı game_time (yoksa açık)
var gate_ready_at: Dictionary = {} ## kapı anahtarı -> yeniden kapatılabileceği game_time
var node_until: Dictionary = {} ## kaynak anahtarı -> yeniden doğacağı game_time (yoksa hazır)
var chest_opened: Dictionary = {} ## sandık anahtarı -> true
var barrel_fuse: Dictionary = {} ## gaz fıçısı anahtarı -> patlayacağı game_time (fitil yanıyor)
var barrel_until: Dictionary = {} ## gaz fıçısı anahtarı -> yeniden dolacağı game_time (patladı)
var _trap_hit: Dictionary = {} ## tuzak anahtarı -> son vurduğu döngü (oyuncuya döngü başına bir kez)
var _trap_creature_cycle: Dictionary = {}
var _sync_requested: bool = false
var _res_label: Label = null
var _map_id: String = "" ## harita kipi: haritanın profil kimliği (boşsa normal zindan yöneticisi)
var _map_props: Dictionary = {} ## harita kipi: nesne anahtarı -> o temanın DungeonProps örneği


func _ready() -> void:
	name = "DungeonManager"
	add_to_group(&"dungeon_manager")
	DungeonWorldScript.ensure()
	_create_prompt()
	_setup_map()


func _process(delta: float) -> void:
	if not DungeonWorldScript.ensure():
		return
	if not _sync_requested and NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_sync_requested = true
		_rpc_request_sync.rpc_id(1)
	if NetworkManager.is_host or not NetworkManager.is_multiplayer_active:
		_host_tick()
	_tick_traps()
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		_prompt.visible = false
		return
	_local_interactions()


# ================================================================== yerel oyuncu: istem + etkileşim
func _local_interactions() -> void:
	var alive: bool = _player.get("is_dead") != true
	var pressed: bool = Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing")) \
			and not GameManager.is_skill_input_blocked() if GameManager.has_method("is_skill_input_blocked") else \
			Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing"))
	var id: String = str(_player.get("in_dungeon"))
	if id == "" and _map_id != "":
		id = _map_id ## harita kipi: haritanın kendi nesneleri (dışarı / içeri yok)
	## nesneye uzaklık AYAKTAN (hareketle aynı nokta, dungeon_world.gd AYAK KURALI)
	var feet: Vector2 = _player.global_position + Vector2(0.0, DungeonWorldScript.FEET_SHIFT)
	if id == "" or not alive:
		_prompt.visible = false
		return
	var e: Dictionary = DungeonWorldScript.entry(id)
	if e.is_empty():
		_prompt.visible = false
		return
	var data: Resource = e["data"]
	var local: Vector2 = feet - (e["rect"] as Rect2).position
	var best: Dictionary = {}
	var best_d: float = INTERACT_RADIUS
	for o: Dictionary in data.objects:
		var t: String = str(o.get("type", ""))
		if not ["kapi", "kaynak", "sandik", "sunak", "kol", "fici"].has(t):
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
			if str((best.get("props", {}) as Dictionary).get("grup", "")) != "":
				_show_prompt(Loc.t("%s kolla iner") % best["name"], false) ## madde 449: gruplu parmaklık yalnız kolla
			elif gate_until.has(key):
				_show_prompt(Loc.t("%s indi") % best["name"], false)
			elif float(gate_ready_at.get(key, 0.0)) > GameManager.game_time:
				_show_prompt(Loc.t("%s hazırlanıyor (%d sn)") % [best["name"], int(ceil(float(gate_ready_at[key]) - GameManager.game_time))], false)
			else:
				_show_prompt(Loc.t("%s indirmek için %s") % [_accusative(str(best["name"])), _key()])
				if pressed:
					request_gate(key)
		"kaynak":
			var key2: String = str(best.get("node_key", ""))
			var res: String = _resource_of(id, best)
			var rname: String = str(DungeonDefsScript.RESOURCES.get(res, {}).get("name", res))
			if node_until.has(key2):
				_show_prompt(Loc.t("Tükendi - %s yeniden birikiyor") % rname, false)
			else:
				_show_prompt(Loc.t("%s toplamak için %s") % [rname, _key()])
				if pressed:
					request_harvest(key2)
		"sandik":
			var key3: String = str(best.get("chest_key", ""))
			if chest_opened.has(key3):
				_show_prompt("Boş sandık", false)
			else:
				_show_prompt(Loc.t("Sandığı açmak için %s") % _key())
				if pressed:
					request_chest(key3)
		"sunak":
			_altar_prompt(id, e, best, local, pressed)
		"fici":
			var bk: String = str(best.get("barrel_key", ""))
			if barrel_until.has(bk):
				_show_prompt(Loc.t("Gaz Fıçısı yeniden doluyor (%d sn)") % int(ceil(float(barrel_until[bk]) - GameManager.game_time)), false)
			elif barrel_fuse.has(bk):
				_show_prompt(Loc.t("Fitil yanıyor!"), false)
			else:
				_show_prompt(Loc.t("Gaz Fıçısını ateşlemek için %s") % _key())
				if pressed:
					request_barrel(bk)
		"kol":
			var lk: String = str(best.get("lever_key", ""))
			var gks: Array = _lever_gates(lk)
			var down: bool = false
			var wait: float = 0.0
			for gk: String in gks:
				down = down or gate_until.has(gk)
				wait = maxf(wait, float(gate_ready_at.get(gk, 0.0)) - GameManager.game_time)
			if down:
				_show_prompt(Loc.t("Köprü parmaklıkları indi"), false)
			elif wait > 0.0:
				_show_prompt(Loc.t("%s hazırlanıyor (%d sn)") % [best["name"], int(ceil(wait))], false)
			elif not gks.is_empty():
				_show_prompt(Loc.t("%s çekmek için %s") % [_accusative(str(best["name"])), _key()])
				if pressed:
					request_lever(lk)


func _altar_prompt(map_or_id: String, _e: Dictionary, o: Dictionary, local: Vector2, pressed: bool) -> void:
	var id: String = _offer_id(map_or_id, o) ## harita kipinde sunağın teması hangi zindansa onun teklifleri / kaynağı
	var offers: Array = ALTAR_OFFERS.get(id, [])
	if offers.is_empty():
		return
	var r: Rect2 = o["rect"]
	var idx: int = 0 if local.x < r.position.x + r.size.x * 0.5 or offers.size() < 2 else 1
	var off: Dictionary = offers[idx]
	var res: String = str(DungeonDefsScript.by_id(id).get("resource", ""))
	var rname: String = str(DungeonDefsScript.RESOURCES.get(res, {}).get("name", res))
	var cost: int = altar_cost(id, idx)
	var have: int = GameManager.get_dungeon_resource(res)
	var other: String = ""
	if offers.size() > 1:
		other = Loc.t("  (%s: diğer yanda)") % (offers[1 - idx] as Dictionary)["name"]
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
		"Tahta Barikat": "Tahta Barikatı", "Demir Kapı": "Demir Kapıyı", "Kristal Duvar": "Kristal Duvarı", "Demir Parmaklık": "Demir Parmaklığı",
		"Köprü Kolu": "Köprü Kolunu"}


func _accusative(name_s: String) -> String:
	return str(ACCUSATIVE.get(name_s, name_s))


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


## KOL (madde 449, Taşkın Hisar): aynı "grup"taki tüm parmaklıkları birlikte indirir (her biri normal kapı gibi: süre, bekleme, RPC).
func request_lever(key: String) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_rpc_req_lever.rpc_id(1, key)
	else:
		host_pull_lever(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_lever(key: String) -> void:
	if NetworkManager.is_host:
		host_pull_lever(key)


func host_pull_lever(key: String) -> bool:
	var any: bool = false
	for gk: String in _lever_gates(key):
		if host_close_gate(gk):
			any = true
	return any


## Kolun grubundaki parmaklıkların anahtarları (nesnelerin "grup" özelliği aynı).
func _lever_gates(lever_key: String) -> Array:
	var out: Array = []
	var lo: Dictionary = _object_by_key("lever_key", lever_key)
	var grp: String = str((lo.get("props", {}) as Dictionary).get("grup", ""))
	var e: Dictionary = DungeonWorldScript.entry(lever_key.get_slice(":", 0))
	if grp == "" or e.is_empty():
		return out
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get("type", "")) == "kapi" and str((o.get("props", {}) as Dictionary).get("grup", "")) == grp:
			out.append(str(o.get("gate_key", "")))
	return out


## Kapı durumu değişince aynı gruptaki kolların görseli (inik parmaklık varsa kol çekili) - her eşte, ek RPC yok.
func _refresh_levers(gate_key: String) -> void:
	var go: Dictionary = _object_by_key("gate_key", gate_key)
	var grp: String = str((go.get("props", {}) as Dictionary).get("grup", ""))
	var e: Dictionary = DungeonWorldScript.entry(gate_key.get_slice(":", 0))
	if grp == "" or e.is_empty():
		return
	for o: Dictionary in (e["data"] as Resource).objects:
		if str(o.get("type", "")) != "kol" or str((o.get("props", {}) as Dictionary).get("grup", "")) != grp:
			continue
		var lk: String = str(o.get("lever_key", ""))
		var pulled: bool = false
		for gk: String in _lever_gates(lk):
			pulled = pulled or gate_until.has(gk)
		var lp: Node = _props_for(lk)
		if lp != null and lp.has_method("set_lever"):
			lp.set_lever(lk, pulled)


func request_barrel(key: String) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		_rpc_req_barrel.rpc_id(1, key)
	else:
		host_ignite_barrel(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_req_barrel(key: String) -> void:
	if NetworkManager.is_host:
		host_ignite_barrel(key)


func host_ignite_barrel(key: String) -> bool:
	if barrel_until.has(key) or barrel_fuse.has(key) or _object_by_key("barrel_key", key).is_empty():
		return false
	_apply_barrel(key, 1, GameManager.game_time + BARREL_FUSE_SEC)
	if NetworkManager.is_multiplayer_active:
		_rpc_barrel.rpc(key, 1, BARREL_FUSE_SEC)
	return true


## host: patlamanın yaratık hasarı (oyuncu hasarını her eş kendi oyuncusuna _apply_barrel'da verir)
func _host_barrel_blast(key: String) -> void:
	var pos: Vector2 = _barrel_center(key)
	for c: Variant in EnemyQueryScript.candidates(get_tree(), pos, BARREL_RADIUS):
		var en := c as Node2D
		if en == null or not is_instance_valid(en) or en.get("is_dead") == true or en.global_position.distance_to(pos) > BARREL_RADIUS:
			continue
		var mult: float = 0.2 if (en.is_in_group("boss") or en.has_meta("dungeon_hunter")) else 1.0
		if en.has_method("take_damage_host"):
			en.take_damage_host(float(en.get("max_health")) * BARREL_CREATURE_DAMAGE * mult, false, 1.0, 0)


func _barrel_center(key: String) -> Vector2:
	var o: Dictionary = _object_by_key("barrel_key", key)
	var e: Dictionary = DungeonWorldScript.entry(key.get_slice(":", 0))
	if o.is_empty() or e.is_empty():
		return Vector2.ZERO
	return (e["rect"] as Rect2).position + (o["rect"] as Rect2).get_center()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_barrel(key: String, state: int, seconds: float) -> void:
	if not NetworkManager._from_host():
		return
	_apply_barrel(key, state, GameManager.game_time + seconds)


## state: 0 hazır, 1 fitil yanıyor (until = patlama), 2 patladı (until = yeniden dolma). Görsel + patlama efekti + yerel oyuncu hasarı.
func _apply_barrel(key: String, state: int, until: float, fx: bool = true) -> void:
	match state:
		0:
			barrel_fuse.erase(key)
			barrel_until.erase(key)
		1:
			barrel_fuse[key] = until
		2:
			barrel_fuse.erase(key)
			barrel_until[key] = until
			if fx:
				var pos: Vector2 = _barrel_center(key)
				var ex: Node2D = BarrelBlastScene.instantiate() as Node2D
				var sc: Node = get_tree().current_scene
				if sc != null:
					sc.add_child(ex)
					ex.global_position = pos
					if ex.has_method("setup"):
						ex.setup(120.0, Color(0.72, 1.0, 0.36))
				if _player != null and is_instance_valid(_player) and _player.get("is_dead") != true \
						and _player.global_position.distance_to(pos) <= BARREL_RADIUS and _player.has_method("take_damage"):
					_player.take_damage(float(_player.get("max_health")) * BARREL_PLAYER_DAMAGE)
	var props: Node = _props_for(key)
	if props != null and props.has_method("set_barrel"):
		props.set_barrel(key, state)


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
	var barrels: Dictionary = {}
	for k: String in barrel_until.keys():
		barrels[k] = float(barrel_until[k]) - now
	_rpc_full_state.rpc_id(multiplayer.get_remote_sender_id(), gates, nodes, chest_opened.keys(), barrels)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_full_state(gates: Dictionary, nodes: Dictionary, chests: Array, barrels: Dictionary = {}) -> void:
	if not NetworkManager._from_host():
		return
	var now: float = GameManager.game_time
	for k: String in gates.keys():
		_apply_gate(k, true, now + float(gates[k]))
	for k: String in nodes.keys():
		_apply_node(k, false, now + float(nodes[k]))
	for k: Variant in chests:
		_apply_chest(str(k))
	for k: String in barrels.keys():
		_apply_barrel(k, 2, now + float(barrels[k]), false)


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
	var res: String = _resource_of(key.get_slice(":", 0), _object_by_key("node_key", key))
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
	for k: String in barrel_fuse.keys():
		if now >= float(barrel_fuse[k]):
			_host_barrel_blast(k)
			_apply_barrel(k, 2, now + BARREL_RESPAWN_SEC)
			if NetworkManager.is_multiplayer_active:
				_rpc_barrel.rpc(k, 2, BARREL_RESPAWN_SEC)
	for k: String in barrel_until.keys():
		if now >= float(barrel_until[k]):
			_apply_barrel(k, 0, 0.0)
			if NetworkManager.is_multiplayer_active:
				_rpc_barrel.rpc(k, 0, 0.0)


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
	_notice("info", "+%d %s" % [amount, info.get("name", res)], Loc.t("Toplam %d") % GameManager.get_dungeon_resource(res))


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
	var props: Node = _props_for(key)
	if props != null:
		props.set_gate_closed(key, closed)
	_refresh_levers(key)


func _apply_node(key: String, available: bool, until: float) -> void:
	if available:
		node_until.erase(key)
	else:
		node_until[key] = until
	var props: Node = _props_for(key)
	if props != null:
		props.set_node_available(key, available)


func _apply_chest(key: String) -> void:
	chest_opened[key] = true
	var props: Node = _props_for(key)
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


# ================================================================== harita kipi (madde 444)
## Zindan biçimli harita seçiliyse kök = sahnedeki Harita; derinlik, kan shader'ı, ışık (tek ortam rengi + `isik` nesneleri + oyuncu feneri),
## tema başına bir DungeonProps (o zindanın görsel tablosu ve sayfa klasörü, yalnız o temanın nesneleri).
func _setup_map() -> void:
	if str(MapProfilesScript.current().get("tur", "")) != MapProfilesScript.KIND_ZINDAN:
		return
	var e: Dictionary = DungeonWorldScript.map_entry()
	var root := get_parent().get_node_or_null("Harita") as Node2D if get_parent() != null else null
	if e.is_empty() or root == null:
		return
	_map_id = str(e["id"])
	_roots[_map_id] = root
	## örnekten kurulan haritalar (madde 446) birden çok derinlikli "Eşya*" ve "Kan*" katmanı taşır (örneğin çakışan eşya katmanları)
	var depth_layers: Array = ["Eşya", "Eşya alt"]
	var kan_layers: Array = []
	for c: Node in root.get_children():
		var nm: String = String(c.name)
		if c is TileMapLayer and nm.begins_with("Eşya ") and nm != "Eşya alt" and nm != "Eşya üst":
			depth_layers.append(nm)
		elif c is TileMapLayer and (nm == "Kan" or nm.begins_with("Kan ")):
			kan_layers.append(c)
	DepthOccludersScript.new().setup_interior(root, depth_layers)
	for kan: TileMapLayer in kan_layers:
		var mat := ShaderMaterial.new()
		mat.shader = KanShader
		kan.material = mat
	## zemin shader'ı (madde 449: döşeme taşı derzleri + duvar dibi gölgesi), profil bayrağıyla
	if MapProfilesScript.feature("zemin_tasi"):
		var floor_fx := DungeonFloorScript.new()
		root.add_child(floor_fx)
		floor_fx.setup(root, MapProfilesScript.data())
	var emissive: Array = []
	for did: String in EMISSIVE:
		for f: String in EMISSIVE[did]:
			emissive.append(str(MAP_THEME_PREFIX.get(did, "")) + f)
	var light := DungeonLightScript.new()
	root.add_child(light)
	light.setup(root, e["def"], e["data"], e["rect"], emissive)
	_lights[_map_id] = light
	var by_theme: Dictionary = {}
	for o: Dictionary in (e["data"] as Resource).objects:
		var did2: String = _offer_id(_map_id, o)
		if did2 == "":
			continue
		if not by_theme.has(did2):
			by_theme[did2] = []
		(by_theme[did2] as Array).append(o)
	for did3: String in by_theme:
		var sub: Resource = DungeonDataScript.new()
		sub.objects = by_theme[did3]
		var props := DungeonPropsScript.new()
		props.setup(did3, sub)
		root.add_child(props)
		props.light = light
		for o2: Dictionary in sub.objects:
			for field: String in ["gate_key", "node_key", "chest_key", "trap_key", "lever_key", "barrel_key"]:
				if str(o2.get(field, "")) != "":
					_map_props[str(o2[field])] = props
			if str(o2.get("type", "")) == "kaynak":
				var res: String = str(DungeonDefsScript.by_id(did3).get("resource", ""))
				var col: Color = DungeonDefsScript.RESOURCES.get(res, {}).get("color", Color.WHITE)
				var r: Rect2 = o2["rect"]
				light.add_keyed_light(str(o2.get("node_key", "")), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.35), 84.0, col, 0.95)


## Görsel örneği: harita kipinde nesne anahtarına göre (tema başına örnek), değilse zindanın kendi örneği.
func _props_for(key: String) -> Node:
	var p: Variant = _map_props.get(key)
	if p != null:
		return p
	return _props.get(key.get_slice(":", 0))


## Sunak teklifi / kaynak türü / görsel tablosu için zindan kimliği: haritada nesnenin teması, zindanda kendisi.
func _offer_id(id: String, o: Dictionary) -> String:
	if id != _map_id or _map_id == "":
		return id
	return str(MAP_THEME_DUNGEON.get(str((o.get("props", {}) as Dictionary).get("tema", "")), ""))


func _resource_of(id: String, o: Dictionary) -> String:
	return str(DungeonDefsScript.by_id(_offer_id(id, o)).get("resource", ""))


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
	var entries: Array[Dictionary] = DungeonWorldScript.dungeons().duplicate()
	if _map_id != "":
		entries.append(DungeonWorldScript.map_entry())
	for e: Dictionary in entries:
		var id: String = str(e["id"])
		var props: Node = _props.get(id)
		var rect: Rect2 = e["rect"]
		var local_in: bool = _player != null and (str(_player.get("in_dungeon")) == id or (id == _map_id and str(_player.get("in_dungeon")) == ""))
		if not local_in and not host and props == null:
			continue
		for o: Dictionary in (e["data"] as Resource).objects:
			if str(o.get("type", "")) != "tuzak":
				continue
			var key: String = str(o.get("trap_key", ""))
			var lv: float = trap_level(key, t)
			var tp: Node = _props_for(key) if id == _map_id else props
			if tp != null and tp.is_visible_in_tree():
				tp.set_trap_level(key, lv)
			if lv < 0.99:
				continue
			var wr := Rect2(rect.position + (o["rect"] as Rect2).position, (o["rect"] as Rect2).size)
			if local_in and int(_trap_hit.get(key, -1)) != cycle and _player.get("is_dead") != true and wr.has_point(_player.global_position + Vector2(0, DungeonWorldScript.FEET_SHIFT)):
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
	_notice("fail", Loc.t("%s SENİ GÖRDÜ!") % title.to_upper(), "Kaç! Kapıları indir, gölgelere saklan, çıkışa koş.")
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
	return {"loaded": _roots.keys(), "gates_closed": gate_until.keys(), "nodes_down": node_until.keys(),
			"chests": chest_opened.keys(), "prompt": _prompt.text if _prompt.visible else ""}
