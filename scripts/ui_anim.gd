extends Node

## ARAYÜZ CANLILIĞI - kullanıcı isteği (2026-10-17): "oyundaki tüm arayüzlerin animasyonlu olmasını istiyorum butonlar v.b
## dahil çok ruhsuz ve hissiyatı yok hiçbirşeyin fakat karmaşık ve göz yorucu olmasınlar". TEK yer (madde 200). İlke: her
## hareket kısa (<0,45 sn), tek seferlik, sonunda TAM eski hâline döner - kalıcı ölçek yok (piksel yazı ölçekli kalırsa
## bulanıklaşır/tırtıklanır, madde 144), sürekli yanıp sönen/dönen bir şey yok.
##  - HER BaseButton (otomatik, SceneTree.node_added): fare/odak gelince kenar başına ~3 px "nefes" + tek geçişlik ışık
##    parıltısı (sadece dolu zeminli Button); basınca çökme + yaylanma. Büyük düğmeler (tam ekran tıklama yakalayıcıları)
##    atlanır. Kendi kart animasyonu olan ekranlar `skip(node)` ile çıkar - atası işaretli düğmeler de atlanır. Başka bir
##    animasyon ölçeği değiştirmişse (scale != 1) dokunulmaz.
##  - Pencere açılışı `window_in(root)`: içerik saydamdan belirir + %3,5 büyükten yerine oturur (telefonda sadece belirir). CanvasLayer kökte
##    katmanın kendi ölçeği/ofseti oynar (CenterContainer sıralaması çocuk ölçeğini sıfırladığı için çocuklara dokunulmaz).
##  - Liste girişi `cascade(container)`: satırlar sırayla belirir (sadece saydamlık; konum container'ın).
##  - `slide_x(control, x)`: container'da OLMAYAN bir çocuğu yumuşakça kaydırır (ana menü öğesi odakta sağa kayar).
##  - Sahne geçişi: eski ekranın son karesi yeni sahnenin üstünde 0,3 sn'de söner (çapraz geçiş, ilk sahnede yok).
##  - Ayar: Grafik penceresi "Arayüz animasyonları" (UISound.ui_anim_enabled); kapalıyken hepsi anında olur.
## UISound _ready'de bunu çocuk olarak kurar (project.godot'a yeni autoload yok). Çağıranlar:
##   const UiAnim := preload("res://scripts/ui_anim.gd")  ->  UiAnim.window_in(self) / UiAnim.cascade(box) / UiAnim.skip(card)

const MobileUIScript := preload("res://scripts/mobile_ui.gd")

const META_SKIP := &"ui_anim_skip"
const META_HOOKED := &"_ua_hooked"
const META_TW := &"_ua_tw"
const META_SHINE_TW := &"_ua_shine_tw"
const META_PIVOT := &"_ua_pivot"
const META_T := &"_ua_t"
const META_SHINE := &"_ua_shine"
const META_ALPHA := &"_ua_alpha"
const META_SLIDE_TW := &"_ua_slide_tw"
const META_FADE_TW := &"_ua_fade_tw"

## Fare üstüne gelince düğmenin her kenarı bu kadar piksel dışarı taşar (sonra geri döner).
const POP_PX := 3.0
const POP_MIN := 0.012
const POP_MAX := 0.06
## Bundan büyük düğmeler animasyonsuz (tam ekran arka plan tıklayıcıları, dev kart kapları).
const MAX_W := 1300.0
const MAX_H := 520.0
const HOVER_UP := 0.08
const HOVER_DOWN := 0.16
## Aynı düğmede fare + odak aynı karede gelince (ana menü: fare = odak) ikinci kez oynamasın.
const HOVER_DEBOUNCE_MS := 150
const SHINE_TIME := 0.42
const SHINE_ALPHA := 0.16
const SHINE_COLOR := Color(1.0, 0.95, 0.82)
const WINDOW_FROM := 1.035
const WINDOW_TIME := 0.24
const FADE_TIME := 0.16
const CASCADE_STEP := 0.04
const CASCADE_TIME := 0.18
const CASCADE_MAX := 16
const SLIDE_TIME := 0.14
const CROSSFADE_TIME := 0.3
const CROSSFADE_LAYER := 128

## Tipsiz: bu betiğin kendi yöntemleri dinamik çağrılır (class_name yok, preload ile kullanılıyor).
static var _inst = null
var _first_scene_seen: bool = false


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


## ------------------------------------------------------------------ dış API (statik, preload ile çağrılır)

static func is_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var s: Node = tree.root.get_node_or_null(^"UISound")
	return s == null or bool(s.get(&"ui_anim_enabled"))


