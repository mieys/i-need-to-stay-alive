"""Shaman totemleri v6 PROTOTIPLERI - SERBEST + OYUN SANATIYLA UYUMLU (madde 176 devami). OYUNA BAGLI DEGIL.

Kullanici (2026-10-16, doga temali v5'ten sonra): "daha fazla prototip oner hicbirseyden esinlenmeden hicbir temaya bagli kalmadan
tek istegim oyunla uyumlu gorunmesi pixel sanati olarak".

Oyunun harita sanatindan (harita/Objects.png, "sade agac ve tas.png") olculen kurallar - onceki turlarin hepsi bunlara uymuyordu:
  * Kontur SIYAH DEGIL: malzemenin en koyu tonu x ~0.42 (kaya (64,51,48), kutuk (48,21,18), yaprak (25,57,38)) -> `_selout`.
  * Golgeleme: sol ustten isik, 4-5 tonlu SADE duzlemler (gurultu yok); tepe-sol kenarda tek piksel parlak cizgi; catlak = orta-koyu
    cizgi + yaninda acik ton.
  * Objeler toprak tumsegine degil CIMEN TUTAMLARINA oturur (koyu yesil dip, acik yesil uclar, objenin onune taser).
  * Renkler haritadan: sicak bej kaya, kizil kahve kutuk/kabuk, kum heykel tonu, yosunlu kahve kaya, harita yesilleri.
  * Isik (glow) sadece element parcasinda; govde mat.
Efekt A ile uyum: ates (Q) / isik kalkani (E) totemin tepesinde. Kare 40x56, ayak y=52, 8 kare 10 fps, Shaman pikseli.
Yonler: A Kaya Sunak, B Kutuk Fener, C Harabe Sutun, D Kum Heykel, E Ayakli Mangal, F Yosunlu Tas Kule.
Ciktilar: tools/proto_20261016/totem4/ (.gdignore). Calistir: python tools/proto_20261016/shaman_totem_proto4.py
"""
import importlib.util
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "totem4")
_spec = importlib.util.spec_from_file_location("p2", os.path.join(HERE, "shaman_totem_proto2.py"))
p2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(p2)

W, H, CX, GY, FRAMES, FPS = p2.W, p2.H, p2.CX, p2.GY, p2.FRAMES, p2.FPS
M, rgba, wave = p2.M, p2.rgba, p2.wave
FIRE, SPIRIT, ELEM = p2.FIRE, p2.SPIRIT, p2.ELEM
TAU = math.tau

# ------------------------------------------------------------------ oyun paletleri (harita sanatindan olculdu)
ROCK = (rgba(102, 86, 83), rgba(145, 125, 114), rgba(193, 171, 147), rgba(226, 213, 185), rgba(246, 235, 201))
STUMP_TOP = (rgba(109, 66, 58), rgba(148, 110, 94), rgba(167, 130, 107), rgba(195, 160, 126), rgba(214, 184, 148))
BARK = (rgba(75, 40, 35), rgba(109, 66, 58), rgba(151, 89, 62), rgba(169, 118, 71), rgba(190, 142, 92))
SAND = (rgba(110, 77, 61), rgba(141, 107, 78), rgba(169, 136, 96), rgba(191, 160, 107), rgba(215, 190, 117))
MOSSROCK = (rgba(70, 51, 42), rgba(110, 91, 75), rgba(139, 116, 88), rgba(164, 140, 102), rgba(194, 173, 116))
MOSSY = (rgba(70, 63, 39), rgba(113, 114, 83), rgba(120, 122, 82), rgba(137, 147, 89), rgba(160, 170, 104))
GREEN = (rgba(25, 57, 38), rgba(53, 113, 55), rgba(77, 132, 59), rgba(104, 150, 61), rgba(135, 171, 62), rgba(151, 186, 58))
IRON = (rgba(44, 40, 46), rgba(70, 64, 72), rgba(100, 92, 98), rgba(134, 124, 126), rgba(168, 158, 154))
BRONZE = (rgba(84, 50, 32), rgba(128, 82, 46), rgba(170, 118, 62), rgba(206, 160, 90), rgba(232, 204, 136))


