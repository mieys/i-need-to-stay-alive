# ATEŞ ASASI püskürtme alevi - YENİ 4 PİKSEL PROTOTİP (2026-11-09, kullanıcı: "eskisi iyi değil çok göz yoruyor").
# Oyuna bağlı DEĞİL. Çıktı: out/ates_alev/sheets/<kod>.png (yatay şerit) + <kod>.json; ates_alev_capture.gd bunları
# gerçek oyunda mevcut alevin (fx_enchant_sprite "flame_fire") yerine takar.
#
# Kurallar (hafıza: fx-texel-density-and-soft-ends, minimal-visuals-and-prototypes):
#  - 1 sanat pikseli = 0,903 dünya birimi (karakter pikseli; eskisi 2,74 birimlik iri bloklardı), sayfa oyundaki boyda çizilir, gerilmez.
#  - Limon sarısı / beyaz çekirdek YOK: en açık ton sıcak açık turuncu ve az kullanılır; saydamlık 5 basamak (dither / nokta nokta parazit yok).
#  - Her başlangıç/bitiş incelir (dil uçları, yay uçları), kenara değen piksel yok.
#  - Dört yönün silüeti VE çizim dili ayrı: A tek dış hatlı saydam koni (bugünkü silüet) / B dış hatsız eşmerkezli toplar (Terraria) /
#    C ince bantlı yay dalgaları / D renkli dış hatlı kısa baş + çizgi kıvılcımlar.
#  - Hasar konisi aynı (140 birim = 155 sanat px, 60 derece); görünür boy menzilin %80-100'ü.
# Çalıştır: python -I tools/proto_20261109/ates_alev_proto.py
import os, json, math
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "ates_alev", "sheets")
W, H = 168, 176
X0, CY = 6, 88          # namlu (asanın ucu) sanat pikseli
NF, FPS = 24, 20
T = NF / FPS            # 1,2 sn dikişsiz döngü
WORLD_PX = 0.903


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


# Ortak sıcak, kısık palet (rengi aynı, çizim dili farklı)
OUT_C = hx("#5c1e1a")   # koyu bordo dış hat
DEEP = hx("#962c1e")
RED = hx("#cd4e26")
ORG = hx("#ec8038")
LIT = hx("#f6b062")     # en açık: sıcak açık turuncu (beyaz/limon yok)
SMOKE = hx("#463432")

ys, xs = np.mgrid[0:H, 0:W]
PX = xs + 0.5 - X0
PY = ys + 0.5 - CY


def h01(i, k=0):
    v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)


def band(a):
    """Saydamlık 5 basamak (0,2 adım)."""
    return np.round(np.clip(a, 0, 1) * 5.0) / 5.0


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3))
        self.a = np.zeros((H, W))

    def put(self, mask, col, alpha):
        self.rgb[mask] = col
        self.a[mask] = alpha if np.isscalar(alpha) else alpha[mask]

    def image(self):
        a = band(self.a)
        out = np.dstack([self.rgb, a * 255.0]).round().clip(0, 255).astype(np.uint8)
        out[a <= 0] = 0
        return Image.fromarray(out, "RGBA")


def grow4(m):
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


def tongue(t, sx, sy, ang, L, wmax, amp, lam, phase, lobe=0.2, w0=1.2):
    """Dalgalanan, ucu incelen alev dili: (içeride, yanal derinlik, boy oranı)."""
    ca, sa = math.cos(ang), math.sin(ang)
    u = (PX - sx) * ca + (PY - sy) * sa
    v = -(PX - sx) * sa + (PY - sy) * ca
    s = np.clip(u / L, 0, 1)
    ctr = amp * s * np.sin(2 * math.pi * (u / lam - t / T) + phase)
    prof = np.where(s < 0.14, s / 0.14, np.where(s < 0.5, 1.0, 0.5 * (1 + np.cos(math.pi * (s - 0.5) / 0.5))))
    w = np.maximum(w0 * (s < 0.97), wmax * prof)
    w = w * (1 + lobe * np.sin(2 * math.pi * (u / 15.0 - 2 * t / T) + phase * 1.7))
    d = w - np.abs(v - ctr)
    inside = (u >= 0) & (u <= L) & (d > 0)
    return inside, np.where(inside, d, -1.0), s


