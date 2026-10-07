extends Node

## Telefon: açılır ekranları (mobile_ui.gd FIT_LAYER_SCRIPTS) içerikleri ekrana sığacak kadar büyütüp ortalar - kullanıcı
## isteği 2026-10-01: "arayüzleri büyüt ve doğru konumda olduklarından emin ol". mobile_ui.gd apply() kök pencereye
## ekler; sahneye eklenen her eşleşen CanvasLayer'a bir MenuFitter takar. Masaüstünde hiç yaratılmaz.
const MobileUIScript := preload("res://scripts/mobile_ui.gd")


## Kökü Control olan menüler -> büyütülecek çocuk adları (boşsa sadece ortalanır). Bkz. RootFitter.
## character_select.gd ve lobby_menu.gd 2026-10-03'ten beri telefonda kendi tam ekran yerleşimini kurar (_build_mobile) -
## listede YOK.
const FIT_ROOT_SCRIPTS: Dictionary = {
	"res://scripts/main_menu.gd": ["TitleSign", "MenuPanel"],
}


func on_node_added(n: Node) -> void:
	if n is Control and n.get_script() != null and FIT_ROOT_SCRIPTS.has((n.get_script() as Script).resource_path):
		var rf := RootFitter.new()
		rf.name = "MobileRootFit"
		rf.grow = FIT_ROOT_SCRIPTS[(n.get_script() as Script).resource_path]
		n.add_child.call_deferred(rf)
		return
	if not (n is CanvasLayer):
		return
	var sc: Script = n.get_script() as Script
	if sc == null or not MobileUIScript.FIT_LAYER_SCRIPTS.has(sc.resource_path):
		return
	var f := MenuFitter.new()
	f.name = "MobileMenuFit"
	n.add_child.call_deferred(f)


## Ekran (CanvasLayer) görünür olduğunda içeriğini ölçer, katmanın dönüşümüyle büyütüp ortalar. Açılış animasyonları
## (uçan kartlar) kutuyu sonradan büyütebilir: ilk FIT_WINDOW saniyede ve görünür alt-düğüm sayısı değiştikçe (ör.
## duraklat -> ayarlar) yeniden ölçülür; aynı açılışta ölçek sadece KÜÇÜLEBİLİR (zıplayıp büyümesin).
## Girdi: Godot GUI olayları katman dönüşümünü hesaba katar - düğmeler büyümüş halleriyle tıklanır.
class MenuFitter extends Node:
	const FIT_WINDOW := 0.6
	const RESIZE_POLL := 0.25
	const RESIZE_TOL := 6.0 ## px - hover/animasyon titreşimi yeniden ölçümü tetiklemesin
	var _fit_size: Vector2 = Vector2.ZERO
	var _resize_poll: float = 0.0
	var _scale: float = 0.0
	var _age: float = 0.0
	var _was_visible: bool = false
	var _child_sig: int = -1

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		var layer := get_parent() as CanvasLayer
		if layer == null:
			return
		if not layer.visible:
			_was_visible = false
			return
		if not _was_visible:
			_was_visible = true
			_scale = 0.0
			_age = 0.0
		var sig: int = _visible_children(layer)
		if _age > FIT_WINDOW and sig == _child_sig:
			## Alt-düğüm sayısı aynı ama içerik BOYU sonradan değiştiyse (zafer penceresinde diğer oyuncuların takım tablosu satırları
			## ağdan geç gelir) baştan ölç: kilitli kalan ölçek büyüyen pencereyi ekran dışına taşırırdı.
			if not _resized_since_fit(layer, delta):
				return
			_scale = 0.0
			_age = 0.0
		if sig != _child_sig and _age > FIT_WINDOW:
			_scale = 0.0 ## yeni bir alt panel açıldı/kapandı: baştan ölç
			_age = 0.0
		_child_sig = sig
		_age += delta
		var vp: Vector2 = layer.get_viewport().get_visible_rect().size
		var r: Rect2 = MobileUIScript.content_rect(layer, vp)
		if r.size.x < 1.0:
			return
		var s: float = MobileUIScript.fit_scale(r.size, vp)
		if _scale > 0.0:
			s = minf(s, _scale)
		_scale = s
		_fit_size = r.size
		layer.transform = MobileUIScript.fit_transform(r, s, vp)

	## Son ölçümden beri içerik boyu RESIZE_TOL'dan fazla değişti mi? Yalnız RESIZE_POLL aralığıyla bakılır.
	func _resized_since_fit(layer: CanvasLayer, delta: float) -> bool:
		_resize_poll += delta
		if _resize_poll < RESIZE_POLL:
			return false
		_resize_poll = 0.0
		var r: Rect2 = MobileUIScript.content_rect(layer, layer.get_viewport().get_visible_rect().size)
		return r.size.x >= 1.0 and (r.size - _fit_size).length() > RESIZE_TOL

	func _visible_children(layer: Node) -> int:
		var n: int = 0
		for c in layer.get_children():
			if c is CanvasItem and (c as CanvasItem).visible:
				n += 1
				for cc in c.get_children():
					if cc is CanvasItem and (cc as CanvasItem).visible:
						n += 1
		return n


