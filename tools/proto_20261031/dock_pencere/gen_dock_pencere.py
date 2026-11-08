# YETENEK PANELİ ARKA PENCERESİ prototipleri (2026-10-31, madde 391; oyuna bağlı DEĞİL).
# Yetenek yuvaları / çubuklar / portre / kalpler AYNI; sadece arkadaki pencere (DockFrame = panel_ability_bar.png) + ona yapışık
# iki yan panelin (efsanevi yuvalar + mini stat, bugün panel_status_badge.png) dokusu. Palet HUD teması "Kısık Ahşap" (hud_theme.gd)
# ile aynı aile -> ENVANTER / altın levhaları, grup paneli, görev satırı, bildirim levhası, minimap halkası ile uyumlu.
#   A Levha        : grup paneli / bildirim levhasının (hud_plaque_clean) BİREBİR dili, köşe çentikli düz dikdörtgen.
#   B Oval Tahta   : bugünkü oval silüet + iki tahta (yetenek sırası ile can çubuğu arasında derz) + ahşap damarı.
#   C Gömme Tepsi  : ince ahşap kenar, içi koyu çukur tepsi (ipucu/kuyu dili); yuvalar ve çubuklar öne çıkar, kuyular bir ton koyu.
#   D Pirinç Köşe  : A'nın levhası + köşelerde seviye rozetinin pirincinden L köşebent ve perçin.
# Çıktı: out/tex_<X>/dock.png + side.png, out/palettes.json (dock_capture.gd okur). Dock dokusu TAM YÜKSEKLİKTE (152 = hud.gd DOCK_H):
# üst 76 / alt 75 satır pay -> dikeyde hiç esnemez; yatayda orta sütun tekdüze (B'de 48 sanat pikseli periyotla karo).
# Kullanım: python tools/proto_20261031/dock_pencere/gen_dock_pencere.py
import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

# HUD teması "Kısık Ahşap" (scripts/hud_theme.gd + mevcut HUD dokularından ölçüldü)
OUTLINE = "#20150d"
RIM = "#6a4a30"
RIM_HI = "#86623f"
RIM_LO = "#4b3320"
WOOD_MID = "#785638"
PANEL = "#5a4734"
PANEL_HI = "#665240"
PANEL_LO = "#4f3d2c"
GRAIN = "#4a3827"  # B tahta damarı (PANEL'den bir ton koyu, kuyudan açık)
INSET = "#271a11"
# seviye rozetinin pirinci (assets/ui/kit/hud_level_badge.png)
BRASS_HI = "#cba15e"
BRASS = "#a98140"
BRASS_LO = "#71532a"

DOCK_H = 152  # hud.gd DOCK_H (tasarım pikseli)


def rgb(h):
	h = h.lstrip("#")
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def rounded_mask(w, h, prof):
	"""prof[i] = köşede i. satırda kesilen piksel sayısı (dört köşe simetrik)."""
	m = [[True] * w for _ in range(h)]
	for i, cut in enumerate(prof):
		for x in range(cut):
			for (yy, xx) in ((i, x), (i, w - 1 - x), (h - 1 - i, x), (h - 1 - i, w - 1 - x)):
				m[yy][xx] = False
	return m


def depth_map(m):
	"""4-komşulu aşındırma derinliği: 0 = en dış halka. Her halka pikselinin hangi yöne baktığı (ışık/gölge) da döner."""
	h = len(m)
	w = len(m[0])
	depth = [[-1] * w for _ in range(h)]
	side = [[0] * w for _ in range(h)]  # +1 ışık (üst/sol), -1 gölge (alt/sağ)
	cur = [row[:] for row in m]
	d = 0
	while any(any(r) for r in cur):
		nxt = [[False] * w for _ in range(h)]
		for y in range(h):
			for x in range(w):
				if not cur[y][x]:
					continue
				up = y > 0 and cur[y - 1][x]
				dn = y < h - 1 and cur[y + 1][x]
				lf = x > 0 and cur[y][x - 1]
				rt = x < w - 1 and cur[y][x + 1]
				if up and dn and lf and rt:
					nxt[y][x] = True
				else:
					depth[y][x] = d
					if not up:
						side[y][x] = 1
					elif not dn:
						side[y][x] = -1
					elif not lf:
						side[y][x] = 1
					else:
						side[y][x] = -1
		cur = nxt
		d += 1
		if d > 60:
			break
	for y in range(h):
		for x in range(w):
			if m[y][x] and depth[y][x] < 0:
				depth[y][x] = 99
	return depth, side