def disc(cx, cy, r):
    return (PX - cx) ** 2 + (PY - cy) ** 2 <= r * r


# ------------------------------------------------------------------ A  SAKİN NEFES (bugünkü silüet, yeniden: tek dış hatlı saydam koni)
def erode4(m):
    e = m.copy()
    e[1:, :] &= m[:-1, :]
    e[:-1, :] &= m[1:, :]
    e[:, 1:] &= m[:, :-1]
    e[:, :-1] &= m[:, 1:]
    e[0, :] = e[-1, :] = False
    e[:, 0] = e[:, -1] = False
    return e


def depth(m, n=8):
    d = np.zeros(m.shape, int)
    cur = m.copy()
    for _ in range(n):
        d += cur
        cur = erode4(cur)
    return d


def frame_A(f):
    """Ateş kısmı OPAK (saydam kırmızı çimen üstünde kahverengi çamura dönüyordu), saydamlık yalnız sönen duman ucunda."""
    t = f / FPS
    C = Canvas()
    K = 36
    inside = np.zeros((H, W), bool)
    agemin = np.full((H, W), 9.0)
    for i in range(K):
        a = ((t / T) * 2 + i / K) % 1.0     # döngüde iki geçiş: ~130 px / 0,6 sn
        dist = 3 + 124 * a
        lat = (h01(i, 1) - 0.5) * 2 * dist * math.tan(math.radians(15))
        lat += 1.6 * math.sin(2 * math.pi * (a * 1.5 + h01(i, 2)))
        r = (3.0 + 0.10 * dist) * (0.85 + 0.3 * h01(i, 3))
        if a > 0.72:
            r *= 1 - (a - 0.72) / 0.28 * 0.7              # uçta topçuklar küçülerek söner
        if r < 1.0:
            continue
        m = disc(dist, lat, r)
        inside |= m
        agemin = np.where(m, np.minimum(agemin, a), agemin)
    inside |= erode4(grow4(inside))      # küçük iç delikleri kapat (içte koyu nokta kalmasın)
    agemin = np.where(inside & (agemin > 8), 0.5, agemin)
    d = depth(inside)
    tone = np.where(d >= 6, 3, np.where(d >= 3, 2, np.where(d >= 2, 1, 0)))
    tone = np.where((tone == 3) & (agemin > 0.35), 2, tone)
    tone = np.clip(tone - (agemin > 0.5), 0, 3)
    fire = inside & (agemin < 0.72)
    smoke = inside & ~fire
    near = agemin.copy()
    for sh in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        near = np.minimum(near, np.roll(agemin, sh, axis=(0, 1)))
    ring = grow4(inside) & ~inside
    C.put(ring, OUT_C, np.where(near < 0.72, 1.0, 0.4))
    for i, col in enumerate([DEEP, RED, ORG, LIT]):
        C.put(fire & (tone == i), col, 1.0)
    sm_a = np.where(agemin < 0.86, 0.6, 0.4)
    C.put(smoke & (d >= 3), DEEP, sm_a)
    C.put(smoke & (d < 3), SMOKE, sm_a)
    return C.image()


