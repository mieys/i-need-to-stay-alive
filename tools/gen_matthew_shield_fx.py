#!/usr/bin/env python3
"""Matthew ULTI'si (Feda Kalkani) - kalkan, kalkan kirilmasi ve kalkan patlamasi: PIXEL-ART yeniden tasarim + SPRITESHEET.

Kullanici istegi (2026-09-24): "matthew'in ultisinin kalkan ve kalkan patlama efektini pixel tarzda yeniden tasarla ...
sonrasinda spritesheete donustur ki performans kaybi olmasin."
Eskiden kalkan (tools/gen_heavy_fx_perf_sprites.py) prosedurel cizimin 1:1 pisirilmis haliydi (ince turuncu halka + noktalar)
ve patlama (fx_matthew_explosion.gd) HER KAREDE _draw() ile 35 cam kiymigi + 2 sok dalgasi ciziyordu.
Yeni tasarim (48x48 piksel dili - 1 sanat pikseli = PixelDraw.TEXEL; kalkan oyuncuya bagli oldugu icin 1.212 yerel birim,
patlama dunyada 1.212 dunya birimi):
  LOOP (16 kare, 12 fps): tilki atesi kubbesi - kenara dogru koyulasan yari saydam kehribar balon, 2 px turuncu-altin
    kenar + 1 px koyu kontur, sol ustte parlak yansima yayi, balonun icinden gecen soluk parlama bandi, cevresinde donen
    6 tilki atesi (kivilcim kuyruklu alev dili; 60 derece/dongu -> kesintisiz), tepede iki tilki kulagi.
  POP (14 kare, 24 fps): kenar beyaz parlar, carpma noktasindan catlaklar yayilir, balon ucgen kehribar cam kiymiklarina
    ayrilip disa savrulur (donerek, hafif dusus), kulaklar yukari firlayip soner, disa acilan kesikli halka.
  EXPLOSION (16 kare, 20 fps, R=182 sanat px = 220 dunya birimi - _matthew_dome_explosion yaricapi): turuncu-beyaz yildiz
    parlama, iki kesikli sok dalgasi (disa acilip incelir ve kararir), 32 donen cam kiymigi, yukselen tilki atesi korlari.
Cikti: assets/fx/matthew_fox_shield/{loop,pop,explosion}_sheet.png + *_frames.tres.
Kullanim: python tools/gen_matthew_shield_fx.py [onizleme.png]
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_enemy_ability_fx import put, rgba, with_alpha, outline_pass, ease_out  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "matthew_fox_shield")
RES = "res://assets/fx/matthew_fox_shield/"

WHITE = rgba(1.0, 0.98, 0.9)
GOLD = rgba(1.0, 0.84, 0.36)
ORANGE = rgba(1.0, 0.58, 0.16)
DEEP = rgba(0.82, 0.3, 0.06)
DARK = rgba(0.42, 0.13, 0.03)
AMBER_FILL = (1.0, 0.62, 0.2)

R = 48  # kubbe yaricapi (sanat px) - eski kalkanin ~60 yerel birimi
LOOP_W, LOOP_H = 120, 128
LCX, LCY = 60, 70


def ring(im, cx, cy, r, col, dash=0, phase=0.0, squash=1.0):
    n = max(12, int(math.tau * r * 1.2))
    for i in range(n):
        if dash and ((i + int(phase)) // dash) % 3 == 2:
            continue
        a = i / n * math.tau
        put(im, cx + math.cos(a) * r, cy + math.sin(a) * r * squash, col)


def bubble(im, cx, cy, r, fill_scale=1.0, sweep=None):
    """Yari saydam kehribar balon: merkez cok soluk, kenara dogru 3 kademe koyulasir (dither yok)."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d > r - 1:
                continue
            k = d / r
            a = 0.035 if k < 0.6 else (0.07 if k < 0.84 else 0.14)
            c = AMBER_FILL
            if sweep is not None:
                band = (x - cx) + (y - cy) * 0.6 - sweep
                if -3.0 < band < 3.0:
                    a += 0.1
                    c = (1.0, 0.85, 0.55)
            put(im, x, y, rgba(c[0], c[1], c[2], a * fill_scale))


