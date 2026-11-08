extends RefCounted
## PİKSEL KENARLI PANEL prototipi (2026-11-06, oyuna bağlı DEĞİL): bir StyleBoxFlat'i AYNI renklerle piksel kenarlı
## StyleBoxTexture'a çevirir. 1 sanat pikseli = 3 ekran px (stil rehberi). Doku yok, dither yok: düz ahşap renkleri.
## Görüntü sanat pikselinde boyanır, x3 en yakın komşu büyütülür, 9 dilim (köşe 1:1, kenar/orta düz renk -> esner).
##   A  Basamaklı Köşe : kenar 1 sanat px, köşe piksel basamak (yarıçap / 3 sanat px).
##   B  Kabartma       : A + kenarın içinde 1 sanat px ışık (üst/sol) ve gölge (alt/sağ).
##   C  Çift Çerçeve   : koyu dış hat + kenar + alta 1 sanat px sert gölge.
##   D  Oyma Köşe      : köşede kare oyuk, kenar oyuğu içeri doğru izler.

const HT := preload("res://scripts/hud_theme.gd")
const PX := 3

static var _cache: Dictionary = {}


static func profile(n: int) -> Array:
	## Köşe basamağı: satır i'de köşeden kaç sanat pikseli kesilir (simetrik piksel daire).
	if n <= 0:
		return []
	if n == 1:
		return [1]
	var out: Array = []
	for i in n:
		var d: int = n - i
		out.append(n - int(floor(sqrt(float(n * n - d * d)))))
	return out


static func to_pixel(flat: StyleBoxFlat, v: String, ctl_size: Vector2 = Vector2.ZERO) -> StyleBox:
	if flat == null or v == "simdi":
		return flat
	## kenar kalınlığı / yarıçap her yanda aynı değilse dokunma (sekme altı çizgisi vb.)
	var bw: int = flat.border_width_left
	if flat.border_width_top != bw or flat.border_width_right != bw or flat.border_width_bottom != bw:
		return flat
	var r: int = flat.corner_radius_top_left
	if flat.corner_radius_top_right != r or flat.corner_radius_bottom_left != r or flat.corner_radius_bottom_right != r:
		return flat
	var fill: Color = flat.bg_color if flat.draw_center else Color(0, 0, 0, 0)
	var border: Color = flat.border_color if bw > 0 else Color(0, 0, 0, 0)
	var b: int = 0
	if border.a > 0.0 and bw > 0:
		b = maxi(1, int(round(bw / 3.0)))
	var n: int = int(round(r / 3.0))
	var shadow: int = 0
	var kind := v
	## küçük kutular (kaydırıcı, ince şerit): basamak sığmazsa küçült
	var small: float = minf(ctl_size.x, ctl_size.y) if ctl_size != Vector2.ZERO else 999.0
	if small < 30.0:
		n = mini(n, 1)
		if kind != "A":
			kind = "A"
	var prof: Array = profile(n)
	if kind == "D":
		var q: int = mini(n, 3)
		prof = []
		for i in q:
			prof.append(q)
	var rings: int = b
	if kind == "B" and b > 0:
		rings = b + 1
	if kind == "C" and border.a > 0.0:
		rings = b + 1
		shadow = 1
	var M: int = maxi(maxi(prof.size(), rings), 1)
	if kind == "D":
		M = maxi(M, prof.size() + 1) ## orta piksel oyuğa çapraz değmesin (8 komşulu kenar)
	var key := "%s|%s|%s|%d|%d|%s" % [kind, fill.to_html(), border.to_html(), b, n, str(prof)]
	var tex: Texture2D = _cache.get(key)
	if tex == null:
		tex = _paint(kind, fill, border, b, prof, M, shadow)
		_cache[key] = tex
	var st := StyleBoxTexture.new()
	st.texture = tex
	st.texture_margin_left = M * PX
	st.texture_margin_right = M * PX
	st.texture_margin_top = M * PX
	st.texture_margin_bottom = (M + shadow) * PX
	st.draw_center = true
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		st.set_content_margin(side, flat.get_margin(side))
	st.expand_margin_left = flat.expand_margin_left
	st.expand_margin_right = flat.expand_margin_right
	st.expand_margin_top = flat.expand_margin_top
	st.expand_margin_bottom = flat.expand_margin_bottom + shadow * PX
	return st


