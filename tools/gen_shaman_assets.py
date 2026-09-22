#!/usr/bin/env python3
"""Shaman'in 3 totem yetenegi icin SIFIRDAN pixel-art assetleri (48x48 izgara) + sesler uretir.

Kullanim (repo kokunden):  python tools/gen_shaman_assets.py

Cikti:
  assets/shaman/totem_{shield,attack,area}_idle.png   6 kareli (288x64) bosta animasyonu - her kare 48x64 (v2 tasarim: tools/shaman_totem_art.py)
  assets/skills/shaman_{kalkan,saldiri,alan}_totemi_icon.png  48x48 madalyon -> 3x = 144x144 (eski dosyalarin uzerine yazar)
  assets/audio/shaman/*.wav                           prosedurel (numpy) ses efektleri (kisa; uzun/loop YOK)
Yeni PNG/WAV icin Godot'ta bir kez `--headless --import` gerekir. Kullanici geri bildirimi: oyun 48x48 piksel yogunlugunda
(bkz. hafiza "Pixel density 48x48") - kalin bloklar / 32x32 yok.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_TOTEM = os.path.join(ROOT, "assets", "shaman")
OUT_SKILL = os.path.join(ROOT, "assets", "skills")
OUT_AUDIO = os.path.join(ROOT, "assets", "audio", "shaman")

S = 48
FRAMES = 6


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def new_canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def outline(layer, col=(14, 9, 10, 255)):
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


def put(im, pts, col):
    for (x, y) in pts:
        if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
            im.putpixel((int(x), int(y)), col)


# ------------------------------------------------------------------ paletler
STONE_D = rgba(58, 54, 66)
STONE = rgba(96, 90, 108)
STONE_L = rgba(140, 134, 152)
WOOD_D = rgba(56, 36, 24)
WOOD = rgba(104, 68, 40)
WOOD_L = rgba(150, 104, 62)
BONE = rgba(232, 222, 196)
BONE_D = rgba(170, 156, 130)


# ------------------------------------------------------------------ TOTEMLER + IKONLAR (v2: tools/shaman_totem_art.py)
# Kullanici geri bildirimi (2026-09-22): "totemleri beğenmedim, baştan tasarla, gerçekten sihirli totemlere benzesinler" - eski tabela/kafatasi/
# kure tasarimi kaldirildi; oyma direk + yuz + parlayan run + havada suzulen buyulu odak (kristal / yasayan alev / bosluk kuresi).
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shaman_totem_art as art

K = 3


def medallion(rim, rim_l, rim_d, bg, bg_l):
    im = new_canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((1, 1, 46, 46), fill=(20, 12, 10, 255))
    d.ellipse((2, 2, 45, 45), fill=rim)
    d.ellipse((4, 4, 43, 43), fill=rim_d)
    d.ellipse((5, 5, 42, 42), fill=bg)
    d.ellipse((9, 8, 38, 34), fill=bg_l)
    for deg in range(200, 262, 3):
        a = np.deg2rad(deg)
        x = int(round(23.5 + 20.5 * np.cos(a)))
        y = int(round(23.5 + 20.5 * np.sin(a)))
        im.putpixel((x, y), rim_l)
    return im


MEDALLIONS = {
    "kalkan": (rgba(70, 140, 235), rgba(190, 225, 255), rgba(30, 64, 130), rgba(12, 22, 46), rgba(22, 40, 78)),
    "saldiri": (rgba(238, 100, 36), rgba(255, 200, 130), rgba(122, 36, 14), rgba(38, 12, 8), rgba(70, 22, 12)),
    "alan": (rgba(160, 96, 230), rgba(226, 190, 255), rgba(70, 34, 130), rgba(20, 12, 38), rgba(36, 22, 68)),
}
ICON_SRC = {"kalkan": "shield", "saldiri": "attack", "alan": "area"}


def make_totems():
    return art.make_totems(OUT_TOTEM)


def make_icons(sheets):
    """Ikon = madalyon + totemin ust kismi (odak + yuz), kare 1 (nabiz tepede) - 36x36'lik kesit piksel-piksel yapistirilir (yeniden olcekleme YOK)."""
    os.makedirs(OUT_SKILL, exist_ok=True)
    for icon_name, src in ICON_SRC.items():
        base = medallion(*MEDALLIONS[icon_name])
        frame = sheets[src].crop((art.W, 0, art.W * 2, art.H))  # 2. kare (48x64)
        crop = frame.crop((6, 0, 42, 36))  # 36x36: odak + ust yuz
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).ellipse((5, 5, 42, 42), fill=255)
        layer = new_canvas()
        layer.paste(crop, (6, 6))
        layer = Image.composite(layer, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask)
        base.alpha_composite(layer)
        big = base.resize((S * K, S * K), Image.NEAREST)
        big.save(os.path.join(OUT_SKILL, f"shaman_{icon_name}_totemi_icon.png"))


