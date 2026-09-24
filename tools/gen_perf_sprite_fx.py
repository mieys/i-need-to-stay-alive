#!/usr/bin/env python3
"""Kullanici isteği (2026-09-23): kalkan/bariyer catlama efekti + Oakley ari surusu halkasi +
Oakley sarmasik uzantisi PROSEDUREL (her karede yuzlerce/binlerce draw_rect()) cizildigi icin
coklu ornek ayni anda canli oldugunda FPS cokertiyordu (bkz. fx_paladin_barrier.gd/fx_shield_hit.gd
uzerindeki notlar). "En ucuz olani yap" - bu script GORUNUMU AYNI tutarak bu efektleri PNG'ye
"pisirir" (bake), oyun ici script'ler artik draw_rect yerine AnimatedSprite2D/Sprite2D/Line2D
(tek doku cizimi) kullanir.

Uretilen dosyalar (repo kokunden calistir: python tools/gen_perf_sprite_fx.py):
  assets/fx/shield_hit/hit_sheet.png        3 varyant x 24 kare (referans yaricap 40 world birimi)
  assets/fx/oakley_bee_ring/fill.png        statik dither dolgu (yaricap 130 texel, hic donmuyor)
  assets/fx/oakley_bee_ring/ring_outer.png  statik kesikli halka (script'te dondurulur)
  assets/fx/oakley_bee_ring/ring_inner.png  statik kesikli halka (script'te ters yonde dondurulur)
  assets/fx/oakley_bee_ring/bee_flap.png    2 kareli (kanat yukari/asagi) minik ari
  assets/fx/oakley_vine/soil_ring.png       statik toprak halkasi (yon BAGIMSIZ)
  assets/fx/oakley_vine/bud.png             tomurcuk+yapraklar (yone gore script'te dondurulur)
  assets/fx/oakley_vine/tendril_tile.png    uzanti icin tekrarlanan (Line2D TILE) doku

Tum PNG'ler "1 raster piksel = 1 WORLD birimi" olarak uretildi (pixel_draw.gd'de radius/pos
gibi buyuklukler zaten dogrudan world biriminde - TEXEL sadece TEK BIR "sanat pikseli"nin
boyutunu belirliyor, konumlari OLCEKLEMIYOR) - oyun ici node'lar bu yuzden PixelDraw.TEXEL ile
AYRICA olceklenMEZ (yanlislikla ~%21 buyutur), sadece gerekirse bir yaricap orani uygulanir
(bkz. fx_shield_hit.gd REFERENCE_RADIUS notu). Sarmasik tendril_tile.png de ayni kuralla
(Line2D dogrudan WORLD birimde calisir) 1 raster px = 1 WORLD birimi.

Yeni PNG'ler icin Godot'ta bir kez `--headless --import` gerekir (bkz. hafiza "Godot CLI testing").
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_draw_py import blend_px, clamp, col, disc_dither, line, new_canvas, px, ring  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# =====================================================================================
# 1) KALKAN CATLAMA EFEKTI (fx_shield_hit.gd) - referans yaricap 40 texel, carpma acisi 0
#    (script'te node.rotation = impact_angle ile istenen yone dondurulur, node.scale ile
#    baska yaricaplara (ör. Sovalye bariyeri) olceklenir).
# =====================================================================================
SH_RADIUS = 40.0
SH_LIFE = 0.55
SH_BUBBLE_LIFE = 0.36
SH_CRACK_GROW = 0.13
SH_CRACK_HOLD = 0.30
## Kare sayısı runtime maliyetini ETKİLEMEZ (yine tek bir doku çizimi) - sadece PNG boyutunu
## büyütür, o yüzden orijinal ~60fps'lik prosedürel akıcılığa yakın durmak için yüksek tutuldu.
SH_FRAMES = 24
SH_VARIANTS = 3


def sh_build_cracks(rng, radius):
    cracks = []
    origin = (radius, 0.0)
    inward = math.pi
    offsets = [-0.42, 0.02, 0.4]
    lengths = [0.62, 0.95, 0.58]
    for m in range(3):
        path = [origin]
        dir_a = inward + offsets[m] + rng.uniform(-0.12, 0.12)
        max_len = radius * lengths[m]
        travelled = 0.0
        pos = origin
        step_i = 0
        while travelled < max_len:
            dir_a += rng.uniform(-0.42, 0.42)
            step = rng.uniform(2.6, 4.4)
            pos = (pos[0] + math.cos(dir_a) * step, pos[1] + math.sin(dir_a) * step)
            travelled += step
            if math.hypot(*pos) > radius - 1.0:
                break
            path.append(pos)
            step_i += 1
            if step_i >= 2 and rng.random() < 0.42:
                branch = [pos]
                b_a = dir_a + (0.7 if rng.random() < 0.5 else -0.7) + rng.uniform(-0.25, 0.25)
                bp = pos
                for _k in range(rng.randint(2, 4)):
                    b_a += rng.uniform(-0.4, 0.4)
                    bp = (bp[0] + math.cos(b_a) * rng.uniform(2.2, 3.6), bp[1] + math.sin(b_a) * rng.uniform(2.2, 3.6))
                    if math.hypot(*bp) > radius - 1.0:
                        break
                    branch.append(bp)
                if len(branch) > 1:
                    cracks.append(branch)
        cracks.append(path)
    tangent_a = math.pi * 0.5
    for sgn in (-1.0, 1.0):
        path2 = [origin]
        p2 = origin
        a2 = tangent_a if sgn > 0 else tangent_a + math.pi
        for _k in range(rng.randint(3, 5)):
            a2 += rng.uniform(-0.3, 0.3) + (0.06 if sgn > 0 else -0.06)
            p2 = (p2[0] + math.cos(a2) * rng.uniform(2.4, 3.8), p2[1] + math.sin(a2) * rng.uniform(2.4, 3.8))
            length = math.hypot(*p2)
            cap = min(length, radius - 1.5)
            if length > 0.0001:
                p2 = (p2[0] / length * cap, p2[1] / length * cap)
            path2.append(p2)
        cracks.append(path2)
    return cracks


def sh_render_frame(radius, cx, cy, cracks, shards, t, size):
    im = new_canvas(size, size)
    origin = (radius, 0.0)
    bub = clamp(1.0 - t / SH_BUBBLE_LIFE, 0.0, 1.0)
    if bub > 0.0:
        pop = 1.0 + 0.045 * math.sin(min(t / 0.08, 1.0) * math.pi)
        rr = radius * pop
        parity = int(t * 30.0)
        disc_dither(im, (cx, cy), rr - 1.0, col(0.42, 0.72, 1.0, 0.26 * bub), parity, 2)
        ring(im, (cx, cy), rr, col(0.62, 0.86, 1.0, 0.78 * bub), 1)
        ring(im, (cx, cy), rr - 2.0, col(0.4, 0.68, 1.0, 0.32 * bub), 1, 2, 3, t * 25.0)
        arc_half = math.radians(38.0)
        ring(im, (cx, cy), rr + 1.0, col(0.86, 0.96, 1.0, 0.85 * bub), 1, 0, 0, 0.0, -arc_half, arc_half * 2.0)
        ring(im, (cx, cy), rr - 1.0, col(0.86, 0.96, 1.0, 0.6 * bub), 1, 0, 0, 0.0, -arc_half * 0.7, arc_half * 1.4)
    for ring_i in range(3):
        delay = 0.03 * ring_i
        denom = 0.34 - delay
        lk = 0.0 if denom <= 0.0 else clamp((t - delay) / denom, 0.0, 1.0)
        if lk <= 0.0 or lk >= 1.0:
            continue
        rad = 3.0 + 22.0 * lk
        n = max(12, int(2 * math.pi * rad))
        wcol = col(0.7, 0.9, 1.0, 0.6 * (1.0 - lk))
        for i in range(n):
            a = 2 * math.pi * i / n
            p = (origin[0] + math.cos(a) * rad, origin[1] + math.sin(a) * rad)
            if math.hypot(*p) <= radius - 1.0:
                blend_px(im, (cx + p[0], cy + p[1]), wcol)
    grow = clamp(t / SH_CRACK_GROW, 0.0, 1.0)
    fade = 1.0 - clamp((t - SH_CRACK_HOLD) / (SH_LIFE - SH_CRACK_HOLD), 0.0, 1.0)
    if fade > 0.0:
        for path in cracks:
            n_pts = len(path)
            visible = min(n_pts, max(2, int(math.ceil(n_pts * grow))))
            for i in range(visible - 1):
                a2, b2 = path[i], path[i + 1]
                depth = i / max(n_pts - 1, 1)
                ca = fade * (1.0 - depth * 0.55)
                line(im, (cx + a2[0] + 1, cy + a2[1] + 1), (cx + b2[0] + 1, cy + b2[1] + 1), col(0.18, 0.36, 0.78, 0.55 * ca), 1)
                line(im, (cx + a2[0], cy + a2[1]), (cx + b2[0], cy + b2[1]), col(0.9, 0.97, 1.0, 0.92 * ca), 1)
    if t < 0.1:
        fk = 1.0 - t / 0.1
        px(im, (cx + origin[0], cy + origin[1]), 3, col(1, 1, 1, 0.9 * fk))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            blend_px(im, (cx + origin[0] + dx * 3, cy + origin[1] + dy * 3), col(0.85, 0.96, 1.0, 0.8 * fk))
            blend_px(im, (cx + origin[0] + dx * 5, cy + origin[1] + dy * 5), col(0.6, 0.85, 1.0, 0.5 * fk))
    k = t / SH_LIFE
    for (sx, sy, vx, vy) in shards:
        decay = (1.0 - math.exp(-4.0 * t)) / 4.0
        blend_px(im, (cx + sx + vx * decay, cy + sy + vy * decay), col(0.85, 0.96, 1.0, 0.8 * (1.0 - k)))
    return im


def gen_shield_hit():
    from PIL import Image

    size = int(2 * (SH_RADIUS + 8))
    cx = cy = size / 2.0
    sheet = Image.new("RGBA", (size * SH_FRAMES, size * SH_VARIANTS), (0, 0, 0, 0))
    for v in range(SH_VARIANTS):
        rng = random.Random(1000 + v * 37)
        cracks = sh_build_cracks(rng, SH_RADIUS)
        origin = (SH_RADIUS, 0.0)
        shards = []
        for _i in range(5):
            a = math.pi + rng.uniform(-0.9, 0.9)
            speed = rng.uniform(14.0, 42.0)
            shards.append((origin[0], origin[1], math.cos(a) * speed, math.sin(a) * speed))
        for f in range(SH_FRAMES):
            t = SH_LIFE * f / (SH_FRAMES - 1)
            frame = sh_render_frame(SH_RADIUS, cx, cy, cracks, shards, t, size)
            sheet.paste(frame, (f * size, v * size), frame)
    out_dir = os.path.join(ROOT, "assets", "fx", "shield_hit")
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "hit_sheet.png"))
    print("shield_hit: %dx%d cell, %d variants x %d frames -> %s" % (size, size, SH_VARIANTS, SH_FRAMES, out_dir))
    return size


# =====================================================================================
# 2) OAKLEY ARI SURUSU HALKASI (oakley_bee_swarm_ring.gd) - RADIUS hep 130.0 (tek cagri
#    yeri, hic degismiyor) - donen halkalar script'te rotation ile, dither dolgu statik.
# =====================================================================================
BEE_RADIUS = 130.0


def gen_bee_ring():
    pad = 10
    size = int(2 * (BEE_RADIUS + pad))
    c = size / 2.0
    out_dir = os.path.join(ROOT, "assets", "fx", "oakley_bee_ring")
    os.makedirs(out_dir, exist_ok=True)

    fill = new_canvas(size, size)
    disc_dither(fill, (c, c), BEE_RADIUS, col(1.0, 0.8, 0.25, 0.07), 0, 3)
    fill.save(os.path.join(out_dir, "fill.png"))

    outer = new_canvas(size, size)
    ring(outer, (c, c), BEE_RADIUS, col(1.0, 0.78, 0.2, 0.75), 1, 5, 2, 0.0)
    outer.save(os.path.join(out_dir, "ring_outer.png"))

    inner = new_canvas(size, size)
    ring(inner, (c, c), BEE_RADIUS - 4.0, col(1.0, 0.86, 0.35, 0.3), 1, 2, 5, 0.0)
    inner.save(os.path.join(out_dir, "ring_inner.png"))

    # --- Ari: 2 kare (kanat yukari/asagi), sadece SAGA bakan referans (script flip_h ile sola cevirir) ---
    bw, bh = 12, 12
    anchor = (2.0, 7.0)  # 'pos' (govdenin arka ucu) bu noktada
    C_YELLOW, C_YELLOW_D, C_BLACK, C_WING = col(1.0, 0.84, 0.16), col(0.9, 0.6, 0.08), col(0.1, 0.07, 0.03), col(0.85, 0.95, 1.0, 0.8)
    from PIL import Image
    bee_sheet = Image.new("RGBA", (bw * 2, bh), (0, 0, 0, 0))
    for frame_i, wing_up in enumerate((True, False)):
        im = new_canvas(bw, bh)
        ax, ay = anchor
        px(im, (ax, ay), 2, C_YELLOW)
        px(im, (ax + 1.5, ay), 1, C_BLACK)
        px(im, (ax + 2.5, ay), 2, C_YELLOW_D)
        px(im, (ax + 3.5, ay), 1, C_BLACK)
        px(im, (ax + 4.5, ay), 1, C_BLACK)
        wy = ay - (1.5 if wing_up else 2.5)
        px(im, (ax + 0.5, wy), 1, C_WING)
        px(im, (ax + 1.5, wy - (1.0 if wing_up else 0.0)), 1, C_WING)
        px(im, (ax + 2.5, wy), 1, C_WING)
        bee_sheet.paste(im, (frame_i * bw, 0), im)
    bee_sheet.save(os.path.join(out_dir, "bee_flap.png"))
    print("bee_ring: ring/fill %dx%d, bee_flap %dx%d (2 frame) -> %s" % (size, size, bw, bh, out_dir))
    return size, bw, bh


# =====================================================================================
# 3) OAKLEY SARMASIK: baş (toprak halkasi + tomurcuk/yaprak) + uzanti icin tile doku
#    (oakley_vine_visual.gd) - govde (iz) KULLANICI KARARIYLA prosedurel birakildi.
# =====================================================================================
def gen_vine_head():
    out_dir = os.path.join(ROOT, "assets", "fx", "oakley_vine")
    os.makedirs(out_dir, exist_ok=True)
    C_OUT, C_MID, C_LIGHT = col(0.07, 0.17, 0.06), col(0.27, 0.55, 0.18), col(0.52, 0.82, 0.3)
    C_THORN_TIP, C_SOIL, C_SOIL_L = col(1.0, 0.95, 0.75), col(0.2, 0.13, 0.08), col(0.38, 0.26, 0.15)

    # --- Toprak halkasi: yon BAGIMSIZ, statik (script hic dondurmuyor) ---
    size = 22
    c = size / 2.0
    soil = new_canvas(size, size)
    rng = random.Random(7)
    for k in range(9):
        a = k * (2 * math.pi / 9.0) + 0.4
        r = 2.6 + rng.random() * 2.2
        p = (c + math.cos(a) * r, c + math.sin(a) * r * 0.55 + 1.6)
        px(soil, p, 1, C_SOIL_L if k % 2 == 0 else C_SOIL)
    soil.save(os.path.join(out_dir, "soil_ring.png"))

    # --- Tomurcuk + yapraklar: SAGA (dir=RIGHT) bakan referans, script head_dir'e gore dondurur ---
    bsize = 14
    bc = bsize / 2.0
    bud = new_canvas(bsize, bsize)
    px(bud, (bc, bc), 3, C_OUT)
    px(bud, (bc, bc), 2, C_MID)
    px(bud, (bc - 0.5, bc - 0.5), 1, C_LIGHT)
    dir_v = (1.0, 0.0)
    nrm = (-dir_v[1], dir_v[0])
    for side in (-1.0, 1.0):
        leaf_base = (bc + nrm[0] * side * 2.4 - dir_v[0] * 1.5, bc + nrm[1] * side * 2.4 - dir_v[1] * 1.5)
        px(bud, leaf_base, 1, C_MID)
        px(bud, (leaf_base[0] + nrm[0] * side, leaf_base[1] + nrm[1] * side), 1, C_LIGHT)
        px(bud, (leaf_base[0] + nrm[0] * side * 2.0 + dir_v[0] * 1.2, leaf_base[1] + nrm[1] * side * 2.0 + dir_v[1] * 1.2), 1, C_THORN_TIP)
    bud.save(os.path.join(out_dir, "bud.png"))

    # --- Uzanti tile dokusu: Line2D TILE modu icin, WORLD birimde (1 raster px = 1 world birimi,
    #     TEXEL olcekleme YOK - Line2D dogrudan _tendril()'in world-birim noktalarini kullanir).
    #     18 birim uzunlugunda (2 x diken araligi=9) yatay bir serit - saga (+X) tekrarlanir.
    C_THORN = col(0.88, 0.8, 0.54)
    tile_w, tile_h = 18, 10
    tile_c_y = tile_h / 2.0
    tendril = new_canvas(tile_w, tile_h)
    for i in range(tile_w):
        u = i / float(tile_w - 1)
        p = (i, tile_c_y)
        px(tendril, (p[0], p[1] + 0.6), 2, C_OUT)
        px(tendril, p, 2, col(0.15, 0.34, 0.11))
        px(tendril, p, 1, C_MID)
        if i % 4 == 0:
            px(tendril, (p[0] - 0.5, p[1] - 0.5), 1, C_LIGHT)
        if i % 9 == 4:
            side = 1.0 if (i // 9) % 2 == 0 else -1.0
            base = (p[0], p[1] + side * 1.5)
            px(tendril, base, 1, C_THORN)
            px(tendril, (base[0] + 0.8, base[1] + side * 1.2), 1, C_THORN_TIP)
        _ = u
    tendril.save(os.path.join(out_dir, "tendril_tile.png"))
    print("vine: soil_ring %dx%d, bud %dx%d, tendril_tile %dx%d -> %s" % (size, size, bsize, bsize, tile_w, tile_h, out_dir))


if __name__ == "__main__":
    from PIL import Image  # noqa: E402  (yukarida bazi yerlerde lazy import edildi)

    gen_shield_hit()
    gen_bee_ring()
    gen_vine_head()
    print("ok")
