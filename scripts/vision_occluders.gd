extends RefCounted

## Görüşü ENGELLEYEN harita karolarının (orman/uçurum duvarı, bkz.
## GameManager.get_forest_layer) hafif bir ızgara kopyası - vision_fog.gd
## tarafından iki yerde kullanılır:
##   - CPU: düşman/mermi gizleme için is_ray_blocked() (bkz. _target_visibility),
##   - GPU: vision_fog_mask.gdshader'a R8 bir texture olarak (make_texture) verilir,
##     shader AYNI ışın algoritmasını piksel başına çalıştırıp duvarın arkasını
##     görüş dışı sayar (normal sis: soluk arazi, gizli düşman - kapkara DEĞİL).
## Izgara TileMapLayer'dan okunduğu için harita Tiled'da düzenlenip yeniden bake
## edilince otomatik güncel kalır (bkz. GameManager'daki su/ev karo sorgusu ile aynı gerekçe).
##
## ışın kuralı (duvarın KENDİSİ görünür, ARKASI görünmez): ışın kaynaktan hedefe
## karo karo (DDA) yürür; bir engel karosuna GİRİLİP sonra engel olmayan bir karoya
## ÇIKILIRSA (ve duvarın içinden en az MIN_WALL_CROSSING karo yol katedilmişse - köşe
## sürtünmesi sayılmaz) duvarın arkasındayız -> engelli. Hedef engel karosunun içindeyse
## (duvarın yüzü) ışın hiç çıkmadığı için engelli SAYILMAZ; kaynağın kendi karosu yok sayılır.
## Böylece kaya duvar kalınlığı ne olursa olsun (saçak + kaya + ...) tamamen görünür,
## sadece ardındaki dünya "görüş dışı" olur. GLSL karşılığı: vision_fog_mask.gdshader ray_blocked().

## Işının atlayabileceği en fazla karo adımı (görüş menzili ~35 karo yatay + ~25 dikey).
## vision_fog_mask.gdshader'daki döngü sınırıyla AYNI olmalı.
const MAX_RAY_STEPS := 96

## Işın, bir duvarın içinden en az bu kadar karo yol kat etmedikçe "duvarın arkası"
## sayılmaz. Sebep: duvarın merdiven gibi basamaklı kenarındaki tek karoluk çıkıntıların
## KÖŞESİNE sürtünen ışınlar da görüşü kesip duvar dibinde uzun, sert kenarlı, doğal
## olmayan gölge çizgileri çıkarıyordu (kullanıcı bildirimi: "duvarda çok keskin çizgiler
## var, anormal gözüküyor"). Gerçek duvar gövdesi (>= ~1 karo kalınlık) yine keser.
## vision_fog_mask.gdshader'a uniform olarak verilir - TEK kaynak burası.
const MIN_WALL_CROSSING := 0.75

var _cells: PackedByteArray = PackedByteArray()
var _grid_origin: Vector2i = Vector2i.ZERO
var _grid_size: Vector2i = Vector2i.ONE
var _world_origin: Vector2 = Vector2.ZERO
var _cell_size: float = 16.0
var _texture: ImageTexture = null