# ------------------------------------------------------------------ SESLER
SR = 44100


def t_axis(sec):
    return np.linspace(0, sec, int(SR * sec), endpoint=False)


def env_ad(n, attack, release_pow=2.2):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.linspace(1, 0, n - a) ** release_pow
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


def add_reverb(x, mix_amt=0.25):
    out = x.copy()
    for delay_ms, gain in ((37, 0.45), (61, 0.35), (97, 0.25), (143, 0.15)):
        d = int(SR * delay_ms / 1000.0)
        out += mix_amt * gain * np.concatenate([np.zeros(d), x])[: len(x)]
    return out


def save_wav(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) or 1.0) * gain
    f = int(SR * 0.01)
    x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(OUT_AUDIO, exist_ok=True)
    with wave.open(os.path.join(OUT_AUDIO, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def thud(sec=0.5, f0=85.0, seed=1):
    t = t_axis(sec)
    body = np.sin(2 * np.pi * f0 * t * (1 + 0.6 * np.exp(-t * 25))) * np.exp(-t * 9)
    noise = np.random.RandomState(seed).randn(len(t))
    grit = lowpass(noise, 700) * np.exp(-t * 28) * 1.3
    return body * 1.3 + grit


def snd_plant_shield():
    n = int(SR * 1.1)
    out = np.zeros(n)
    th = thud(0.5, 90, 1)
    out[: len(th)] += th
    for i, f in enumerate((659.25, 987.77, 1318.5)):  # E5 B5 E6: parlak kristal cani
        t = t_axis(0.8)
        seg = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t)) * np.exp(-t * 4.2) * (0.5 - 0.08 * i)
        s = int(SR * (0.12 + 0.09 * i))
        out[s:s + len(seg)] += seg[: n - s]
    save_wav("shaman_plant_shield.wav", add_reverb(out, 0.4))


def snd_plant_attack():
    n = int(SR * 1.0)
    out = np.zeros(n)
    th = thud(0.5, 70, 2)
    out[: len(th)] += th
    rs = np.random.RandomState(3)
    noise = rs.randn(n)
    t = t_axis(1.0)
    whoosh = (noise - lowpass(noise, 1400)) * np.minimum(1.0, t / 0.18) * np.exp(-t * 2.6) * 0.55
    roar = lowpass(noise, 380) * np.exp(-t * 3.0) * 1.2
    crackle = np.zeros(n)
    for _ in range(38):
        s = int(SR * rs.uniform(0.05, 0.9))
        m = min(int(SR * 0.012), n - s)
        crackle[s:s + m] += rs.randn(m) * rs.uniform(0.2, 0.7) * np.exp(-np.arange(m) / (SR * 0.004))
    save_wav("shaman_plant_attack.wav", add_reverb(out + whoosh + roar + crackle, 0.2))


