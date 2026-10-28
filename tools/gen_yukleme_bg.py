# YÜKLEME EKRANI arka planı "Mühürlü Kapı" (madde 370; prototip madde 366 A, kullanıcı: "A - Mühürlü Kapı'yı oyuna al").
# Önceki sahne "Eve Dönüş" (madde 233: kodla dizilmiş kulübe + yol) git geçmişinde. Yeni sahne derin orman Kuzey'deki KEMİK MAHZENİ:
# arka plan GERÇEK çiziciden oyuncusuz çekim (tools/yukleme/yukleme_capture.ps1 -> tools/yukleme/cekim/), bu betik ona gece tonunu verir.
# Kapı ayağı tuval (546, 200) - kahraman bar %97'deyken tam kapının ağzında (loading_screen.gd PATH_RECT değişmedi, yol bandı tuval y 213..227).
# Kurallar: ışık YUMUŞAK (madde 326: Bayer basamakları "pixel pixel"); ay tonu + kenar karartma (sol daha koyu, yaratıklar karanlıktan çıkar);
# ışıyan pikseller (yeşil alev, kristal) gece tonundan muaf - oyundaki bölge renk ayarı gibi.
# Çıktı assets/ui/yukleme/:
#   yukleme_bg.png   640x360 gece tonlu arka plan
#   yukleme_isik.png 640x360 kapının yeşil ışığı (TOPLAMALI katman; loading_screen.gd ilerlemeyle güçlendirir, varışta parlatır)
#   kapi_alev.png    kapı alevi şeridi (yalnız değişen pikseller, Tiled animasyonunun 6 karesi çekimden, döngü sırasıyla)
# + scripts/loading_scene_parts.gd (yerleşim; JSON export filtresine girmediği için GDScript sabiti); sonra Godot `--headless --import`.
#   python tools/gen_yukleme_bg.py                    (oyun dosyaları)
#   python tools/gen_yukleme_bg.py --onizle <png> [p] (ek olarak x3 önizleme: ışık katmanı p ilerlemesinde, alev 0. karede)
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
CEKIM = os.path.join(HERE, "yukleme", "cekim")
OUT = os.path.join(ROOT, "assets", "ui", "yukleme")
PARTS_GD = os.path.join(ROOT, "scripts", "loading_scene_parts.gd")
ATLAS_JSON = os.path.join(HERE, "derin_orman", "atlas.json")
W, H = 640, 360
AMBIENT = np.array([0.46, 0.52, 0.68], np.float32)   # ay tonu
LIGHT_COL = np.array([0.32, 1.0, 0.6], np.float32)   # kapının yeşil ışığı
LIGHT_R = 180.0                                      # tuval px (yatay); dikeyde x0,75 basık
LIGHT_SQUASH = 0.75
LIGHT_I = 1.15                                       # %100'deki güç (oyunda modulate.a 0,26 -> 1)
GLOW_KEEP = 0.9                                      # ışıyan piksellerin korunan parlaklığı
OLD_PARTS = ["agac_0.png", "agac_1.png", "agac_2.png", "agac_3.png", "duman.png"]   # "Eve Dönüş" canlı parçaları

YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def vignette():
    vx = (XX / W - 0.5) * 2
    vy = (YY / H - 0.5) * 2
    v = np.clip(vx ** 2 * 0.4 + vy ** 2 * 0.55 - 0.18 + np.clip(-vx - 0.5, 0, None) * 0.5, 0, 1)
    return 1 - 0.6 * v


def glow_mask(a):
    """Doygun + parlak + yeşil/mavi baskın piksel (alev, ruh ışığı, kristal)."""
    mx = a.max(-1)
    mn = a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    return (sat > 0.32) & (mx > 0.5) & (a[..., 0] < a[..., 1] * 0.9)


def night(a, vig):
    out = a * AMBIENT * vig[..., None]
    g = glow_mask(a)
    out[g] = np.maximum(out[g], a[g] * GLOW_KEEP)
    return out


def light_layer(a, vig, center):
    d = np.sqrt((XX - center[0]) ** 2 + ((YY - center[1]) / LIGHT_SQUASH) ** 2) / LIGHT_R
    f = np.clip(1 - d, 0, 1) ** 2
    out = a * (f * vig)[..., None] * LIGHT_COL * LIGHT_I
    out[glow_mask(a)] = 0.0
    return out


