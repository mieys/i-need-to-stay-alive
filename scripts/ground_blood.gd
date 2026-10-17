extends Node2D

## Hasar alan karakterin ayağının dibine sıçrayan ve yerde bir süre kalan kan (kullanıcı isteği 2026-10-14: "yere de
## hafif kan fışkırmasını ve yerde bir süre o kanın kalmasını istiyorum. pixel art olacak").
##
## - Birkaç damla bedenden kısa bir yay çizerek fırlar (FLY süresi), düştüğü yerde 1x1..3x2 piksellik leke olur; ayak
##   dibinde küçük bir birikinti hemen belirir. Lekeler STAY_TIME boyunca durur (pıhtılaşır gibi koyulaşır), sonra
##   FADE_TIME'da söner. Pikseller karakterin sanat pikseliyle aynı ölçek/ızgarada (death_blood.gd ile aynı palet).
## - Dünyada durur (haritanın hemen üstü, enemy_abilities.place_on_ground): karakter yürüyünce leke geride kalır,
##   yaratıklar ve oyuncular üstünde yürür.
## - Çizim sadece damlalar havadayken yenilenir; sonrası durağan (kare başı maliyet yok), sönme modulate tween'i.
##
## Çok oyunculu: fx_blood_splatter.gd _ready'sinden doğar - o sahne kasterde VE (skill_scene yayınıyla) diğer
## istemcilerde zaten açılıyor, bu yüzden ek RPC yok; her istemci damlaları kendi rastgele seçer (paylaşılan oyun
## durumu değil, kozmetik).

const STAY_TIME := 8.0
const FADE_TIME := 2.5
const MAX_ALIVE := 24 ## aşılırsa en eski leke hemen söner (zehir/yanma tikleri yeri kana boğmasın)
const MIN_INTERVAL_MS := 250 ## aynı karakter için iki leke arası en az süre
const META_LAST := &"ground_blood_ms"

const C_BODY := Color(0.60, 0.08, 0.13)
const C_RIM := Color(0.26, 0.03, 0.06)
const C_LIP := Color(0.74, 0.15, 0.19)
const C_CLOT := Color(0.72, 0.62, 0.66) ## modulate hedefi: zamanla koyulaşma

static var _alive: Array = []

var _drops: Array = [] ## {from, to, t, h, sz} - leke yerel pikseli
var _pool: Vector2i = Vector2i(3, 2)
var _elapsed: float = 0.0
var _fly_end: float = 0.0
var _fading: bool = false
var _stay_tween: Tween = null


## host: hasar alan oyuncu (player.gd) ya da kuklası (remote_player.gd).
static func spawn(host: Node2D) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	## Görünmeyen (çalıda saklanan uzak oyuncu vb.) karakterin yerini kan ele vermesin.
	if not host.is_visible_in_tree() or host.modulate.a < 0.3:
		return
	var tree: SceneTree = host.get_tree()
	if tree.current_scene == null:
		return
	var now: int = Time.get_ticks_msec()
	if host.has_meta(META_LAST) and now - int(host.get_meta(META_LAST)) < MIN_INTERVAL_MS:
		return
	host.set_meta(META_LAST, now)
	var node: Node2D = (load("res://scripts/ground_blood.gd") as GDScript).new()
	tree.current_scene.add_child(node)
	preload("res://scripts/enemy_abilities.gd").place_on_ground(tree, node)
	var feet: Node2D = host.get_node_or_null("Shadow") as Node2D
	node.global_position = feet.global_position if feet != null else host.global_position
	var a = host.get("anim")
	var px: Vector2 = Vector2(0.6, 0.6)
	if a != null and is_instance_valid(a) and a is Node2D:
		px = (a as Node2D).global_scale.abs()
	node.global_scale = px
	## Damlaların çıkış noktası: bedenin ortası (leke yerel pikselinde, ayağa göre).
	var body_local: Vector2 = (host.global_position - node.global_position) / px
	node.call("_setup", body_local)


func _setup(body_local: Vector2) -> void:
	name = "GroundBlood"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pool = Vector2i(randi_range(2, 4), 2)
	var n: int = randi_range(4, 7)
	for i in n:
		var ang: float = randf() * TAU
		var dist: float = randf_range(5.0, 15.0)
		var hs: float = randf()
		var sz: Vector2i = Vector2i(2, 2) if hs > 0.8 else (Vector2i(2, 1) if hs > 0.45 else Vector2i(1, 1))
		if hs > 0.93:
			sz = Vector2i(3, 2)
		## Yukarıdan bakış: dikey yayılım yarıya basık.
		var to: Vector2 = Vector2(cos(ang) * dist, sin(ang) * dist * 0.5).round()
		var t: float = randf_range(0.16, 0.30)
		_fly_end = maxf(_fly_end, t)
		_drops.append({"from": body_local, "to": to, "t": t, "h": randf_range(3.0, 7.0), "sz": sz})
	_alive.append(self)
	while _alive.size() > MAX_ALIVE:
		var old = _alive.pop_front()
		if is_instance_valid(old):
			old.call("_fade", 0.5)


func _exit_tree() -> void:
	_alive.erase(self)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _fly_end:
		set_process(false)
		_stay_tween = create_tween()
		_stay_tween.tween_property(self, "modulate", C_CLOT, STAY_TIME)
		_stay_tween.tween_callback(_fade.bind(FADE_TIME))


func _fade(time: float) -> void:
	if _fading:
		return
	_fading = true
	set_process(false)
	if _stay_tween != null and _stay_tween.is_valid():
		_stay_tween.kill()
	_elapsed = _fly_end
	queue_redraw()
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, time)
	tw.tween_callback(queue_free)


func _draw() -> void:
	## Ayak dibi birikinti: koyu kenar + gövde + altta ıslak parlama pikseli.
	var pw: int = _pool.x
	draw_rect(Rect2(-pw, -1, pw * 2, 2), C_RIM)
	draw_rect(Rect2(-pw + 1, -1, pw * 2 - 2, 1), C_BODY)
	draw_rect(Rect2(-pw + 1, 0, pw * 2 - 2, 1), C_BODY)
	draw_rect(Rect2(-pw + 2, 0, 1, 1), C_LIP)
	for d in _drops:
		var k: float = clampf(_elapsed / float(d["t"]), 0.0, 1.0)
		var to: Vector2 = d["to"]
		var sz: Vector2i = d["sz"]
		if k < 1.0:
			## Havada: yaylı tek piksel + bir piksellik iz.
			var p: Vector2 = (d["from"] as Vector2).lerp(to, k)
			p.y -= sin(k * PI) * float(d["h"])
			p = p.floor()
			draw_rect(Rect2(p, Vector2.ONE), C_LIP)
			var k2: float = maxf(0.0, k - 0.18)
			var q: Vector2 = (d["from"] as Vector2).lerp(to, k2)
			q.y -= sin(k2 * PI) * float(d["h"])
			draw_rect(Rect2(q.floor(), Vector2.ONE), C_BODY)
			continue
		draw_rect(Rect2(to, Vector2(sz)), C_BODY)
		if sz.x >= 2 and sz.y >= 2:
			## Büyük leke: alt sıra koyu kenar, sol üst köşe ıslak parlama.
			draw_rect(Rect2(to + Vector2(0, sz.y - 1), Vector2(sz.x, 1)), C_RIM)
			draw_rect(Rect2(to, Vector2.ONE), C_LIP)
		elif sz == Vector2i(1, 1):
			draw_rect(Rect2(to, Vector2.ONE), C_RIM)
