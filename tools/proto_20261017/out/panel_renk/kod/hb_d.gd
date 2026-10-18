extends RefCounted

## ORTAK MENÜ ARKA PLANI "Ocak Başı" (2026-10-16, kullanıcı: "çok oyunculu, oda kurma ve tek oyunculunun arka planı ana menüdekiyle aynı
## olsun"): ocak_basi.png + canlı şömine ateşi + şömineye dönük oturan parti + uyuyan köpek - ana menünün sahnesi (main_menu.gd _build_scene).
## Ölçü/konum/ton sabitleri ve SheetAnim/SceneSprite TEK yerde, main_menu.gd'de: burası onları kullanır, kopyalamaz (sahne değişirse bu
## ekranlar da değişir). main_menu.gd bu dosyayı preload ETMESİN (döngü); ana menü kendi sahnesini sol menü gölgesiyle kurar.
## Kullanan: character_select.gd, room_browser.gd, lobby_menu.gd. Hepsi statik: const HearthBg := preload("res://tools/proto_20261017/out/panel_renk/kod/hb_d.gd").

const MM := preload("res://scripts/main_menu.gd")
const PC := preload("res://scripts/pet_catalog.gd")
## Koyu kit panelleri (menu_dark_kit.gd) sahnenin üstünde okunur kalsın diye düz koyu örtü; şömine ışığı yine seçilir.
const DIM_COLOR := Color(0.06, 0.02, 0.02)
const DIM_DESKTOP := 0.3


## Tam ekran katman ("BackgroundImage", root'un İLK çocuğu olmalı - üstüne ekran kurulur); içindeki 1920x1080 sahne katmanı ÖRTECEK kadar
## ölçeklenir (KEEP_ASPECT_COVERED gibi, telefonda da ekranın tamamı) - ateş/parti arka planla hizalı kalır. dim > 0: üstüne koyu örtü.
static func add_to(root: Control, dim: float = 0.0) -> Control:
	var layer := Control.new()
	layer.name = "BackgroundImage"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stage)
	stage.size = MM.SCREEN
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/ana_menu/ocak_basi.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	bg.position = Vector2.ZERO
	bg.size = MM.SCREEN
	var fire = MM.SheetAnim.new(load("res://assets/ui/ana_menu/ocak_ates.png"), MM.FIRE_FRAME, MM.FIRE_FRAMES, MM.FIRE_FPS, MM.ART_K)
	stage.add_child(fire)
	fire.position = MM.FIRE_POS * MM.ART_K
	fire.size = MM.FIRE_FRAME * MM.ART_K
	var pet_spec: Array = PC.FRAMES.get(MM.DOG[0], [])
	if not pet_spec.is_empty():
		_add_sprite(stage, load(str(pet_spec[0])) as SpriteFrames, str(MM.DOG[1]), MM.DOG[2])
	var party: Array = MM.PARTY.duplicate()
	party.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector2).y < (b[2] as Vector2).y)
	for p: Array in party:
		_add_sprite(stage, load(str(Characters.get_def(int(p[0])).get("frames", ""))) as SpriteFrames, str(p[1]), p[2])
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(DIM_COLOR, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.resized.connect(func() -> void: _fit(layer, stage))
	_fit(layer, stage)
	return layer


static func _add_sprite(stage: Control, sf: SpriteFrames, clip: String, foot: Vector2) -> void:
	if sf == null:
		return
	var s = MM.SceneSprite.new(sf, clip, MM.ART_K)
	stage.add_child(s)
	s.place_at(foot)
	s.modulate = MM.SCENE_TINT


static func _fit(layer: Control, stage: Control) -> void:
	if not is_instance_valid(stage) or layer.size.x < 1.0:
		return
	var s: float = maxf(layer.size.x / MM.SCREEN.x, layer.size.y / MM.SCREEN.y)
	stage.scale = Vector2(s, s)
	stage.position = ((layer.size - MM.SCREEN * s) * 0.5).floor()
