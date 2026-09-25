"""HUD çerçevelerini sadeleştirir (kullanıcı isteği 2026-09-25).

"altın göstergesi, minimap, sol üst avatar can kalkan barı v.b çerçeve kenarlıkları gereksiz ayrıntılara sahip. kenarlarda
yaprak parçaları ve tuhaf ayrıntılar var. gereksiz görsel karmaşayı azaltıp tasarımı bozmadan daha sade bir arayüze çevirmen
gerekiyor parçacıkları silip." + "sol üstteki can kalkan barının dolma barlarının oval ve içlerinin çizgisiz olmasını istiyorum."

Tasarım (ahşap bantlar, renkler, köşeler) AYNEN kalır; sadece süsler silinir:
  hud_avatar_frame.png     köşelerdeki yeşil yapraklar + kenar ortalarındaki altın perçinler
  hud_bar_frame_hp/shield  sağ uçtaki altın perçin
  hud_minimap_ring.png     N levhası, altın perçinler ve koyu "halat" bantları - halka, kendi temiz kesitinden (radyal profil)
                           yeniden örneklenir
  game/hud_plaque_clean.png altın göstergesi için plaque.png'nin perçinsiz kopyası (plaque.png menülerde de kullanıldığı için
                           ona dokunulmaz)
  hud_bar_fill_round.png   oval (uçları tam yuvarlak) dolgu - 16x10 sanat pikseli x2 (32x20); üstte parlak şerit, altta hafif gölge
                           (renk TextureProgressBar tint'i ile verilir)
  hud_bar_under_wide.png   dolgu 12 px'lik esneme payı istediği için eski 8 px'lik zeminin 32 px'lik kopyası

Silme yöntemi: süs pikseli, bulunduğu satırın ya da sütunun iki yanındaki (en fazla 10 px) ilk süs-olmayan piksel AYNI renkse
o renkle doldurulur (düz bant üstündeki perçin); değilse aynalı konumdaki piksel (çerçeveler simetrik), o da süsse en sık
komşu (dışarı taşan yapraklar saydama döner). Yeniden çalıştırmak güvenli: kaynak git'teki (404a6e0) orijinaller.

Çalıştır: python tools/simplify_hud_frames.py
"""

import math
import os
import subprocess
from collections import Counter

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, "assets", "ui", "kit")
GAME = os.path.join(ROOT, "assets", "ui", "game")
ORIGINAL_COMMIT = "404a6e0"

ORNAMENT = {
    (40, 97, 36), (86, 159, 53),  # yapraklar
    (183, 136, 35), (194, 172, 94), (135, 82, 12),  # perçin (kit)
    (183, 139, 42), (194, 170, 108), (149, 99, 19),  # perçin (game plaque)
}


def load_original(rel):
    """Dosyanın git'teki orijinalini okur (script tekrar çalışınca zaten temizlenmiş dosyayı değil)."""
    data = subprocess.run(["git", "show", "%s:%s" % (ORIGINAL_COMMIT, rel)], cwd=ROOT, capture_output=True, check=True).stdout
    import io
    return Image.open(io.BytesIO(data)).convert("RGBA")


def is_orn(px):
    return px[3] > 0 and px[:3] in ORNAMENT


def clean(im, mirror=True):
    W, H = im.size
    src = im.load()
    orn = {(x, y) for y in range(H) for x in range(W) if is_orn(src[x, y])}
    out = im.copy()
    o = out.load()

    def first_clean(x, y, dx, dy):
        for k in range(1, 11):
            xx, yy = x + dx * k, y + dy * k
            if not (0 <= xx < W and 0 <= yy < H):
                return (0, 0, 0, 0)
            if (xx, yy) not in orn:
                return src[xx, yy]
        return None

    for (x, y) in orn:
        l, r = first_clean(x, y, -1, 0), first_clean(x, y, 1, 0)
        u, d = first_clean(x, y, 0, -1), first_clean(x, y, 0, 1)
        if l is not None and l == r:
            o[x, y] = l
            continue
        if u is not None and u == d:
            o[x, y] = u
            continue
        done = False
        if mirror:
            for mx, my in ((W - 1 - x, y), (x, H - 1 - y), (W - 1 - x, H - 1 - y), (y, x), (H - 1 - y, W - 1 - x)):
                if 0 <= mx < W and 0 <= my < H and (mx, my) not in orn:
                    o[x, y] = src[mx, my]
                    done = True
                    break
        if done:
            continue
        cand = [c for c in (l, r, u, d) if c is not None]
        o[x, y] = Counter(cand).most_common(1)[0][0] if cand else (0, 0, 0, 0)
    return out


