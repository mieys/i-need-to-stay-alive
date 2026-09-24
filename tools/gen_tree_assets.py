#!/usr/bin/env python3
"""Görev sistemi (Ağacı Koru) için "temsili" (kullanıcı isteği: "ağaç için temsili birşey
hazırla") piksel-sanatı ağaç - gerçek büyüme-fazlı sprite paketi hâlâ bulunamadı, bu YERİNE
geçiyor (bkz. scripts/mission_tree.gd, world_event_manager.gd dosya başı notu).

Kullanım (repo kökünden):  python tools/gen_tree_assets.py

Çıktı: assets/generated/mission_tree_phase_0.png .. phase_4.png (5 büyüme fazı, hepsi AYNI
64x80 tuval - gövde tabanı hep aynı Y'de, "büyüme" hissi taç/gövdenin BÜYÜMESİYLE veriliyor,
kamera/anchor kaymasın diye). 48x48 piksel yoğunluğu kuralına uyar (bkz. hafıza "Pixel density
48x48" - kalın 2-3 px bloklar/32x32 YOK), tools/gen_shaman_assets.py'nin AYNI outline() +
elle piksel yerleştirme tekniği. Yeni PNG'ler için Godot'ta bir kez `--headless --import`
gerekir.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "generated")

W, H = 64, 80
GROUND_Y = 76  ## gövde tabanı - TÜM fazlarda sabit, sadece yukarısı büyüyor
NUM_PHASES = 5

TRUNK_D = (58, 38, 24, 255)
TRUNK = (92, 60, 34, 255)
TRUNK_L = (124, 84, 48, 255)
CANOPY_D = (28, 66, 26, 255)
CANOPY = (46, 104, 40, 255)
CANOPY_L = (76, 148, 62, 255)
CANOPY_HL = (128, 190, 96, 255)
OUTLINE_COL = (16, 12, 10, 255)


def new_canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def put(im, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        im.putpixel((x, y), color)


def outline(layer):
    """Şeffaf pikselleri, dolu bir komşusu varsa koyu bir dış çizgiyle doldurur - Shaman
    totemindeki (tools/gen_shaman_assets.py) AYNI teknik, temiz piksel-sanatı silüeti verir."""
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 0:
                    op[x, y] = OUTLINE_COL
                    break
    return out


def draw_trunk(im, trunk_h, trunk_w):
    cx = W // 2
    top = GROUND_Y - trunk_h
    half = trunk_w // 2
    for y in range(top, GROUND_Y):
        for x in range(cx - half, cx + half + 1):
            ## Sol kenar koyu, orta orta ton, sağ kenar açık - basit bir "silindir" hissi.
            if x <= cx - half:
                put(im, x, y, TRUNK_D)
            elif x >= cx + half:
                put(im, x, y, TRUNK_L)
            else:
                put(im, x, y, TRUNK)
    ## Kökler (sadece daha büyük fazlarda anlamlı görünsün diye taban genişliğine göre kısa
    ## yanal çıkıntılar).
    if trunk_w >= 4:
        for dx in range(-2, 3):
            put(im, cx + dx - half - 1, GROUND_Y - 1, TRUNK_D)
            put(im, cx + dx + half + 1, GROUND_Y - 1, TRUNK_D)


def _canopy_shape(radius_x, radius_y, center_y):
    """Organik (tam daire değil) bir taç silüeti için basit süperelips benzeri maske."""
    cx = W / 2.0
    cy = float(center_y)
    pts = []
    for y in range(int(cy - radius_y) - 1, int(cy + radius_y) + 2):
        for x in range(int(cx - radius_x) - 1, int(cx + radius_x) + 2):
            dx = (x - cx) / radius_x
            dy = (y - cy) / radius_y
            if abs(dx) ** 1.7 + abs(dy) ** 1.7 <= 1.0:
                pts.append((x, y))
    return pts


def draw_canopy(im, radius, center_y):
    ## Üç iç içe blob (arka/gölge, orta, ön/vurgu) - tek düz renkli daire yerine basit
    ## gölgeleme, "1 texel detay" hissi (bkz. hafıza "Pixel density 48x48").
    for (x, y) in _canopy_shape(radius, radius * 0.85, center_y):
        put(im, x, y, CANOPY_D)
    for (x, y) in _canopy_shape(radius * 0.86, radius * 0.74, center_y - radius * 0.08):
        put(im, x, y, CANOPY)
    for (x, y) in _canopy_shape(radius * 0.55, radius * 0.46, center_y - radius * 0.28):
        put(im, x, y, CANOPY_L)
    for (x, y) in _canopy_shape(radius * 0.28, radius * 0.22, center_y - radius * 0.42):
        put(im, x, y, CANOPY_HL)


def build_phase(i):
    t = i / float(NUM_PHASES - 1)  ## 0..1 büyüme oranı
    im = new_canvas()
    trunk_h = int(round(8 + t * 22))
    trunk_w = 2 if t < 0.35 else (4 if t < 0.7 else 6)
    canopy_r = 9 + t * 15
    canopy_cy = GROUND_Y - trunk_h - canopy_r * 0.55
    draw_trunk(im, trunk_h, trunk_w)
    draw_canopy(im, canopy_r, canopy_cy)
    return outline(im)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for i in range(NUM_PHASES):
        img = build_phase(i)
        path = os.path.join(OUT_DIR, "mission_tree_phase_%d.png" % i)
        img.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
