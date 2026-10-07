extends SceneTree

## Harita gölgeleri (2026-10-02, kullanıcı seçimi "B - Tepe gölgesi") - 1. ADIM: maske yakalama.
## Haritayı (scenes/harita_baked.tscn) 4096x4096 tek bir SubViewport'ta, her obje kategorisi için ayrı ayrı beyaz siluet
## olarak çizer ve PNG kaydeder; kaya/kütük gibi objelerin dibindeki çim saçağını ayıklamak için aynı katmanların renkli
## hali de kaydedilir. 2. ADIM tools/bake_map_shadows.py bu maskelerden assets/map/harita_golgeleri.png'yi üretir.
##
## GERÇEK RENDER gerekir (--headless'ta kukla render var, görüntü okunamaz). Kullanım (proje klasöründe):
##   Godot.exe --windowed --resolution 1280x720 --path . -s tools/bake_map_shadows.gd
##   python tools/bake_map_shadows.py <yazdırılan klasör>
##   Godot.exe --headless --path . --import
## Harita (Tiled -> harita_baked.tscn) yeniden bake edildiğinde bu iki adım tekrar çalıştırılmalı, yoksa gölgeler eski
## objelerin yerinde kalır.

const MAP_SIZE := 4096
## Kategori -> harita katmanları (Harita düğümüne göre yol). Ağaç katmanları AYRI: üst üste binen ağaçlar farklı
## katmanlarda, ayrı yakalanınca her ağaç kendi gölgesini alır.
const CATS := {
	"tree0": ["Shader Eklenecek/Ağaç 0"],
	"tree1": ["Shader Eklenecek/Ağaç 1"],
	"tree2": ["Shader Eklenecek/Ağaç 2"],
	## (OtOnKatman/"Çalılar ön" katmanları oyun açılırken bu katmanlardan ayrılıyor - sahne dosyasında çalının tamamı burada.)
	"bush": ["Shader Eklenecek/Çalılar", "Shader Eklenecek/Çalılar1", "Shader Eklenecek/Animasyonsuz çalılar",
		"Shader Eklenecek/Çiçekler 1"],
	## 2026-10-07: demirci binası (Blacksmith + kapısı) eklendi; "baca duman" duman animasyonu olduğu için gölge almaz.
	"house": ["ev/Blacksmith", "ev/blacksmith kapı", "ev/Ev ayrıntı", "ev/Ev", "ev/ev kapı", "ev/Ev Çatı 1"],
	"farm": ["tarla/tarla 1", "tarla/tarla 1_5", "tarla/tarla 2"],
	"rock": ["Etkileşimler/Maden", "Etkileşimler/Maden 1", "Düşman Üssü/Özel maden", "Düşman Üssü/Düşman üssü"],
	"cliff": ["Orman parçaları/orman parçaları -1", "Orman parçaları/Orman parçaları", "Orman parçaları/Orman parçaları 2",
		"Orman parçaları/Orman parçaları 3", "Orman parçaları/Orman parçaları 4"],
}
## Renkli yakalama (çim saçağı testi) - sadece koyu gövdeli obje kategorileri.
const COLOR_CATS := ["rock", "cliff"]

var _out_dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("bake_map_shadows.gd gerçek render ister: --headless OLMADAN çalıştır (--windowed).")
		quit(1)
		return
	_out_dir = OS.get_environment("SHADOW_BAKE_DIR")
	if _out_dir == "":
		_out_dir = OS.get_user_data_dir().path_join("shadow_bake")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var vp := SubViewport.new()
	vp.size = Vector2i(MAP_SIZE, MAP_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	vp.add_child(harita)
	await process_frame

	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { float a = step(0.5, texture(TEXTURE, UV).a * COLOR.a); COLOR = vec4(1.0, 1.0, 1.0, a); }"
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = sh
	var plain_sh := Shader.new()
	plain_sh.code = "shader_type canvas_item;\nvoid fragment() { COLOR = texture(TEXTURE, UV) * COLOR; }"
	var plain_mat := ShaderMaterial.new()
	plain_mat.shader = plain_sh

	var layers: Array = []
	for n in _all(harita):
		if n is TileMapLayer:
			layers.append(n)

	for cat in CATS.keys():
		await _capture(vp, harita, layers, CATS[cat], mask_mat, cat + ".png", true)
	for cat in COLOR_CATS:
		## Renkli: salınım/çimen gibi katman shader'ları olmadan düz doku rengi.
		await _capture(vp, harita, layers, CATS[cat], plain_mat, cat + "_color.png", false)
	print("SHADOW_BAKE_DIR=", _out_dir)
	quit(0)


func _capture(vp: SubViewport, harita: Node, layers: Array, wanted: Array, mat: ShaderMaterial, file: String, _as_mask: bool) -> void:
	for l in layers:
		(l as CanvasItem).visible = false
	for path in wanted:
		var l: TileMapLayer = harita.get_node_or_null(path) as TileMapLayer
		if l == null:
			push_warning("Katman yok: " + path)
			continue
		l.visible = true
		l.use_parent_material = false
		l.material = mat
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	## Maske = alfa kanalı (Python okur); renkli yakalamada RGB de kullanılır.
	var img: Image = vp.get_texture().get_image()
	img.save_png(_out_dir.path_join(file))
	print("SAVED ", file)