# ------------------------------------------------------------------ tuval: harita tarzi kontur + cimen katmani
class Cv(p2.Cv):
    LAYERS = ("back", "body", "emis", "grass", "front")

    def render(self):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hm = {}
        for (x, y, c, k) in self.halo:
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    d = math.hypot(dx, dy)
                    if d == 0 or d > 3.2:
                        continue
                    a = (110 if d < 1.5 else (52 if d < 2.5 else 20)) * k
                    key = (x + dx, y + dy)
                    if key not in hm or hm[key][3] < a:
                        hm[key] = (c[0], c[1], c[2], int(min(200, a)))
        for (x, y), c in hm.items():
            if 0 <= x < W and 0 <= y < H:
                out.putpixel((x, y), c)
        out.alpha_composite(self.L["back"])
        out.alpha_composite(_selout(self.L["body"]))
        out.alpha_composite(self.L["emis"])
        out.alpha_composite(self.L["grass"])
        out.alpha_composite(self.L["front"])
        return out


def _selout(layer):
    """Secici kontur: bos pikselin en koyu govde komsusu x0.42 (oyunun harita objeleri gibi malzeme renginde kontur)."""
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > 0:
                continue
            best = None
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 0:
                    c = px[nx, ny]
                    if best is None or sum(c[:3]) < sum(best[:3]):
                        best = c
            if best is not None:
                op[x, y] = (int(best[0] * 0.42), int(best[1] * 0.40), int(best[2] * 0.40), 255)
    return out


def vol(cv, rows, pal, layer="body", rim=True, light=(0.32, 0.28)):
    """Hacim golgesi: sol ustten isik, 4 ton duz bant + tepe-sol kenarda parlak tek piksel cizgi (harita kayalari gibi)."""
    ys = sorted(rows)
    x0 = min(r[0] for r in rows.values())
    x1 = max(r[1] for r in rows.values())
    y0, y1 = ys[0], ys[-1]
    cxm, cym = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = max(1.0, (x1 - x0) / 2), max(1.0, (y1 - y0) / 2)
    for y, (xl, xr) in rows.items():
        for x in range(xl, xr + 1):
            nx, ny = (x - cxm) / hx, (y - cym) / hy
            lum = 0.55 - light[0] * nx - light[1] * ny
            c = pal[3] if lum > 0.66 else (pal[2] if lum > 0.36 else pal[1])
            if rim and lum > 0.45:
                top_edge = (y - 1 not in rows) or not (rows[y - 1][0] <= x <= rows[y - 1][1])
                left_edge = x == xl
                if top_edge or (left_edge and lum > 0.6):
                    c = pal[4]
            cv.px(x, y, c, layer)


def crack(cv, pts, pal):
    """Catlak: orta-koyu cizgi + solunda acik ton (kayalardaki gibi)."""
    for i in range(len(pts) - 1):
        (xa, ya), (xb, yb) = pts[i], pts[i + 1]
        n = int(max(abs(xb - xa), abs(yb - ya))) + 1
        for k in range(n + 1):
            x = round(xa + (xb - xa) * k / n)
            y = round(ya + (yb - ya) * k / n)
            if cv.get_body(x, y):
                cv.px(x, y, pal[1])
                if cv.get_body(x - 1, y):
                    cv.px(x - 1, y, pal[3])


def _get_body(self, x, y):
    return 0 <= x < W and 0 <= y < H and self.L["body"].getpixel((int(x), int(y)))[3] > 0


Cv.get_body = _get_body


def _h(x, s=0):
    return ((x * 73856093) ^ (s * 19349663)) & 0xFFFF


def grass(cv, x0, x1, t=0.0, seed=1, front=True):
    """Objenin dibindeki cimen yatagi + tutamlar: arkada koyu yesil zemin lekesi, onde uclari acik yesil bicaklar (hafif salinir)."""
    cx, hw = (x0 + x1) / 2, (x1 - x0) / 2 + 3
    for y, k in ((GY - 1, 0.8), (GY, 1.0), (GY + 1, 0.85), (GY + 2, 0.55)):
        for x in range(int(cx - hw * k), int(cx + hw * k) + 1):
            cv.px(x, y, GREEN[1] if (x + y) % 3 else GREEN[0], "back")
    sw = 1 if wave(t) > 0.45 else 0
    for x in range(int(cx - hw), int(cx + hw) + 1):
        h = _h(x, seed) % 5
        inside = x0 + 1 <= x <= x1 - 1
        if h < 2 or (inside and h < 3):
            continue
        hh = min(4, h)
        base = GY + 1 if not inside else GY + 1
        for j in range(hh):
            y = base - j
            xx = x + (sw if j == hh - 1 and _h(x, seed + 3) % 2 else 0)
            c = GREEN[1] if j == 0 else (GREEN[2] if j < hh - 1 else GREEN[4 if _h(x, seed + 7) % 2 else 3])
            cv.px(xx, y, c, "grass" if front else "back")


