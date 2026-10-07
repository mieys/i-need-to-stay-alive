extends Control

## Sandık sırası efekti (kullanıcı isteği 2026-10-07: "bir oyuncu normal sandığı aldığında sıra onda değilse sandık grup
## penceresinden o kişinin barına gidecek"). Normal sandıklar oyunculara SIRAYLA verilir (NetworkManager.next_chest_turn);
## sandığı yerden alan kişi sıradaki kişi değilse küçük bir sandık, alanın çubuğundan (müttefikse grup panelindeki satırı,
## kendimizsek alttaki can çubuğu) sıradakinin çubuğuna uçar, varınca halka + kıvılcım patlar. Herkesin ekranında kendi
## görünümüyle oynar (NetworkManager._rpc_announce_chest_winner) - ağdan konum gitmez, her peer çubukların yerini kendi bilir.
## Oyun duraklatılmışken de oynar (sandık menüsü açıkken biri sandık alabilir): kendi CanvasLayer'ı PROCESS_MODE_ALWAYS.

const SHEET := preload("res://assets/sprites/chests/chest_normal_t1.png")
const SFX_LAND := preload("res://Sound FX Starter Pack Vol. 1/Motions and Impacts/Impact Redwood.wav")
const FRAME := 48
const LAYER_NAME := "ChestPassLayer"
const LAYER_INDEX := 100 ## menülerin (bekleme katmanı 90, grup paneli 96) üstünde
const POP_TIME := 0.18
const FLY_TIME := 0.8
const LAND_TIME := 0.3
const POP_SCALE := 2.0 ## 48 px kare 2x = 96 px: satırdan (~80 px) biraz büyük, uçarken okunur
const END_SCALE := 1.0
const ARC_HEIGHT := 90.0 ## uçuş yayının orta noktası doğrudan çizginin bu kadar (ekran px) yukarısında
const TRAIL_STEP := 0.045 ## uçuşta her bu kadar ilerlemede bir kıvılcım bırakılır (0..1)
const GOLD := Color("#ffd35a")
const GOLD_LIGHT := Color("#fff1b0")

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _icon: TextureRect = null
var _trail_next: float = 0.0


## İki ekran noktası arasında (canvas koordinatı) uçuş. Katman yoksa kurar. Dönen: efekt düğümü (testler için).
static func play(tree: SceneTree, from_pos: Vector2, to_pos: Vector2) -> Control:
	if tree == null or not is_finite(from_pos.x) or not is_finite(to_pos.x):
		return null
	var layer: CanvasLayer = _ensure_layer(tree)
	if layer == null:
		return null
	var fx: Control = new()
	layer.add_child(fx)
	fx.call("_start", from_pos, to_pos)
	return fx


## Sandığı alan (picker) -> sıradaki (winner) çubuğu: konumlar bu peer'in HUD'undan okunur. Çubuklardan biri bulunamazsa
## (panel kapalı / müttefik satırı henüz yok) efekt atlanır - yüzen yazı yine de bilgi verir. local_id: bu peer'in kimliği.
static func play_between_peers(tree: SceneTree, picker_id: int, winner_id: int, local_id: int) -> Control:
	if tree == null or picker_id <= 0 or winner_id <= 0 or picker_id == winner_id:
		return null
	var hud: Node = _find_hud(tree)
	if hud == null:
		return null
	var from_pos: Vector2 = bar_center(hud, picker_id, local_id)
	var to_pos: Vector2 = bar_center(hud, winner_id, local_id)
	if not is_finite(from_pos.x) or not is_finite(to_pos.x):
		return null
	return play(tree, from_pos, to_pos)


## Bir oyuncunun çubuğunun ekrandaki ortası; bulunamazsa Vector2.INF.
static func bar_center(hud: Node, peer_id: int, local_id: int) -> Vector2:
	if peer_id == local_id:
		return hud.call("get_own_bar_center") if hud.has_method("get_own_bar_center") else Vector2.INF
	var party: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
	if party != null and party.has_method("get_row_center"):
		return party.call("get_row_center", peer_id)
	return Vector2.INF


