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

PARILTI DUZELTMESI (kullanici 2026-10-01: "bizimki iyiymis ama nedense oyunda hic parlitili gorunmuyor") - oyun ici
yakin cekimle olculen kok nedenler: (1) hale orbun ORTA tonunda yari saydam ciziliyordu -> yesil cimende zemini
aydinlatmiyor, golge gibi duruyordu; (2) yildiz pirilti sadece kademe 3+ ve 8 karenin 2'sinde; (3) 1 piksellik detaylar
xp_orb.gd'nin 0.92-1.08 "nefes" olceginde kuculurken ekrandan dusuyordu. Simdi: hale ACIK/parlama tonunda (ic halka
nabiz gibi, dis halka dama dither) -> her zeminde isik gibi okunur; yildiz HER kademede 3 kare (kademe 4+ kollar 2 px,
kademe 5'te karsi kosede ikinci yildiz); kayan parilti 2 px. Nefes olcegi artik sadece buyur (bkz. xp_orb.gd PULSE_*).
Kare 20 -> 24 (dis halka kenara degmesin); govde/renk/caplar ayni.

Cikti: assets/pickups/xp_orb/xp_orb_<renk>.png (8 kare x 24x24) + xp_orb_frames.tres (ayni uid'lerle yeniden yazilir).
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
CELL = 24
FRAMES = 8
FPS = 8.0
## Kullanici istegi (2026-10-02): "simdiki renk ayarlariyla elmas kristal versiyonunu ekler misin oyuna deneyecegim" - sekil
## prototiplerinden (A Elmas Kristal) secildi. SHAPE = "round" yazip calistirmak eski yuvarlak orbu geri uretir (ayni renkler).
SHAPE = "diamond"
if SHAPE == "diamond":
    CELL = 32  # suzulme + 3 halkali hale + yildiz sigsin, kenara degmesin (2026-10-02 %15 buyutme: 28 -> 32)
    FRAMES = 12
    FPS = 10.0


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# (renk adi, cap, [dis hat, koyu, orta, acik, parlama])
# 2026-10-02 "hepsini %15 buyut": boylar 9/9/12/12/14 -> 10/10/14/14/16 (sanat boyu - olcek degil, piksel yogunlugu ayni);
# xp_orb.gd carpisma yaricaplari ayni oranda x1.15.
TIERS = [
    # Kademe 1: beyaz/gri denendi (2026-10-01), kullanici begenmedi -> 2026-10-02 "cimenin ustundeyken zor gorunmeyecek
    # turden bir yesil". Oyundaki cimen ~93 derece sarimsi yesil, doygunluk ~0.38, parlaklik ~0.5 (yakalamadan olculdu);
    # orb ~155 derece zumrut/nane: ton farki ~60 derece, doygunluk ~2 kat, koyu yesil dis hat, hale cimenden parlak nane.
    ("green", 10, ["#0b3b2c", "#138a5c", "#22d685", "#8cffc6", "#effff7"]),
    ("blue", 10, ["#152f5f", "#2457b2", "#3f8df0", "#8fcaff", "#e8f7ff"]),
    ("purple", 14, ["#3a1a5e", "#6a2fa8", "#9b57e2", "#d09eff", "#f7eaff"]),
    ("yellow", 14, ["#5c3508", "#b06a10", "#f0a920", "#ffe174", "#fffbe2"]),
    ("red", 16, ["#5c1010", "#a82525", "#e8494a", "#ff9c8c", "#fff1ec"]),
]


def mix(c1, c2, t):
    """c1 -> c2 arasi renk (t 0..1), alfa c1'den."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (c1[3],)


## 2026-10-02 (kullanici: "disindaki pariltilar orb rengiyle uyumsuz, cok beyaz ... mevcut renginden disa dogru gittikce
## beyazlassin"): hale artik orbun KENDI renginden baslar - ic halka orta ton (canli), orta halka acik ton, dis halka acik
## ile parlama arasi (en dista hafif beyazlasir, soluk). Yildiz kollari acik ton, sadece merkez pikseli parlama rengi.
def halo_colors(mid, light, hi):
    return mid, light, mix(light, hi, 0.5)


def put(img, x, y, col):
    if 0 <= x < CELL and 0 <= y < CELL and col[3] > 0:
        img.putpixel((x, y), col)


def draw_orb(tier_index, diameter, pal, frame):
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    outline, dark, mid, light, hi = [hexc(c) for c in pal]
    r = diameter / 2.0
    cx = cy = CELL / 2.0
    t = frame / FRAMES

    # Hale (isik): ic halka acik tonda nabiz gibi, dis halka parlama tonunda dama dither - zemini AYDINLATIR (eskiden orta
    # ton yari saydamdi, cimende golge gibi kaliyordu).
    # 2026-10-01 ikinci tur ("kuresi kuculsun, parlitisi buyusun"): hale 3 halka - ic acik ton, orta parlama tonu dama
    # dither, dis halka seyrek (her 4 pikselde 1) ve nabizla soner.
    pulse = 0.5 + 0.5 * math.sin(t * math.tau)
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            h1, h2, h3 = halo_colors(mid, light, hi)
            if r - 0.05 <= d < r + 0.95:
                put(img, x, y, (h1[0], h1[1], h1[2], int(170 + 85 * pulse)))
            elif r + 0.95 <= d < r + 1.95 and (x + y) % 2 == 0:
                put(img, x, y, (h2[0], h2[1], h2[2], int(110 + 90 * pulse)))
            elif r + 1.95 <= d < r + 2.95 and x % 2 == 0 and y % 2 == 0:
                put(img, x, y, (h3[0], h3[1], h3[2], int(50 + 90 * pulse)))

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
            band = abs((dx - dy) * 0.7071 - sweep)
            if math.hypot(dx, dy) < r - 1.6 and band < 1.1 and img.getpixel((x, y))[:3] in (mid[:3], dark[:3]):
                put(img, x, y, hi if band < 0.45 else light)

    # Yildiz pirilti: HER kademede ust sag kosede 3 kare (nokta -> arti -> nokta); kademe 4+ kollar 2 px.
    def star(sx, sy, arm):
        put(img, sx, sy, hi)
        for i in range(1, arm + 1):
            col = (light[0], light[1], light[2], 255 if i == 1 else 150)
            for ox, oy in ((i, 0), (-i, 0), (0, i), (0, -i)):
                put(img, sx + ox, sy + oy, col)

    sx, sy = int(cx + r * 0.75), int(cy - r * 0.85)
    if frame in (1, 5):
        put(img, sx, sy, (hi[0], hi[1], hi[2], 220))
    elif frame in (2, 4):
        star(sx, sy, 1)
    elif frame == 3:
        star(sx, sy, 3 if tier_index >= 3 else 2)
    # Kademe 5: karsi kosede (sol alt) ikinci yildiz, faz kaymali.
    if tier_index >= 4:
        bx, by = int(cx - r * 0.75), int(cy + r * 0.62)
        if frame in (6, 0):
            star(bx, by, 1)
        elif frame == 7:
            star(bx, by, 2)

    # Tier 4+: govdenin etrafinda donen zerre(ler).
    motes = 0 if tier_index < 3 else (1 if tier_index == 3 else 2)
    for m in range(motes):
        ang = t * math.tau + m * math.pi
        mx = int(round(cx - 0.5 + math.cos(ang) * (r + 0.6)))
        my = int(round(cy - 0.5 + math.sin(ang) * (r + 0.6) * 0.6))
        put(img, mx, my, hi)
    return img


def _blend(img, x, y, col):
    """Yari saydam pikseli alttakiyle harmanlar (hale/yildiz kollari ust uste binebilir); kenar pikseli hep bos kalir."""
    if not (1 <= x < CELL - 1 and 1 <= y < CELL - 1) or col[3] <= 0:
        return
    if col[3] >= 255:
        img.putpixel((x, y), col)
        return
    bg = img.getpixel((x, y))
    a = col[3] / 255.0
    ba = bg[3] / 255.0
    oa = a + ba * (1 - a)
    rgb = tuple(int((col[i] * a + bg[i] * ba * (1 - a)) / oa) for i in range(3))
    img.putpixel((x, y), rgb + (int(oa * 255),))


def draw_diamond(tier_index, size, pal, frame):
    """Elmas kristal: dikey eskenar dortgen, sol-ust isikli 4 yuz + ust sirt cizgisi, yavasca suzulur (1 px), kareler 6-10
    arasi capraz isik cizgisi gecer, ust sag kosede yildiz cakar. Hale yuvarlak orbla ayni dil: sekli 1/2/3 piksel saran
    halkalar (ic acik ton nabiz, orta parlama dama, dis seyrek). Boy = TIERS'teki cap degeri (9/9/12/12/14)."""
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    outline, dark, mid, light, hi = [hexc(c) for c in pal]
    tones = [dark, mid, light, hi]
    cx = cy = CELL / 2.0
    w, h = size * 0.42, size * 0.66
    bob = round(math.sin(frame / FRAMES * math.tau) * 1.0)
    sweep = (frame - 6) / 4.0 if 6 <= frame <= 10 else None

    def inside(x, y):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy - bob
        return abs(dx) / w + abs(dy) / h <= 1.0

    def shade(x, y):
        dx, dy = x + 0.5 - cx, y + 0.5 - cy - bob
        if sweep is not None and abs((dx * 1.4 + dy) - (-h + 2 * h * sweep)) < 1.0:
            return 3
        if abs(dx) < 0.6 and dy < 0:
            return 3 if dy < -h * 0.35 else 2  # ust sirt cizgisi
        if dy < 0:
            return 2 if dx < 0 else 1
        return 1 if dx < 0 else 0

    mask = [[inside(x, y) for x in range(CELL)] for y in range(CELL)]

    def grow(src):
        out = [row[:] for row in src]
        for y in range(CELL):
            for x in range(CELL):
                if not src[y][x] and any(0 <= y + oy < CELL and 0 <= x + ox < CELL and src[y + oy][x + ox]
                                         for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = True
        return out

    m1 = grow(mask)
    m2 = grow(m1)
    m3 = grow(m2)
    pulse = 0.5 + 0.5 * math.sin(frame / FRAMES * math.tau)
    for y in range(CELL):
        for x in range(CELL):
            if mask[y][x]:
                continue
            h1, h2, h3 = halo_colors(mid, light, hi)
            if m1[y][x]:
                _blend(img, x, y, (h1[0], h1[1], h1[2], int(170 + 85 * pulse)))
            elif m2[y][x] and (x + y) % 2 == 0:
                _blend(img, x, y, (h2[0], h2[1], h2[2], int(110 + 90 * pulse)))
            elif m3[y][x] and x % 2 == 0 and y % 2 == 0:
                _blend(img, x, y, (h3[0], h3[1], h3[2], int(50 + 90 * pulse)))
    for y in range(CELL):
        for x in range(CELL):
            if not mask[y][x]:
                continue
            edge = any(not (0 <= y + oy < CELL and 0 <= x + ox < CELL and mask[y + oy][x + ox])
                       for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            _blend(img, x, y, outline if edge else tones[shade(x, y)])
    # Yildiz: kare 1 nokta, 2 arti, 3 buyuk (kademe 4+ kollar 3 px), 4 arti, 5 nokta.
    sx, sy = round(cx + w * 0.9), round(cy - h * 0.55 + bob)
    arm = {1: 0, 2: 1, 3: 3 if tier_index >= 3 else 2, 4: 1, 5: 0}.get(frame, -1)
    if arm == 0:
        _blend(img, sx, sy, (hi[0], hi[1], hi[2], 220))
    elif arm > 0:
        _blend(img, sx, sy, hi)
        for i in range(1, arm + 1):
            col = (light[0], light[1], light[2], 255 if i == 1 else 150)
            for ox, oy in ((i, 0), (-i, 0), (0, i), (0, -i)):
                _blend(img, sx + ox, sy + oy, col)
    return img


def main():
    draw = draw_diamond if SHAPE == "diamond" else draw_orb
    for i, (name, diameter, pal) in enumerate(TIERS):
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for f in range(FRAMES):
            sheet.paste(draw(i, diameter, pal, f), (f * CELL, 0))
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
