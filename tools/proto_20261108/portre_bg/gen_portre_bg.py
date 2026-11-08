# Portre ARKA PLANI prototipleri (2026-11-08, madde 458 devami; oyuna bagli DEGIL). Kullanici: "karakter portrelerinin arkaplani bos ahsap
# gibi durmasin daha uyumlu dursun". Her varyant duz yatay bantlar (ditherli gecis / hale / parilti YOK, bkz. sandik v3 dersi).
#   <X>_dock.png  84x84  : hud_avatar_tray.png'nin ICI (12..71) bu bantlarla doldurulur + ust/sol 1 sanat px ic golge (gomme hissi)
#   <X>_party.png 24x24  : grup paneli avatar zemini (48 kutuda 2x = yuzun piksel izgarasi)
#   python -I tools/proto_20261108/portre_bg/gen_portre_bg.py
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out", "tex")
os.makedirs(OUT, exist_ok=True)


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# (ad, ustten alta bant renkleri, bant agirliklari)
V = {
    "A": ("Sicak Aksam", ["#d6a46a", "#c48f58", "#ad7a47", "#94653a", "#7a5030"], [3, 3, 3, 2, 1]),
    "B": ("Cayir", ["#b4c79a", "#9cb682", "#86a26c", "#6f8c58", "#566f44"], [3, 3, 3, 2, 1]),
    "C": ("Parsomen", ["#efdcb4", "#e5cfa2", "#d9bf8e", "#c8aa78", "#b39466"], [3, 3, 3, 2, 1]),
    "D": ("Alacakaranlik", ["#6d7c94", "#8a8098", "#a88a8e", "#c49a7c", "#a07a5c"], [3, 3, 2, 2, 2]),
}
SHADOW = hx("#20150d")


def bands(w, h, cols, weights, unit):
    """Yukaridan asagi bantlar; bant sinirlari `unit` piksel katina oturur."""
    img = Image.new("RGBA", (w, h))
    tot = sum(weights)
    rows = h // unit
    edges = []
    acc = 0
    for wgt in weights:
        acc += wgt
        edges.append(round(rows * acc / tot))
    for y in range(h):
        r = y // unit
        i = next(k for k, e in enumerate(edges) if r < e)
        for x in range(w):
            img.putpixel((x, y), hx(cols[i]))
    return img


def main():
    frame = Image.open(os.path.join(ROOT, "assets", "ui", "kit", "hud_avatar_tray.png")).convert("RGBA")
    for key, (name, cols, wts) in V.items():
        # dock: ic alan 12..71 (60x60 doku pikseli, 3'luk sanat izgarasi)
        d = frame.copy()
        inner = bands(60, 60, cols, wts, 3)
        d.paste(inner, (12, 12))
        for i in range(60):  # ust + sol ic golge (1 sanat px = 3 doku px), yari saydam koyu
            for t in range(3):
                for (x, y) in ((12 + i, 12 + t), (12 + t, 12 + i)):
                    base = d.getpixel((x, y))
                    d.putpixel((x, y), tuple(int(base[c] * 0.55 + SHADOW[c] * 0.45) for c in range(3)) + (255,))
        d.save(os.path.join(OUT, "%s_dock.png" % key))
        # grup paneli: 24x24, 1 piksel = yuz pikseli
        bands(24, 24, cols, wts, 1).save(os.path.join(OUT, "%s_party.png" % key))
        print("yazildi", key, name)


if __name__ == "__main__":
    main()
