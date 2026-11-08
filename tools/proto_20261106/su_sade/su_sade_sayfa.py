"""SADE SU prototipleri karşılaştırma sayfaları (2026-11-06, oyuna bağlı DEĞİL).

Girdi : out/kare/<nokta>_<ad>_<i>.png (su_sade_capture.gd, CROPS bölgesi, 1 px = 1 dünya px)
Çıktı : out/su_sade_<nokta>.gif - Şu an + A-D, 3x2 ızgara, 2x (= oyundaki boyut, kamera x2), 1/12 sn kare
        out/su_sade_ozet.png    - 3 nokta x 5 sürüm ilk kare, 2x
        konsol: kare başı değişen piksel oranı (sadelik ölçüsü; yüksek = hareketli)
Çalıştır: python -I tools/proto_20261106/su_sade/su_sade_sayfa.py
"""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SPOTS = ["gol", "nehir", "kuzeydogu"]
VARIANTS = [
    ("0_simdi", "ŞU AN  (C3 Akıntılı Dalgacık)"),
    ("A_yavas_isik", "A  Yavaş Işık"),
    ("B_seyrek_dalgacik", "B  Seyrek Dalgacık"),
    ("C_akinti_cizgisi", "C  Akıntı Çizgileri"),
    ("D_kiyi_nefesi", "D  Kıyı Nefesi"),
]
NOTES = [
    "Hepsi: suyun kendi rengi (derinlik tonu yok),",
    "   1 px kıyı çizgisi, nokta yok",
    "A  büyük açık lekeler yavaşça geçer,",
    "   küçük öğe hiç yok",
    "B  şu anki dalgacık şekli, yarısından az,",
    "   gölgesiz + sönük, akıntıyla kayar",
    "C  düz 1 px kısa çizgiler,",
    "   akıntıyla kayıp söner",
    "D  ortası durgun; kıyıda tek çizgi",
    "   yavaşça açılıp geri gelir",
]
SCALE = 2
LABEL_H = 22
BG = (24, 22, 20)
FG = (236, 226, 204)
SUB = (200, 190, 170)


def font(size: int) -> ImageFont.FreeTypeFont:
    for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def path(spot: str, key: str, i: int) -> str:
    return os.path.join(OUT, "kare", f"{spot}_{key}_{i:02d}.png")


def frame_count(spot: str) -> int:
    n = 0
    while os.path.exists(path(spot, "0_simdi", n)):
        n += 1
    return n


def grid_frame(spot: str, i: int, f_lab, f_note) -> Image.Image:
    first = Image.open(path(spot, "0_simdi", 0))
    pw, ph = first.width * SCALE, first.height * SCALE
    sheet = Image.new("RGB", (pw * 3, (ph + LABEL_H) * 2), BG)
    d = ImageDraw.Draw(sheet)
    for k, (key, label) in enumerate(VARIANTS):
        im = Image.open(path(spot, key, i)).convert("RGB").resize((pw, ph), Image.NEAREST)
        x, y = (k % 3) * pw, (k // 3) * (ph + LABEL_H)
        sheet.paste(im, (x, y + LABEL_H))
        d.text((x + 8, y + 2), label, fill=FG, font=f_lab)
    x0, y0 = 2 * pw + 14, ph + LABEL_H + 12
    for j, line in enumerate(NOTES):
        d.text((x0, y0 + j * 26), line, fill=SUB if line.startswith(" ") else FG, font=f_note)
    return sheet


def change_ratio(spot: str, key: str, n: int) -> float:
    tot = 0.0
    prev = Image.open(path(spot, key, 0)).convert("RGB")
    for i in range(1, n):
        cur = Image.open(path(spot, key, i)).convert("RGB")
        diff = ImageChops.difference(prev, cur).convert("L").point(lambda v: 255 if v > 2 else 0)
        tot += diff.histogram()[255] / (cur.width * cur.height)
        prev = cur
    return tot / max(1, n - 1)


def main() -> None:
    f_lab = font(15)
    f_note = font(16)
    for spot in SPOTS:
        n = frame_count(spot)
        if n < 2:
            continue
        frames = [grid_frame(spot, i, f_lab, f_note).convert("P", palette=Image.ADAPTIVE, colors=255, dither=Image.Dither.NONE)
                  for i in range(n)]
        p = os.path.join(OUT, f"su_sade_{spot}.gif")
        frames[0].save(p, save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=1)
        print(p, n, "kare", os.path.getsize(p) // 1024, "KB")
        print("  kare basi degisen piksel:", ", ".join(f"{k} %{change_ratio(spot, k, n) * 100:.2f}" for k, _ in VARIANTS))

    first = Image.open(path("gol", "0_simdi", 0))
    cw, ch = first.width * SCALE, first.height * SCALE
    sheet = Image.new("RGB", (cw * 5, (ch + LABEL_H) * 3), BG)
    d = ImageDraw.Draw(sheet)
    for r, spot in enumerate(SPOTS):
        for c, (key, label) in enumerate(VARIANTS):
            im = Image.open(path(spot, key, 0)).convert("RGB").resize((cw, ch), Image.NEAREST)
            sheet.paste(im, (c * cw, r * (ch + LABEL_H) + LABEL_H))
            d.text((c * cw + 6, r * (ch + LABEL_H) + 2), label, fill=FG, font=f_lab)
    sheet.save(os.path.join(OUT, "su_sade_ozet.png"))
    print("su_sade_ozet.png", sheet.size)


if __name__ == "__main__":
    main()