def stroke(cv, pts, widths, pal, layer="body"):
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
        for k in range(n + 1):
            s = k / n
            x, y, r = x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, (w0 + (w1 - w0) * s) / 2
            R = int(math.ceil(r))
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    if math.hypot(dx, dy) <= max(0.5, r):
                        u = (dx + r) / (2 * r) if r > 0.6 else 0.5
                        cv.px(x + dx, y + dy, pal[3] if u < 0.3 else (pal[2] if u < 0.7 else pal[1]), layer)


def leafy(cv, x, y, n, seed, pal=GREEN):
    """Kucuk sarmasik yaprak kumesi (harita bitkileri gibi 2-3 px yaprak)."""
    for i in range(n):
        dx = (_h(i, seed) % 5) - 2
        dy = (_h(i, seed + 1) % 3) - 1
        cv.px(x + dx, y + dy, pal[3])
        cv.px(x + dx + 1, y + dy, pal[2])
        cv.px(x + dx, y + dy + 1, pal[1])


def bob(t):
    return 1 if wave(t) > 0.5 else (-1 if wave(t) < -0.5 else 0)


def element(cv, kind, f, t, cy, shield_top=None, orb_r=3.2, flame_h=8):
    """Tepedeki element: Q kor + alev + kivilcim, E isik kalkani (Algiz + parilti) + pariltilar."""
    if kind == "q":
        p2.orb(cv, CX, cy, orb_r, t, FIRE)
        p2.flame(cv, CX, cy - 2, flame_h, 6, t, FIRE)
        p2.particles(cv, t, FIRE, [(CX - 4, cy, 0.0, 1.0), (CX + 4, cy, 0.5, 1.0), (CX, cy - 6, 0.25, 1.4)], 10)
    else:
        p2.light_shield(cv, cy - 7 if shield_top is None else shield_top, f, SPIRIT)
        p2.twinkles(cv, f, SPIRIT, [(CX, cy - 12, 0), (CX - 12, cy - 4, 3), (CX + 12, cy - 6, 5)])


# ------------------------------------------------------------------ A) KAYA SUNAK
ROCK_A = {30: (15, 23), 31: (13, 25), 32: (12, 26), 33: (11, 27), 34: (10, 28), 35: (10, 28), 36: (10, 28)}
ROCK_A.update({y: (9, 29) for y in range(37, 50)})
ROCK_A.update({50: (9, 29), 51: (10, 28)})


def totem_a(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 9, 29, t, 1)
    vol(cv, ROCK_A, ROCK)
    # tepede oyulmus kase (koyu ic + acik kenar)
    cv.hl(15, 23, 31, ROCK[0])
    cv.hl(16, 22, 32, ROCK[1])
    cv.hl(14, 24, 30, ROCK[4])
    for pts in (((13, 36), (16, 40), (15, 45)), ((25, 34), (23, 38), (25, 43)), ((20, 46), (22, 49)), ((11, 42), (12, 46))):
        crack(cv, pts, ROCK)
    # yuzde oyma run (element renginde, nabiz)
    hi = (FIRE if kind == "q" else SPIRIT)[4 if wave(t) > 0 else 3]
    p2.glyph(cv, 17, 38, p2.RUNE5_FIRE if kind == "q" else p2.RUNE5_WARD, hi, "emis", 0.5)
    # yosun / sarmasik dokunusu
    leafy(cv, 11, 37, 4, 3)
    leafy(cv, 27, 47, 3, 5)
    element(cv, kind, f, t, 25 + bob(t), shield_top=12 + bob(t), orb_r=3.4, flame_h=9)
    return cv.render()


# ------------------------------------------------------------------ B) KUTUK FENER
STUMP_TOP_R = {35: (14, 24), 36: (12, 26), 37: (11, 27), 38: (11, 27), 39: (12, 26)}


