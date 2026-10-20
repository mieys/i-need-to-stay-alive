# Yakin dovus ZINCIRI (madde 347) once/sonra karsilastirma GIF'leri: yakin_zincir_run.ps1 -Tag once / -Tag sonra karelerinden
# silah basina ESKI | YENI x (saldiri hizi x1, x2, x4) izgarasi. Her satir kendi vurus doneminde (2 aralik: kilic yon degistirir) dikissiz doner.
#   python tools/proto_20261020/yakin_zincir_gif.py
import glob
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "out", "yakin_zincir")
KEYS = [("uzunkilic", "KILIÇ"), ("dagger", "BIÇAK"), ("topuz", "TOPUZ"), ("pence", "PENÇE"), ("mizrak", "MIZRAK"), ("kalkan", "KALKAN")]
RATES = [1.0, 2.0, 4.0]
BASE_WAIT = 1.1111 / 0.7
FPS = 30
START = 0.15
GAP = 6
HEAD = 30
ROW_LABEL = 22
BG = (24, 22, 30)
INK = (236, 226, 204)
DIM = (170, 160, 140)
OLD_C = (214, 120, 96)
NEW_C = (140, 206, 120)
NEW_NOTE = {"dagger": "zincir + yavaş geri kayma", "pence": "zincir + farklı açılar"}


def font(size, bold=True):
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "segoeuib.ttf", "segoeui.ttf"):
        p = os.path.join("C:/Windows/Fonts", name)
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load(tag, key, rate):
    d = os.path.join(ROOT, tag, "%s_x%s" % (key, rate))
    out = []
    for f in sorted(glob.glob(os.path.join(d, "f_*.png"))):
        ms = int(os.path.basename(f)[:-4].split("_")[2])
        out.append((ms / 1000.0, f))
    return out


def frame_at(frames, t, cache):
    pick = frames[0][1]
    for s, f in frames:
        if s <= t:
            pick = f
        else:
            break
    if pick not in cache:
        cache[pick] = Image.open(pick).convert("RGB")
    return cache[pick]


def main():
    f_head = font(18)
    f_row = font(14, False)
    for key, title in KEYS:
        rows = []
        for rate in RATES:
            rows.append((rate, load("once", key, rate), load("sonra", key, rate)))
        if any(not r[1] or not r[2] for r in rows):
            print("eksik:", key)
            continue
        cw, ch = Image.open(rows[0][1][0][1]).size
        width = cw * 2 + GAP * 3
        height = HEAD + len(rows) * (ROW_LABEL + ch + GAP) + GAP
        dur = 2.0 * BASE_WAIT / min(RATES)
        cache = {}
        out = []
        n = int(round(dur * FPS))
        for i in range(n):
            t = i / FPS
            img = Image.new("RGB", (width, height), BG)
            dr = ImageDraw.Draw(img)
            dr.text((GAP + 8, 6), "%s  -  ESKİ" % title, font=f_head, fill=OLD_C)
            dr.text((GAP * 2 + cw + 8, 6), "%s  -  YENİ (%s)" % (title, NEW_NOTE.get(key, "zincir")), font=f_head, fill=NEW_C)
            y = HEAD
            for rate, old, new in rows:
                wait = BASE_WAIT / rate
                period = 2.0 * wait
                lt = START + (t % period)
                dr.text((GAP + 8, y + 3), "saldırı hızı x%d  (vuruş aralığı %.2f sn)" % (rate, wait), font=f_row, fill=DIM)
                y += ROW_LABEL
                img.paste(frame_at(old, lt, cache), (GAP, y))
                img.paste(frame_at(new, lt, cache), (GAP * 2 + cw, y))
                y += ch + GAP
            out.append(img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
        path = os.path.join(ROOT, "%s_once_sonra.gif" % key)
        out[0].save(path, save_all=True, append_images=out[1:], duration=int(1000 / FPS), loop=0, disposal=1)
        print(path, len(out), "kare", "%.2f sn" % dur)


## Pençe açı döngüsü (PenceHookMath.TILT_CYCLE, 6 vuruş): yakin_zincir_run.ps1 -Tag sonra_pence -Keys pence -Rates "2,4" -Dur 5.2 karelerinden
## x2 | x4 yan yana, satır başına tam döngü (x2: 6 vuruş, x4: 2 x 6 vuruş) - dikişsiz.
def pence_cycle():
    if not os.path.isdir(os.path.join(ROOT, "sonra_pence")):
        return
    f_head = font(18)
    cols = [(rate, load("sonra_pence", "pence", rate)) for rate in RATES[1:]]
    cw, ch = Image.open(cols[0][1][0][1]).size
    width = cw * len(cols) + GAP * (len(cols) + 1)
    height = HEAD + ch + GAP
    dur = 6.0 * BASE_WAIT / cols[0][0]
    cache = {}
    out = []
    for i in range(int(round(dur * FPS))):
        t = i / FPS
        img = Image.new("RGB", (width, height), BG)
        dr = ImageDraw.Draw(img)
        x = GAP
        for rate, frames in cols:
            wait = BASE_WAIT / rate
            dr.text((x + 8, 6), "PENÇE - saldırı hızı x%d (6 açı sırayla)" % rate, font=f_head, fill=NEW_C)
            img.paste(frame_at(frames, START + (t % (6.0 * wait)), cache), (x, HEAD))
            x += cw + GAP
        out.append(img.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    path = os.path.join(ROOT, "pence_acilar.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=int(1000 / FPS), loop=0, disposal=1)
    print(path, len(out), "kare", "%.2f sn" % dur)


main()
pence_cycle()
