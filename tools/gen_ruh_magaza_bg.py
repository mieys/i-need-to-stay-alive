# Ruh Mağazası arka planı (2026-10-16, E tasarımı): oyunun KENDİ iç mekan sanatından kurulmuş gece dükkanı.
# Kullanıcı: "arka plan ai slop gibi, ışıklar doğru konumlandırılmamış, daha kaliteli yap" -> kodla çizilmiş desen yerine
# harita/Ev içi karoları (ahşap duvar + zemin + raf/kitaplık/fıçı/lamba) + demirci paketinin duvar meşaleleri.
# Işık: sahne karanlık ortam ışığıyla çarpılır, her ışık kaynağının havuzu TAM alevin/lamba başının pikselinde ortalanır;
# meşale/lamba sprite'ları (kendi parıltılarıyla) ışıklandırmadan SONRA, ışıksız çizilir.
# Işık ve eşyalar sadece E arayüzünün açık bıraktığı yerlerde: üst şeritte başlığın iki yanı + sol menünün altındaki köşe.
# Çıktı: 480x270 (oyunda x4 en yakın komşu = 1920x1080).
#   python tools/gen_ruh_magaza_bg.py  -> assets/ui/ruh_magaza/bg_ruh_magaza.png (oyunun kullandığı) + tools/proto_20261016/out/ruh_magaza/bg_ruh_magaza_x4.png (önizleme)
# Arayüz yerleşimi (soul_shop_screen.gd: başlık genişliği, sol menü/kart yükseklikleri) değişirse eşya/ışık koordinatları da kaydırılmalı.
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EV = os.path.join(ROOT, "harita", "Ev içi")
BS = os.path.abspath(os.path.join(ROOT, "..", "Harita içerikleri", "blacksmith", "Tiled_files"))  # proje DIŞI; sadece bu üretici okur, çıktı PNG bağımsızdır
OUT = os.path.join(ROOT, "assets", "ui", "ruh_magaza")
PREVIEW = os.path.join(ROOT, "tools", "proto_20261016", "out", "ruh_magaza")

W, H = 480, 270
WALL_Y = 4        # duvar bloğunun üstü (üstte ince tavan kirişi)
WALL_H = 48
BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def sheet(path):
    return Image.open(path).convert("RGBA")


