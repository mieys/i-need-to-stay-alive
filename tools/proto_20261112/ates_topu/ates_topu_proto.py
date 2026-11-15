# ATEŞ ASASI "TUTUŞMA" ateş topu PROTOTİPLERİ A-D (2026-11-12; oyuna bağlı DEĞİL).
# Kullanıcı: püskürtme yerine ateş topu; ilk top yakar, yanan hedefe çarpan top yanmayı tüketip patlatır (alevlenme);
# "fazla efekt olursa karmaşıklaşır, kalıcı efekt olmasın sürekli yanma harici" -> top + kısa vuruş patlaması + biraz büyük
# alevlenme patlaması, hepsi bir anda biter (duman/iz/yerde kalan yok).
# Çizim dili: yaratık yanma alevi (yer alevi, madde 551) = fire_min: 3 düz ton + 1 px bordo dış hat, dither yok,
# 1 sanat pikseli = 0,903 dünya birimi (karakter pikseli).
#   A Kor Topu      - yuvarlak top + arkada kıvrılan üç kısa dil
#   B Kuyruklu Kor  - küçük baş + tek uzun sivrilen kuyruk
#   C Dönen Kor     - top + çevresinde dönen dört kıvrık dil (fırıldak)
#   D Kor Taşı      - içi çatlaklı koyu kor taşı + ince alev kabuğu + düşen kıvılcım
# Her kod için: <kod>_top (döngü), <kod>_vur (vuruş, tek sefer), <kod>_alev (alevlenme, tek sefer) .png + .json
# Çalıştır: python -I tools/proto_20261112/ates_topu/ates_topu_proto.py
import os, json, math
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "sheets")
WORLD_PX = 0.903
TAU = 2 * math.pi


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.uint8)


OUTL, RED, ORG, YEL = hx("#661a0f"), hx("#d64c1f"), hx("#fa9433"), hx("#ffdb75")
ROCK_D, ROCK = hx("#2c120c"), hx("#4a1f14")


def h01(i, k=0):
    v = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return v - math.floor(v)


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return x + 0.5, y + 0.5


def disc(X, Y, cx, cy, r):
    return np.clip(1.0 - np.hypot(X - cx, Y - cy) / r, 0.0, 1.0)


def tongue(X, Y, x0, y0, ang, L, w, wob=0.0, ph=0.0):
    """Kökten (x0,y0) 'ang' yönüne giden sivrilen dil: ısı kökte 1, uçta 0."""
    if L < 0.8:
        return np.zeros(X.shape)
    c, s = math.cos(ang), math.sin(ang)
    u = (X - x0) * c + (Y - y0) * s
    v = -(X - x0) * s + (Y - y0) * c
    k = np.clip(u / L, 0.0, 1.0)
    v = v - wob * np.sin(u * 0.55 + ph) * k
    width = w * (1.0 - k) ** 0.8 + 0.45
    inside = (u >= -0.5) & (u <= L)
    return np.where(inside, np.clip(1.0 - np.abs(v) / width, 0.0, 1.0) * (1.0 - 0.75 * k), 0.0)


def grow4(m):
    g = m.copy()
    g[1:, :] |= m[:-1, :]
    g[:-1, :] |= m[1:, :]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


def paint(heat, rock=None, cracks=None, cut=0.14):
    """Isı alanı -> fire_min tonları + bordo dış hat. rock: koyu taş maskesi, cracks: taşın içinde parlayan çatlak."""
    h, w = heat.shape
    img = np.zeros((h, w, 4), np.uint8)
    m = heat > cut
    if rock is not None:
        m |= rock
    edge = grow4(m) & ~m
    img[edge, :3] = OUTL
    img[edge, 3] = 255
    for th, col in ((cut, RED), (0.44, ORG), (0.72, YEL)):
        sel = heat > th
        img[sel, :3] = col
        img[sel, 3] = 255
    if rock is not None:
        inner = rock & ~grow4(~rock)
        img[rock, :3] = ROCK_D
        img[inner, :3] = ROCK
        img[rock, 3] = 255
        if cracks is not None:
            img[cracks & rock, :3] = ORG
            img[cracks & inner & (heat > 0.9), :3] = YEL
    return img