static func _find_hud(tree: SceneTree) -> Node:
	var scene: Node = tree.current_scene
	return scene.get_node_or_null("HUD") if scene != null else null


static func _ensure_layer(tree: SceneTree) -> CanvasLayer:
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var existing: Node = parent.get_node_or_null(LAYER_NAME)
	if existing is CanvasLayer:
		return existing as CanvasLayer
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = LAYER_INDEX
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	return layer


func _start(from_pos: Vector2, to_pos: Vector2) -> void:
	_from = from_pos
	_to = to_pos
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(FRAME, FRAME)
	pivot_offset = size * 0.5
	position = _from - size * 0.5
	scale = Vector2.ONE * 0.5
	modulate.a = 0.0

	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(0, 0, FRAME, FRAME) ## kapalı sandık karesi
	_icon = TextureRect.new()
	_icon.texture = atlas
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = size
	add_child(_icon)

	## 1) Çıkış noktasında belirir; 2) yay çizerek hedefe uçar; 3) varınca halka + kıvılcım, sandık küçülüp söner.
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, POP_TIME)
	tw.tween_property(self, "scale", Vector2.ONE * POP_SCALE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_method(_fly, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(_land)
	tw.chain().tween_property(self, "scale", Vector2.ONE * (END_SCALE * 0.5), LAND_TIME).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, LAND_TIME)
	tw.chain().tween_callback(queue_free)


## t: 0..1 uçuş ilerlemesi. İkinci dereceden Bezier: kontrol noktası çizginin ortasının yukarısında.
func _fly(t: float) -> void:
	var ctrl: Vector2 = (_from + _to) * 0.5 + Vector2(0.0, -ARC_HEIGHT)
	var p: Vector2 = _from.lerp(ctrl, t).lerp(ctrl.lerp(_to, t), t)
	position = p - size * 0.5
	rotation = sin(t * PI * 2.0) * 0.22
	scale = Vector2.ONE * lerpf(POP_SCALE, END_SCALE * 1.3, t)
	while t >= _trail_next and _trail_next < 1.0:
		_spark(p, GOLD if int(_trail_next / TRAIL_STEP) % 2 == 0 else GOLD_LIGHT, 5.0, 0.35, 10.0)
		_trail_next += TRAIL_STEP


func _land() -> void:
	rotation = 0.0
	position = _to - size * 0.5
	_ring(_to)
	for i in range(10):
		var ang: float = TAU * float(i) / 10.0
		_spark(_to, GOLD if i % 2 == 0 else GOLD_LIGHT, 6.0, 0.45, 46.0, Vector2.from_angle(ang))
	var p := AudioStreamPlayer.new()
	p.stream = SFX_LAND
	p.volume_db = -12.0
	p.pitch_scale = 1.6
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Varış halkası: altın çizgili, genişleyip sönen daire (katmana eklenir - sandık küçülüp silinse de görünmeye devam eder).
func _ring(center: Vector2) -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(64)
	sb.anti_aliasing = false
	ring.add_theme_stylebox_override("panel", sb)
	ring.size = Vector2(28, 28)
	ring.pivot_offset = ring.size * 0.5
	ring.position = center - ring.size * 0.5
	layer.add_child(ring)
	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 4.0, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


## Küçük kare kıvılcım (piksel dilinde): drift kadar (dir yönünde ya da rastgele) süzülüp söner. Katmana eklenir.
func _spark(center: Vector2, color: Color, px: float, life: float, drift: float, dir: Vector2 = Vector2.ZERO) -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var s := ColorRect.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.color = color
	s.size = Vector2(px, px)
	s.position = center - s.size * 0.5
	layer.add_child(s)
	var d: Vector2 = dir if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
	var tw: Tween = s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position", s.position + d * drift, life).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)
