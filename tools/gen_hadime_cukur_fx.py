"""Suriyeli Hadime E "LANET CUKURU" efekt sayfalari (2026-11-11, madde 556 prototip A "Coken Zemin" OYUNDA; eski "Kara Delik"
sayfasinin yerine) -> assets/fx/hadime/cukur/

Cizim tools/proto_20261111/kara_delik/kara_delik_proto.py A'nin aynisi; farklar: olcek parametresi S (Genisleyen Cukur evrimi
x1,5 icin AYRI sayfa - germe yok, piksel ayni boyda), dongu 24 kare 12 fps (bellek), tuvaller cizimden degil FORMULDEN merkezli
(dugum = tuvalin tam ortasi -> centered sprite, ofset yok).

  zemin (ground): catlaklar + moloz halkasi + ic duvarli cukur (dibinde yesil lanet isigi) + sarmal cizip cukura kayan
                  toprak/cimen parcalari + soluk alan siniri. Dugumun kendisi (haritanin hemen ustu, yaratiklarin ALTI).
  on (front)    : giris toz halkasi + carpma anindaki yesil isik sutunu ve toz halkasi. z 20 (yaratiklarin ustu).
Zaman cizelgesi SES ile ayni (madde 533): giris 8 kare 20 fps (0,4 sn), dongu, cikis 6,0 sn'de 8 kare 16 fps, CARPMA cikisin
4. karesi = 6,25 sn (cokus vurusu). Cikis basladiktan sonra kodun kendisi (hadime_black_hole.gd) degismez.
1 sanat pikseli = 0,903 dunya (karakter pikseli, stil rehberi). Renkler TAM degerler: harita zeminine gore renk degisimi
(kum / tas) shaders/hadime_cukur_palet.gdshader ile bu tonlari birebir eslestirir - burada ton degistirirsen oradaki listeyi de.

Cikti (S = 1 -> "", S = 1,5 -> "_buyuk"; katman zemin / on; her animasyon AYRI PNG = satir dolgusu yok):
  cukur{_buyuk}_{zemin,on}_{giris,dongu,cikis}.png + cukur{_buyuk}_{zemin,on}.tres (SpriteFrames: intro / loop / outro)
Calistir: python -I tools/gen_hadime_cukur_fx.py   (sonra Godot --headless --import)
"""

import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "hadime", "cukur")
RES = "res://assets/fx/hadime/cukur/"

WORLD_PX = 0.903
SQ = 0.5
HOLE_RADIUS = 110.0          # HadimeMath.HOLE_RADIUS (dunya)
N_IN, N_LOOP, N_OUT = 8, 24, 8
FPS_IN, FPS_LOOP, FPS_OUT = 20, 12, 16
TAU = 2 * math.pi

# ---- palet (TAM degerler; hadime_cukur_palet.gdshader kaynak listesiyle ayni) ----
OUTL = (30, 19, 14)
ED = (68, 45, 31)
EM = (112, 78, 52)
EL = (158, 116, 78)
EH = (196, 156, 108)
GM = (82, 132, 52)
GL = (128, 176, 72)
PIT = (12, 6, 14)
WALL_DEEP = (36, 24, 24)
WALL_GLOW = (24, 30, 22)
CG1 = (34, 96, 34)
CG2 = (111, 220, 74)
CG3 = (214, 255, 170)
DUST = [(92, 76, 58), (140, 122, 98), (180, 164, 138), (214, 202, 178)]


def clamp01(x):
    return max(0.0, min(1.0, x))


def ease_out(t):
    t = clamp01(t)
    return 1.0 - (1.0 - t) ** 2


def hash01(*v):
    h = 2166136261
    for x in v:
        h = (h ^ (int(x) & 0xFFFFFFFF)) * 16777619 & 0xFFFFFFFF
        h ^= h >> 13
    return (h & 0xFFFF) / 65535.0


def band(a):
    """Saydamlik 3 basamak (duz bantlar, dither yok)."""
    if a > 0.8:
        return 1.0
    if a > 0.45:
        return 0.66
    if a > 0.12:
        return 0.33
    return 0.0


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def erode(m):
    o = m.copy()
    o[1:, :] &= m[:-1, :]
    o[:-1, :] &= m[1:, :]
    o[:, 1:] &= m[:, :-1]
    o[:, :-1] &= m[:, 1:]
    return o


