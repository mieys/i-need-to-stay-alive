#!/usr/bin/env python3
"""Ruhani Yetenekler (scripts/spiritual_skills.gd) icin ikon + ses assetlerini uretir.

Kullanim (repo kokunden):
    python tools/gen_spirit_assets.py

1) assets/skills/spirit_<id>_icon.png  - 48x48 pixel-art madalyon (oyunun piksel yogunlugu), 144x144'e NEAREST buyutulmus.
2) assets/audio/spiritual/*.wav        - kisa, prosedurel (numpy) ses efektleri. Uzun/loop ses YOK (bkz. hafiza:
   bow hum). Yeni PNG/WAV'lar icin Godot'ta bir kez `--headless --import` gerekir.
"""
import os
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_SKILL = os.path.join(ROOT, "assets", "skills")
OUT_AUDIO = os.path.join(ROOT, "assets", "audio", "spiritual")

# ---------------------------------------------------------------- ikonlar
# Kullanici geri bildirimi (2026-09-21): "oyunum 48x48 piksel oranlarina sahip, ikonlari/efektleri cok pixel yapiyorsun" ->
# ikonlar 48x48 sanat izgarasinda cizilir (eskiden 32x32) ve 3x buyutulur (144x144, NEAREST): her sanat pikseli oyundaki
# karakter pikseline yakin, ince detayli.
S = 48
K = 3


def new_canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def medallion(rim, rim_l, rim_d, bg, bg_l):
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((1, 1, 46, 46), fill=(20, 12, 10, 255))  # koyu dis kontur
    d.ellipse((2, 2, 45, 45), fill=rim)
    d.ellipse((4, 4, 43, 43), fill=rim_d)
    d.ellipse((5, 5, 42, 42), fill=bg)
    d.ellipse((9, 8, 38, 34), fill=bg_l)  # ust kisim hafif aydinlik
    # rim uzerinde sol-ust parlama (yay boyunca 1px)
    for deg in range(200, 262, 3):
        a = np.deg2rad(deg)
        x = int(round(23.5 + 20.5 * np.cos(a)))
        y = int(round(23.5 + 20.5 * np.sin(a)))
        im.putpixel((x, y), rim_l)
    return im


def outline(layer, col=(18, 10, 8, 255)):
    """Emblemin etrafina 1px koyu kontur (yalnizca dis kenar)."""
    w, h = layer.size
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    op[x, y] = col
                    break
    return out


def put(layer, pts, col):
    for (x, y) in pts:
        if 0 <= x < S and 0 <= y < S:
            layer.putpixel((x, y), col)


def sparkle(layer, cx, cy, core, arm, long_arm=2):
    """Ince 4 kollu parilti (1px cekirdek + 1px kollar)."""
    put(layer, [(cx, cy)], core)
    for i in range(1, long_arm + 1):
        put(layer, [(cx + i, cy), (cx - i, cy), (cx, cy + i), (cx, cy - i)], arm)


def finish(base, emblem, name):
    emblem = outline(emblem)
    base.alpha_composite(emblem)
    big = base.resize((S * K, S * K), Image.NEAREST)
    big.save(os.path.join(OUT_SKILL, f"spirit_{name}_icon.png"))


