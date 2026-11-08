# YETENEK PANELİ ARKA PENCERESİ prototipleri v2 (2026-10-31, madde 391; oyuna bağlı DEĞİL).
# v1 (Levha / Oval Tahta / Gömme Tepsi / Pirinç Köşe) REDDEDİLDİ - kullanıcı: "bunları beğenmedim aynı renkte daha farklı varyantlar yap".
# Ders: renk aynı kalmalı (bugünkü "Kısık Ahşap" kahvesi, yeni renk yok: v1 C koyu tepsi + D pirinç renk değiştiriyordu), fark SİLÜET + YAPI'da.
#   A Bölmeli Konsol : tek gövde, içinde oyma kirişler -> portre bölmesi / yetenek rafı / kalp bölmesi / çubuk bölmesi (gömme bölmeler).
#   B Kemerli Portre : portre sütunu panelin üstüne kemer gibi yükselir (oyma kemer çizgisi + küçük rozet), sağ uç bugünkü gibi oval.
#   C Tomar Uçlu     : iki uçta topuzlu ahşap merdane (parşömen tomarı tutacağı), arada ince kenarlı levha.
#   D Kütük Kiriş    : üstte ve altta iki uçtan taşan kütük kiriş (kesik uç halkası + ağaç çivisi), arada pano; kütük damarı karo.
# Panelin içindeki her şey AYNI (yuvalar, çubuklar, portre, rozet, kalpler). Ölçüler hud.gd ile (dock tasarım pikseli / 2 = sanat pikseli).
# Çıktı out/v2/tex_<X>/{dock,side}.png + out/v2/palettes.json (dock_capture.gd: payları + taşma payları expand_margin).
# Kullanım: python tools/proto_20261031/dock_pencere/gen_dock_pencere_v2.py
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_dock_pencere as v1  # noqa: E402  (rgb, depth_map, palet)

OUT = os.path.join(HERE, "out", "v2")
U = 2  # sanat pikseli = 2 doku pikseli (bugünkü panel_ability_bar ile aynı yoğunluk)
H = 76  # DOCK_H 152 / U
OUTLINE, RIM, RIM_HI, RIM_LO, WOOD_MID = v1.OUTLINE, v1.RIM, v1.RIM_HI, v1.RIM_LO, v1.WOOD_MID
PANEL, PANEL_HI, PANEL_LO = v1.PANEL, v1.PANEL_HI, v1.PANEL_LO
# panel içeriğinin sanat pikseli konumları (hud.gd: portre 14..98, yetenek sırası x 112 / y 14..78, can 86.., kalpler W-100..W-12)
CONTENT_X = 56
SKILL_Y1 = 39
HEARTS_W = 50


class Art:
	"""Sanat pikseli tuvali; (0,0) panelin sol üstü, ex = (sol, üst, sağ, alt) taşma (panel dışına çizilen kısım)."""

	def __init__(self, w, ex=(0, 0, 0, 0)):
		self.w = w
		self.ex = ex
		self.img = Image.new("RGBA", (w + ex[0] + ex[2], H + ex[1] + ex[3]), (0, 0, 0, 0))
		self.px = self.img.load()

	def xs(self):
		return range(-self.ex[0], self.w + self.ex[2])

	def ys(self):
		return range(-self.ex[1], H + self.ex[3])

	def set(self, x, y, col):
		X = x + self.ex[0]
		Y = y + self.ex[1]
		if 0 <= X < self.img.width and 0 <= Y < self.img.height:
			self.px[X, Y] = v1.rgb(col)

	def tex(self):
		return self.img.resize((self.img.width * U, self.img.height * U), Image.NEAREST)


def rect_in(x, y, x0, y0, x1, y1, tl=(), tr=(), bl=(), br=()):
	"""[x0,x1) x [y0,y1) dikdörtgeni, köşe başına kesim profili (satır i'de kesilen piksel)."""
	if not (x0 <= x < x1 and y0 <= y < y1):
		return False
	for prof, dx, dy in ((tl, x - x0, y - y0), (tr, x1 - 1 - x, y - y0), (bl, x - x0, y1 - 1 - y), (br, x1 - 1 - x, y1 - 1 - y)):
		if dy < len(prof) and dx < prof[dy]:
			return False
	return True


def plate(a, inside, layers, fill):
	"""inside(x, y) şeklini dıştan içe katmanlarla boyar (üst/sol ışık, alt/sağ gölge). Derinlik sözlüğü döner."""
	xs = list(a.xs())
	ys = list(a.ys())
	m = [[inside(x, y) for x in xs] for y in ys]
	depth, side = v1.depth_map(m)
	out = {}
	for j, y in enumerate(ys):
		for i, x in enumerate(xs):
			if not m[j][i]:
				continue
			d = depth[j][i]
			out[(x, y)] = d
			if d < len(layers):
				lt, dk = layers[d]
				a.set(x, y, lt if side[j][i] > 0 else dk)
			else:
				a.set(x, y, fill)
	return out