def paint_layers(w, h, prof, layers, fill):
	"""layers[d] = (ışık rengi, gölge rengi); derinlik >= len(layers) -> fill."""
	m = rounded_mask(w, h, prof)
	depth, side = depth_map(m)
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	px = img.load()
	for y in range(h):
		for x in range(w):
			if not m[y][x]:
				continue
			d = depth[y][x]
			if d < len(layers):
				lt, dk = layers[d]
				px[x, y] = rgb(lt if side[y][x] > 0 else dk)
			else:
				px[x, y] = rgb(fill)
	return img, depth


def upscale(img, u):
	return img.resize((img.width * u, img.height * u), Image.NEAREST)


def fit_tex(big, tw, th):
	"""Ortadan (tekdüze bölgeden) satır/sütun atarak hedef boyuta indirir: üst/sol yarı üstten/soldan, alt/sağ yarı alttan/sağdan."""
	w, h = big.size
	out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
	top = th // 2
	left = tw // 2
	out.paste(big.crop((0, 0, left, top)), (0, 0))
	out.paste(big.crop((w - (tw - left), 0, w, top)), (left, 0))
	out.paste(big.crop((0, h - (th - top), left, h)), (0, top))
	out.paste(big.crop((w - (tw - left), h - (th - top), w, h)), (left, top))
	return out


def put(img, x, y, col):
	if 0 <= x < img.width and 0 <= y < img.height:
		img.putpixel((x, y), rgb(col))


# ------------------------------------------------------------------ A Levha
def proto_a(u=3, wa=40, side_art=16):
	ha = (DOCK_H + u - 1) // u + 2
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM_LO), (PANEL_HI, PANEL_LO)]
	img, depth = paint_layers(wa, ha, [1], layers, PANEL)
	_corner_studs(img, 2)
	dock = fit_tex(upscale(img, u), 80, DOCK_H)
	s, _ = paint_layers(side_art, side_art, [1], layers, PANEL)
	_corner_studs(s, 2)
	return dock, upscale(s, u)


def _corner_studs(img, d):
	"""hud_plaque'taki iç köşe ışıkları: iç halkanın dört köşesine bir ton açık piksel."""
	w, h = img.size
	for (x, y) in ((d, d), (w - 1 - d, d), (d, h - 1 - d), (w - 1 - d, h - 1 - d)):
		put(img, x, y, RIM_HI)


# ------------------------------------------------------------------ B Oval Tahta
PERIOD = 48  # sanat pikseli; damar deseni bu periyotla karo


def proto_b(u=2):
	ha = DOCK_H // u  # 76 sanat satırı = tam doku
	corner = 24
	wa = corner * 2 + PERIOD
	prof = [7, 5, 3, 2, 2, 1, 1]  # bugünkü panel_ability_bar oval ucu (2x sanatta ölçüldü)
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM), (RIM, RIM_LO), (OUTLINE, OUTLINE)]
	img, depth = paint_layers(wa, ha, prof, layers, PANEL)
	px = img.load()
	# kenar damarı: ahşap kenarın orta tonuna seyrek uzun çizgiler (yatay kenarlarda)
	for y in range(ha):
		for x in range(wa):
			if depth[y][x] == 2 and y < ha // 2 and ((x - corner) % PERIOD in range(5, 13) or (x - corner) % PERIOD in range(29, 35)):
				px[x, y] = rgb(WOOD_MID)
	# iki tahta: derz yetenek sırası (dock y 14..78) ile can çubuğu (86) arasında -> dock y 82 = sanat satırı 41
	seam = 82 // u
	inner = [(x, y) for y in range(ha) for x in range(wa) if depth[y][x] >= len(layers)]
	for (x, y) in inner:
		if y == seam:
			px[x, y] = rgb(OUTLINE)
		elif y == seam + 1:
			px[x, y] = rgb(PANEL_HI)
		elif y == seam - 1:
			px[x, y] = rgb(PANEL_LO)
	# damar: tahta başına periyodik, düşük kontrast kısa yatay çizgiler (karo sınırında kesintisiz)
	grain = [(6, 9, 11), (19, 30, 7), (33, 16, 9), (41, 49, 5), (12, 58, 8), (27, 63, 10), (2, 22, 6), (38, 36, 7), (22, 71, 6)]
	for (gx, gy, ln) in grain:
		for k in range(ln):
			for rep in range(-1, wa // PERIOD + 2):
				x = corner + rep * PERIOD + (gx + k) % PERIOD
				y = gy
				if 0 <= x < wa and 0 <= y < ha and depth[y][x] >= len(layers) and abs(y - seam) > 1:
					px[x, y] = rgb(GRAIN)
	dock = upscale(img, u)
	# yan paneller: aynı kenar, düz iç (9 dilimde esner)
	s, _ = paint_layers(24, 24, [3, 2, 1, 1], layers, PANEL)
	return dock, upscale(s, u)


# ------------------------------------------------------------------ C Gömme Tepsi
TRAY = "#35261a"
TRAY_SHADOW = "#2a1d13"
TRAY_LIP = "#433020"
C_INSET = "#1c120b"


def proto_c(u=3, wa=40, side_art=16):
	ha = (DOCK_H + u - 1) // u + 2
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM), (RIM, RIM_LO), (OUTLINE, OUTLINE)]

	def tray(w, h):
		img, depth = paint_layers(w, h, [2, 1], layers, TRAY)
		px = img.load()
		top = min(y for y in range(h) for x in range(w) if depth[y][x] >= len(layers))
		bot = max(y for y in range(h) for x in range(w) if depth[y][x] >= len(layers))
		for x in range(w):
			for (yy, col) in ((top, TRAY_SHADOW), (top + 1, TRAY_SHADOW), (bot, TRAY_LIP)):
				if depth[yy][x] >= len(layers):
					px[x, yy] = rgb(col)
		for y in range(h):
			for x in range(w):
				if depth[y][x] >= len(layers) and (x > 0 and depth[y][x - 1] == len(layers) - 1):
					px[x, y] = rgb(TRAY_SHADOW)
		return img

	dock = fit_tex(upscale(tray(wa, ha), u), 80, DOCK_H)
	return dock, upscale(tray(side_art, side_art), u)


