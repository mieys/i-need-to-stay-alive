"""Sovalye E "Koruma Bariyeri" - A "Donen Kalkanlar" BUYU turu: A5-A8 (oyuna bagli DEGIL).

Kullanici (A1-A4 icin): "ilk hali hala daha iyi, yeni yaptiklarin buyuye benzemiyor, dumduz simge donuyor gibi sikici ve ruhsuz."
Teshis: A'yi buyu gibi gosteren yari saydam mavi-mor ISIK rengiydi. A1-A4 kalkani koyu dis hatli KATI METAL plakaya cevirdi ve kalkan
sabit bir ikon gibi donuyordu: isik yaymiyor, iz birakmiyor, nefes almiyor, cevresine hicbir sey yapmiyor.
Bu turda A'nin KENDI kalkani (9x11 sablon, ayni palet, ayni yorunge) korunur, ustune BUYU DILI eklenir (dither yok, alfa basamakli):
  - 2 basamakli HALE (kalkan isik sacar), kalkan rengi NEFES alir (acik tonlara cikip iner), hac parlar,
  - kenardan bakinca kalkan "sise" degil ISIK CIZGISI (beyaz cekirdek),
  - tam tur dongu: 90 kare / 20 fps (4,5 sn tur) -> uc kalkan birbirinden BAGIMSIZ titresir/zerre doker,
  - acilis: merkezde 4 kollu yildiz parlamasi + kalkanlar izleriyle sarmal acilir; kapanis kodda (bariyer_variant.gd).
Secenekler:
  A5 Isik Kuyrugu : kuyruklu yildiz gibi incelen isik izi + izden dokulup suzulen pariltilar + kalkanin yere dusen isigi.
  A6 Ruh Alevi    : kalkan mor-mavi ruh atesinden: ustten titreyen alev dilleri, alevli iz, yukselen korlar.
  A7 Yildiz Tozu  : kalkanlarin yorungesinde 2 kat hizla donen, goz kirpan yildiz tozu kusagi.
  A8 Koruma Nabzi : ayaktan disa yayilan koruma dalgasi (1,5 sn'de bir), dalga gectikce kalkan parlar + yerde isik halkasi.

Calistir: python -I tools/proto_20261111/sovalye_bariyer/kalkan_buyu_proto.py -> out/sheets/a5..a8_back|front.png + meta.json
          (+ out/sheets/onizleme_buyu.png)
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bariyer_proto as BP  # noqa: E402

OUT = BP.OUT
W = H = 72
OX, OY = 36, 36
FEET_Y = OY + 18
ORBIT_CY = OY + 3        # A ile ayni: govde ortasinin 3 px alti
RX, RY = 22, 7
N_IN, N_LOOP, FPS = 8, 90, 20      # dongu = tam tur (4,5 sn)

B_DEEP, B_INDIGO, B_BLUE, B_LAV, B_PALE, B_WHITE = BP.B_DEEP, BP.B_INDIGO, BP.B_BLUE, BP.B_LAV, BP.B_PALE, BP.B_WHITE
SHIELD = BP.SHIELD
PAL_FRONT = {"o": B_DEEP, "H": B_LAV, "W": B_WHITE, "L": B_BLUE}
PAL_FRONT_LIT = {"o": B_INDIGO, "H": B_PALE, "W": B_WHITE, "L": B_LAV}      # nefesin tepesi / dalga gecisi
## Arkaya donen kalkan da ISIK: koyu dolu kapsul yerine mavi govde + arkadan soluk gorunen hac (A'nin en "ikon" duran yeriydi).
PAL_BACK = {"o": B_INDIGO, "H": B_BLUE, "W": B_LAV, "L": B_BLUE}
PAL_BACK_LIT = {"o": B_INDIGO, "H": B_LAV, "W": B_PALE, "L": B_LAV}


def put(img, x, y, col, a, over=False):
    BP.put(img, x, y, col, a, over)


def rnd(x):
    return int(math.floor(x + 0.5))


def ease_out(t):
    return 1 - (1 - t) ** 3


# ------------------------------------------------------------------ kalkan + hale
def shield_cells(phi, lit):
    """{(dx, dy): renk} - A'nin sablonu, bakisa gore daralir; kenardan isik cizgisi."""
    front = math.sin(phi) > 0
    facing = abs(math.sin(phi))
    sw = len(SHIELD[0])
    w = max(3, rnd(sw * (0.35 + 0.65 * facing)))
    if front:
        pal = PAL_FRONT_LIT if lit else PAL_FRONT
    else:
        pal = PAL_BACK_LIT if lit else PAL_BACK
    x0 = rnd(-w / 2)
    y0 = -len(SHIELD) // 2
    cells = {}
    for r, row in enumerate(SHIELD):
        for i in range(w):
            ch = row[min(sw - 1, int((i + 0.5) * sw / w))]
            if ch == ".":
                continue
            col = pal[ch]
            if w <= 4 and ch != "o":
                # kenardan bakis: isik cizgisi (orta sutun beyaz cekirdek)
                col = (B_WHITE if i == w // 2 else B_PALE) if front else (B_LAV if i == w // 2 else B_BLUE)
            cells[(x0 + i, y0 + r)] = col
    return cells


def ring_of(cells, n_steps):
    """Hucre kumesinin disina 4 komsulu 1 px halkalar: [halka1, halka2, ...]."""
    taken = set(cells)
    rings = []
    cur = set(cells)
    for _ in range(n_steps):
        nxt = set()
        for (x, y) in cur:
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (x + ox, y + oy)
                if k not in taken:
                    nxt.add(k)
        taken |= nxt
        rings.append(nxt)
        cur = nxt
    return rings


def draw_shield(img, cx, cy, phi, lit, halo_a, a_mul=1.0, cells=None):
    """Kalkan + nefes alan HALE: ic halka acik (kalkan isik sacar), dis halka mor; parlarken 3. halka (hale buyur)."""
    ix, iy = rnd(cx), rnd(cy)
    if cells is None:
        cells = shield_cells(phi, lit)
    front = math.sin(phi) > 0
    r1, r2, r3 = ring_of(cells, 3)
    strong = halo_a >= 0.8
    if front:
        rings = [(r1, B_WHITE if lit else B_PALE, 0.8 if strong else 0.55), (r2, B_LAV, 0.55 if strong else 0.3)]
        if lit:
            rings.append((r3, B_LAV, 0.3))
    else:
        rings = [(r1, B_LAV, 0.55 if strong else 0.3)]
    for ring, col, a in reversed(rings):
        for (x, y) in ring:
            put(img, ix + x, iy + y, col, a * a_mul, over=True)
    for (x, y), col in cells.items():
        put(img, ix + x, iy + y, col, a_mul, over=True)
    return cells


def star4(img, x, y, size, a, core=B_WHITE, arm=B_PALE, tip=B_LAV):
    """4 kollu yildiz: cekirdek + kollar (uzunluk size)."""
    x, y = rnd(x), rnd(y)
    put(img, x, y, core, a, over=True)
    for k in range(1, size + 1):
        col = arm if k < size else tip
        aa = a if k < size else a * 0.55
        for ox, oy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            put(img, x + ox, y + oy, col, aa, over=True)


# ------------------------------------------------------------------ yorunge
def shield_phi(s, t, spin=0.0):
    return 2 * math.pi * t + s * 2 * math.pi / 3 + spin


def orbit_pt(phi, rad=1.0, lift=0.0):
    return OX + RX * rad * math.cos(phi), ORBIT_CY + RY * rad * math.sin(phi) - lift


def layer_for(back, front, phi):
    return front if math.sin(phi) > 0 else back


def comet_trail(back, front, phi, rad, length_deg, a_mul, wavy=0.0, t=0.0, flame=False):
    """Kalkanin arkasinda yorunge boyunca incelen kuyruklu yildiz izi: beyaz bas 3 px -> mor kuyruk 1 px."""
    step = math.radians(2.0)
    n = int(length_deg / 2.0)
    ## bas kalkanin arka kenarindan baslar (kalin bas kalkanin altinda kaybolmasin): kalkanin yarim genisligi kadar aci
    w_half = (4.5 * (0.35 + 0.65 * abs(math.sin(phi))) + 1.5) / max(4.0, RX * rad * abs(math.sin(phi)) + RY * rad * abs(math.cos(phi)))
    j0 = int(w_half / step)
    for j in range(0, n):
        u = j / n                       # 0 bas -> 1 kuyruk
        p = phi - w_half - j * step
        x, y = orbit_pt(p, rad)
        if wavy:
            y += wavy * math.sin(2 * math.pi * (9 * t) - j * 0.45)
        thick = 3 if u < 0.5 else 2 if u < 0.8 else 1
        if u < 0.2:
            col, side, a = B_WHITE, B_PALE, 1.0
        elif u < 0.45:
            col, side, a = B_PALE, B_LAV, 0.8
        elif u < 0.75:
            col, side, a = B_LAV, B_BLUE, 0.55
        else:
            col, side, a = B_BLUE, B_BLUE, 0.3
        if flame and u < 0.45:
            side = B_LAV
        img = layer_for(back, front, p)
        xi, yi = rnd(x), rnd(y)
        put(img, xi, yi, col, a * a_mul, over=True)
        if thick >= 2:
            put(img, xi, yi + 1, side, max(0.3, a - 0.25) * a_mul)
        if thick >= 3:
            put(img, xi, yi - 1, side, max(0.3, a - 0.25) * a_mul)


def ground_light(back, phi, rad, a_mul, big=False):
    """Kalkanin yere dusen isigi (golge yerine): disi mor, ici acik."""
    gx, gy = OX + RX * rad * math.cos(phi), FEET_Y + RY * rad * math.sin(phi) + 1
    ix, iy = rnd(gx), rnd(gy)
    hw = 5 if big else 4
    for dx in range(-hw, hw + 1):
        put(back, ix + dx, iy, B_LAV, 0.55 * a_mul)
    for dx in range(-hw + 1, hw):
        put(back, ix + dx, iy + 1, B_LAV, 0.3 * a_mul)
        put(back, ix + dx, iy - 1, B_LAV, 0.3 * a_mul)
    for dx in range(-2, 3):
        put(back, ix + dx, iy, B_PALE, 0.8 * a_mul, over=True)
    put(back, ix, iy, B_WHITE, 0.8 * a_mul, over=True)


def ground_ring(back, a, rx=16, ry=5):
    for x, y, _ in BP.ellipse_cells(OX, FEET_Y, rx, ry):
        put(back, x, y, B_LAV, a)


# ------------------------------------------------------------------ parcaciklar (dongu icinde dikissiz: dogum zamani dongu kesri)
class Mote:
    def __init__(self, s, tb, life, rng):
        self.s, self.tb, self.life = s, tb, life      # life: dongu kesri
        self.dx = rng.uniform(-3.5, 3.5)
        self.dy = rng.uniform(-4, 4)
        self.drift = rng.uniform(-2, 2)
        self.kind = rng.random()


def make_motes(per_shield, life, seed):
    rng = random.Random(seed)
    out = []
    for s in range(3):
        for e in range(per_shield):
            out.append(Mote(s, (e + rng.uniform(0, 0.6)) / per_shield, life, rng))
    return out


def mote_age(m, t):
    a = (t - m.tb) % 1.0
    return a / m.life if a < m.life else None


# ------------------------------------------------------------------ secenekler
MOTES_A5 = make_motes(9, 0.11, 5)
MOTES_A6 = make_motes(14, 0.09, 6)
EMBER_TONGUE_SEED = [random.Random(60 + s).uniform(0, 6.28) for s in range(3)]


def breath(s, t, cycles=3):
    """0..1 nefes, kalkan basina faz kaymasi; dongude tam sayi devir -> dikissiz."""
    return 0.5 + 0.5 * math.sin(2 * math.pi * cycles * t + s * 2.1)


A5_TRAIL_DEG = 56   ## kullanici: "izi biraz kis" (84 -> 56); yerdeki isik lekeleri A5'ten kaldirildi


def draw_a5(back, front, t, rad, a_mul, intro):
    for s in range(3):
        comet_trail(back, front, shield_phi(s, t, intro), rad, A5_TRAIL_DEG, a_mul)
    # izden dokulup asagi suzulen pariltilar
    if not intro:
        for m in MOTES_A5:
            age = mote_age(m, t)
            if age is None:
                continue
            phi_b = shield_phi(m.s, m.tb)
            x, y = orbit_pt(phi_b, rad)
            x += m.dx * 0.4 + m.drift * age
            y += m.dy * 0.4 + 9 * age
            img = layer_for(back, front, phi_b)
            if age < 0.3:
                star4(img, x, y, 1, 0.8 * a_mul)
            elif age < 0.65:
                put(img, rnd(x), rnd(y), B_PALE, 0.8 * a_mul, over=True)
            else:
                put(img, rnd(x), rnd(y), B_LAV, 0.55 * a_mul, over=True)
    for s in sorted(range(3), key=lambda k: math.sin(shield_phi(k, t, intro))):
        phi = shield_phi(s, t, intro)
        x, y = orbit_pt(phi, rad)
        b = breath(s, t)
        draw_shield(layer_for(back, front, phi), x, y + round(math.sin(2 * math.pi * 2 * t + s * 2.1)), phi,
                    b > 0.7, 0.8 if b > 0.5 else 0.55, a_mul)


def flame_cells(phi, s, t):
    """Ruh alevi kalkani: sablonun ustune titreyen alev dilleri + ic sicak cekirdek."""
    cells = shield_cells(phi, False)
    front = math.sin(phi) > 0
    if not cells:
        return cells
    xs = sorted({x for x, _ in cells})
    top = {x: min(y for (xx, y) in cells if xx == x) for x in xs}
    out = dict(cells)
    # ic: alt-orta cekirdek acik (ates icten yanar)
    for (x, y), col in cells.items():
        if col in (B_DEEP,):
            out[(x, y)] = B_INDIGO if front else B_DEEP
        elif front and y >= 1 and abs(x) <= 1:
            out[(x, y)] = B_PALE
    # alev dilleri: her sutunda tepe ustune 0-4 px, zamanla titrer (tam sayi devir)
    for x in xs:
        if x in (xs[0], xs[-1]):
            continue
        ph = EMBER_TONGUE_SEED[s] + x * 1.7
        h = 2.6 + 1.6 * math.sin(2 * math.pi * 7 * t + ph) + 1.1 * math.sin(2 * math.pi * 11 * t + ph * 2.3)
        h = max(0, rnd(h))
        if abs(x) <= 1:
            h += 1
        for k in range(1, h + 1):
            u = k / max(1, h)
            col = (B_WHITE if u < 0.3 else B_PALE if u < 0.6 else B_LAV) if front else (B_LAV if u < 0.5 else B_BLUE)
            out[(x, top[x] - k)] = col
    return out


def draw_a6(back, front, t, rad, a_mul, intro):
    for s in range(3):
        phi = shield_phi(s, t, intro)
        ground_light(back, phi, rad, a_mul)
    for s in range(3):
        comet_trail(back, front, shield_phi(s, t, intro), rad, 56, a_mul, wavy=1.2, t=t, flame=True)
    # yukselen korlar
    if not intro:
        for m in MOTES_A6:
            age = mote_age(m, t)
            if age is None:
                continue
            phi_b = shield_phi(m.s, m.tb)
            x, y = orbit_pt(phi_b, rad)
            x += m.dx * 0.6 + m.drift * age + math.sin(age * 9 + m.dx) * 0.8
            y += -6 - 16 * age
            img = layer_for(back, front, phi_b)
            if age < 0.25:
                star4(img, x, y, 1, a_mul)
            else:
                col = B_PALE if age < 0.55 else B_LAV
                put(img, rnd(x), rnd(y), col, (0.8 if age < 0.7 else 0.55) * a_mul, over=True)
                put(img, rnd(x), rnd(y) + 1, B_LAV, 0.3 * a_mul)
    for s in sorted(range(3), key=lambda k: math.sin(shield_phi(k, t, intro))):
        phi = shield_phi(s, t, intro)
        x, y = orbit_pt(phi, rad)
        cells = flame_cells(phi, s, t)
        b = breath(s, t, 5)
        draw_shield(layer_for(back, front, phi), x, y, phi, False, 0.8 if b > 0.5 else 0.55, a_mul, cells=cells)


DUST = []
_rng = random.Random(7)
for _k in range(18):
    _a = _rng.uniform(0, 2 * math.pi / 3)
    _dr = _rng.uniform(-3.5, 3.5)
    _dh = _rng.uniform(-4, 4)
    _tw = _rng.choice([2, 3, 4, 5])
    _ph = _rng.uniform(0, 6.28)
    for _c in range(3):      # 3 katli simetri
        DUST.append((_a + _c * 2 * math.pi / 3, _dr, _dh, _tw, _ph + _c * 1.3))


def draw_a7(back, front, t, rad, a_mul, intro):
    ground_ring(back, 0.3 * a_mul, 17, 5)
    for s in range(3):
        ground_light(back, shield_phi(s, t, intro), rad, a_mul)
    rot = 2 * math.pi * 2 * t + (intro * 1.5 if intro else 0)    # tozu kalkanlardan 2 kat hizli
    for a0, dr, dh, tw, ph in DUST:
        ang = a0 + rot
        x = OX + (RX + dr) * rad * math.cos(ang)
        y = ORBIT_CY + (RY + dr * 0.3) * rad * math.sin(ang) + dh
        k = 0.5 + 0.5 * math.sin(2 * math.pi * tw * t + ph)
        img = layer_for(back, front, ang)
        if k > 0.93:
            star4(img, x, y, 2, 0.8 * a_mul)
        elif k > 0.75:
            star4(img, x, y, 1, 0.8 * a_mul)
        elif k > 0.35:
            put(img, rnd(x), rnd(y), B_PALE, 0.8 * a_mul, over=True)
        else:
            put(img, rnd(x), rnd(y), B_LAV, 0.55 * a_mul)
    for s in sorted(range(3), key=lambda k2: math.sin(shield_phi(k2, t, intro))):
        phi = shield_phi(s, t, intro)
        x, y = orbit_pt(phi, rad)
        b = breath(s, t, 4)
        draw_shield(layer_for(back, front, phi), x, y + round(math.sin(2 * math.pi * 2 * t + s * 2.1)), phi,
                    b > 0.75, 0.8 if b > 0.5 else 0.55, a_mul)


WAVES = 3          # dongude 3 dalga (1,5 sn'de bir)


def draw_a8(back, front, t, rad, a_mul, intro):
    ground_ring(back, 0.55 * a_mul, 16, 5)
    # yayilan koruma dalgasi: ayaktan disa, yer elipsi
    wave_r = None
    if not intro:
        wt = (t * WAVES) % 1.0
        wave_r = 6 + 30 * ease_out(min(1.0, wt / 0.7))
        if wt < 0.7:
            wa = 0.8 if wt < 0.3 else 0.55 if wt < 0.5 else 0.3
            rx = rnd(wave_r)
            ry = max(2, rnd(wave_r * 0.32))
            for x, y, ang in BP.ellipse_cells(OX, FEET_Y, rx, ry):
                put(back, x, y, B_PALE if wt < 0.3 else B_LAV, wa * a_mul, over=True)
            if wt < 0.45:
                for x, y, ang in BP.ellipse_cells(OX, FEET_Y, max(2, rx - 1), max(1, ry - 1)):
                    put(back, x, y, B_LAV, 0.3 * a_mul)
            # dalganin govdeye cikan yuzu: on yarisi govdenin onunde (ayaklara binen ince yay)
        else:
            wave_r = None
    for s in range(3):
        ground_light(back, shield_phi(s, t, intro), rad, a_mul, big=True)
    for s in range(3):
        comet_trail(back, front, shield_phi(s, t, intro), rad, 30, a_mul)
    for s in sorted(range(3), key=lambda k2: math.sin(shield_phi(k2, t, intro))):
        phi = shield_phi(s, t, intro)
        x, y = orbit_pt(phi, rad)
        hit = wave_r is not None and abs(wave_r - RX) < 4.5
        cells = draw_shield(layer_for(back, front, phi), x, y, phi, hit, 0.8 if hit else 0.55, a_mul)
        if hit and math.sin(phi) > -0.3:
            star4(layer_for(back, front, phi), x, y - 1, 2, 0.8 * a_mul)


VARIANTS = {"a5": draw_a5, "a6": draw_a6, "a7": draw_a7, "a8": draw_a8}


def frame(v, kind, i):
    back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    front = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if kind == "in":
        k = (i + 1) / N_IN
        e = ease_out(k)
        rad = 0.12 + 0.88 * e
        spin = -(1 - e) * math.pi * 1.1
        t = (i - N_IN) / N_LOOP
        a_mul = 0.55 if i == 0 else 1.0
        # merkezde yildiz parlamasi (ilk 5 kare), govdenin onunde
        if i < 5:
            size = [2, 4, 5, 4, 2][i]
            star4(front, OX, OY - 2, size, [1.0, 1.0, 0.8, 0.55, 0.3][i])
        VARIANTS[v](back, front, t, rad, a_mul, spin if spin != 0 else 1e-6)
    else:
        VARIANTS[v](back, front, i / N_LOOP, 1.0, 1.0, 0.0)
    return back, front


def main():
    meta_path = OUT / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    for v in VARIANTS:
        backs, fronts = [], []
        for i in range(N_IN):
            b, f = frame(v, "in", i)
            backs.append(b)
            fronts.append(f)
        for i in range(N_LOOP):
            b, f = frame(v, "loop", i)
            backs.append(b)
            fronts.append(f)
        for name, frames in (("back", backs), ("front", fronts)):
            s = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
            for j, fr in enumerate(frames):
                s.paste(fr, (j * W, 0))
            s.save(OUT / f"{v}_{name}.png")
        meta[v] = {"w": W, "h": H, "ox": OX, "oy": OY, "in": N_IN, "loop": N_LOOP, "out": 0, "fps": FPS}
        print(v, "tamam")
    meta_path.write_text(json.dumps(meta, indent=1), encoding="utf-8")
    picks = [2, N_IN + 5, N_IN + 20, N_IN + 37, N_IN + 61]
    sc = 4
    prev = Image.new("RGBA", (len(picks) * W * sc, len(VARIANTS) * H * sc), (126, 176, 84, 255))
    for r, v in enumerate(VARIANTS):
        bs = Image.open(OUT / f"{v}_back.png")
        fs = Image.open(OUT / f"{v}_front.png")
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
    prev.save(OUT / "onizleme_buyu.png")
    print("onizleme", OUT / "onizleme_buyu.png")


if __name__ == "__main__":
    main()
