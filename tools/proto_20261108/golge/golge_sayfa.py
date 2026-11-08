# GOLGE acik/kapali karsilastirma sayfalari (golge_capture.gd ciktisindan, 2026-11-08).
# Calistir: python -I tools/proto_20261108/golge/golge_sayfa.py
# Cikti: out/sayfa_<nokta>.jpg (2x2: hal basina bir kare) + out/ozet.jpg (her noktadan 1 ve 4 yan yana, kucuk)
# -*- coding: utf-8 -*-
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
PROJ = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SPOTS = ["ev", "kuzey_agaclar", "orta_orman", "gol"]
SPOT_NAMES = {"ev": "Evin önü", "kuzey_agaclar": "Kuzey ağaçlıkları", "orta_orman": "Orta orman", "gol": "Göl kıyısı"}
STATES = [
    ("1_hepsi_acik", "1  HEPSİ AÇIK  (Yüksek kalite, bugünkü varsayılan)"),
    ("2_bulut_kapali", "2  BULUT GÖLGESİ KAPALI  (ayardaki düğme kapalı = Orta / Düşük)"),
    ("3_harita_kapali", "3  + HARİTA GÖLGELERİ KAPALI  (ayarı yok, sadece görmek için)"),
    ("4_hic_golge", "4  HİÇ GÖLGE YOK  (+ karakter ayak gölgesi; ayarı yok)"),
]
BG = (28, 22, 17)
INK = (236, 222, 196)
GOLD = (222, 178, 92)


def font(size):
    for p in [os.path.join(PROJ, "assets", "fonts", "m5x7.ttf"), "C:/Windows/Fonts/consola.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def label_strip(w, text, size=32, color=INK):
    s = Image.new("RGB", (w, size + 16), BG)
    ImageDraw.Draw(s).text((12, 4), text, font=font(size), fill=color)
    return s


def tile(spot, key, title):
    im = Image.open(os.path.join(OUT, "%s_%s.png" % (spot, key))).convert("RGB")
    lab = label_strip(im.width, title)
    t = Image.new("RGB", (im.width, im.height + lab.height), BG)
    t.paste(lab, (0, 0))
    t.paste(im, (0, lab.height))
    return t


def main():
    gap = 12
    for spot in SPOTS:
        tiles = [tile(spot, k, n) for k, n in STATES]
        tw, th = tiles[0].size
        head = label_strip(tw * 2 + gap * 3, "GÖLGELER - " + SPOT_NAMES[spot], 48, GOLD)
        page = Image.new("RGB", (tw * 2 + gap * 3, head.height + th * 2 + gap * 3), BG)
        page.paste(head, (0, 0))
        for i, t in enumerate(tiles):
            page.paste(t, (gap + (i % 2) * (tw + gap), head.height + gap + (i // 2) * (th + gap)))
        page.save(os.path.join(OUT, "sayfa_%s.jpg" % spot), quality=90)
    # Ozet: her nokta icin 1 (hepsi acik) | 2 (bulut kapali) | 4 (hic golge), yarim boy.
    rows = []
    for spot in SPOTS:
        ims = []
        for k, n in [STATES[0], STATES[1], STATES[3]]:
            im = Image.open(os.path.join(OUT, "%s_%s.png" % (spot, k))).convert("RGB")
            ims.append(im.resize((im.width // 2, im.height // 2), Image.LANCZOS))
        w, h = ims[0].size
        r = Image.new("RGB", (w * 3 + gap * 4, h + gap), BG)
        for i, im in enumerate(ims):
            r.paste(im, (gap + i * (w + gap), gap))
        rows.append(r)
    head = label_strip(rows[0].width, "1 HEPSİ AÇIK            2 BULUT GÖLGESİ KAPALI            4 HİÇ GÖLGE", 32, GOLD)
    oz = Image.new("RGB", (rows[0].width, head.height + sum(r.height for r in rows) + gap), BG)
    oz.paste(head, (0, 0))
    y = head.height
    for r in rows:
        oz.paste(r, (0, y))
        y += r.height
    oz.save(os.path.join(OUT, "ozet.jpg"), quality=88)
    # Yakin cekim: karakterin cevresi 2x (en yakin komsu) - harita + ayak golgesi farki tam boyda zor seciliyor.
    for spot in ["kuzey_agaclar", "orta_orman"]:
        tiles = []
        for k, n in STATES:
            im = Image.open(os.path.join(OUT, "%s_%s.png" % (spot, k))).convert("RGB")
            cx, cy = im.width // 2, im.height // 2
            c = im.crop((cx - 300, cy - 170, cx + 300, cy + 168)).resize((1200, 676), Image.NEAREST)
            lab = label_strip(c.width, n)
            t = Image.new("RGB", (c.width, c.height + lab.height), BG)
            t.paste(lab, (0, 0))
            t.paste(c, (0, lab.height))
            tiles.append(t)
        tw, th = tiles[0].size
        head = label_strip(tw * 2 + gap * 3, "YAKIN ÇEKİM (2x) - " + SPOT_NAMES[spot], 48, GOLD)
        page = Image.new("RGB", (tw * 2 + gap * 3, head.height + th * 2 + gap * 3), BG)
        page.paste(head, (0, 0))
        for i, t in enumerate(tiles):
            page.paste(t, (gap + (i % 2) * (tw + gap), head.height + gap + (i // 2) * (th + gap)))
        page.save(os.path.join(OUT, "yakin_%s.jpg" % spot), quality=90)
    print("yazildi", OUT)


if __name__ == "__main__":
    main()
