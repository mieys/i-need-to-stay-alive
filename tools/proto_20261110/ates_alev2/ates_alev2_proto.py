# ATEŞ ASASI püskürtme alevi - 2. TUR, 4 YENİ PİKSEL PROTOTİP (2026-11-10).
# Dünkü A-D (tools/proto_20261109/ates_alev_proto.py) kısık paletli daire/yay/çizgi denemeleriydi ve ateş gibi okunmadı.
# Bu tur OYUNUN ONAYLI ATEŞ DİLİ: yaratıklardaki yanma alevi (assets/fx/burn/fire_min_sheet.png) - sivri alev dilleri,
# iç içe 3 düz ton (#d64c1f / #fa9433 / #ffdb75) + 1 px bordo dış hat (#661a0f), saydamlık / dither / nokta yok.
#  - 1 sanat pikseli = 0,903 dünya birimi (karakter pikseli), sayfa oyundaki boyda çizilir, gerilmez.
#  - 12 kare / 12 fps dikişsiz döngü (bugünkü 30 fps yanıp sönme göz yoruyordu).
#  - Dört yönün SİLÜETİ ayrı: A tek alev mızrağı + yan diller / B koniye açılan beş dilli yelpaze (dış hatsız) /
#    C kısa namlu alevi + yerde sırayla tutuşan dik alevcikler (ayrı sayfa, yakalama betiği dizer) / D art arda fırlayan kuyruklu damlalar.
#  - Denenip atılan: üç ince şerit (kök/damar gibi), birbirine dolanan iki şerit (örgü ip gibi).
# Oyuna bağlı DEĞİL. Çıktı: out/sheets/<kod>.png + .json (+ C_alevcik.png); ates_alev2_capture.gd gerçek oyunda takar.
# Çalıştır: python -I tools/proto_20261110/ates_alev2/ates_alev2_proto.py
import os, json, math
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "sheets")
W, H = 168, 176
X0, CY = 6, 88          # namlu (asanın ucu) sanat pikseli
NF, FPS = 12, 12
T = NF / FPS
WORLD_PX = 0.903
TAU = 2 * math.pi


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


# fire_min_sheet.png paleti (oyundaki yanma alevi)
OUTL = hx("#661a0f")
RED = hx("#d64c1f")
ORG = hx("#fa9433")
YEL = hx("#ffdb75")
DEEP = hx("#a8301a")    # yalnız dış hatsız B'de kenar tonu


def grid(w, h, ox, oy):
    ys, xs = np.mgrid[0:h, 0:w]
    return xs + 0.5 - ox, ys + 0.5 - oy


PX, PY = grid(W, H, X0, CY)


def h01(i, k=0):
    v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)


def uv(px, py, ox, oy, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    return (px - ox) * ca + (py - oy) * sa, -(px - ox) * sa + (py - oy) * ca


def teardrop(s, s0, pw):
    """Yuvarlak dip, sivri uç: s0'da en geniş."""
    s = np.clip(s, 0.0, 1.0)
    a = np.sqrt(np.clip(1 - ((s0 - s) / s0) ** 2, 0, 1))
    b = np.clip(1 - (s - s0) / (1 - s0), 0, 1) ** pw
    return np.where(s < s0, a, b)


def zero(u):
    return u * 0.0


def ribbon(u, v, L, cfun, w, s0=0.25, pw=1.2, spine=True):
    """Merkez çizgisi cfun(u) olan, ucu sivrilen alev şeridi. (maske, kenara derinlik px)"""
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


class Canvas:
    def __init__(self, w=W, h=H):
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))

    def put(self, mask, col):
        self.rgb[mask] = col
        self.a[mask] = 1.0

    def outline(self, mask, col=OUTL):
        self.put(grow4(mask) & ~mask, col)

    def image(self):
        out = np.dstack([self.rgb, self.a * 255.0]).round().clip(0, 255).astype(np.uint8)
        out[self.a <= 0] = 0
        return Image.fromarray(out, "RGBA")