## `layer`'daki DOLU hücrelerin HEPSİ engel olur (çarpışmayla aynı küme, bkz.
## GameManager.is_position_blocked_by_forest). Kullanıcı isteği: "küçük parçaların
## görüşü engellememe sınırını kaldır, onları haritadan kaldırdım, bu layerdaki HER ŞEY
## görüşü engellesin" - eskiden burada bitişik hücre kümelerinden küçük olanlar (taş,
## mantar, çalı gibi dağınık dekorlar) eleniyordu; o filtre kaldırıldı. Boş/null katmanda
## ızgara boş kalır.
func build(layer: TileMapLayer) -> void:
	_cells = PackedByteArray()
	_texture = null
	if layer == null or layer.tile_set == null:
		return
	var used: Array[Vector2i] = layer.get_used_cells()
	if used.is_empty():
		return
	var rect := Rect2i(used[0], Vector2i.ONE)
	for cell: Vector2i in used:
		rect = rect.expand(cell)
	## 1 karo boşluk payı: sınırdaki hücrelerin komşusu ızgara dışına taşmasın.
	_grid_origin = rect.position - Vector2i.ONE
	_grid_size = rect.size + Vector2i(2, 2)
	_world_origin = layer.to_global(Vector2.ZERO)
	_cell_size = layer.to_global(Vector2(layer.tile_set.tile_size.x, 0.0)).x - _world_origin.x
	_cells.resize(_grid_size.x * _grid_size.y)
	for cell: Vector2i in used:
		var rel: Vector2i = cell - _grid_origin
		_cells[rel.y * _grid_size.x + rel.x] = 255


func is_empty() -> bool:
	return _cells.is_empty()


func get_grid_origin() -> Vector2i:
	return _grid_origin


func get_grid_size() -> Vector2i:
	return _grid_size


func get_world_origin() -> Vector2:
	return _world_origin


func get_cell_size() -> float:
	return _cell_size


func world_to_cell_f(world_pos: Vector2) -> Vector2:
	return (world_pos - _world_origin) / _cell_size


func blocks_cell(cell: Vector2i) -> bool:
	var rel: Vector2i = cell - _grid_origin
	if rel.x < 0 or rel.y < 0 or rel.x >= _grid_size.x or rel.y >= _grid_size.y:
		return false
	return _cells[rel.y * _grid_size.x + rel.x] != 0


func blocks_world_pos(world_pos: Vector2) -> bool:
	return blocks_cell(Vector2i(world_to_cell_f(world_pos).floor()))


## Izgaranın shader'a verilen hali: 1 texel = 1 harita karosu, R8 (255 = engel).
func make_texture() -> ImageTexture:
	if _cells.is_empty():
		return null
	if _texture == null:
		_texture = ImageTexture.create_from_image(Image.create_from_data(_grid_size.x, _grid_size.y, false, Image.FORMAT_R8, _cells))
	return _texture


## `from_world`'den `to_world`'e görüş, bir duvarın ARKASINDAN geçiyorsa true (kural
## için dosya başındaki nota bak).
func is_ray_blocked(from_world: Vector2, to_world: Vector2) -> bool:
	if _cells.is_empty():
		return false
	var a: Vector2 = world_to_cell_f(from_world)
	var b: Vector2 = world_to_cell_f(to_world)
	var d: Vector2 = b - a
	var cell := Vector2i(a.floor())
	var end_cell := Vector2i(b.floor())
	var step := Vector2i(1 if d.x > 0.0 else -1, 1 if d.y > 0.0 else -1)
	var inv := Vector2(1.0 / maxf(absf(d.x), 0.000001), 1.0 / maxf(absf(d.y), 0.000001))
	var to_edge := Vector2(
		(cell.x + 1 - a.x) if d.x > 0.0 else (a.x - cell.x),
		(cell.y + 1 - a.y) if d.y > 0.0 else (a.y - cell.y))
	var t_max: Vector2 = to_edge * inv
	var ray_length: float = d.length()
	var entered: bool = false
	var t_enter: float = 0.0
	for _i: int in range(MAX_RAY_STEPS):
		if cell == end_cell or minf(t_max.x, t_max.y) > 1.0:
			break
		var t_cross: float = minf(t_max.x, t_max.y)
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += inv.x
		else:
			cell.y += step.y
			t_max.y += inv.y
		if blocks_cell(cell):
			if not entered:
				entered = true
				t_enter = t_cross
		elif entered:
			## Duvardan çıkış: yeterince kalın bir gövdeden mi geçtik, yoksa köşesine mi sürtündük?
			if (t_cross - t_enter) * ray_length >= MIN_WALL_CROSSING:
				return true
			entered = false
	return false