def clean_ring(im):
    """Halkayı temiz bir açıdaki radyal profilden yeniden kurar (N levhası/perçin/halat bantları gider)."""
    W, H = im.size
    cx, cy = W / 2.0, H / 2.0
    src = im.load()
    # 8 yönden radyal profil al, her yarıçap için en sık (mod) rengi seç - tek bir yöndeki süs baskın olamaz
    samples = {}
    for i in range(64):
        a = 2 * math.pi * i / 64
        for r10 in range(0, int(min(cx, cy) * 10)):
            r = r10 / 10.0
            x, y = int(cx + r * math.cos(a)), int(cy + r * math.sin(a))
            if 0 <= x < W and 0 <= y < H:
                px = src[x, y]
                if not is_orn(px):
                    samples.setdefault(int(round(r * 2)), []).append(px)
    profile = {k: Counter(v).most_common(1)[0][0] for k, v in samples.items()}
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    o = out.load()
    for y in range(H):
        for x in range(W):
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            k = int(round(r * 2))
            if k in profile:
                o[x, y] = profile[k]
    return out


def round_fill():
    """16x10 sanat pikseli, uçları tam yarım daire (yarıçap 5), 2x büyütülmüş = 32x20 (hud.gd BAR_SLOT_HEIGHT 20 - dikeyde
    esnemez, uçlar ezilmez). Beyaz tonlar (tint ile boyanır)."""
    aw, ah, r = 16, 10, 5.0
    art = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    p = art.load()
    for y in range(ah):
        for x in range(aw):
            X, Y = x + 0.5, y + 0.5
            cxl, cxr = r, aw - r
            if cxl <= X <= cxr:
                inside = True
            else:
                ccx = cxl if X < cxl else cxr
                inside = math.hypot(X - ccx, Y - r) <= r
            if not inside:
                continue
            if y <= 1:
                v = 255  # üst parlak şerit (karakter üstü barın "glow"u gibi)
            elif y >= ah - 1:
                v = 190  # alt gölge
            else:
                v = 226
            p[x, y] = (v, v, v, 255)
    return art.resize((aw * 2, ah * 2), Image.NEAREST)


def wide_under(im):
    """8x24 zemin -> 32x24: kenar sütunları korunur, orta sütun tekrarlanır."""
    W, H = im.size
    out = Image.new("RGBA", (32, H), (0, 0, 0, 0))
    for x in range(32):
        sx = x if x < 2 else (W - (32 - x) if x >= 30 else W // 2)
        for y in range(H):
            out.putpixel((x, y), im.getpixel((sx, y)))
    return out


def main():
    for rel, dst in (
        ("assets/ui/kit/hud_avatar_frame.png", os.path.join(KIT, "hud_avatar_frame.png")),
        ("assets/ui/kit/hud_bar_frame_hp.png", os.path.join(KIT, "hud_bar_frame_hp.png")),
        ("assets/ui/kit/hud_bar_frame_shield.png", os.path.join(KIT, "hud_bar_frame_shield.png")),
    ):
        clean(load_original(rel), mirror="avatar" in rel).save(dst)
        print("temizlendi:", os.path.relpath(dst, ROOT))
    clean_ring(load_original("assets/ui/kit/hud_minimap_ring.png")).save(os.path.join(KIT, "hud_minimap_ring.png"))
    print("temizlendi: hud_minimap_ring.png")
    clean(load_original("assets/ui/game/plaque.png"), mirror=False).save(os.path.join(GAME, "hud_plaque_clean.png"))
    print("yazıldı: hud_plaque_clean.png")
    round_fill().save(os.path.join(KIT, "hud_bar_fill_round.png"))
    wide_under(load_original("assets/ui/kit/hud_bar_under.png")).save(os.path.join(KIT, "hud_bar_under_wide.png"))
    print("yazıldı: hud_bar_fill_round.png, hud_bar_under_wide.png")


if __name__ == "__main__":
    main()
