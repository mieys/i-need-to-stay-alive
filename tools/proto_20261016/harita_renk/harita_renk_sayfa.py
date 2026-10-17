"""Harita renk ayarı prototipleri: karşılaştırma sayfaları + göz yorgunluğu ölçümleri (2026-10-16, oyuna bağlı DEĞİL).

Girdi: harita_renk_capture.gd çıktıları (out/<nokta>_<ayar>.png, 960x540, 1 px = 1 dünya px).
Çıktı: harita_renk_ozet.png (tüm noktalar x tüm ayarlar, küçültülmüş), harita_renk_<nokta>.png (1:1 kesitler),
ölçüm tablosu stdout'a.
Çalıştır (depo kökünden): python tools/proto_20261016/harita_renk/harita_renk_sayfa.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "PixelifySans-Bold.ttf")
SPOTS = [("koy", "Köy"), ("kopru", "Köprü / çayır"), ("guneydogu", "Güneydoğu toprak")]
PRESETS = [
    ("0_mevcut", "Mevcut"),
    ("A_derin_cayir", "A - Derin Çayır"),
    ("B_yumusak_isik", "B - Yumuşak Işık"),
    ("C_altin_hasat", "C - Altın Hasat"),
    ("D_serin_golge", "D - Serin Gölge"),
]


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def label(img, text, size=20):
    d = ImageDraw.Draw(img)
    f = font(size)
    w = d.textlength(text, font=f)
    d.rectangle((0, 0, w + 16, size + 12), fill=(18, 20, 24))
    d.text((8, 4), text, font=f, fill=(240, 236, 224))


def metrics(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    # 3x3 komşu ortalamasından sapma = yüksek frekanslı benek (çiçek/yonca/ot/çakıl) gürültüsü
    p = np.pad(lum, 1, mode="edge")
    box = sum(p[1 + dy:1 + dy + lum.shape[0], 1 + dx:1 + dx + lum.shape[1]]
              for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    noise = np.abs(lum - box)
    return {
        "parlaklik": lum.mean() * 100,
        "parlak_alan": (lum > 0.62).mean() * 100,
        "doygunluk": sat.mean() * 100,
        "benek": noise.mean() * 1000,
    }


def main():
    # 1) özet: 3 nokta x 5 ayar, %40 küçültülmüş
    tw, th = 384, 216
    ozet = Image.new("RGB", (tw * len(PRESETS), th * len(SPOTS)), (18, 20, 24))
    for r, (spot, _) in enumerate(SPOTS):
        for c, (key, name) in enumerate(PRESETS):
            im = Image.open(os.path.join(OUT, f"{spot}_{key}.png")).convert("RGB").resize((tw, th), Image.LANCZOS)
            if r == 0:
                label(im, name, 16)
            ozet.paste(im, (c * tw, r * th))
    ozet.save(os.path.join(HERE, "harita_renk_ozet.png"))

    # 2) nokta başına 1:1 kesit (piksel ayrıntısı görünsün): 3x2 ızgara, 6. hücre = ölçümler
    cw, ch = 640, 360
    for spot, spot_name in SPOTS:
        sheet = Image.new("RGB", (cw * 3, ch * 2), (18, 20, 24))
        rows = []
        for i, (key, name) in enumerate(PRESETS):
            path = os.path.join(OUT, f"{spot}_{key}.png")
            im = Image.open(path).convert("RGB").crop((160, 90, 160 + cw, 90 + ch))
            label(im, name)
            sheet.paste(im, ((i % 3) * cw, (i // 3) * ch))
            rows.append((name, metrics(path)))
        d = ImageDraw.Draw(sheet)
        f, fs = font(22), font(18)
        x0, y0 = cw * 2 + 24, ch + 20
        d.text((x0, y0), f"{spot_name} - ölçümler (düşük = daha az yorucu)", font=f, fill=(240, 236, 224))
        d.text((x0, y0 + 40), "ayar            parlak  parlak%  doygun  benek", font=fs, fill=(170, 170, 160))
        for j, (name, m) in enumerate(rows):
            d.text((x0, y0 + 70 + j * 30),
                   f"{name.split(' - ')[0]:<14}  {m['parlaklik']:5.1f}   {m['parlak_alan']:5.1f}   "
                   f"{m['doygunluk']:5.1f}   {m['benek']:5.1f}", font=fs, fill=(230, 226, 214))
        sheet.save(os.path.join(HERE, f"harita_renk_{spot}.png"))

    # 3) tablo (3 noktanın ortalaması, mevcut = %100)
    print("ayar              parlaklik  parlak_alan  doygunluk  benek   (3 nokta ortalamasi; parantez = mevcuda gore)")
    base = None
    for key, name in PRESETS:
        ms = [metrics(os.path.join(OUT, f"{s}_{key}.png")) for s, _ in SPOTS]
        avg = {k: sum(m[k] for m in ms) / len(ms) for k in ms[0]}
        base = base or avg
        cells = "  ".join(f"{avg[k]:6.1f} ({avg[k] / base[k] * 100:4.0f}%)" for k in avg)
        print(f"{name:<18} {cells}")


if __name__ == "__main__":
    main()