## Kökü Control olan, 1920x1080 tasarım koordinatıyla mutlak yerleştirilmiş menüler (MenuKit.place). Geniş telefonda
## (20:9 -> 2400x1080 tuval) içerik sola yaslı kalıyordu (kullanıcı: "simetrik değil"): kök tasarım boyutunda ortalanır,
## tam-ekran çocuklar (arka plan, karartmalar) ekranın tamamına yayılır. "grow" listesindeki çocuklar (ana menü tabelası
## + düğme paneli) ayrıca ekrana sığacak kadar büyütülür - ipler tabelayla birlikte (adı "Rope" ile başlar).
class RootFitter extends Node:
	const DESIGN := Vector2(1920, 1080)
	var grow: Array = []
	var _orig: Dictionary = {} ## düğüm -> [global_position, scale] (büyütmeden önceki hali)
	var _done_grow: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		var root := get_parent() as Control
		if root == null:
			return
		var vp: Vector2 = root.get_viewport().get_visible_rect().size
		var d: Vector2 = ((vp - DESIGN) * 0.5).max(Vector2.ZERO)
		if root.anchor_right != 0.0 or not root.position.is_equal_approx(d):
			root.set_anchors_preset(Control.PRESET_TOP_LEFT)
			root.position = d
			root.size = DESIGN
		for c in root.get_children():
			var ctl := c as Control
			if ctl and ctl.anchor_left == 0.0 and ctl.anchor_top == 0.0 and ctl.anchor_right == 1.0 and ctl.anchor_bottom == 1.0:
				if not is_equal_approx(ctl.offset_left, -d.x) or not is_equal_approx(ctl.offset_top, -d.y):
					ctl.offset_left = -d.x
					ctl.offset_top = -d.y
					ctl.offset_right = d.x
					ctl.offset_bottom = d.y
		if not _done_grow and not grow.is_empty():
			_grow(root, vp)

	func _grow(root: Control, vp: Vector2) -> void:
		var main: Array[Control] = []
		var ropes: Array[Control] = []
		for c in root.get_children():
			var ctl := c as Control
			if ctl == null:
				continue
			if grow.has(String(ctl.name)):
				main.append(ctl)
			elif String(ctl.name).begins_with("Rope"):
				ropes.append(ctl)
		if main.is_empty() or main.any(func(m: Control) -> bool: return m.size.y < 1.0):
			return ## kapsayıcılar henüz boyutlanmadı - sonraki kare
		var r: Rect2 = main[0].get_global_rect()
		for m in main:
			r = r.merge(m.get_global_rect())
		var s: float = MobileUIScript.fit_scale(r.size, vp)
		var xf: Transform2D = MobileUIScript.fit_transform(r, s, vp)
		for c in main + ropes:
			c.pivot_offset = Vector2.ZERO
			c.scale = c.scale * s
			c.global_position = xf * c.global_position
		_done_grow = true
