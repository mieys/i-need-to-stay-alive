extends Node2D
class_name DungeonLight

## ZİNDAN IŞIĞI (madde 373): cozy ev ışığıyla (cozy_ev_light.gd, madde 311) aynı Godot 2D modeli - ortam = CanvasModulate (zindanın kendi rengi,
## gün saatine göre hafif: gece biraz daha karanlık), kaynaklar = TMX "isik" nesneleri (meşale / mum / ruh alevi, üretici koyar) PointLight2D +
## yumuşak hale dokusu (titreşim). Işık veren karolar (mum/meşale/heykel alevi...) unshaded: karanlıkta da parlak. Zindandaki her oyuncunun etrafında
## küçük bir FENER (kendi rengi) - karanlıkta kendi çevresini görür, yaratıklar ışığın dışında sezilir.
## Zindan kökünün çocuğu: kök gizlenince (kamera zindanda değilken) CanvasModulate ve ışıklar kendiliğinden kapanır, dış dünya etkilenmez.
## Işık bütçesi: Godot 2D bir öğeyi en çok 16 ışıkla aydınlatır -> karo katmanları quadrant 8 (cozy ev tuzağı); kameradan uzak ışıklar kapalı.

const AtmosphereMath := preload("res://scripts/atmosphere_math.gd")
const CozyEvLightScript := preload("res://scripts/cozy_ev_light.gd")
const HALO_TEX: Texture2D = preload("res://assets/fx/cozy_ev_isik/hale.png")
const HALO_TEX_RADIUS := 256.0
const LIGHT_QUADRANT := 8
const ACTIVE_RANGE := 760.0 ## kameradan bu kadar uzaktaki ışık kapalı (px)
const LANTERN_RADIUS := 92.0
const LANTERN_ENERGY := 0.62
const LANTERN_OFFSET := Vector2(0.0, -6.0)
const LANTERN_GROUPS: Array[StringName] = [&"player", &"remote_players"]
const LANTERN_CHECK := 0.4
const OVERLAY_CHECK := 0.5

var ambient: CanvasModulate = null
var dungeon_id: String = ""
var _ambient_day: Color = Color(0.4, 0.4, 0.45)
var _ambient_night: Color = Color(0.32, 0.32, 0.38)
var _lantern_color: Color = Color(0.9, 0.95, 1.0)
var _sources: Array[Dictionary] = [] ## {"light", "energy", "phase", "pos"}
var _lanterns: Dictionary = {} ## sahip instance_id -> PointLight2D
var _t: float = 0.0
var _cull_acc: float = 0.0
var _lantern_acc: float = 0.0
var _overlay_acc: float = 0.0
var _rect: Rect2 = Rect2()
## Kaynak düğümleri (ruh kandili / et kesesi / kristal) gibi açılıp kapanan ışıklar: anahtar -> {"light", "energy"}.
var _keyed: Dictionary = {}


func setup(root: Node2D, def: Dictionary, data: Resource, rect: Rect2, emissive_textures: Array) -> void:
	name = "ZindanIsik"
	dungeon_id = str(def.get("id", ""))
	_rect = rect
	_ambient_day = def.get("ambient_day", _ambient_day)
	_ambient_night = def.get("ambient_night", _ambient_night)
	_lantern_color = def.get("player_light", _lantern_color)
	ambient = CanvasModulate.new()
	ambient.name = "ZindanOrtam"
	add_child(ambient)
	for child: Node in root.get_children():
		if child is TileMapLayer:
			(child as TileMapLayer).rendering_quadrant_size = LIGHT_QUADRANT
	_mark_emissive(root, emissive_textures)
	for o: Dictionary in data.objects:
		if str(o.get("type", "")) != "isik":
			continue
		var p: Dictionary = o.get("props", {})
		var r: Rect2 = o["rect"]
		var col: Color = _parse_color(str(p.get("renk", "1,1,1")))
		var rad: float = float(p.get("r", 96))
		var l := _halo(r.position, rad, col)
		_sources.append({"light": l, "energy": float(p.get("g", 1.0)), "phase": randf() * TAU if int(p.get("titre", 1)) == 1 else NAN,
				"pos": root.position + r.position})
	_apply()


## Açılıp kapanan ışık (kaynak düğümü): local = zindan yerel px.
func add_keyed_light(key: String, local: Vector2, radius: float, color: Color, energy: float) -> void:
	var l := _halo(local, radius, color)
	_keyed[key] = {"light": l, "energy": energy}
	l.energy = energy


func set_keyed_light(key: String, on: bool) -> void:
	var k: Variant = _keyed.get(key)
	if k == null:
		return
	var l: PointLight2D = (k as Dictionary)["light"]
	l.enabled = on
	l.energy = float((k as Dictionary)["energy"]) if on else 0.0


