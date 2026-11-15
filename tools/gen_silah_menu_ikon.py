#!/usr/bin/env python3
"""Tüfek + Pompalı Tüfek MENÜ ikonları: yatay çizimi diğer silahlar gibi ÇAPRAZ (namlu sağ-üst) 48x48 tuvale döndürür.

Neden: seçim ekranındaki `DK.icon` ikonu yalnız TAM KATLARDA büyütür (menu_dark_kit.gd). 64x32 / 64x64 yatay çizim 96 kutuda 1x kalıyor
(içerik ~12 px yüksek, "çok ufak"); diğer silahlar 32x32 çapraz olduğundan 3x oluyor. 48x48 tuval 96 kutuda tam 2x (telefon 144'te 3x).
Oyundaki silah dokusu (assets/weapons/yeni/tufek.png, pompali/icon.png; FORWARD 0 = namlu sağa) DEĞİŞMEZ - bunlar yalnız menü ikonu
(`WeaponCatalog.menu_icon`).

Döndürme: ters eşlemeli, çıkış pikseli başına 4x4 alt örnek, renklerin ÇOĞUNLUĞU (yeni renk üretilmez, kenar yumuşatma yok) - piksel sanatı kalır.

  python -I tools/gen_silah_menu_ikon.py            # PNG'leri yazar
  python -I tools/gen_silah_menu_ikon.py --onizle F # F yoluna karşılaştırma sayfası da yazar
"""
import math
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILE = 48          # 96 kutuda 2x
FILL = 44          # çapraz içerik sınırlayıcı kutusu (tuvalde 2 px boşluk = 96'da 4 px)
SS = 4             # alt örnek ızgarası (SS x SS)

JOBS = {
    "tufek": (ROOT / "assets/weapons/yeni/tufek.png", ROOT / "assets/weapons/yeni/tufek_menu.png"),
    "pompali": (ROOT / "assets/weapons/pompali/icon.png", ROOT / "assets/weapons/pompali/menu.png"),
    "makineli": (ROOT / "assets/weapons/makineli/icon.png", ROOT / "assets/weapons/makineli/menu.png"), ## madde 652
}


def rotate_fit(src: Image.Image) -> Image.Image:
    """İki geçiş: dikdörtgen sınırına göre ilk ölçek, sonra GERÇEK şeklin sınırlayıcı kutusu FILL'e oturacak şekilde yeniden ölçek +
    tam piksel kaydırarak tuvale ortalama."""
    src = src.convert("RGBA")
    box = src.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()
    crop = src.crop(box)
    w, h = crop.size
    f0 = FILL / ((w + h) * math.sqrt(0.5))   # kaynak pikseli başına çıkış pikseli (dikdörtgen için güvenli)
    first = _render(crop, f0)
    bb = first.getchannel("A").getbbox()
    f1 = f0 * FILL / float(max(bb[2] - bb[0], bb[3] - bb[1]))
    out = _render(crop, f1)
    bb = out.getchannel("A").getbbox()
    shift = (round(TILE / 2.0 - (bb[0] + bb[2]) / 2.0), round(TILE / 2.0 - (bb[1] + bb[3]) / 2.0))
    moved = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    moved.paste(out, shift, out)
    return moved


def _render(crop: Image.Image, f: float) -> Image.Image:
    w, h = crop.size
    px = crop.load()
    c = s = math.sqrt(0.5)
    out = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    op = out.load()
    scx, scy = w / 2.0, h / 2.0
    for oy in range(TILE):
        for ox in range(TILE):
            votes: Counter = Counter()
            opaque = 0
            for j in range(SS):
                for i in range(SS):
                    dx = ox + (i + 0.5) / SS - TILE / 2.0
                    dy = oy + (j + 0.5) / SS - TILE / 2.0
                    # ters dönüş: src = R^T * out (R: x ekseni -> sağ-üst)
                    sx = (c * dx - s * dy) / f + scx
                    sy = (s * dx + c * dy) / f + scy
                    ix, iy = int(math.floor(sx)), int(math.floor(sy))
                    if 0 <= ix < w and 0 <= iy < h:
                        p = px[ix, iy]
                        if p[3] >= 128:
                            opaque += 1
                            votes[p[:3]] += 1
            if opaque * 2 >= SS * SS:
                r, g, b = votes.most_common(1)[0][0]
                op[ox, oy] = (r, g, b, 255)
    return out


def main() -> None:
    for key, (src_path, dst_path) in JOBS.items():
        img = rotate_fit(Image.open(src_path))
        img.save(dst_path)
        print(key, "->", dst_path.relative_to(ROOT), img.getchannel("A").getbbox())
    if "--onizle" in sys.argv:
        out_path = Path(sys.argv[sys.argv.index("--onizle") + 1])
        # Yan yana: Bıçak / Uzunkılıç (3x, 96) | Tüfek eski (1x) / yeni (2x) | Pompalı eski / yeni
        names = [("bicak", ROOT / "assets/weapons/yeni/bicak.png", 3), ("uzunkilic", ROOT / "assets/weapons/yeni/uzunkilic.png", 3),
                 ("tufek-eski", JOBS["tufek"][0], 1), ("tufek-yeni", JOBS["tufek"][1], 2),
                 ("pompali-eski", JOBS["pompali"][0], 1), ("pompali-yeni", JOBS["pompali"][1], 2)]
        sheet = Image.new("RGBA", (6 * 112, 112), (52, 36, 26, 255))
        for n, (_, p, k) in enumerate(names):
            im = Image.open(p).convert("RGBA")
            im = im.resize((im.width * k, im.height * k), Image.NEAREST)
            tile_x = n * 112 + 8
            sheet.alpha_composite(im, (tile_x + (96 - im.width) // 2, 8 + (96 - im.height) // 2))
            # 96 kutunun çerçevesi (içeriğin kutuya değip değmediğini görmek için)
            for t in range(96):
                for (xx, yy) in ((tile_x + t, 8), (tile_x + t, 103), (tile_x, 8 + t), (tile_x + 95, 8 + t)):
                    sheet.putpixel((xx, yy), (120, 90, 60, 255))
        sheet.save(out_path)
        print("önizleme:", out_path)


if __name__ == "__main__":
    main()