static func _inside(x: int, y: int, W: int, H: int, prof: Array) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	var dx: int = mini(x, W - 1 - x)
	var dy: int = mini(y, H - 1 - y)
	if dy < prof.size() and dx < int(prof[dy]):
		return false
	if dx < prof.size() and dy < int(prof[dx]):
		return false
	return true


static func _paint(kind: String, fill: Color, border: Color, b: int, prof: Array, M: int, shadow: int) -> Texture2D:
	var W: int = 2 * M + 1
	var H0: int = W
	var H: int = H0 + shadow
	## 4 komşulu uzaklık (kenardan içeri halka numarası)
	var ring: Dictionary = {}
	var frontier: Array = []
	## D: oyuğun iç köşesi de kenar olsun (8 komşu) -> kenar oyuğu L biçiminde içeri izler
	var dirs0: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if kind == "D":
		dirs0 = dirs0 + [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for y in H0:
		for x in W:
			if not _inside(x, y, W, H0, prof):
				continue
			for d: Vector2i in dirs0:
				if not _inside(x + d.x, y + d.y, W, H0, prof):
					ring[Vector2i(x, y)] = 0
					frontier.append(Vector2i(x, y))
					break
	var k := 0
	while not frontier.is_empty() and k < M + 2:
		var nxt: Array = []
		for p: Vector2i in frontier:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if _inside(q.x, q.y, W, H0, prof) and not ring.has(q):
					ring[q] = k + 1
					nxt.append(q)
		frontier = nxt
		k += 1
	var hi: Color = Color(fill.lerp(border, 0.5), fill.a) if border.a > 0.0 else fill.lightened(0.15)
	var lo: Color = Color(fill.darkened(0.45), fill.a)
	var outline: Color = HT.OUTLINE
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in H0:
		for x in W:
			var p := Vector2i(x, y)
			if not _inside(x, y, W, H0, prof):
				continue
			var rr: int = int(ring.get(p, 99))
			var col: Color = fill
			match kind:
				"C":
					if border.a > 0.0 and rr == 0:
						col = outline
					elif rr <= b:
						col = border if border.a > 0.0 else fill
				_:
					if rr < b:
						col = border
					elif kind == "B" and b > 0 and rr == b and fill.a > 0.0:
						var t: int = mini(y, x)
						var bt: int = mini(H0 - 1 - y, W - 1 - x)
						col = hi if t <= bt else lo
			img.set_pixel(x, y, col)
	if shadow > 0:
		var sc := Color(HT.DEEP, 0.75)
		for y in range(1, H):
			for x in W:
				if not _inside(x, y, W, H0, prof) and _inside(x, y - 1, W, H0, prof):
					img.set_pixel(x, y, sc)
	img.resize(W * PX, H * PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## ---------------------------------------------------------------- bir alt ağaçtaki tüm düz kutuları topla / değiştir
static func collect(root: Node) -> Array:
	## [{kind:"ovr", node, name, sb} | {kind:"theme", theme, type, name, sb}]
	var out: Array = []
	var themes: Dictionary = {}
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for nd in nodes:
		if not (nd is Control):
			continue
		var c := nd as Control
		for pr: Dictionary in c.get_property_list():
			var pn: String = pr["name"]
			if pn.begins_with("theme_override_styles/"):
				var s = c.get(pn)
				if s is StyleBoxFlat:
					out.append({"kind": "ovr", "node": c, "name": pn.trim_prefix("theme_override_styles/"), "sb": s})
		if c.theme != null and not themes.has(c.theme):
			themes[c.theme] = true
			for tp: String in c.theme.get_stylebox_type_list():
				for nm: String in c.theme.get_stylebox_list(tp):
					var s2 = c.theme.get_stylebox(nm, tp)
					if s2 is StyleBoxFlat:
						out.append({"kind": "theme", "theme": c.theme, "type": tp, "name": nm, "sb": s2})
	return out


static func apply(entries: Array, v: String) -> int:
	var n := 0
	for e: Dictionary in entries:
		if e["kind"] == "ovr":
			var c: Control = e["node"]
			if not is_instance_valid(c):
				continue
			var ns: StyleBox = to_pixel(e["sb"], v, c.size)
			c.add_theme_stylebox_override(e["name"], ns)
			if ns != e["sb"]:
				n += 1
		else:
			var th: Theme = e["theme"]
			var ns2: StyleBox = to_pixel(e["sb"], v)
			th.set_stylebox(e["name"], e["type"], ns2)
			if ns2 != e["sb"]:
				n += 1
	return n
