extends SceneTree

## SU SHADER PROTOTİPLERİ (2026-10-17, oyuna bağlı DEĞİL) - gerçek çizicide.
## Kullanıcı: "oyundaki suların shader'ı neredeyse yok gibi, 4 shader prototipi".
## 1) SU_PHASE=maske: GÖRÜNEN su maskesi (Su karosunun mavi pikselleri - kıyı ayrıntı katmanlarının mavi OLMAYAN opak pikselleri; aynı kural
##    terrain_collision.gd _class_mask / madde 86), 2 dünya px/teksel -> out/su_maske.png (0..252 kaplama) + out/su_maske.json (köken).
##    Sonra: python tools/proto_20261017/su_shader/su_mesafe.py -> out/su_mesafe.png (R = kıyıya uzaklık / 64 dünya px, G = kaplama).
## 2) Varsayılan: harita_baked.tscn oyunun yoluyla (GrassSway + TreeSway + MapShadows + MapColorGrade) su noktalarında; Su/Su katmanının
##    shader'ı Mevcut + A-D ile değiştirilir, her biri FRAMES kare -> out/kare/<nokta>_<ad>_<i>.png. 960x540 = oyunun görüşü, 1 px = 1 dünya px.
## Çalıştır: Godot --path . --windowed --resolution 480x270 -s tools/proto_20261017/su_shader/su_capture.gd
## Ortam: SU_PHASE=maske | SU_ONLY=<ad,ad> (sadece o shader'lar; 2. set: SU_ONLY=0_mevcut,E_kontur,F_akan_nehir,G_esinti,H_sakin_kirilma) | SU_SPOT=<nokta> | SU_FRAMES=<n> | SU_HIDE=1 (su gizli, dip)
##        SU_DEBUG=1/2 (D: sadece dip / sadece yansıma) | SU_OYUN=1 (oyunun kendi su yolu, madde 214)

const DIR := "res://tools/proto_20261017/su_shader/"
const OUT := DIR + "out/"
const VIEW := Vector2i(960, 540)
const TEXEL := 2 ## dünya px / maske tekseli

const VARIANTS := {
	"0_mevcut": "",
	"A_kiyi_kopugu": DIR + "su_A_kiyi_kopugu.gdshader",
	"B_isik_agi": DIR + "su_B_isik_agi.gdshader",
	"C_dalgacik": DIR + "su_C_dalgacik.gdshader",
	"C1_dalgacik_v1": DIR + "su_C_dalgacik_v1.gdshader", ## sadece karşılaştırma (C v2 öncesi)
	"D_derin_gol": DIR + "su_D_derin_gol.gdshader",
	"D1_derin_gol_v1": DIR + "su_D_derin_gol_v1.gdshader", ## sadece karşılaştırma (D v2 öncesi)
	## 2. set (kullanıcı C v2'yi sevmedi, "yeni 4 prototip"): noktasız, temiz tonlar, sakin
	"E_kontur": DIR + "su_E_kontur.gdshader",
	"F_akan_nehir": DIR + "su_F_akan_nehir.gdshader",
	"G_esinti": DIR + "su_G_esinti.gdshader",
	"H_sakin_kirilma": DIR + "su_H_sakin_kirilma.gdshader",
	## C v1 + akıntı (kullanıcı: "ilk halinin C'si ama akıntılı"); "?ad=değer" = shader parametresi
	"C3_akintili": DIR + "su_C3_akintili_dalgacik.gdshader",
	"C4_akintiya_donuk": DIR + "su_C3_akintili_dalgacik.gdshader?yonlu=true",
}

## Su noktaları: maskeden 960x540 görüşte en çok suyu olan 3 ayrık ekran (gol %27 = batı köprüsünün doğusundaki genişleme,
## nehir %17 = orta dere kıvrımı, kuzeydogu %15 = kuzeydoğu gölü). Su haritanın ~%9'u, çoğu 2-4 hücrelik dar dere.
## Animasyon karelerinde sadece bu bölge kaydedilir (görüş içi, dünya px; su_sayfa.py 2x büyütür = oyundaki boyut).
const CROPS := {
	"gol": Rect2i(150, 160, 240, 150),
	"nehir": Rect2i(260, 170, 240, 150),
	"kuzeydogu": Rect2i(500, 250, 240, 150),
}

