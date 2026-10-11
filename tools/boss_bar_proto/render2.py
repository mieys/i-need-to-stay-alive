"""2. tur prototiplerini PNG'ye çizer: her tasarım x 3 durum (dolu / yaralı+kalkan / kalkansız düşük can). python -I render2.py <çıktı_klasörü>"""
import os
import random
import sys
from PIL import Image
from art import *
import protos_top2 as P

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
STATES = [
    ("Wendigo", 1.0, 1.0, 200000, 280000),
    ("Balkabağı Kafa", 0.62, 0.38, 100000, 120000),
    ("Uçan Şeytan", 0.14, 0.0, 1000000, 1200000),
]
SCALE = 3


def bg(w, h, night=False):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = im.load()
    r = random.Random(3)
    for y in range(h):
        for x in range(w):
            base = (122, 168, 82) if not night else (44, 62, 52)
            n = r.randint(-6, 6)
            px[x, y] = (base[0] + n, base[1] + n, base[2] + n // 2, 255)
    return im


sheets = {}
for pid, pname, fn in P.PROTOS:
    arts = []
    for (bname, hp, sh, hpm, shm) in STATES:
        a = fn(bname.upper(), hp, sh, hpm, shm)
        arts.append(a)
        a.scaled(SCALE).save(os.path.join(OUT, f"{pid}_{len(arts)}.png"))
    W = arts[0].w * SCALE
    H = sum(a.h * SCALE + 18 for a in arts) + 18
    sheet = bg(W + 40, H)
    y = 18
    for a in arts:
        sheet.alpha_composite(a.scaled(SCALE), (20, y))
        y += a.h * SCALE + 18
    sheet.save(os.path.join(OUT, f"{pid}_sheet.png"))
    sheets[pid] = sheet
print("ok", OUT)
