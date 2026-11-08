extends SceneTree

## SADE SU prototipleri (2026-11-06, oyuna bağlı DEĞİL) - gerçek çizicide (madde 209 aracının sadeleşmiş kopyası).
## Kullanıcı: "sudaki shaderlar için daha sade 4 prototip hazırla".
## Oyunun kendi su yolu (scripts/water_fx.gd + assets/map/su_*.png, Harita main.tscn'deki gibi (-2, 21)) = "0_simdi" (C3);
## A-D aynı dokularla aynı materyal parametrelerini alır, yalnız shader değişir. Su + Su collisionsuz ikisi de.
## Çıktı: out/kare/<nokta>_<ad>_<i>.png (CROPS bölgesi, 1 px = 1 dünya px) -> python -I su_sade_sayfa.py
## Çalıştır: su_sade_run.ps1 (gizli masaüstü). Ortam: SU_ONLY=<ad,ad> | SU_SPOT=<nokta> | SU_FRAMES=<n>

const DIR := "res://tools/proto_20261106/su_sade/"
const OUT := DIR + "out/"
const VIEW := Vector2i(960, 540)

const VARIANTS := {
	"0_simdi": "",
	"A_yavas_isik": DIR + "su_A_yavas_isik.gdshader",
	"B_seyrek_dalgacik": DIR + "su_B_seyrek_dalgacik.gdshader",
	"C_akinti_cizgisi": DIR + "su_C_akinti_cizgisi.gdshader",
	"D_kiyi_nefesi": DIR + "su_D_kiyi_nefesi.gdshader",
}
const COPY_PARAMS := ["su_mesafe", "su_akis", "doku_origin", "doku_size"]

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
	harita.position = Vector2(-2, 21)
	vp.add_child(harita)
	await process_frame
	load("res://scripts/grass_sway.gd").new().setup(harita)
	load("res://scripts/tree_sway.gd").new().setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	load("res://scripts/map_color_grade.gd").attach(harita, true, true)
	load("res://scripts/forest_canopy.gd").new().setup(harita)
	load("res://scripts/water_fx.gd").attach(harita)
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()

	var water := harita.get_node("Su/Su") as TileMapLayer
	var water_cs := harita.get_node("Su/Su collisionsuz") as TileMapLayer
	var game_mat := water.material as ShaderMaterial
	var only := OS.get_environment("SU_ONLY").split(",", false)
	var only_spot := OS.get_environment("SU_SPOT")
	if only_spot != "":
		spots = {only_spot: spots[only_spot]}
	var frames := int(OS.get_environment("SU_FRAMES")) if OS.get_environment("SU_FRAMES") != "" else 48

	var mats := {}
	for v in VARIANTS:
		if not only.is_empty() and not only.has(v):
			continue
		if VARIANTS[v] == "":
			mats[v] = game_mat
			continue
		var m := ShaderMaterial.new()
		m.shader = load(VARIANTS[v])
		for p: String in COPY_PARAMS:
			m.set_shader_parameter(p, game_mat.get_shader_parameter(p))
		mats[v] = m

	for spot in spots:
		cam.position = spots[spot].round()
		for v in mats:
			water.material = mats[v]
			water_cs.material = mats[v]
			await _wait(0.6)
			for i in frames:
				var im := await _grab(vp)
				if frames > 1:
					im = im.get_region(CROPS[spot])
				im.save_png(ProjectSettings.globalize_path(OUT + "kare/%s_%s_%02d.png" % [spot, v, i]))
				await _wait(1.0 / 12.0)
			print("SU_SADE yazildi ", spot, " ", v)
	print("SU_SADE bitti")
	quit()