def disc(a, cx, cy, r, inner=None):
	"""Küçük oyma rozet: dış hat + sol üst açık / sağ alt koyu dolgu (+ istenirse iç halka)."""
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
			if d > r:
				continue
			if d > r - 1.0:
				a.set(x, y, OUTLINE)
			elif inner is not None and abs(d - inner) < 0.5:
				a.set(x, y, OUTLINE)
			else:
				a.set(x, y, RIM_HI if (x + 0.5 - cx) + (y + 0.5 - cy) < 0 else RIM)


FRAME4 = [(OUTLINE, OUTLINE), (RIM_HI, RIM), (RIM, RIM_LO), (PANEL_HI, PANEL_LO)]


def side_plate(layers, prof):
	a = Art(24)
	a.img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
	a.px = a.img.load()
	m = [[rect_in(x, y, 0, 0, 24, 24, prof, prof, prof, prof) for x in range(24)] for y in range(24)]
	depth, side = v1.depth_map(m)
	for y in range(24):
		for x in range(24):
			if m[y][x]:
				d = depth[y][x]
				a.px[x, y] = v1.rgb(layers[d][0 if side[y][x] > 0 else 1] if d < len(layers) else PANEL)
	return a.tex()


# ------------------------------------------------------------------ A Bölmeli Konsol
def proto_a():
	L = R = 58
	w = L + 4 + R
	a = Art(w)
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM), (RIM, RIM_LO), (OUTLINE, OUTLINE)]
	plate(a, lambda x, y: rect_in(x, y, 0, 0, w, H, (2, 1), (2, 1), (2, 1), (2, 1)), layers, PANEL)
	struct = set()

	def rib_v(x, y0, y1):
		for y in range(y0 + 1, y1):
			for xx in (x - 1, x + 1):
				a.set(xx, y, OUTLINE)
				struct.add((xx, y))
		return [(x, y) for y in range(y0, y1 + 1)]

	def rib_h(y, x0, x1):
		for x in range(x0 + 1, x1):
			for yy in (y - 1, y + 1):
				a.set(x, yy, OUTLINE)
				struct.add((x, yy))
		return [(x, y) for x in range(x0, x1 + 1)]

	# portre bölmesi | yetenek rafı (üst) / çubuklar (alt) | kalp bölmesi; kiriş çekirdeği çerçeveye kaynar
	cores = rib_v(52, 3, 72) + rib_h(41, 52, w - 4) + rib_v(w - 53, 3, 41)
	for (x, y) in cores:
		a.set(x, y, RIM)
		struct.add((x, y))
	# gömme bölmeler: üst/sol iç kenar gölge, alt/sağ iç kenar ışık
	frame = lambda x, y: x < 4 or y < 4 or x >= w - 4 or y >= H - 4  # noqa: E731
	solid = lambda x, y: frame(x, y) or (x, y) in struct  # noqa: E731
	for y in range(4, H - 4):
		for x in range(4, w - 4):
			if solid(x, y):
				continue
			if solid(x, y - 1) or solid(x - 1, y):
				a.set(x, y, PANEL_LO)
			elif solid(x, y + 1) or solid(x + 1, y):
				a.set(x, y, PANEL_HI)
	side = side_plate(layers, (1,))
	return a, (L, R), side, False


# ------------------------------------------------------------------ B Kemerli Portre
def proto_b():
	L, R = 58, 12
	w = L + 4 + R
	rise = 12
	a = Art(w, (0, rise, 0, 0))

	def arch_top(x, rx=28.0, h=rise, cx=27.5):
		t = (x + 0.5 - cx) / rx
		return round(-h * math.sqrt(1 - t * t)) if abs(t) < 1 else 1.0  # yuvarlanır: tepede tek piksellik sivrilik olmasın

	oval = (7, 5, 3, 2, 2, 1, 1)  # bugünkü panelin oval ucu

	def inside(x, y):
		if y < 0:
			return 1 <= x <= 54 and y >= arch_top(x)
		return rect_in(x, y, 0, 0, w, H, (), oval, (2, 1), oval)

	plate(a, inside, FRAME4, PANEL)
	# oyma kemer: kemerin içinden giden V oluk (üst yay + portre sütununun sağ çizgisi), altı ışık
	tower = lambda x, y: 4 <= x <= 51 and arch_top(x, 24.0, 7.5) - 1 <= y <= 71  # noqa: E731
	for y in range(-rise, H):
		for x in range(4, 52):
			if not tower(x, y):
				continue
			if not tower(x, y - 1) or x == 51:
				a.set(x, y, OUTLINE)
				a.set(x + (1 if x == 51 else 0), y + (0 if x == 51 else 1), PANEL_HI)
	disc(a, 27.5, -3.5, 3.2, inner=1.2)
	side = side_plate(FRAME4[:3], (3, 2, 1, 1))
	return a, (L, R), side, False


