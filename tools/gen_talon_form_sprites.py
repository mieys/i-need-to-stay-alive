#!/usr/bin/env python3
"""Talon'un Ayna Formu (R) aurasi (scripts/fx_talon_form.gd) icin spritesheet'ler.

Kullanici bildirimi (2026-09-24): "talon oyunu cok kastiriyor yetenek kullandiginda acaba ultisini spritesheet yapmadik
mi" - OLCUM (gercek render, 60 yaratik + 5 silah, scratchpad talon_perf.gd): taban ~7 ms/kare; R acikken 15.4 ms (65 fps),
ayni R FX'i gizlenince 8.4 ms (119 fps) -> FX'in kendisi tek basina ~7 ms. Eski fx_talon_form.gd her karede pixel_draw.gd
ile iki dither disk + 2 katmanli 37 sutunluk alev izgarasi + kor + parilti + zikzak ciziyordu (binlerce draw_rect, 15 sn
boyunca). Bu arac AYNI matematigi (fx_talon_form.gd _draw/_draw_front) SANAT PIKSELI cozunurlugunde bir kez PNG'ye pisirir:

  arka katman (karakterin ARKASI): isik sutunu (giris), dither isima, alev sutunlari, yukselen kor
  on katman (karakterin ONU): sok halkalari + isinlar + beyaz parlama (giris), govde "+" parintilari, zikzak simsekler,
                              govde cevresinde donen 4 parlak piksel

Her katman: "intro" (INTRO_TIME = 0.7 sn, tek seferlik) + "loop" (2*pi sn SEAMLESS dongu: alev frekanslari 8/9/15 rad/s
tam sayi oldugu icin 2*pi'de birebir basa doner; kor/parintilar dongu periyoduna bolunmus deterministik dogus
zamanlariyla uretilir, donen 4 piksel 2.2 -> 2.0 rad/s'ye yuvarlandi ki dongu kusursuz olsun). Silahlarin uzerindeki
parintilar silah KONUMUNA bagli oldugu icin fx_talon_form.gd'de prosedurel kaldi (birkac piksel, ucuz).

Olcek: 1 raster pikseli = 1 sanat pikseli (PixelDraw.TEXEL dunya birimi) - oyun ici AnimatedSprite2D.scale = TEXEL,
offset = (-0.5, oy_kaymasi - 0.5) (bkz. fx_talon_form.gd). Koordinatlar FX node'unun yerel uzayinda (dunya birimi / TEXEL).

Kullanim (repo kokunden):  python tools/gen_talon_form_sprites.py
Cikti: assets/fx/talon_form/{back_intro,back_loop,front_intro,front_loop}.png + back_frames.tres + front_frames.tres
Yeni PNG'ler icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_draw_py import blend_px, col  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fx", "talon_form")
RES_DIR = "res://assets/fx/talon_form"

TEXEL = 1.212
INTRO_TIME = 0.7
FLAME_COLUMNS = 13
BODY_CENTER = (0.0, -4.0)

LOOP_PERIOD = 2.0 * math.pi
LOOP_FRAMES = 75  ## ~12 fps
INTRO_FRAMES = 14  ## 20 fps
INTRO_FPS = INTRO_FRAMES / INTRO_TIME
LOOP_FPS = LOOP_FRAMES / LOOP_PERIOD

EMBER_SPAWN_N = 210  ## dongu basina kor sayisi (~0.03 sn aralik, eski _spawn_acc > 0.03 ile ayni yogunluk)
EMBER_LIFE = 0.75
SPARK_N = 88  ## dongu basina govde parintisi (~14/sn, eski randf() < delta * 14 ile ayni yogunluk)
ORBIT_SPEED = 2.0

## Tuval (sanat pikseli). Arka: x +-56, y -94..+42 (giris sutunu 130 birim yukari cikiyor). On giris: sok halkasi
## 104 birim yaricap -> +-92; on dongu: +-56. Her ikisinde origin (0,0) = (ox, oy).
BACK_W, BACK_H, BACK_OX, BACK_OY = 112, 136, 56, 94
FRONT_INTRO_W = 184
FRONT_LOOP_W = 112


def fire_color(t, a=1.0):
    stops = [(1.0, 0.96, 0.7), (1.0, 0.78, 0.22), (1.0, 0.5, 0.1), (0.9, 0.2, 0.06), (0.45, 0.08, 0.06)]
    t = max(0.0, min(1.0, t)) * (len(stops) - 1)
    i = min(int(t), len(stops) - 2)
    f = t - i
    x, y = stops[i], stops[i + 1]
    return col(x[0] + (y[0] - x[0]) * f, x[1] + (y[1] - x[1]) * f, x[2] + (y[2] - x[2]) * f, a)


def hash01(seed):
    x = (seed * 374761393 + 668265263) & 0xFFFFFFFFFFFFFFFF
    x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFFFFFFFFFF
    x = x ^ (x >> 16)
    return (x & 0xFFFF) / 65535.0


class Canvas:
    def __init__(self, w, h, ox, oy):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.ox, self.oy = ox, oy

    def cell(self, kx, ky, rgba):
        blend_px(self.im, (kx + self.ox, ky + self.oy), rgba)

    def px(self, pos, n, rgba):
        """pixel_draw.gd px(): snap(pos) merkezli n x n sanat pikseli (pos DUNYA birimi)."""
        cx = int(round(pos[0] / TEXEL))
        cy = int(round(pos[1] / TEXEL))
        s = cx - n // 2
        t = cy - n // 2
        for iy in range(n):
            for ix in range(n):
                self.cell(s + ix, t + iy, rgba)

    def line(self, a, b, rgba, n=1):
        step = TEXEL * max(n, 1)
        dist = math.hypot(b[0] - a[0], b[1] - a[1])
        steps = max(1, int(dist / step))
        for i in range(steps + 1):
            f = i / steps
            self.px((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f), n, rgba)

    def ring(self, center, radius, rgba, n=1, dash_on=0, dash_off=0, phase=0.0):
        step = TEXEL * max(n, 1)
        count = max(8, int(2.0 * math.pi * radius / step))
        period = dash_on + dash_off
        for i in range(count):
            if period > 0 and (int(i + phase) % period) >= dash_on:
                continue
            a = 2.0 * math.pi * i / count
            self.px((center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius), n, rgba)

    def disc_dither(self, center, radius, rgba, parity=0, cell=1):
        cx = int(round(center[0] / TEXEL))
        cy = int(round(center[1] / TEXEL))
        cs = max(cell, 1)
        rc = int(radius / (TEXEL * cs))
        for iy in range(-rc, rc + 1):
            hw = int(math.sqrt(max(0.0, rc * rc - iy * iy)))
            for ix in range(-hw, hw + 1):
                if ((ix + iy + parity) & 1) == 0:
                    continue
                x0 = cx + ix * cs - cs // 2
                y0 = cy + iy * cs - cs // 2
                for yy in range(cs):
                    for xx in range(cs):
                        self.cell(x0 + xx, y0 + yy, rgba)


def open_factor(t):
    return max(0.0, min(1.0, t / 0.25))


# ------------------------------------------------------------------------------------------------ kor / parinti
def embers_at(t, looped):
    """(pos, age, size) listesi. looped=False: giris (t=0'dan beri dogmuslar), True: dongu (periyoda sarilir)."""
    out = []
    dt = LOOP_PERIOD / EMBER_SPAWN_N
    for k in range(EMBER_SPAWN_N):
        for m in ((0, 1) if looped else (0,)):
            s = k * dt - m * LOOP_PERIOD
            age = t - s
            if age < 0.0 or age >= EMBER_LIFE:
                continue
            if not looped and s < 0.0:
                continue
            ex = -24.0 + 48.0 * hash01(k * 7 + 1)
            y0 = 6.0 + 22.0 * hash01(k * 7 + 2)
            vx = -14.0 + 28.0 * hash01(k * 7 + 3)
            vy = -120.0 + 60.0 * hash01(k * 7 + 4)
            size = 1 if hash01(k * 7 + 5) < 0.5 else 2
            pos = (BODY_CENTER[0] + ex + vx * age, BODY_CENTER[1] + y0 + vy * age)
            out.append((pos, age, size))
    return out


def sparks_at(t, looped):
    out = []
    dt = LOOP_PERIOD / SPARK_N
    for k in range(SPARK_N):
        for m in ((0, 1) if looped else (0,)):
            s = k * dt - m * LOOP_PERIOD
            if not looped and s < 0.0:
                continue
            life = 0.25 + 0.15 * hash01(k * 11 + 1)
            age = t - s
            if age < 0.0 or age >= life:
                continue
            pos = (BODY_CENTER[0] - 18.0 + 36.0 * hash01(k * 11 + 2), BODY_CENTER[1] - 26.0 + 48.0 * hash01(k * 11 + 3))
            out.append((pos, age / life))
    return out


# ------------------------------------------------------------------------------------------------ arka katman
def render_back(t, intro):
    cv = Canvas(BACK_W, BACK_H, BACK_OX, BACK_OY)
    op = open_factor(t) if intro else 1.0
    if intro and t < INTRO_TIME:
        pk = t / INTRO_TIME
        col_h = 130.0 * min(1.0, pk * 3.0)
        half_w = int(6.0 * (1.0 - pk) + 2.0)
        for iy in range(0, int(col_h / TEXEL)):
            y = 26.0 - iy * TEXEL
            for ix in range(-half_w, half_w + 1):
                if ((ix + iy + int(t * 30.0)) & 1) == 0:
                    cv.px((ix * TEXEL, y + BODY_CENTER[1]), 1, col(1.0, 0.92, 0.55, 1.0 - pk))
    flick = int(t * 12.0)
    cv.disc_dither(BODY_CENTER, 50.0 * op, col(1.0, 0.42, 0.06, 0.55), flick, 2)
    cv.disc_dither(BODY_CENTER, 32.0 * op, col(1.0, 0.8, 0.25, 0.6), flick + 1, 2)
    for layer in range(2):
        cols = FLAME_COLUMNS * 2 - 1 if layer == 0 else FLAME_COLUMNS
        for i in range(cols):
            u = (i / (cols - 1)) * 2.0 - 1.0
            x0 = u * 40.0
            centre_boost = 1.0 - abs(u) ** 1.6
            shrink = 1.0 if layer == 0 else 0.62
            h = (26.0 + 46.0 * centre_boost + 10.0 * math.sin(t * 9.0 + i * 1.7) + 7.0 * math.sin(t * 15.0 + i * 0.9)) * op * shrink
            rows = int(h / TEXEL)
            for r in range(rows):
                k = r / max(rows, 1)
                width = max(1, int(round(4.0 * (1.0 - k) + 0.5)))
                sway = math.sin(t * 8.0 + i + r * 0.22) * k * TEXEL * 3.0
                pos = (x0 + sway - u * k * 12.0, 26.0 - r * TEXEL)
                heat = k * 0.85 if layer == 0 else 0.02 + k * 0.5
                cv.px(pos, width if layer == 0 else max(1, width - 1), fire_color(heat))
    for pos, age, size in embers_at(t, not intro):
        k2 = age / EMBER_LIFE
        cv.px(pos, size if k2 < 0.6 else 1, fire_color(0.05 + k2 * 0.85))
    return cv.im


# ------------------------------------------------------------------------------------------------ on katman
def render_front(t, intro, size):
    half = size // 2
    cv = Canvas(size, size, half, half)
    op = open_factor(t) if intro else 1.0
    if intro and t < INTRO_TIME:
        pk = t / INTRO_TIME
        cv.ring(BODY_CENTER, 8.0 + pk * 96.0, fire_color(pk), 2)
        cv.ring(BODY_CENTER, 4.0 + pk * 70.0, fire_color(pk * 0.6), 1, 3, 3, t * 20.0)
        for k in range(12):
            a = k * 2.0 * math.pi / 12.0 + 0.2
            r0 = 20.0 + pk * 40.0
            r1 = r0 + 26.0 * (1.0 - pk)
            p0 = (BODY_CENTER[0] + math.cos(a) * r0, BODY_CENTER[1] + math.sin(a) * r0)
            p1 = (BODY_CENTER[0] + math.cos(a) * r1, BODY_CENTER[1] + math.sin(a) * r1)
            cv.line(p0, p1, fire_color(0.15 + pk * 0.5), 1)
        if t < 0.12:
            cv.disc_dither(BODY_CENTER, 46.0, col(1.0, 0.97, 0.8, 0.85), int(t * 60.0), 2)
    for pos, k in sparks_at(t, not intro):
        big = 0.25 < k < 0.75
        c = col(1.0, 0.97, 0.75)
        cv.px(pos, 1, c)
        if big:
            for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                cv.px((pos[0] + dx * TEXEL, pos[1] + dy * TEXEL), 1, c)
    if op > 0.5 and (t > 0.3 or not intro):
        seed_i = int(t * 11.0)
        for z in range(2):
            side = -1.0 if z == 0 else 1.0
            base = (BODY_CENTER[0] + side * (16.0 + hash01(seed_i * 3 + z) * 8.0), BODY_CENTER[1] + hash01(seed_i * 5 + z + 9) * 40.0 - 22.0)
            prev = base
            for step in range(4):
                nxt = (prev[0] + (hash01(seed_i * 7 + z * 13 + step) - 0.5) * 12.0 * side + side * 3.0,
                       prev[1] - 7.0 - hash01(seed_i + step * 5 + z) * 5.0)
                cv.line(prev, nxt, col(1.0, 0.96, 0.55), 1)
                prev = nxt
    if op > 0.5:
        for k in range(4):
            a2 = t * ORBIT_SPEED + k * 2.0 * math.pi / 4.0
            cv.px((BODY_CENTER[0] + math.cos(a2) * 20.0, BODY_CENTER[1] + math.sin(a2) * 30.0), 1, col(1.0, 0.85, 0.4))
    return cv.im


# ------------------------------------------------------------------------------------------------ cikti
def save_sheet(frames, name):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    path = os.path.join(OUT_DIR, name)
    sheet.save(path)
    print("wrote", path, sheet.size)
    return w, h


def write_frames_tres(path, anims):
    """anims: [(name, png_res_path, cell_w, cell_h, count, loop, speed)] - her animasyon kendi sayfasindan."""
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for i, a in enumerate(anims):
        lines.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % (a[1], i + 1))
    lines.append("")
    at = 0
    blocks = []
    for i, (name, _png, cw, ch, count, loop, speed) in enumerate(anims):
        ids = []
        for f in range(count):
            lines.append('[sub_resource type="AtlasTexture" id="AT_%d"]' % at)
            lines.append('atlas = ExtResource("%d")' % (i + 1))
            lines.append("region = Rect2(%d, 0, %d, %d)" % (f * cw, cw, ch))
            lines.append("")
            ids.append(at)
            at += 1
        entries = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % x for x in ids)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            entries, "true" if loop else "false", name, speed))
    lines.append("[resource]")
    lines.append("animations = [%s]" % ", ".join(blocks))
    lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote", path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    back_intro = [render_back(i / INTRO_FPS, True) for i in range(INTRO_FRAMES)]
    back_loop = [render_back(i / LOOP_FPS, False) for i in range(LOOP_FRAMES)]
    front_intro = [render_front(i / INTRO_FPS, True, FRONT_INTRO_W) for i in range(INTRO_FRAMES)]
    front_loop = [render_front(i / LOOP_FPS, False, FRONT_LOOP_W) for i in range(LOOP_FRAMES)]
    save_sheet(back_intro, "back_intro.png")
    save_sheet(back_loop, "back_loop.png")
    save_sheet(front_intro, "front_intro.png")
    save_sheet(front_loop, "front_loop.png")
    write_frames_tres(os.path.join(OUT_DIR, "back_frames.tres"), [
        ("intro", RES_DIR + "/back_intro.png", BACK_W, BACK_H, INTRO_FRAMES, False, round(INTRO_FPS, 4)),
        ("loop", RES_DIR + "/back_loop.png", BACK_W, BACK_H, LOOP_FRAMES, True, round(LOOP_FPS, 4)),
    ])
    write_frames_tres(os.path.join(OUT_DIR, "front_frames.tres"), [
        ("intro", RES_DIR + "/front_intro.png", FRONT_INTRO_W, FRONT_INTRO_W, INTRO_FRAMES, False, round(INTRO_FPS, 4)),
        ("loop", RES_DIR + "/front_loop.png", FRONT_LOOP_W, FRONT_LOOP_W, LOOP_FRAMES, True, round(LOOP_FPS, 4)),
    ])
    preview = os.environ.get("TALON_PREVIEW_DIR")
    if preview:
        picks = [back_intro[3], back_intro[10], back_loop[0], back_loop[30]]
        fpicks = [front_intro[3], front_intro[10], front_loop[0], front_loop[30]]
        cell = 184
        out = Image.new("RGBA", (cell * 4, cell * 2), (60, 90, 50, 255))
        for i, im in enumerate(picks):
            out.alpha_composite(im, (i * cell + (cell - BACK_W) // 2, (cell - BACK_H) // 2))
        for i, im in enumerate(fpicks):
            out.alpha_composite(im, (i * cell + (cell - im.size[0]) // 2, cell + (cell - im.size[1]) // 2))
        out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
        out.save(os.path.join(preview, "talon_form_preview.png"))


if __name__ == "__main__":
    main()