var spots := {
	"gol": Vector2(1760, 1966),
	"nehir": Vector2(2912, 1390),
	"kuzeydogu": Vector2(3584, 398),
}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "kare/"))
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var harita: Node2D = load("res://scenes/harita_baked.tscn").instantiate()
	vp.add_child(harita)
	await process_frame
	if OS.get_environment("SU_PHASE") == "maske":
		_build_mask(harita)
		quit()
		return
	load("res://scripts/grass_sway.gd").new().setup(harita)
	load("res://scripts/tree_sway.gd").new().setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	load("res://scripts/map_color_grade.gd").attach(harita, true, true)
	load("res://scripts/forest_canopy.gd").new().setup(harita)
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()

	var water := harita.get_node("Su/Su") as TileMapLayer
	var water_cs := harita.get_node("Su/Su collisionsuz") as TileMapLayer
	var orig_mat := water.material as ShaderMaterial
	if OS.get_environment("SU_HIDE") == "1":
		water.visible = false
		water_cs.visible = false
	## D'nin ekran dokusu (dip kırılması) için Su katmanlarından ÖNCE tam görüş kopyası: otomatik kopya dipte sadece
	## temizleme rengini (gri) okuyordu. Diğer prototiplerin görünüşünü değiştirmez.
	if true:
		var bbc := BackBufferCopy.new()
		bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		water.get_parent().add_child(bbc)
		water.get_parent().move_child(bbc, water_cs.get_index())
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "su_maske.json"))
	var dimg := Image.load_from_file(ProjectSettings.globalize_path(OUT + "su_mesafe.png"))
	var dtex := ImageTexture.create_from_image(dimg)
	var atex := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(OUT + "su_akis.png")))
	var morg := Vector2(info["ox"], info["oy"])
	var msize := Vector2(dimg.get_width() * TEXEL, dimg.get_height() * TEXEL)

	var only_spot := OS.get_environment("SU_SPOT")
	if only_spot != "":
		spots = {only_spot: spots[only_spot]}
	var only := OS.get_environment("SU_ONLY").split(",", false)
	var frames := int(OS.get_environment("SU_FRAMES")) if OS.get_environment("SU_FRAMES") != "" else 24
	print("spots: ", spots)

	var mats := {}
	## SU_OYUN=1: oyunun kendi yolu (madde 214: scenes/su.gdshader + scripts/water_fx.gd, assets/map/su_*.png) -> "oyun" sürümü
	if OS.get_environment("SU_OYUN") == "1":
		## main.tscn'deki gibi Harita (-2, 21) konumunda (madde 214 hatası: doku harita orijinine göre pişiyor, shader dünya koordinatı)
		harita.position = Vector2(-2, 21)
		load("res://scripts/water_fx.gd").attach(harita)
		mats["oyun"] = water.material
	for v in VARIANTS:
		if mats.has("oyun"):
			break
		if not only.is_empty() and not only.has(v):
			continue
		if VARIANTS[v] == "":
			mats[v] = orig_mat
			continue
		var m := ShaderMaterial.new()
		var spec: String = VARIANTS[v]
		m.shader = load(spec.get_slice("?", 0))
		if spec.contains("?"):
			for kv: String in spec.get_slice("?", 1).split("&"):
				m.set_shader_parameter(kv.get_slice("=", 0), str_to_var(kv.get_slice("=", 1)))
		m.set_shader_parameter("su_mesafe", dtex)
		m.set_shader_parameter("mesafe_origin", morg)
		m.set_shader_parameter("mesafe_size", msize)
		m.set_shader_parameter("su_akis", atex)
		if OS.get_environment("SU_DEBUG") != "":
			m.set_shader_parameter("hata_ayikla", int(OS.get_environment("SU_DEBUG")))
		mats[v] = m

	for spot in spots:
		cam.position = spots[spot].round()
		for v in mats:
			water.material = mats[v]
			water_cs.material = mats[v] if v == "oyun" else (null if VARIANTS[v] == "" else mats[v])
			await _wait(0.6)
			for i in frames:
				var im := await _grab(vp)
				if frames > 1:
					im = im.get_region(CROPS[spot])
				im.save_png(ProjectSettings.globalize_path(OUT + "kare/%s_%s_%02d.png" % [spot, v, i]))
				await _wait(1.0 / 12.0)
			print("yazildi ", spot, " ", v)
	quit()