# ------------------------------------------------------------------ A  ALEV MIZRAĞI
# Tek alev dili: namluda en geniş, uca doğru incelip kamçılanır; kenarlarından ileri akan yan diller + uçtan kopan 3 alevcik.
# Tam fire_min dili (bordo dış hat + 3 ton).
def frame_A(ph):
    C = Canvas()
    L = 110 + 6 * math.sin(TAU * 2 * ph) + 3 * math.sin(TAU * 3 * ph + 1.3)
    lam = 62.0

    def cf(uu):
        return 5.6 * np.clip(uu / L, 0, 1.2) ** 1.5 * np.sin(TAU * (uu / lam - 2 * ph))

    WB, S0, PW = 7.0, 0.13, 0.92
    red, d = ribbon(PX, PY, L, cf, WB, s0=S0, pw=PW)
    org, _ = ribbon(PX - 2.5, PY, L * 0.74, lambda uu: cf(uu + 2.5), WB - 2.4, s0=0.15, pw=0.95)
    org &= d >= 1.9
    yel, _ = ribbon(PX - 4.5, PY, L * 0.42, lambda uu: cf(uu + 4.5), WB - 4.6, s0=0.2, pw=0.95)
    yel &= d >= 3.9
    K = 8
    for i in range(K):
        a = (ph + i / K) % 1.0
        ub = 6 + 84 * a
        side = 1.0 if i % 2 == 0 else -1.0
        env = min(1.0, a * 5.0) * min(1.0, (1 - a) * 2.4)
        hb = WB * float(teardrop(np.float64(ub / L), S0, PW))
        by = float(cf(np.float64(ub))) + side * hb * 0.5
        ang = side * math.radians(11 + 9 * h01(i, 2))
        Lb = (17 + 9 * h01(i, 1)) * env + 2
        wb = 3.6 * env + 0.4
        uu, vv = uv(PX, PY, ub, by, ang)
        bend = side * (0.05 + 0.05 * h01(i, 3))
        m, dd = ribbon(uu, vv, Lb, lambda q: bend * q * q / max(Lb, 1.0) * 4.0, wb, s0=0.3, pw=1.1)
        red |= m
        mi, _ = ribbon(uu - 1.5, vv, Lb * 0.6, lambda q: bend * (q + 1.5) ** 2 / max(Lb, 1.0) * 4.0, wb - 1.7, s0=0.32, pw=1.0, spine=False)
        org |= mi & (dd >= 1.1)
    for j in range(3):
        a = (2 * ph + j / 3.0) % 1.0
        ue = 104 + 34 * a
        ye = (h01(j, 5) - 0.5) * 20 * a + 3.0 * math.sin(TAU * (ph * 2 + j * 0.31))
        uu, vv = uv(PX, PY, ue, ye, (h01(j, 6) - 0.5) * 0.5)
        m, dd = ribbon(uu, vv, 10 * (1 - a) + 2, zero, 2.6 * (1 - a) + 0.6, s0=0.35, pw=1.0)
        red |= m
        org |= m & (dd >= 1.3)
    C.outline(red)
    C.put(red, RED)
    C.put(org & red, ORG)
    C.put(yel & red, YEL)
    return C.image()


# ------------------------------------------------------------------ B  ALEV YELPAZESİ
# Koniye açılan beş alev dili (yanma alevinin yan yatmış, yelpaze hâli); dipte tek gövde, uçta ayrı parmaklar.
# Bordo dış hat YOK: kenar koyu kırmızı (yumuşak okunur), iç turuncu, dipten çıkan sarı damarlar.
def frame_B(ph):
    C = Canvas()
    union = np.zeros((H, W), bool)
    dmax = np.full((H, W), -1.0)
    smin = np.full((H, W), 9.0)
    for j, (deg, L0) in enumerate(((-26, 84), (-13, 104), (0, 118), (13, 104), (26, 84))):
        L = L0 * (1 + 0.08 * math.sin(TAU * (2 * ph - j * 0.21)) + 0.04 * math.sin(TAU * (3 * ph + j * 0.37)))
        lam = 44.0
        p = j * 1.7

        def cf(uu, L=L, p=p):
            return 3.2 * np.clip(uu / L, 0, 1.2) ** 1.5 * np.sin(TAU * (uu / lam - 2 * ph) + p)

        u, v = uv(PX, PY, 0, 0, math.radians(deg))
        m, d = ribbon(u, v, L, cf, 6.2, s0=0.27, pw=0.88)
        union |= m
        smin = np.where(m & (d > dmax), u / L, smin)
        dmax = np.maximum(dmax, d)
    C.put(union, DEEP)
    C.put(union & (dmax >= 1.2), RED)
    C.put(union & (dmax >= 2.5) & (smin < 0.72), ORG)
    C.put(union & (dmax >= 4.5) & (smin < 0.44), YEL)
    return C.image()