def to_img(a, alpha=None):
    rgb = np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(rgb, "RGB")
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def flame_frames(meta):
    """Çekim karelerinden kapı alevinin döngüsü: değişen pikseller + benzersiz durumlar zaman sırasıyla (yalnız bir tur)."""
    cx, cy, cw, ch = meta["crop"]
    s = np.asarray(Image.open(os.path.join(CEKIM, "alev_kareleri.png")).convert("RGB"))
    cr = np.stack([s[:, k * cw:(k + 1) * cw] for k in range(int(meta["frames"]))])
    var = (cr != cr[0:1]).any(axis=(0, 3))
    if not var.any():
        sys.exit("HATA: kapı alevi çekimde hiç değişmiyor")
    seen, order = {}, []
    for k in range(cr.shape[0]):
        key = cr[k][var].tobytes()
        if key not in seen:
            seen[key] = k
            order.append(k)
    ys, xs = np.nonzero(var)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return [cr[k] for k in order], var, box, (cx, cy)


def main():
    meta = json.load(open(os.path.join(CEKIM, "meta.json"), encoding="utf-8"))
    raw = np.asarray(Image.open(os.path.join(CEKIM, "mahzen.png")).convert("RGB")).astype(np.float32) / 255.0
    assert raw.shape == (H, W, 3), raw.shape
    vig = vignette()
    mouth = meta["mouth"]
    center = (mouth[0], mouth[1] + 8.0)
    os.makedirs(OUT, exist_ok=True)
    bg = night(raw, vig)
    to_img(bg).save(os.path.join(OUT, "yukleme_bg.png"))
    to_img(light_layer(raw, vig, center), np.full((H, W), 255, np.uint8)).save(os.path.join(OUT, "yukleme_isik.png"))

    frames, var, (x0, y0, x1, y1), (cx, cy) = flame_frames(meta)
    fw, fh = x1 - x0, y1 - y0
    sub_vig = vig[cy + y0:cy + y1, cx + x0:cx + x1]
    strip = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        a = fr[y0:y1, x0:x1].astype(np.float32) / 255.0
        g = night(a, sub_vig)
        alpha = np.where(var[y0:y1, x0:x1], 255, 0).astype(np.uint8)
        strip.paste(to_img(g, alpha), (i * fw, 0))
    strip.save(os.path.join(OUT, "kapi_alev.png"))
    anim = json.load(open(ATLAS_JSON, encoding="utf-8"))["anims"]["kemik_mahzen"]
    if len(frames) != int(anim["frames"]):
        print("UYARI: çekimde %d alev durumu, atlas %d kare" % (len(frames), anim["frames"]))
    fps = 1000.0 / float(anim["ms"])
    pos = (cx + x0, cy + y0)

    for name in OLD_PARTS:
        for p in (name, name + ".import"):
            fp = os.path.join(OUT, p)
            if os.path.exists(fp):
                os.remove(fp)
    with open(PARTS_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write("## OTOMATİK ÜRETİLİR: python tools/gen_yukleme_bg.py - elle düzenleme (çekim/sahne değişince yeniden üret).\n")
        f.write("## Yükleme ekranı \"Mühürlü Kapı\" (assets/ui/yukleme/yukleme_bg.png, 640x360 tuval, oyunda x3) canlı parçaları: yatay kare şeritleri.\n")
        f.write("## [dosya, tuvalde sol üst, kare boyutu, kare sayısı, fps, ayak y (çizim sırası)]\n\n")
        f.write("const CANVAS := Vector2(%d, %d)\n" % (W, H))
        f.write("const PARTS: Array = [\n")
        f.write("\t[\"kapi_alev.png\", Vector2(%d, %d), Vector2(%d, %d), %d, %s, %d],\n" % (pos[0], pos[1], fw, fh, len(frames), repr(round(fps, 3)), int(meta["foot"][1])))
        f.write("]\n")
        f.write("## kapının yeşil ışığı (toplamalı katman, %%100'de güç %.2f) + zindan kapısı ağzı (hale ve ruh ışıkları buradan)\n" % LIGHT_I)
        f.write("const LIGHT := \"yukleme_isik.png\"\n")
        f.write("const GATE_MOUTH := Vector2(%d, %d)\n" % (round(mouth[0]), round(mouth[1])))
    print("yazildi: yukleme_bg.png, yukleme_isik.png, kapi_alev.png (%d kare %dx%d @ %s), loading_scene_parts.gd" % (len(frames), fw, fh, pos))

    if "--onizle" in sys.argv:
        i = sys.argv.index("--onizle")
        dst = sys.argv[i + 1]
        p = float(sys.argv[i + 2]) if len(sys.argv) > i + 2 else 0.6
        k = (0.26 + 0.74 * p)
        comp = bg + light_layer(raw, vig, center) * k
        im = to_img(comp).convert("RGBA")
        im.alpha_composite(strip.crop((0, 0, fw, fh)), pos)
        im.resize((W * 3, H * 3), Image.NEAREST).convert("RGB").save(dst)
        print("onizleme:", dst)


if __name__ == "__main__":
    main()