## Görünen su maskesi: 2x2 dünya pikseli = 1 teksel, değer = görünen su pikseli sayısı x 63 (0..252).
## "Su/Su" + "Su/Su collisionsuz" (çarpışmasız su karoları - oyunda shader'ı YOK, prototiplerde ikisine de uygulanır; aynı hücre ızgarası).
## Köprü/iskele: ayrıntı karosu hücrenin suyunun %60+ını örtüyor ve iki yanında (3 hücre içinde, yatay ya da dikey) GÖRÜNÜR su
## (%60+ açık hücre) var -> altı su sayılır (yoksa köprü boyunca kıyı köpüğü çıkıyordu; batı köprüsü "Su ayrıntılar 3"te, altı
## Su collisionsuz). Kıyı boyunca komşular da örtülü olduğundan kıyı hücresi bu kurala girmez.
func _build_mask(harita: Node) -> void:
	var TC: GDScript = load("res://scripts/terrain_collision.gd")
	var helper: Node = load("res://scripts/depth_occluders.gd").new()
	var water := harita.get_node("Su/Su") as TileMapLayer
	var wofs: Vector2 = helper.cell_origin(water)
	var rect: Rect2i = water.get_used_rect().grow(4)
	var w: int = rect.size.x * 8
	var h: int = rect.size.y * 8
	var cache: Dictionary = {}
	var t0 := Time.get_ticks_msec()
	## 1. geçiş: hücre (Su ızgarası) -> {base, vis, oran}
	var cells: Dictionary = {}
	for wl: TileMapLayer in [water, harita.get_node("Su/Su collisionsuz") as TileMapLayer]:
		var lofs: Vector2 = helper.cell_origin(wl)
		var lshift := Vector2i(roundi((lofs.x - wofs.x) / 16.0), roundi((lofs.y - wofs.y) / 16.0))
		var details: Array = []
		for path: String in TC.WATER_DETAIL_LAYERS:
			var dl := harita.get_node_or_null(path) as TileMapLayer
			if dl != null and dl.tile_set != null and not dl.get_used_cells().is_empty():
				var dofs: Vector2 = helper.cell_origin(dl)
				details.append({"layer": dl, "shift": Vector2i(roundi((dofs.x - lofs.x) / 16.0), roundi((dofs.y - lofs.y) / 16.0))})
		for cell: Vector2i in wl.get_used_cells():
			var base: PackedByteArray = TC._class_mask(helper, wl, cell, cache)
			if base.is_empty():
				continue
			var vis: PackedByteArray = base.duplicate()
			for d: Dictionary in details:
				var dl: TileMapLayer = d["layer"]
				var dc: Vector2i = cell - (d["shift"] as Vector2i)
				if dl.get_cell_source_id(dc) == -1:
					continue
				var over: PackedByteArray = TC._class_mask(helper, dl, dc, cache)
				if over.is_empty():
					continue
				for i in 256:
					if over[i] == 2:
						vis[i] = 0
			var shown := 0
			var blue := 0
			for i in 256:
				shown += int(vis[i] == 1)
				blue += int(base[i] == 1)
			if blue == 0:
				continue
			var key: Vector2i = cell + lshift
			if cells.has(key) and float(cells[key]["oran"]) >= float(shown) / blue:
				continue
			cells[key] = {"base": base, "vis": vis, "oran": float(shown) / blue}
	helper.free()
	## 2. geçiş: köprü/iskele + yazma
	var acc := PackedByteArray()
	acc.resize(w * h)
	var bridged := 0
	for key: Vector2i in cells:
		var c: Dictionary = cells[key]
		var vis: PackedByteArray = c["vis"]
		if float(c["oran"]) < 0.4 and _between_water(cells, key):
			vis = c["base"]
			bridged += 1
		var mc: Vector2i = key - rect.position
		if mc.x < 0 or mc.y < 0 or mc.x * 8 + 8 > w or mc.y * 8 + 8 > h:
			continue
		for y in 16:
			var row: int = (mc.y * 8 + (y >> 1)) * w + mc.x * 8
			for x in 16:
				if vis[y * 16 + x] == 1:
					acc[row + (x >> 1)] = mini(252, acc[row + (x >> 1)] + 63)
	print("kopru/iskele hucresi su sayildi: ", bridged)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_L8, acc)
	img.save_png(ProjectSettings.globalize_path(OUT + "su_maske.png"))
	var origin: Vector2 = wofs + Vector2(rect.position) * 16.0
	var f := FileAccess.open(OUT + "su_maske.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"ox": origin.x, "oy": origin.y, "w": w, "h": h, "texel": TEXEL, "cells": cells.size()}))
	f.close()
	print("maske ", w, "x", h, " origin ", origin, " hucre ", cells.size(), " ", Time.get_ticks_msec() - t0, " ms")


func _between_water(cells: Dictionary, c: Vector2i) -> bool:
	var horiz: bool = _open_within(cells, c, Vector2i(-1, 0)) and _open_within(cells, c, Vector2i(1, 0))
	var vert: bool = _open_within(cells, c, Vector2i(0, -1)) and _open_within(cells, c, Vector2i(0, 1))
	return horiz or vert


func _open_within(cells: Dictionary, c: Vector2i, step: Vector2i) -> bool:
	for k in range(1, 4):
		var n: Vector2i = c + step * k
		if cells.has(n) and float(cells[n]["oran"]) >= 0.6:
			return true
	return false
