extends Node

## TAKIM ÜSSÜ KAMPI görünüşü (PvPvE, madde 607; kullanıcının kamp.zip paketi, tools/kamp/gen_kamp.py -> kamp_yerlesim.gd + assets/map/kamp/).
## - Parçalar Main'in DOĞRUDAN çocukları (çadır, kamp ateşi, kütük, kaya, kamp karakterleri): "ysort_props" ile yaratık / evcil ayak sırasına girer
##   (main.gd CREATURE_SORT_GROUPS) ve totem_base.gd DERİNLİK yöntemiyle arkasında karakter duran parça z 2'ye çıkar (oyuncu z 1'in üstü,
##   ağaç / ev ön kopyası z 3'ün altı). Derinlik denetimi tek düğümde, birkaç karede bir, bütün parçalar için.
## - Çadırlar "move_blockers" çemberi (player.gd _block_movement_into_blockers): oyuncu çadırın içinden geçemez. Diğer parçalar geçilir.
## - Zemin / ağaç çizilmez: kamp kurulduğu haritanın zeminine oturur. Animasyonlu parçalar paketin 150 ms karesiyle döner (rastgele başlangıç).
## - Kozmetik: her makine kendi kurar (konum pvp_net.gd ile host'tan), ağ trafiği yok.

const LayoutScript := preload("res://scripts/pvp/kamp_yerlesim.gd")
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")

const DEPTH_SORT_GROUP := "ysort_props"
const DEPTH_Z := 0
const DEPTH_FRONT_Z := 2
const DEPTH_EVERY := 3

var center: Vector2 = Vector2.ZERO
var team: int = 0
var _pieces: Array = [] ## [{"node": CanvasItem, "x": orta x, "base": ayak y, "top": üst y, "half": yarım genişlik}]
var _blockers: Array[Node2D] = []


## main: parçaların ekleneceği düğüm (Main). Parçalar bu düğümün silinmesiyle değil, _exit_tree'de temizlenir.
## max_r > 0: dar yer (zindan) - yalnız ayak ortası + yarım genişliğinin yarısı bu yarıçapa sığan parçalar (kamp ateşi hep) kurulur.
func build(main: Node, at: Vector2, team_index: int, max_r: float = 0.0) -> void:
	center = at
	team = team_index
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0 + at.y * 13.0)
	for e: Dictionary in LayoutScript.PARCALAR:
		var tex: Texture2D = load(LayoutScript.DIR + str(e["dosya"])) as Texture2D
		if tex == null:
			push_warning("Kamp parçası yüklenemedi: " + str(e["dosya"]))
			continue
		var frames: int = int(e["kare"])
		var w: float = float(e["w"])
		var h: float = float(e["h"])
		if max_r > 0.0 and str(e["tur"]) != "ates" and not fits(e, max_r):
			continue
		var node: Node2D
		if frames > 1:
			var sf := SpriteFrames.new()
			sf.set_animation_loop(&"default", true)
			sf.set_animation_speed(&"default", 1000.0 / float(LayoutScript.KARE_MS))
			for f in range(frames):
				var at_tex := AtlasTexture.new()
				at_tex.atlas = tex
				at_tex.region = Rect2(f * w, 0.0, w, h)
				sf.add_frame(&"default", at_tex)
			var a := AnimatedSprite2D.new()
			a.sprite_frames = sf
			a.centered = false
			a.play(&"default")
			a.frame = rng.randi() % frames
			node = a
		else:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			node = s
		node.name = "Kamp_%d_%s" % [team, str(e["ad"])]
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.z_index = DEPTH_Z
		node.position = at + Vector2(float(e["x"]), float(e["y"]))
		node.add_to_group(DEPTH_SORT_GROUP)
		node.set_meta("_foot_visual", node)
		node.set_meta("_foot_local", float(e["ayak"]))
		main.add_child(node)
		_pieces.append({"node": node, "x": node.position.x + w * 0.5, "base": node.position.y + float(e["ayak"]),
				"top": node.position.y, "half": w * 0.5})
		if e.has("engel_r"):
			var b := TentBlocker.new()
			b.name = "KampEngel_%d_%s" % [team, str(e["ad"])]
			b.block_radius = float(e["engel_r"])
			b.position = Vector2(node.position.x + w * 0.5, node.position.y + float(e["ayak"]) - b.block_radius * 0.6)
			main.add_child(b)
			_blockers.append(b)


## Parça dar kampa sığar mı (ayak ortasının kamp merkezine uzaklığı + yarım genişliğin yarısı).
static func fits(e: Dictionary, max_r: float) -> bool:
	var foot := Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["ayak"]))
	return foot.length() + float(e["w"]) * 0.25 <= max_r


func piece_count() -> int:
	return _pieces.size()


func _process(_delta: float) -> void:
	if (Engine.get_process_frames() + team) % DEPTH_EVERY != 0 or _pieces.is_empty():
		return
	var chars: Array[Vector4] = DepthOccludersScript.collect_characters(get_tree())
	for p: Dictionary in _pieces:
		var node: CanvasItem = p["node"]
		if not is_instance_valid(node):
			continue
		var behind: bool = false
		for c: Vector4 in chars:
			if c.y < float(p["base"]) and c.y > float(p["top"]) and absf(c.x - float(p["x"])) < float(p["half"]) + c.z:
				behind = true
				break
		node.z_index = DEPTH_FRONT_Z if behind else DEPTH_Z


func _exit_tree() -> void:
	for p: Dictionary in _pieces:
		var node: Node = p["node"]
		if is_instance_valid(node):
			node.queue_free()
	for b: Node2D in _blockers:
		if is_instance_valid(b):
			b.queue_free()
	_pieces.clear()
	_blockers.clear()


## Çadır çarpışma çemberi ("move_blockers" sözleşmesi, player.gd _block_movement_into_blockers).
class TentBlocker extends Node2D:
	var block_radius: float = 24.0

	func _ready() -> void:
		add_to_group("move_blockers")

	func block_center() -> Vector2:
		return global_position
