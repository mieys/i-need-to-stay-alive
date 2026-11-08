extends Node2D
## RUH HÂLİ görseli (madde 438/439, 2026-11-07): level/sandık menüsündeki oyuncu (yerel Player VEYA RemotePlayer kuklası) dünyada değilmiş gibi
## MAVİ RUH olarak çizilir - kullanıcının seçtiği prototip "A - Hayalet" + GÖLGESİZ (kullanıcı: "hayalet olsun ama gölge olmamalı").
## Asıl AnimatedSprite2D gizlenir (kare ilerlemeye devam eder - okuma klibi oynar), bu düğüm her karede onun karesini kopyalayıp
## `shaders/ruh_hali.gdshader` ile çizer: kendi çiziminden camgöbeği, yarı saydam, aşağı doğru silinen kuyruk; yerden 2 sanat px yukarıda
## +-1 px süzülür. Ayak gölgesi ("Shadow" düğümü, ground_shadow.gd - 15 karakterin hepsinde) ruh hâli boyunca gizli.
## Sahibi PROCESS_MODE_DISABLED iken de çalışsın diye ALWAYS. Kaster ve kukla AYNI düğümü kurar (ek ağ yok: durum
## NetworkManager.level_up_busy_peers'tan gelir, bkz. limbo.gd).

const ShaderRes: Shader = preload("res://shaders/ruh_hali.gdshader")
const NODE_NAME := "LimboFx"
const FLOAT_PX := 2.0 ## sanat pikseli: yerden yükseklik
const BOB_PX := 1.0 ## sanat pikseli: süzülme genliği (tam piksele yuvarlanır)
const BOB_SPEED := 2.4

## Karenin opak satır aralığı önbelleği (atlas + bölge -> Vector2i(üst, alt)); kuyruk silinmesi gövdenin kendi boyuna göre.
static var _rows_cache: Dictionary = {}

var src: AnimatedSprite2D = null
var _copy: Sprite2D = null
var _mat: ShaderMaterial = null
var _src_was_visible: bool = true
var _shadow: CanvasItem = null
var _shadow_was_visible: bool = false
var _restored: bool = false
var _t: float = 0.0


static func attach(host: Node2D, anim: AnimatedSprite2D) -> void:
	if host == null or not is_instance_valid(anim):
		return
	var old: Node = host.get_node_or_null(NODE_NAME)
	if old != null:
		if not old.is_queued_for_deletion():
			return
		## Aynı karede bitip yeniden başlayan ruh hâli (art arda seviye): silinmeyi bekleyen eskisi yeni görseli engellemesin.
		old.name = NODE_NAME + "_eski"
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/limbo_fx.gd"))
	fx.name = NODE_NAME
	fx.set("src", anim)
	host.add_child(fx)


static func detach(host: Node) -> void:
	if host == null:
		return
	var fx: Node = host.get_node_or_null(NODE_NAME)
	if fx != null:
		fx.call("restore")
		fx.queue_free()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_instance_valid(src):
		return
	_t = randf() * TAU
	z_index = src.z_index
	z_as_relative = src.z_as_relative
	_shadow = get_parent().get_node_or_null("Shadow") as CanvasItem
	if _shadow != null:
		_shadow_was_visible = _shadow.visible
		_shadow.visible = false
	_copy = Sprite2D.new()
	_mat = ShaderMaterial.new()
	_mat.shader = ShaderRes
	_copy.material = _mat
	_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_copy)
	_src_was_visible = src.visible
	src.visible = false
	## Gövde zaten gizliyse (Matthew topu gibi bir form karakteri saklıyor) ruh kopyası da çizilmez - form son hâliyle donar.
	_copy.visible = _src_was_visible
	if not _src_was_visible:
		set_process(false)
		return
	_sync_copy()


## Ruh hâli bitti: sprite + gölge eski hâline. Bundan sonra bu düğüm (kare sonunda silinene dek) HİÇBİR şeye dokunmaz - kullanıcı
## 2026-11-07 "level atladıktan sonra oyun devam edince karakter görünmez oldu": silinmeden önceki son karede _process sprite'ı
## yeniden gizliyordu (test_limbo test_character_visible_after_frames_once_limbo_ends).
func restore() -> void:
	if _restored:
		return
	_restored = true
	set_process(false)
	if _copy != null:
		_copy.visible = false
	if is_instance_valid(src):
		src.visible = _src_was_visible
	if is_instance_valid(_shadow):
		_shadow.visible = _shadow_was_visible


func _exit_tree() -> void:
	restore()


func _process(delta: float) -> void:
	if _restored:
		return
	if not is_instance_valid(src):
		queue_free()
		return
	_t += delta
	if src.visible: ## başka bir kod geri açtıysa (form/görünmezlik) yine gizle - ruh tek görüntü
		src.visible = false
	if is_instance_valid(_shadow) and _shadow.visible:
		_shadow.visible = false
	_sync_copy()


func _sync_copy() -> void:
	if _copy == null or src.sprite_frames == null or not src.sprite_frames.has_animation(src.animation):
		return
	var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	_copy.texture = tex
	_copy.scale = src.scale
	_copy.offset = src.offset
	_copy.centered = src.centered
	_copy.flip_h = src.flip_h
	_copy.flip_v = src.flip_v
	_copy.rotation = src.rotation
	var px: float = absf(src.scale.y)
	_copy.position = src.position - Vector2(0.0, (FLOAT_PX + roundf(sin(_t * BOB_SPEED) * BOB_PX)) * px)
	var region := Vector4(0, 0, 1, 1)
	var body := Vector2(0, 1)
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		var at := tex as AtlasTexture
		var asz: Vector2 = at.atlas.get_size()
		if asz.x > 0.0 and asz.y > 0.0:
			region = Vector4(at.region.position.x / asz.x, at.region.position.y / asz.y, at.region.size.x / asz.x, at.region.size.y / asz.y)
			var rows: Vector2i = _body_rows(at)
			body = Vector2((at.region.position.y + rows.x) / asz.y, (at.region.position.y + rows.y + 1) / asz.y)
	_mat.set_shader_parameter("region", region)
	_mat.set_shader_parameter("body_y", body)


static func _body_rows(at: AtlasTexture) -> Vector2i:
	var key: String = "%d:%s" % [at.atlas.get_instance_id(), str(at.region)]
	if _rows_cache.has(key):
		return _rows_cache[key]
	var r := Rect2i(at.region)
	var out := Vector2i(0, maxi(r.size.y - 1, 0))
	var img: Image = at.atlas.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var top: int = -1
		var bot: int = -1
		for y in r.size.y:
			for x in r.size.x:
				if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.5:
					if top < 0:
						top = y
					bot = y
					break
		if top >= 0:
			out = Vector2i(top, bot)
	_rows_cache[key] = out
	return out