def rim(im, cx, cy, r, flash=0.0):
    col_out = WHITE if flash > 0.5 else ORANGE
    col_in = WHITE if flash > 0.2 else GOLD
    ring(im, cx, cy, r, col_out)
    ring(im, cx, cy, r - 1, col_in)
    ring(im, cx, cy, r + 1, with_alpha(DARK, 0.85))
    # sol-ust parlak yansima yayi + nokta
    for i in range(18):
        a = math.radians(205 + i * 2.6)
        put(im, cx + math.cos(a) * (r - 5), cy + math.sin(a) * (r - 5), with_alpha(WHITE, 0.85))
    put(im, cx - r * 0.45, cy - r * 0.62, WHITE)
    put(im, cx - r * 0.45 + 1, cy - r * 0.62, with_alpha(WHITE, 0.7))


def ear(im, cx, cy, side, lift=0.0, alpha=1.0, spin=0.0):
    """Kubbenin tepesinde tilki kulagi: turuncu dis, krem ic, koyu kontur (kontur outline_pass'ten)."""
    base_x = cx + side * 22
    base_y = cy - 43 - lift
    pts_out = [(-6, 0), (6, 0), (side * 3, -12)]
    pts_in = [(-3, -1), (3, -1), (side * 2, -8)]

    def rot(px_, py_):
        ca, sa = math.cos(spin), math.sin(spin)
        return base_x + px_ * ca - py_ * sa, base_y + px_ * sa + py_ * ca

    def tri_fill(pts, col):
        (x0, y0), (x1, y1), (x2, y2) = [rot(*p) for p in pts]
        minx, maxx = int(min(x0, x1, x2)) - 1, int(max(x0, x1, x2)) + 2
        miny, maxy = int(min(y0, y1, y2)) - 1, int(max(y0, y1, y2)) + 2
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-6:
            return
        for y in range(miny, maxy):
            for x in range(minx, maxx):
                px_, py_ = x + 0.5, y + 0.5
                l1 = ((y1 - y2) * (px_ - x2) + (x2 - x1) * (py_ - y2)) / den
                l2 = ((y2 - y0) * (px_ - x2) + (x0 - x2) * (py_ - y2)) / den
                if l1 >= 0 and l2 >= 0 and l1 + l2 <= 1:
                    put(im, x, y, with_alpha(col, alpha))

    tri_fill(pts_out, ORANGE)
    tri_fill(pts_in, rgba(1.0, 0.9, 0.72))


def foxfire(im, x, y, heading, size=1.0, alpha=1.0):
    """Tilki atesi: hareket yonunun tersine uzanan kuyruklu kucuk alev (bas beyaz-altin, kuyruk turuncu-koyu)."""
    back = heading + math.pi
    for s in range(int(7 * size)):
        u = s / (7 * size)
        px_ = x + math.cos(back) * s * 1.1
        py_ = y + math.sin(back) * s * 1.1 - u * 2
        w = (2.4 * (1 - u)) * size
        col = WHITE if u < 0.15 else (GOLD if u < 0.4 else (ORANGE if u < 0.75 else DEEP))
        for oy in range(-int(w), int(w) + 1):
            if abs(oy) <= w:
                put(im, px_ - math.sin(back) * oy, py_ + math.cos(back) * oy, with_alpha(col, alpha))


def loop_frames():
    n = 16
    out = []
    for fi in range(n):
        t = fi / n
        im = Image.new("RGBA", (LOOP_W, LOOP_H), (0, 0, 0, 0))
        sweep = -60 + t * 120
        bubble(im, LCX, LCY, R, 1.0, sweep)
        rim(im, LCX, LCY, R)
        ear(im, LCX, LCY, -1)
        ear(im, LCX, LCY, 1)
        # 6 tilki atesi, 60 derece / dongu (kesintisiz)
        for k in range(6):
            a = k * math.tau / 6 + t * math.tau / 6
            fx = LCX + math.cos(a) * (R + 3)
            fy = LCY + math.sin(a) * (R + 3)
            flick = 0.85 + 0.15 * math.sin(t * math.tau * 3 + k)
            foxfire(im, fx, fy, a + math.pi / 2, 1.7 * flick)
        out.append(im)
    # kulaklarin konturu (sadece opak kisimlar - balon dolgusu dusuk alfa oldugu icin konturlanmaz)
    for im in out:
        outline_pass(im, with_alpha(DARK, 0.9))
    return out