# ------------------------------------------------------------------ C  YER ATEŞİ (namlu alevi sayfası + ayrı alevcik sayfası)
def frame_C(ph):
    C = Canvas()
    L = 24 + 3 * math.sin(TAU * 2 * ph) + 2 * math.sin(TAU * 3 * ph + 0.7)

    def cf(uu):
        return 1.6 * np.clip(uu / L, 0, 1.2) ** 1.3 * np.sin(TAU * (uu / 20.0 - 2 * ph))

    red, d = ribbon(PX, PY, L, cf, 4.6, s0=0.3, pw=1.1)
    org, _ = ribbon(PX - 1.5, PY, L * 0.66, lambda uu: cf(uu + 1.5), 2.8, s0=0.32, pw=1.0, spine=False)
    org &= d >= 1.4
    yel, _ = ribbon(PX - 2.5, PY, L * 0.36, lambda uu: cf(uu + 2.5), 1.4, s0=0.35, pw=1.0, spine=False)
    yel &= d >= 2.8
    for side in (1.0, -1.0):
        Ls = 12 + 2.5 * math.sin(TAU * (2 * ph + (0.2 if side > 0 else 0.6)))
        uu, vv = uv(PX, PY, 1.0, side * 2.2, side * math.radians(24))
        m, dd = ribbon(uu, vv, Ls, zero, 2.8, s0=0.3, pw=1.1)
        red |= m
        org |= m & (dd >= 1.5) & (uu < Ls * 0.55)
    C.outline(red)
    C.put(red, RED)
    C.put(org & red, ORG)
    C.put(yel & red, YEL)
    return C.image()


FW, FH, FAX, FAY = 24, 30, 12, 26      # alevcik tuvali, tutunma noktası = taban ortası
FLN = 10                               # yaşam kareleri (12 fps = 0,83 sn)
FL_ENV = [0.28, 0.6, 0.9, 1.0, 0.9, 1.0, 0.88, 0.66, 0.42, 0.22]
FL_LIFT = [0, 0, 0, 0, 0, 0, 0, 1, 3, 6]


def flamelet(g):
    """Yerde dik duran küçük alev (fire_min'in üç dilli silüeti, karakter pikselinde)."""
    px, py = grid(FW, FH, FAX, FAY)
    e = FL_ENV[g]
    lift = FL_LIFT[g]
    C = Canvas(FW, FH)
    red = np.zeros((FH, FW), bool)
    org = np.zeros((FH, FW), bool)
    yel = np.zeros((FH, FW), bool)
    up = -math.pi / 2
    sway = 0.10 * math.sin(TAU * g / 5.0)
    tongues = [
        (0.0, up + sway, 17.0 * e * (0.94 + 0.12 * h01(g, 1)), 3.5 * min(1.0, e * 1.25), True),
        (-3.6, up - 0.20 + sway * 0.5, 10.5 * e * (0.9 + 0.2 * h01(g, 2)), 2.7 * min(1.0, e * 1.25), False),
        (3.6, up + 0.17 + sway * 0.5, 12.0 * e * (0.9 + 0.2 * h01(g, 3)), 2.7 * min(1.0, e * 1.25), False),
    ]
    if e < 0.45:
        tongues = tongues[:1]
    for bx, ang, L, w, core in tongues:
        u, v = uv(px, py, bx, -lift + 1.5, ang)
        m, d = ribbon(u, v, L + 1.5, zero, w, s0=0.32, pw=1.15)
        red |= m
        mi, _ = ribbon(u - 1.0, v, (L + 1.5) * 0.62, zero, w - 1.5, s0=0.34, pw=1.0, spine=False)
        org |= mi & (d >= 1.1)
        if core and e > 0.6:
            my, _ = ribbon(u - 1.5, v, (L + 1.5) * 0.36, zero, w - 2.5, s0=0.36, pw=1.0, spine=False)
            yel |= my & (d >= 2.2)
    if lift == 0:
        flat = py > 0.0          # düz taban (yere basar)
        red &= ~flat
    C.outline(red)
    if lift == 0:
        C.a[py > 1.0] = 0.0
    C.put(red, RED)
    C.put(org & red, ORG)
    C.put(yel & red, YEL)
    return C.image()


# ------------------------------------------------------------------ D  ALEV SAĞANAĞI
# Namludan art arda fırlayan kuyruklu alev damlaları (baş önde, kuyruk geride), koniye yayılır, menzilde küçülerek söner.
def nozzle(C_red, C_org, C_yel, ph, L0=24.0, w=4.6):
    L = L0 + 3 * math.sin(TAU * 2 * ph) + 2 * math.sin(TAU * 3 * ph + 0.7)

    def cf(uu):
        return 1.6 * np.clip(uu / L, 0, 1.2) ** 1.3 * np.sin(TAU * (uu / 20.0 - 2 * ph))

    red, d = ribbon(PX, PY, L, cf, w, s0=0.3, pw=1.1)
    org, _ = ribbon(PX - 1.5, PY, L * 0.66, lambda uu: cf(uu + 1.5), w - 1.8, s0=0.32, pw=1.0, spine=False)
    yel, _ = ribbon(PX - 2.5, PY, L * 0.36, lambda uu: cf(uu + 2.5), w - 3.2, s0=0.35, pw=1.0, spine=False)
    C_red |= red
    C_org |= org & (d >= 1.4)
    C_yel |= yel & (d >= 2.8)


