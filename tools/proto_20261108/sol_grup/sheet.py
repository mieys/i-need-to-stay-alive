# Sol ust + grup paneli + Hasar + bildirim prototipleri (madde 480) ozet sayfasi: hud_capture.gd SOLG=<simdi|A..D> cekimlerinden
# (hud_yeni/out/solg_<X>.png) sol ust + sag sutun kirpilir, 1:1 (gercek boy). Cikti: sol_grup/out/ozet.png
#   python -I tools/proto_20261108/sol_grup/sheet.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..")
SRC = os.path.join(HERE, "..", "hud_yeni", "out")
NAMES = [("simdi", "SU AN"), ("A", "A - Ayri Tepsiler"), ("B", "B - Tek Konsol"), ("C", "C - Gomme Kuyular"), ("D", "D - Pirinc Percin")]
NOTES = ["Hepsi oyuncu panelinin malzemesi (Gomme Tepsi):",
         "yan kutu dokusu, yuva cercevesi, koyu kuyu, cubuk pirinci.",
         "Cubuklar, minimap, alt panel gercek oyun.",
         "Yazi m5x7 32, sayi PixeloidSans 18; 1 sanat px = 3 ekran px.",
         "Bildirimler: satici geldi + sayacli gorev uyarisi (gercek).",
         "",
         "A: her parca ayri tepsi (paneldeki yan kutu gibi)",
         "B: sol ust tek konsol, grup tek uzun tepsi + Hasar sekmesi",
         "C: ahsap kutu yok - kare yuva + koyu gomme kuyular",
         "D: A + pirinc perçin, pirinc kapakli kuyular, ad sekmesi"]


def main():
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "m5x7.ttf"), 32)
    tiles = []
    for key, label in NAMES:
        im = Image.open(os.path.join(SRC, "solg_%s.png" % key)).convert("RGB")
        a = im.crop((0, 0, 300, 250))
        b = im.crop((1500, 180, 1920, 620))
        t = Image.new("RGB", (300 + 16 + 420, 44 + 440), (23, 17, 12))
        ImageDraw.Draw(t).text((4, 4), label, fill=(240, 192, 112), font=font)
        t.paste(a, (0, 44))
        t.paste(b, (316, 44))
        tiles.append(t)
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * 2 + 24, (h + 20) * 3), (23, 17, 12))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * (w + 24), (i // 2) * (h + 20)))
    d = ImageDraw.Draw(sheet)
    x0, y0 = w + 24 + 8, 2 * (h + 20) + 50
    for j, line in enumerate(NOTES):
        d.text((x0, y0 + j * 34), line, fill=(232, 214, 180), font=font)
    out = os.path.join(HERE, "out", "ozet.png")
    sheet.save(out)
    print("ok", sheet.size, out)


if __name__ == "__main__":
    main()
