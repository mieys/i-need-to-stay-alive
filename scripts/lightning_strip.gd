extends RefCounted

## Yıldırım Asası'nın ışını VE zincir sıçraması için ORTAK piksel şimşek çizici (kullanıcı isteği 2026-09-25: "yıldırım
## asasının yıldırım efektini yeniden tasarlamanı istiyorum pixel tarzda ... spritesheete dönüştür ki performans düşmesin").
## tools/gen_lightning_staff_fx.py "bolt_tiles.png": uçları dikişsiz bağlanan 24x15'lik şimşek karoları. İki nokta arası
## bu karolarla döşenir (her karo tek draw_texture_rect_region), karo varyantları ve dikey aynalama belirli aralıklarla
## rastgele değiştirilir -> cızırdayan, piksel tarzda şimşek; ışın başına ~10 çizim komutu (eskiden antialias'lı çizgi
## zikzakları + her karede script'te hesaplanan kıvılcım parçacıkları). fx_lightning_beam.gd ve fx_lightning_chain.gd
## ikisi de bunu kullanır (formül/karo boyu tek yerde).

const TILES := preload("res://assets/fx/lightning_staff/bolt_tiles.png")
const TILE_W := 24.0
const TILE_H := 15.0
const MID := 7.0 ## karonun giriş/çıkış satırı
const VARIANTS := 6


## count karo için rastgele [varyant, aynala] listesi (flicker'da çağrılır).
static func reroll(count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(maxi(count, 1))
	for i in range(out.size()):
		out[i] = randi() % VARIANTS + (VARIANTS if randf() < 0.5 else 0) ## >= VARIANTS: dikey aynalı
	return out


static func tile_count(from: Vector2, to: Vector2) -> int:
	return int(ceil(from.distance_to(to) / TILE_W))


## ci'nin YEREL koordinatlarında from -> to arasına şimşeği çizer. tiles: reroll() çıktısı (eksikse tekrar kullanılır).
static func draw(ci: CanvasItem, from: Vector2, to: Vector2, tiles: PackedInt32Array, tint: Color = Color.WHITE) -> void:
	var length: float = from.distance_to(to)
	if length < 1.0 or tiles.is_empty():
		return
	var dir: Vector2 = (to - from) / length
	var angle: float = dir.angle()
	var n: int = int(ceil(length / TILE_W))
	for i in range(n):
		var start: Vector2 = from + dir * (TILE_W * i)
		var w: float = minf(TILE_W, length - TILE_W * i)
		var code: int = tiles[i % tiles.size()]
		var variant: int = code % VARIANTS
		var flip: float = -1.0 if code >= VARIANTS else 1.0
		ci.draw_set_transform(start, angle, Vector2(1.0, flip))
		ci.draw_texture_rect_region(TILES, Rect2(0.0, -MID, w, TILE_H), Rect2(variant * TILE_W, 0.0, w, TILE_H), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
