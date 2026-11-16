extends SceneTree

## ANA MENÜ "Nehir Kenarı Kampı" görünüm yakalaması (gerçek çizici): main_menu.tscn kökün çocuğu + current_scene, ~1.5 sn bekler, iki anda
## kare alır (alev/kor/yansıma değişiyor mu). Çıktı: tools/proto_20261115/kamp_menu/out/menu_<n>.png (+ _yakin = sahnenin ortası tam çözünürlük).
## Gizli masaüstünde: kamp_run.ps1 -Script menu_capture.gd. KAMP_MENU_SCENE ile başka sahne (ör. res://scenes/lobby_menu.tscn) denenebilir.

## Hava denemeleri (gunbatimi = shader varsayılanları; OYUNDAKİ hâl "ay2" = menu_camp_scene.gd SKY; önce "gece3" idi).
const HAVA := {
	"gece": {
		"dusk_color": Color(0.30, 0.34, 0.62), "gold_color": Color(0.42, 0.47, 0.80), "dim": 0.62, "vignette": 0.45,
		"fire_strength": 1.9, "fire_radius": 390.0, "warm_glow": Color(0.0, 0.02, 0.05), "haze_color": Color(0.02, 0.04, 0.10),
		"water_tint": Color(0.55, 0.62, 0.95), "sky_far": Color(0.12, 0.16, 0.35), "sky_near": Color(0.35, 0.42, 0.70),
		"sky_amount": 0.8, "glint_color": Color(0.75, 0.85, 1.0),
	},
	## Doğal + cozy gece (kullanıcı: "ışıklandırmayı daha doğal ve cozy yap"): ay ışığı renkleri soldurur, hafif mavi-yeşil (mor değil);
	## ateş sıcak turuncu, ortası sarı, uzun yumuşak kuyruk, aydınlattığı yerde renkler canlı (solmamış renkle aydınlatır), havada hafif hale.
	"gece2": {
		"dusk_color": Color(0.34, 0.42, 0.64), "gold_color": Color(0.42, 0.50, 0.72), "desat": 0.5, "dim": 0.5, "vignette": 0.36,
		"warm_glow": Color(0.0, 0.0, 0.0), "haze_color": Color(0.01, 0.02, 0.05),
		"fire_color": Color(1.0, 0.42, 0.15), "fire_core": Color(1.0, 0.68, 0.34), "fire_strength": 1.1, "fire_lum": 0.9,
		"fire_radius": 520.0, "fire_falloff": 1.35, "fire_halo": 0.06,
		"water_tint": Color(0.50, 0.60, 0.88), "sky_far": Color(0.10, 0.14, 0.26), "sky_near": Color(0.20, 0.28, 0.48),
		"sky_amount": 0.7, "glint_color": Color(0.70, 0.82, 1.0),
	},
	## gece2 + AY IŞIĞI (kullanıcı: "gece iyi ama çok karanlık, ay ışığı hissiyatı olmalı ortamda"): genel loşluk açıldı, ay tarafı (sağ üst,
	## sun_uv) daha parlak + soğuk, açık yüzeylerde mavi-beyaz ay parlaması (warm_glow alanı soğuk renkle), hafif ay pusu, nehirde güçlü ay
	## yansıması; ateş başı aynı.
	"gece3": {
		"dusk_color": Color(0.42, 0.50, 0.72), "gold_color": Color(0.62, 0.72, 0.95), "desat": 0.45, "dim": 0.66, "vignette": 0.30,
		"warm_glow": Color(0.05, 0.08, 0.14), "haze_color": Color(0.05, 0.07, 0.12),
		"fire_color": Color(1.0, 0.42, 0.15), "fire_core": Color(1.0, 0.68, 0.34), "fire_strength": 1.0, "fire_lum": 0.8,
		"fire_radius": 520.0, "fire_falloff": 1.35, "fire_halo": 0.06,
		"water_tint": Color(0.58, 0.68, 0.95), "sky_far": Color(0.18, 0.24, 0.40), "sky_near": Color(0.42, 0.52, 0.78),
		"sky_amount": 1.0, "glint_color": Color(0.85, 0.92, 1.0),
	},
	## COZY GECE denemeleri (kullanıcı: "ışıklandırmayı beğenmedim, daha cozy yap ortam hissini"; gece3 soğuk mavi-gri, soluk, sağ üstte gri
	## sis, sıcaklık yalnız ateşin dibindeydi). Hepsinde: renkler daha az solar, ateşin çok geniş zayıf ikinci ışığı sahneyi sarar
	## (fire_wide_*), havada sıcak parıltı (fire_bloom), nehirde ateş yansıması (water_fire), kenar karartması kampa odaklı; ateş böcekleri sahnede.
	"sicak": {
		"dusk_color": Color(0.36, 0.40, 0.66), "gold_color": Color(0.52, 0.56, 0.82), "desat": 0.2, "dim": 0.6, "vignette": 0.45,
		"vignette_center": Vector2(0.56, 0.62), "warm_glow": Color(0.02, 0.02, 0.05), "haze_color": Color(0.03, 0.03, 0.07),
		"fire_color": Color(1.0, 0.44, 0.18), "fire_core": Color(1.0, 0.64, 0.34), "fire_strength": 0.9, "fire_lum": 0.5,
		"fire_radius": 560.0, "fire_falloff": 1.25, "fire_halo": 0.05,
		"fire_wide_radius": 1250.0, "fire_wide_strength": 0.28, "fire_bloom": 0.10, "fire_bloom_radius": 140.0, "water_fire": 0.6,
		"water_tint": Color(0.50, 0.56, 0.92), "sky_far": Color(0.12, 0.12, 0.30), "sky_near": Color(0.28, 0.30, 0.58),
		"sky_amount": 0.9, "glint_color": Color(0.80, 0.86, 1.0),
	},
	"mor": {
		"dusk_color": Color(0.48, 0.38, 0.66), "gold_color": Color(0.66, 0.52, 0.78), "desat": 0.12, "dim": 0.68, "vignette": 0.40,
		"vignette_center": Vector2(0.56, 0.62), "warm_glow": Color(0.05, 0.02, 0.04), "haze_color": Color(0.06, 0.03, 0.06),
		"fire_color": Color(1.0, 0.44, 0.18), "fire_core": Color(1.0, 0.64, 0.34), "fire_strength": 0.9, "fire_lum": 0.5,
		"fire_radius": 560.0, "fire_falloff": 1.25, "fire_halo": 0.05,
		"fire_wide_radius": 1300.0, "fire_wide_strength": 0.30, "fire_bloom": 0.10, "fire_bloom_radius": 140.0, "water_fire": 0.6,
		"water_tint": Color(0.62, 0.52, 0.90), "sky_far": Color(0.22, 0.14, 0.32), "sky_near": Color(0.46, 0.30, 0.52),
		"sky_amount": 0.9, "glint_color": Color(1.0, 0.80, 0.90),
	},
	"ay2": {
		"dusk_color": Color(0.40, 0.48, 0.70), "gold_color": Color(0.58, 0.66, 0.88), "desat": 0.25, "dim": 0.66, "vignette": 0.38,
		"vignette_center": Vector2(0.56, 0.62), "warm_glow": Color(0.04, 0.06, 0.10), "haze_color": Color(0.02, 0.03, 0.06),
		"fire_color": Color(1.0, 0.44, 0.18), "fire_core": Color(1.0, 0.64, 0.34), "fire_strength": 0.9, "fire_lum": 0.5,
		"fire_radius": 560.0, "fire_falloff": 1.25, "fire_halo": 0.05,
		"fire_wide_radius": 1200.0, "fire_wide_strength": 0.22, "fire_bloom": 0.09, "fire_bloom_radius": 140.0, "water_fire": 0.5,
		"water_tint": Color(0.58, 0.68, 0.95), "sky_far": Color(0.18, 0.24, 0.40), "sky_near": Color(0.42, 0.52, 0.78),
		"sky_amount": 1.0, "glint_color": Color(0.85, 0.92, 1.0),
	},
	"gunbatimi": {},
	"gunduz": {
		"dusk_color": Color(0.86, 0.86, 0.93), "gold_color": Color(1.06, 1.0, 0.90), "dim": 0.98, "vignette": 0.20,
		"fire_strength": 0.45, "fire_radius": 300.0, "warm_glow": Color(0.04, 0.03, 0.01), "haze_color": Color(0.08, 0.06, 0.02),
		"water_tint": Color(0.95, 0.97, 1.03), "sky_far": Color(0.55, 0.68, 0.95), "sky_near": Color(0.95, 0.90, 0.75),
		"sky_amount": 0.8, "glint_color": Color(1.0, 0.95, 0.80),
	},
}

