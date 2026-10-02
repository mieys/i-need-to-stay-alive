"""Elit yaratık aurası "B - Yükselen Kıvılcımlar" (kullanıcı seçimi 2026-10-02, 4 prototipten) -> assets/fx/elite/elite_aura.png

Sayfa: 16 kare yatay x 2 satır. Üst satır ARKA katman (yaratığın altında çizilir), alt satır ÖN katman (önünden geçen
parçacıklar). Kare 80x80 texel; 1 piksel = 1 karakter texel'i (PixelDraw.TEXEL = 1.212 dünya birimi), ayak merkezi
(FOOT_X, FOOT_Y) = (40, 60), referans ayak elipsi 22x8 texel. Kesintisiz döngü, 10 fps (scripts/elite_aura.gd).
Kurallar (hafıza): temiz alfa bantları, dither yok, parçacıklar yumuşak doğup söner, tuval kenarında kesilme yok.

Çalıştır: python tools/gen_elite_aura.py   (sonra Godot import: --headless --import)
"""
import math
import os
import random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "elite", "elite_aura.png")

N = 16
W, H = 80, 80
CX, FY = 40, 60
REF_RX, REF_RY = 22, 8

# mor palet (scripts/elite_star.gd ile aynı aile)
DEEP = (92, 34, 150)
MID = (158, 66, 235)
LIGHT = (214, 153, 255)
WHITE = (255, 245, 255)


def blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def put(img, x, y, col, a=255):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < W and 0 <= y < H and a > 0:
        if a >= img.getpixel((x, y))[3]:
            img.putpixel((x, y), (col[0], col[1], col[2], int(a)))


def quant(a):
    """Alfa'yı 4 temiz banda indir (yumuşak bitiş, gürültüsüz)."""
    a = max(0.0, min(1.0, a))
    for lv in (1.0, 0.75, 0.5, 0.25):
        if a >= lv - 0.125:
            return int(lv * 255)
    return 0


def frame(f):
    back, front = blank(), blank()
    t = f / N
    # zeminde parlayan mor gölcük (3 bant, hafif nefes)
    rx, ry = REF_RX + 2, REF_RY + 1
    pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi)
    for yy in range(-ry, ry + 1):
        for xx in range(-rx, rx + 1):
            d = (xx / rx) ** 2 + (yy / ry) ** 2
            if d <= 1.0:
                a = 0.42 if d < 0.35 else 0.28 if d < 0.7 else 0.15
                put(back if yy < 0 else front, CX + xx, FY + yy, MID, int(a * pulse * 255))
    # yükselen kıvılcımlar: gövde tabanından doğar, kıvrılarak yükselir, küçülüp söner
    rnd = random.Random(21)
    for i in range(22):
        ph = (t + i / 22 + rnd.random() * 0.05) % 1.0
        ang = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.4, 1.05)
        x0 = CX + math.cos(ang) * REF_RX * rr
        y0 = FY + math.sin(ang) * REF_RY * rr
        h = rnd.uniform(30, 52)
        sway = math.sin((ph * 2 + rnd.random()) * math.pi) * 2.5
        x, y = x0 + sway, y0 - ph * h
        a = quant(min(1.0, ph * 6) * (1.0 - ph) ** 0.6)
        size = 2 if ph < 0.6 else 1
        col = WHITE if ph < 0.2 else LIGHT if ph < 0.55 else MID if ph < 0.8 else DEEP
        if a < 190:  # yarı saydam beyaz/açık mor çimde griye dönüyor - saydamken koyu mor
            col = MID if col in (WHITE, LIGHT) else col
        layer = back if y0 < FY else front
        for dx in range(size):
            for dy in range(size):
                put(layer, x + dx, y + dy, col, a)
        if size == 2:
            put(layer, x, y + 2, MID, quant(a / 255 * 0.75))
            put(layer, x + 1, y + 2, DEEP, quant(a / 255 * 0.5))
    return back, front


def main():
    sheet = Image.new("RGBA", (W * N, H * 2), (0, 0, 0, 0))
    for f in range(N):
        b, fr = frame(f)
        sheet.paste(b, (f * W, 0))
        sheet.paste(fr, (f * W, H))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("yazıldı:", OUT, sheet.size)


if __name__ == "__main__":
    main()
