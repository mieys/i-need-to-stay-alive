extends Node

## ZİNDAN ZEMİN SHADER'I (madde 449, prototip "C - Döşeme Taşları"): haritanın zemin katmanlarına (FLOOR_LAYERS) tek ShaderMaterial takar.
## Maske haritanın kendisinden (hücre başına 1 piksel: R duvar, G su - DungeonData.cells) - ek dosya yok, her zindan
## haritasında çalışır. Profil bayrağı "zemin_tasi" açık haritalarda DungeonManager harita kipi kurar (dungeon_manager.gd _setup_map).
## Grafik > Zemin ayrıntısı kapalıyken taş derzleri kapanır, duvar dibi gölgesi kalır (water_fx.gd ile aynı ayar).

const FloorShader := preload("res://shaders/zindan_zemin.gdshader")
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const FLOOR_LAYERS: Array[String] = ["Zemin", "Zemin ayrıntı", "Zemin desen", "Zemin süsü"]

var material: ShaderMaterial = null


## R duvar, G su. (Taş derzi hangi piksele işler: shader'da kum rengi - hücre başına döşeli maskesi kaldırıldı.)
static func mask_texture(data: Resource) -> ImageTexture:
	var sz: Vector2i = data.size
	var cells: PackedByteArray = data.cells
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RG8)
	for y in range(sz.y):
		for x in range(sz.x):
			var c: int = cells[y * sz.x + x]
			if c == DungeonDataScript.CELL_WALL:
				img.set_pixel(x, y, Color(1.0, 0.0, 0.0))
			elif c == DungeonDataScript.CELL_WATER:
				img.set_pixel(x, y, Color(0.0, 1.0, 0.0))
	return ImageTexture.create_from_image(img)


## root: harita kökü (zemin katmanları doğrudan çocukları), data: DungeonData. Takılan katman sayısını döner.
func setup(root: Node2D, data: Resource) -> int:
	name = "ZindanZemin"
	material = ShaderMaterial.new()
	material.shader = FloorShader
	material.set_shader_parameter("zemin_maske", mask_texture(data))
	material.set_shader_parameter("harita_origin", root.global_position)
	material.set_shader_parameter("harita_hucre", Vector2(data.size))
	var prof: Dictionary = preload("res://scripts/map_profiles.gd").current()
	if prof.has("zemin_rengi"): ## setin zemin rengi (Dungeon1 mavi-gri); yoksa shader varsayılanı (Dungeon3 kum)
		var c: Color = prof["zemin_rengi"]
		material.set_shader_parameter("kum_renk", Vector3(c.r, c.g, c.b))
	var n: int = 0
	for c: Node in root.get_children():
		if c is TileMapLayer and FLOOR_LAYERS.has(String(c.name)) and (c as CanvasItem).material == null:
			(c as CanvasItem).material = material
			n += 1
	_apply()
	return n


func _ready() -> void:
	UISound.graphics_changed.connect(_apply)


func _apply() -> void:
	if material != null:
		material.set_shader_parameter("tas_acik", UISound.gfx_ground_detail)


func _exit_tree() -> void:
	if UISound.graphics_changed.is_connected(_apply):
		UISound.graphics_changed.disconnect(_apply)