var _out: String =ProjectSettings.globalize_path("res://").path_join("tools/proto_20261115/kamp_menu/out")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var path: String = OS.get_environment("KAMP_MENU_SCENE")
	if path.is_empty():
		path = "res://scenes/main_menu.tscn"
	var menu: Node = (load(path) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	if OS.get_environment("KAMP_NO_FF") == "1": ## denetim: ateş böceklerini gizle (sudaki dalgacık farkını ölçerken karışmasın)
		for ff: Node in menu.find_children("Fireflies", "", true, false):
			(ff as CanvasItem).visible = false
	for shot in range(2):
		for _i in range(45 if shot == 0 else 20):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var w: int = img.get_width()
		var h: int = img.get_height()
		var yakin: Image = img.get_region(Rect2i(int(w * 0.40), int(h * 0.42), int(w * 0.40), int(h * 0.50)))
		yakin.save_png(_out.path_join("menu_%d_yakin.png" % shot))
		img.get_region(Rect2i(int(w * 0.40), int(h * 0.12), int(w * 0.20), int(h * 0.28))).save_png(_out.path_join("menu_%d_balik.png" % shot)) ## Talon'un oltası
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		img.save_png(_out.path_join("menu_%d.png" % shot))
		print("SHOT menu_", shot, " ", w, "x", h)
	## KAMP_HAVA="gece,gunbatimi,gunduz": aynı sahne farklı havada (kamp_gunbatimi.gdshader parametreleri ezilir; OYUNA BAĞLI DEĞİL,
	## kullanıcıya göstermek için) -> out/hava_<ad>.png (960x540) + out/hava_<ad>_yakin.png
	var hava: String = OS.get_environment("KAMP_HAVA")
	if not hava.is_empty():
		var grade: CanvasItem = menu.find_child("SunsetGrade", true, false) as CanvasItem
		var mat: ShaderMaterial = grade.material as ShaderMaterial
		var base: Dictionary = {}
		for v: Dictionary in HAVA.values():
			for k: String in v.keys():
				base[k] = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), k) ## shader varsayılanı = günbatımı
		for ad: String in hava.split(",", false):
			for k: String in base.keys():
				mat.set_shader_parameter(k, base[k])
			for k: String in HAVA.get(ad, {}).keys():
				mat.set_shader_parameter(k, HAVA[ad][k])
			for _i in range(20):
				await process_frame
			await RenderingServer.frame_post_draw
			var im: Image = root.get_texture().get_image()
			var ww: int = im.get_width()
			var hh: int = im.get_height()
			im.get_region(Rect2i(int(ww * 0.40), int(hh * 0.30), int(ww * 0.45), int(hh * 0.62))).save_png(_out.path_join("hava_%s_yakin.png" % ad))
			im.resize(960, 540, Image.INTERPOLATE_BILINEAR)
			im.save_png(_out.path_join("hava_%s.png" % ad))
			print("SHOT hava_", ad)
	## KAMP_MENU_SERIES=N: sahnenin ortasından N kare, ~0,2 sn arayla (canlılık: nefes / gülme / olta / ateş) -> out/seri_<i>.png
	var n: int = int(OS.get_environment("KAMP_MENU_SERIES"))
	for i in range(n):
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 200:
			await process_frame
		await RenderingServer.frame_post_draw
		var im: Image = root.get_texture().get_image()
		var ww: int = im.get_width()
		var hh: int = im.get_height()
		im = im.get_region(Rect2i(int(ww * 0.38), int(hh * 0.12), int(ww * 0.42), int(hh * 0.80)))
		im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_NEAREST)
		im.save_png(_out.path_join("seri_%02d.png" % i))
	quit()