# ------------------------------------------------------------------ D Pirinç Köşe
def proto_d(u=3, wa=40, side_art=16):
	ha = (DOCK_H + u - 1) // u + 2
	layers = [(OUTLINE, OUTLINE), (RIM_HI, RIM_LO), (RIM, RIM_LO), (PANEL_HI, PANEL_LO)]

	def board(w, h, arm):
		img, _ = paint_layers(w, h, [1], layers, PANEL)
		_brackets(img, arm)
		return img

	dock = fit_tex(upscale(board(wa, ha, 7), u), 80, DOCK_H)
	return dock, upscale(board(side_art, side_art, 5), u)


def _brackets(img, arm):
	"""Dört köşeye pirinç L köşebent (2 piksel kalın, dış hatlı) + köşede perçin."""
	w, h = img.size
	for (sx, sy) in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
		ox = 1 if sx > 0 else w - 2
		oy = 1 if sy > 0 else h - 2
		cells = set()
		for i in range(arm):
			for t in range(2):
				cells.add((ox + sx * i, oy + sy * t))
				cells.add((ox + sx * t, oy + sy * i))
		# dış hat: hücrelerin 8-komşusu (panel içinde kalanlar)
		ring = set()
		for (x, y) in cells:
			for dx in (-1, 0, 1):
				for dy in (-1, 0, 1):
					q = (x + dx, y + dy)
					if q not in cells and 0 < q[0] < w - 1 and 0 < q[1] < h - 1:
						ring.add(q)
		for q in ring:
			put(img, q[0], q[1], OUTLINE)
		for (x, y) in cells:
			# ışık sol üstten: panel kenarına bakan dış satır/sütun üstte/solda açık, altta/sağda koyu
			hi = (y == oy and sy > 0) or (x == ox and sx > 0)
			lo = (y == oy and sy < 0) or (x == ox and sx < 0)
			put(img, x, y, BRASS_HI if hi else (BRASS_LO if lo else BRASS))
		# perçinler: kolların uçlarına yakın iç satırda koyu nokta
		put(img, ox + sx * (arm - 2), oy + sy, BRASS_LO)
		put(img, ox + sx, oy + sy * (arm - 2), BRASS_LO)


PROTOS = {
	"A": ("Levha", proto_a, {"dock_margins": [36, 76, 36, 75], "side_margins": [18, 18, 18, 18]}),
	"B": ("Oval Tahta", proto_b, {"dock_margins": [48, 76, 48, 75], "dock_tile": True, "side_margins": [16, 16, 16, 16]}),
	"C": ("Gömme Tepsi", proto_c, {"dock_margins": [36, 76, 36, 75], "side_margins": [18, 18, 18, 18],
		"inset": C_INSET, "rim_lo": RIM_LO}),
	"D": ("Pirinç Köşe", proto_d, {"dock_margins": [36, 76, 36, 75], "side_margins": [18, 18, 18, 18]}),
}


def main():
	os.makedirs(OUT, exist_ok=True)
	pal = {}
	for key, (name, fn, spec) in PROTOS.items():
		dock, side = fn()
		d = os.path.join(OUT, "tex_" + key)
		os.makedirs(d, exist_ok=True)
		dock.save(os.path.join(d, "dock.png"))
		side.save(os.path.join(d, "side.png"))
		e = dict(spec)
		e["name"] = name
		pal[key] = e
		print(key, name, "dock", dock.size, "side", side.size)
	with open(os.path.join(OUT, "palettes.json"), "w", encoding="utf-8") as f:
		json.dump(pal, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
