"""Shaman Q/E RUN TASLARI - kullanicinin cizimlerinden oyun dokulari (madde 557; runler madde 569 "A - Parlayan Oyma").

Kaynak (kullanicinin 32x32 cizimleri, degistirilmez): tools/shaman_rune_stone/kaynak/
  q_tas.png / e_tas.png            tas govdesi
  <q|e>_run_<0|1|2|3|4|f>.png      run isaretleri (0 = evrimsiz, 1-4 = "N evrimli ekstra", f = final)
                                    renkler: parlak cizgi, golge cizgi, (0,0,0,127) oyma golgesi

Cikti (assets/shaman/rune_stone/):
  <q|e>_tas.png       tasin birebir kopyasi (32x32)
  <q|e>_tas_isik.png  tasin DISINDA 2 halka parilti (ic halka tam, dis halka yari alfa; 36x36, 2 px pay; oyunda modulate.a nabiz)
  <q|e>_runler.png    2 sutun x 6 satir (run 0,1,2,3,4,f), 32x32 hucre (tasla ayni kare, ayni yerde):
                      sutun 0 = AKKOR run (parlak cizgi -> beyaz-sicak, golge cizgi -> sari / acik mavi) + oyma golgesi,
                      sutun 1 = cizginin cevresinde 3 halkali HALE, alfa basamakli (0,75 / 0,45 / 0,22), dither yok.
Madde 568 prototipi A (kullanici: "runler cok donuk, ucuyormus gibi gorunmuyor, hic parildamiyor" -> A secildi).
Hangi evrimin hangi satiri gosterdigi oyunda: scripts/totem_rune_stone.gd EVO_ROW.

Kullanim:  python -I tools/gen_shaman_rune_stones.py   ; dokular degisince Godot --headless --import
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "shaman_rune_stone", "kaynak")
OUT = os.path.join(ROOT, "assets", "shaman", "rune_stone")

RUNES = ["0", "1", "2", "3", "4", "f"]
CELL = 32
GLOW_PAD = 2
COLS = 2


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# Q kirmiziya (ates), E maviye (kalkan) dogru parlar. hot/mid = akkor cekirdek, g1-g3 = hale disari dogru.
PAL = {
    "q": {"hot": "#fff4cf", "mid": "#ffdb75", "g1": "#ff7a2a", "g2": "#e8401e", "g3": "#b02818"},
    "e": {"hot": "#ffffff", "mid": "#a6d8ff", "g1": "#6cc4ff", "g2": "#3a7ce0", "g3": "#1e4aa0"},
}
HALO_ALPHA = (191, 115, 56)  # 0,75 / 0,45 / 0,22


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def mask_of(im, pred):
    w, h = im.size
    px = im.load()
    return {(x, y) for y in range(h) for x in range(w) if pred(px[x, y])}


def dilate(cells, w, h, eight=False):
    nb = ((1, 0), (-1, 0), (0, 1), (0, -1)) + (((1, 1), (1, -1), (-1, 1), (-1, -1)) if eight else ())
    out = set(cells)
    for (x, y) in cells:
        for dx, dy in nb:
            if 0 <= x + dx < w and 0 <= y + dy < h:
                out.add((x + dx, y + dy))
    return out


def classify_rune(im):
    """Run pikselleri: parlak (en acik opak renk), golge (diger opak), oyma (yari saydam)."""
    px = im.load()
    opaque = {}
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            p = px[x, y]
            if p[3] == 255:
                opaque.setdefault(p[:3], []).append((x, y))
    if not opaque:
        raise SystemExit("run bos")
    bright_col = max(opaque, key=lambda c: sum(c))
    bright = set(opaque[bright_col])
    shade = set()
    for c, cells in opaque.items():
        if c != bright_col:
            shade.update(cells)
    groove = mask_of(im, lambda p: 0 < p[3] < 255)
    return bright, shade, groove


def put(img, cells, rgba):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    lp = layer.load()
    for c in cells:
        lp[c] = rgba
    img.alpha_composite(layer)


def rune_cells(kind, rune_im):
    """(akkor cekirdek + oyma, 3 halkali hale) hucreleri."""
    pal = PAL[kind]
    bright, shade, groove = classify_rune(rune_im)
    stroke = bright | shade
    r1 = dilate(stroke, CELL, CELL) - stroke
    r2 = dilate(stroke | r1, CELL, CELL, True) - stroke - r1
    r3 = dilate(stroke | r1 | r2, CELL, CELL) - stroke - r1 - r2
    core = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    put(core, groove, (0, 0, 0, 127))
    put(core, shade, hx(pal["mid"]))
    put(core, bright, hx(pal["hot"]))
    halo = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    put(halo, r3, hx(pal["g3"], HALO_ALPHA[2]))
    put(halo, r2, hx(pal["g2"], HALO_ALPHA[1]))
    put(halo, r1, hx(pal["g1"], HALO_ALPHA[0]))
    return core, halo


def stone_glow(kind, stone):
    pal = PAL[kind]
    w, h = stone.size
    W, H = w + 2 * GLOW_PAD, h + 2 * GLOW_PAD
    smask = {(x + GLOW_PAD, y + GLOW_PAD) for (x, y) in mask_of(stone, lambda p: p[3] > 0)}
    r1 = dilate(smask, W, H) - smask
    r2 = dilate(smask | r1, W, H, True) - smask - r1
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    put(img, r2, hx(pal["g2"], 128))
    put(img, r1, hx(pal["g1"]))
    return img


def build(kind):
    stone = load("%s_tas.png" % kind)
    if stone.size != (CELL, CELL):
        raise SystemExit("tas 32x32 olmali")
    sheet = Image.new("RGBA", (CELL * COLS, CELL * len(RUNES)), (0, 0, 0, 0))
    for row, r in enumerate(RUNES):
        core, halo = rune_cells(kind, load("%s_run_%s.png" % (kind, r)))
        sheet.alpha_composite(core, (0, row * CELL))
        sheet.alpha_composite(halo, (CELL, row * CELL))
    return stone, stone_glow(kind, stone), sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind in ("q", "e"):
        stone, glow, sheet = build(kind)
        stone.save(os.path.join(OUT, "%s_tas.png" % kind))
        glow.save(os.path.join(OUT, "%s_tas_isik.png" % kind))
        sheet.save(os.path.join(OUT, "%s_runler.png" % kind))
        print(kind, "->", OUT, "tas", stone.size, "isik", glow.size, "runler", sheet.size)


if __name__ == "__main__":
    main()