# ------------------------------------------------------------------ B  ALEV TOPLARI (dış hatsız, eşmerkezli, Terraria)
def frame_B(f):
    t = f / FPS
    C = Canvas()
    K = 20
    parts = []
    for i in range(K):
        life = 0.6 + 0.16 * h01(i, 3)
        age = (t - i * T / K) % T
        if age >= life:
            continue
        a = age / life
        th = (h01(i, 1) - 0.5) * 2 * 0.45
        D = 118 + 30 * h01(i, 2)
        dist = D * (1 - (1 - a) ** 1.8)
        wob = 3.0 * math.sin(2 * math.pi * (a * 1.3 + h01(i, 4)))
        x = dist * math.cos(th) - wob * math.sin(th)
        y = dist * math.sin(th) + wob * math.cos(th)
        r = 2.2 + 8.6 * a ** 0.55
        if a > 0.76:
            r *= 1 - (a - 0.76) / 0.24 * 0.45
        parts.append((a, x, y, r))
    parts.sort(key=lambda p: -p[0])  # yaşlılar arkada
    for a, x, y, r in parts:
        if a < 0.36:
            tones, al = (RED, ORG, LIT), 1.0
        elif a < 0.62:
            tones, al = (DEEP, RED, ORG), 1.0
        elif a < 0.8:
            tones, al = (SMOKE, DEEP, RED), 0.6
        else:
            tones, al = (SMOKE, SMOKE, DEEP), 0.4
        C.put(disc(x, y, r), tones[0], al)
        C.put(disc(x + 0.6, y - 0.4, r * 0.68), tones[1], al)
        C.put(disc(x + 0.9, y - 0.6, r * 0.36), tones[2], al)
    return C.image()


# ------------------------------------------------------------------ C  ALEV DALGASI (ince bantlı yay cepheleri)
def frame_C(f):
    t = f / FPS
    C = Canvas()
    rr = np.hypot(PX, PY)
    an = np.arctan2(PY, PX)
    K, life = 4, 0.9
    waves = []
    for i in range(K):
        age = (t - i * T / K) % T
        if age >= life:
            continue
        waves.append(age / life)
    waves.sort(reverse=True)
    for a in waves:
        r = 6 + 142 * (1 - (1 - a) ** 1.3)
        phi = math.radians(12 + 17 * min(1.0, a * 1.6))
        th = 7 if a < 0.25 else 5 if a < 0.5 else 4 if a < 0.75 else 2
        q = np.clip(an / phi, -1.2, 1.2)
        taper = np.sqrt(np.clip(1 - q * q, 0, 1))
        # cephe dişleri: ileri bakan küçük alev uçları, yavaşça kayar
        tooth = np.abs(((an * 180 / math.pi) / 6.0 + t * 1.5 + i * 0.37) % 2.0 - 1.0)
        teeth = np.clip((1 - tooth) * 2.0 - 0.6, 0, 1) * 5.0 * (a < 0.8)
        outer = r + teeth * taper
        inner = r - th * taper
        band_m = (np.abs(an) <= phi) & (rr <= outer) & (rr >= inner) & (taper > 0.15)
        lead = band_m & (rr > outer - 2.6)
        al = 1.0 if a < 0.4 else 0.8 if a < 0.7 else 0.6
        body = DEEP if a > 0.6 else RED
        edge = LIT if a < 0.3 else ORG if a < 0.6 else RED
        C.put(band_m, body, al)
        C.put(lead, edge, al)
    # namlu alevi: küçük dış hatsız dil (kaynak okunsun)
    m, d, s = tongue(t, 0, 0, 0.0, 20, 3.6, 1.2, 14, 0.0, lobe=0.25)
    C.put(m, RED, 1.0)
    C.put(m & (d > 1.2), ORG, 1.0)
    C.put(m & (d > 2.4) & (s < 0.5), LIT, 1.0)
    return C.image()


# ------------------------------------------------------------------ D  KOR YELPAZESİ (kısa baş + çizgi kıvılcım)
def put_line(C, x0, y0, x1, y1, col, al, thick=1):
    n = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2.5))
    nx, ny = -(y1 - y0), (x1 - x0)
    ln = math.hypot(nx, ny) or 1.0
    nx, ny = nx / ln, ny / ln
    for k in range(n + 1):
        u = k / n
        x, y = x0 + (x1 - x0) * u, y0 + (y1 - y0) * u
        for o in range(thick):
            ix = int(math.floor(x + nx * o * 0.9 + X0))
            iy = int(math.floor(y + ny * o * 0.9 + CY))
            if 1 <= ix < W - 1 and 1 <= iy < H - 1:
                C.rgb[iy, ix] = col
                C.a[iy, ix] = al


