extends RefCounted

## Ana menü başlık prototipleri (2026-11-13, oyuna bağlı DEĞİL). baslik_capture.gd çağırır: build(v, menu) -> Control.
##  A Altın Logo  = elle çizilmiş piksel logo (gen_logo.py logo_gold) x6 + altında ortalı aralıklı slogan; silahlar ve kiriş çubuğu yok.
##  B Kuru Çiçek  = A'nın yerleşimi, harfler sönük taç yaprağı tonlarında + hafif zıplama (potpourri = kuru çiçek karışımı).
##  C Yan Silahlar = A + logonun iki yanında Bıçak ve Ateş Asası (aynı boy x3, ayna duruş). OYUNDA (madde 660, main_menu.gd _title_sign).
##  (C v1 "Arma" = silahlar logonun üstünde çapraz, küçük kalıyordu, atıldı.)

const DK := preload("res://scripts/menu_dark_kit.gd")
const HT := preload("res://scripts/hud_theme.gd")
const K := 6.0
const POS := Vector2(40, 80)


static func _tex_file(name: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://tools/proto_20261113/menu_baslik/out/" + name))
	return ImageTexture.create_from_image(img)


static func _pix(tex: Texture2D, k: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = tex.get_size() * k
	tr.size = tex.get_size() * k
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _tagline(w: float) -> Label:
	var l := DK.lbl("Hayatta kal. Birlikte.", 32, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.uppercase = true
	var fv := FontVariation.new()
	fv.base_font = l.get_theme_font("font")
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	l.custom_minimum_size = Vector2(w, 32)
	l.size = Vector2(w, 32)
	return l


static func build(v: String, _menu: Node) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = POS
	var logo_name := "logo_petal.png" if v == "B" else "logo_gold.png"
	var logo := _pix(_tex_file(logo_name), K)
	var x := 0.0
	if v == "C":
		## C (v2): eski tabeladaki iki silah logonun iki yanında, aynı boy (x3 = 96 px), harf yüzüne göre dikey ortalı, ayna duruş.
		var d := _pix(load("res://assets/weapons/yeni/bicak.png"), 3.0)
		d.flip_h = true
		d.position = Vector2(0, 66.0 * 0.5 - 48.0 + 3.0)
		root.add_child(d)
		x = 96.0 + 6.0
		var s := _pix(load("res://assets/weapons/yeni/fire_staff.png"), 3.0)
		s.position = Vector2(x + logo.size.x + 6.0, d.position.y)
		root.add_child(s)
	logo.position = Vector2(x, 0)
	root.add_child(logo)
	var tag := _tagline(logo.size.x)
	tag.position = Vector2(x, logo.size.y - 2.0)
	root.add_child(tag)
	return root
