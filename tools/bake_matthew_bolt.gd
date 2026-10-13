extends SceneTree

## Matthew Q şimşeğinin döşeme sayfasını pişirir (madde 99): assets/fx/matthew_lightning/bolt_tiles.png.
## Çalıştırma:  Godot --headless --path . -s res://tools/bake_matthew_bolt.gd   (sonra bir kez:  Godot --headless --path . --import)
## Biçim kuralları AYNEN eski fx_matthew_bolt.gd'deki gibi (ML.zig / cells_of / stamp_bolt, evre parametreleri aynı) - fark sadece
## parçaların bir kez, düz (sağa bakan) olarak pişirilmesi. Parçalar yan yana dikişsiz otursun diye:
##  - her parçanın yolu kenarlara 3 px'lik DÜZ kütükle girer/çıkar (kenardan ±3 px içinde yol orta satırda),
##  - kare dışına taşan kısım yolun gerçek devamıyla (düz uzatma) basılıp KIRPILIR - komşu parçanın çekirdek/kontur payı kenar sütunlarında doğru çıkar.
## Evre alanı: 0 öncü çizgi, 1 kalın + çatal, 2 titrek, 3 kopuk, 4 kesik çizgiler, 5 kıvılcım.

const ML := preload("res://scripts/matthew_lightning.gd")
const OUT := "res://assets/fx/matthew_lightning/bolt_tiles.png"
const L: int = ML.BOLT_TILE_LEN
const STUB: float = 3.0
const TAIL: float = 16.0 ## kırpılan uzatma: sivrilme (taper en çok 5, geniş halka 2 x taper) kare içine girmesin


func _init() -> void:
	var w: int = ML.BOLT_TILE_W
	var h: int = ML.BOLT_TILE_H
	var rows: int = ML.BOLT_ROW_END + ML.BOLT_END_VARIANTS
	var img := Image.create(ML.BOLT_STAGES * w, rows * h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for row in range(rows):
		var kind: String = "start" if row < ML.BOLT_ROW_MID else ("mid" if row < ML.BOLT_ROW_END else "end")
		var variant: int = row - (0 if kind == "start" else (ML.BOLT_ROW_MID if kind == "mid" else ML.BOLT_ROW_END))
		for stage in range(ML.BOLT_STAGES):
			_bake_tile(img, row, stage, kind, variant)
	var err: Error = img.save_png(OUT)
	if err != OK:
		printerr("bolt_tiles.png yazılamadı: ", err)
		quit(1)
		return
	print("bolt_tiles.png yazıldı: ", img.get_width(), "x", img.get_height())
	quit(0)


func _bake_tile(img: Image, row: int, stage: int, kind: String, variant: int) -> void:
	var seed_base: int = 9001 + row * 131
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + mini(stage, 2) * 13 ## eski şimşekle aynı: biçim evre 2'den sonra sabit, sadece söner
	var salt: float = float(seed_base % 11)
	var pts := PackedVector2Array()
	match kind:
		"start":
			pts = ML.zig(rng, Vector2.ZERO, Vector2(float(L) - STUB, 0.0), 11.0, 6.5)
			pts.append(Vector2(float(L) + TAIL, 0.0))
		"mid":
			pts.append(Vector2(-TAIL, 0.0))
			pts.append_array(ML.zig(rng, Vector2(STUB, 0.0), Vector2(float(L) - STUB, 0.0), 11.0, 6.5))
			pts.append(Vector2(float(L) + TAIL, 0.0))
		_:
			pts.append(Vector2(-TAIL, 0.0))
			pts.append_array(ML.zig(rng, Vector2(STUB, 0.0), Vector2(float(L) - 1.0, 0.0), 11.0, 6.5))
	var pix: Array[Vector2i] = ML.cells_of(pts)
	var taper_of: Array[int] = [0, 3, 4, 5, 0, 0]
	var tp: int = 0 if kind == "mid" else taper_of[stage]
	var cells: Dictionary = {}
	## Çatal: yalnız çatallı orta parçalarda, evre 1-2'de; kaynak = ilk gerçek köşe (x 6..18), parça içinde kalır.
	if kind == "mid" and stage in [1, 2] and ML.BOLT_FORK_VARIANTS.has(variant):
		var src: Vector2 = Vector2(-1.0, 0.0)
		for p: Vector2 in pts:
			if p.x >= 6.0 and p.x <= 18.0 and p.y != 0.0:
				src = p
				break
		if src.x > 0.0:
			var side: float = -1.0 if variant == ML.BOLT_FORK_VARIANTS[0] else 1.0
			var ang: float = side * rng.randf_range(0.45, 0.95)
			var ln: float = rng.randf_range(10.0, 20.0) if stage == 1 else rng.randf_range(8.0, 14.0)
			var to: Vector2 = src + Vector2.RIGHT.rotated(ang) * ln
			ML.stamp_bolt(cells, ML.cells_of(ML.zig(rng, src, to, 4.0, 2.0)), 1, 2)
	match stage:
		0:
			ML.stamp_bolt(cells, pix, 1, 0, 3, false)
		1:
			ML.stamp_bolt(cells, pix, 5, tp)
		2:
			ML.stamp_bolt(cells, pix, 3, tp)
		3:
			ML.stamp_bolt(cells, pix, 3, tp, 3, true, 0.2, salt)
		4:
			ML.stamp_bolt(cells, pix, 1, 0, 3, false, 0.52, salt)
		_:
			ML.stamp_bolt(cells, pix, 1, 0, 2, false, 0.8, salt)
	if kind == "start" and stage <= 1: ## elde atış parlaması (eski şimşekle aynı)
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i.ZERO]:
			cells[o] = 4
		if stage == 1:
			for o: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				cells[o] = 3
	var w: int = ML.BOLT_TILE_W
	var h: int = ML.BOLT_TILE_H
	var ox: int = stage * w
	var oy: int = row * h
	for c: Vector2i in cells:
		var px: int = c.x + ML.BOLT_TILE_PAD
		var py: int = c.y + ML.BOLT_TILE_CY
		if px < 0 or px >= w or py < 0 or py >= h:
			continue
		if kind != "start" and px < ML.BOLT_TILE_PAD: ## başlangıç dışında sol pay boş kalır (komşunun payına taşmasın)
			continue
		img.set_pixel(ox + px, oy + py, ML.PALETTE[int(cells[c])])
