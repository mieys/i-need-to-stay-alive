# ATEŞ ASASI püskürtmesi "ALEV SAĞANAĞI" (madde 550, 2026-11-10; kullanıcı madde 548 prototiplerinden D'yi seçti).
# Namludan art arda fırlayan kuyruklu alev damlaları (baş önde, kuyruk geride): koniye yayılır, menzilde küçülerek söner.
# Çizim dili = yaratıklardaki yanma alevi (assets/fx/burn/fire_min_sheet.png): sivri diller, 3 düz ton + 1 px bordo dış hat,
# saydamlık / dither / nokta yok. 1 sanat pikseli = 0,903 dünya birimi (karakter pikseli) - sayfa oyundaki boyda çizilir.
#
# Çıktı (assets/fx/enchant/, fx_enchant_sprite "loop" animasyonu, 20 kare / 20 fps dikişsiz, 5x4 ızgara):
#   flame_shower_fire      taban koni: 140 birim / 60 derece (9 damla, +-23 derece)
#   flame_shower_fire_big  Ejderha Nefesi: 205 birim (çizim sınırı) / 75-90 derece (14 damla, +-31 derece) - GERME YOK, ayrı sayfa
#   flame_shower_ice[_big] aynı sayfanın buza boyanmışı (kapalı "destiny" kartının buz dalı)
# Sayfa boyu / namlu ofseti değişirse scripts/weapon_traits/ates_nefesi.gd DROPS_* sabitlerini güncelle (betik sonunda yazdırır).
# Çalıştır: python -I tools/gen_alev_saganagi_fx.py   (sonra Godot --import ya da editör)
import os, math
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "enchant")
RES = "res://assets/fx/enchant/"
NF, FPS, COLS = 20, 20, 5
WORLD_PX = 0.903
TAU = 2 * math.pi


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


# fire_min_sheet.png paleti
OUTL, RED, ORG, YEL = hx("#661a0f"), hx("#d64c1f"), hx("#fa9433"), hx("#ffdb75")
# buz: eski flame_ice sayfasının mavileri (koyu hat -> mavi -> açık mavi -> buz beyazı)
ICE = {OUTL: hx("#1f4a8c"), RED: hx("#3f84e0"), ORG: hx("#6fb6f5"), YEL: hx("#ecfaff")}


def h01(i, k=0):
    v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)


def teardrop(s, s0, pw):
    s = np.clip(s, 0.0, 1.0)
    a = np.sqrt(np.clip(1 - ((s0 - s) / s0) ** 2, 0, 1))
    b = np.clip(1 - (s - s0) / (1 - s0), 0, 1) ** pw
    return np.where(s < s0, a, b)


def zero(u):
    return u * 0.0


def ribbon(u, v, L, cfun, w, s0=0.25, pw=1.2, spine=True):
    """Merkez çizgisi cfun(u) olan, ucu sivrilen alev şeridi: (maske, kenara derinlik px)."""
    if L < 1.0 or w <= 0.2:
        return np.zeros(u.shape, bool), np.full(u.shape, -1.0)
    s = u / L
    c = cfun(u)
    slope = cfun(u + 0.5) - cfun(u - 0.5)
    hh = w * teardrop(s, s0, pw)
    off = np.abs(v - c)
    d = hh - off / np.sqrt(1 + slope * slope)
    inside = (s >= 0) & (s <= 1) & (d > 0)
    if spine:   # uç 1 px'lik kesintisiz çizgiyle biter (kopuk nokta olmasın)
        inside |= (s >= 0) & (s <= 0.97) & (off <= 0.5)
    return inside, np.where(inside, np.maximum(d, 0.01), -1.0)


def grow4(m):
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


