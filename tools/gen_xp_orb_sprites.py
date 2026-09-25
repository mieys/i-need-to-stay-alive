"""Kullanici istegi (2026-09-25): "exp orblarini yeniden tasarlamani istiyorum pixel tarzda. her kademenin rengi diger
renklerle ayni olacak sekilde yeniden daha iyi bir sekilde tasarla. opaklik ayarini da kaldir."

Eski orblar 64x64 karelik, yumusak (piksel olmayan) parlamali "dugme" gorunumlu cizimlerdi; oyunda 0.22-0.30 gibi
TAM SAYI OLMAYAN olceklerle kucultuluyordu (her tier farkli piksel yogunlugu, bulanik/dagilmis pikseller) ve sahnede
%70 saydamdi. Yeni tasarim:
  - Tek piksel yogunlugu: her tier AYNI olcekte (xp_orb.gd ORB_TEXEL = karakterlerin sanat pikseli, 1080p'de ~1.2 ekran
    pikseli) - tier buyuklugu olcekle degil SANAT boyutuyla artar (9/9/11/11/13 piksel cap).
  - Ayni aile: 1 piksel koyu dis hat, sol-ustten isik alan 4 tonlu yuvarlak govde, parlak cekirdek, beyazimsi parlama
    noktasi, disarida soluk 1 piksellik hale. Renk SIRASI eskisiyle ayni (yesil -> mavi -> mor -> altin -> kirmizi) -
    oyuncu hangi rengin daha degerli oldugunu zaten biliyor; oyundaki tier dili (mavi/mor/kirmizi) ile uyumlu.
  - Animasyon (8 kare, dongu): hale nabzi + govdede kayan bir parilti; tier 3+ ust kosede 4 kollu yildiz pirilti,
    tier 4+ govde etrafinda donen 1 / tier 5'te 2 zerre.
  - Tamamen opak (saydamlik yok).

Cikti: assets/pickups/xp_orb/xp_orb_<renk>.png (8 kare x 20x20) + xp_orb_frames.tres (ayni uid'lerle yeniden yazilir).
Calistir: python tools/gen_xp_orb_sprites.py   (sonra Godot editoru PNG'leri yeniden import eder)
"""

import math
import os
import re

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_DIR = os.path.join(ROOT, "assets", "pickups", "xp_orb")
## Kullanici istegi (2026-09-25, sonraki tur): "tum exp orblari %25 buyutmeni istiyorum" - sprite'i 1.25 ile OLCEKLEMEK
## piksel yogunlugunu bozardi (her 4 pikselden biri cift); onun yerine sanat capi %25 buyutuldu (9/11/13 -> 11/14/16) ve
## kare 16 -> 20 px (hale + zerreler sigsin). Olcek (xp_orb.gd ORB_TEXEL) ayni kaldi; carpisma yaricaplari x1.25.
CELL = 20
FRAMES = 8
FPS = 8.0


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# (renk adi, cap, [dis hat, koyu, orta, acik, parlama])
TIERS = [
    ("green", 11, ["#1b4a26", "#2e7f3c", "#4dc155", "#9eea74", "#eaffd6"]),
    ("blue", 11, ["#152f5f", "#2457b2", "#3f8df0", "#8fcaff", "#e8f7ff"]),
    ("purple", 14, ["#3a1a5e", "#6a2fa8", "#9b57e2", "#d09eff", "#f7eaff"]),
    ("yellow", 14, ["#5c3508", "#b06a10", "#f0a920", "#ffe174", "#fffbe2"]),
    ("red", 16, ["#5c1010", "#a82525", "#e8494a", "#ff9c8c", "#fff1ec"]),
]


def put(img, x, y, col):
    if 0 <= x < CELL and 0 <= y < CELL and col[3] > 0:
        img.putpixel((x, y), col)


