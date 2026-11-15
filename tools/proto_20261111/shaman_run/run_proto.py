"""Shaman Q/E RUN TASI runleri - PARLAYAN / UCAN prototipleri (madde 568, oyuna bagli DEGIL).

Kullanici (madde 567'den sonra): "runler cok donuk, ucuyormus gibi gorunmuyor, hic parildamiyor ve efektsiz".
Arka plan: gercek cizici (../shaman_mermi/yakala.ps1 -Mode tas: taslar var, RUNLERI ve parlamasi GIZLI; ayni sahne + Shaman).
Runler kullanicinin cizimleri (tools/shaman_rune_stone/kaynak), dongu oyundakiyle ayni (belir 0,5 / parla 1,0 / son 0,6 / 1,5 sn'de bir).
Q tum evrimler (6 run), E iki evrim (3 run). Parilti: kademeli piksel hale (3 halka, dither YOK), az ve iri (2x2) kivilcim.
  A  Parlayan Oyma : run tasta kalir; beyaz-sicak cekirdek + 3 halkali hale + tasin dis kenari parlar + yukselen kivilcim
  B  Suzulen Run   : run tastan yukselip ustunde suzulur (hafif salinim), alttan tasa isik huzmesi, sonerken yukari dagilir
  C  Yorunge       : sahip olunan butun runler tasin cevresinde yavas donen yorungede (arkadakiler tasin ardinda), sirasi gelen parlar
  D  Isik Sutunu   : tastan yukselen isik sutunu, runler sirayla tastan cikip sutunun icinde YUKARI ucar ve tepede soner
Kullanim (repo kokunden): python -I tools/proto_20261111/shaman_run/run_proto.py
Cikti tools/proto_20261111/shaman_run/out/: karsilastirma.gif (SU AN + A-D), run_<A-D>.gif (x2), ozet.png
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
CAP = os.path.join(HERE, "..", "shaman_mermi", "out")
SRC = os.path.join(ROOT, "tools", "shaman_rune_stone", "kaynak")
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")

META = json.load(open(os.path.join(CAP, "yakala_tas", "meta.json"), encoding="utf-8"))
S = META["px_per_world"]
K_ST = META["q_stone_px"]   # ekran px / tas pikseli (0,632 dunya)
K_CH = 0.903 * S            # ekran px / karakter pikseli
FPS = 20
DUR = 6.0
NFR = int(DUR * FPS)
T_IN, T_HOLD, T_OUT = 0.5, 1.0, 0.6
PERIOD = T_IN + T_HOLD
CROP = (330, 30, 800, 222)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


PAL = {
    "q": {"hot": hx("#fff4cf"), "mid": hx("#ffdb75"), "g1": hx("#ff7a2a"), "g2": hx("#e8401e"), "g3": hx("#b02818"),
          "spark": [hx("#fff4cf"), hx("#fa9433"), hx("#d64c1f"), hx("#661a0f")]},
    "e": {"hot": hx("#ffffff"), "mid": hx("#a6d8ff"), "g1": hx("#6cc4ff"), "g2": hx("#3a7ce0"), "g3": hx("#1e4aa0"),
          "spark": [hx("#ffffff"), hx("#a6d8ff"), hx("#4aa8ff"), hx("#1e50b4")]},
}
ROWS = {"q": [0, 4, 1, 3, 2, 5], "e": [0, 1, 2]}  # dongu sirasi (EVO_ROW ile ayni eslesme)
RUNE_FILES = ["0", "1", "2", "3", "4", "f"]
STONE = {k: Image.open(os.path.join(SRC, "%s_tas.png" % k)).convert("RGBA") for k in "qe"}
STONE_C = {"q": tuple(META["q_stone"]), "e": tuple(META["e_stone"])}


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


# ------------------------------------------------------------------ run hazirligi
def dilate(cells, w, h, eight=False):
    out = set(cells)
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1)) + (((1, 1), (1, -1), (-1, 1), (-1, -1)) if eight else ())
    for (x, y) in cells:
        for dx, dy in nb:
            if 0 <= x + dx < w and 0 <= y + dy < h:
                out.add((x + dx, y + dy))
    return out


class Rune:
    """Kullanicinin run cizimi: cekirdek (parlak/golge), oyma golgesi, 3 hale halkasi - hepsi ayri katman (alfa kare kare)."""

    def __init__(self, kind, row, pad=4, crop=True):
        im = Image.open(os.path.join(SRC, "%s_run_%s.png" % (kind, RUNE_FILES[row]))).convert("RGBA")
        px = im.load()
        opaque = {}
        for y in range(32):
            for x in range(32):
                p = px[x, y]
                if p[3] == 255:
                    opaque.setdefault(p[:3], []).append((x, y))
        bright_c = max(opaque, key=lambda c: sum(c))
        bright = set(opaque[bright_c])
        shade = set(c for col, cells in opaque.items() if col != bright_c for c in cells)
        groove = set((x, y) for y in range(32) for x in range(32) if 0 < px[x, y][3] < 255)
        allp = bright | shade
        if crop:
            xs = [c[0] for c in allp]
            ys = [c[1] for c in allp]
            ox, oy = min(xs) - pad, min(ys) - pad
            w, h = max(xs) - min(xs) + 1 + 2 * pad, max(ys) - min(ys) + 1 + 2 * pad
        else:
            ox, oy, w, h = -pad, -pad, 32 + 2 * pad, 32 + 2 * pad
        sh = lambda cells: set((x - ox, y - oy) for (x, y) in cells)
        bright, shade, groove = sh(bright), sh(shade), sh(groove)
        core = bright | shade
        r1 = dilate(core, w, h) - core
        r2 = dilate(core | r1, w, h, True) - core - r1
        r3 = dilate(core | r1 | r2, w, h) - core - r1 - r2
        pal = PAL[kind]
        self.size = (w, h)
        self.offset = (ox, oy)  # 32x32 kareden kirpma kaymasi
        self.layers = {}
        for name, cells, col in (("core_b", bright, pal["hot"]), ("core_s", shade, pal["mid"]), ("groove", groove, (0, 0, 0, 127)),
                                 ("dim_b", bright, pal["g2"]), ("dim_s", shade, pal["g3"]),
                                 ("h1", r1, pal["g1"]), ("h2", r2, pal["g2"]), ("h3", r3, pal["g3"])):
            lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            lp = lay.load()
            for c in cells:
                lp[c] = col
            self.layers[name] = lay
        self._scaled = {}

    def scaled(self, name, k):
        key = (name, round(k, 3))
        if key not in self._scaled:
            lay = self.layers[name]
            self._scaled[key] = lay.resize((max(1, round(lay.width * k)), max(1, round(lay.height * k))), Image.NEAREST)
        return self._scaled[key]


RUNES = {(k, r, crop): None for k in "qe" for r in range(6) for crop in (True, False)}


def rune(kind, row, crop=True):
    key = (kind, row, crop)
    if RUNES.get(key) is None:
        RUNES[key] = Rune(kind, row, crop=crop)
    return RUNES[key]


def paste(fr, im, x, y, alpha=1.0):
    x, y = int(round(x)), int(round(y))
    if alpha <= 0.0:
        return
    if alpha < 1.0:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(fr.width, x + im.width), min(fr.height, y + im.height)
    if x1 <= x0 or y1 <= y0:
        return
    fr.alpha_composite(im.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def draw_rune(fr, kind, row, center, k, vis, glow, crop=True, carved=False, halo=(0.6, 0.32, 0.14), dim=0.0):
    """Runu ekran merkezine (center) k olcekte ciz: vis = gorunurluk 0..1, glow = hale gucu 0..1,
    dim = 0..1 sonuk kor tonu (sirasi gelmeyen run: koyu kirmizi / koyu mavi, hale yok)."""
    r = rune(kind, row, crop)
    w, h = r.size
    x0 = center[0] - w * k / 2
    y0 = center[1] - h * k / 2
    for name, a in (("h3", halo[2]), ("h2", halo[1]), ("h1", halo[0])):
        paste(fr, r.scaled(name, k), x0, y0, a * glow * vis)
    if carved:
        paste(fr, r.scaled("groove", k), x0, y0, vis)
    if dim > 0.0:
        paste(fr, r.scaled("dim_s", k), x0, y0, vis * dim)
        paste(fr, r.scaled("dim_b", k), x0, y0, vis * dim)
    paste(fr, r.scaled("core_s", k), x0, y0, vis * (1.0 - dim))
    paste(fr, r.scaled("core_b", k), x0, y0, vis * (1.0 - dim))


def slot_level(age):
    if age < 0:
        return None
    if age < T_IN:
        return smooth(age / T_IN)
    if age < T_IN + T_HOLD:
        return 1.0
    if age < T_IN + T_HOLD + T_OUT:
        return smooth(1 - (age - T_IN - T_HOLD) / T_OUT)
    return None


def cycle(kind, t):
    """O an gorunen runler: [(satir, seviye, yas)]."""
    rows = ROWS[kind]
    idx = int(t // PERIOD)
    out = []
    for j in (idx - 1, idx):
        if j < 0:
            continue
        age = t - j * PERIOD
        lv = slot_level(age)
        if lv is not None:
            out.append((rows[j % len(rows)], lv, age))
    return out


# ------------------------------------------------------------------ ortak parcalar
_stone_rim = {}


def stone_rim(kind, k):
    """Tasin DISINDA 2 kademeli parlak kenar (ekran olceginde)."""
    key = (kind, round(k, 3))
    if key not in _stone_rim:
        st = STONE[kind]
        mask = set((x, y) for y in range(32) for x in range(32) if st.getpixel((x, y))[3] > 0)
        pad = 3
        m = set((x + pad, y + pad) for (x, y) in mask)
        W = 32 + 2 * pad
        r1 = dilate(m, W, W) - m
        r2 = dilate(m | r1, W, W, True) - m - r1
        pal = PAL[kind]
        img1 = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        img2 = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        for c in r1:
            img1.putpixel(c, pal["g1"])
        for c in r2:
            img2.putpixel(c, pal["g2"])
        _stone_rim[key] = [i.resize((round(W * k), round(W * k)), Image.NEAREST) for i in (img1, img2)]
    return _stone_rim[key]


def draw_stone_rim(fr, kind, a1, a2):
    k = K_ST
    imgs = stone_rim(kind, k)
    c = STONE_C[kind]
    x0 = c[0] - imgs[0].width / 2
    y0 = c[1] - imgs[0].height / 2
    paste(fr, imgs[1], x0, y0, a2)
    paste(fr, imgs[0], x0, y0, a1)


_stone_scaled = {}


def stone_sprite(kind):
    if kind not in _stone_scaled:
        st = STONE[kind]
        _stone_scaled[kind] = st.resize((round(32 * K_ST), round(32 * K_ST)), Image.NEAREST)
    return _stone_scaled[kind]


def draw_stone(fr, kind):
    im = stone_sprite(kind)
    c = STONE_C[kind]
    paste(fr, im, c[0] - im.width / 2, c[1] - im.height / 2)


def stone_top(kind):
    return (STONE_C[kind][0], STONE_C[kind][1] - 15 * K_ST)


def rune_in_stone(kind):
    """Taşın içindeki run merkezi (32x32 karede run kutusunun ortası ~ (15, 13.5)/(15, 15.5))."""
    cy = 13.5 if kind == "q" else 15.5
    return (STONE_C[kind][0] + (15 - 16) * K_ST, STONE_C[kind][1] + (cy - 16) * K_ST)


def sparks(fr, kind, t, origin, spread, rate=3.0, life=0.9, rise=16.0, scale=K_CH):
    """Yukselen iri kivilcimlar (2x2 / 1x1 karakter pikseli), deterministik."""
    pal = PAL[kind]["spark"]
    period = 1.0 / rate
    j0 = int((t - life) / period) - 1
    for j in range(j0, int(t / period) + 1):
        born = j * period
        age = t - born
        if not (0 <= age <= life):
            continue
        u = age / life
        jx = ((j * 37) % 11 - 5) / 5.0 * spread
        x = origin[0] + jx + math.sin(u * 5 + j) * 0.6 * scale
        y = origin[1] - rise * S * age
        col = pal[min(3, int(u * 4))]
        size = 2 if u < 0.5 else 1
        sq = Image.new("RGBA", (size, size), col).resize((round(size * scale), round(size * scale)), Image.NEAREST)
        paste(fr, sq, x - sq.width / 2, y - sq.height / 2, 1.0 - smooth((u - 0.6) / 0.4))


# ------------------------------------------------------------------ varyantlar
def var_A(fr, kind, t):
    """Parlayan Oyma: run tasta, gercekten parlar."""
    vis = cycle(kind, t)
    peak = max([lv for _, lv, _ in vis] + [0.0])
    breathe = 0.5 + 0.5 * math.sin(t * 2.4)
    draw_stone_rim(fr, kind, (0.35 + 0.35 * breathe) * max(0.4, peak), (0.18 + 0.12 * breathe) * max(0.4, peak))
    for row, lv, _age in vis:
        draw_rune(fr, kind, row, (STONE_C[kind][0], STONE_C[kind][1]), K_ST, lv, (0.75 + 0.25 * breathe) * lv,
                  crop=False, carved=True, halo=(0.75, 0.45, 0.22))
    sparks(fr, kind, t, rune_in_stone(kind), 3 * K_ST, rate=2.5, life=0.9, rise=14.0, scale=K_ST * 1.4)


def var_B(fr, kind, t):
    """Suzulen Run: tastan yukselir, ustunde suzulur."""
    vis = cycle(kind, t)
    peak = max([lv for _, lv, _ in vis] + [0.0])
    breathe = 0.5 + 0.5 * math.sin(t * 2.4)
    draw_stone_rim(fr, kind, 0.3 * peak, 0.15 * peak)
    # tastaki oyma: evrimsiz run sonuk kor gibi hep durur
    draw_rune(fr, kind, 0, (STONE_C[kind][0], STONE_C[kind][1]), K_ST, 0.55, 0.25, crop=False, carved=True)
    top = stone_top(kind)
    hover = (top[0], top[1] - 13 * S)
    src = rune_in_stone(kind)
    for row, lv, age in vis:
        if age < T_IN:
            u = smooth(age / T_IN)
            c = (src[0] + (hover[0] - src[0]) * u, src[1] + (hover[1] - src[1]) * u)
        else:
            c = (hover[0], hover[1] - (S * 5 * smooth((age - T_IN - T_HOLD) / T_OUT) if age > T_IN + T_HOLD else 0))
        c = (c[0], c[1] + math.sin(t * 3.0) * 1.0 * S)
        # huzme: tas tepesinden rune
        beam_top = c[1] + 8 * K_CH
        if beam_top < top[1]:
            for half, a in ((2, 0.12), (1, 0.24), (0, 0.4)):
                col = PAL[kind]["g1"] if half else PAL[kind]["mid"]
                w = round((2 * half + 1) * K_CH)
                hgt = round(top[1] - beam_top)
                bar = Image.new("RGBA", (w, hgt), col)
                paste(fr, bar, c[0] - w / 2, beam_top, a * lv * (0.7 + 0.3 * breathe))
        draw_rune(fr, kind, row, c, K_CH, lv, (0.8 + 0.2 * breathe) * lv)
    sparks(fr, kind, t, (hover[0], hover[1] - 4 * K_CH), 6 * K_CH, rate=2.0, life=0.8, rise=10.0)


def var_C(fr, kind, t):
    """Yorunge: butun runler tasin cevresinde doner, sirasi gelen parlar."""
    rows = ROWS[kind]
    n = len(rows)
    vis = {row: lv for row, lv, _ in cycle(kind, t)}
    c0 = (STONE_C[kind][0], STONE_C[kind][1] - 3 * S)
    rx, ry = 22 * S, 7 * S
    items = []
    for i, row in enumerate(rows):
        ang = t * 0.9 + i * math.tau / n
        p = (c0[0] + math.cos(ang) * rx, c0[1] + math.sin(ang) * ry)
        front = math.sin(ang) > 0
        items.append((math.sin(ang), row, p, front))
    items.sort()
    # arkadakiler once, sonra tas yeniden, sonra ondekiler (tasin ardinda kalsinlar)
    for depth, row, p, front in items:
        if not front:
            lv = vis.get(row, 0.0)
            draw_rune(fr, kind, row, p, K_ST, 0.75, 0.4 * lv, dim=1.0 - lv)
    draw_stone(fr, kind)
    draw_rune(fr, kind, 0, (STONE_C[kind][0], STONE_C[kind][1]), K_ST, 0.6, 0.3, crop=False, carved=True)
    for depth, row, p, front in items:
        if front:
            lv = vis.get(row, 0.0)
            draw_rune(fr, kind, row, p, K_ST, 1.0, 0.15 + 0.85 * lv, dim=1.0 - lv)
    draw_stone_rim(fr, kind, 0.3, 0.15)


def var_D(fr, kind, t):
    """Isik Sutunu: tastan yukselen sutunda runler yukari ucar."""
    top = stone_top(kind)
    height = 38 * S
    breathe = 0.5 + 0.5 * math.sin(t * 2.0)
    pal = PAL[kind]
    # sutun: satir satir yavas akan parlaklik (yumusak, kademeli)
    rows_px = int(height / K_CH)
    for i in range(rows_px):
        y = top[1] - (i + 1) * K_CH
        u = i / rows_px
        fade = (1 - u) ** 1.2
        flow = 0.75 + 0.25 * math.sin(u * 9 - t * 4)
        for half, col, a in ((2, pal["g2"], 0.22), (1, pal["g1"], 0.38), (0, pal["mid"], 0.6)):
            w = round((2 * half + 1) * K_CH)
            bar = Image.new("RGBA", (w, max(1, round(K_CH))), col)
            paste(fr, bar, top[0] - w / 2, y, a * fade * flow * (0.8 + 0.2 * breathe))
    draw_stone_rim(fr, kind, 0.4 + 0.2 * breathe, 0.2)
    draw_rune(fr, kind, 0, (STONE_C[kind][0], STONE_C[kind][1]), K_ST, 0.7, 0.4, crop=False, carved=True)
    # runler: her 0,8 sn'de biri tastan cikar, 1,8 sn'de yukari ucar
    rows = ROWS[kind]
    life, gap = 1.8, 0.8
    j0 = int((t - life) / gap) - 1
    for j in range(j0, int(t / gap) + 1):
        age = t - j * gap
        if not (0 <= age <= life):
            continue
        u = age / life
        y = top[1] - 4 * K_CH - u * (height - 8 * K_CH)
        a = smooth(u / 0.2) * (1 - smooth((u - 0.7) / 0.3))
        draw_rune(fr, kind, rows[j % len(rows)], (top[0], y), K_CH, a, a)
    sparks(fr, kind, t, (top[0], top[1] - 6 * K_CH), 3 * K_CH, rate=2.0, life=1.0, rise=20.0)


VARIANTS = {"A": var_A, "B": var_B, "C": var_C, "D": var_D}
NAMES = {
    "suan": "ŞU AN",
    "A": "A - Parlayan Oyma",
    "B": "B - Süzülen Rün",
    "C": "C - Yörünge",
    "D": "D - Işık Sütunu",
}


def label(fr, text):
    try:
        fnt = ImageFont.truetype(FONT, 32)
    except OSError:
        fnt = ImageFont.load_default()
    d = ImageDraw.Draw(fr)
    tw = d.textlength(text, font=fnt)
    d.rectangle([8, 6, 8 + tw + 16, 6 + 30], fill=(42, 30, 20, 220))
    d.text((16, 6), text, font=fnt, fill=(240, 226, 196, 255))


def load_seq(d):
    files = sorted(f for f in os.listdir(d) if f.startswith("kare_"))
    return [Image.open(os.path.join(d, f)).convert("RGBA") for f in files]


def save_gif_clean(frames, path):
    rgb = [f.convert("RGB") for f in frames]
    step = max(1, len(rgb) // 8)
    samples = rgb[::step]
    w, h = rgb[0].size
    mont = Image.new("RGB", (w, h * len(samples)))
    for i, f in enumerate(samples):
        mont.paste(f, (0, i * h))
    pal = mont.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in rgb]
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(1000 / FPS), loop=0)
    print(path, os.path.getsize(path) // 1024, "KB")


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = load_seq(os.path.join(CAP, "yakala_tas"))
    now = load_seq(os.path.join(CAP, "yakala_bos"))
    seqs = {}
    for key in ("suan", "A", "B", "C", "D"):
        seq = []
        for i in range(NFR):
            t = i / FPS
            if key == "suan":
                fr = now[i % len(now)].copy()
            else:
                fr = bg[i % len(bg)].copy()
                for kind in "qe":
                    VARIANTS[key](fr, kind, t)
            seq.append(fr.crop(CROP))
        seqs[key] = seq
        if key != "suan":
            big = []
            for c in seq:
                c2 = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
                label(c2, NAMES[key])
                big.append(c2)
            save_gif_clean(big, os.path.join(OUT, "run_%s.gif" % key))
    small = {}
    for key, seq in seqs.items():
        out = []
        for c in seq:
            c2 = c.resize((round(c.width * 1.5), round(c.height * 1.5)), Image.NEAREST)
            label(c2, NAMES[key])
            out.append(c2)
        small[key] = out
    w, h = small["A"][0].size
    grid = []
    for i in range(NFR):
        im = Image.new("RGBA", (w * 2 + 6, (h + 6) * 3 - 6), (20, 16, 12, 255))
        im.paste(small["suan"][i], ((w + 6) // 2, 0))
        for j, k in enumerate("ABCD"):
            im.paste(small[k][i], ((j % 2) * (w + 6), (j // 2 + 1) * (h + 6)))
        grid.append(im)
    save_gif_clean(grid, os.path.join(OUT, "karsilastirma.gif"))
    grid[16].convert("RGB").save(os.path.join(OUT, "ozet.png"))
    print("ozet:", os.path.join(OUT, "ozet.png"))


if __name__ == "__main__":
    main()