class Sheet:
    """Bir koni boyu için kare çizici. reach = damlanın vardığı uzaklık (sanat px), spread = +- derece, k = damla sayısı."""

    def __init__(self, name, reach, spread, k, order):
        self.name, self.reach, self.spread, self.k, self.order = name, reach, spread, k, order
        self.x0 = 6
        self.w = int(self.x0 + reach + 26)
        half = int(math.sin(math.radians(spread)) * reach + 18)
        self.h = half * 2
        self.cy = half
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        self.px = xs + 0.5 - self.x0
        self.py = ys + 0.5 - self.cy

    def uv(self, ox, oy, ang):
        ca, sa = math.cos(ang), math.sin(ang)
        return (self.px - ox) * ca + (self.py - oy) * sa, -(self.px - ox) * sa + (self.py - oy) * ca

    def frame(self, ph):
        PX, PY = self.px, self.py
        red = np.zeros(PX.shape, bool)
        org = np.zeros(PX.shape, bool)
        yel = np.zeros(PX.shape, bool)
        # namlu alevi (kaynak okunsun)
        L = 17.0 + 3 * math.sin(TAU * 2 * ph) + 2 * math.sin(TAU * 3 * ph + 0.7)

        def cf(uu):
            return 1.6 * np.clip(uu / L, 0, 1.2) ** 1.3 * np.sin(TAU * (uu / 20.0 - 2 * ph))

        m, d = ribbon(PX, PY, L, cf, 4.2, s0=0.3, pw=1.1)
        mo, _ = ribbon(PX - 1.5, PY, L * 0.66, lambda uu: cf(uu + 1.5), 2.4, s0=0.32, pw=1.0, spine=False)
        my, _ = ribbon(PX - 2.5, PY, L * 0.36, lambda uu: cf(uu + 2.5), 1.0, s0=0.35, pw=1.0, spine=False)
        red |= m
        org |= mo & (d >= 1.4)
        yel |= my & (d >= 2.8)
        life = 0.78
        for i in range(self.k):
            age = (ph - i / self.k) % 1.0
            if age >= life:
                continue
            a = age / life
            th = math.radians(-self.spread + 2 * self.spread * self.order[i] / (self.k - 1)) * (0.75 + 0.25 * h01(i, 4))
            dist = 10 + (self.reach - 10) * (1 - (1 - a) ** 1.6)
            wob = 2.2 * math.sin(TAU * (a * 1.2 + h01(i, 2)))
            hx_ = dist * math.cos(th) - wob * math.sin(th)
            hy_ = dist * math.sin(th) + wob * math.cos(th)
            size = min(1.0, 0.45 + a * 4.0) * (1.0 if a < 0.68 else 1.0 - (a - 0.68) / 0.32 * 0.7)
            r = (4.3 + 0.8 * h01(i, 3)) * size
            tail = min((22 - 9 * a) * (0.5 + 0.5 * size), dist - 4.0)   # kuyruk namlunun gerisine taşmaz
            uu, vv = self.uv(hx_ + r * 0.7 * math.cos(th), hy_ + r * 0.7 * math.sin(th), th + math.pi)
            sw = 0.9 * math.sin(TAU * (a * 2.0 + h01(i, 5)))
            TL = tail + r
            m, d = ribbon(uu, vv, TL, lambda q: sw * (q / TL) ** 2 * 3.0, r, s0=0.22, pw=1.25)
            red |= m
            mi, _ = ribbon(uu - 1.2, vv, TL * 0.55, zero, r - 1.6, s0=0.3, pw=1.1, spine=False)
            org |= mi & (d >= 1.2)
            if a < 0.5 and r > 3.4:
                my, _ = ribbon(uu - 2.0, vv, TL * 0.28, zero, r - 3.0, s0=0.4, pw=1.0, spine=False)
                yel |= my & (d >= 2.4)
        out = np.zeros(PX.shape + (4,), np.uint8)
        for mask, col in ((grow4(red) & ~red, OUTL), (red, RED), (org & red, ORG), (yel & red, YEL)):
            out[mask] = col + (255,)
        return out


def recolor(arr, table):
    out = arr.copy()
    for src, dst in table.items():
        m = (arr[:, :, 0] == src[0]) & (arr[:, :, 1] == src[1]) & (arr[:, :, 2] == src[2]) & (arr[:, :, 3] > 0)
        out[m] = dst + (255,)
    return out


def write_tres(name, w, h):
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             '[ext_resource type="Texture2D" path="%s%s_sheet.png" id="1"]' % (RES, name), ""]
    for i in range(NF):
        lines += ['[sub_resource type="AtlasTexture" id="AT_%d"]' % i, 'atlas = ExtResource("1")',
                  "region = Rect2(%d, %d, %d, %d)" % ((i % COLS) * w, (i // COLS) * h, w, h), ""]
    fr = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in range(NF))
    lines += ["[resource]", 'animations = [{\n"frames": [%s],\n"loop": true,\n"name": &"loop",\n"speed": %.1f\n}]' % (fr, FPS), ""]
    with open(os.path.join(OUT, name + "_frames.tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def save(name, frames, w, h):
    sheet = Image.new("RGBA", (w * COLS, h * (NF // COLS)))
    for i, fr in enumerate(frames):
        sheet.paste(Image.fromarray(fr, "RGBA"), ((i % COLS) * w, (i // COLS) * h))
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    write_tres(name, w, h)


def main():
    sheets = [
        Sheet("flame_shower_fire", 132.0, 23.0, 9, [4, 0, 7, 2, 5, 8, 1, 6, 3]),
        Sheet("flame_shower_fire_big", 196.0, 31.0, 14, [(i * 5) % 14 for i in range(14)]),
    ]
    for sh in sheets:
        frames = [sh.frame(f / NF) for f in range(NF)]
        for i, fr in enumerate(frames):
            a = fr[:, :, 3] > 0
            if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
                print("UYARI kenara değiyor:", sh.name, i)
        save(sh.name, frames, sh.w, sh.h)
        save(sh.name.replace("fire", "ice"), [recolor(fr, ICE) for fr in frames], sh.w, sh.h)
        cover = np.mean([(fr[:, :, 3] > 0).mean() for fr in frames])
        print("%s: kare %dx%d, sayfa %dx%d, ofset Vector2(%.1f, %.1f), kaplama %.3f, isik konisi %d px" % (
            sh.name, sh.w, sh.h, sh.w * COLS, sh.h * (NF // COLS), sh.w * 0.5 - sh.x0, sh.h * 0.5 - sh.cy, cover,
            round(sh.reach + 5)))


if __name__ == "__main__":
    main()
