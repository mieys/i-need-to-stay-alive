#!/usr/bin/env python3
"""Silah efektleri + yeni Bumerang gorunumu - hepsi pixel-art spritesheet.

Kullanici istegi (2026-09-24):
  "yay, tufek tabanca arbalet tuftuf gibi silahlarin mermilerinin atis aninda arkalarinda mermilerinin rengine bagli
   olacak sekilde acik renkte iz efekti hazirla" -> trail_*: BEYAZ/gri tonlu iz (oyunda mermi rengine gore modulate).
  "kilic ve boomerang silahlarina ozel calisma bicimlerine uygun yeni ozel efektler de hazirla" ->
   sword_arc_*: Uzunkilic oyuncunun etrafinda DONEN bir kilic - arkasindan yorunge boyunca uzanan hilal iz.
   boomerang_whoosh_* / boomerang_catch_*: donen bumerangin etrafinda hava cizgileri + geri yakalanma pariltisi.
  "boomerangin gorunusunu yeniden tasarla (ikonuyla boomerangin oyun ici goruntusu ayni olmali)" ->
   boomerang art 48x48 (1 px kontur, 3 ton ahsap, boyali serit): icon.png bunun TAM 4x buyutulmusu, oyun ici mermi
   AYNI cizimin 12 onceden dondurulmus karesi (RotSprite benzeri: 4x EPX buyut -> dondur -> blok merkezinden ornekle -
   pixel izgarasi bozulmadan doner).
  "bu efektler pixel sanati olacak ve spritesheete donusturulecek" (bkz. hafiza: 48x48 yogunluk, 1 texel detay).

Cikti:
  assets/fx/trails/trail_sheet.png + trail_frames.tres            ("launch" tek sefer, "fly" dongu)
  assets/fx/sword_arc/arc_sheet.png + arc_frames.tres             ("loop" dongu - eski donen kilic; artik kullanilmiyor)
  assets/fx/sword_sweep/sweep_sheet.png + sweep_frames.tres       ("play" tek sefer - bkz. gen_sword_sweep)
  assets/fx/sword_hit/hit_sheet.png + hit_frames.tres             ("play" tek sefer - Uzunkilic isabeti, gen_sword_hit)

  assets/fx/tufek_hit/hit_sheet.png + hit_frames.tres             ("play" tek sefer - Tufek mermi isabeti, gen_tufek_hit)

Sadece kilic savurusu + isabeti: python tools/gen_weapon_fx_sprites.py sweep
Sadece tufek isabeti: python tools/gen_weapon_fx_sprites.py tufek
  assets/weapons/boomerang/art48.png                              (48x48 kaynak cizim)
  assets/weapons/boomerang/icon.png                               (200x200 - art48 x4, ortali)
  assets/weapons/boomerang/rot_sheet.png                          (12 x 48x48 onceden dondurulmus - artik kullanilmiyor)
  assets/weapons/boomerang/rot24_sheet.png + rot24_frames.tres    (24 x 48x48, 15 derece - gen_boomerang_rot24)
  assets/fx/boomerang/whoosh_sheet.png + whoosh_frames.tres       ("loop")
  assets/fx/boomerang/catch_sheet.png + catch_frames.tres         ("play" tek sefer)
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgba(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def put(im, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < im.width and 0 <= y < im.height:
        old = im.getpixel((x, y))
        if c[3] >= old[3]:
            im.putpixel((x, y), c)


def save_sheet(frames, path):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote", path, sheet.size)
    return w, h


def res(path):
    return "res://" + os.path.relpath(path, ROOT).replace("\\", "/")


# ------------------------------------------------------------------------------------------------ mermi izi
def trail_frame(length, flick, grow=1.0):
    """Sagda (bas) mermiye yapisik, sola dogru incelip saydamlasan beyaz iz. 4 alfa basamagi (dither yok), 3 px kalin
    cekirdek + 1 px yumusak kenar sirasi. flick: kareler arasi kucuk kayma (parilti hissi)."""
    W, H = 32, 7
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    L = max(2, int(round(length * grow)))
    cy = H // 2
    for i in range(L):
        x = W - 1 - i
        f = i / max(L - 1, 1)  # 0 bas .. 1 kuyruk
        if f < 0.2:
            a, half = 0.95, 1
        elif f < 0.45:
            a, half = 0.7, 1
        elif f < 0.7:
            a, half = 0.45, 0 if (i + flick) % 3 else 1
        else:
            a, half = 0.22, 0
        if f > 0.85 and (i + flick) % 2:
            continue
        for dy in range(-half, half + 1):
            put(im, x, cy + dy, rgba(1, 1, 1, a if dy == 0 else a * 0.55))
    # bas: 2 px parlak nokta
    put(im, W - 1, cy, rgba(1, 1, 1, 1))
    put(im, W - 2, cy, rgba(1, 1, 1, 1))
    return im


def gen_trails():
    out = os.path.join(ROOT, "assets", "fx", "trails")
    launch = [trail_frame(28, 0, g) for g in (0.25, 0.5, 0.75, 1.0)]
    fly = [trail_frame(28, k) for k in range(3)]
    cell = save_sheet(launch + fly, os.path.join(out, "trail_sheet.png"))
    write_sprite_frames(os.path.join(out, "trail_frames.tres"), res(os.path.join(out, "trail_sheet.png")), cell[0], cell[1],
                        [("launch", (0, 0), 4, False, 40.0), ("fly", (4, 0), 3, True, 18.0)])


# ------------------------------------------------------------------------------------------------ kilic yorunge izi
def gen_sword_arc():
    """Merkez (oyuncu) karenin ortasinda; iz R yaricapli yorunge boyunca, bas 0 derecede (+x), kuyruk -100 dereceye
    uzanir (kilic artan aciyla doner - bkz. weapon_orbit_math.gd). Bas kalin ve parlak (beyaz-mavi celik), kuyruga dogru
    incelir ve 4 basamakta saydamlasir; kenarda tek tuk kivilcim."""
    out = os.path.join(ROOT, "assets", "fx", "sword_arc")
    R = 60
    S = R * 2 + 16
    c = S // 2
    frames = []
    span = math.radians(100)
    for fi in range(4):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        steps = int(span * R * 1.6)
        for i in range(steps):
            f = i / steps  # 0 bas .. 1 kuyruk
            a = -f * span
            thick = 5 - int(f * 4.5)  # 5 px -> 1 px
            if f < 0.25:
                col, al = (0.92, 0.97, 1.0), 0.95
            elif f < 0.5:
                col, al = (0.75, 0.88, 1.0), 0.72
            elif f < 0.75:
                col, al = (0.6, 0.78, 1.0), 0.45
            else:
                col, al = (0.5, 0.7, 1.0), 0.22
            for t in range(max(1, thick)):
                rr = R - 2 + t - thick // 2
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(*col, al))
            # dis kenarda ince parlak cizgi (celik yansimasi)
            if f < 0.6:
                rr = R - 2 + thick // 2 + 1
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, al * 0.8))
        # kivilcimlar: kareye gore kayan 3 nokta
        for k in range(3):
            f = ((k * 0.31 + fi * 0.09) % 0.8) + 0.05
            a = -f * span
            rr = R + 4 + (k % 2) * 2
            put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, 0.9 - f))
        frames.append(im)
    cell = save_sheet(frames, os.path.join(out, "arc_sheet.png"))
    write_sprite_frames(os.path.join(out, "arc_frames.tres"), res(os.path.join(out, "arc_sheet.png")), cell[0], cell[1],
                        [("loop", (0, 0), 4, True, 16.0)])


def gen_sword_sweep():
    """Kullanici istegi (2026-09-26): "kilicin calisma bicimini degistiriyoruz artik etrafimizda donmesi yerine
    hedefledigi dusmana dogru savurulsun ... savurusunu daha guzel yap". Uzunkilic artik hedefe atilip onun uzerinden
    genis bir yay cizerek suprur (bkz. scripts/sword_swing_math.gd). Bu, bicagin UCUNUN izledigi yay boyunca kalan hilal:
    merkez (el/pivot) karenin ortasinda, yay -75..+75 derece (+x = hedef yonu, y asagi = saat yonu). Ilk 4 kare bicakla
    birlikte buyur (bas parlak ve kalin, kuyruk ince ve dither'li saydam), son 4 karede kuyruktan basa dogru erir.
    Palet eski donen kilic iziyle (gen_sword_arc) ayni celik beyaz-mavi. Ters yone savurusta sprite dikeyde aynalanir."""
    out = os.path.join(ROOT, "assets", "fx", "sword_sweep")
    R = 32
    S = R * 2 + 8
    c = S / 2.0
    a_s, a_e = math.radians(-75), math.radians(75)
    T_MAX = 7.0
    grow = [(0.0, 0.30), (0.0, 0.58), (0.06, 0.82), (0.18, 1.0)]
    fade = [(0.36, 1.0, 0.9), (0.58, 1.0, 0.7), (0.76, 1.0, 0.45), (0.9, 1.0, 0.25)]
    plan = [(t, h, 1.0) for t, h in grow] + fade
    frames = []
    for fi, (tail, head, fa) in enumerate(plan):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for y in range(S):
            for x in range(S):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                r = math.hypot(dx, dy)
                if r > R + 0.5 or r < R - T_MAX - 1:
                    continue
                u = (math.atan2(dy, dx) - a_s) / (a_e - a_s)
                if u < tail or u > head or head - tail < 1e-3:
                    continue
                v = (u - tail) / (head - tail)  # 0 kuyruk .. 1 bas
                thick = T_MAX * (v ** 0.9)
                if v > 0.86:
                    thick *= 1.0 - (v - 0.86) / 0.14 * 0.55  # bas ucu sivrilir
                if fi >= 4:
                    thick *= 0.55 + 0.45 * fa  # erirken incelir
                d = R - r  # 0 = dis kenar
                if d < -0.5 or d > thick:
                    continue
                if v < 0.22:
                    if (x + y) % 2:
                        continue
                    al = 0.35
                elif v < 0.5:
                    al = 0.62
                else:
                    al = 0.95
                if d < 1.0:
                    col = (1.0, 1.0, 1.0)
                elif d < thick * 0.6:
                    col = (0.82, 0.92, 1.0)
                else:
                    col = (0.56, 0.74, 1.0)
                    al *= 0.85
                put(im, x, y, rgba(*col, al * fa))
        # kivilcimlar: bicak basinin hemen disinda, karelere gore kayan 2-3 piksel
        if 1 <= fi <= 5:
            for k in range(3):
                uu = min(head, 1.0) - 0.05 - k * 0.11 - (fi % 2) * 0.03
                if uu < tail:
                    continue
                a = a_s + (a_e - a_s) * uu
                rr = R + 2 + (k % 2) * 2
                put(im, c - 0.5 + math.cos(a) * rr, c - 0.5 + math.sin(a) * rr, rgba(1, 1, 1, (0.9 - k * 0.25) * fa))
        frames.append(im)
    cell = save_sheet(frames, os.path.join(out, "sweep_sheet.png"))
    write_sprite_frames(os.path.join(out, "sweep_frames.tres"), res(os.path.join(out, "sweep_sheet.png")), cell[0], cell[1],
                        [("play", (0, 0), 8, False, 26.0)])


def gen_sword_hit():
    """Uzunkilic isabet efekti (2026-09-26): savrulan kilicin celik mavisi hilaliyle uyumlu kucuk bir "kesik" parlamasi.
    Eski kirmizi "Isabet 2" cizgileri (fx_hit_slash_streak) yeni hilalle catisiyordu. +x = saldiri yonu (weapon.gd
    _spawn_melee_hit_fx rotation = direction.angle()); kesik cizgisi buna DIK (dikey), yani bicagin supurme yonunde.
    Kivilcimlar ileriye (hedefin arkasina) ve biraz geriye sacilir; 6 kare, tek sefer."""
    out = os.path.join(ROOT, "assets", "fx", "sword_hit")
    S = 30
    c = S // 2
    WHITE = (1.0, 1.0, 1.0)
    PALE = (0.82, 0.92, 1.0)
    BLUE = (0.56, 0.74, 1.0)
    # (cizgi yari boyu, kalinlik, alfa, bosluklu mu), kivilcim mesafesi, kivilcim alfasi
    plan = [(5, 1, 1.0, False, 0, 0.0), (10, 2, 1.0, False, 3, 1.0), (12, 2, 0.9, False, 6, 0.95),
            (12, 1, 0.65, True, 9, 0.75), (9, 1, 0.38, True, 11, 0.45), (5, 1, 0.18, True, 12, 0.2)]
    shards = [math.radians(a) for a in (18, -24, 52, -58, 165, 195)]
    frames = []
    for half, thick, al, gappy, sd, sal in plan:
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for dy in range(-half, half + 1):
            if gappy and dy % 3 == 1:
                continue
            taper = 1.0 - abs(dy) / (half + 1.0)
            y = c + dy
            put(im, c, y, rgba(*WHITE, al * (0.55 + 0.45 * taper)))
            if thick >= 2 and abs(dy) < half - 1:
                put(im, c + 1, y, rgba(*PALE, al * 0.9))
                put(im, c - 1, y, rgba(*BLUE, al * 0.6))
        if half >= 10 and not gappy:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                put(im, c + dx, c + dy, rgba(*WHITE, al))
        if sd > 0:
            for k, a in enumerate(shards):
                d = sd * (0.75 if k >= 4 else 1.0)
                x, y = c + math.cos(a) * d, c + math.sin(a) * d
                put(im, x, y, rgba(*(WHITE if k % 2 == 0 else PALE), sal))
                if sd <= 6:
                    put(im, x - math.cos(a), y - math.sin(a), rgba(*BLUE, sal * 0.6))
        frames.append(im)
    cell = save_sheet(frames, os.path.join(out, "hit_sheet.png"))
    write_sprite_frames(os.path.join(out, "hit_frames.tres"), res(os.path.join(out, "hit_sheet.png")), cell[0], cell[1],
                        [("play", (0, 0), 6, False, 24.0)])


def gen_tufek_hit():
    """Tufek mermi isabeti (kullanici istegi 2026-09-28: "tufek ates ettiginde dusmanda cikan mermi isabet efektini
    yeniden tasarla, pixel tarzda spritesheet olsun"). Eskiden kilicla paylasilan kirmizi "Isabet 2" cizgileri
    (fx_hit_slash_streak) kullaniliyordu. Merminin altin izine (projectile.gd TRAIL_TINTS "tufek_projectile") uyan
    beyaz-altin-kehribar palet: once sert bir namlu-disi flas (ileri kolu uzun 4 kollu yildiz), sonra kirik bir darbe
    halkasi genisler, kivilcimlar ileri (mermi yonune, +x) bir koni halinde ve ikisi geri seker, sonunda kucuk dithered
    bir duman/toz kalir. +x = ucus yonu (projectile.gd impact_face_direction ile doner). 8 kare, tek sefer."""
    out = os.path.join(ROOT, "assets", "fx", "tufek_hit")
    S = 44
    c = S // 2
    WHITE = (1.0, 1.0, 0.95)
    GOLD = (1.0, 0.93, 0.6)
    AMBER = (1.0, 0.72, 0.3)
    EMBER = (0.85, 0.4, 0.15)
    SMOKE = (0.62, 0.57, 0.52)

    def star(im, fwd, back, side, al, core):
        """Merkezde 4 kollu flas: +x kolu fwd, -x kolu back, dikey kollar side piksel. Kol ucu altina, kok beyaza doner."""
        for dx, dy, ln in ((1, 0, fwd), (-1, 0, back), (0, 1, side), (0, -1, side)):
            for i in range(1, ln + 1):
                f = i / (ln + 1)
                col = WHITE if f < 0.35 else (GOLD if f < 0.7 else AMBER)
                put(im, c + dx * i, c + dy * i, rgba(*col, al * (1.0 - 0.45 * f)))
        for dx in range(-core, core + 1):
            for dy in range(-core, core + 1):
                if abs(dx) + abs(dy) <= core:
                    put(im, c + dx, c + dy, rgba(*(WHITE if abs(dx) + abs(dy) < core else GOLD), al))

    def ring(im, r, col, al, gap):
        """1 px kirik halka; gap > 0 ise her gap'inci piksel bos (dagilma hissi)."""
        n = max(8, int(math.tau * r * 1.5))
        seen = set()
        for i in range(n):
            a = i / n * math.tau
            p = (int(round(c + math.cos(a) * r)), int(round(c + math.sin(a) * r)))
            if p in seen:
                continue
            seen.add(p)
            if gap and len(seen) % gap == 0:
                continue
            put(im, p[0], p[1], rgba(*col, al))

    # kivilcim yonleri: ileri koni + iki geri sekme (kisa)
    sparks = [(math.radians(a), k) for a, k in ((-38, 1.0), (-14, 1.15), (9, 1.05), (33, 0.95), (162, 0.55), (203, 0.6))]

    def spark_pass(im, d, streak, head_col, tail_col, al):
        for a, k in sparks:
            dd = d * k
            x, y = c + math.cos(a) * dd, c + math.sin(a) * dd
            put(im, x, y, rgba(*head_col, al))
            for s in range(1, streak + 1):
                put(im, x - math.cos(a) * s, y - math.sin(a) * s, rgba(*tail_col, al * (0.7 - 0.2 * s)))

    def smoke(im, r, al, phase):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y > r * r or (x + y + phase) % 2:
                    continue
                put(im, c - 1 + x, c + y, rgba(*SMOKE, al))

    frames = []
    # 0: ilk temas - kucuk beyaz cekirdek
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    star(im, 3, 2, 2, 1.0, 1)
    frames.append(im)
    # 1: tam flas - ileri kolu uzun yildiz
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    star(im, 9, 4, 5, 1.0, 2)
    frames.append(im)
    # 2: flas kisalir, kucuk darbe halkasi, kivilcimlar halkanin DISINA firlar
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ring(im, 3, GOLD, 0.7, 0)
    star(im, 6, 3, 3, 0.85, 1)
    spark_pass(im, 7, 2, WHITE, GOLD, 1.0)
    frames.append(im)
    # 3
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ring(im, 5, AMBER, 0.4, 3)
    star(im, 2, 1, 1, 0.6, 1)
    spark_pass(im, 11, 2, GOLD, AMBER, 0.95)
    frames.append(im)
    # 4: halka biter, duman baslar
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    smoke(im, 2, 0.3, 0)
    put(im, c, c, rgba(*AMBER, 0.5))
    spark_pass(im, 14, 2, AMBER, EMBER, 0.8)
    frames.append(im)
    # 5
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    smoke(im, 3, 0.24, 1)
    spark_pass(im, 16, 1, AMBER, EMBER, 0.55)
    frames.append(im)
    # 6
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    smoke(im, 3, 0.16, 0)
    spark_pass(im, 17, 0, EMBER, EMBER, 0.35)
    frames.append(im)
    # 7: son kor pikseller
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    smoke(im, 3, 0.08, 1)
    for a, k in sparks[1:3]:
        put(im, c + math.cos(a) * 18 * k, c + math.sin(a) * 18 * k, rgba(*EMBER, 0.2))
    frames.append(im)

    cell = save_sheet(frames, os.path.join(out, "hit_sheet.png"))
    write_sprite_frames(os.path.join(out, "hit_frames.tres"), res(os.path.join(out, "hit_sheet.png")), cell[0], cell[1],
                        [("play", (0, 0), 8, False, 30.0)])


# ------------------------------------------------------------------------------------------------ bumerang
WOOD =[rgba(0.86, 0.62, 0.36), rgba(0.66, 0.42, 0.22), rgba(0.45, 0.27, 0.13)]  # acik, orta, koyu
OUTLINE = rgba(0.16, 0.08, 0.05)
PAINT_A = rgba(0.95, 0.9, 0.76)  # krem serit
PAINT_B = rgba(0.78, 0.2, 0.14)  # kirmizi serit


def boomerang_art():
    """48x48: klasik V bicimli bumerang, dirsek ustte-ortada, iki kol asagi-disa acilir, hafif kavisli. Isik sol-ustten:
    ust kenar acik, alt kenar koyu, 1 px koyu kontur, her kolun ucuna yakin krem+kirmizi boyali serit."""
    N = 48
    big = 8  # alt ornekleme icin once 8x cozunurlukte maske
    M = Image.new("L", (N * big, N * big), 0)
    d = ImageDraw.Draw(M)
    # kavisli kol: iki cubic benzeri egriyi kalin cizgiyle ciz
    def arm(p0, p1, p2, w0, w1):
        pts = []
        for i in range(41):
            t = i / 40
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            w = w0 + (w1 - w0) * t
            pts.append((x, y, w))
        for x, y, w in pts:
            r = w * big / 2
            d.ellipse([x * big - r, y * big - r, x * big + r, y * big + r], fill=255)
    elbow = (24, 12)
    arm(elbow, (14, 16), (5, 33), 9.0, 6.5)
    arm(elbow, (34, 16), (43, 33), 9.0, 6.5)
    mask = M.resize((N, N), Image.BOX).point(lambda v: 255 if v >= 128 else 0)
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mp = mask.load()
    inside = lambda x, y: 0 <= x < N and 0 <= y < N and mp[x, y] > 0
    for y in range(N):
        for x in range(N):
            if not inside(x, y):
                continue
            edge_up = not inside(x, y - 1) or not inside(x - 1, y - 1)
            edge_dn = not inside(x, y + 1) or not inside(x + 1, y + 1)
            col = WOOD[0] if edge_up else (WOOD[2] if edge_dn else WOOD[1])
            im.putpixel((x, y), col)
    # boyali seritler (kol uclarina yakin, kola dik)
    for side in (-1, 1):
        for t, pc in ((0.62, PAINT_A), (0.7, PAINT_B), (0.78, PAINT_A)):
            # kol ekseni uzerindeki nokta
            p0, p1, p2 = elbow, (24 + side * 10, 16), (24 + side * 19, 33)
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            tx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
            ty = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
            ln = math.hypot(tx, ty)
            nx, ny = -ty / ln, tx / ln
            for s in range(-6, 7):
                px_, py_ = int(round(x + nx * s * 0.5)), int(round(y + ny * s * 0.5))
                if inside(px_, py_):
                    im.putpixel((px_, py_), pc)
    # dirsekte kucuk parlak nokta (cila)
    for px_, py_ in ((23, 11), (24, 11), (22, 12)):
        if inside(px_, py_):
            im.putpixel((px_, py_), rgba(0.97, 0.8, 0.55))
    # 1 px dis kontur
    out = im.copy()
    for y in range(N):
        for x in range(N):
            if inside(x, y):
                continue
            if any(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), OUTLINE)
    return out


def epx(im):
    """Scale2x/EPX: kenarlari yumusatan 2x buyutme (RotSprite'in ilk adimi)."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    o = out.load()
    g = lambda x, y: src[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]
    for y in range(h):
        for x in range(w):
            P = g(x, y)
            A, B, C, D = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            e0 = A if (C == A and C != D and A != B) else P
            e1 = B if (A == B and A != C and B != D) else P
            e2 = C if (D == C and D != B and C != A) else P
            e3 = D if (B == D and B != A and D != C) else P
            o[2 * x, 2 * y] = e0
            o[2 * x + 1, 2 * y] = e1
            o[2 * x, 2 * y + 1] = e2
            o[2 * x + 1, 2 * y + 1] = e3
    return out


def rotsprite(im, deg):
    up = epx(epx(im))  # 4x
    rot = up.rotate(-deg, resample=Image.NEAREST, center=(up.width / 2, up.height / 2))
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = rot.load()
    for y in range(h):
        for x in range(w):
            out.putpixel((x, y), r[x * 4 + 2, y * 4 + 2])
    return out


def gen_boomerang():
    wdir = os.path.join(ROOT, "assets", "weapons", "boomerang")
    fxdir = os.path.join(ROOT, "assets", "fx", "boomerang")
    art = boomerang_art()
    os.makedirs(wdir, exist_ok=True)
    art.save(os.path.join(wdir, "art48.png"))
    icon = Image.new("RGBA", (200, 200), (0, 0, 0, 0))
    icon.paste(art.resize((192, 192), Image.NEAREST), (4, 4))
    icon.save(os.path.join(wdir, "icon.png"))
    print("wrote icon.png (art48 x4)")
    rots = [rotsprite(art, k * 30) for k in range(12)]
    cell = save_sheet(rots, os.path.join(wdir, "rot_sheet.png"))
    ## "spin": kare = donus acisi (boomerang_projectile.gd kareyi aciya gore SECER, oynatmaz - hiz 0).
    write_sprite_frames(os.path.join(wdir, "rot_frames.tres"), res(os.path.join(wdir, "rot_sheet.png")), cell[0], cell[1],
                        [("spin", (0, 0), 12, True, 0.0)])

    # hava cizgileri: donen bumerangin etrafinda 3 kavisli beyaz cizgi, kare basina donerek kayar (4 kare dongu)
    S = 64
    c = S // 2
    wh = []
    for fi in range(4):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for k in range(3):
            base = k * math.tau / 3 + fi * (math.tau / 12)
            for i in range(22):
                a = base + i * 0.045
                rr = 25 + (k % 2)
                al = 0.75 * (1 - i / 22)
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(1, 1, 1, al))
        wh.append(im)
    cell = save_sheet(wh, os.path.join(fxdir, "whoosh_sheet.png"))
    write_sprite_frames(os.path.join(fxdir, "whoosh_frames.tres"), res(os.path.join(fxdir, "whoosh_sheet.png")), cell[0], cell[1],
                        [("loop", (0, 0), 4, True, 20.0)])

    # yakalanma pariltisi: 4 kollu yildiz + halka, 6 kare
    S = 32
    c = S // 2
    ct = []
    for fi in range(6):
        t = fi / 5
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ln = int(3 + t * 9)
        al = 1.0 - t * 0.85
        for i in range(ln):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(im, c + dx * i, c + dy * i, rgba(1, 0.95, 0.75, al * (1 - i / (ln + 1))))
        rr = 2 + t * 11
        for i in range(int(math.tau * rr)):
            a = i / (math.tau * rr) * math.tau
            if i % 3 == 0:
                put(im, c + math.cos(a) * rr, c + math.sin(a) * rr, rgba(0.95, 0.75, 0.45, al * 0.8))
        ct.append(im)
    cell = save_sheet(ct, os.path.join(fxdir, "catch_sheet.png"))
    write_sprite_frames(os.path.join(fxdir, "catch_frames.tres"), res(os.path.join(fxdir, "catch_sheet.png")), cell[0], cell[1],
                        [("play", (0, 0), 6, False, 24.0)])


def gen_boomerang_rot24():
    """Kullanici bildirimi (2026-09-26): "boomerangin gidip gelme animasyonu cok goz yoruyor". 12 karelik (30 derece)
    donus sayfasi hizli donuste titriyordu - AYNI 48x48 cizimin 24 karelik (15 derece) RotSprite sayfasi. Mevcut
    rot_sheet.png/rot_frames.tres'e dokunmaz (ayri dosya); boomerang_projectile.gd bunu kullanir."""
    wdir = os.path.join(ROOT, "assets", "weapons", "boomerang")
    art = boomerang_art()
    rots = [rotsprite(art, k * 15) for k in range(24)]
    cell = save_sheet(rots, os.path.join(wdir, "rot24_sheet.png"))
    write_sprite_frames(os.path.join(wdir, "rot24_frames.tres"), res(os.path.join(wdir, "rot24_sheet.png")), cell[0], cell[1],
                        [("spin", (0, 0), 24, True, 0.0)])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "sweep":
        gen_sword_sweep()
        gen_sword_hit()
    elif len(sys.argv) > 1 and sys.argv[1] == "rot24":
        gen_boomerang_rot24()
    elif len(sys.argv) > 1 and sys.argv[1] == "tufek":
        gen_tufek_hit()
    else:
        gen_trails()
        gen_sword_arc()
        gen_sword_sweep()
        gen_sword_hit()
        gen_boomerang()
        gen_boomerang_rot24()