def totem_b(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 9, 29, t, 2)
    # kokler
    for pts, ws in (([(12, 46), (9, 49), (6, 52)], [3.0, 2.2, 1.2]), ([(14, 48), (12, 51), (10, 52)], [2.2, 1.6, 1.0])):
        stroke(cv, pts, ws, BARK)
        stroke(cv, [(M(x), y) for x, y in pts], ws, BARK)
    # kabuk govde: dikey cizgiler
    for y in range(39, 51):
        for x in range(11, 28):
            u = (x - 11) / 16
            c = BARK[3] if u < 0.2 else (BARK[2] if u < 0.65 else BARK[1])
            if x in (14, 18, 23) and (y + x) % 5 != 0:
                c = BARK[1] if u < 0.65 else BARK[0]
            if x in (12, 16) and y % 4 == 1:
                c = BARK[4]
            cv.px(x, y, c)
    # kesik tepe: halkalar
    for y, (xl, xr) in STUMP_TOP_R.items():
        for x in range(xl, xr + 1):
            d = math.hypot((x - 19) / 1.0, (y - 37) * 2.2)
            c = STUMP_TOP[3] if int(d) % 3 else STUMP_TOP[2]
            if d < 1.2:
                c = STUMP_TOP[1]
            if y == 39:
                c = STUMP_TOP[1] if x > 19 else STUMP_TOP[2]
            cv.px(x, y, c)
    cv.hl(13, 18, 35, STUMP_TOP[4])
    # kutukten cikan egri dal + kanca
    stroke(cv, [(24, 37), (25, 31), (25, 24), (24, 19), (22, 17), (20, 17)], [2.6, 2.4, 2.2, 2.0, 1.6, 1.2], BARK)
    # fener (sallanir): zincir + catili demir kafes + cam
    sw = round(wave(t) * 1.0)
    fx_ = CX + sw
    cv.px(CX, 18, IRON[2])
    cv.px(CX + (sw > 0), 19, IRON[1])
    for y, (a, b) in ((20, (-1, 1)), (21, (-3, 3)), (22, (-4, 4))):
        for x in range(a, b + 1):
            cv.px(fx_ + x, y, IRON[3] if x < 0 else IRON[2])
    glow_pal = FIRE if kind == "q" else SPIRIT
    for y in range(23, 31):
        for x in range(-4, 5):
            if abs(x) == 4 or x == 0:
                cv.px(fx_ + x, y, IRON[2] if x < 0 else IRON[1])
    for (y, xl, xr) in ((31, -4, 4), (32, -3, 3)):
        for x in range(xl, xr + 1):
            cv.px(fx_ + x, y, IRON[2] if x < 0 else IRON[1])
    # cam icindeki isik: Q alev, E kucuk kalkan
    for y in range(23, 31):
        for x in (-3, -2, -1, 1, 2, 3):
            cv.glow(fx_ + x, y, glow_pal[2] if abs(x) == 3 else glow_pal[3], 0.0, "emis")
    if kind == "q":
        p2.flame(cv, fx_, 30, 7, 5, t, FIRE, 0.4, "emis")
        p2.particles(cv, t, FIRE, [(fx_ - 2, 20, 0.0, 0.8), (fx_ + 2, 20, 0.5, 0.8)], 7)
    else:
        rows = (2, 3, 3, 3, 2, 1, 0)
        for j, hw in enumerate(rows):
            for x in range(-hw, hw + 1):
                cv.glow(fx_ + x, 24 + j, SPIRIT[5] if (abs(x) == hw or j == 0) else SPIRIT[4], 0.0, "emis")
        p2.twinkles(cv, f, SPIRIT, [(fx_ - 7, 22, 0), (fx_ + 7, 26, 4)])
    for x in range(-4, 5):  # isik halesi (camdan tasan)
        for y in (23, 30):
            cv.halo.append((fx_ + x, y, glow_pal[3], 0.5))
    leafy(cv, 12, 40, 3, 7)
    return cv.render()