POP_W = POP_H = 180
PCX, PCY = 90, 94


def pop_frames():
    rnd = random.Random(12)
    shards = []
    for i in range(36):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.6, 1.0) * R
        shards.append((a, rr, rnd.uniform(0.7, 1.3), rnd.uniform(-8, 8), rnd.randint(4, 7)))
    cracks = []
    for i in range(6):
        a = math.radians(-120) + i * math.tau / 6 + rnd.uniform(-0.3, 0.3)
        pts = [(PCX - 14, PCY - 16)]
        for s in range(1, 6):
            a += rnd.uniform(-0.4, 0.4)
            pts.append((pts[-1][0] + math.cos(a) * 9, pts[-1][1] + math.sin(a) * 9))
        cracks.append(pts)
    n = 14
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (POP_W, POP_H), (0, 0, 0, 0))
        if fi <= 3:
            flash = 1.0 - fi / 4.0
            bubble(im, PCX, PCY, R, 1.0 + flash * 1.5)
            rim(im, PCX, PCY, R, flash)
            ear(im, PCX, PCY, -1)
            ear(im, PCX, PCY, 1)
            if fi >= 1:
                reach = min(1.0, fi / 3.0)
                for pts in cracks:
                    m = int(len(pts) * reach)
                    for j in range(max(0, m - 1)):
                        x0, y0 = pts[j]
                        x1, y1 = pts[j + 1]
                        for s in range(10):
                            f = s / 10
                            put(im, x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, WHITE)
        else:
            u = (fi - 4) / (n - 5)
            # kiymiklar
            for a, rr, sp, spin, sz in shards:
                d = rr + (30 + 60 * sp) * ease_out(u)
                x = PCX + math.cos(a) * d
                y = PCY + math.sin(a) * d + u * u * 18
                alpha = 1.0 - max(0.0, u - 0.5) * 2.0
                ang = spin * u + a
                for k in range(sz):
                    for j in range(sz - k):
                        dx = k * math.cos(ang) - j * math.sin(ang)
                        dy = k * math.sin(ang) + j * math.cos(ang)
                        col = WHITE if (k == 0 and j == 0) else (GOLD if k + j < sz - 1 else ORANGE)
                        put(im, x + dx, y + dy, with_alpha(col, alpha))
            # kulaklar yukari firlar, doner, soner
            ear(im, PCX, PCY, -1, lift=u * 26, alpha=1.0 - u, spin=-u * 2.2)
            ear(im, PCX, PCY, 1, lift=u * 26, alpha=1.0 - u, spin=u * 2.2)
            # disa acilan kesikli halka
            outline_pass(im, with_alpha(DARK, 0.9 * (1.0 - u)))
            if u < 0.7:
                ring(im, PCX, PCY, R + 30 * ease_out(u / 0.7), with_alpha(GOLD, 1.0 - u / 0.7), dash=3)
        out.append(im)
    return out


EXP = 380
ECX = ECY = EXP // 2
ER = 182  # 220 dunya birimi / 1.212


