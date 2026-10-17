"""HUD TEMA prototipi (2026-10-17) - karşılaştırma sayfaları. Oyuna bağlı DEĞİL.

Girdi: hud_tema_capture.gd yakalamaları (out/hud_tema/simdi.png, tema_A..D.png, 1920x1080).
Çıktı: out/hud_tema/ozet.png  (tam ekranlar, yarı boyut, 2 sütun)
       out/hud_tema/yakin.png (1:1 yakın plan: sol üst + yetenek paneli + sağ sütun)
Kullanım: python tools/proto_20261017/hud_tema_sheet.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "tools", "proto_20261017", "out", "hud_tema")
FONT = os.path.join(ROOT, "assets", "fonts", "PixeloidSans-Bold.ttf")
BG = (18, 16, 14)
INK = (236, 226, 204)
DIM = (160, 148, 128)


def tr_upper(t: str) -> str:
    return t.replace("i", "İ").replace("ı", "I").upper()


def labels() -> list:
    pal = json.load(open(os.path.join(OUT, "palettes.json"), encoding="utf-8"))
    out = [("simdi", "ŞU AN", "mevcut açık ahşap kit")]
    notes = {
        "A": "koyu ahşap, soluk bronz kenar (Seyyar/Demirci dükkanlarıyla aynı aile)",
        "B": "koyu yeşil-camgöbeği (ana menü / karakter seçimiyle aynı aile)",
        "C": "koyu arduvaz zemin, soluk pirinç kenar (klasik RPG)",
        "D": "mevcut kitin kısık hâli: aynı ahşap, daha koyu ve sakin (en az değişiklik)",
    }
    for k in "ABCD":
        out.append(("tema_" + k, f"{k} - {tr_upper(pal[k]['name'])}", notes[k]))
    return out


def caption(draw: ImageDraw.ImageDraw, x: int, y: int, title: str, note: str, f1, f2) -> None:
    draw.text((x, y), title, font=f1, fill=INK)
    draw.text((x, y + 30), note, font=f2, fill=DIM)


def main() -> None:
    f1 = ImageFont.truetype(FONT, 27)
    f2 = ImageFont.truetype(FONT, 18)
    items = labels()

    # --- özet: tam ekranlar yarı boyut, 2 sütun
    tw, th, cap, gap = 960, 540, 64, 16
    cols = 2
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw + (cols + 1) * gap, rows * (th + cap) + (rows + 1) * gap), BG)
    d = ImageDraw.Draw(sheet)
    for i, (key, title, note) in enumerate(items):
        im = Image.open(os.path.join(OUT, key + ".png")).convert("RGB").resize((tw, th), Image.LANCZOS)
        x = gap + (i % cols) * (tw + gap)
        y = gap + (i // cols) * (th + cap + gap)
        caption(d, x, y, title, note, f1, f2)
        sheet.paste(im, (x, y + cap))
    sheet.save(os.path.join(OUT, "ozet.png"))

    # --- yakın plan 1:1: sol üst (envanter/altın/kıymık) + yetenek paneli + sağ sütun (minimap/grup/görev)
    crops = [(0, 0, 200, 215), (410, 880, 1300, 1080), (1600, 0, 1920, 470)]
    cw = sum(c[2] - c[0] for c in crops) + gap * (len(crops) - 1)
    ch = max(c[3] - c[1] for c in crops)
    sheet = Image.new("RGB", (cw + 2 * gap, len(items) * (ch + cap + gap) + gap), BG)
    d = ImageDraw.Draw(sheet)
    for i, (key, title, note) in enumerate(items):
        im = Image.open(os.path.join(OUT, key + ".png")).convert("RGB")
        y = gap + i * (ch + cap + gap)
        caption(d, gap, y, title, note, f1, f2)
        x = gap
        for c in crops:
            part = im.crop(c)
            # yetenek paneli alta hizalı (sağ sütun uzun)
            py = y + cap + (ch - part.height if c[1] > 500 else 0)
            sheet.paste(part, (x, py))
            x += part.width + gap
    sheet.save(os.path.join(OUT, "yakin.png"))
    print("tamam:", os.path.join(OUT, "ozet.png"), os.path.join(OUT, "yakin.png"))


if __name__ == "__main__":
    main()
