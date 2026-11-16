# Necro pasif ikonu: yalnız MAVİ tonları (hue 150-260) döndürür, parlaklığı (luma) korur.
# Kullanım: python -I recolor_pasif.py <giris.png> <cikis.png> <hedef_hue_derece>
import sys, colorsys
from PIL import Image

def luma(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b

def main(src, dst, target):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    center = 205.0  # ikonun mavi merkezi
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            hd = h * 360
            # 150-260 arası tam, kenarlarda 15 derece yumuşak geçiş
            if hd < 135 or hd > 275:
                continue
            w = 1.0
            if hd < 150: w = (hd - 135) / 15
            elif hd > 260: w = (275 - hd) / 15
            nh = ((hd + (target - center) * w) % 360) / 360
            nr, ng, nb = colorsys.hsv_to_rgb(nh, s, v)
            nr, ng, nb = nr * 255, ng * 255, nb * 255
            l0, l1 = luma(r, g, b), luma(nr, ng, nb)
            if l1 > 0.5:
                k = l0 / l1
                nr, ng, nb = nr * k, ng * k, nb * k
                m = max(nr, ng, nb)
                if m > 255:  # tavan aşılırsa kalan parlaklığı griye dağıt
                    nr, ng, nb = [c * 255 / m for c in (nr, ng, nb)]
                    l2 = luma(nr, ng, nb)
                    if l2 < l0:
                        f = (l0 - l2) / max(1e-6, 255 - l2)
                        nr, ng, nb = [c + (255 - c) * f for c in (nr, ng, nb)]
            px[x, y] = (int(round(min(255, max(0, nr)))), int(round(min(255, max(0, ng)))),
                        int(round(min(255, max(0, nb)))), a)
    im.save(dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]))
