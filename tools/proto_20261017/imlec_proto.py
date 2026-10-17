#!/usr/bin/env python3
"""Oyun içi İMLEÇ prototipleri (madde 205, 2026-10-17) - oyuna bağlı DEĞİL.

Oyunda özel imleç yok (Windows oku); fare nişan almıyor (sadece arayüz), bu yüzden dört yön de
nişangâh değil İŞARETÇİ. Her yön 3 durum: normal (CURSOR_ARROW), el (tıklanabilir, CURSOR_POINTING_HAND),
basılı (fare tuşu basılıyken). Sanat 1x piksel; oyunda 1080p'de x2 (HUD kitinin 2x dokularıyla aynı
piksel), 1440p+ için x3 (donanım imleci canvas_items ölçeğini İZLEMEZ).

  A Kehribar Ok   : sade krem ok, sıcak kahve dış hat; üstünde kehribar + ışıltı
  B Demir Eldiven : çelik zırh eldiveni (işaret parmağı), altın bilezik; üstünde pirince döner
  C Kılıç         : küçük kılıç (ucu = tıklama noktası), altın balçak; üstünde büyülü sıcak parıltı
  D Ruh Kristali  : Ruh Kıymığı mavisi yontulmuş kristal; üstünde hale + ışıltı

Yön 45 derece (sol üste) olan şekiller u/v uzayında çizilir: u = x + y (uca uzaklık), v = x - y
(+ = sağ üst yüz, ışık alır). Böylece kenarlar temiz piksel köşegenleri olur.

Çalıştırma: python tools/proto_20261017/imlec_proto.py
Çıktı: tools/proto_20261017/out/imlec/ (karşılaştırma + detay + <yön>/<durum>_x2|x3.png + hotspots.json)
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "imlec")
BG = os.path.join(HERE, "out", "hud_tema", "simdi.png")  # gerçek oyun yakalaması (madde 202, 1080p)
FONT = os.path.join(ROOT, "assets", "fonts", "PixeloidSans-Bold.ttf")

P = 6  # uç ile tuval kenarı arası (basılı ışınları + dış hat için yer)
STATES = ("normal", "el", "basili")
STATE_TR = {"normal": "normal", "el": "tıklanabilir", "basili": "basılı"}


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def darker(pal, k=0.82):
    out = {}
    for key, c in pal.items():
        out[key] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), c[3])
    return out


# ---------------------------------------------------------------- şekiller (uç = (0,0), rol harfleri)

def uv_shape(fn, umax, vmin, vmax):
    px = {}
    for u in range(umax + 1):
        for v in range(vmin, vmax + 1):
            if (u + v) % 2:
                continue
            r = fn(u, v)
            if r:
                px[((u + v) // 2, (u - v) // 2)] = r
    return px


def ascii_shape(rows):
    """'#' = iç; rol otomatik kabartma: sol/üst kenar H, sağ/alt kenar M, gerisi L."""
    cells = {(x, y) for y, row in enumerate(rows) for x, ch in enumerate(row) if ch == "#"}
    px = {}
    for (x, y) in cells:
        lit = (x - 1, y) not in cells or (x, y - 1) not in cells
        shd = (x + 1, y) not in cells or (x, y + 1) not in cells
        px[(x, y)] = "H" if lit and not shd else ("M" if shd and not lit else "L")
    return px


# A - klasik ok silüeti (sol kenar dik), kısa kuyruk
ARROW_ROWS = [
    "#",
    "##",
    "###",
    "####",
    "#####",
    "######",
    "#######",
    "########",
    "#########",
    "##########",
    "######",
    "###.##",
    "##..###",
    "#....##",
    ".....###",
    "......##",
]


# B - dik çizilmiş zırh eldiveni (işaret parmağı + iki kıvrık parmak + başparmak + altın bilezik),
# sonra her 4 satırda 1 piksel kaydırılır -> parmak sol üste ~14 derece eğik bakar. D = parmak arası/boğum.
GAUNTLET_ROWS = [
    "....H",
    "...HLM",
    "...HLM",
    "...MMD",
    "...HLM",
    "...HLM..H",
    "...HLMDHLM",
    "...MMDDHLM..H",
    "...HLMDHLMDHLM",
    ".H.HLMDHLMDHLM",
    "HLMHLMDMMDDMMM",
    "HLMLLLLLLLLLLM",
    ".HLLLLLLLLLLLM",
    "..HLLLLLLLLLMM",
    "..HLLLLLLLLLM",
    "...GGGGGGGGGg",
    "...CCCCCCCCCc",
    "..CCCCCCCCCCcc",
]


def rows_shape(rows, shear=0):
    """Rol harfli satırlar ('.' = dış). shear > 0: her `shear` satırda alt kısım 1 piksel sağa."""
    px = {}
    for y, row in enumerate(rows):
        dx = y // shear if shear else 0
        for x, ch in enumerate(row):
            if ch != ".":
                px[(x + dx, y)] = ch
    tip = min(px, key=lambda p: (p[1], p[0]))  # en üst satırın ilk pikseli = parmak ucu
    return {(x - tip[0], y - tip[1]): r for (x, y), r in px.items()}


def sword(u, v):
    av = abs(v)
    if u <= 13:  # bıçak
        w = 0 if u == 0 else (1 if u == 1 else 2)
        if av > w:
            return None
        if v == 0:
            return "H" if u >= 2 else "L"
        return "L" if v > 0 else ("M" if v == -1 else "D")
    if u <= 16:  # balçak
        lim = 6 if u == 15 else 5
        if av > lim:
            return None
        if u == 15 and av == 1:
            return "R"
        return {14: "G", 15: "g", 16: "q"}[u]
    if u <= 21:  # kabza (deri sargı)
        if av > 1:
            return None
        return "B" if u % 2 == 0 else "b"
    if u <= 24:  # topuz
        if av > (1 if u == 24 else 2):
            return None
        if u == 24:
            return "q"
        return "G" if v > 0 else "g"
    return None


def crystal(u, v):
    if u <= 10:  # sivri tepe
        w = int(u * 0.4 + 0.5)
    elif u <= 16:
        w = 4
    else:  # alt uç
        w = 4 - int((u - 16) * 1.4 + 0.5)
    if w < 0 or abs(v) > w:
        return None
    if u >= 17:  # alt yüzey (gölgede)
        return "M" if v > 0 else "D"
    if u <= 10:  # tepe yüzeyi (en çok ışık)
        if u == 5 and v == 1:
            return "W"
        return "H" if v >= 0 else "L"
    return "L" if v >= 0 else ("D" if v == -w else "M")


# ---------------------------------------------------------------- yönler (palet + süs)

def style_defs():
    a_n = {"H": hx("fffbf2"), "L": hx("f1e2c2"), "M": hx("c8a578")}
    a_h = {"H": hx("fff1c8"), "L": hx("f5c463"), "M": hx("c9822f")}
    b_n = {"H": hx("ffffff"), "L": hx("d9dfe4"), "M": hx("9aa5b0"), "D": hx("5c6672"),
           "G": hx("f2c46a"), "g": hx("c98a36"), "C": hx("7a5038"), "c": hx("553323")}
    b_h = dict(b_n, H=hx("fff6d6"), L=hx("f4d690"), M=hx("d29a4a"), D=hx("8f5a24"),
               G=hx("fff0b0"), g=hx("f2c46a"))
    c_n = {"H": hx("ffffff"), "L": hx("e6edf2"), "M": hx("a9b6c1"), "D": hx("6b7884"),
           "G": hx("f6d27a"), "g": hx("d79a3e"), "q": hx("94591f"), "B": hx("8a5a3a"),
           "b": hx("5e3a24"), "R": hx("d4483c")}
    c_h = dict(c_n, H=hx("fffbe8"), L=hx("ffe7a8"), M=hx("e2b25c"), D=hx("a8742e"),
               G=hx("fff0b0"), g=hx("f6d27a"))
    d_n = {"H": hx("ffffff"), "L": hx("cdeefb"), "M": hx("7fb3e6"), "D": hx("4a6cbf"), "W": hx("ffffff")}
    d_h = {"H": hx("ffffff"), "L": hx("e8fbff"), "M": hx("a6dcf6"), "D": hx("6f9df2"), "W": hx("ffffff")}
    return {
        "A": dict(name="Kehribar Ok", sub="sade krem ok · üstünde kehribar",
                  shape=ascii_shape(ARROW_ROWS), ink=hx("2a190d"),
                  pal={"normal": a_n, "el": a_h, "basili": darker(a_h)},
                  accent=hx("f5c463"), spark=(7, 1), glow=None),
        "B": dict(name="Demir Eldiven", sub="çelik eldiven · üstünde pirinç",
                  shape=rows_shape(GAUNTLET_ROWS, 4), ink=hx("1f1a18"),
                  pal={"normal": b_n, "el": b_h, "basili": darker(b_h)},
                  accent=hx("f2c46a"), spark=(9, 0), glow=None),
        "C": dict(name="Kılıç", sub="ucu tıklar · üstünde altın parıltı",
                  shape=uv_shape(sword, 24, -6, 6), ink=hx("22170f"),
                  pal={"normal": c_n, "el": c_h, "basili": darker(c_h)},
                  accent=hx("ffe7a8"), spark=(8, 0), glow=None),
        "D": dict(name="Ruh Kristali", sub="Ruh Kıymığı mavisi · üstünde hale",
                  shape=uv_shape(crystal, 20, -5, 5), ink=hx("182039"),
                  pal={"normal": d_n, "el": d_h, "basili": {"H": hx("d8f4ff"), "L": hx("9fd6f2"),
                                                            "M": hx("5f97d8"), "D": hx("3a56a8"),
                                                            "W": hx("ffffff")}},
                  accent=hx("a6dcf6"), spark=(8, 0), glow=(140, 220, 255, 110)),
    }


# ---------------------------------------------------------------- çizim

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def build(style, state):
    shape = style["shape"]
    ox = P + max(0, -min(x for x, _ in shape))  # eldivende başparmak ucun solunda kalır
    oy = P + max(0, -min(y for _, y in shape))
    w = ox + max(x for x, _ in shape) + 4
    h = oy + max(y for _, y in shape) + 4
    pal = style["pal"][state]
    body = {(x + ox, y + oy): pal[r] for (x, y), r in shape.items()}
    ink = {}
    for (x, y) in body:
        for dx, dy in N4:
            q = (x + dx, y + dy)
            if q not in body:
                ink[q] = style["ink"]
    ink[(ox - 1, oy - 1)] = style["ink"]  # sivri, koyu uç = tıklama noktası
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pix = img.load()
    solid = dict(ink)
    solid.update(body)
    if state != "basili":  # gölge: basılıyken imleç zemine "oturur"
        for (x, y) in solid:
            q = (x + 1, y + 1)
            if q not in solid and 0 <= q[0] < w and 0 <= q[1] < h:
                pix[q] = (16, 10, 6, 95)
    if style["glow"] and state == "el":
        for (x, y) in ink:
            for dx, dy in N4:
                q = (x + dx, y + dy)
                if q not in solid and 0 <= q[0] < w and 0 <= q[1] < h:
                    pix[q] = style["glow"]
    for q, c in solid.items():
        pix[q] = c
    acc = style["accent"]
    if state == "el":  # dört köşeli ışıltı
        sx, sy = style["spark"][0] + ox, style["spark"][1] + oy
        dim = acc[:3] + (170,)
        for (dx, dy, c) in ((0, 0, (255, 255, 255, 255)), (1, 0, acc), (-1, 0, acc), (0, 1, acc),
                            (0, -1, acc), (2, 0, dim), (-2, 0, dim), (0, 2, dim), (0, -2, dim)):
            q = (sx + dx, sy + dy)
            if q not in solid and 0 <= q[0] < w and 0 <= q[1] < h:
                pix[q] = c
    if state == "basili":  # uçtan üç kısa tık ışını
        tip = (ox - 1, oy - 1)
        rays = [(-2, -2), (-3, -3), (1, -3), (1, -4), (-3, 1), (-4, 1)]
        for dx, dy in rays:
            q = (tip[0] + dx, tip[1] + dy)
            s = (q[0] + 1, q[1] + 1)
            if 0 <= s[0] < w and 0 <= s[1] < h and s not in solid and pix[s][3] == 0:
                pix[s] = (16, 10, 6, 120)
        for dx, dy in rays:
            q = (tip[0] + dx, tip[1] + dy)
            if 0 <= q[0] < w and 0 <= q[1] < h:
                pix[q] = acc
    return img, (ox - 1, oy - 1)


def windows_arrow():
    rows = [
        "X", "XX", "XWX", "XWWX", "XWWWX", "XWWWWX", "XWWWWWX", "XWWWWWWX", "XWWWWWWWX",
        "XWWWWWWWWX", "XWWWWWWWWWX", "XWWWWWWXXXXX", "XWWWXWWX", "XWWXXWWX", "XWX..XWWX",
        "XX...XWWX", "X.....XWWX", "......XWWX", ".......XX",
    ]
    img = Image.new("RGBA", (12, 19), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "X":
                img.putpixel((x, y), (0, 0, 0, 255))
            elif ch == "W":
                img.putpixel((x, y), (255, 255, 255, 255))
    return img, (0, 0)


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


# ---------------------------------------------------------------- sayfalar

# gerçek oyun yakalamasında uç noktaları (1080p): dünya (karakterin sağ altı), ENVANTER düğmesi, 2. yetenek yuvası
TIPS = {"normal": (1030, 562), "el": (122, 44), "basili": (830, 946)}
ROW_TR = {"normal": "Dünyada (normal)", "el": "Düğmenin üstünde (tıklanabilir)", "basili": "Tıklarken (basılı)"}


def crop_with_cursor(bg, cur, hot, tip, cw, ch, ax, ay):
    """bg'den uç (tip) kırpmanın (ax, ay) noktasına gelecek şekilde cw x ch kırp, imleci bindir."""
    x0 = min(max(tip[0] - ax, 0), bg.width - cw)
    y0 = min(max(tip[1] - ay, 0), bg.height - ch)
    c = bg.crop((x0, y0, x0 + cw, y0 + ch)).convert("RGBA")
    c.alpha_composite(cur, (tip[0] - x0 - hot[0], tip[1] - y0 - hot[1]))
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    styles = style_defs()
    bg = Image.open(BG).convert("RGBA")
    f_t = ImageFont.truetype(FONT, 26)
    f_s = ImageFont.truetype(FONT, 15)
    f_r = ImageFont.truetype(FONT, 17)

    # imleç dosyaları (x2 = 1080p, x3 = 1440p+)
    hot_json = {}
    cursors = {}  # (yön, durum) -> (1080p görüntü, hotspot)
    for key, st in styles.items():
        d = os.path.join(OUT, key)
        os.makedirs(d, exist_ok=True)
        hot_json[key] = {"ad": st["name"]}
        for state in STATES:
            img, hot = build(st, state)
            for k in (2, 3):
                up(img, k).save(os.path.join(d, "%s_x%d.png" % (state, k)))
            hot_json[key][state] = {"x2": [hot[0] * 2, hot[1] * 2], "x3": [hot[0] * 3, hot[1] * 3],
                                    "boyut_x2": [img.width * 2, img.height * 2]}
            cursors[(key, state)] = (up(img, 2), (hot[0] * 2, hot[1] * 2))
    wa, wh = windows_arrow()
    for state in STATES:
        cursors[("now", state)] = (wa, wh)
    with open(os.path.join(OUT, "hotspots.json"), "w", encoding="utf-8") as fp:
        json.dump(hot_json, fp, ensure_ascii=False, indent=1)

    # ---- karşılaştırma: ŞU AN + A-D, 3 durum 1:1 + x3 büyütme
    cols = [("now", "ŞU AN", "Windows oku (her yerde aynı)")] + \
           [(k, "%s  %s" % (k, s["name"]), s["sub"]) for k, s in styles.items()]
    CW, CH, GAP, X0 = 370, 170, 4, 25
    STRIP = 28
    ZW, ZH, ZK = 120, 150, 2
    H = 82 + (STRIP + CH) * 3 + STRIP + ZH + 22
    sheet = Image.new("RGBA", (1920, H), hx("17120e"))
    dr = ImageDraw.Draw(sheet)
    ink, dim, gold = hx("efe2c6"), hx("ad9b80"), hx("e2a64e")
    for i, (key, title, sub) in enumerate(cols):
        x = X0 + i * (CW + GAP)
        dr.text((x + 4, 14), title, font=f_t, fill=gold if key != "now" else ink)
        dr.text((x + 4, 50), sub, font=f_s, fill=dim)
    y = 82
    for state in STATES:
        dr.text((X0 + 4, y + 5), ROW_TR[state] + "  -  1:1 oyun ölçeği (1080p)", font=f_r, fill=ink)
        y += STRIP
        for i, (key, _, _) in enumerate(cols):
            cur, hot = cursors[(key, state)]
            sheet.alpha_composite(crop_with_cursor(bg, cur, hot, TIPS[state], CW, CH, CW // 2, CH // 2),
                                  (X0 + i * (CW + GAP), y))
        y += CH
    dr.text((X0 + 4, y + 5), "x2 büyütme (soldan: normal / tıklanabilir / basılı)", font=f_r, fill=ink)
    y += STRIP
    for i, (key, _, _) in enumerate(cols):
        for j, state in enumerate(STATES):
            cur, hot = cursors[(key, state)]
            small = crop_with_cursor(bg, cur, hot, TIPS[state], ZW // ZK, ZH // ZK, 14, 12)
            sheet.alpha_composite(up(small, ZK), (X0 + i * (CW + GAP) + j * (ZW + 5), y))
    sheet.convert("RGB").save(os.path.join(OUT, "imlec_karsilastirma.png"))

    # ---- detay: sanat x8, uç noktası işaretli
    K8 = 8
    cell_w = max(build(s, st)[0].width for s in styles.values() for st in STATES) * K8 + 30
    cell_h = max(build(s, st)[0].height for s in styles.values() for st in STATES) * K8 + 40
    det = Image.new("RGBA", (200 + cell_w * 3, 50 + cell_h * 4), hx("17120e"))
    dd = ImageDraw.Draw(det)
    for j, state in enumerate(STATES):
        dd.text((200 + j * cell_w, 14), STATE_TR[state], font=f_r, fill=ink)
    for i, (key, st) in enumerate(styles.items()):
        yy = 50 + i * cell_h
        dd.text((14, yy + 10), "%s  %s" % (key, st["name"]), font=f_r, fill=gold)
        for j, state in enumerate(STATES):
            img, hot = build(st, state)
            xx = 200 + j * cell_w
            dd.rectangle((xx, yy, xx + img.width * K8 - 1, yy + img.height * K8 - 1), fill=hx("5f7a45"))
            det.alpha_composite(up(img, K8), (xx, yy))
            hx0, hy0 = xx + hot[0] * K8 + K8 // 2, yy + hot[1] * K8 + K8 // 2
            dd.line((hx0 - 3, hy0, hx0 + 3, hy0), fill=hx("ff3030"))
            dd.line((hx0, hy0 - 3, hx0, hy0 + 3), fill=hx("ff3030"))
            dd.text((xx, yy + img.height * K8 + 6), "x2: %dx%d" % (img.width * 2, img.height * 2),
                    font=f_s, fill=dim)
    det.convert("RGB").save(os.path.join(OUT, "imlec_detay.png"))
    print("tamam ->", OUT)


if __name__ == "__main__":
    main()