def draw_orb(tier_index, diameter, pal, frame):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    outline, dark, mid, light, hi = [hexc(c) for c in pal]
    r = diameter / 2.0
    cx = cy = CELL / 2.0
    t = frame / FRAMES

    # Hale: govdenin 1 piksel disi, yari saydam orta ton, nabiz gibi (tamamen opak orbun "isigi").
    halo_a = int(70 + 45 * math.sin(t * math.tau))
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r - 0.05 <= d < r + 0.95:
                put(img, x, y, (mid[0], mid[1], mid[2], halo_a))

    # Govde: dis hat + sol-ustten isik alan tonlar.
    lx, ly = -0.45, -0.55  # isik yonu (sol-ust)
    for y in range(CELL):
        for x in range(CELL):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d >= r:
                continue
            if d >= r - 1.0:
                put(img, x, y, outline)
                continue
            # Isiga donukluk: -1 (golge) .. 1 (isik); merkeze yakin cekirdek daha parlak.
            facing = (dx * lx + dy * ly) / max(r - 1.0, 0.5)
            core = 1.0 - d / (r - 1.0)
            v = facing * 0.9 + core * 0.8
            if v < -0.35:
                col = dark
            elif v < 0.45:
                col = mid
            else:
                col = light
            put(img, x, y, col)

    # Parlama noktasi (sol-ust), buyuk orblarda 2 piksel.
    hx, hy = int(cx - r * 0.42), int(cy - r * 0.45)
    put(img, hx, hy, hi)
    if diameter >= 11:
        put(img, hx + 1, hy, hi)
        put(img, hx, hy + 1, light)

    # Kayan parilti: govde boyunca capraz inen tek acik piksel (kare kare), dis hatta degmez.
    sweep = -r + 2 + (2 * r - 3) * t
    for y in range(CELL):
        for x in range(CELL):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if math.hypot(dx, dy) < r - 1.6 and abs((dx - dy) * 0.7071 - sweep) < 0.5 and img.getpixel((x, y))[:3] == mid[:3]:
                put(img, x, y, light)

    # Tier 3+: ust sag kosede 4 kollu yildiz pirilti (2 karede parlar).
    if tier_index >= 2 and frame in (3, 4):
        sx, sy = int(cx + r * 0.62), int(cy - r * 0.7)
        put(img, sx, sy, hi)
        if frame == 3:
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(img, sx + ox, sy + oy, (hi[0], hi[1], hi[2], 190))

    # Tier 4+: govdenin etrafinda donen zerre(ler).
    motes = 0 if tier_index < 3 else (1 if tier_index == 3 else 2)
    for m in range(motes):
        ang = t * math.tau + m * math.pi
        mx = int(round(cx - 0.5 + math.cos(ang) * (r + 0.6)))
        my = int(round(cy - 0.5 + math.sin(ang) * (r + 0.6) * 0.6))
        put(img, mx, my, hi)
    return img


def main():
    for i, (name, diameter, pal) in enumerate(TIERS):
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for f in range(FRAMES):
            sheet.paste(draw_orb(i, diameter, pal, f), (f * CELL, 0))
        path = os.path.join(OUT_DIR, f"xp_orb_{name}.png")
        sheet.save(path)
        print("yazildi:", os.path.normpath(path))
    write_tres()


def write_tres():
    """xp_orb_frames.tres'i yeni 16x16 x 8 kare duzenine gore yeniden yazar - resource/ext_resource uid'leri korunur."""
    path = os.path.join(OUT_DIR, "xp_orb_frames.tres")
    old = open(path, encoding="utf-8").read()
    res_uid = re.search(r'\[gd_resource[^\]]*uid="([^"]+)"', old).group(1)
    ext = {}
    for m in re.finditer(r'\[ext_resource type="Texture2D" uid="([^"]+)" path="res://assets/pickups/xp_orb/xp_orb_(\w+)\.png"', old):
        ext[m.group(2)] = m.group(1)
    lines = [f'[gd_resource type="SpriteFrames" format=3 uid="{res_uid}"]', ""]
    for i, (name, _, _) in enumerate(TIERS):
        uid = ext.get(name)
        uid_part = f' uid="{uid}"' if uid else ""
        lines.append(f'[ext_resource type="Texture2D"{uid_part} path="res://assets/pickups/xp_orb/xp_orb_{name}.png" id="{i + 1}"]')
    lines.append("")
    for i, (name, _, _) in enumerate(TIERS):
        for f in range(FRAMES):
            lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{name}_{f}"]')
            lines.append(f'atlas = ExtResource("{i + 1}")')
            lines.append(f"region = Rect2({f * CELL}, 0, {CELL}, {CELL})")
            lines.append("")
    lines.append("[resource]")
    anims = []
    for name, _, _ in TIERS:
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%s_%d")\n}' % (name, f) for f in range(FRAMES))
        anims.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %.1f\n}' % (frames, name, FPS))
    lines.append("animations = [" + ", ".join(anims) + "]")
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("yazildi:", os.path.normpath(path))


if __name__ == "__main__":
    main()
