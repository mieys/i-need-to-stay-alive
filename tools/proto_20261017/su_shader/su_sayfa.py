"""Su shader prototipleri karşılaştırma sayfaları (2026-10-17, oyuna bağlı DEĞİL).

Girdi : out/kare/<nokta>_<ad>_<i>.png (su_capture.gd, SU_FRAMES=36 -> CROPS bölgesi, 1 px = 1 dünya px)
Çıktı : out/su_<nokta>.gif  - Mevcut + A-D, 3x2 ızgara, 2x büyütme (= oyundaki boyut, kamera x2), 1/12 sn kare
        out/su_ozet.png     - 3 nokta x 5 sürüm ilk kare, 1x
        out/su_D_v2.gif     - D göz yorgunluğu düzeltmesi: 3 nokta (satır) x Mevcut / D v1 / D v2, 2x
        out/su_C_v2.gif     - C "baloncuk" düzeltmesi: 3 nokta (satır) x Mevcut / C v1 / C v2, 2x
        out/su2_<nokta>.gif - 2. set (Mevcut + E-H), `python su_sayfa.py 2`
        out/su_C_akinti.gif - C ilk hali / C3 akıntılı / C4 akıntıya dönük, 3 nokta, `python su_sayfa.py c3`
Çalıştır: python tools/proto_20261017/su_shader/su_sayfa.py [1|2|c3]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SPOTS = ["gol", "nehir", "kuzeydogu"]
VARIANTS = [
    ("0_mevcut", "Mevcut"),
    ("A_kiyi_kopugu", "A  Kıyı Köpüğü"),
    ("B_isik_agi", "B  Işık Ağı"),
    ("C_dalgacik", "C  Dalgacık"),
    ("D_derin_gol", "D  Derin Göl"),
]
NOTES = [
    "A  derinlik kademesi + kıyı köpüğü,",
    "   kıyıya yürüyen kesik dalgalar",
    "B  dibe vuran ışık bantları (kostik),",
    "   berrak, dip daha çok görünür",
    "C  el çizimi dalga sırtları + akıntı,",
    "   kıyıya gelip giden yalama çizgisi",
    "D  dip kırılması (dip dalgalanır) +",
    "   bulut yansıması + güneş pırıltısı",
]
VARIANTS2 = [
    ("0_mevcut", "Mevcut"),
    ("E_kontur", "E  Kontur Bantları"),
    ("F_akan_nehir", "F  Akan Nehir"),
    ("G_esinti", "G  Esinti"),
    ("H_sakin_kirilma", "H  Sakin Kırılma"),
]
NOTES2 = [
    "E  kıyıya paralel temiz renk bantları,",
    "   sınır çizgileri yavaşça nefes alır",
    "F  dere akış yönünde sürüklenen doku,",
    "   ortada hızlı, kıyıda durgun",
    "G  cam gibi durgun su, üstünden",
    "   yavaşça geçen rüzgâr lekeleri",
    "H  sadece dip çok yavaş dalgalanır,",
    "   temiz derinlik tonları",
    "(hepsi noktasız / dither'sız)",
]
SCALE = 2
LABEL_H = 22
BG = (24, 22, 20)
FG = (236, 226, 204)


def font(size: int) -> ImageFont.FreeTypeFont:
    for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def frame_count(spot: str) -> int:
    n = 0
    while os.path.exists(os.path.join(OUT, "kare", f"{spot}_0_mevcut_{n:02d}.png")):
        n += 1
    return n


def grid_frame(spot: str, i: int, f_lab, f_note, variants=VARIANTS, notes=NOTES) -> Image.Image:
    first = Image.open(os.path.join(OUT, "kare", f"{spot}_0_mevcut_00.png"))
    pw, ph = first.width * SCALE, first.height * SCALE
    sheet = Image.new("RGB", (pw * 3, (ph + LABEL_H) * 2), BG)
    d = ImageDraw.Draw(sheet)
    for k, (key, label) in enumerate(variants):
        im = Image.open(os.path.join(OUT, "kare", f"{spot}_{key}_{i:02d}.png")).convert("RGB")
        im = im.resize((pw, ph), Image.NEAREST)
        x, y = (k % 3) * pw, (k // 3) * (ph + LABEL_H)
        sheet.paste(im, (x, y + LABEL_H))
        d.text((x + 8, y + 2), label, fill=FG, font=f_lab)
    x0, y0 = 2 * pw + 14, ph + LABEL_H + LABEL_H + 6
    for j, line in enumerate(notes):
        d.text((x0, y0 + j * 26), line, fill=(200, 190, 170) if line.startswith(" ") else FG, font=f_note)
    return sheet


def main() -> None:
    f_lab = font(15)
    f_note = font(16)
    if len(sys.argv) > 1 and sys.argv[1] == "c3":
        compare(f_lab, [("C1_dalgacik_v1", "C ilk hali (akıntı yok)"), ("C3_akintili", "C3 akıntılı (şekil aynı)"),
                        ("C4_akintiya_donuk", "C4 akıntıya dönük")], "su_C_akinti.gif")
        return
    if len(sys.argv) > 1 and sys.argv[1] == "2":
        for spot in SPOTS:
            n = frame_count(spot)
            frames = [grid_frame(spot, i, f_lab, f_note, VARIANTS2, NOTES2).convert("P", palette=Image.ADAPTIVE, colors=255, dither=Image.Dither.NONE)
                      for i in range(n)]
            path = os.path.join(OUT, f"su2_{spot}.gif")
            frames[0].save(path, save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=1)
            print(path, n, "kare", os.path.getsize(path) // 1024, "KB")
        return
    for spot in SPOTS:
        n = frame_count(spot)
        frames = [grid_frame(spot, i, f_lab, f_note).convert("P", palette=Image.ADAPTIVE, colors=255, dither=Image.Dither.NONE)
                  for i in range(n)]
        path = os.path.join(OUT, f"su_{spot}.gif")
        frames[0].save(path, save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=1)
        print(path, n, "kare", os.path.getsize(path) // 1024, "KB")

    first = Image.open(os.path.join(OUT, "kare", "gol_0_mevcut_00.png"))
    cw, ch = first.width, first.height
    sheet = Image.new("RGB", (cw * 5, (ch + LABEL_H) * 3), BG)
    d = ImageDraw.Draw(sheet)
    for r, spot in enumerate(SPOTS):
        for c, (key, label) in enumerate(VARIANTS):
            im = Image.open(os.path.join(OUT, "kare", f"{spot}_{key}_00.png")).convert("RGB")
            sheet.paste(im, (c * cw, r * (ch + LABEL_H) + LABEL_H))
            d.text((c * cw + 6, r * (ch + LABEL_H) + 2), label, fill=FG, font=f_lab)
    sheet.save(os.path.join(OUT, "su_ozet.png"))
    print("su_ozet.png", sheet.size)
    compare(f_lab, [("0_mevcut", "Mevcut"), ("D1_derin_gol_v1", "D önceki (v1)"), ("D_derin_gol", "D yeni (v2) - daha sakin")], "su_D_v2.gif")
    compare(f_lab, [("0_mevcut", "Mevcut"), ("C1_dalgacik_v1", "C önceki (v1)"), ("C_dalgacik", "C yeni (v2) - dalga sırtları")], "su_C_v2.gif")


def compare(f_lab, cols: list, name: str) -> None:
    first = Image.open(os.path.join(OUT, "kare", "gol_0_mevcut_00.png"))
    pw, ph = first.width * SCALE, first.height * SCALE
    n = frame_count("gol")
    frames = []
    for i in range(n):
        sheet = Image.new("RGB", (pw * 3, (ph + LABEL_H) * len(SPOTS)), BG)
        d = ImageDraw.Draw(sheet)
        for r, spot in enumerate(SPOTS):
            for c, (key, label) in enumerate(cols):
                im = Image.open(os.path.join(OUT, "kare", f"{spot}_{key}_{i:02d}.png")).convert("RGB").resize((pw, ph), Image.NEAREST)
                sheet.paste(im, (c * pw, r * (ph + LABEL_H) + LABEL_H))
                d.text((c * pw + 8, r * (ph + LABEL_H) + 2), label, fill=FG, font=f_lab)
        frames.append(sheet.convert("P", palette=Image.ADAPTIVE, colors=255, dither=Image.Dither.NONE))
    path = os.path.join(OUT, name)
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=83, loop=0, disposal=1)
    print(path, n, "kare", os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main()