# ------------------------------------------------------------------ C) HARABE SUTUN
def totem_c(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 8, 30, t, 3)
    vol(cv, {48: (11, 27), 49: (11, 27)}, ROCK)
    vol(cv, {50: (10, 28), 51: (10, 28), 52: (10, 28)}, ROCK)
    # govde + oluklar; kirik tepe
    top = [31, 30, 29, 29, 28, 29, 30, 30, 31, 32, 31]
    rows = {}
    for y in range(28, 48):
        xs = [14 + i for i in range(11) if y >= top[i]]
        if xs:
            rows[y] = (xs[0], xs[-1])
    for y, (xl, xr) in rows.items():
        for x in range(xl, xr + 1):
            if y < top[x - 14]:
                continue
            u = (x - 14) / 10
            c = ROCK[3] if u < 0.3 else (ROCK[2] if u < 0.72 else ROCK[1])
            if x in (16, 19, 22):
                c = ROCK[2] if u < 0.5 else ROCK[1]
            if x in (15, 18) and u < 0.5:
                c = ROCK[4]
            if y == top[x - 14]:
                c = ROCK[4] if u < 0.6 else ROCK[3]
            cv.px(x, y, c)
    crack(cv, ((21, 33), (20, 37), (22, 40)), ROCK)
    # sarmasik sargisi
    for y in range(33, 48):
        x = 19 + round(4.6 * math.sin(y * 0.42))
        if math.cos(y * 0.42) > -0.3:
            cv.px(x, y, GREEN[2])
            if y % 3 == 0:
                leafy(cv, x, y, 2, y)
    leafy(cv, 14, 46, 4, 11)
    leafy(cv, 24, 45, 3, 13)
    # dusmus parca
    vol(cv, {47: (4, 7), 48: (3, 8), 49: (3, 8), 50: (3, 8)}, ROCK)
    element(cv, kind, f, t, 21 + bob(t), shield_top=13 + bob(t), orb_r=3.4, flame_h=8)
    return cv.render()