def explosion_frames():
    rnd = random.Random(31)
    shards = [(rnd.uniform(0, math.tau), rnd.uniform(0.35, 0.95), rnd.randint(5, 9), rnd.uniform(-6, 6)) for _ in range(32)]
    embers = [(rnd.uniform(0, math.tau), rnd.uniform(0.15, 0.7), rnd.random()) for _ in range(18)]
    n = 16
    out = []
    for fi in range(n):
        t = fi / (n - 1)
        im = Image.new("RGBA", (EXP, EXP), (0, 0, 0, 0))
        # parlama
        if t < 0.2:
            k = 1.0 - t / 0.2
            core = 6 + 10 * k
            for dy in range(-int(core) - 1, int(core) + 2):
                for dx in range(-int(core) - 1, int(core) + 2):
                    s = abs(dx) + abs(dy)
                    if s <= core and dx * dx + dy * dy <= core * core:
                        put(im, ECX + dx, ECY + dy, WHITE if s < core * 0.6 else GOLD)
            for kk in range(8):
                a = kk * math.tau / 8
                ln = (40 if kk % 2 == 0 else 24) * k
                for s_ in range(int(core), int(core + ln)):
                    put(im, ECX + math.cos(a) * s_, ECY + math.sin(a) * s_, GOLD if s_ < core + ln * 0.5 else ORANGE)
        # sok dalgasi 1 (kalin -> ince, beyaz -> turuncu -> koyu, sonda kesikli)
        k1 = t / 0.55
        if k1 < 1.0:
            rr = 16 + (ER - 16) * ease_out(k1)
            col = WHITE if k1 < 0.25 else (GOLD if k1 < 0.5 else (ORANGE if k1 < 0.8 else DEEP))
            thick = 3 if k1 < 0.4 else (2 if k1 < 0.75 else 1)
            for w in range(thick):
                ring(im, ECX, ECY, rr - w, with_alpha(col, 1.0 - max(0.0, k1 - 0.7) * 2.5), dash=5 if k1 > 0.7 else 0)
        # sok dalgasi 2 (altin, gecikmeli)
        k2 = (t - 0.1) / 0.55
        if 0.0 < k2 < 1.0:
            ring(im, ECX, ECY, 10 + (ER * 0.8) * ease_out(k2), with_alpha(GOLD, 0.9 * (1.0 - k2)), dash=4, phase=fi * 2)
        # cam kiymiklari
        for a, sp, sz, spin in shards:
            u = min(1.0, t / 0.8)
            d = 14 + ER * sp * ease_out(u)
            x = ECX + math.cos(a) * d
            y = ECY + math.sin(a) * d + u * u * 14
            alpha = 1.0 - max(0.0, u - 0.55) / 0.45
            ang = a + spin * u
            for k in range(sz):
                for j in range(sz - k):
                    dx = k * math.cos(ang) - j * math.sin(ang)
                    dy = k * math.sin(ang) + j * math.cos(ang)
                    col = WHITE if (k + j == 0) else (GOLD if k + j < sz - 2 else ORANGE)
                    put(im, x + dx, y + dy, with_alpha(col, alpha))
        # yukselen tilki atesi korlari
        for a, sp, ph in embers:
            u = (t * 1.3 + ph * 0.3)
            if u > 1.0:
                continue
            d = ER * sp * ease_out(min(1.0, t / 0.4))
            x = ECX + math.cos(a) * d
            y = ECY + math.sin(a) * d - u * 30
            foxfire(im, x, y, -math.pi / 2, 1.6, 1.0 - u)
        out.append(im)
    return out


def save(frames, name, anim, fps, loop):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0), f)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, name + "_sheet.png"))
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])
    print("wrote", name, sheet.size)


def main():
    lf, pf, ef = loop_frames(), pop_frames(), explosion_frames()
    save(lf, "loop", "loop", 12.0, True)
    save(pf, "pop", "pop", 24.0, False)
    save(ef, "explosion", "play", 20.0, False)
    if len(sys.argv) > 1:
        S = 2
        rows = [lf[::4], pf[::3], ef[::3]]
        width = max(sum(f.size[0] * S + 6 for f in r) for r in rows) + 10
        height = sum(max(f.size[1] for f in r) * S + 10 for r in rows) + 10
        prev = Image.new("RGBA", (width, height), (58, 72, 52, 255))
        y = 5
        for r in rows:
            x = 5
            for f in r:
                prev.alpha_composite(f.resize((f.size[0] * S, f.size[1] * S), Image.NEAREST), (x, y))
                x += f.size[0] * S + 6
            y += max(f.size[1] for f in r) * S + 10
        prev.save(sys.argv[1])
        print("preview ->", sys.argv[1])


if __name__ == "__main__":
    main()
