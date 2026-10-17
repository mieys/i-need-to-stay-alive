extends Node

## OYUN İMLECİ (madde 206, 2026-10-17): kullanıcının seçtiği prototip A "Kehribar Ok" (madde 205). Windows oku yerine
## krem piksel ok; tıklanabilir düğmenin üstünde kehribar + ışıltı (CURSOR_POINTING_HAND); sol tuş basılıyken koyu
## kehribar + uçta tık ışınları, gölge kalkar. Dokular 1x sanat: `tools/gen_imlec.py` (çizim tools/proto_20261017/imlec_proto.py).
##  - Donanım imleci canvas_items ölçeğini İZLEMEZ: arayüz pikseli = 2 x min(genişlik/1920, yükseklik/1080); imleç pikseli
##    bunun SIZE_FACTOR katının aşağı tam katı (720p/1080p x1, 1440p x2, 4K x3, 5K x4); pencere boyutu değişince yeniden kurulur.
##    İlk sürüm arayüz pikseliyle aynıydı (1440p x3, ok ~51 px) - kullanıcı: "imleç çok büyük gözüküyor" -> bir kademe küçüldü.
##  - Her BaseButton (SceneTree.node_added) kendi şekli ok ise el imlecine geçer; devre dışı ya da tam ekran (tıklama
##    yakalayıcı) düğme ok kalır - fare her girdiğinde yeniden bakılır. Yazı alanları (I-ışını) sistem imleci kalır.
##  - Telefonda kurulmaz. UISound _ready'de bunu çocuk olarak kurar (project.godot'a yeni autoload yok).

const MobileUIScript := preload("res://scripts/mobile_ui.gd")

const TEX_NORMAL := preload("res://assets/ui/cursor/imlec_normal.png")
const TEX_HAND := preload("res://assets/ui/cursor/imlec_el.png")
const TEX_PRESSED := preload("res://assets/ui/cursor/imlec_basili.png")
## 1x dokuda koyu uç pikseli = tıklama noktası (tools/gen_imlec.py çıktısıyla aynı olmalı).
const HOTSPOT := Vector2i(5, 5)
## Donanım imleci en fazla 256x256; 19x25 sanat x4 = 76x100.
const MAX_SCALE := 4
## İmleç pikseli / arayüz pikseli (aşağı yuvarlanır). 1,0 = arayüzle aynı iri piksel (çok büyük bulundu).
const SIZE_FACTOR := 0.75
## ui_anim.gd ile aynı: bundan büyük düğmeler tam ekran tıklama yakalayıcısıdır, el göstermez.
const MAX_W := 1300.0
const MAX_H := 520.0
const META_HOOKED := &"_gc_hooked"

## Tipsiz: testler örneğe buradan ulaşır (class_name yok, preload ile kullanılıyor).
static var _inst = null

var _scale: int = 0
var _pressed: bool = false
## ölçek -> {"normal": Image, "el": Image, "basili": Image}; her ölçek bir kez büyütülür.
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if MobileUIScript.is_real_phone():
		return
	_inst = self
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


static func scale_for(win: Vector2i) -> int:
	var ui := minf(win.x / 1920.0, win.y / 1080.0) * 2.0
	return clampi(floori(ui * SIZE_FACTOR + 0.05), 1, MAX_SCALE) ## +0,05: 1440p'de 1,9999 -> 1 olmasın


static func scaled_image(tex: Texture2D, s: int) -> Image:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	return img


func _refresh() -> void:
	var s := scale_for(DisplayServer.window_get_size())
	if s == _scale:
		return
	_scale = s
	_apply()


func _images(s: int) -> Dictionary:
	if not _cache.has(s):
		_cache[s] = {
			"normal": scaled_image(TEX_NORMAL, s),
			"el": scaled_image(TEX_HAND, s),
			"basili": scaled_image(TEX_PRESSED, s),
		}
	return _cache[s]


func _apply() -> void:
	var imgs := _images(_scale)
	var hot := Vector2(HOTSPOT * _scale)
	Input.set_custom_mouse_cursor(imgs["basili"] if _pressed else imgs["normal"], Input.CURSOR_ARROW, hot)
	Input.set_custom_mouse_cursor(imgs["basili"] if _pressed else imgs["el"], Input.CURSOR_POINTING_HAND, hot)


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_set_pressed(mb.pressed)


func _notification(what: int) -> void:
	## Basılıyken pencere odağı giderse bırakma olayı gelmeyebilir - basılı görünüm takılı kalmasın.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_pressed(false)


func _set_pressed(p: bool) -> void:
	if p == _pressed or _scale == 0:
		return
	_pressed = p
	_apply()


## ------------------------------------------------------------------ düğmeler (otomatik el imleci)

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_hook(n as BaseButton)


func _hook(b: BaseButton) -> void:
	if b.has_meta(META_HOOKED):
		return
	## Kendi şeklini seçmiş düğmeye dokunma (zaten el olanlar da olduğu gibi kalır).
	if b.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		return
	b.set_meta(META_HOOKED, true)
	sync_shape(b)
	b.mouse_entered.connect(sync_shape.bind(b))


static func sync_shape(b: BaseButton) -> void:
	var catcher := b.size.x > MAX_W or b.size.y > MAX_H
	b.mouse_default_cursor_shape = Control.CURSOR_ARROW if (b.disabled or catcher) else Control.CURSOR_POINTING_HAND