# ------------------------------------------------------------------ C Tomar Uçlu
def proto_c():
	L = R = 12
	w = L + 4 + R
	ex = (0, 6, 0, 6)
	a = Art(w, ex)
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM_LO), (PANEL_HI, PANEL_LO)]
	plate(a, lambda x, y: rect_in(x, y, 3, 2, w - 3, H - 2, (1,), (1,), (1,), (1,)), layers, PANEL)
	for y in range(5, H - 5):  # merdanenin levhaya düşen gölgesi
		for x in (6, w - 7):
			a.set(x, y, PANEL_LO)
	cols = [OUTLINE, RIM_HI, RIM, RIM, RIM_LO, OUTLINE]
	knob = [(None, OUTLINE, OUTLINE, OUTLINE, OUTLINE, None),
		(OUTLINE, RIM_HI, RIM_HI, RIM, RIM_LO, OUTLINE),
		(OUTLINE, RIM_HI, RIM, RIM, RIM_LO, OUTLINE),
		(None, OUTLINE, OUTLINE, OUTLINE, OUTLINE, None)]
	neck = (None, OUTLINE, RIM, RIM_LO, OUTLINE, None)
	for x0 in (0, w - 6):
		for y in range(-1, H + 1):
			for c in range(6):
				col = cols[c]
				if y in (-1, H):
					col = None if c in (0, 5) else OUTLINE
				elif c == 3 and (y % 9) in (2, 3, 4):
					col = WOOD_MID  # merdane damarı
				if col:
					a.set(x0 + c, y, col)
		for (yy, row) in [(-2, neck), (H + 1, neck)] + [(-6 + i, r) for i, r in enumerate(knob)] + [(H + 2 + i, r) for i, r in enumerate(knob)]:
			for c, col in enumerate(row):
				if col:
					a.set(x0 + c, yy, col)
	side = side_plate(layers, (1,))
	return a, (L, R), side, False


# ------------------------------------------------------------------ D Kütük Kiriş
P = 24  # kütük damarı periyodu (karo)


def proto_d():
	L = R = 20
	w = L + P + R
	ex = (8, 6, 8, 4)
	a = Art(w, ex)
	plate(a, lambda x, y: rect_in(x, y, 0, 1, w, H - 1, (1,), (1,), (1,), (1,)), FRAME4, PANEL)

	def log(ya, n):
		xa, xb = -ex[0], w + ex[2] - 1
		shade = [OUTLINE, RIM_HI, RIM_HI] + [RIM] * (n - 6) + [RIM_LO, RIM_LO, OUTLINE]
		half = (n - 1) / 2
		grain = [(2, 9), (13, 6), (19, 4)]  # (başlangıç, uzunluk) periyot içinde
		for r in range(n):
			dy = abs(r - half) / (half + 0.5)
			cut = int(round(3 * (1 - math.sqrt(max(0.0, 1 - dy * dy)))))
			for x in range(xa + cut, xb - cut + 1):
				edge = x in (xa + cut, xb - cut)
				col = OUTLINE if edge else shade[r]
				if not edge and r == n // 2:
					ph = (x - L) % P
					if any(s <= ph < s + ln for s, ln in grain):
						col = RIM_LO
				a.set(x, ya + r, col)
			# kesik uç (3/4 bakış): açık yüz + halka + öz
			for end, sgn in ((xa + cut, 1), (xb - cut, -1)):
				if 2 <= r <= n - 3:
					a.set(end + sgn, ya + r, RIM_HI)
					a.set(end + 2 * sgn, ya + r, WOOD_MID if r == n // 2 else RIM_HI)
					a.set(end + 3 * sgn, ya + r, RIM_LO)
		# ağaç çivileri panelin yan direklerinin üstünde
		for px in (1, w - 4):
			cy = ya + n // 2 - 1
			for (dx, dy, col) in ((0, 0, OUTLINE), (1, 0, OUTLINE), (2, 0, OUTLINE), (0, 1, OUTLINE), (1, 1, RIM_HI), (2, 1, OUTLINE),
					(0, 2, OUTLINE), (1, 2, OUTLINE), (2, 2, OUTLINE)):
				a.set(px + dx, cy + dy, col)

	log(-6, 10)
	log(H - 5, 9)
	side = side_plate(FRAME4[:3], (1,))
	return a, (L, R), side, True


PROTOS = {
	"A": ("Bölmeli Konsol", proto_a),
	"B": ("Kemerli Portre", proto_b),
	"C": ("Tomar Uçlu", proto_c),
	"D": ("Kütük Kiriş", proto_d),
}


def main():
	os.makedirs(OUT, exist_ok=True)
	pal = {}
	for key, (name, fn) in PROTOS.items():
		art, (L, R), side, tile = fn()
		exl, ext, exr, exb = art.ex
		d = os.path.join(OUT, "tex_" + key)
		os.makedirs(d, exist_ok=True)
		dock = art.tex()
		dock.save(os.path.join(d, "dock.png"))
		side.save(os.path.join(d, "side.png"))
		pal[key] = {
			"name": name,
			"dock_margins": [(exl + L) * U, ext * U + 76, (exr + R) * U, exb * U + 75],
			"dock_expand": [exl * U, ext * U, exr * U, exb * U],
			"dock_tile": tile,
			"side_margins": [16, 16, 16, 16],
		}
		print(key, name, "dock", dock.size, pal[key]["dock_margins"], pal[key]["dock_expand"])
	with open(os.path.join(OUT, "palettes.json"), "w", encoding="utf-8") as f:
		json.dump(pal, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
