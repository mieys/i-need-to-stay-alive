extends RefCounted

## Görev ağacı atışlarının ortak piksel çizim yardımcıları + renkleri (mission_tree_bolt.gd / mission_tree_blast.gd; 2026-10-19, madde 317).
## Yuvarlak hatlar dünya pikseli ızgarasında satır satır dikdörtgen (yumuşak daire değil - oyunun piksel efekt dili).

const CORE := Color(0.88, 0.99, 1.0)
const MID := Color(0.45, 0.85, 1.0)
const EDGE := Color(0.18, 0.48, 0.88)


static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Toplamsal hale/iz çizimi için çocuk düğüm (parent'ın ARKASINDA, aynı dönüşüm). draw_fn(ci) her yeniden çizimde çağrılır.
static func make_glow_child(parent: Node2D, draw_fn: Callable) -> Node2D:
	var g := Node2D.new()
	g.material = add_material()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.show_behind_parent = true
	parent.add_child(g)
	g.draw.connect(draw_fn.bind(g))
	return g


static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	var ri: int = int(ceil(r))
	var cx: float = roundf(c.x)
	var cy: float = roundf(c.y)
	for y in range(-ri, ri + 1):
		var w: int = int(roundf(sqrt(maxf(r * r - float(y * y), 0.0))))
		if w <= 0 and absi(y) == ri:
			continue
		ci.draw_rect(Rect2(cx - w, cy + y, w * 2 + 1, 1), col)


static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, px: float) -> void:
	if col.a <= 0.0:
		return
	var n: int = maxi(8, int(TAU * r / 2.0))
	for i in range(n):
		var p: Vector2 = (c + Vector2.from_angle(TAU * float(i) / float(n)) * r).round()
		ci.draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), col)


## Gidiş yönüne bakan kristal kıymığı (uç f*len, kuyruk -f*tail, yarı genişlik w).
static func shard(ci: CanvasItem, c: Vector2, f: Vector2, length: float, tail: float, w: float) -> void:
	var n := Vector2(-f.y, f.x)
	ci.draw_colored_polygon(PackedVector2Array([c + f * length, c + n * w, c - f * tail, c - n * w]), EDGE)
	ci.draw_colored_polygon(PackedVector2Array([c + f * (length - 2.0), c + n * (w - 1.5), c - f * (tail * 0.5), c - n * (w - 1.5)]), MID)
	ci.draw_colored_polygon(PackedVector2Array([c + f * (length - 4.0), c + n * 1.0, c - f * 1.0, c - n * 1.0]), CORE)


## İz noktaları MESAFEYLE eklenir (kare hızından bağımsız: düşük FPS'te kopuk noktalara dönüşmesin), toplam boy max_len'i aşınca baştan kırpılır.
static func push_trail(trail: PackedVector2Array, pos: Vector2, step: float, max_len: float) -> PackedVector2Array:
	if trail.is_empty() or trail[trail.size() - 1].distance_to(pos) >= step:
		trail.append(pos)
	var total: float = 0.0
	for i in range(trail.size() - 1, 0, -1):
		total += trail[i].distance_to(trail[i - 1])
		if total > max_len:
			return trail.slice(i)
	return trail


## Sürekli, kuyruğa doğru incelen iz (dünya noktaları + baş = ci'nin orijini). Eklem yerleri diskle kapatılır.
static func draw_trail(ci: CanvasItem, trail: PackedVector2Array, w_tail: float, w_head: float, outer: Color, core: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in trail:
		pts.append(ci.to_local(p))
	pts.append(Vector2.ZERO)
	var n: int = pts.size()
	for i in range(1, n):
		var a: float = float(i) / float(n - 1)
		var w: float = lerpf(w_tail, w_head, a)
		ci.draw_line(pts[i - 1], pts[i], Color(outer.r, outer.g, outer.b, outer.a * a), w)
		disc(ci, pts[i], w * 0.5, Color(outer.r, outer.g, outer.b, outer.a * a * 0.6))
		ci.draw_line(pts[i - 1], pts[i], Color(core.r, core.g, core.b, core.a * a), maxf(1.0, w * 0.35))