def snd_plant_area():
    n = int(SR * 1.3)
    out = np.zeros(n)
    th = thud(0.5, 60, 4)
    out[: len(th)] += th * 0.9
    t = t_axis(1.3)
    hum = (np.sin(2 * np.pi * 110 * t) + np.sin(2 * np.pi * 116.5 * t)) * 0.5
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * (3 + 5 * t) * t)
    env = np.minimum(1.0, t / 0.35) * np.exp(-np.maximum(0, t - 0.4) * 2.4)
    noise = np.random.RandomState(5).randn(n)
    sweep = lowpass(noise, 400) * (0.3 + 0.7 * t / 1.3)
    swirl = (lowpass(noise, 1800) - lowpass(noise, 500)) * np.sin(np.pi * t / 1.3) * 0.6
    save_wav("shaman_plant_area.wav", add_reverb(out + hum * trem * env * 0.6 + sweep * 0.25 + swirl, 0.35))


def snd_expire():
    n = int(SR * 0.8)
    t = t_axis(0.8)
    rs = np.random.RandomState(6)
    out = lowpass(rs.randn(n), 260) * np.exp(-t * 4.0) * 1.3
    for _ in range(14):
        s = int(SR * rs.uniform(0.0, 0.55))
        m = min(int(SR * 0.09), n - s)
        tt = np.arange(m) / SR
        out[s:s + m] += lowpass(rs.randn(m), rs.uniform(500, 1500)) * np.exp(-tt * 40) * rs.uniform(0.3, 0.9)
    out += np.sin(2 * np.pi * 55 * t) * np.exp(-t * 7) * 0.8
    save_wav("shaman_expire.wav", add_reverb(out, 0.15))


def snd_shield_pulse():
    t = t_axis(0.45)
    f = 880 + 440 * np.minimum(1.0, t / 0.08)
    ping = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    ping += 0.3 * np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 14)
    save_wav("shaman_shield_pulse.wav", add_reverb(ping, 0.35), gain=0.6)


def snd_bolt_shot():
    n = int(SR * 0.32)
    t = t_axis(0.32)
    rs = np.random.RandomState(7)
    noise = rs.randn(n)
    band = lowpass(noise, 3400) - lowpass(noise, 700)
    sweep = band * (1 - t / 0.32) * np.minimum(1.0, t / 0.02)
    pop = np.sin(2 * np.pi * 240 * t * (1 + 1.2 * np.exp(-t * 30))) * np.exp(-t * 26) * 0.9
    save_wav("shaman_bolt_shot.wav", sweep * 0.8 + pop, gain=0.75)


def snd_bolt_hit():
    n = int(SR * 0.28)
    t = t_axis(0.28)
    rs = np.random.RandomState(8)
    burst = lowpass(rs.randn(n), 2200) * np.exp(-t * 20)
    body = np.sin(2 * np.pi * 130 * t * (1 + 0.5 * np.exp(-t * 30))) * np.exp(-t * 16)
    crack = np.zeros(n)
    for _ in range(9):
        s = int(SR * rs.uniform(0.0, 0.16))
        m = min(int(SR * 0.008), n - s)
        crack[s:s + m] += rs.randn(m) * rs.uniform(0.3, 0.8) * np.exp(-np.arange(m) / (SR * 0.003))
    save_wav("shaman_bolt_hit.wav", burst * 0.9 + body + crack, gain=0.75)


def snd_area_pulse():
    n = int(SR * 0.7)
    t = t_axis(0.7)
    rs = np.random.RandomState(9)
    hum = np.sin(2 * np.pi * 72 * t) * np.sin(np.pi * t / 0.7) ** 1.5
    swirl = (lowpass(rs.randn(n), 1400) - lowpass(rs.randn(n), 300)) * np.sin(np.pi * t / 0.7) ** 2 * 0.5
    save_wav("shaman_area_pulse.wav", add_reverb(hum * 0.9 + swirl, 0.3), gain=0.6)


def make_sounds():
    snd_plant_shield()
    snd_plant_attack()
    snd_plant_area()
    snd_expire()
    snd_shield_pulse()
    snd_bolt_shot()
    snd_bolt_hit()
    snd_area_pulse()


if __name__ == "__main__":
    make_icons(make_totems())
    make_sounds()
    print("ok")
