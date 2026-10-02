"""Eşya pasif efektleri (2026-10-02, yeni eşya sistemi) -> assets/fx/items/<ad>_sheet.png + <ad>_frames.tres.

Kullanıcı: "bazı itemlerin bazı pasif özellikleri için minimal ancak gözle görülebilir efektler hazırlanması gerekiyor,
bunların spritesheet pixel sanatında olmasını sağla". Oyunun FX dili (hafıza: fx-texel-density-and-soft-ends): içi dolu
kütleler, koyu kontur, ilk karelerde parlama, sönerken hilallere/kıvılcımlara incelir (keskin kesik yok). 1 sayfa pikseli
= 1 karakter pikseli (sahnelerde ölçek 2.424 karakter kökü altında / 1.212 dünyada).

Sahneler: scenes/fx_item_<ad>.tscn (fx_oneshot_sprite.gd). Çalıştır: python tools/gen_item_fx.py (+ Godot --import).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
from gen_hadime_fx import plot, disc, ring, line, spark, outline, fade_img, sheet, new  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "items")
RES = "res://assets/fx/items/"
TAU = 2 * math.pi

ICE = [(16, 40, 84), (44, 104, 184), (100, 178, 240), (176, 230, 255), (240, 252, 255)]
GOLD = [(70, 40, 6), (168, 112, 20), (236, 182, 52), (255, 226, 120), (255, 250, 214)]
SUN = [(110, 34, 6), (220, 92, 18), (255, 170, 40), (255, 222, 104), (255, 252, 220)]
SHIELD = [(14, 30, 70), (30, 70, 150), (70, 144, 236), (150, 208, 255), (234, 248, 255)]
BLOOD = [(48, 6, 12), (120, 16, 28), (196, 36, 48), (240, 100, 98), (255, 200, 196)]
FIRE = [(80, 16, 12), (184, 46, 24), (240, 118, 36), (255, 190, 70), (255, 242, 180)]
VOID = [(22, 6, 36), (64, 24, 108), (124, 60, 196), (186, 136, 250), (240, 222, 255)]
HOLY = [(90, 60, 10), (200, 150, 40), (255, 214, 96), (255, 242, 176), (255, 255, 240)]
HEAL = [(20, 60, 24), (48, 140, 56), (96, 206, 96), (176, 248, 160), (240, 255, 230)]


def save(name, frames, anim="play", loop=False, fps=16.0):
    os.makedirs(OUT, exist_ok=True)
    sheet(frames).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = frames[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])
    print("   %-18s %dx%d x %d" % (name, w, h, len(frames)))


def ease_out(t):
    return 1.0 - (1.0 - t) * (1.0 - t)


def thick_ring(im, cx, cy, r, w, pal, a=1.0, squash=1.0, gap_fn=None):
    """Dolu halka bandı: dış kenar açık, iç kenar koyu (sol üstten ışık)."""
    for y in range(int(cy - r - 2), int(cy + r + 3)):
        for x in range(int(cx - r - 2), int(cx + r + 3)):
            dx = (x + 0.5 - cx)
            dy = (y + 0.5 - cy) / squash
            d = math.hypot(dx, dy)
            if r - w <= d <= r:
                ang = math.atan2(dy, dx)
                if gap_fn and gap_fn(ang):
                    continue
                lit = -(math.cos(ang) * -0.55 + math.sin(ang) * -0.83)
                k = 2 + (1 if lit > 0.3 else 0) - (1 if lit < -0.4 else 0)
                if d > r - 0.9:
                    k = min(4, k + 1)
                plot(im, x, y, pal[k], a, True)


def shield_shape(im, cx, cy, w, h, pal, a=1.0):
    """Küçük kalkan arması: dolu gövde + açık sol kenar + kontur."""
    for y in range(int(cy - h), int(cy + h) + 1):
        t = (y - (cy - h)) / max(1.0, 2 * h)
        half = w if t < 0.55 else w * max(0.0, 1.0 - (t - 0.55) / 0.45)
        for x in range(int(cx - half), int(cx + half) + 1):
            k = 2 if x > cx else 3
            if y < cy - h + 2:
                k = 4
            plot(im, x, y, pal[k], a, True)
    line(im, cx, cy - h + 2, cx, cy + h - 2, pal[4], a)


# ---------------------------------------------------------------- Zaman Kıran: buzlu saat kadranı açılır, akrep geri döner,
# kadran buz kıymıklarına dağılır (ölümsüzlük + donma anı)
def time_freeze():
    frames = []
    n = 14
    S = 60
    cx, cy = S / 2, S / 2 - 2
    rnd = random.Random(7)
    shards = [(rnd.uniform(0, TAU), rnd.uniform(0.8, 1.2)) for _ in range(12)]
    for i in range(n):
        t = i / (n - 1)
        im = new(S, S)
        if i <= 8:
            g = ease_out(min(1.0, i / 4.0))
            r = 8 + 16 * g
            fade = 1.0 if i < 7 else 0.8
            thick_ring(im, cx, cy, r, 3.0, ICE, fade, 0.92)
            # 12 saat işareti
            for k in range(12):
                a = TAU * k / 12
                x = cx + math.cos(a) * (r - 4.5)
                y = cy + math.sin(a) * (r - 4.5) * 0.92
                plot(im, x, y, GOLD[3] if k % 3 == 0 else ICE[3], fade)
            # akrep/yelkovan geri sarar
            ang = -math.pi / 2 - t * TAU * 1.6
            line(im, cx, cy, cx + math.cos(ang) * (r - 6), cy + math.sin(ang) * (r - 6) * 0.92, ICE[4], fade)
            ang2 = -math.pi / 2 - t * TAU * 0.4
            line(im, cx, cy, cx + math.cos(ang2) * (r - 10), cy + math.sin(ang2) * (r - 10) * 0.92, GOLD[3], fade)
            disc(im, cx, cy, 1.5, ICE[4], fade)
            if i in (1, 2):
                disc(im, cx, cy, 6 - i, ICE[4], 0.8)
        if i >= 6:
            u = (i - 6) / (n - 7)
            for (a, sp) in shards:
                d = 22 + 12 * ease_out(u) * sp
                x = cx + math.cos(a) * d
                y = cy + math.sin(a) * d * 0.92
                ln = max(0.0, 3.0 * (1.0 - u))
                line(im, x, y, x + math.cos(a) * ln, y + math.sin(a) * ln * 0.92, ICE[3] if u < 0.5 else ICE[2], 1.0 - 0.6 * u)
                if u < 0.4:
                    plot(im, x, y, ICE[4], 1.0)
        outline(im, ICE[0], 0.8)
        frames.append(im)
    save("time_freeze", frames, fps=14.0)


# ---------------------------------------------------------------- Güneşin İradesi: arkada güneş diski + ışınlar, öne altın kalkan
def sun_will():
    frames = []
    n = 14
    S = 64
    cx, cy = S / 2, S / 2 - 4
    for i in range(n):
        t = i / (n - 1)
        im = new(S, S)
        g = ease_out(min(1.0, i / 5.0))
        fade = 1.0 if t < 0.65 else max(0.0, 1.0 - (t - 0.65) / 0.35)
        rays = 12
        for k in range(rays):
            a = TAU * k / rays + t * 0.6
            r0 = 9 * g
            r1 = (16 + (6 if k % 2 == 0 else 2)) * g + 6 * t
            w = 2.2 if k % 2 == 0 else 1.4
            for s in range(int(r1 - r0) + 1):
                rr = r0 + s
                taper = 1.0 - s / max(1.0, r1 - r0)
                x = cx + math.cos(a) * rr
                y = cy + math.sin(a) * rr
                disc(im, x, y, max(0.5, w * taper), SUN[3] if s < (r1 - r0) * 0.6 else SUN[2], fade)
        disc(im, cx, cy, 8.5 * g, SUN[2], fade)
        disc(im, cx - 1.5, cy - 1.5, 6.0 * g, SUN[3], fade)
        disc(im, cx - 2.5, cy - 2.5, 2.5 * g, SUN[4], fade)
        if i >= 3:
            u = min(1.0, (i - 3) / 3.0)
            shield_shape(im, cx, cy + 12, 6 * u, 7 * u, GOLD, fade)
        if i in (0, 1):
            disc(im, cx, cy, 5 + 3 * i, SUN[4], 1.0)
        outline(im, SUN[0], 0.8 * fade)
        frames.append(im)
    save("sun_will", frames, fps=14.0)


# ---------------------------------------------------------------- Ölüm Eşiği: mavi kalkan arması parlar, halka dalgası, kırıntılar
def death_threshold():
    frames = []
    n = 12
    S = 52
    cx, cy = S / 2, S / 2 - 2
    rnd = random.Random(3)
    bits = [(rnd.uniform(0, TAU), rnd.uniform(0.7, 1.2)) for _ in range(9)]
    for i in range(n):
        t = i / (n - 1)
        im = new(S, S)
        g = ease_out(min(1.0, i / 3.0))
        fade = 1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.4)
        r = 10 + 13 * ease_out(t)
        thick_ring(im, cx, cy, r, max(1.0, 3.0 * (1.0 - t)), SHIELD, fade * 0.9, 0.85,
                   gap_fn=(lambda a, tt=t: tt > 0.5 and math.sin(a * 5 + 1.3) > 1.6 - 2.2 * tt))
        if i < 9:
            shield_shape(im, cx, cy, 7 * g, 9 * g, SHIELD, 1.0 if i < 7 else 0.55)
        if i >= 6:
            u = (i - 6) / (n - 7)
            for (a, sp) in bits:
                d = 8 + 14 * u * sp
                plot(im, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.85, SHIELD[3], 1.0 - u)
        if i == 1:
            disc(im, cx, cy, 9, SHIELD[4], 0.8)
        outline(im, SHIELD[0], 0.8 * fade)
        frames.append(im)
    save("death_threshold", frames, fps=16.0)


# ---------------------------------------------------------------- Aegis: gövdeden yukarı süzülen 3 küçük kalkan kıvılcımı
def aegis():
    frames = []
    n = 10
    W, H = 36, 48
    seeds = [(-9, 0.0), (8, 0.25), (0, 0.5)]
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        for (ox, ph) in seeds:
            u = (t + ph) % 1.0 if ph else t
            u = min(1.0, max(0.0, (t * 1.3) - ph * 0.6))
            if u <= 0.0 or u >= 1.0:
                continue
            x = W / 2 + ox + math.sin(u * 6) * 1.5
            y = H - 10 - 26 * u
            a = 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
            shield_shape(im, x, y, 2.4, 3.0, SHIELD, a)
            plot(im, x, y + 5, SHIELD[2], a * 0.8)
            plot(im, x, y + 7, SHIELD[1], a * 0.5)
        outline(im, SHIELD[0], 0.7)
        frames.append(im)
    save("aegis", frames, fps=14.0)


# ---------------------------------------------------------------- Anka: göğüste minik alev kalbi + yükselen közler
def phoenix():
    frames = []
    n = 10
    W, H = 36, 48
    rnd = random.Random(11)
    embers = [(rnd.uniform(-10, 10), rnd.uniform(0.0, 0.5), rnd.uniform(0.8, 1.2)) for _ in range(6)]
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        cx, cy = W / 2, H / 2 + 2
        pulse = 1.0 + 0.25 * math.sin(t * TAU)
        fade = 1.0 if t < 0.7 else max(0.0, 1.0 - (t - 0.7) / 0.3)
        # alev kalbi
        for (dx, r) in ((-2.2, 2.8), (2.2, 2.8)):
            disc(im, cx + dx * pulse, cy - 1, r * pulse, FIRE[2], fade)
        for y in range(int(cy), int(cy + 6 * pulse) + 1):
            half = max(0.0, 4.5 * pulse * (1.0 - (y - cy) / (6.0 * pulse)))
            for x in range(int(cx - half), int(cx + half) + 1):
                plot(im, x, y, FIRE[2], fade, True)
        disc(im, cx - 2, cy - 2, 1.2, FIRE[4], fade)
        for (ox, ph, sp) in embers:
            u = min(1.0, max(0.0, t * 1.2 - ph))
            if 0.0 < u < 1.0:
                x = cx + ox + math.sin(u * 5 + ox) * 1.5
                y = cy + 6 - 30 * u * sp
                plot(im, x, y, FIRE[3] if u < 0.5 else FIRE[2], 1.0 - u)
                if u < 0.4:
                    plot(im, x, y + 1, FIRE[1], 0.8 - u)
        outline(im, FIRE[0], 0.7 * fade)
        frames.append(im)
    save("phoenix", frames, fps=14.0)


# ---------------------------------------------------------------- Kızıl Hasat: kırmızı damlalar gövdeye akar + artı işareti
def crimson_harvest():
    frames = []
    n = 10
    S = 32
    cx, cy = S / 2, S / 2
    for i in range(n):
        t = i / (n - 1)
        im = new(S, S)
        if i < 6:
            u = i / 5.0
            for k in range(5):
                a = TAU * k / 5 + 0.4
                d = 13 * (1 - ease_out(u)) + 2
                x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
                disc(im, x, y, 1.6 * (1 - 0.4 * u), BLOOD[2], 1.0)
                plot(im, x - 0.5, y - 0.8, BLOOD[4], 1.0)
        if i >= 4:
            u = min(1.0, (i - 4) / 2.0)
            fade = 1.0 if t < 0.75 else max(0.0, 1.0 - (t - 0.75) / 0.25)
            for d in range(-3, 4):
                plot(im, cx + d * u, cy, BLOOD[3], fade, True)
                plot(im, cx, cy + d * u, BLOOD[3], fade, True)
            plot(im, cx, cy, BLOOD[4], fade, True)
        outline(im, BLOOD[0], 0.8)
        frames.append(im)
    save("crimson_harvest", frames, fps=16.0)


# ---------------------------------------------------------------- Kral'ın Kadehi: küçük altın kadeh yükselir, +1 parıltısı
def kings_chalice():
    frames = []
    n = 12
    W, H = 28, 40
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        cx = W / 2
        cy = H - 14 - 10 * ease_out(t)
        fade = 1.0 if t < 0.65 else max(0.0, 1.0 - (t - 0.65) / 0.35)
        g = ease_out(min(1.0, i / 3.0))
        # kase
        for y in range(int(cy - 5 * g), int(cy) + 1):
            half = 5 * g * (0.6 + 0.4 * (cy - y) / max(1.0, 5 * g))
            for x in range(int(cx - half), int(cx + half) + 1):
                plot(im, x, y, GOLD[2] if x > cx - 1 else GOLD[3], fade, True)
        line(im, cx - 5 * g, cy - 5 * g, cx + 5 * g, cy - 5 * g, GOLD[4], fade)
        plot(im, cx - 1, cy - 3 * g, (200, 30, 40), fade, True)  # yakut
        line(im, cx, cy + 1, cx, cy + 4 * g, GOLD[2], fade)
        line(im, cx - 3 * g, cy + 4 * g, cx + 3 * g, cy + 4 * g, GOLD[3], fade)
        if 3 <= i <= 8:
            spark(im, cx + 6, cy - 7, 2 if i % 2 else 1, GOLD[4], GOLD[3], 1.0)
        outline(im, GOLD[0], 0.8 * fade)
        frames.append(im)
    save("kings_chalice", frames, fps=14.0)


# ---------------------------------------------------------------- Kan Ağlayan: kan damlası mavi kalkan kıvılcımına dönüşür
def blood_shield():
    frames = []
    n = 10
    W, H = 28, 36
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        cx, cy = W / 2, H / 2
        if i < 5:
            u = i / 4.0
            y = cy - 8 + 8 * u
            disc(im, cx, y, 2.6, BLOOD[2], 1.0, ry=3.2)
            plot(im, cx, y - 4, BLOOD[2], 1.0)
            plot(im, cx - 1, y - 1, BLOOD[4], 1.0)
        else:
            u = (i - 5) / 4.0
            fade = 1.0 - max(0.0, u - 0.5) * 2.0
            shield_shape(im, cx, cy, 4 + 2 * u, 5 + 2 * u, SHIELD, fade)
            if i == 5:
                disc(im, cx, cy, 5, SHIELD[4], 0.8)
            for k in range(4):
                a = TAU * k / 4 + 0.6
                d = 7 + 6 * u
                plot(im, cx + math.cos(a) * d, cy + math.sin(a) * d, SHIELD[3], fade)
        outline(im, SHIELD[0] if i >= 5 else BLOOD[0], 0.8)
        frames.append(im)
    save("blood_shield", frames, fps=16.0)


# ---------------------------------------------------------------- Işığın Muhafızı: ayakta altın ışık halkası + yükselen ışık zerreleri
def light_guard():
    frames = []
    n = 12
    W, H = 48, 56
    rnd = random.Random(5)
    motes = [(rnd.uniform(-14, 14), rnd.uniform(0.0, 0.45), rnd.uniform(0.8, 1.2)) for _ in range(8)]
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        cx, fy = W / 2, H - 9
        g = ease_out(min(1.0, i / 4.0))
        fade = 1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.4)
        thick_ring(im, cx, fy, 6 + 12 * g, 2.0, HOLY, fade, 0.38)
        for (ox, ph, sp) in motes:
            u = min(1.0, max(0.0, t * 1.25 - ph))
            if 0.0 < u < 1.0:
                x = cx + ox * (1.0 - 0.3 * u)
                y = fy - 4 - 34 * u * sp
                a = 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
                plot(im, x, y, HOLY[4], a, True)
                plot(im, x, y + 1, HOLY[3], a * 0.8)
                if u < 0.3:
                    plot(im, x, y + 2, HOLY[2], a * 0.6)
        if 2 <= i <= 6:
            spark(im, cx + 9, fy - 30, 2, HOLY[4], HOLY[3], 1.0)
        outline(im, HOLY[0], 0.6 * fade)
        frames.append(im)
    save("light_guard", frames, fps=14.0)


# ---------------------------------------------------------------- Azrail'in Gözü: yaratığın üstünde mor göz açılır, kırmızı iris
# parlar ve kapanır (ilk vuruş = garanti kritik)
def azrail_mark():
    frames = []
    n = 12
    W, H = 30, 22
    cx, cy = W / 2, H / 2
    for i in range(n):
        t = i / (n - 1)
        im = new(W, H)
        if i <= 3:
            o = ease_out(i / 3.0)
        elif i <= 8:
            o = 1.0
        else:
            o = 1.0 - (i - 8) / 3.0
        rx = 11
        ry = max(0.6, 6.0 * o)
        for y in range(int(cy - 7), int(cy + 8)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                dx = (x + 0.5 - cx) / rx
                if abs(dx) > 1.0:
                    continue
                half = ry * (1.0 - dx * dx) ** 0.8
                dy = y + 0.5 - cy
                if abs(dy) <= half + 1.0:
                    plot(im, x, y, VOID[1] if abs(dy) > half else VOID[2], 1.0, True)
                if abs(dy) <= half - 0.6:
                    plot(im, x, y, (232, 220, 206), 1.0, True)
        if o > 0.5:
            disc(im, cx, cy, 3.4 * o, BLOOD[2], 1.0)
            line(im, cx, cy - 2.5 * o, cx, cy + 2.5 * o, (20, 4, 8), 1.0)
            plot(im, cx - 1, cy - 1, BLOOD[4], 1.0)
        if i in (4, 5):
            spark(im, cx + 11, cy - 6, 2, (255, 230, 230), BLOOD[3], 1.0)
        outline(im, VOID[0], 0.9)
        frames.append(im)
    save("azrail_mark", frames, fps=16.0)


ALL = [time_freeze, sun_will, death_threshold, aegis, phoenix, crimson_harvest, kings_chalice, blood_shield, light_guard,
       azrail_mark]

if __name__ == "__main__":
    for fn in ALL:
        fn()
    if "--preview" in sys.argv:
        from PIL import Image
        path = sys.argv[sys.argv.index("--preview") + 1]
        rows = []
        for fn in ALL:
            im = Image.open(os.path.join(OUT, fn.__name__ + "_sheet.png")).convert("RGBA")
            rows.append(im)
        sc = 4
        W = max(r.width for r in rows) * sc
        Ht = sum(r.height * sc + 6 for r in rows)
        out = Image.new("RGBA", (W, Ht), (46, 70, 40, 255))
        y = 0
        for r in rows:
            out.alpha_composite(r.resize((r.width * sc, r.height * sc), Image.NEAREST), (0, y))
            y += r.height * sc + 6
        out.save(path)