def lit_pass(base, lights, ambient):
    """Basamaklı (titreşimli) ışık haritası ile çarpma: renk = taban * (ortam + toplam ışık)."""
    px = base.load()
    out = Image.new("RGBA", base.size)
    po = out.load()
    for y in range(H):
        for x in range(W):
            b = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0 - 0.5
            lr, lg, lb = ambient
            for (cx, cy, rad, col, inten, squash) in lights:
                dx = (x - cx)
                dy = (y - cy) / squash
                d = (dx * dx + dy * dy) ** 0.5 / rad
                if d < 1.0:
                    k = (1.0 - d) ** 1.7 * inten
                    k = max(0.0, min(1.0, int(k * 7 + b + 0.5) / 7.0))
                    lr += col[0] * k
                    lg += col[1] * k
                    lb += col[2] * k
            # kenar karartma (basamaklı)
            vx = (x / W - 0.5) * 2
            vy = (y / H - 0.5) * 2
            v = max(0.0, vx * vx * 0.35 + vy * vy * 0.45 - 0.2)
            v = int(v * 5 + b + 0.5) / 5.0 * 0.35
            r, g, bb, a = px[x, y]
            if a == 0:
                continue
            m = 1.0 - v
            po[x, y] = (min(255, int(r * min(lr, 1.35) * m)), min(255, int(g * min(lg, 1.3) * m)),
                        min(255, int(bb * min(lb, 1.3) * m)), a)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    wf = sheet(os.path.join(EV, "Interior_walls_floor.png"))
    inter = sheet(os.path.join(EV, "Interior.png"))
    iobj = sheet(os.path.join(EV, "Interior_objects.png"))
    torch = sheet(os.path.join(BS, "Torch_animation.png"))
    lightpool = sheet(os.path.join(BS, "Light_animation.png"))

    scene = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    # zemin: sıcak ahşap tahta (dikişsiz 16x16)
    floor = wf.crop((80, 16, 96, 32))
    for y in range(WALL_Y + WALL_H - 16, H, 16):
        for x in range(0, W, 16):
            scene.alpha_composite(floor, (x, y))
    # arka duvar: ahşap panel bloğu 64x48 (üst pervaz + korkuluk + süpürgelik gölgesi)
    wall = wf.crop((0, 208, 64, 256))
    for x in range(0, W, 64):
        scene.alpha_composite(wall, (x, WALL_Y))
    # tavan kirişi: duvarın en koyu tonu
    for y in range(WALL_Y):
        for x in range(W):
            scene.putpixel((x, y), (38, 22, 20, 255) if y < WALL_Y - 1 else (58, 34, 28, 255))
    # duvar dibinde zemine düşen yumuşak gölge (2 basamak)
    for y in range(WALL_Y + WALL_H, WALL_Y + WALL_H + 5):
        for x in range(W):
            r, g, b, a = scene.getpixel((x, y))
            k = 0.62 if y < WALL_Y + WALL_H + 2 else 0.8
            if y >= WALL_Y + WALL_H + 2 and (x + y) % 2 == 0:
                k = 0.7
            scene.putpixel((x, y), (int(r * k), int(g * k), int(b * k), 255))

    # eşyalar AYRI katmanda: zemine düşen lamba ışığı lekesi eşyaların ALTINDA kalsın
    props = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    def put(src, rect, x, y):
        props.alpha_composite(src.crop(rect), (x, y))

    def floor_shadow(x0, x1, y):
        for xx in range(x0 + 1, x1 - 1):
            for yy in (y, y + 1):
                if 0 <= yy < H:
                    r, g, b, a = scene.getpixel((xx, yy))
                    scene.putpixel((xx, yy), (int(r * 0.55), int(g * 0.55), int(b * 0.55), 255))

    # --- üst şerit, sol boşluk (GERİ ile başlık arası; 480'lik ölçekte x 53..187) ---
    put(inter, (146, 136, 180, 168), 57, WALL_Y + 6)      # silah rafı (kılıçlar) duvarda; sağ ucu sol menünün içinde kalsın (x <= 90)
    put(inter, (83, 202, 105, 233), 152, WALL_Y)          # tavandan sarkan kuru ot demeti
    # --- üst şerit, sağ boşluk (başlık ile bakiye arası; x 293..414) ---
    put(inter, (163, 81, 189, 125), 303, WALL_Y + WALL_H - 44 + 2)  # kitaplık duvara dayalı
    floor_shadow(303, 329, WALL_Y + WALL_H + 2)
    put(inter, (173, 188, 187, 228), 392, WALL_Y)         # sarkan sarımsak dizisi
    # --- sol alt köşe (sol menünün altı; x 8..90, y 140..262) ---
    put(inter, (53, 49, 79, 73), 12, 228)                 # üst üste sandıklar
    floor_shadow(12, 38, 252)
    put(inter, (157, 2, 173, 26), 38, 232)                # fıçı
    floor_shadow(38, 54, 256)
    put(inter, (180, 256, 189, 272), 27, 214)             # uzun sandığın üstünde kırmızı iksir

    # ışık kaynakları (alev / lamba başı pikseli). Meşale hücresi 48x48, alev ~ (24, 21).
    T1 = (120, WALL_Y + 14)
    T2 = (360, WALL_Y + 14)
    LAMP_X, LAMP_Y = 60, 206                              # ayaklı lamba sprite'ının sol üstü
    LAMP_HEAD = (LAMP_X + 10, LAMP_Y + 11)
    warm = (1.0, 0.70, 0.40)
    lights = [
        (T1[0], T1[1], 92, warm, 1.05, 0.8),
        (T2[0], T2[1], 92, warm, 1.05, 0.8),
        (LAMP_HEAD[0], LAMP_HEAD[1], 78, warm, 1.0, 0.85),
    ]
    amb = (0.30, 0.27, 0.34)
    lit = lit_pass(scene, lights, ambient=amb)
    lit_props = lit_pass(props, lights, ambient=amb)

    # ışıksız (kendi parıltılı) sprite'lar
    def emissive(src, rect, x, y, alpha=1.0):
        s = src.crop(rect)
        if alpha < 1.0:
            a = s.split()[3].point(lambda v: int(v * alpha))
            s.putalpha(a)
        lit.alpha_composite(s, (x, y))

    emissive(lightpool, (14, 4, 130, 42), LAMP_HEAD[0] - 58, LAMP_Y + 26, 0.45)  # lambanın zemine düşen ışık lekesi
    lit.alpha_composite(lit_props)
    emissive(iobj, (92, 69, 119, 112), LAMP_X, LAMP_Y)                          # ayaklı lamba
    emissive(torch, (48, 0, 96, 48), T1[0] - 24, T1[1] - 21)                    # duvar meşaleleri
    emissive(torch, (48, 0, 96, 48), T2[0] - 24, T2[1] - 21)

    lit.save(os.path.join(OUT, "bg_ruh_magaza.png"))
    os.makedirs(PREVIEW, exist_ok=True)
    lit.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(PREVIEW, "bg_ruh_magaza_x4.png"))
    print("ok", os.path.join(OUT, "bg_ruh_magaza.png"))


if __name__ == "__main__":
    main()
