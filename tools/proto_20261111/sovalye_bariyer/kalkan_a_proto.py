"""Sovalye E "Koruma Bariyeri" - A "Donen Kalkanlar" KALITE turu: A1-A4 (oyuna bagli DEGIL).

Kullanici: "A guzel ancak daha kaliteli olabilir."
A'nin (bariyer_proto.py draw_a) teshisi: kalkan duz 3 renkli sablon, yandan bakinca sablon sutunlari seyreltildigi icin "sise"
gibi daraliyor (kalinlik yok), 12 fps / 18 kare (kare basi 6,7 derece - kesik kesik), iz noktali cizgi, golge yok (havada durdugu
anlasilmiyor), acilis/kapanis yalniz yaricap + alfa.

Bu turda HEPSINDE:
  - Kalkan GERCEK 3B: hafif bombeli haclı kalkan (genislik 11, boy 12, kalinlik 2 sanat px) her karede z-tamponla piksel
    izgarasina cizilir (ceyrek piksel ornek, en yakin ornegin rengi - kenar yumusatma yok), yandan bakinca kalinligi gorunur,
    arkadan bakinca kayisli sirti; sol ust isikla bombe golgelemesi (3-4 ton); 1 px yuz kenari (ust/sol acik, alt/sag koyu) +
    1 px koyu dis hat. Bicim yalniz aciya bagli (merkez tam sayiya yuvarlanir -> titreme yok).
  - Akici donus: 30 kare / 20 fps (kare basi 4 derece), 120 derece simetriyle dikissiz.
  - Kalkan one gelirken yuzunden capraz bir parilti gecer.
  - Her kalkanin altinda yerde tek ton golge (havada durdugu okunur), hafif suzulme (+-1 px, ucu birlikte).
  - Acilis: merkezden beyaz siluet olarak sarmal cikip renge doner. Kapanis kodda (aci bagimsiz): kisa parlama + alfa basamaklari.
Secenekler (malzeme / bariyer okunusu):
  A1 Celik Kalkan : celik kenar + kraliyet mavisi alan + gumus hac, ince iz.
  A2 Isik Kalkani : yari saydam isik kalkan (parlak kenar + beyaz hac + 1 px isik halesi), isik kurdelesi iz + birakilan
                    pariltilar, yerde golge yerine isik lekesi.
  A3 Altin Hac    : A1 + altin kenar ve hac (kutsal sovalye).
  A4 Kalkan Cemberi: A1 kalkanlari bel hizasinda isik cemberine dizili (on yarisi onde, arkasi arkada) + cemberde kayan isik.

Calistir: python -I tools/proto_20261111/sovalye_bariyer/kalkan_a_proto.py -> out/sheets/a1..a4_back|front.png + meta.json
          (+ out/sheets/onizleme_a.png)
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bariyer_proto as BP  # noqa: E402

OUT = BP.OUT
W = H = 72
OX, OY = 36, 36          # govde ortasi
FEET_Y = OY + 18         # ayak
N_IN, N_LOOP, FPS = 8, 30, 20

RX, RY = 23, 7
TV = math.asin(RY / RX)  # bakis egimi (yorunge elipsinden)
COS_TV, SIN_TV = math.cos(TV), math.sin(TV)
LIFT = 14                # kalkan merkezi ayak duzleminin bu kadar ustunde (ekran px)
ORBIT_CY = FEET_Y - LIFT
SW, SH, ST = 11.0, 12.0, 2.0
BULGE = 1.1
STEP = 0.25
## Alan tonu isiktan bu kadar koyu: one bakan kalkanin alani kraliyet mavisi kalsin, hac/kenar parlasin.
FIELD_SHIFT = 0.32


def norm3(x, y, z):
    m = math.sqrt(x * x + y * y + z * z)
    return (x / m, y / m, z / m)


LIGHT = norm3(-0.55, 0.65, 0.55)   # sol ust on
UP = (0.0, 1.0, 0.0)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def add3(*vs):
    return tuple(sum(v[i] for v in vs) for i in range(3))


def mul3(v, s):
    return (v[0] * s, v[1] * s, v[2] * s)


def half_w(v):
    if v < 0.07:
        return 0.82
    if v <= 0.5:
        return 1.0
    return max(0.0, 1.0 - ((v - 0.5) / 0.5) ** 1.7)


def in_shape(a, v):
    return 0.0 <= v <= 1.0 and abs(a) <= half_w(v) + 1e-9


def is_cross(a, v):
    return (abs(a) < 0.09 and 0.12 < v < 0.84) or (abs(v - 0.34) < 0.045 and abs(a) < 0.66)


_CACHE = {}


def zbuffer(phi, scale):
    """Kalkani z-tamponla izgaraya dok: {(dx, dy): (derinlik, tur, a, v, normal)} - kalkan merkezine gore tam sayi."""
    key = (round(phi % (2 * math.pi), 6), round(scale, 4))
    if key in _CACHE:
        return _CACHE[key]
    n = (math.cos(phi), 0.0, math.sin(phi))
    t = (-math.sin(phi), 0.0, math.cos(phi))
    sw, sh, st = SW * scale, SH * scale, ST * scale
    buf = {}
    hits = {}   ## piksel -> [on yuz ornegi, hac ornegi]: ince hac her acida ayni piksellerde kalsin (en yakin ornek tek basina kaciriyordu)

    def put_sample(P, kind, a, v, nrm):
        sx = P[0]
        sy = -P[1] * COS_TV + P[2] * SIN_TV
        d = P[1] * SIN_TV + P[2] * COS_TV
        k = (math.floor(sx + 0.5), math.floor(sy + 0.5))
        if kind in ("front", "cross"):
            h = hits.setdefault(k, [0, 0])
            h[0] += 1
            h[1] += 1 if is_cross(a, v) else 0
        old = buf.get(k)
        if old is None or d > old[0]:
            buf[k] = (d, kind, a, v, nrm)

    na = max(4, int(sw / STEP))
    nv = max(4, int(sh / STEP))
    for i in range(na + 1):
        a = -1.0 + 2.0 * i / na
        for j in range(nv + 1):
            v = j / nv
            if not in_shape(a, v):
                continue
            s = a * sw / 2
            yy = (0.5 - v) * sh
            b = BULGE * scale * (1 - a * a)
            ang = a * 0.65
            nl = add3(mul3(n, math.cos(ang)), mul3(t, math.sin(ang)))
            base = add3(mul3(t, s), mul3(UP, yy))
            put_sample(add3(base, mul3(n, st / 2 + b)), "front", a, v, nl)
            put_sample(add3(base, mul3(n, -st / 2 + b)), "back", a, v, mul3(nl, -1))
    # yan yuzeyler (kalinlik): kenar boyunca n yonunde
    nk = max(2, int(st / STEP))
    edge = []
    for j in range(nv + 1):
        v = j / nv
        hw = half_w(v)
        edge.append((-hw, v, mul3(t, -1)))
        edge.append((hw, v, t))
    for i in range(na + 1):
        a = -0.82 + 1.64 * i / na
        edge.append((a, 0.0, UP))
    for a, v, en in edge:
        s = a * sw / 2
        yy = (0.5 - v) * sh
        b = BULGE * scale * (1 - a * a)
        base = add3(mul3(t, s), mul3(UP, yy))
        for k in range(nk + 1):
            put_sample(add3(base, mul3(n, -st / 2 + st * k / nk + b)), "side", a, v, en)
    for k, (h_all, h_cross) in hits.items():
        if k in buf and buf[k][1] == "front":
            d, kind, a, v, nrm = buf[k]
            buf[k] = (d, "cross" if h_cross >= 0.28 * h_all else "front", a, v, nrm)
    _CACHE[key] = buf
    return buf


# ------------------------------------------------------------------ malzemeler
STEEL = {
    "field": [(34, 38, 104), (54, 70, 170), (84, 110, 226), (128, 156, 255)],
    "cross": [(150, 156, 196), (206, 212, 240), (244, 246, 255)],
    "rim_lo": (112, 116, 156), "rim_hi": (226, 230, 246),
    "side": [(84, 88, 128), (140, 146, 182), (196, 200, 226)],
    "back": [(38, 40, 68), (58, 60, 94), (82, 86, 122)], "strap": (96, 66, 58),
    "outline": (24, 20, 52), "glint": (255, 255, 255),
}
GOLD = dict(STEEL)
GOLD.update({
    "cross": [(176, 116, 40), (236, 186, 80), (255, 232, 150)],
    "rim_lo": (164, 104, 34), "rim_hi": (255, 226, 140),
    "side": [(130, 82, 28), (204, 146, 58), (246, 206, 112)],
    "outline": (34, 20, 30), "glint": (255, 250, 220),
})
LIGHTM = {
    "field": [(44, 40, 128), (78, 82, 214), (112, 142, 255), (170, 140, 255)],
    "cross": [(242, 244, 255), (242, 244, 255), (255, 255, 255)],
    "rim_lo": (206, 216, 255), "rim_hi": (255, 255, 255),
    "side": [(170, 140, 255), (206, 216, 255), (242, 244, 255)],
    "back": [(78, 82, 214), (112, 142, 255), (170, 140, 255)], "strap": (112, 142, 255),
    "outline": (170, 140, 255), "glint": (255, 255, 255),
}
STYLE = {"a1": STEEL, "a2": LIGHTM, "a3": GOLD, "a4": STEEL}
ALPHA = {  # (alan, hac/kenar, yan, sirt, dis hat) - isik kalkani yari saydam, dis hatti hale
    "a2": (0.8, 1.0, 1.0, 0.55, 0.3),
}
DEFAULT_ALPHA = (1.0, 1.0, 1.0, 1.0, 1.0)


def tone(ramp, lam):
    if len(ramp) == 4:
        idx = 3 if lam > 0.5 else 2 if lam > 0.15 else 1 if lam > -0.2 else 0
    else:
        idx = 2 if lam > 0.35 else 1 if lam > -0.1 else 0
    return ramp[idx]


def shield_pixels(phi, scale, style, flash=False):
    """[(dx, dy, renk, alfa)] - z-tamponu malzemeyle boyar, kenar + dis hat + parilti ekler."""
    buf = zbuffer(phi, scale)
    m = STYLE[style]
    a_field, a_cross, a_side, a_back, a_out = ALPHA.get(style, DEFAULT_ALPHA)
    fronts = {k for k, val in buf.items() if val[1] in ("front", "cross")}
    deg = math.degrees(phi) % 360
    glint_c = None
    if 35 <= deg <= 145:
        g = (deg - 35) / 110
        glint_c = 1.6 - 3.2 * g
    px = []
    for (x, y), (d, kind, a, v, nrm) in buf.items():
        lam = dot(nrm, LIGHT)
        if kind in ("front", "cross"):
            miss_hi = (x - 1, y) not in fronts or (x, y - 1) not in fronts
            miss_lo = (x + 1, y) not in fronts or (x, y + 1) not in fronts
            if miss_hi:
                col, al = m["rim_hi"], a_cross
            elif miss_lo:
                col, al = m["rim_lo"], a_cross
            elif kind == "cross":
                col, al = tone(m["cross"], lam + 0.25), a_cross
            elif glint_c is not None and abs(a + (v - 0.5) * 1.1 - glint_c) < 0.09:
                col, al = m["field"][3], a_field   ## parilti: alanin en acik tonu (beyaz bant hacla karisiyordu)
            else:
                col, al = tone(m["field"], lam - FIELD_SHIFT), a_field
        elif kind == "back":
            col, al = tone(m["back"], lam), a_back
            if abs(a) < 0.2 and 0.2 < v < 0.7:
                col = m["strap"]
        else:
            col, al = tone(m["side"], lam), a_side
        if flash:
            col, al = BP.B_WHITE, 1.0
        px.append((x, y, col, al))
    for (x, y) in list(buf.keys()):
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = (x + ox, y + oy)
            if k not in buf:
                px.append((k[0], k[1], BP.B_PALE if flash else m["outline"], 0.55 if flash else a_out))
    return px


def shield_width(phi, scale):
    return SW * scale * abs(math.sin(phi)) + ST * scale * abs(math.cos(phi))


# ------------------------------------------------------------------ kare
def blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def put_shield(img, phi, scale, style, cx, cy, a_mul, flash):
    px = shield_pixels(phi, scale, style, flash)
    ix, iy = int(math.floor(cx + 0.5)), int(math.floor(cy + 0.5))
    n_body = len(zbuffer(phi, scale))
    # dis hat once (govdenin altinda kalsin), govde sonra
    for x, y, col, al in px[n_body:]:
        BP.put(img, ix + x, iy + y, col, al * a_mul, over=True)
    for x, y, col, al in px[:n_body]:
        BP.put(img, ix + x, iy + y, col, al * a_mul, over=True)


def orbit_xy(phi, rad):
    bob = round(math.sin(3 * phi))
    return OX + RX * rad * math.cos(phi), ORBIT_CY + RY * rad * math.sin(phi) + bob


def draw_shadow(back, phi, rad, scale, style, a_mul):
    gx = OX + RX * rad * math.cos(phi)
    gy = FEET_Y + RY * rad * math.sin(phi) + 1
    hw = max(2, int(round(shield_width(phi, scale) / 2)))
    ix, iy = int(math.floor(gx + 0.5)), int(math.floor(gy + 0.5))
    col, al = ((170, 140, 255), 0.3) if style == "a2" else ((10, 16, 12), 0.3)
    for dx in range(-hw + 1, hw):
        BP.put(back, ix + dx, iy, col, al * a_mul, over=True)
    for dx in range(-hw + 2, hw - 1):
        BP.put(back, ix + dx, iy + 1, col, al * a_mul, over=True)


def draw_trail(back, front, phi, rad, style, a_mul):
    if style == "a4":
        return
    n_pts = 14 if style == "a2" else 9
    step = math.radians(3.2)
    prev = None
    for j in range(2, n_pts):
        p = phi - j * step
        x, y = orbit_xy(p, rad)
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))
        if style == "a2":
            col = BP.B_WHITE if j < 5 else BP.B_PALE if j < 9 else BP.B_LAV
            al = 0.8 if j < 5 else 0.55 if j < 9 else 0.3
        else:
            col = BP.B_PALE if j < 5 else BP.B_LAV
            al = 0.55 if j < 5 else 0.3
        img = front if math.sin(p) > 0 else back
        if prev is not None:
            BP.line(img, prev[0], prev[1], x, y, col, al * a_mul)
            if style == "a2":
                BP.line(img, prev[0], prev[1] + 1, x, y + 1, BP.B_LAV, 0.3 * a_mul)
        prev = (x, y)


SPARK_ANGLES = [math.radians(d) for d in (14, 52, 92)]


def draw_sparks(back, front, base, rad, a_mul):
    """A2: kalkanlarin gectigi sabit noktalarda kisa pariltilar (120 derece simetriyle dongude dikissiz)."""
    for k in range(3):
        for sa in SPARK_ANGLES:
            ang = sa + k * 2 * math.pi / 3
            # en yakin arkadan gelen kalkanin bu noktayi gecmesinden beri gecen aci
            since = min(((ang - (base + i * 2 * math.pi / 3)) * -1) % (2 * math.pi) for i in range(3))
            since_deg = math.degrees(since)
            if since_deg > 40:
                continue
            x, y = orbit_xy(ang, rad)
            x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5)) + 3 + int(since_deg // 14)
            img = front if math.sin(ang) > 0 else back
            if since_deg < 14:
                BP.plus(img, x, y, BP.B_WHITE, BP.B_PALE, 0.8 * a_mul)
            elif since_deg < 28:
                BP.put(img, x, y, BP.B_PALE, 0.55 * a_mul, over=True)
            else:
                BP.put(img, x, y, BP.B_LAV, 0.3 * a_mul, over=True)


def draw_ring(back, front, base, rad, a_mul):
    """A4: kalkanlarin dizildigi isik cemberi + kalkan aralarinda kayan isik."""
    rx, ry = int(round(RX * rad)), int(round(RY * rad))
    for x, y, ang in BP.ellipse_cells(OX, ORBIT_CY, rx, ry):
        fr = math.sin(ang) > 0
        # kalkan aralarinda (60 derece ileride) parlak kesit
        dmin = min(abs(((ang - (base + math.pi / 3 + i * 2 * math.pi / 3)) + math.pi) % (2 * math.pi) - math.pi)
                   for i in range(3))
        if dmin < math.radians(7):
            BP.put(front if fr else back, x, y, BP.B_WHITE, 0.8 * a_mul, over=True)
        elif dmin < math.radians(16):
            BP.put(front if fr else back, x, y, BP.B_PALE, 0.55 * a_mul, over=True)
        else:
            BP.put(front if fr else back, x, y, BP.B_PALE if fr else BP.B_LAV, 0.3 * a_mul)
    # cemberin koyu alt hatti (cimen ustunde okunsun)
    for x, y, ang in BP.ellipse_cells(OX, ORBIT_CY + 1, rx, ry):
        if math.sin(ang) > 0.2:
            BP.put(front, x, y, BP.B_DEEP, 0.3 * a_mul)


def ease_out(t):
    return 1 - (1 - t) ** 3


def frame(style, kind, i):
    back, front = blank(), blank()
    if kind == "in":
        k = (i + 1) / N_IN
        e = ease_out(k)
        rad, scale = 0.15 + 0.85 * e, 0.45 + 0.55 * e
        spin = -(1 - e) * math.pi * 0.9
        flash = i < 3
        a_mul = 0.55 if i == 0 else 1.0
        sh_mul = 0.0 if i < 3 else 1.0
        t = (i - N_IN) / N_LOOP
    else:
        rad, scale, spin, flash, a_mul, sh_mul = 1.0, 1.0, 0.0, False, 1.0, 1.0
        t = i / N_LOOP
    base = 2 * math.pi * t / 3 + spin
    phis = [base + s * 2 * math.pi / 3 for s in range(3)]
    if sh_mul > 0:
        for p in phis:
            draw_shadow(back, p, rad, scale, style, a_mul)
    if style == "a4" and not flash:
        draw_ring(back, front, base, rad, a_mul if kind == "loop" else min(1.0, scale))
    if not flash:
        for p in phis:
            draw_trail(back, front, p, rad, style, a_mul)
        if style == "a2" and kind == "loop":
            draw_sparks(back, front, base, rad, a_mul)
    for p in sorted(phis, key=math.sin):
        x, y = orbit_xy(p, rad)
        put_shield(front if math.sin(p) > 0 else back, p, scale, style, x, y, a_mul, flash)
    return back, front


def main():
    meta_path = OUT / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    styles = ["a1", "a2", "a3", "a4"]
    for st in styles:
        backs, fronts = [], []
        for i in range(N_IN):
            b, f = frame(st, "in", i)
            backs.append(b)
            fronts.append(f)
        for i in range(N_LOOP):
            b, f = frame(st, "loop", i)
            backs.append(b)
            fronts.append(f)
        for name, frames in (("back", backs), ("front", fronts)):
            s = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
            for j, fr in enumerate(frames):
                s.paste(fr, (j * W, 0))
            s.save(OUT / f"{st}_{name}.png")
        meta[st] = {"w": W, "h": H, "ox": OX, "oy": OY, "in": N_IN, "loop": N_LOOP, "out": 0, "fps": FPS}
        print(st, "tamam")
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")
    # onizleme: secenek basina acilis karesi + 3 dongu karesi, gri govde kutusu, 4x
    picks = [3, N_IN + 2, N_IN + 9, N_IN + 17]
    sc = 4
    prev = Image.new("RGBA", (len(picks) * W * sc, len(styles) * H * sc), (126, 176, 84, 255))
    for r, st in enumerate(styles):
        bs = Image.open(OUT / f"{st}_back.png")
        fs = Image.open(OUT / f"{st}_front.png")
        for c, fi in enumerate(picks):
            tile = Image.new("RGBA", (W, H), (126, 176, 84, 255))
            body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            for yy in range(OY - 20, FEET_Y):
                for xx in range(OX - 6, OX + 6):
                    body.putpixel((xx, yy), (60, 54, 70, 255))
            tile.alpha_composite(bs.crop((fi * W, 0, fi * W + W, H)))
            tile.alpha_composite(body)
            tile.alpha_composite(fs.crop((fi * W, 0, fi * W + W, H)))
            prev.paste(tile.resize((W * sc, H * sc), Image.NEAREST), (c * W * sc, r * H * sc))
    prev.save(OUT / "onizleme_a.png")
    print("onizleme", OUT / "onizleme_a.png")


if __name__ == "__main__":
    main()