## Bu düğümü ve altındaki tüm düğmeleri otomatik düğme animasyonundan çıkarır (kendi animasyonu olan kartlar).
static func skip(node: Node) -> void:
	if node:
		node.set_meta(META_SKIP, true)


## Pencere/ekran açılışı: belirme + yerine oturma. CanvasLayer ya da (container'da olmayan) Control kök.
static func window_in(root: Node) -> void:
	if _inst and is_instance_valid(root):
		_inst._window_in(root)


## Container'ın görünür çocukları sırayla belirir. `delay` ilk çocuğun gecikmesi (art arda gelen satırları sıraya dizmek için).
static func cascade(container: Node, step: float = CASCADE_STEP, max_items: int = CASCADE_MAX, delay: float = 0.0) -> void:
	if _inst and is_instance_valid(container):
		_inst._cascade(container, step, max_items, delay)


## Tek bir öğe `from_alpha`dan asıl saydamlığına yumuşakça gelir (seçim değişince ayrıntı paneli, seçim halkası).
## `delay`: farklı container'lardaki öğeleri tek bir sıraya dizmek için (Ruh Mağazası sayfa girişi).
static func reveal(ci: CanvasItem, from_alpha: float = 0.35, dur: float = 0.16, delay: float = 0.0) -> void:
	if _inst and is_instance_valid(ci) and is_enabled() and ci.is_visible_in_tree():
		_inst._fade_in(ci, delay, dur, from_alpha)


## Düğme olmayan tıklanabilir bir Control için fare üstü "nefes" (örn. karakter kartı).
static func pop(c: Control) -> void:
	if _inst and is_instance_valid(c):
		_inst._hover_pop(c, false)