# ------------------------------------------------------------------ D) KUM HEYKEL (kukuletali figur, elementi basinin ustunde tutar)
def totem_d(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 10, 28, t, 4)
    vol(cv, {48: (12, 26), 49: (12, 26), 50: (11, 27), 51: (11, 27), 52: (11, 27)}, SAND)
    # cuppe: asagi dogru genisler
    robe = {y: (CX - (5 + (y - 31) // 4), CX + (5 + (y - 31) // 4)) for y in range(31, 48)}
    vol(cv, robe, SAND)
    for (x, y0, y1) in ((16, 36, 47), (22, 38, 47), (19, 41, 47)):
        for y in range(y0, y1 + 1):
            cv.px(x, y, SAND[1])
    # kollar: omuzdan yukari, eller tepede
    stroke(cv, [(14, 32), (13, 27), (14, 22), (16, 19)], [3.0, 2.6, 2.4, 2.0], SAND)
    stroke(cv, [(24, 32), (25, 27), (24, 22), (22, 19)], [3.0, 2.6, 2.4, 2.0], SAND)
    # kukuleta + golgeli yuz + element gozler
    hood = {23: (17, 21), 24: (16, 22), 25: (15, 23), 26: (15, 23), 27: (15, 23), 28: (15, 23), 29: (15, 23), 30: (16, 22), 31: (16, 22)}
    vol(cv, hood, SAND)
    for (y, xl, xr) in ((26, 17, 21), (27, 16, 22), (28, 16, 22), (29, 17, 21)):
        cv.hl(xl, xr, y, SAND[0])
    eye = (FIRE if kind == "q" else SPIRIT)[5 if wave(t, 0.2) > 0 else 4]
    cv.glow(17, 27, eye, 0.5, "emis")
    cv.glow(21, 27, eye, 0.5, "emis")
    # bel kusagi
    cv.hl(14, 24, 35, SAND[0])
    cv.hl(14, 24, 36, BRONZE[2])
    cv.glow(19, 36, (FIRE if kind == "q" else SPIRIT)[3], 0.4, "emis")
    element(cv, kind, f, t, 16 + bob(t), shield_top=8 + bob(t), orb_r=3.2, flame_h=8)
    return cv.render()


# ------------------------------------------------------------------ E) AYAKLI MANGAL
BOWL = {31: (11, 27), 32: (11, 27), 33: (12, 26), 34: (13, 25), 35: (14, 24), 36: (16, 22)}


def totem_e(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 8, 30, t, 5)
    # demir ayaklar (orta ayak arkada)
    stroke(cv, [(19, 36), (19, 50)], [1.6, 1.6], IRON, "body")
    stroke(cv, [(14, 35), (12, 41), (11, 47), (9, 51)], [2.2, 2.0, 1.9, 1.8], IRON)  # hafif disa kivrik
    stroke(cv, [(24, 35), (26, 41), (27, 47), (29, 51)], [2.2, 2.0, 1.9, 1.8], IRON)
    for x in (7, 8, 30, 31):  # ayak kivrimlari
        cv.px(x, 51, IRON[2])
    # bronz kase + kenar + tas
    vol(cv, BOWL, BRONZE)
    cv.hl(11, 27, 31, BRONZE[4])
    cv.hl(12, 26, 33, BRONZE[1])
    cv.glow(18, 34, (FIRE if kind == "q" else SPIRIT)[3], 0.5, "emis")
    cv.glow(19, 34, (FIRE if kind == "q" else SPIRIT)[5], 0.6, "emis")
    cv.glow(20, 34, (FIRE if kind == "q" else SPIRIT)[3], 0.5, "emis")
    if kind == "q":
        # buyuk ates: uc dil + cekirdek
        p2.flame(cv, CX - 4, 31, 7, 5, t, FIRE, 0.6, "front", 0.3)
        p2.flame(cv, CX + 4, 31, 7, 5, t, FIRE, 0.6, "front", 0.6)
        p2.orb(cv, CX, 27, 3.4, t, FIRE)
        p2.flame(cv, CX, 25, 10, 7, t, FIRE)
        p2.particles(cv, t, FIRE, [(14, 26, 0.0, 1.2), (24, 25, 0.4, 1.2), (19, 14, 0.7, 1.5)], 11)
    else:
        p2.flame(cv, CX - 3, 31, 5, 5, t, SPIRIT, 0.5, "front", 0.3)
        p2.flame(cv, CX + 3, 31, 5, 5, t, SPIRIT, 0.5, "front", 0.6)
        p2.flame(cv, CX, 31, 6, 6, t, SPIRIT, 0.6, "front", 0.0)
        p2.light_shield(cv, 12 + bob(t), f, SPIRIT)
        p2.twinkles(cv, f, SPIRIT, [(CX, 8, 0), (8, 18, 3), (30, 16, 5)])
    return cv.render()


# ------------------------------------------------------------------ F) YOSUNLU TAS KULE
def totem_f(kind, f):
    t = f / FRAMES
    cv = Cv()
    grass(cv, 8, 30, t, 6)
    vol(cv, {44: (11, 26), 45: (10, 28), 46: (9, 29), 47: (9, 29), 48: (9, 29), 49: (9, 29), 50: (9, 29), 51: (10, 28)}, MOSSROCK)
    vol(cv, {37: (14, 23), 38: (13, 25), 39: (12, 26), 40: (12, 26), 41: (12, 26), 42: (13, 26), 43: (14, 25)}, MOSSROCK)
    vol(cv, {31: (16, 21), 32: (15, 23), 33: (14, 23), 34: (14, 23), 35: (15, 23), 36: (16, 22)}, MOSSROCK)
    # yosun kapaklari (her tasin tepesi)
    for (y, xl, xr) in ((44, 12, 19), (45, 11, 15), (37, 15, 20), (38, 14, 16), (31, 16, 19)):
        for x in range(xl, xr + 1):
            cv.px(x, y, MOSSY[3] if (x + y) % 3 else MOSSY[4])
    crack(cv, ((22, 46), (20, 49)), MOSSROCK)
    crack(cv, ((16, 40), (17, 42)), MOSSROCK)
    # cakillar
    for (x, y) in ((5, 51), (32, 50)):
        vol(cv, {y - 1: (x, x + 1), y: (x - 1, x + 2)}, MOSSROCK)
    leafy(cv, 26, 43, 3, 21)
    element(cv, kind, f, t, 24 + bob(t), shield_top=14 + bob(t), orb_r=3.0, flame_h=8)
    return cv.render()


DIRECTIONS = [
    ("A", "Kaya Sunak", totem_a),
    ("B", "Kutuk Fener", totem_b),
    ("C", "Harabe Sutun", totem_c),
    ("D", "Kum Heykel", totem_d),
    ("E", "Ayakli Mangal", totem_e),
    ("F", "Yosunlu Tas Kule", totem_f),
]


def map_strip(width, height):
    """Arka plan: harita objelerinden kesitler (kaya, kutuk, agac) - totemler gercek harita sanatinin yaninda gorunsun."""
    root = os.path.abspath(os.path.join(HERE, "..", ".."))
    bg = p2.grass_bg(width, height, seed=9)
    obj = Image.open(os.path.join(root, "harita", "Objects.png")).convert("RGBA")
    for (box, x) in (((400, 175, 440, 215), 6), ((115, 140, 155, 180), width - 46), ((140, 0, 210, 75), width // 2 - 35)):
        piece = obj.crop(box)
        bg.alpha_composite(piece, (x, height - piece.height - 2))
    return bg


def main():
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    sheets = {}
    for (key, name, fn) in DIRECTIONS:
        for kind in ("q", "e"):
            frames = [fn(kind, f) for f in range(FRAMES)]
            sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                sheet.paste(fr, (i * W, 0), fr)
            sheet.save(os.path.join(OUT, "totem_%s_%s.png" % (key, kind)))
            sheets[(key, kind)] = frames
    fnt = p2.font(20)
    # 1) yakin sayfa x4: her satirda 2 yon (Q, E, | Q, E)
    Z = 4
    cw, ch = W * Z, H * Z
    pad, lab = 14, 36
    per_row = 2
    rows_n = (len(DIRECTIONS) + per_row - 1) // per_row
    page = Image.new("RGBA", (pad + per_row * (2 * (cw + pad) + pad), lab + rows_n * (ch + lab) + pad), rgba(34, 40, 30))
    d = ImageDraw.Draw(page)
    for i, (key, name, fn) in enumerate(DIRECTIONS):
        r, c0 = divmod(i, per_row)
        y = lab + r * (ch + lab)
        xb = pad + c0 * (2 * (cw + pad) + pad)
        d.text((xb, y - 28), "%s - %s  (Q | E)" % (key, name), fill=(236, 226, 200), font=fnt)
        for c, kind in enumerate(("q", "e")):
            x = xb + c * (cw + pad)
            page.paste(p2.grass_bg(W, H, seed=i * 5 + c).resize((cw, ch), Image.NEAREST), (x, y))
            page.alpha_composite(sheets[(key, kind)][0].resize((cw, ch), Image.NEAREST), (x, y))
    page.save(os.path.join(OUT, "totem_sayfa.png"))
    # 2) oyun olcegi x2, gercek harita objeleriyle ayni sahnede
    S = 2
    items = [("Shaman", p2.shaman_frame(), 41)]
    for (key, name, fn) in DIRECTIONS:
        items.append((key + " Q", sheets[(key, "q")][0], GY))
        items.append((key + " E", sheets[(key, "e")][0], GY))
    gap, base = 3, 96
    tot_w = sum(im.width for _, im, _ in items) + gap * (len(items) + 1)
    scene = p2.grass_bg(tot_w, base + 52, seed=3)
    obj = Image.open(os.path.join(HERE, "..", "..", "harita", "Objects.png")).convert("RGBA")
    deco = [((400, 175, 440, 215), 10), ((115, 140, 155, 180), 150), ((270, 195, 315, 235), 300), ((440, 290, 485, 330), 470), ((400, 175, 440, 215), 560)]  # agac totemi orttugu icin calilik
    for box, x in deco:
        piece = obj.crop(box)
        scene.alpha_composite(piece, (x, base + 50 - piece.height))
    x = gap
    labels = []
    for (nm, im, foot) in items:
        scene.alpha_composite(im, (x, base - foot))
        labels.append((nm, x + im.width // 2))
        x += im.width + gap
    big = scene.resize((scene.width * S, scene.height * S), Image.NEAREST)
    canvas = Image.new("RGBA", (big.width, big.height + 28), rgba(34, 40, 30))
    canvas.paste(big, (0, 0))
    d = ImageDraw.Draw(canvas)
    f2 = p2.font(14)
    for (nm, cx) in labels:
        d.text((cx * S - d.textlength(nm, font=f2) / 2, big.height + 6), nm, fill=(236, 226, 200), font=f2)
    canvas.save(os.path.join(OUT, "totem_oyun.png"))
    # 3) GIF x3
    Z = 3
    n = len(DIRECTIONS) * 2
    gw, gh = n * (W * Z + 4) + 4, H * Z + 10
    bgs = p2.grass_bg(gw // Z + 1, gh // Z + 1, seed=11).resize(((gw // Z + 1) * Z, (gh // Z + 1) * Z), Image.NEAREST).crop((0, 0, gw, gh))
    gif = []
    for f in range(FRAMES):
        fr = bgs.copy()
        x = 4
        for (key, name, fn) in DIRECTIONS:
            for kind in ("q", "e"):
                fr.alpha_composite(sheets[(key, kind)][f].resize((W * Z, H * Z), Image.NEAREST), (x, 5))
                x += W * Z + 4
        gif.append(fr.convert("RGB"))
    gif[0].save(os.path.join(OUT, "totem_anim.gif"), save_all=True, append_images=gif[1:], duration=int(1000 / FPS), loop=0)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