def a_wob(th):
    return 1 + 0.08 * np.sin(3 * th + 1.0) + 0.05 * np.sin(5 * th + 2.0) + 0.04 * np.sin(7 * th + 0.5)


def a_wob2(th):
    return 1 + 0.10 * np.sin(4 * th + 0.3) + 0.07 * np.sin(9 * th + 1.7) + 0.05 * np.sin(13 * th + 4.0)


class Canvas:
    """Capa = tuvalin tam ortasi (W, H cift). Koordinatlar capaya gore ekran sanat pikseli."""

    def __init__(self, hw, hh):
        self.W, self.H = 2 * hw, 2 * hh
        self.AX, self.AY = hw, hh
        xs = np.arange(self.W) + 0.5 - self.AX
        ys = np.arange(self.H) + 0.5 - self.AY
        self.GX, self.GY = np.meshgrid(xs, ys)
        self.PU, self.PV = self.GX, self.GY / SQ
        self.PR = np.hypot(self.PU, self.PV)
        self.PT = np.arctan2(self.PV, self.PU)

    def layer(self):
        return np.zeros((self.H, self.W, 4), dtype=np.uint8)

    def put(self, L, mask, col, a=1.0):
        a = band(a)
        if a <= 0:
            return
        L[mask, 0] = col[0]
        L[mask, 1] = col[1]
        L[mask, 2] = col[2]
        L[mask, 3] = int(round(255 * a))

    def px(self, L, x, y, col, a=1.0):
        a = band(a)
        x, y = int(math.floor(x + self.AX)), int(math.floor(y + self.AY))
        if 0 <= x < self.W and 0 <= y < self.H and a > 0:
            L[y, x] = (col[0], col[1], col[2], int(round(255 * a)))

    def ell(self, cx, cy, rx, ry):
        if rx <= 0.3 or ry <= 0.3:
            return np.zeros((self.H, self.W), bool)
        return ((self.GX - cx) / rx) ** 2 + ((self.GY - cy) / ry) ** 2 <= 1.0

    def plane_disc(self, r, wob=None):
        if r <= 0.3:
            return np.zeros((self.H, self.W), bool)
        if wob is None:
            return self.PR <= r
        return self.PR <= r * wob(self.PT)

    def ring1(self, mask):
        return mask & ~erode(mask)

    def line(self, L, x0, y0, x1, y1, col, a=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.px(L, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, a)

    def vnoise(self, scale, seed):
        gx = (self.GX + self.AX) / scale
        gy = (self.GY + self.AY) / scale
        x0 = np.floor(gx).astype(int)
        y0 = np.floor(gy).astype(int)
        fx = gx - x0
        fy = gy - y0
        rng = np.random.default_rng(seed)
        tab = rng.random((int(self.H / scale) + 3, int(self.W / scale) + 3))

        def g(x, y):
            return tab[np.clip(y, 0, tab.shape[0] - 1), np.clip(x, 0, tab.shape[1] - 1)]

        sx = fx * fx * (3 - 2 * fx)
        sy = fy * fy * (3 - 2 * fy)
        a = g(x0, y0) * (1 - sx) + g(x0 + 1, y0) * sx
        b = g(x0, y0 + 1) * (1 - sx) + g(x0 + 1, y0 + 1) * sx
        return a * (1 - sy) + b * sy


def to_screen(rho, th, h=0.0):
    return rho * math.cos(th), rho * math.sin(th) * SQ - h


class Cukur:
    def __init__(self, S):
        self.S = S
        self.R = HOLE_RADIUS * S / WORLD_PX
        self.RP = 26.0 * S          # cukur (duzlem px)
        self.RR = 34.0 * S          # moloz halkasinin disi
        self.g = Canvas(int(math.ceil(self.R + 3)), int(math.ceil(self.R * SQ + 3)))
        self.f = Canvas(int(math.ceil(84 * S)), int(math.ceil(48 * S)))
        self.tex = self.g.vnoise(3.0, 11)
        self.cracks = []
        for j in range(8):
            rng = np.random.default_rng(100 + j)
            th = TAU * j / 8 + rng.uniform(-0.25, 0.25)
            ln = rng.uniform(26, 52) * S
            pts = []
            a = th
            for s in range(0, int(ln) + 1, 3):
                a += rng.uniform(-0.09, 0.09)
                pts.append((s, a))
            self.cracks.append(pts)
        n = int(round(12 * S))
        self.clods = []
        for j in range(n):
            self.clods.append({"th": TAU * j / n + hash01(j, 3) * 0.5, "off": (j * 5 % n) / float(n), "turf": j % 3 == 0,
                               "size": 3.0 + (j % 3) * 0.8, "seed": j})

    # ------------------------------------------------------------------ zemin
    def pit(self, L, k, glow, ph, jit=0):
        c = self.g
        if k <= 0.04:
            return
        rp, rr = self.RP * k, self.RR * k
        shift = np.roll(c.PR, jit, axis=1) if jit else c.PR
        pit = shift <= rp * a_wob(c.PT)
        rub = (shift <= rr * a_wob2(c.PT)) & ~pit
        allm = pit | rub
        c.put(L, dilate(allm) & ~allm, OUTL)
        c.put(L, rub, EM)
        c.put(L, rub & (self.tex > 0.62), ED)
        c.put(L, rub & (self.tex < 0.25), EL)
        lit = rub & ~erode(allm) & (c.GY < 2) & (c.GX < 6 * self.S)
        c.put(L, lit, EH)
        c.put(L, rub & dilate(pit), ED)
        c.put(L, pit, PIT)
        dep = max(2.0, 7.0 * k)
        floor_m = (c.PU ** 2 + ((c.GY - dep) / SQ) ** 2) <= (rp * 0.86) ** 2
        wall = pit & ~floor_m & (c.GY < dep * 0.6)
        if wall.any():
            top = np.full(c.W, 10 ** 6)
            for col in np.where(wall.any(axis=0))[0]:
                top[col] = np.argmax(pit[:, col])
            d = np.arange(c.H)[:, None] - top[None, :]
            for dd, col in ((0, EL), (1, EM), (2, ED), (3, ED), (4, WALL_DEEP), (5, WALL_DEEP)):
                c.put(L, wall & (d == dd), col)
            c.put(L, wall & (d >= 6), WALL_GLOW)
        if glow > 0:
            gr = rp * (0.48 + 0.06 * math.sin(TAU * ph * 2))
            gm = (c.PU ** 2 + ((c.GY - dep - 1) / SQ) ** 2) <= gr ** 2
            c.put(L, gm & pit, CG1, 0.66 * glow + 0.34 * (glow > 0.99))
            core = (c.PU ** 2 + ((c.GY - dep - 1) / SQ) ** 2) <= (gr * 0.45) ** 2
            c.put(L, core & pit, CG2 if glow < 1.2 else CG3, 1.0 if glow >= 0.66 else 0.66)
            c.put(L, c.ring1(gm) & pit & (c.GY > 0), CG2, 0.66)
        c.put(L, dilate(pit) & ~pit & (c.GY > 1), EH)

    def draw_cracks(self, L, length_k, base_r):
        c = self.g
        for pts in self.cracks:
            n = max(1, int(len(pts) * clamp01(length_k)))
            for idx in range(n - 1):
                s0, a0 = pts[idx]
                s1, a1 = pts[idx + 1]
                x0, y0 = to_screen(base_r + s0, a0)
                x1, y1 = to_screen(base_r + s1, a1)
                c.line(L, x0, y0 + 1, x1, y1 + 1, EL, 0.66)
                c.line(L, x0, y0, x1, y1, OUTL)
                if idx < n * 0.55:
                    c.line(L, x0 + 1, y0, x1 + 1, y1, OUTL)

    def clod_pos(self, cl, u):
        if u < 0.86:
            rho = self.RP + (self.R - 6 - self.RP) * (1 - u / 0.86)
        else:
            rho = self.RP * (1 - (u - 0.86) / 0.14 * 0.6)
        x, y = to_screen(rho, cl["th"] + 1.5 * u)
        if u >= 0.86:
            y += (u - 0.86) / 0.14 * 8 * self.S
        return x, y

    def clod(self, L, cl, u, pitmask):
        c = self.g
        if u < 0 or u >= 1:
            return
        x, y = self.clod_pos(cl, u)
        s = cl["size"] * min(1.0, u / 0.08) * (1 - 0.35 * clamp01((u - 0.6) / 0.4))
        if s < 1.0:
            return
        falling = u >= 0.86
        if not falling and u > 0.06:
            x0, y0 = self.clod_pos(cl, u - 0.05)
            c.line(L, x0, y0 + s * 0.6, x, y + s * 0.6, ED, 0.33)
        m = c.ell(x, y, s, s * 0.8)
        rng = np.random.default_rng(cl["seed"])
        cut = c.ell(x + rng.uniform(-1, 1) * s, y - s * 0.9, s * 0.7, s * 0.5)
        m = m & ~(cut & (hash01(cl["seed"], 7) > 0.5))
        if falling:
            m = m & pitmask
            if not m.any():
                return
            c.put(L, dilate(m) & ~m & pitmask, OUTL)
            c.put(L, m, ED if u < 0.93 else WALL_DEEP)
            return
        c.put(L, dilate(m) & ~m, OUTL)
        if cl["turf"]:
            c.put(L, m, EM)
            top = m & (c.GY < y)
            c.put(L, top, GM)
            c.put(L, top & ~np.roll(top, 1, axis=0), GL)
        else:
            c.put(L, m, EM)
            c.put(L, m & (c.GY < y - s * 0.25) & (c.GX < x + s * 0.2), EL)
            c.put(L, m & ((c.GY > y + s * 0.3) | (c.GX > x + s * 0.55)), ED)
            c.px(L, x - s * 0.35, y - s * 0.35, EH)

    # ------------------------------------------------------------------ on katman
    def dust_ring(self, L, rr, lift, size, erode_k, seed=0):
        """Toz halkasi TEK KUTLE (ayni diskler 'mantar/para yigini' gibi okunur); erode_k: ustten hilale asinir."""
        c = self.f
        if size < 0.8:
            return
        rng = np.random.default_rng(seed)
        m = np.zeros((c.H, c.W), bool)
        cut = np.zeros((c.H, c.W), bool)
        n = int(round(16 * self.S))
        for j in range(n):
            th = TAU * j / n + rng.uniform(-0.12, 0.12)
            r = size * rng.uniform(0.55, 1.0)
            x, y = to_screen(rr * rng.uniform(0.9, 1.08), th, lift * rng.uniform(0.5, 1.0))
            m |= c.ell(x, y, r, r * 0.75)
            if erode_k > 0:
                cut |= c.ell(x + r * 0.3, y - r * (0.35 + 0.5 * erode_k), r * (0.5 + 0.55 * erode_k), r * 0.8)
        m &= ~cut
        if not m.any():
            return
        c.put(L, m, DUST[1])
        c.put(L, m & ~np.roll(m, 2, axis=0), DUST[2])
        c.put(L, m & ~np.roll(m, 1, axis=0), DUST[3])
        c.put(L, m & ~np.roll(m, -2, axis=0), DUST[0])

    # ------------------------------------------------------------------ kareler
    def frame(self, phase, i):
        S = self.S
        g, f = self.g.layer(), self.f.layer()
        seam = self.g.ring1(self.g.plane_disc(self.R - 2))
        if phase == "in":
            t = i / (N_IN - 1)
            k = ease_out(t * 1.15)
            if t > 0.4:
                self.g.put(g, seam, ED, 0.33)
            self.draw_cracks(g, ease_out(t * 1.3), self.RR * k)
            self.pit(g, k, t, 0.0)
            self.dust_ring(f, (10 + 40 * ease_out(t)) * S, 5 * S * math.sin(math.pi * t), (6.0 * (1 - t) + 1.0) * S,
                           clamp01((t - 0.35) / 0.65), seed=3)
            if i >= 5:
                pitm = self.g.plane_disc(self.RP * k, a_wob)
                for cl in self.clods:
                    self.clod(g, cl, cl["off"] * min(1.0, (i - 4) / 3.0), pitm)
        elif phase == "loop":
            ph = i / N_LOOP
            self.g.put(g, seam, ED, 0.33)
            self.draw_cracks(g, 1.0, self.RR)
            self.pit(g, 1.0, 1.0, ph)
            pitm = self.g.plane_disc(self.RP, a_wob)
            for cl in self.clods:
                self.clod(g, cl, (ph + cl["off"]) % 1.0, pitm)
        else:
            if i < 4:
                k = 1.0 - 0.12 * i / 3
                jit = (1 if i % 2 == 0 else -1) if i > 0 else 0
                self.g.put(g, seam, ED, 0.33)
                self.draw_cracks(g, 1.0, self.RR * k)
                self.pit(g, k, 1.0 + 0.4 * i / 3, 0.0, jit)
                pitm = self.g.plane_disc(self.RP * k, a_wob)
                for cl in self.clods:
                    self.clod(g, cl, (cl["off"] + 0.12 * i * (1 + i * 0.3)) % 1.0, pitm)
            else:
                u = (i - 4) / 3.0
                self.draw_cracks(g, 1.0 - u, self.RR * (0.6 - 0.3 * u))
                if i == 4:
                    self.pit(g, 0.45, 1.5, 0.0)
                elif i == 5:
                    self.pit(g, 0.2, 0.0, 0.0)
                fc = self.f
                if i <= 6:
                    hgt = (40 if i == 4 else (30 if i == 5 else 18)) * S
                    wb = (7 if i == 4 else (5 if i == 5 else 3)) * S
                    col = fc.ell(0, -hgt / 2, wb, hgt / 2) & (fc.GY < 2)
                    if i >= 5:
                        col = col & ~fc.ell(-1, -hgt / 2 - 4 * S * (i - 4), wb * 0.9, hgt / 2)
                    fc.put(f, dilate(col) & ~col, CG1)
                    fc.put(f, col, CG2)
                    fc.put(f, col & fc.ell(0, -hgt / 2 + 2, max(1, wb - 3), hgt / 2 - 3), CG3)
                    if i == 4:
                        self.g.put(g, self.g.ell(0, 0, 14 * S, 7 * S), CG2, 0.66)
                        self.g.put(g, self.g.ell(0, 0, 8 * S, 4 * S), CG3)
                self.dust_ring(f, (30 + 34 * ease_out(u)) * S, 3 * S * (1 - u), 7.0 * S * (1 - 0.55 * u), u * 0.9, seed=5)
        return g, f


def edge_touch(a):
    return bool(a[0, :, 3].any() or a[-1, :, 3].any() or a[:, 0, 3].any() or a[:, -1, 3].any())


def write_frames_tres(path, anims):
    """anims: [(ad, png_res, kare_w, kare_h, kare_sayisi, dongu, fps)] - her animasyon kendi dokusundan."""
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for n, a in enumerate(anims):
        lines.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % (a[1], n + 1))
    lines.append("")
    blocks = []
    at = 0
    for n, (name, _res, w, h, count, loop, fps) in enumerate(anims):
        ids = []
        for i in range(count):
            lines.append('[sub_resource type="AtlasTexture" id="AT_%d"]' % at)
            lines.append('atlas = ExtResource("%d")' % (n + 1))
            lines.append("region = Rect2(%d, 0, %d, %d)" % (i * w, w, h))
            lines.append("")
            ids.append(at)
            at += 1
        entries = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in ids)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            entries, "true" if loop else "false", name, float(fps)))
    lines.append("[resource]")
    lines.append("animations = [%s]" % ", ".join(blocks))
    lines.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def build(S, suffix):
    cz = Cukur(S)
    phases = (("giris", "in", N_IN, "intro", False, FPS_IN), ("dongu", "loop", N_LOOP, "loop", True, FPS_LOOP),
              ("cikis", "out", N_OUT, "outro", False, FPS_OUT))
    os.makedirs(OUT, exist_ok=True)
    tres = {"zemin": [], "on": []}
    edges = []
    for fname, ph, n, anim, loop, fps in phases:
        frames = [cz.frame(ph, i) for i in range(n)]
        for li, lname in enumerate(("zemin", "on")):
            imgs = [fr[li] for fr in frames]
            if lname == "on" and ph == "loop":
                imgs = [imgs[0]]       # on katmanin dongusu bos: tek saydam kare
            cv = cz.g if lname == "zemin" else cz.f
            sheet = np.zeros((cv.H, cv.W * len(imgs), 4), dtype=np.uint8)
            for k, im in enumerate(imgs):
                if edge_touch(im):
                    edges.append("%s/%s/%d" % (lname, ph, k))
                sheet[:, k * cv.W:(k + 1) * cv.W] = im
            png = "cukur%s_%s_%s.png" % (suffix, lname, fname)
            Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, png))
            tres[lname].append((anim, RES + png, cv.W, cv.H, len(imgs), loop, fps))
    for lname, anims in tres.items():
        write_frames_tres(os.path.join(OUT, "cukur%s_%s.tres" % (suffix, lname)), anims)
    print("  S=%.1f zemin %dx%d  on %dx%d  kenar=%s" % (S, cz.g.W, cz.g.H, cz.f.W, cz.f.H, edges[:5] if edges else "temiz"))
    return not edges


def main():
    ok = build(1.0, "") and build(1.5, "_buyuk")
    print("tamam" if ok else "UYARI: tuval kenarina degen kare var")


if __name__ == "__main__":
    main()