def icon_para():
    base = medallion((214, 160, 40, 255), (255, 232, 140, 255), (120, 78, 16, 255), (44, 30, 14, 255), (70, 50, 22, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    GOLD, GOLD_L, GOLD_D, GOLD_X = (255, 208, 60, 255), (255, 240, 150, 255), (206, 132, 22, 255), (140, 84, 12, 255)
    # 4 madeni para yigini (alttan uste), her biri kenar + yuz + ic oyuk
    for i, cy in enumerate((33, 28, 23, 18)):
        d.ellipse((11, cy - 4, 35, cy + 4), fill=GOLD_X)  # kenar (koyu)
        d.ellipse((11, cy - 6, 35, cy + 2), fill=GOLD)  # yuz
        d.ellipse((13, cy - 5, 33, cy + 1), fill=GOLD_D)  # ic oyuk
        d.ellipse((14, cy - 5, 32, cy), fill=GOLD_L if i == 3 else GOLD)
        put(e, [(16, cy - 3), (17, cy - 4), (18, cy - 4)], (255, 250, 220, 255))
    # ust madeni: ince dikey oyuk ("1" gibi)
    d.rectangle((22, 14, 23, 20), fill=GOLD_D)
    put(e, [(21, 15), (20, 16)], GOLD_D)
    sparkle(e, 36, 11, (255, 255, 255, 255), (255, 240, 170, 255), 3)
    sparkle(e, 10, 34, (255, 255, 255, 255), (255, 232, 140, 255), 1)
    finish(base, e, "para")


def icon_can():
    base = medallion((60, 200, 110, 255), (170, 255, 190, 255), (20, 100, 56, 255), (10, 40, 30, 255), (18, 66, 44, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    R, R_L, R_D, R_X = (236, 64, 96, 255), (255, 160, 180, 255), (170, 26, 66, 255), (110, 14, 44, 255)
    d.ellipse((10, 11, 24, 25), fill=R)
    d.ellipse((23, 11, 37, 25), fill=R)
    d.polygon([(10, 21), (37, 21), (23.5, 38)], fill=R)
    d.polygon([(14, 24), (35, 24), (23.5, 37)], fill=R_D)
    d.ellipse((29, 14, 36, 22), fill=R_D)
    d.polygon([(19, 26), (33, 26), (23.5, 36)], fill=R_X)
    d.ellipse((13, 13, 19, 18), fill=R_L)
    put(e, [(14, 12), (15, 12), (12, 15), (12, 16)], (255, 225, 232, 255))
    d.rectangle((21, 17, 26, 30), fill=(255, 255, 255, 255))
    d.rectangle((16, 21, 31, 26), fill=(255, 255, 255, 255))
    d.rectangle((22, 18, 25, 29), fill=(255, 214, 224, 255))
    d.rectangle((17, 22, 30, 25), fill=(255, 214, 224, 255))
    sparkle(e, 8, 36, (220, 255, 225, 255), (120, 240, 150, 255), 2)
    sparkle(e, 39, 12, (220, 255, 225, 255), (120, 240, 150, 255), 2)
    finish(base, e, "can")


def icon_adc():
    base = medallion((230, 80, 40, 255), (255, 190, 120, 255), (120, 30, 16, 255), (40, 12, 10, 255), (66, 20, 14, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    STEEL, STEEL_L, STEEL_D = (206, 214, 226, 255), (250, 252, 255, 255), (110, 120, 140, 255)
    d.line((12, 36, 31, 17), fill=STEEL_D, width=4)
    d.line((12, 35, 31, 16), fill=STEEL, width=3)
    d.line((13, 34, 30, 17), fill=STEEL_L, width=1)
    d.polygon([(28, 9), (39, 9), (39, 20)], fill=STEEL_D)
    d.polygon([(29, 10), (38, 10), (38, 19)], fill=STEEL)
    d.polygon([(31, 11), (37, 11), (37, 17)], fill=STEEL_L)
    d.polygon([(8, 30), (15, 30), (13, 38), (6, 38)], fill=(255, 120, 60, 255))
    d.polygon([(8, 31), (12, 31), (10, 36), (7, 37)], fill=(255, 176, 100, 255))
    d.polygon([(9, 40), (15, 33), (19, 39), (13, 42)], fill=(230, 60, 40, 255))
    put(e, [(4, 18), (5, 18), (6, 18), (7, 18), (8, 18)], (255, 200, 120, 255))
    put(e, [(3, 24), (4, 24), (5, 24), (6, 24), (7, 24), (8, 24), (9, 24), (10, 24)], (255, 150, 80, 255))
    put(e, [(15, 8), (16, 8), (17, 8), (18, 8), (19, 8), (20, 8)], (255, 200, 120, 255))
    d.polygon([(36, 29), (33, 34), (39, 34)], fill=(230, 40, 60, 255))
    d.ellipse((33, 32, 39, 38), fill=(230, 40, 60, 255))
    put(e, [(35, 34), (35, 35)], (255, 170, 176, 255))
    finish(base, e, "adc")


def icon_tank():
    base = medallion((90, 150, 230, 255), (190, 225, 255, 255), (36, 70, 130, 255), (14, 22, 44, 255), (24, 40, 76, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    ST, ST_L, ST_D = (120, 140, 176, 255), (196, 214, 240, 255), (64, 80, 116, 255)
    d.polygon([(24, 8), (37, 12), (37, 26), (24, 41), (11, 26), (11, 12)], fill=ST_D)
    d.polygon([(24, 10), (35, 13), (35, 25), (24, 38), (13, 25), (13, 13)], fill=ST)
    d.polygon([(24, 10), (24, 38), (13, 25), (13, 13)], fill=ST_L)
    d.line((15, 14, 24, 11), fill=(240, 248, 255, 255), width=1)
    d.polygon([(24, 15), (31, 17), (31, 24), (24, 32), (17, 24), (17, 17)], fill=(206, 140, 40, 255))
    d.polygon([(24, 16), (30, 18), (30, 23), (24, 30), (18, 23), (18, 18)], fill=(240, 190, 70, 255))
    d.polygon([(24, 16), (24, 30), (18, 23), (18, 18)], fill=(255, 226, 130, 255))
    d.rectangle((23, 19, 24, 27), fill=(150, 90, 20, 255))
    d.rectangle((20, 22, 27, 23), fill=(150, 90, 20, 255))
    put(e, [(14, 14), (34, 14), (14, 25), (34, 25)], (230, 240, 255, 255))
    sparkle(e, 41, 19, (230, 250, 255, 255), (150, 220, 255, 255), 2)
    sparkle(e, 6, 19, (230, 250, 255, 255), (150, 220, 255, 255), 2)
    finish(base, e, "tank")


def icon_taktik():
    base = medallion((60, 200, 220, 255), (190, 250, 255, 255), (16, 90, 110, 255), (8, 30, 40, 255), (14, 52, 66, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    cols = [(52, 120, 150, 255), (100, 200, 228, 255), (232, 255, 255, 255)]
    for i, c in enumerate(cols):
        ox = 10 + i * 9
        d.line((ox, 12, ox + 8, 23), fill=c, width=4)
        d.line((ox + 8, 24, ox, 35), fill=c, width=4)
        if i == 2:
            d.line((ox + 1, 13, ox + 7, 23), fill=(190, 240, 255, 255), width=1)
    put(e, [(4, 20), (5, 20), (6, 20), (7, 20)], (150, 230, 250, 255))
    put(e, [(3, 28), (4, 28), (5, 28), (6, 28), (7, 28), (8, 28)], (100, 200, 228, 255))
    sparkle(e, 38, 9, (255, 255, 255, 255), (190, 250, 255, 255), 3)
    sparkle(e, 7, 39, (255, 255, 255, 255), (150, 235, 250, 255), 2)
    finish(base, e, "taktik")


def icon_dukkan():
    base = medallion((160, 110, 230, 255), (225, 200, 255, 255), (70, 40, 130, 255), (24, 16, 44, 255), (40, 28, 72, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    d.ellipse((8, 30, 39, 42), outline=(200, 150, 255, 255), width=2)
    d.ellipse((12, 33, 35, 40), outline=(140, 90, 220, 255), width=1)
    d.rectangle((13, 20, 34, 35), fill=(214, 168, 108, 255))
    d.rectangle((13, 20, 18, 35), fill=(238, 200, 140, 255))
    d.rectangle((30, 20, 34, 35), fill=(184, 138, 86, 255))
    d.polygon([(10, 20), (37, 20), (31, 9), (16, 9)], fill=(200, 60, 56, 255))
    d.polygon([(10, 20), (16, 20), (16, 9)], fill=(240, 110, 100, 255))
    d.polygon([(31, 9), (37, 20), (32, 20)], fill=(160, 40, 40, 255))
    for x in range(12, 36, 5):
        d.rectangle((x, 17, x + 2, 20), fill=(255, 235, 200, 255))
    d.rectangle((21, 26, 27, 35), fill=(90, 56, 36, 255))
    d.rectangle((22, 27, 26, 35), fill=(60, 36, 24, 255))
    put(e, [(25, 31), (26, 31)], (255, 224, 120, 255))
    d.rectangle((15, 24, 18, 28), fill=(255, 226, 150, 255))
    d.rectangle((29, 24, 32, 28), fill=(255, 226, 150, 255))
    d.ellipse((22, 12, 27, 16), fill=(255, 210, 70, 255))
    put(e, [(23, 13)], (255, 250, 210, 255))
    sparkle(e, 40, 12, (255, 255, 255, 255), (230, 200, 255, 255), 3)
    finish(base, e, "dukkan")


def icon_savas_sevki():
    # Kullanici istegi (2026-09-23): "Savas sevki" - olum vurusu/infaz + kalici guc kazanma teması, sicak
    # kirmizi-turuncu (savas cosku) paleti - alevli, yukari dogru kalkan bir kilic.
    base = medallion((210, 60, 30, 255), (255, 150, 90, 255), (110, 24, 10, 255), (34, 10, 8, 255), (60, 18, 12, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    STEEL, STEEL_L, STEEL_D = (222, 228, 236, 255), (255, 255, 255, 255), (140, 148, 168, 255)
    GOLD, GOLD_D = (255, 208, 90, 255), (170, 110, 30, 255)
    d.polygon([(24, 5), (28, 12), (28, 30), (20, 30), (20, 12)], fill=STEEL)
    d.polygon([(24, 5), (28, 12), (24, 12)], fill=STEEL_L)
    d.line((23, 10, 23, 28), fill=STEEL_D, width=1)
    d.rectangle((13, 30, 35, 33), fill=GOLD)
    d.rectangle((13, 30, 35, 31), fill=(255, 232, 160, 255))
    d.rectangle((21, 34, 27, 41), fill=(120, 70, 30, 255))
    d.ellipse((19, 40, 29, 46), fill=GOLD_D)
    d.ellipse((22, 42, 26, 45), fill=GOLD)
    for (fx, fy) in [(13, 25), (35, 21), (10, 15), (38, 13), (16, 8), (32, 6), (24, 3)]:
        put(e, [(fx, fy), (fx + 1, fy)], (255, 140, 40, 255))
        put(e, [(fx, fy - 2)], (255, 210, 100, 255))
    sparkle(e, 7, 34, (255, 220, 180, 255), (255, 140, 60, 255), 2)
    sparkle(e, 41, 30, (255, 220, 180, 255), (255, 140, 60, 255), 2)
    finish(base, e, "savas_sevki")


def icon_kalkan_bagi():
    # Kullanici istegi: "Kalkan bagi" - iki ayri kalkanin ortak bir zincirle/baglantiyla birlestigi görsel.
    base = medallion((70, 130, 220, 255), (170, 210, 255, 255), (24, 60, 120, 255), (10, 22, 40, 255), (18, 40, 70, 255))
    e = new_canvas()
    d = ImageDraw.Draw(e)
    BLU, BLU_L, BLU_D = (100, 160, 230, 255), (200, 230, 255, 255), (40, 80, 150, 255)
    GOLD = (255, 214, 110, 255)
    d.polygon([(7, 10), (19, 7), (19, 25), (13, 35), (7, 25)], fill=BLU_D)
    d.polygon([(8, 11), (18, 9), (18, 24), (13, 33), (8, 24)], fill=BLU)
    d.polygon([(8, 11), (13, 10), (13, 33), (8, 24)], fill=BLU_L)
    d.polygon([(41, 10), (29, 7), (29, 25), (35, 35), (41, 25)], fill=BLU_D)
    d.polygon([(40, 11), (30, 9), (30, 24), (35, 33), (40, 24)], fill=BLU)
    d.polygon([(40, 11), (35, 10), (35, 33), (40, 24)], fill=(230, 245, 255, 255))
    for (cx, cy) in [(20, 17), (24, 19), (28, 17), (20, 24), (24, 26), (28, 24)]:
        d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), outline=GOLD, width=1)
    put(e, [(24, 21), (24, 22)], (255, 245, 210, 255))
    sparkle(e, 6, 38, (220, 240, 255, 255), (150, 210, 255, 255), 2)
    sparkle(e, 41, 38, (220, 240, 255, 255), (150, 210, 255, 255), 2)
    finish(base, e, "kalkan_bagi")


def make_icons():
    os.makedirs(OUT_SKILL, exist_ok=True)
    icon_para()
    icon_can()
    icon_adc()
    icon_tank()
    icon_taktik()
    icon_dukkan()
    icon_savas_sevki()
    icon_kalkan_bagi()


# ------------------------------------------------------------------ sesler
SR = 44100


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    """Kisa atak + ustel sonum zarfi."""
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** release_pow
    e[a:] = tail
    return e


def lowpass(x, cutoff_hz):
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def add_reverb(x, mix=0.25):
    out = x.copy()
    for delay_ms, gain in ((37, 0.45), (61, 0.35), (97, 0.25), (143, 0.15)):
        d = int(SR * delay_ms / 1000.0)
        pad = np.zeros(d)
        out += mix * gain * np.concatenate([pad, x])[: len(x)]
    return out


def save_wav(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    f = int(SR * 0.01)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    with wave.open(os.path.join(OUT_AUDIO, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tone(freq, sec, harmonics=((1, 1.0), (2, 0.3), (3, 0.12))):
    t = t_axis(sec)
    y = np.zeros_like(t)
    for h, g in harmonics:
        y += g * np.sin(2 * np.pi * freq * h * t)
    return y


def snd_can():
    # yukselen 4 notali sifa cani (C5-E5-G5-C6), her nota canli, sonda parilti
    notes = [523.25, 659.25, 783.99, 1046.5]
    total = np.zeros(int(SR * 1.3))
    for i, f in enumerate(notes):
        seg = tone(f, 0.9) * env_ad(int(SR * 0.9), 0.005, 3.0)
        s = int(SR * 0.11 * i)
        total[s:s + len(seg)] += seg * (0.7 + 0.1 * i)
    sparkle_n = np.random.RandomState(1).randn(int(SR * 0.5))
    sparkle_n = (sparkle_n - lowpass(sparkle_n, 3000)) * env_ad(len(sparkle_n), 0.05, 2.0) * 0.05
    total[int(SR * 0.4):int(SR * 0.4) + len(sparkle_n)] += sparkle_n
    save_wav("spirit_can.wav", add_reverb(total, 0.35))


def snd_adc():
    # yukselen "guc" sweep'i + keskin vurus: testere sweep + gurultu
    n = int(SR * 0.75)
    t = t_axis(0.75)
    f = 180 * (1 + 4.5 * (t / 0.75) ** 1.6)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    sq = np.sign(np.sin(phase))
    y = (0.6 * saw + 0.3 * sq) * env_ad(n, 0.02, 1.3)
    noise = np.random.RandomState(2).randn(n)
    noise = (noise - lowpass(noise, 1500)) * env_ad(n, 0.01, 2.0) * 0.4
    hit = tone(90, 0.3) * env_ad(int(SR * 0.3), 0.002, 2.5)
    out = y + noise
    out[:len(hit)] += hit * 1.2
    save_wav("spirit_adc.wav", add_reverb(out, 0.15))


def snd_tank():
    # agir metalik "kalkan" vurusu: dusuk sine + metal inharmonik ust tonlar
    sec = 0.9
    t = t_axis(sec)
    low = np.sin(2 * np.pi * 70 * t * (1 + 0.5 * np.exp(-t * 20))) * np.exp(-t * 6)
    metal = np.zeros_like(t)
    for f, g in ((311, 0.6), (523, 0.5), (846, 0.35), (1290, 0.25), (1811, 0.15)):
        metal += g * np.sin(2 * np.pi * f * t) * np.exp(-t * (5 + f / 400))
    thump = np.random.RandomState(3).randn(len(t))
    thump = lowpass(thump, 400) * np.exp(-t * 30) * 1.5
    save_wav("spirit_tank.wav", add_reverb(low * 1.4 + metal * 0.8 + thump, 0.2))


def snd_tank_reflect():
    sec = 0.3
    t = t_axis(sec)
    y = np.zeros_like(t)
    for f, g in ((880, 0.7), (1320, 0.5), (1975, 0.35), (2960, 0.2)):
        y += g * np.sin(2 * np.pi * f * t) * np.exp(-t * (14 + f / 500))
    y += 0.4 * np.random.RandomState(4).randn(len(t)) * np.exp(-t * 60)
    save_wav("spirit_tank_reflect.wav", y, gain=0.7)


def snd_taktik():
    # hizli "zip": yuksekten alcaga suzulen filtre gurultu + kisa sinus sweep
    sec = 0.42
    n = int(SR * sec)
    t = t_axis(sec)
    noise = np.random.RandomState(5).randn(n)
    bright = noise - lowpass(noise, 2500)
    low = lowpass(noise, 900)
    mix = bright * (1 - t / sec) + low * (t / sec)
    mix *= env_ad(n, 0.02, 1.6)
    f = 1800 * np.exp(-t * 5.5) + 300
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.005, 2.0) * 0.5
    pop_t = t_axis(0.12)
    pop = np.sin(2 * np.pi * 520 * pop_t) * np.exp(-pop_t * 30) * 0.6
    out = mix * 0.9 + sweep
    out[:len(pop)] += pop
    save_wav("spirit_taktik.wav", out)


def snd_dukkan():
    # 3sn'lik yukselen "odaklanma" parilti: tam olarak kanal suresi kadar; tek atimlik (loop YOK)
    sec = 3.0
    n = int(SR * sec)
    t = t_axis(sec)
    glide = 220 * (1 + 2.2 * (t / sec) ** 1.4)
    ph = 2 * np.pi * np.cumsum(glide) / SR
    base = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * (3 + 6 * t / sec) * t)
    env = np.minimum(1.0, t / 0.25) * (0.35 + 0.65 * (t / sec) ** 1.2)
    shimmer = np.zeros(n)
    rs = np.random.RandomState(6)
    for i in range(46):
        st = rs.uniform(0.2, 2.8)
        fq = rs.choice([1568, 1976, 2349, 2637, 3136])
        s = int(SR * st)
        m = min(int(SR * 0.25), n - s)
        tt = np.arange(m) / SR
        shimmer[s:s + m] += 0.10 * np.sin(2 * np.pi * fq * tt) * np.exp(-tt * 14) * (0.3 + st / 3)
    out = base * trem * env * 0.55 + shimmer
    save_wav("spirit_dukkan.wav", add_reverb(out, 0.25), gain=0.7)


def snd_teleport():
    # ısınlanma "pop": kisa alcalan sweep + parilti
    sec = 0.55
    t = t_axis(sec)
    f = 1400 * np.exp(-t * 7) + 180
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.004, 2.2)
    sp = np.zeros(len(t))
    rs = np.random.RandomState(7)
    for i in range(14):
        s = int(SR * rs.uniform(0.02, 0.35))
        m = min(int(SR * 0.12), len(t) - s)
        tt = np.arange(m) / SR
        sp[s:s + m] += 0.18 * np.sin(2 * np.pi * rs.choice([1976, 2637, 3136]) * tt) * np.exp(-tt * 24)
    save_wav("spirit_teleport.wav", add_reverb(sweep * 0.9 + sp, 0.3))


def snd_kalkan_bagi():
    # Iki ayri "kalkan" notasinin birlesip tek bir uyumlu akorda donustugu kisa bir "baglanma" sesi.
    sec = 0.7
    t = t_axis(sec)
    a = tone(392.0, sec, harmonics=((1, 1.0), (2, 0.25))) * env_ad(len(t), 0.02, 2.0)
    b = tone(523.25, sec, harmonics=((1, 1.0), (2, 0.25))) * env_ad(len(t), 0.02, 2.0)
    glide_in = np.minimum(1.0, t / 0.18)
    out = (a * (1.0 - 0.4 * (1.0 - glide_in)) + b * glide_in) * 0.6
    shimmer = np.zeros(len(t))
    rs = np.random.RandomState(9)
    for i in range(10):
        s = int(SR * rs.uniform(0.05, 0.5))
        m = min(int(SR * 0.15), len(t) - s)
        tt = np.arange(m) / SR
        shimmer[s:s + m] += 0.12 * np.sin(2 * np.pi * rs.choice([1568, 1976, 2349]) * tt) * np.exp(-tt * 18)
    save_wav("spirit_kalkan_bagi.wav", add_reverb(out + shimmer, 0.3))


def make_sounds():
    snd_can()
    snd_adc()
    snd_tank()
    snd_tank_reflect()
    snd_taktik()
    snd_dukkan()
    snd_teleport()
    snd_kalkan_bagi()


if __name__ == "__main__":
    make_icons()
    make_sounds()
    print("ok")