def sheet(frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    return out


# ---------------------------------------------------------------- top (uçuş yönü +x, baş X0,CY'de)
TW, TH, X0, CY = 34, 20, 26, 10
NB, FPS_B = 6, 12


def ball_A(f):
    X, Y = grid(TW, TH)
    t = f / NB * TAU
    heat = disc(X, Y, X0, CY, 5.2) * 1.35
    for i, (da, L) in enumerate(((0.0, 11.0), (0.42, 7.5), (-0.42, 7.5))):
        Lf = L * (0.86 + 0.14 * math.sin(t + i * 2.1))
        heat = np.maximum(heat, tongue(X, Y, X0 - 2.5, CY, math.pi + da, Lf, 2.6, 1.1, t + i) * 1.1)
    return paint(heat)


def ball_B(f):
    X, Y = grid(TW, TH)
    t = f / NB * TAU
    heat = disc(X, Y, X0, CY, 4.3) * 1.4
    heat = np.maximum(heat, tongue(X, Y, X0 - 1.5, CY, math.pi, 21.0 * (0.94 + 0.06 * math.sin(t)), 3.6, 0.8, t) * 1.05)
    # kuyruktan kopan tek kıvılcım (sırayla geride kalır)
    px = X0 - 20 - (f % 3) * 2.0
    py = CY + (1 if f % 2 else -1)
    heat = np.maximum(heat, disc(X, Y, px, py, 1.4) * 0.6)
    return paint(heat)


def ball_C(f):
    X, Y = grid(TW, TH)
    rot = f / NB * (math.pi / 2)   # dört katlı simetri: 90 derece = dikişsiz döngü
    cx = X0 - 4
    heat = disc(X, Y, cx, CY, 4.6) * 1.4
    for i in range(4):
        a = rot + i * math.pi / 2
        x0, y0 = cx + math.cos(a) * 3.2, CY + math.sin(a) * 3.2
        heat = np.maximum(heat, tongue(X, Y, x0, y0, a + 2.0, 6.5, 2.0, 0.6, i) * 1.0)
    return paint(heat)


def ball_D(f):
    X, Y = grid(TW, TH)
    t = f / NB * TAU
    cx = X0 - 2
    rock = np.hypot(X - cx, Y - CY) < 4.6
    # alev kabuğu: taşın arkasından kısa diller + ince kenar
    heat = disc(X, Y, cx, CY, 6.4) * 0.75
    for i, (da, L) in enumerate(((0.0, 8.0), (0.55, 5.5), (-0.55, 5.5))):
        heat = np.maximum(heat, tongue(X, Y, cx - 3.0, CY, math.pi + da, L * (0.85 + 0.15 * math.sin(t + i * 2)), 2.4, 0.9, t + i) * 1.05)
    # çatlaklar (taşla birlikte yavaşça döner)
    a = t * 0.25
    u = (X - cx) * math.cos(a) + (Y - CY) * math.sin(a)
    v = -(X - cx) * math.sin(a) + (Y - CY) * math.cos(a)
    cracks = (np.abs(v - 0.35 * u) < 0.5) & (np.abs(u) < 3.3) | (np.abs(u + 0.6 * v - 1.0) < 0.45) & (v > 0) & (v < 3.0)
    hot = np.where(cracks, 1.0, 0.0)
    heat = np.maximum(heat * ~rock, hot * (0.95 if f % 2 else 0.7))
    # arkadan düşen iki kıvılcım
    for k in range(2):
        px = cx - 11 - ((f + k * 3) % NB) * 1.6
        py = CY + 1 + ((f + k * 3) % NB) * 0.6
        heat = np.maximum(heat, disc(X, Y, px, py, 1.25) * 0.8)
    return paint(heat, rock, cracks)


# ---------------------------------------------------------------- patlama (merkez ortada)
def burst(code, R, big):
    n = 6 if big else 5
    env = [1.0, 1.0, 0.86, 0.62, 0.38, 0.2][:n] if big else [1.0, 0.95, 0.75, 0.48, 0.24]
    grow = [0.45, 0.78, 0.94, 1.0, 1.04, 1.07][:n] if big else [0.5, 0.85, 1.0, 1.05, 1.08]
    S = int(R * 2 + 10)
    c = S / 2.0
    X, Y = grid(S, S)
    frames = []
    for f in range(n):
        g, e = grow[f], env[f]
        heat = np.zeros(X.shape)
        rock = np.zeros(X.shape, bool)
        if code == "A":
            k = 7 if big else 6
            for i in range(k):
                a = i / k * TAU + h01(i, 3) * 0.35
                L = R * g * (0.7 + 0.25 * h01(i, 1))
                heat = np.maximum(heat, tongue(X, Y, c, c, a, L, R * 0.2, 0.3, i) * 1.2)
            heat = np.maximum(heat, disc(X, Y, c, c, R * (0.26 if big else 0.36) * (1.2 - 0.5 * f / n)) * 1.4)
        elif code == "B":
            k = 6 if big else 5
            for i in range(k):
                a = i / k * TAU + h01(i, 7) * 0.6
                L = R * g * (0.45 + 0.4 * h01(i, 2))
                heat = np.maximum(heat, tongue(X, Y, c, c, a, L, R * 0.17, 0.3, i) * 1.15)
                # dilin ucundan fırlayan damla
                rr = R * (0.5 + 0.55 * g) * (0.7 + 0.3 * h01(i, 5))
                heat = np.maximum(heat, disc(X, Y, c + math.cos(a + 0.25) * rr, c + math.sin(a + 0.25) * rr, 3.0) * (1.0 if f < n - 1 else 0.5))
            heat = np.maximum(heat, disc(X, Y, c, c, R * (0.24 if big else 0.32) * (1.2 - 0.6 * f / n)) * 1.4)
        elif code == "C":
            k = 11 if big else 9
            rr = R * (0.25 + 0.6 * g)
            for i in range(k):
                a = i / k * TAU + f * 0.12
                x0, y0 = c + math.cos(a) * rr, c + math.sin(a) * rr
                heat = np.maximum(heat, tongue(X, Y, x0, y0, a + 0.9, R * 0.3, R * 0.1, 0.2, i) * 1.15)
            if f < 2:
                heat = np.maximum(heat, disc(X, Y, c, c, R * (0.3 if f == 0 else 0.2)) * 1.35)
            if big:
                rr2 = rr * 0.55
                for i in range(k // 2):
                    a = i / (k // 2) * TAU - f * 0.18
                    x0, y0 = c + math.cos(a) * rr2, c + math.sin(a) * rr2
                    heat = np.maximum(heat, tongue(X, Y, x0, y0, a - 0.9, R * 0.24, R * 0.08, 0.2, i) * 1.05)
        else:  # D
            heat = np.maximum(heat, disc(X, Y, c, c, R * (0.3 if big else 0.42) * (1.15 - 0.55 * f / n)) * 1.35)
            k = 6 if big else 5
            for i in range(k):
                a = i / k * TAU + h01(i, 9) * 0.5
                heat = np.maximum(heat, tongue(X, Y, c, c, a, R * g * 0.55, R * 0.16, 0.3, i) * 1.1)
                # taş parçası dışarı fırlar
                rr = R * (0.35 + 0.7 * g) * (0.75 + 0.25 * h01(i, 4))
                sx, sy = c + math.cos(a + 0.3) * rr, c + math.sin(a + 0.3) * rr + f * f * 0.35
                sz = 2.6 if big else 2.1
                rock |= (np.abs(X - sx) < sz) & (np.abs(Y - sy) < sz)
                heat = np.maximum(heat, disc(X, Y, sx, sy, sz + 2.2) * 0.8)
        if big:  # alevlenme: ortadan kısa yükselen alev sütunu
            heat = np.maximum(heat, tongue(X, Y, c, c, -math.pi / 2, R * 0.8 * min(1.0, g * 1.1), R * 0.2, 0.6, f) * 1.25)
        heat = heat * e
        frames.append(paint(heat, rock if rock.any() else None, cut=0.14))
    return frames, S


def save(name, frames, fps, extra):
    img = sheet(frames)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name + ".png"))
    h, w = frames[0].shape[:2]
    meta = {"name": name, "w": w, "h": h, "frames": len(frames), "fps": fps, "world_px": WORLD_PX}
    meta.update(extra)
    with open(os.path.join(OUT, name + ".json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False)


def main():
    os.makedirs(OUT, exist_ok=True)
    balls = {"A": ball_A, "B": ball_B, "C": ball_C, "D": ball_D}
    R_HIT = 40.0 / WORLD_PX * 0.8      # vuruş patlaması: 40 birimlik alanın ~%80'i çizilir
    R_BIG = 60.0 / WORLD_PX * 0.8      # alevlenme: 60 birim
    for code, fn in balls.items():
        save(code + "_top", [fn(f) for f in range(NB)], FPS_B, {"x0": X0, "cy": CY})
        fr, S = burst(code, R_HIT, False)
        save(code + "_vur", fr, 15, {"x0": S / 2.0, "cy": S / 2.0})
        fr, S = burst(code, R_BIG, True)
        save(code + "_alev", fr, 14, {"x0": S / 2.0, "cy": S / 2.0})
    # önizleme: dört top 6x büyütülmüş (yalnız inceleme için)
    rows = []
    for code in "ABCD":
        im = Image.open(os.path.join(OUT, code + "_top.png"))
        rows.append(im)
    w = max(r.width for r in rows)
    pv = Image.new("RGBA", (w, sum(r.height + 2 for r in rows)), (40, 30, 24, 255))
    y = 0
    for r in rows:
        pv.alpha_composite(r, (0, y))
        y += r.height + 2
    pv.resize((pv.width * 6, pv.height * 6), Image.NEAREST).save(os.path.join(HERE, "out", "toplar_6x.png"))
    print("tamam", OUT)


if __name__ == "__main__":
    main()
