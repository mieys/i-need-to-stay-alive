"""Kalkan darbe (hasar alma) efekti prototipi (oyuna bagli DEGIL): yakala.ps1 karelerinden
out/<kalkan>/karsilastirma.gif (SU AN + A-D, x2, 15 fps, ortak palet, dither YOK) + out/<kalkan>/ozet.png
(secenek basina bir darbenin 5 ani, x3).
Kullanim: python -I tools/proto_20261111/kalkan_darbe/gif.py [shield_standart]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PROJ = ROOT.parents[2]
SHIELD = sys.argv[1] if len(sys.argv) > 1 else "shield_standart"
SRC = ROOT / "out" / SHIELD
VARIANTS = [
    ("suan", "ŞU AN", "dönen mühür (izometrik disk)"),
    ("a", "A - Işıyan Yüzey", "vurulan yerde baloncuk belirir"),
    ("b", "B - Esneyen Zar", "yüzey içeri çöker, yaylanır"),
    ("c", "C - Dalga Halkası", "yüzeye yayılan iki halka"),
    ("d", "D - Seken Darbe", "dıştan gelir, kıvılcımlar seker"),
    ("e", "A + menzilliye D", "yakın: yama / menzilli: seken darbe"),
    ("oyun", "OYUNDA: A + menzilliye sıçrama", "mermi baloncuğun dışında söner"),
]
VARIANTS = [v for v in VARIANTS if (SRC / v[0]).is_dir()]  ## yalniz cekilen secenekler
FONT = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 32)
FONT_S = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 16)
BG = (30, 22, 16)
INK = (242, 228, 196)
DIM = (176, 156, 124)
CAP_H = 44
PAD = 8
_LOG = SRC / "yakala.log"
## yakala_gercek.ps1 cekimi (gercek Main + gercek yaratiklar, kamera oyunun kendisi): gunlukte "KD oyuncu" satiri var
GERCEK = _LOG.exists() and "KD oyuncu" in _LOG.read_text(encoding="utf-8", errors="replace")
SC = 2  ## tam kat (1,5 kat pikselleri esitsiz yapar, madde 564 ek 4)
GIF_CROP = (300, 240) if GERCEK else None  ## gercek cekim 400x300: ortadaki oyuncu + yakin yaratiklar
## ozet: kuzeyden gelen darbe (yakala.gd HITS[1], kare 28 -> 15 fps'te 14) ve dogudan (kare 10 -> 5)
PICKS = [(14, "kuzey +0"), (15, "+0,07 sn"), (17, "+0,2 sn"), (5, "doğu +0"), (6, "+0,07 sn"), (8, "+0,2 sn")]


def frames(v):
    return sorted((SRC / v).glob("f_*.png"))


def panel(img, title, sub):
    w, h = img.size
    out = Image.new("RGB", (w, h + CAP_H), BG)
    out.paste(img.convert("RGB"), (0, CAP_H))
    d = ImageDraw.Draw(out)
    d.text((8, 0), title, font=FONT, fill=INK)
    d.text((8, 26), sub, font=FONT_S, fill=DIM)
    return out


def main():
    seqs = [frames(v) for v, _, _ in VARIANTS]
    n = min(len(s) for s in seqs)
    w, h = Image.open(seqs[0][0]).size
    gbox = (0, 0, w, h)
    if GIF_CROP and len(VARIANTS) > 1:  ## tek secenekte tam kare (uzaktan atan yaratiklar da gorunsun)
        gbox = (w // 2 - GIF_CROP[0] // 2, h // 2 - GIF_CROP[1] // 2 + 10, w // 2 + GIF_CROP[0] // 2, h // 2 + GIF_CROP[1] // 2 + 10)
    w2, h2 = (gbox[2] - gbox[0]) * SC, (gbox[3] - gbox[1]) * SC
    pw, ph = w2, h2 + CAP_H
    cols = min(3, len(VARIANTS))
    rows = (len(VARIANTS) + cols - 1) // cols
    gw, gh = pw * cols + PAD * (cols + 1), ph * rows + PAD * (rows + 1)
    grids = []
    for i in range(n):
        g = Image.new("RGB", (gw, gh), BG)
        for k, (v, title, sub) in enumerate(VARIANTS):
            im = Image.open(seqs[k][i]).convert("RGB").crop(gbox).resize((w2, h2), Image.NEAREST)
            g.paste(panel(im, title, sub), (PAD + (k % cols) * (pw + PAD), PAD + (k // cols) * (ph + PAD)))
        grids.append(g)
    ## ortak palet: ilk kareler + darbe anlari birlesimi, dither YOK
    probe = Image.new("RGB", (gw, gh * 4))
    for j, fi in enumerate([5, 14, 15, 41]):
        probe.paste(grids[min(fi, n - 1)], (0, gh * j))
    pal = probe.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out_frames = [g.quantize(palette=pal, dither=Image.Dither.NONE) for g in grids]
    gif = SRC / "karsilastirma.gif"
    out_frames[0].save(gif, save_all=True, append_images=out_frames[1:], duration=67, loop=0, disposal=1)
    print("GIF", gif, n, "kare", gif.stat().st_size // 1024, "KB")

    if GERCEK:
        gercek_ozet(seqs, n, w, h)
        return
    cw, ch = 190, 190  ## baloncuk merkezi = oyuncu kökü (kamera +6 dünya yukarıda -> 12 px aşağıda)
    crop = (w // 2 - cw // 2, h // 2 + 12 - ch // 2, w // 2 + cw // 2, h // 2 + 12 + ch // 2)
    sc = 2
    lab_w = 250
    sheet = Image.new("RGB", (lab_w + len(PICKS) * (cw * sc + PAD) + PAD, 30 + len(VARIANTS) * (ch * sc + PAD) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    for j, (fi, txt) in enumerate(PICKS):
        d.text((lab_w + PAD + j * (cw * sc + PAD), 4), txt, font=FONT, fill=DIM)
    for k, (v, title, sub) in enumerate(VARIANTS):
        y = 30 + PAD + k * (ch * sc + PAD)
        d.text((8, y + 8), title, font=FONT, fill=INK)
        d.text((8, y + 40), sub, font=FONT_S, fill=DIM)
        for j, (fi, _) in enumerate(PICKS):
            im = Image.open(seqs[k][min(fi, n - 1)]).convert("RGB").crop(crop).resize((cw * sc, ch * sc), Image.NEAREST)
            sheet.paste(im, (lab_w + PAD + j * (cw * sc + PAD), y))
    ozet = SRC / "ozet.png"
    sheet.save(ozet)
    print("OZET", ozet, sheet.size)


def gercek_ozet(seqs, n, w, h):
    """Secenek basina ilk 4 GERCEK darbe (yakala.log "DARBE <secenek> <kare>"), darbeden 1 kare (~0,07 sn) sonra, x2."""
    hits = {}
    for line in (SRC / "yakala.log").read_text(encoding="utf-8", errors="replace").splitlines():
        p = line.split()
        if len(p) >= 3 and p[0] == "DARBE":
            hits.setdefault(p[1], []).append((int(p[2]), p[3] if len(p) > 3 else ""))
    if "oyun" in [v for v, _, _ in VARIANTS]:
        ## oyun cekimi: merminin baloncuga DEGDIGI kareler (yakala.log "DEGME oyun <kare> <uzaklik>")
        hits["e"] = []
        for line in (SRC / "yakala.log").read_text(encoding="utf-8", errors="replace").splitlines():
            p = line.split()
            if len(p) >= 3 and p[0] == "DEGME":
                hits["e"].append((int(p[2]), "menzilli"))
    if "e" in hits:
        ## E cekimi: ayni kareler butun satirlarda (belirlenimci), 2 menzilli + 2 yakin darbe
        picked = []
        for want, cap in (("menzilli", 2), ("yakin", 2), ("menzilli", 4)):  ## yakin yoksa bos yerler menzilliyle dolar
            for f, kind in hits["e"]:
                if len(picked) < 4 and kind == want and f > 0 and all(abs(f - q) >= 6 for q, _ in picked) and sum(1 for _, k in picked if k == want) < cap:
                    picked.append((f, kind))
        picked.sort()
    cw, ch = 220, 190
    crop = (w // 2 - cw // 2, h // 2 - ch // 2 + 10, w // 2 + cw // 2, h // 2 + ch // 2 + 10)
    sc = 2
    k_n = 4
    lab_w = 250
    sheet = Image.new("RGB", (lab_w + k_n * (cw * sc + PAD) + PAD, 30 + len(VARIANTS) * (ch * sc + PAD) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    for j in range(k_n):
        txt = "%d. darbe +0,07 sn" % (j + 1)
        if "e" in hits and j < len(picked):
            txt = ("MENZİLLİ" if picked[j][1] == "menzilli" else "YAKIN") + " darbe +0,07 sn"
        d.text((lab_w + PAD + j * (cw * sc + PAD), 4), txt, font=FONT, fill=DIM)
    for k, (v, title, sub) in enumerate(VARIANTS):
        y = 30 + PAD + k * (ch * sc + PAD)
        d.text((8, y + 8), title, font=FONT, fill=INK)
        d.text((8, y + 40), sub, font=FONT_S, fill=DIM)
        fl = []
        if "e" in hits:
            fl = [f for f, _ in picked]
        for f, _ in ([] if "e" in hits else hits.get(v, [])):
            ## kare 0 = onceki secenekten kalan sayac (sahte darbe); aralikli 4 darbe (farkli yonler)
            if f > 0 and (not fl or f - fl[-1] >= 10):
                fl.append(f)
        for j, fi in enumerate(fl[:k_n]):
            im = Image.open(seqs[k][min(fi + 1, n - 1)]).convert("RGB").crop(crop).resize((cw * sc, ch * sc), Image.NEAREST)
            sheet.paste(im, (lab_w + PAD + j * (cw * sc + PAD), y))
    ozet = SRC / "ozet.png"
    sheet.save(ozet)
    print("OZET", ozet, sheet.size)


if __name__ == "__main__":
    main()
