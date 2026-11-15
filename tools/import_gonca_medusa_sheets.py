"""Zehirli Gonca (Kara Bataklık K5 bossu) + Filiz (yavrusu) + Medusa (Altın Kumlar K10 / son bossu) sprite sayfalarını projeye alır (madde 682).

Kaynak: masaüstündeki `2 yeni boss` klasörünün iki zip'i (açılmış hâli argüman olarak verilir):
  `Flower monster.zip`  -> light outline/200% (128x128) + plant shot/200% (36x40)
  `Medusa - spritesheets (light outline added).zip` -> light outline/200% (128x128)
Balkabağı Kafa ile aynı ressam / aynı düzen: paketin satır sırası aşağı, SOL, SAĞ, YUKARI. Projenin sırası aşağı, YUKARI, SOL, SAĞ (enemy.gd ROW_*)
-> yeni satır <- kaynak satır: 0<-0, 1<-3, 2<-1, 3<-2. Hücre 128 (200% sanat; sahnede 0,8 ölçek = Balkabağı ile aynı piksel yoğunluğu).
Çiçeğin yürüme sayfası YOK (yerinden kıpırdamaz): yürüme = bekleme sayfası.

Kullanım:  python -I tools/import_gonca_medusa_sheets.py <cicek_klasoru> <medusa_klasoru>   sonra Godot'u bir kez `--headless --import` ile aç.
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
ROW_MAP = [0, 3, 1, 2]

GONCA = {
    "gonca_idle.png": "flower monster - idle.png",
    "gonca_walk.png": "flower monster - idle.png",
    "gonca_attack.png": "flower monster - attack 1.png",  ## dikenli kolları kıvırıp pembe halka: ısırık + Diken Halkası
    "gonca_spit.png": "flower monster - attack 2.png",  ## başını soğana çekip tohum tükürür
    "gonca_grow.png": "flower monster - grow.png",  ## topraktan çıkış (filiz doğuşu, Kök Göçü sonrası)
    "gonca_hurt.png": "flower monster - hit.png",
    "gonca_death.png": "flower monster - death.png",  ## solup kurur
}
MEDUSA = {
    "medusa_walk.png": "medusa - move.png",
    "medusa_idle.png": "medusa - idle.png",
    "medusa_gaze.png": "medusa - gaze attack.png",  ## taşlaştıran bakış (beyaz yay dalgaları dahil)
    "medusa_snake.png": "medusa - snake attack.png",  ## saçındaki yılanlar ileri atılır
    "medusa_hurt.png": "medusa - hit.png",
    "medusa_death.png": "medusa - death.png",  ## taş kozaya döner
}
SEED = {
    "seed_loop.png": "plant shot - loop.png",
    "seed_end.png": "plant shot - ending.png",
}


def repack(src_path, dst_path, cell):
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    assert h == cell * 4 and w % cell == 0, f"{src_path}: beklenmeyen boyut {im.size}"
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for new_row, src_row in enumerate(ROW_MAP):
        out.paste(im.crop((0, src_row * cell, w, (src_row + 1) * cell)), (0, new_row * cell))
    out.save(dst_path)
    return w // cell


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    flower_src, medusa_src = sys.argv[1], sys.argv[2]
    g_dir = os.path.join(flower_src, "light outline", "200% (128x128)")
    s_dir = os.path.join(flower_src, "plant shot", "200% (36x40)")
    m_dir = os.path.join(medusa_src, "light outline", "200% (128x128)")
    out_g = os.path.join(ROOT, "enemies", "gonca")
    out_m = os.path.join(ROOT, "enemies", "medusa")
    out_f = os.path.join(ROOT, "fx", "gonca")
    for d in (out_g, out_m, out_f):
        os.makedirs(d, exist_ok=True)
    for dst, src in GONCA.items():
        print(dst, repack(os.path.join(g_dir, src), os.path.join(out_g, dst), 128), "kare")
    for dst, src in MEDUSA.items():
        print(dst, repack(os.path.join(m_dir, src), os.path.join(out_m, dst), 128), "kare")
    ## tohum: tek satır, 36x40 kare (uçuş döngüsü 3, patlama 3); sağa bakar
    for dst, src in SEED.items():
        im = Image.open(os.path.join(s_dir, src)).convert("RGBA")
        assert im.size[1] == 40 and im.size[0] % 36 == 0, f"{src}: {im.size}"
        im.save(os.path.join(out_f, dst))
        print(dst, im.size[0] // 36, "kare")


if __name__ == "__main__":
    main()