func _halo(local: Vector2, radius: float, color: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = HALO_TEX
	l.position = local
	l.scale = Vector2.ONE * (radius / HALO_TEX_RADIUS)
	l.color = color
	l.energy = 1.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(l)
	return l


static func _parse_color(s: String) -> Color:
	var parts: PackedStringArray = s.split(",")
	if parts.size() < 3:
		return Color.WHITE
	return Color(float(parts[0]), float(parts[1]), float(parts[2]))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_clear_lanterns()
		return
	_t += delta
	_apply()
	_cull_acc -= delta
	if _cull_acc <= 0.0:
		_cull_acc = 0.25
		_cull()
	_lantern_acc -= delta
	if _lantern_acc <= 0.0:
		_lantern_acc = LANTERN_CHECK
		_update_lanterns()
	_overlay_acc -= delta
	if _overlay_acc <= 0.0:
		_overlay_acc = OVERLAY_CHECK
		_keep_overlays_unlit()


func _darkness() -> float:
	var atmo: Node = get_tree().get_first_node_in_group("atmosphere") if is_inside_tree() else null
	if atmo != null and "cycle_time" in atmo:
		return AtmosphereMath.darkness(float(atmo.get("cycle_time")))
	return 0.5


func _apply() -> void:
	ambient.color = _ambient_day.lerp(_ambient_night, _darkness())
	var ms: float = _t * 1000.0
	for s: Dictionary in _sources:
		var l: PointLight2D = s["light"]
		if not l.enabled:
			continue
		var e: float = float(s["energy"])
		var ph: float = s["phase"]
		if not is_nan(ph):
			var f: float = 0.07 * sin(ms / 240.0 + ph) + 0.04 * sin(ms / 89.0 + 1.3 + ph * 1.7)
			l.texture_scale = 1.0 + f
			e *= 1.0 + 1.3 * f
		l.energy = e


func _cull() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var c: Vector2 = cam.get_screen_center_position()
	for s: Dictionary in _sources:
		(s["light"] as PointLight2D).enabled = (s["pos"] as Vector2).distance_to(c) < ACTIVE_RANGE


## Zindandaki oyuncular (yerel + kuklalar) fener taşır.
func _update_lanterns() -> void:
	var alive: Dictionary = {}
	for g: StringName in LANTERN_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(g):
			var b := n as Node2D
			if b == null or not is_instance_valid(b) or not _rect.has_point(b.global_position):
				continue
			var id: int = b.get_instance_id()
			alive[id] = true
			if not _lanterns.has(id) or not is_instance_valid(_lanterns[id]):
				var l := PointLight2D.new()
				l.name = "ZindanFeneri"
				l.texture = HALO_TEX
				l.color = _lantern_color
				l.energy = LANTERN_ENERGY
				l.blend_mode = Light2D.BLEND_MODE_ADD
				b.add_child(l)
				## oyuncu kökü 0,5 ölçekli: yarıçap dünya px'inde kalsın
				var gs: float = maxf(0.01, absf(b.global_scale.x))
				l.scale = Vector2.ONE * (LANTERN_RADIUS / HALO_TEX_RADIUS / gs)
				l.position = LANTERN_OFFSET / gs
				_lanterns[id] = l
	for id: int in _lanterns.keys():
		if not alive.has(id):
			var l: Variant = _lanterns[id]
			if l != null and is_instance_valid(l):
				(l as Node).queue_free()
			_lanterns.erase(id)


func _clear_lanterns() -> void:
	if _lanterns.is_empty():
		return
	for id: int in _lanterns.keys():
		var l: Variant = _lanterns[id]
		if l != null and is_instance_valid(l):
			(l as Node).queue_free()
	_lanterns.clear()


func _exit_tree() -> void:
	_clear_lanterns()


## Işık veren karolar (mum, meşale, heykel alevi, kristal...): unshaded -> karanlıkta kendi parlaklığında.
func _mark_emissive(root: Node2D, textures: Array) -> void:
	if textures.is_empty():
		return
	var mat: CanvasItemMaterial = CozyEvLightScript.unlit_material()
	var done: Dictionary = {}
	for child: Node in root.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var ts: TileSet = layer.tile_set
		if done.has(ts.get_instance_id()):
			continue
		done[ts.get_instance_id()] = true
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
			if src == null or src.texture == null or not textures.has(src.texture.resource_path.get_file()):
				continue
			for t in src.get_tiles_count():
				var coords: Vector2i = src.get_tile_id(t)
				var td: TileData = src.get_tile_data(coords, 0)
				if td != null:
					td.material = mat


## Başüstü yazıları / can çubuğu karanlıkta okunur kalsın (cozy_ev_light.gd ile aynı kural).
func _keep_overlays_unlit() -> void:
	var mat: CanvasItemMaterial = CozyEvLightScript.unlit_material()
	for g: StringName in [&"player", &"remote_players", &"npc_actors"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			for c: Node in n.get_children():
				var ci := c as CanvasItem
				if ci == null or ci.has_meta(&"cozy_unlit"):
					continue
				if not ["NameLabel", "OverheadBar", "DownedTimerLabel"].has(String(ci.name)):
					continue
				ci.set_meta(&"cozy_unlit", true)
				if ci.material == null:
					ci.material = mat
				for cc: Node in ci.get_children():
					if cc is CanvasItem and (cc as CanvasItem).material == null:
						(cc as CanvasItem).use_parent_material = true


func light_count() -> int:
	return _sources.size()