def frame_D(ph):
    C = Canvas()
    red = np.zeros((H, W), bool)
    org = np.zeros((H, W), bool)
    yel = np.zeros((H, W), bool)
    nozzle(red, org, yel, ph, L0=17.0, w=4.2)
    K = 9
    order = [4, 0, 7, 2, 5, 8, 1, 6, 3]         # koniye eşit dağılım, komşu damlalar farklı açıda
    life = 0.78
    for i in range(K):
        age = (ph - i / K) % 1.0
        if age >= life:
            continue
        a = age / life
        th = math.radians(-23 + 46 * order[i] / (K - 1)) * (0.75 + 0.25 * h01(i, 4))
        dist = 10 + 122 * (1 - (1 - a) ** 1.6)
        wob = 2.2 * math.sin(TAU * (a * 1.2 + h01(i, 2)))
        hx_ = dist * math.cos(th) - wob * math.sin(th)
        hy_ = dist * math.sin(th) + wob * math.cos(th)
        size = min(1.0, 0.45 + a * 4.0) * (1.0 if a < 0.68 else 1.0 - (a - 0.68) / 0.32 * 0.7)
        r = (4.3 + 0.8 * h01(i, 3)) * size
        tail = min((22 - 9 * a) * (0.5 + 0.5 * size), dist - 4.0)   # kuyruk namlunun gerisine taşmaz
        uu, vv = uv(PX, PY, hx_ + r * 0.7 * math.cos(th), hy_ + r * 0.7 * math.sin(th), th + math.pi)
        sw = 0.9 * math.sin(TAU * (a * 2.0 + h01(i, 5)))
        TL = tail + r
        m, d = ribbon(uu, vv, TL, lambda q: sw * (q / TL) ** 2 * 3.0, r, s0=0.22, pw=1.25)
        red |= m
        mi, _ = ribbon(uu - 1.2, vv, TL * 0.55, zero, r - 1.6, s0=0.3, pw=1.1, spine=False)
        org |= mi & (d >= 1.2)
        if a < 0.5 and r > 3.4:
            my, _ = ribbon(uu - 2.0, vv, TL * 0.28, zero, r - 3.0, s0=0.4, pw=1.0, spine=False)
            yel |= my & (d >= 2.4)
    C.outline(red)
    C.put(red, RED)
    C.put(org & red, ORG)
    C.put(yel & red, YEL)
    return C.image()


DESIGNS = {
    "A": ("Alev Mızrağı", frame_A, 12, 12),
    "B": ("Alev Yelpazesi", frame_B, 12, 12),
    "C": ("Yer Ateşi", frame_C, 12, 12),
    "D": ("Alev Sağanağı", frame_D, 20, 20),
}
GRASS = (74, 120, 60, 255)


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for code, (name, fn, nf, fps) in DESIGNS.items():
        frames = [fn(f / nf) for f in range(nf)]
        sheet = Image.new("RGBA", (W * nf, H))
        for i, im in enumerate(frames):
            a = np.array(im)[:, :, 3]
            if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
                print("UYARI kenara değiyor:", code, i)
            sheet.paste(im, (i * W, 0))
        sheet.save(os.path.join(OUT, code + ".png"))
        cover = np.mean([(np.array(im)[:, :, 3] > 0).mean() for im in frames])
        meta = {"name": name, "w": W, "h": H, "frames": nf, "fps": fps, "x0": X0, "cy": CY, "world_px": WORLD_PX}
        with open(os.path.join(OUT, code + ".json"), "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False)
        print(code, "kaplama %.3f" % cover)
        y0, y1 = 28, 148
        row = Image.new("RGBA", (W * 3 * 3, (y1 - y0) * 3), GRASS)
        for j, fi in enumerate((0, nf // 3, 2 * nf // 3)):
            row.alpha_composite(frames[fi].crop((0, y0, W, y1)).resize((W * 3, (y1 - y0) * 3), Image.NEAREST), (j * W * 3, 0))
        rows.append(row)
    fl = [flamelet(g) for g in range(FLN)]
    sheet = Image.new("RGBA", (FW * FLN, FH))
    for i, im in enumerate(fl):
        sheet.paste(im, (i * FW, 0))
    sheet.save(os.path.join(OUT, "C_alevcik.png"))
    with open(os.path.join(OUT, "C_alevcik.json"), "w", encoding="utf-8") as fh:
        json.dump({"w": FW, "h": FH, "frames": FLN, "fps": FPS, "ax": FAX, "ay": FAY, "world_px": WORLD_PX}, fh)
    row = Image.new("RGBA", (FW * FLN * 5, FH * 5), GRASS)
    row.alpha_composite(sheet.resize((FW * FLN * 5, FH * 5), Image.NEAREST), (0, 0))
    rows.insert(3, row)
    pv = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), GRASS)
    y = 0
    for r in rows:
        pv.paste(r, (0, y))
        y += r.height
    pv.save(os.path.join(HERE, "out", "sanat_onizleme.png"))


if __name__ == "__main__":
    main()
