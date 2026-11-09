# -*- coding: utf-8 -*-
# Karakter ustu can/kalkan cubugu prototip sayfasi (ust_bar_capture.gd ciktisindan, 2026-11-08, oyuna bagli DEGIL).
# Calistir: python -I tools/proto_20261108/ust_bar/ust_bar_sayfa.py
# Cikti: out/ozet.png (satir basina: 2x oyun kirpimi + 4x cubuklar) + out/ozet_1x.png (gercek boy, 1080p'de oyunda gorunen)
import json
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
PROJ = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
STYLES = [
    ("simdi", "ŞU AN", "kalın siyah çerçeve, hafif yuvarlak köşe, üst parlama şeridi"),
    ("A", "A - Pirinç Kapaklı", "oyuncu panelindeki çubuğun küçük eşi: perçinli pirinç kapaklar, sıvı yüzeyi"),
    ("B", "B - Ahşap Levha", "iki çubuk tek ahşap levhada, basamaklı köşe, arada ahşap ayraç"),
    ("C", "C - İnce Hat", "sade: 1 px sıcak kontur, kesik köşe, iki çubuk arası nefes"),
    ("D", "D - Kabartma Bölme", "her 40 can kabartma karo, boşlar oyuk yuva, kalkan tek plaka"),
]
# ub_konum.json sirasi (ust_bar_capture.gd _bars): yerel oyuncu, Mira, Kerem
NAMES = ["sen (Oakley) %72 + kalkan", "Mira (Büyücü) %35 + kalkan", "Kerem (Korsan) %16, 900 can"]
DEFAULT_BARS = [[960, 472], [816, 484], [1104, 484]]
TRIO = (730, 430, 1190, 575)  # 460 x 145
BG = (28, 22, 17)
INK = (236, 222, 196)
DIM = (176, 156, 124)
GOLD = (222, 178, 92)


def font(size):
    p = os.path.join(PROJ, "assets", "fonts", "m5x7.ttf")
    return ImageFont.truetype(p, size) if os.path.exists(p) else ImageFont.load_default()


def bars_of(info, st):
    return info.get(st, {}).get("bars", DEFAULT_BARS)


def main():
    info = {}
    jp = os.path.join(OUT, "ub_konum.json")
    if os.path.exists(jp):
        with open(jp, encoding="utf-8") as f:
            info = json.load(f)
    f_title, f_lbl, f_sub = font(48), font(32), font(16)
    trio_w, trio_h = (TRIO[2] - TRIO[0]) * 2, (TRIO[3] - TRIO[1]) * 2
    bar_w, bar_h = 54 * 4, 24 * 4
    row_h = 44 + max(trio_h, 3 * bar_h + 2 * 22)
    W = 24 + trio_w + 24 + bar_w + 24
    H = 70 + len(STYLES) * (row_h + 18)
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((24, 12), "KARAKTER ÜSTÜ CAN / KALKAN ÇUBUĞU - 4 prototip (gerçek oyun, gündüz)", font=f_title, fill=GOLD)
    y = 70
    small = []
    for st, name, sub in STYLES:
        p = os.path.join(OUT, "ub_%s.png" % st)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        d.text((24, y), name, font=f_lbl, fill=GOLD if st != "simdi" else INK)
        d.text((24 + d.textlength(name, font=f_lbl) + 18, y + 12), sub, font=f_sub, fill=DIM)
        trio = im.crop(TRIO)
        small.append((name, trio))
        sheet.paste(trio.resize((trio_w, trio_h), Image.NEAREST), (24, y + 40))
        bx = 24 + trio_w + 24
        for k, i in enumerate([0, 1, 2]):  # once sen, sonra Mira, Kerem
            x, yy = bars_of(info, st)[i]
            c = im.crop((int(x) - 27, int(yy) - 4, int(x) + 27, int(yy) + 20)).resize((bar_w, bar_h), Image.NEAREST)
            ty = y + 40 + k * (bar_h + 22)
            d.text((bx, ty - 2), NAMES[i], font=f_sub, fill=DIM)
            sheet.paste(c, (bx, ty + 14))
        y += row_h + 18
    sheet.save(os.path.join(OUT, "ozet.png"))
    # gercek boy: 1080p'de oyunda nasil gorunuyorsa
    tw, th = TRIO[2] - TRIO[0], TRIO[3] - TRIO[1]
    one = Image.new("RGB", (tw * 2 + 36, 44 + ((len(small) + 1) // 2) * (th + 36)), BG)
    d1 = ImageDraw.Draw(one)
    d1.text((12, 6), "GERÇEK BOY (1080p, 1:1)", font=f_lbl, fill=GOLD)
    for i, (name, trio) in enumerate(small):
        cx = 12 + (i % 2) * (tw + 12)
        cy = 44 + (i // 2) * (th + 36)
        d1.text((cx, cy), name, font=f_sub, fill=INK)
        one.paste(trio, (cx, cy + 18))
    one.save(os.path.join(OUT, "ozet_1x.png"))
    print("yazildi:", os.path.join(OUT, "ozet.png"), os.path.join(OUT, "ozet_1x.png"))


if __name__ == "__main__":
    main()
