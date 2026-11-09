# SOHBET penceresi + balon prototipleri ozet sayfasi (2026-11-08): run.ps1 cekimlerinden (out/sohbet_<X>_oku.png / _yaz.png) sol alt pencere
# (okuma + yazma) ve iki balon (muttefik Mira + oyuncu) 1:1 kirpilir. Cikti: tools/proto_20261108/sohbet/out/ozet.png
#   python -I tools/proto_20261108/sohbet/sheet.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..")
OUT = os.path.join(HERE, "out")
NAMES = [("simdi", "SU AN"), ("A", "A - Tepsi Pencere"), ("B", "B - Serbest Seritler"), ("C", "C - Portreli Mesajlar"),
         ("D", "D - Golge Perdesi")]
WIN = (0, 560, 600, 1080)       # sol alt pencere
BUB = (330, 340, 1100, 580)     # iki balon + konusanlar
NOTES = ["Hepsi oyuncu panelinin malzemesi (Gomme Tepsi):",
         "tepsi kutusu, gomme kuyu, kabarik levha, cubuk pirinci.",
         "Yazi m5x7 32 (HUD ile ayni), adlar oyuncu renginde.",
         "Sol: okuma (Enter'a basilmamis), sag: yazarken.",
         "Balon dunyada: 1 sanat px = 1 harita pikseli.",
         "",
         "A: hep acik tepsi pencere + SOHBET basligi",
         "B: kutu yok, mesaj basina koyu serit, eskiler soner;",
         "   giris + balon can cubugu gibi pirinc kapakli",
         "C: mesaj basina yuz yuvasi + kuyruklu kutu;",
         "   balon kabarik ahsap levha (Envanter dugmesi gibi)",
         "D: kutu yok, soldan sonen koyu perde + renkli elmas;",
         "   balon cercevesiz koyu perde"]


def main():
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "m5x7.ttf"), 32)
    ww, wh = WIN[2] - WIN[0], WIN[3] - WIN[1]
    bw, bh = BUB[2] - BUB[0], BUB[3] - BUB[1]
    tw, th = ww * 2 + 16, 44 + wh + 10 + bh
    tiles = []
    for key, label in NAMES:
        oku = Image.open(os.path.join(OUT, "sohbet_%s_oku.png" % key)).convert("RGB")
        yaz = Image.open(os.path.join(OUT, "sohbet_%s_yaz.png" % key)).convert("RGB")
        t = Image.new("RGB", (tw, th), (23, 17, 12))
        d = ImageDraw.Draw(t)
        d.text((4, 4), label, fill=(240, 192, 112), font=font)
        d.text((ww + 16 + 4, 4), "yazarken", fill=(196, 176, 144), font=font)
        t.paste(oku.crop(WIN), (0, 44))
        t.paste(yaz.crop(WIN), (ww + 16, 44))
        t.paste(oku.crop(BUB), (0, 44 + wh + 10))
        tiles.append(t)
    sheet = Image.new("RGB", (tw * 2 + 24, (th + 20) * 3), (23, 17, 12))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 2) * (tw + 24), (i // 2) * (th + 20)))
    d = ImageDraw.Draw(sheet)
    x0, y0 = tw + 24 + 8, 2 * (th + 20) + 40
    for j, line in enumerate(NOTES):
        d.text((x0, y0 + j * 36), line, fill=(232, 214, 180), font=font)
    out = os.path.join(OUT, "ozet.png")
    sheet.save(out)
    sheet.resize((sheet.width // 2, sheet.height // 2), Image.NEAREST).save(os.path.join(OUT, "ozet_yarim.png"))
    print("ok", sheet.size, out)


if __name__ == "__main__":
    main()
