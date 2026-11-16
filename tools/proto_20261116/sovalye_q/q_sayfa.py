#!/usr/bin/env python3
"""Şovalye Q prototip sayfası (tek dosya HTML, claude.ai artifact olarak yayınlanır).

Gerçek oyun ölçeğinde (kamera zoom 2, 1080p: 1 dünya px = 2 tuval px) birleştirir:
  - Şovalye idle_down (karakter pikseli 0,903 dünya), Ork 1 idle (yaratık pikseli ~0,85 dünya, YAKLAŞIK),
  - ŞU AN: fx_kalkan_yenileme (0,5 dünya/px, yumuşak, karakterin önünde) / fx_sovalye_taunt (0,606 dünya/px, arkada),
  - A/B/C: q_proto.py sayfaları (karakter pikseli, back = karakter arkası, front = önü),
  - kışkırtılan yaratığın başında ikon: ŞU AN 💢 sayfası, seçenekler Raven Fantasy Icons (0,667 dünya/px =
    fx_taunt_status.gd TEXEL x SIZE_MUL, yani yalnız doku değişseydi oyundaki boy).
Çıktı: out/sovalye_q_prototip.html
"""
import base64
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
RAVEN = r"C:/Users/perva/Desktop/Free - Raven Fantasy Icons/Separated Files/16x16"

ICONS = [
    (684, "Öfke damarı", "Bugünkü 💢 ile aynı anlam; küçük, zeminsiz. Önerim."),
    (698, "Kızgın boynuzlu ağız", "Öfke / kudurma; kırmızı, zeminsiz."),
    (682, "Kızgın yüz", "Turuncu öfke suratı; okunaklı ama daha 'sevimli'."),
    (695, "Öfke alevi", "Kırmızı alevli boynuzlar."),
    (719, "Kırmızı göz", "'Gözü Şovalye'de' okuması."),
    (864, "Hedef kafatası", "Kırmızı halkalı kafatası; 'hedef alındı'."),
    (663, "Kalkık yumruk", "Meydan okuma jesti; tenden, kırmızı değil."),
    (1226, "Kükreyen yüz", "Savaş çığlığı; kare zeminli yetenek simgesi, başta ağır durabilir."),
]


def b64(path, mime="image/png"):
    with open(path, "rb") as fh:
        return f"data:{mime};base64," + base64.b64encode(fh.read()).decode("ascii")


def main():
    meta = json.load(open(os.path.join(OUT, "meta.json"), encoding="utf-8"))
    img = {
        "knight": b64(os.path.join(ROOT, "assets/characters/sovalye/sheets/idle.png")),
        "orc": b64(os.path.join(ROOT, "visuals/Yaratıklar/Tüm Yaratıklar/Ork 1/PNG/Orc1/With_shadow/orc1_idle_with_shadow.png")),
        "cur_base": b64(os.path.join(ROOT, "assets/fx/baked/kalkan_yenileme_sheet.png")),
        "cur_burst": b64(os.path.join(ROOT, "assets/fx/sovalye/taunt_burst_sheet.png")),
        "cur_aura": b64(os.path.join(ROOT, "assets/fx/sovalye/taunt_aura_sheet.png")),
        "cur_status": b64(os.path.join(ROOT, "assets/fx/sovalye/taunt_status_sheet.png")),
    }
    for key in meta["clips"]:
        for layer in ("back", "front"):
            img[f"{key}_{layer}"] = b64(os.path.join(OUT, f"{key}_{layer}.png"))
    for n, _, _ in ICONS:
        img[f"fa{n}"] = b64(os.path.join(RAVEN, f"fa{n}.png"))
    data = {"img": img, "meta": meta, "icons": [{"n": n, "name": a, "desc": d} for n, a, d in ICONS]}
    font = b64(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), "font/ttf")
    with open(os.path.join(HERE, "q_sayfa_sablon.html"), encoding="utf-8") as fh:
        html = fh.read()
    html = html.replace("__FONT__", font).replace("__DATA__", json.dumps(data, ensure_ascii=False))
    out = os.path.join(OUT, "sovalye_q_prototip.html")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(html)
    print(out, round(os.path.getsize(out) / 1024), "KB")


if __name__ == "__main__":
    main()