## Container'da OLMAYAN bir Control'ün x konumunu yumuşakça değiştirir (animasyon kapalıysa anında).
static func slide_x(c: Control, x: float) -> void:
	if not is_instance_valid(c):
		return
	var old: Tween = _meta_tween(c, META_SLIDE_TW)
	if old and old.is_valid():
		old.kill()
	if _inst == null or not is_enabled() or not c.is_visible_in_tree():
		c.position.x = x
		return
	var tw: Tween = _new_tween(c)
	c.set_meta(META_SLIDE_TW, tw)
	tw.tween_property(c, "position:x", x, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## get_meta(ad, null) eksik anahtarda hata basar (null varsayılan sayılmaz) - önce has_meta.
static func _meta_tween(n: Object, key: StringName) -> Tween:
	return n.get_meta(key) as Tween if n.has_meta(key) else null


static func _new_tween(n: Node) -> Tween:
	var tw: Tween = n.create_tween()
	## Duraklatılmış ağaçta da (duraklatma menüsü, seviye ekranı) ve oyun yavaşlatmasından bağımsız aksın.
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	return tw


## ------------------------------------------------------------------ düğmeler (otomatik)

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_hook(n as BaseButton)
	elif n.get_parent() == get_tree().root:
		_on_root_child.call_deferred(n)


func _hook(b: BaseButton) -> void:
	## Ağaçtan çıkıp geri giren (yeniden ebeveynlenen) düğme ikinci kez bağlanmasın.
	if b.has_meta(META_HOOKED):
		return
	b.set_meta(META_HOOKED, true)
	b.mouse_entered.connect(_on_hover.bind(b))
	b.focus_entered.connect(_on_hover.bind(b))
	b.button_down.connect(_on_press.bind(b))
	if b is Button:
		b.draw.connect(_draw_shine.bind(b))


func _can_anim(c: Control) -> bool:
	if not is_enabled() or not c.is_visible_in_tree():
		return false
	if c.size.x > MAX_W or c.size.y > MAX_H:
		return false
	var n: Node = c
	while n:
		if n.has_meta(META_SKIP):
			return false
		n = n.get_parent()
	return true


func _amp(c: Control) -> float:
	return clampf(POP_PX * 2.0 / maxf(1.0, maxf(c.size.x, c.size.y)), POP_MIN, POP_MAX)


func _on_hover(b: BaseButton) -> void:
	if b.disabled:
		return
	_hover_pop(b, true)


func _hover_pop(c: Control, with_shine: bool) -> void:
	if not _can_anim(c):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(c.get_meta(META_T, -100000)) < HOVER_DEBOUNCE_MS:
		return
	c.set_meta(META_T, now)
	var a: float = _amp(c)
	var tw: Tween = _begin_scale(c)
	if tw:
		tw.tween_property(c, "scale", Vector2.ONE * (1.0 + a), HOVER_UP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, HOVER_DOWN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_end_scale.bind(c))
	if with_shine and c is Button:
		_start_shine(c as Button)


func _on_press(b: BaseButton) -> void:
	if not _can_anim(b):
		return
	b.set_meta(META_T, Time.get_ticks_msec()) ## tıklamanın verdiği odak ikinci bir "nefes" başlatmasın
	var a: float = _amp(b)
	var tw: Tween = _begin_scale(b)
	if tw == null:
		return
	tw.tween_property(b, "scale", Vector2.ONE * (1.0 - a * 1.4), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE * (1.0 + a * 0.5), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_end_scale.bind(b))


## Ölçek animasyonu başlatır: önceki BİZİM animasyonumuz kesilir; başkası ölçeklemişse (kart girişi, mobil ölçek) null.
## Pivot geçici olarak merkeze alınır, bitince eski pivot geri konur (ölçek 1'ken pivot görüntüyü etkilemez).
func _begin_scale(c: Control) -> Tween:
	var old: Tween = _meta_tween(c, META_TW)
	if old and old.is_valid():
		old.kill()
	elif not c.scale.is_equal_approx(Vector2.ONE):
		return null
	if not c.has_meta(META_PIVOT):
		c.set_meta(META_PIVOT, c.pivot_offset)
	c.pivot_offset = c.size * 0.5
	var tw: Tween = _new_tween(c)
	c.set_meta(META_TW, tw)
	return tw


func _end_scale(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.scale = Vector2.ONE
	if c.has_meta(META_PIVOT):
		c.pivot_offset = c.get_meta(META_PIVOT)
		c.remove_meta(META_PIVOT)
	c.remove_meta(META_TW)


## Parıltı sadece dolu zeminli düğmede (düz/boş stilde ya da saydam dokuda dikdörtgen bir ışık gibi dururdu).
func _shine_rect(b: Button) -> Rect2:
	if b.flat:
		return Rect2()
	var r := Rect2(Vector2.ZERO, b.size)
	var sb: StyleBox = b.get_theme_stylebox(&"normal")
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		if not f.draw_center or f.bg_color.a < 0.3:
			return Rect2()
		var side: float = maxf(float(f.border_width_left), float(f.corner_radius_top_left) * 0.6)
		var side_r: float = maxf(float(f.border_width_right), float(f.corner_radius_top_right) * 0.6)
		return r.grow_individual(-side - 1.0, -f.border_width_top - 1.0, -side_r - 1.0, -f.border_width_bottom - 1.0)
	if sb is StyleBoxTexture:
		var t := sb as StyleBoxTexture
		return r.grow_individual(-t.texture_margin_left, -t.texture_margin_top, -t.texture_margin_right, -t.texture_margin_bottom)
	return Rect2()


func _start_shine(b: Button) -> void:
	var r: Rect2 = _shine_rect(b)
	if r.size.x < 8.0 or r.size.y < 6.0:
		return
	var old: Tween = _meta_tween(b, META_SHINE_TW)
	if old and old.is_valid():
		old.kill()
	var tw: Tween = _new_tween(b)
	b.set_meta(META_SHINE_TW, tw)
	tw.tween_method(_set_shine.bind(b), 0.0, 1.0, SHINE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_clear_shine.bind(b))


func _set_shine(t: float, b: Button) -> void:
	if is_instance_valid(b):
		b.set_meta(META_SHINE, t)
		b.queue_redraw()


func _clear_shine(b: Button) -> void:
	if is_instance_valid(b):
		b.remove_meta(META_SHINE)
		b.remove_meta(META_SHINE_TW)
		b.queue_redraw()


## Düğmenin kendi çizimine (zemin + yazı) eklenir: soldan sağa kayan eğik, sert kenarlı iki ışık şeridi.
func _draw_shine(b: Button) -> void:
	if not b.has_meta(META_SHINE):
		return
	var r: Rect2 = _shine_rect(b)
	if not r.has_area():
		return
	var t: float = float(b.get_meta(META_SHINE))
	var w: float = roundf(clampf(r.size.y * 0.55, 6.0, 26.0))
	var slant: float = roundf(r.size.y * 0.6)
	var x: float = roundf(lerpf(r.position.x - w * 1.6 - slant - 4.0, r.end.x, t))
	var a: float = SHINE_ALPHA * sin(PI * t)
	var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	_band(b, clip, r, x, w, slant, Color(SHINE_COLOR, a))
	_band(b, clip, r, x + w + 4.0, maxf(2.0, roundf(w * 0.3)), slant, Color(SHINE_COLOR, a * 0.7))


func _band(b: Button, clip: PackedVector2Array, r: Rect2, x: float, w: float, slant: float, col: Color) -> void:
	var poly := PackedVector2Array([
		Vector2(x + slant, r.position.y), Vector2(x + slant + w, r.position.y),
		Vector2(x + w, r.end.y), Vector2(x, r.end.y)])
	for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, clip):
		if p.size() >= 3:
			b.draw_colored_polygon(p, col)


## ------------------------------------------------------------------ pencereler / listeler

func _window_in(root: Node) -> void:
	if not is_enabled():
		return
	var items: Array[CanvasItem] = []
	if root is CanvasLayer:
		for ch: Node in root.get_children():
			if ch is CanvasItem and (ch as CanvasItem).visible:
				items.append(ch as CanvasItem)
	elif root is CanvasItem:
		items.append(root as CanvasItem)
	for ci: CanvasItem in items:
		_fade_in(ci, 0.0, FADE_TIME)
	## Telefonda sadece belirme: mobile_menu_fit.gd ilk 0,6 sn katman dönüşümünü her karede yazar / kökü büyütür - ölçek
	## animasyonu onunla kavga edip yanlış ölçekte bırakırdı.
	if MobileUIScript.enabled:
		return
	if root is CanvasLayer:
		var layer := root as CanvasLayer
		var c: Vector2 = layer.get_viewport().get_visible_rect().size * 0.5
		var tw: Tween = _new_tween(layer)
		tw.tween_method(_layer_zoom.bind(layer, layer.scale, layer.offset, c), WINDOW_FROM, 1.0, WINDOW_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif root is Control and not (root.get_parent() is Container):
		var ctl := root as Control
		var tw: Tween = _begin_scale(ctl)
		if tw:
			ctl.scale = Vector2.ONE * WINDOW_FROM
			tw.tween_property(ctl, "scale", Vector2.ONE, WINDOW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(_end_scale.bind(ctl))


## Katmanı ekran merkezi etrafında ölçekler: p' = C + s * (ofset0 + ölçek0 * p - C).
func _layer_zoom(s: float, layer: CanvasLayer, base_scale: Vector2, base_offset: Vector2, c: Vector2) -> void:
	if not is_instance_valid(layer):
		return
	layer.scale = base_scale * s
	layer.offset = base_offset * s + c * (1.0 - s)


func _cascade(container: Node, step: float, max_items: int, delay: float = 0.0) -> void:
	if not is_enabled():
		return
	var i: int = 0
	for ch: Node in container.get_children():
		var ci := ch as CanvasItem
		if ci == null or not ci.visible:
			continue
		if i >= max_items:
			break
		_fade_in(ci, delay + i * step, CASCADE_TIME)
		i += 1


## Saydamdan asıl alfasına. Asıl alfa meta'da tutulur: animasyon sürerken ikinci bir çağrı 0'ı "asıl" sanmasın.
func _fade_in(ci: CanvasItem, delay: float, dur: float, from_alpha: float = 0.0) -> void:
	var target: float = float(ci.get_meta(META_ALPHA, ci.modulate.a))
	ci.set_meta(META_ALPHA, target)
	ci.modulate.a = from_alpha * target
	var old: Tween = _meta_tween(ci, META_FADE_TW)
	if old and old.is_valid():
		old.kill() ## aynı öğeye art arda gelen belirmeler (hızlı seçim değişimi) birbiriyle yarışmasın
	var tw: Tween = _new_tween(ci)
	ci.set_meta(META_FADE_TW, tw)
	tw.tween_property(ci, "modulate:a", target, dur).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ci):
			ci.remove_meta(META_ALPHA))


## ------------------------------------------------------------------ sahne geçişi

func _on_root_child(n: Node) -> void:
	if not is_instance_valid(n) or n != get_tree().current_scene:
		return
	if not _first_scene_seen:
		_first_scene_seen = true
		return
	if not is_enabled() or DisplayServer.get_name() == "headless":
		return
	## Bu karede henüz yeni sahne çizilmedi: görüntü dokusu hâlâ ESKİ ekranın son karesi.
	var vtex: ViewportTexture = get_viewport().get_texture()
	if vtex == null:
		return
	var img: Image = vtex.get_image()
	if img == null or img.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = CROSSFADE_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	## Görüntü pencere pikselinde (siyah şeritler dahil); tuval biriminde pencerenin tamamını kaplasın (stretch "keep").
	var win: Vector2 = Vector2(img.get_size())
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var k: float = minf(win.x / maxf(1.0, vis.x), win.y / maxf(1.0, vis.y))
	if k <= 0.0:
		return
	var bars: Vector2 = (win - vis * k) * 0.5
	tr.position = -bars / k
	tr.size = win / k
	layer.add_child(tr)
	add_child(layer)
	## İlk kareler yeni sahnenin kurulumuyla uzun sürebilir; söndürme onlar geçince başlasın ki görünsün.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(tr):
		return
	var tw: Tween = _new_tween(tr)
	tw.tween_property(tr, "modulate:a", 0.0, CROSSFADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(layer.queue_free)