def frame_D(f):
    t = f / FPS
    C = Canvas()
    # kıvılcımlar (başın arkasında kalmasın diye önce)
    K = 22
    sp = []
    for i in range(K):
        life = 0.46 + 0.16 * h01(i, 5)
        age = (t - i * T / K) % T
        if age >= life:
            continue
        sp.append((age / life, i))
    sp.sort(reverse=True)
    for a, i in sp:
        th = (h01(i, 6) - 0.5) * 2 * 0.47
        u0 = 12 + 16 * h01(i, 7)
        D = 85 + 60 * h01(i, 8)
        dist = u0 + D * (1 - (1 - a) ** 1.7)
        ln = 12.0 - 8.0 * a
        bx, by = dist * math.cos(th), dist * math.sin(th) + (h01(i, 9) - 0.5) * 4
        tx, ty = bx - ln * math.cos(th), by - ln * math.sin(th)
        col = LIT if a < 0.35 else ORG if a < 0.6 else RED if a < 0.85 else DEEP
        al = 1.0 if a < 0.6 else 0.8 if a < 0.85 else 0.6
        put_line(C, tx, ty, bx, by, col, al, 2 if a < 0.6 else 1)
    # baş: kısa, dolgun, renkli dış hatlı (sel-out) alev
    m, d, s = tongue(t, 0, 0, 0.0, 46, 6.0, 2.0, 24, 0.0, lobe=0.25)
    m2, d2, s2 = tongue(t, 16, 0, 0.45, 22, 3.0, 1.5, 14, 2.0, lobe=0.3)
    m3, d3, s3 = tongue(t, 16, 0, -0.45, 22, 3.0, 1.5, 14, 4.0, lobe=0.3)
    inside = m | m2 | m3
    dd = np.maximum(np.maximum(d, d2), d3)
    ring = grow4(inside) & ~inside
    C.put(ring, DEEP, 0.9)           # renkli dış hat (koyu kırmızı, bordo değil)
    C.put(inside, RED, 1.0)
    C.put(inside & (dd > 1.8), ORG, 1.0)
    C.put(inside & (dd > 4.0) & (s < 0.55), LIT, 1.0)
    return C.image()


DESIGNS = {
    "A": ("Sakin Nefes", frame_A),
    "B": ("Alev Topları", frame_B),
    "C": ("Alev Dalgası", frame_C),
    "D": ("Kor Yelpazesi", frame_D),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    prev_rows = []
    for code, (name, fn) in DESIGNS.items():
        frames = [fn(f) for f in range(NF)]
        sheet = Image.new("RGBA", (W * NF, H))
        for i, im in enumerate(frames):
            a = np.array(im)[:, :, 3]
            edge = a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()
            if edge:
                print("UYARI kenara değiyor:", code, i)
            sheet.paste(im, (i * W, 0))
        sheet.save(os.path.join(OUT, code + ".png"))
        cover = np.mean([(np.array(im)[:, :, 3] > 0).mean() for im in frames])
        meta = {"name": name, "w": W, "h": H, "frames": NF, "fps": FPS, "x0": X0, "cy": CY, "world_px": WORLD_PX}
        with open(os.path.join(OUT, code + ".json"), "w", encoding="utf-8") as fh:
            json.dump(meta, fh, ensure_ascii=False)
        print(code, name, "kaplama %.3f" % cover)
        # önizleme satırı: 4 kare x3 çimen renginde
        row = Image.new("RGBA", (W * 4 * 3, H * 3), (74, 120, 60, 255))
        for j, fi in enumerate((0, 6, 12, 18)):
            row.alpha_composite(frames[fi].resize((W * 3, H * 3), Image.NEAREST), (j * W * 3, 0))
        prev_rows.append(row)
    pv = Image.new("RGBA", (prev_rows[0].width, sum(r.height for r in prev_rows)))
    y = 0
    for r in prev_rows:
        pv.paste(r, (0, y))
        y += r.height
    pv.save(os.path.join(HERE, "out", "ates_alev", "sanat_onizleme.png"))


if __name__ == "__main__":
    main()
