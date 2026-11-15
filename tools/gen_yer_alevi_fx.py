# YER ALEVİ - yanan yaratığın ayak dibindeki tek küçük alev (madde 551, 2026-11-10).
# Ateş Asası prototiplerinden (madde 548) C "Yer Ateşi"nin alevciği; kullanıcı ekran görüntüsüyle bunu seçti:
# "yanmadan kastım ... prototipin C yer ateşi parçalarından biriydi" -> scripts/fx_burn_status.gd'nin ATEŞ katmanı (duman aynen).
# Çizim dili fire_min (yanma alevinin eski minimal denemesi): üç sivri dil, 3 düz ton + 1 px bordo dış hat, düz taban.
# 1 sanat pikseli = 0,903 dünya birimi (karakter pikseli). Kareler prototipteki C_alevcik.png ile PİKSEL PİKSEL aynı.
#
# Çıktı: assets/fx/burn/yer_alevi_sheet.png (10 kare x 24x30, tek satır) + yer_alevi_frames.tres
#   "ignite" kare 0-1 (tutuşma, tek sefer) / "burn" kare 2-6 (döngü) / "die" kare 7-9 (sönme, tek sefer), 12 fps.
#   Tutunma noktası = taban ortası (12, 26) -> ortalı sprite ofseti (0, -11).
# Çalıştır: python -I tools/gen_yer_alevi_fx.py   (sonra Godot --import ya da editör)
import os, sys, math
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "fx", "burn")
RES = "res://assets/fx/burn/"
FW, FH, FAX, FAY = 24, 30, 12, 26
FLN, FPS = 10, 12
FL_ENV = [0.28, 0.6, 0.9, 1.0, 0.9, 1.0, 0.88, 0.66, 0.42, 0.22]
FL_LIFT = [0, 0, 0, 0, 0, 0, 0, 1, 3, 6]
TAU = 2 * math.pi


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


OUTL, RED, ORG, YEL = hx("#661a0f"), hx("#d64c1f"), hx("#fa9433"), hx("#ffdb75")


def h01(i, k=0):
    v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)


def teardrop(s, s0, pw):
    s = np.clip(s, 0.0, 1.0)
    a = np.sqrt(np.clip(1 - ((s0 - s) / s0) ** 2, 0, 1))
    b = np.clip(1 - (s - s0) / (1 - s0), 0, 1) ** pw
    return np.where(s < s0, a, b)


def ribbon(u, v, L, w, s0=0.25, pw=1.2, spine=True):
    if L < 1.0 or w <= 0.2:
        return np.zeros(u.shape, bool), np.full(u.shape, -1.0)
    s = u / L
    off = np.abs(v)
    d = w * teardrop(s, s0, pw) - off
    inside = (s >= 0) & (s <= 1) & (d > 0)
    if spine:
        inside |= (s >= 0) & (s <= 0.97) & (off <= 0.5)
    return inside, np.where(inside, np.maximum(d, 0.01), -1.0)


def grow4(m):
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


def flamelet(g):
    ys, xs = np.mgrid[0:FH, 0:FW]
    px, py = xs + 0.5 - FAX, ys + 0.5 - FAY
    e, lift = FL_ENV[g], FL_LIFT[g]
    red = np.zeros((FH, FW), bool)
    org = np.zeros((FH, FW), bool)
    yel = np.zeros((FH, FW), bool)
    up = -math.pi / 2
    sway = 0.10 * math.sin(TAU * g / 5.0)
    tongues = [
        (0.0, up + sway, 17.0 * e * (0.94 + 0.12 * h01(g, 1)), 3.5 * min(1.0, e * 1.25), True),
        (-3.6, up - 0.20 + sway * 0.5, 10.5 * e * (0.9 + 0.2 * h01(g, 2)), 2.7 * min(1.0, e * 1.25), False),
        (3.6, up + 0.17 + sway * 0.5, 12.0 * e * (0.9 + 0.2 * h01(g, 3)), 2.7 * min(1.0, e * 1.25), False),
    ]
    if e < 0.45:
        tongues = tongues[:1]
    for bx, ang, L, w, core in tongues:
        ca, sa = math.cos(ang), math.sin(ang)
        oy = -lift + 1.5
        u = (px - bx) * ca + (py - oy) * sa
        v = -(px - bx) * sa + (py - oy) * ca
        m, d = ribbon(u, v, L + 1.5, w, s0=0.32, pw=1.15)
        red |= m
        mi, _ = ribbon(u - 1.0, v, (L + 1.5) * 0.62, w - 1.5, s0=0.34, pw=1.0, spine=False)
        org |= mi & (d >= 1.1)
        if core and e > 0.6:
            my, _ = ribbon(u - 1.5, v, (L + 1.5) * 0.36, w - 2.5, s0=0.36, pw=1.0, spine=False)
            yel |= my & (d >= 2.2)
    if lift == 0:
        red &= ~(py > 0.0)          # düz taban (yere basar)
    rgb = np.zeros((FH, FW, 3))
    a = np.zeros((FH, FW))
    ring = grow4(red) & ~red
    rgb[ring] = OUTL
    a[ring] = 1.0
    if lift == 0:
        a[py > 1.0] = 0.0
    for mask, col in ((red, RED), (org & red, ORG), (yel & red, YEL)):
        rgb[mask] = col
        a[mask] = 1.0
    out = np.dstack([rgb, a * 255.0]).round().clip(0, 255).astype(np.uint8)
    out[a <= 0] = 0
    return Image.fromarray(out, "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (FW * FLN, FH))
    for g in range(FLN):
        sheet.paste(flamelet(g), (g * FW, 0))
    sheet.save(os.path.join(OUT, "yer_alevi_sheet.png"))
    write_sprite_frames(os.path.join(OUT, "yer_alevi_frames.tres"), RES + "yer_alevi_sheet.png", FW, FH,
                        [("ignite", (0, 0), 2, False, float(FPS)), ("burn", (2, 0), 5, True, float(FPS)), ("die", (7, 0), 3, False, float(FPS))])
    ref = os.path.join(HERE, "proto_20261110", "ates_alev2", "out", "sheets", "C_alevcik.png")
    if os.path.exists(ref):
        print("prototiple ayni:", np.array_equal(np.array(sheet), np.array(Image.open(ref).convert("RGBA"))))


if __name__ == "__main__":
    main()
