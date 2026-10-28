extends Resource
class_name DungeonData

## ZİNDAN VERİSİ (madde 373): tools/zindan/bake_zindan.gd TMX'ten (harita/zindan/<id>.tmx) üretir - elle düzenleme, TMX'i Tiled'da
## düzenleyip yeniden bake et. Görsel sahne ayrı: scenes/zindan/<id>_baked.tscn (oyuncu zindana inince yüklenir).
## cells: size.x * size.y bayt, hücre kodu (CELL_*): TMX "Engel" katmanı (0 duvar, 1 nesne, 2 saklanma, 3 kapı işaretleri).
## objects: TMX "Etkileşimler" nesne katmanı - {"type", "name", "rect": Rect2 (zindan yerel px), "props": {..}}.

const CELL_EMPTY := 0
const CELL_WALL := 1 ## duvar/kaya: hareket + görüş + mermi
const CELL_SOLID := 2 ## nesne: yalnız hareket
const CELL_HIDE := 3 ## saklanma (yürünür)
const CELL_GATE := 4 ## kapanan kapı (açıkken yürünür)
const CELL_WATER := 5 ## su / kan kanalı: yalnız hareket (nesne gibi), minimapte su rengi (madde 375)

@export var id: String = ""
@export var title: String = ""
@export var size: Vector2i = Vector2i.ZERO
@export var cells: PackedByteArray = PackedByteArray()
@export var objects: Array = []


func cell_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return CELL_WALL
	return cells[c.y * size.x + c.x]


func objects_of(type: String) -> Array:
	var out: Array = []
	for o: Dictionary in objects:
		if str(o.get("type", "")) == type:
			out.append(o)
	return out
