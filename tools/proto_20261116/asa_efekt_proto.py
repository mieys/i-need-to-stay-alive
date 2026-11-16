# -*- coding: utf-8 -*-
"""ASA EFEKT prototipleri (2026-11-16, OYUNA BAĞLI DEĞİL). Kullanıcı: "buz asası, arcane asası ve zehir asasının efektleri için yeni
özel efekt prototipleri hazırla. ve bu silahlar hiç kullanılmıyor çok sıkıcı bulunuyorlar".

Teşhis (oyunda şu an): üç asanın mermisi de aynı "ışık izi" dilinden (madde 201 C) - Buz camgöbeği elmas, Arcane mor top + halka izi,
Zehir minik damla; isabetler dışarıdan alınmış yumuşak sayfalar (pembe kabarcık patlaması, büyük kafatası bulutu); özelliklerin ödülü
GENEL efektlerle: Yankı = düz renkli "ring" + yeniden boyanmış Korsan patlaması, Parçalanma = crystal_burst x4,17 NEAREST (iri piksel),
yavaşlatma / zehir yükü yaratıkta neredeyse görünmüyor -> oyuncu silahın NE yaptığını görmüyor.

Her asa için 3 yön, her yönün KENDİ çizim dili (madde 241 dersi: yalnız şekil değil çizim eli de farklı):
  BUZ    A Kırağı Bloğu   köşeli kristal, 1 px lacivert kontur, 4 ton cel; yavaşlatma = tabanda kırağı dikenleri, donma = yüzlü buz
                          bloğu, parçalanma = blok bütün parçalara bölünüp saçılır + yerde buz dalgası (100 birim).
         B Kar Tanesi     konturSUZ, ışıklı, yumuşak; dönen kar tanesi mermi, yavaşlatma = başın üstünde dönen kar tanesi, donma =
                          kırağılı beyaz tonlama + kar başlığı, parçalanma = temiz soğuk sis bulutu + dışa dönen kar taneleri.
         C Saplanan Sarkıt kalın 2 px çizgi film konturu, 2 ton + parlama; sarkıt yaratığa SAPLANIP KALIR (yavaşlatma sayacı gözle
                          okunur), donma = çizgi film buz kütlesi, parçalanma = sarkıtlar yıldız gibi dışa fırlar, komşulara saplanır.
  ARCANE A Rün Küresi     1 px koyu mor kontur, geometrik; ay taşlı küre + sarmal iz; YANKI = yerde kendini saat gibi çizen rün
                          dairesi (0,8 sn sayaç okunur), sonunda yukarıdan hayalet küre düşer, patlar.
         B Yıldız Tozu    konturSUZ, beyaz çekirdekli parıltılar (büyüyüp küçülür); YANKI = hedefin üstünde iki kez nefes alan
                          hayalet yıldız, parıltılar içine kıvrılır, çöküp patlar.
         C Kaos Yarığı    TERS ışık: kara çekirdek + parlak pembe kenar, kırık çizgiler; YANKI = havada açılan dikey yarık, çevreden
                          karanlık çeker, 0,8 sn'de kırık halka şok dalgası tükürür.
  ZEHİR  A Damla+         parlak sıvı, 1 px koyu yeşil kontur; esneyen damla, düşüp sıçrayan damlacıklar; zehir yükü = yaratığın
                          gövdesinden süzülen damlalar (yük sayısı kadar), ölüm = sıçrama + parlayan damla yayla atlar.
         B Kabarcık       konturSUZ yumuşak gaz; zehir kabarcığı mermi, isabette patlayan halka + hedefe emilen bulut; yük = taban
                          çevresinde nefes alan zehir halesi (yükle büyür) + yükselen kabarcıklar; ölüm = temiz zehir bulutu.
         C Asit           kalın 2 px çizgi film konturu, sarımsı asit; zincir damla tükürük, isabette ŞLAP lekesi gövdede kalır
                          (yük başına bir leke, buhar tüter); ölüm = yaratık erir, asit tükürüğü sıçrar.
"0 Şimdiki" kareleri oyundaki dokulardan YAKLAŞIK kurulur (mermi gövde/iz, isabet sayfaları; Yankı patlaması ve zehir sıçraması
temsili). TİTREŞİM / dither / nokta gürültüsü YOK (kalıcı kural, 2026-11-15): yumuşaklık yalnız düz alfa bantlarıyla.

Ölçek: 1 efekt pikseli = 1 dünya birimi (karakter pikseli 0,903'e yakın; madde 295: 0,575 1080p'de kayboluyordu), GIF'te kamera x2
(1080p oyun ölçeği). Zamanlar gerçek: Buz 1,0 sn / Arcane 1,7 sn / Zehir 1,7 sn atış aralığı, mermi 400 (Zehir 460) birim/sn,
Yankı 0,8 sn + 45 birim, Parçalanma 100 birim, Sıçrama 0,28 sn. Karakter Şovalye, asa tepe yuvasında (0, -62,5) hedefe döner.
Arka plan: proto_20261016 gerçek çizici yakalaması (kopru_oyun_A.png).

Çıktı (out/asa_efekt/): buz.gif, arcane.gif, zehir.gif (her biri 0/A/B/C 2x2), ozet.png (ödül anı), yakin.png (x4 mermi + ödül).
Kullanım (proje kökünden): python -I tools/proto_20261116/asa_efekt_proto.py [buz|arcane|zehir|ozet]   (argümansız: hepsi)
"""
import math
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(PROJECT, "tools", "proto_20261017"))
import silah_takip_proto as T  # noqa: E402
from mermi_proto import label  # noqa: E402
from bicak_proto import header, stack_v, save_gif  # noqa: E402

OUT = os.path.join(HERE, "out", "asa_efekt")
f32 = np.float32
Z = 2  # kamera yakınlaştırması (1080p)
VW, VH = 250, 124  # panel dünya boyu
O = (165, 96)  # panel sol-üst köşesi kopru_oyun_A.png içinde (sakin çimen, köprünün kuzeyi)
FPS = 25
TAU = math.tau
D2R = math.pi / 180.0

P = (40.0, 94.0)  # oyuncu (karakter merkezi)
STAFF = (P[0], P[1] - 62.5)  # tepe yuvası
SL = [(181.0, 80.0), (207.0, 68.0), (215.0, 104.0)]  # S1 (ana hedef), S2, S3
SK = T.SLIME_K
BODY_DY = -2.4  # slime gövde merkezi (kare merkezine göre, dünya)
BODY_R = 9.0
BODY_TOP = -11.4
BODY_BOT = 6.6


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


def ramp(s):
    return [hx(c) for c in s.split()]


WHITE = (255, 255, 255)
ICE = ramp("#ffffff #e0f4fc #b4dcec #88bcd4 #5e8aa0")
ICE_OL = hx("#2e4a5e")
ICE_C = ramp("#f4fcff #d6f0fb #7fc0e0 #4a90b8")
ICE_C_OL = hx("#1e3550")
ARC = ramp("#fbf2ff #e8d2fa #c8a0f0 #9c64dc #6a3aa8")
ARC_SAT = hx("#b070f0")
ARC_GLOW = hx("#d07cff")  # parıltı halesi: pembeye kaçan mor (mavi-mor çimende grileşiyor)
VOID = ramp("#fbe0ff #f070ff #3d1866 #1c0b2e")
POI = ramp("#f4ffc8 #c8f060 #8cd23c #4f9a2a #2c5a1c")
POI_OL = hx("#1e3a14")
ACID = ramp("#fbffd0 #e2f55a #9cc82e #5e8a1c")
ACID_OL = hx("#24300c")


def B(a, n=4):
    """Düz alfa (titreşimsiz): her şekil TEK düz alfa ile çizilir; sönüş zamanda 1/12 basamaklarla iner. (n eski parametre: ilk sürümde
    ceil(a*n)/n düşük alfaları şişiriyordu - 0,22 -> 0,5 - bulutlar pamuk gibi opak çıktı.)"""
    a = max(0.0, min(1.0, a))
    return math.ceil(a * 12 - 1e-6) / 12 if a > 0 else 0.0


def ease_out(x):
    x = max(0.0, min(1.0, x))
    return 1.0 - (1.0 - x) ** 3


def body_c(i):
    return (SL[i][0] + 1.0, SL[i][1] + BODY_DY)


def dist(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


def unit(a, b):
    d = dist(a, b) or 1.0
    return ((b[0] - a[0]) / d, (b[1] - a[1]) / d)


def lerp(a, b, u):
    return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)


def bez(p0, p1, p2, u):
    w = 1.0 - u
    return (w * w * p0[0] + 2 * w * u * p1[0] + u * u * p2[0], w * w * p0[1] + 2 * w * u * p1[1] + u * u * p2[1])


# ------------------------------------------------------------------ efekt katmanı (1 px = 1 dünya birimi, premultiplied)
class Layer:
    def __init__(s, w=None, h=None):
        s.W, s.H = (w or VW), (h or VH)  # tools/gen_asa_efekt_fx.py sayfa karesi boyunda kurar
        s.C = np.zeros((s.H, s.W, 3), f32)
        s.A = np.zeros((s.H, s.W), f32)

    def _blend(s, x0, y0, m, col, a):
        if a <= 0.0:
            return
        h, w = m.shape
        xa, ya, xb, yb = max(0, x0), max(0, y0), min(s.W, x0 + w), min(s.H, y0 + h)
        if xa >= xb or ya >= yb:
            return
        mm = m[ya - y0:yb - y0, xa - x0:xb - x0]
        if not mm.any():
            return
        sub, suba = s.C[ya:yb, xa:xb], s.A[ya:yb, xa:xb]
        if isinstance(col, np.ndarray) and col.ndim == 3:
            cc = col[ya - y0:yb - y0, xa - x0:xb - x0][mm]
        else:
            cc = np.array(col, f32)
        sub[mm] = sub[mm] * (1.0 - a) + cc * a
        suba[mm] = suba[mm] * (1.0 - a) + a

    @staticmethod
    def _mask(bbox, fn):
        x0, y0 = int(math.floor(bbox[0])) - 1, int(math.floor(bbox[1])) - 1
        x1, y1 = int(math.ceil(bbox[2])) + 2, int(math.ceil(bbox[3])) + 2
        if x1 - x0 <= 0 or y1 - y0 <= 0:
            return x0, y0, np.zeros((1, 1), bool)
        im = Image.new("1", (x1 - x0, y1 - y0), 0)
        fn(ImageDraw.Draw(im), x0, y0)
        return x0, y0, np.asarray(im, dtype=bool)

    def px(s, x, y, col, a=1.0):
        s._blend(int(math.floor(x)), int(math.floor(y)), np.ones((1, 1), bool), col, a)

    def rect(s, x, y, w, h, col, a=1.0):
        s._blend(int(math.floor(x)), int(math.floor(y)), np.ones((max(1, int(h)), max(1, int(w))), bool), col, a)

    def ell(s, cx, cy, rx, ry, col, a=1.0):
        if rx < 0.6 and ry < 0.6:
            s.px(cx, cy, col, a)
            return
        x0, y0, m = s._mask((cx - rx, cy - ry, cx + rx, cy + ry),
                            lambda d, ox, oy: d.ellipse([cx - rx - ox, cy - ry - oy, cx + rx - ox - 1, cy + ry - oy - 1], fill=1))
        s._blend(x0, y0, m, col, a)

    def disc(s, cx, cy, r, col, a=1.0):
        s.ell(cx, cy, r, r, col, a)

    def ring(s, cx, cy, rx, ry, w, col, a=1.0):
        if rx < 1.0:
            return
        x0, y0, m = s._mask((cx - rx, cy - ry, cx + rx, cy + ry),
                            lambda d, ox, oy: d.ellipse([cx - rx - ox, cy - ry - oy, cx + rx - ox - 1, cy + ry - oy - 1], outline=1,
                                                        width=max(1, int(w))))
        s._blend(x0, y0, m, col, a)

    def arc(s, cx, cy, rx, ry, a0, a1, w, col, a=1.0):
        """a0..a1 derece (saat yönü, 0 = sağ)."""
        if rx < 1.0 or a1 <= a0:
            return
        x0, y0, m = s._mask((cx - rx, cy - ry, cx + rx, cy + ry),
                            lambda d, ox, oy: d.arc([cx - rx - ox, cy - ry - oy, cx + rx - ox - 1, cy + ry - oy - 1], a0, a1, fill=1,
                                                    width=max(1, int(w))))
        s._blend(x0, y0, m, col, a)

    def line(s, xa, ya, xb, yb, col, a=1.0, w=1):
        x0, y0, m = s._mask((min(xa, xb) - w, min(ya, yb) - w, max(xa, xb) + w, max(ya, yb) + w),
                            lambda d, ox, oy: d.line([xa - ox, ya - oy, xb - ox, yb - oy], fill=1, width=int(w)))
        s._blend(x0, y0, m, col, a)

    def poly(s, pts, col, a=1.0):
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        x0, y0, m = s._mask((min(xs), min(ys), max(xs), max(ys)),
                            lambda d, ox, oy: d.polygon([(p[0] - ox, p[1] - oy) for p in pts], fill=1))
        s._blend(x0, y0, m, col, a)

    def blob(s, circles, col, a=1.0):
        """Dairelerin BİRLEŞİMİ tek maske: üst üste binen yerler koyulaşmaz (temiz bulut, kabarcık görünmez)."""
        circles = [c for c in circles if c[2] >= 0.6]
        if not circles:
            return
        x0, y0, m = s._mask((min(c[0] - c[2] for c in circles), min(c[1] - c[2] for c in circles),
                             max(c[0] + c[2] for c in circles), max(c[1] + c[2] for c in circles)),
                            lambda d, ox, oy: [d.ellipse([c[0] - c[2] - ox, c[1] - c[2] - oy, c[0] + c[2] - ox - 1, c[1] + c[2] - oy - 1],
                                                         fill=1) for c in circles])
        s._blend(x0, y0, m, col, a)

    def cloud(s, circles, cols, alphas, grow=(1.0, 0.72, 0.45)):
        """Bantlı bulut: dış birleşim soluk, iç birleşimler (küçültülmüş yarıçap) daha opak - titreşimsiz yumuşaklık."""
        for col, a, k in zip(cols, alphas, grow):
            s.blob([(c[0], c[1], c[2] * k) for c in circles], col, a)

    def star4(s, cx, cy, r, core, arm, a=1.0):
        r = int(round(r))
        if r <= 0:
            return
        if r >= 2:
            s.line(cx - r, cy, cx + r, cy, arm, a)
            s.line(cx, cy - r, cx, cy + r, arm, a)
        if r >= 3:
            s.rect(cx - 1, cy, 3, 1, core, a)
            s.rect(cx, cy - 1, 1, 3, core, a)
        s.px(cx, cy, core, a)

    def shape(s, pts_local, ang, cx, cy, shade, ol=None, olk=1, a=1.0, sx=1.0, sy=1.0, extra=None):
        """Yerel şekil (+x ileri) -> döndür / ölçekle / yerleştir. shade(LX, LY) -> (h, w, 3) renk. extra: ek yerel daireler [(x,y,r)]
        (birleşim). ol: dış kontur rengi (olk px)."""
        c, sn = math.cos(ang), math.sin(ang)

        def g(p):
            x, y = p[0] * sx, p[1] * sy
            return (cx + c * x - sn * y, cy + sn * x + c * y)

        polys = [[g(p) for p in pts_local]] if pts_local else []
        circles = []
        for (ex, ey, er) in (extra or []):
            gx, gy = g((ex, ey))
            circles.append((gx, gy, er * max(sx, sy) if sx == sy else er))
        xs = [p[0] for pl in polys for p in pl] + [q[0] - q[2] for q in circles] + [q[0] + q[2] for q in circles]
        ys = [p[1] for pl in polys for p in pl] + [q[1] - q[2] for q in circles] + [q[1] + q[2] for q in circles]
        pad = olk + 1

        def fn(d, ox, oy):
            for pl in polys:
                d.polygon([(p[0] - ox, p[1] - oy) for p in pl], fill=1)
            for (gx, gy, er) in circles:
                d.ellipse([gx - er - ox, gy - er - oy, gx + er - ox - 1, gy + er - oy - 1], fill=1)

        x0, y0, m = s._mask((min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad), fn)
        if ol is not None:
            o = m.copy()
            for _ in range(olk):
                o = o | np.roll(o, 1, 0) | np.roll(o, -1, 0) | np.roll(o, 1, 1) | np.roll(o, -1, 1)
            s._blend(x0, y0, o & ~m, ol, a)
        h, w = m.shape
        YY, XX = np.mgrid[0:h, 0:w].astype(f32)
        X = XX + x0 + 0.5 - cx
        Y = YY + y0 + 0.5 - cy
        LX = (c * X + sn * Y) / sx
        LY = (-sn * X + c * Y) / sy
        s._blend(x0, y0, m, shade(LX, LY).astype(f32), a)


def tone2(light, mid, split=0.0, dark=None, dark_at=None):
    """Yerel y'ye göre cel ton (üst ışıklı)."""
    def f(LX, LY):
        out = np.empty(LX.shape + (3,), f32)
        out[:] = np.array(mid, f32)
        out[LY < split] = np.array(light, f32)
        if dark is not None:
            out[LY > dark_at] = np.array(dark, f32)
        return out
    return f


def composite(F, L):
    C = np.repeat(np.repeat(L.C, Z, 0), Z, 1)
    A = np.repeat(np.repeat(L.A, Z, 0), Z, 1)[..., None]
    F[:] = F * (1.0 - A) + C


# ------------------------------------------------------------------ sahne: zemin, karakter, asa, slime
GROUND = None


def ground_crop():
    global GROUND
    if GROUND is None:
        G = T.ground(Z)
        GROUND = G[O[1] * Z:(O[1] + VH) * Z, O[0] * Z:(O[0] + VW) * Z].astype(f32)
    return GROUND.copy()


STAFF_FILE = {"buz_asasi": "buz_asasi", "arcane": "arcane", "tuftuf": "zehir_asasi"}
STAFF_MUL = {"buz_asasi": 1.22, "arcane": 1.06, "tuftuf": 1.09}  # weapon_tier_art.gd SIZE_MULT
_ICON = {}


def staff_icon(key):
    if key not in _ICON:
        im = Image.open(os.path.join(PROJECT, "assets", "weapons", "yeni", STAFF_FILE[key] + ".png")).convert("RGBA")
        a = np.asarray(im, dtype=f32)
        # uç: ileri eksende (-45 derece, sağ-üst) en uzak opak piksel, 3 px içeri
        ys, xs = np.nonzero(a[..., 3] > 0)
        fx, fy = math.cos(-45 * D2R), math.sin(-45 * D2R)
        dots = (xs + 0.5 - a.shape[1] / 2.0) * fx + (ys + 0.5 - a.shape[0] / 2.0) * fy
        j = int(np.argmax(dots))
        tip = (xs[j] + 0.5 - a.shape[1] / 2.0 - 3 * fx, ys[j] + 0.5 - a.shape[0] / 2.0 - 3 * fy)
        _ICON[key] = (a, tip)
    return _ICON[key]


def staff_state(key, t, aim_pt, fires):
    """Asa konumu (bob + geri tepme), dönüşü ve dünya ucu."""
    a, tip = staff_icon(key)
    k = 0.575 * STAFF_MUL[key]
    bob = math.sin(t * 2.2) * 1.2
    ang = math.atan2(aim_pt[1] - STAFF[1], aim_pt[0] - STAFF[0])
    kick = 0.0
    for f in fires:
        if 0.0 <= t - f < 0.14:
            kick = 2.5 * (1.0 - (t - f) / 0.14)
    pos = (STAFF[0] - math.cos(ang) * kick, STAFF[1] + bob - math.sin(ang) * kick)
    rot = ang + 45 * D2R
    c, s = math.cos(rot), math.sin(rot)
    tw = (pos[0] + (c * tip[0] - s * tip[1]) * k, pos[1] + (s * tip[0] + c * tip[1]) * k)
    return pos, rot, tw, k


def tip_at(key, t, aim_pt, fires):
    return staff_state(key, t, aim_pt, fires)[2]


## Yaratık: kırmızı Slime 7 (yeşil zehir / camgöbeği buz / mor arcane üçü de üstünde okunur; Slime 1 yeşil-turkuaz, zehirle karışıyordu).
## Gövde kutusu Slime 1 ile aynı (sanat px x 23..43, y 18..39).
_SLIME = {}


def slime_frame(t, seed=0):
    col = int(t * 8.0 + seed * 3) % 6
    if col not in _SLIME:
        import glob
        p = glob.glob(os.path.join(PROJECT, "visuals", "Yaratıklar", "Tüm Yaratıklar", "Slime 7", "**", "*Idle_with_shadow.png"),
                      recursive=True)[0]
        _SLIME[col] = np.asarray(Image.open(p).convert("RGBA").crop((col * 64, 0, col * 64 + 64, 64)), dtype=f32)
    return _SLIME[col]


def new_slimes():
    return [{"alpha": 1.0, "tint": None, "tint_a": 0.0, "freeze": None, "sx": 1.0, "sy": 1.0, "flash": 0.0} for _ in SL]


def draw_scene(F, t, key, aim_pt, fires, S):
    """Zemin üstüne: gölgeler, slime'lar (y sırası), karakter, asa."""
    def sc(p):
        return (p[0] * Z, p[1] * Z)

    sx, sy = sc((P[0], P[1] + 12.0))
    T.ellipse(F, sx, sy, 9.0 * Z, 3.5 * Z, (0, 0, 0), 0.32)
    pos, rot, _, k = staff_state(key, t, aim_pt, fires)
    sx, sy = sc((pos[0], P[1] + 12.0))
    T.ellipse(F, sx, sy, 6.0 * Z, 2.2 * Z, (0, 0, 0), 0.13)
    for i in sorted(range(len(SL)), key=lambda j: SL[j][1]):
        st = S[i]
        if st["alpha"] <= 0.0:
            continue
        fr = slime_frame(st["freeze"] if st["freeze"] is not None else t, i)
        x, y = SL[i]
        # ölçek tabana sabit (ezilme / erime)
        yb = y + BODY_BOT
        cy = yb - (yb - y) * st["sy"]
        args = (F, fr, x * Z, cy * Z, SK * Z, 0.0, st["sx"], st["sy"])
        T.blit2(*args, alpha=st["alpha"])
        if st["tint"] is not None and st["tint_a"] > 0.0:
            T.blit2(*args, alpha=st["alpha"] * st["tint_a"], tint=st["tint"])
        if st["flash"] > 0.0:
            T.blit2(*args, alpha=st["alpha"] * st["flash"], tint=(255, 250, 240))
    fr = T.char_frame(False, (1, 0), 0.0, t)
    sx, sy = sc((P[0], P[1] + T.CHAR_OFF_Y))
    T.blit2(F, fr, sx, sy, T.CHAR_K * Z)
    a, _ = staff_icon(key)
    sx, sy = sc(pos)
    T.blit2(F, a, sx, sy, k * Z, rot)


def blit_world(F, arr, cx, cy, k, rot=0.0, alpha=1.0, sx=1.0):
    T.blit2(F, arr, cx * Z, cy * Z, k * Z, rot, sx, 1.0, alpha=alpha)


# ------------------------------------------------------------------ oyundaki dokular ("0 Şimdiki")
_TEX = {}


def tex(path, box=None):
    k = (path, box)
    if k not in _TEX:
        im = Image.open(os.path.join(PROJECT, path)).convert("RGBA")
        _TEX[k] = np.asarray(im.crop(box) if box else im, dtype=f32)
    return _TEX[k]


def strip(path, n, i):
    im = Image.open(os.path.join(PROJECT, path))
    w = im.width // n
    return tex(path, (i * w, 0, i * w + w, im.height))


def tres_regions(path):
    s = open(os.path.join(PROJECT, path), encoding="utf-8").read()
    return [tuple(int(float(v)) for v in m.groups()) for m in re.finditer(r"Rect2\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", s)]


def cur_projectile(F, name, nb, bfps, ntr, tfps, tox, pos, ang, age):
    """projectile_art.gd: gövde <name>_govde (nb kare), iz <name>_iz (3 fırlatma + ntr uçuş karesi), WORLD_PX 0,575."""
    k = 0.575
    if ntr > 0:
        nt = 3 + ntr
        fi = int(age * 30.0) if age < 3 / 30.0 else 3 + int((age - 0.1) * tfps) % ntr
        tr = strip("assets/weapons/mermi/%s_iz.png" % name, nt, min(nt - 1, fi))
        w = tr.shape[1]
        off = tox * k
        cx, cy = pos[0] + math.cos(ang) * off, pos[1] + math.sin(ang) * off
        # iz dokusu offset.x = tox: dokunun merkezi pivotun gerisinde
        blit_world(F, tr, cx, cy, k, ang)
        _ = w
    body = strip("assets/weapons/mermi/%s_govde.png" % name, nb, int(age * bfps) % nb)
    blit_world(F, body, pos[0], pos[1], k, ang)


def cur_sheet(F, path, n, age, fps, pos, k, rot=0.0, alpha=1.0):
    i = int(age * fps)
    if 0 <= i < n:
        blit_world(F, strip(path, n, i), pos[0], pos[1], k, rot, alpha)
        return True
    return False


def cur_frames_dir(F, d, n, age, fps, pos, k):
    i = int(age * fps)
    if 0 <= i < n:
        blit_world(F, tex("%s/frame%d.png" % (d, i)), pos[0], pos[1], k)


def flight(f, t, a, b, speed):
    """f anında a'dan atılan mermi t'de nerede (u, konum) / None."""
    T_fl = dist(a, b) / speed
    if f <= t < f + T_fl:
        u = (t - f) / T_fl
        return u, lerp(a, b, u)
    return None


# ================================================================== BUZ ASASI
BUZ_FIRE = [0.10, 1.10, 2.10]
BUZ_SPEED = 400.0
BUZ_LOOP = 3.4


def buz_times():
    aim = body_c(0)
    tips = [tip_at("buz_asasi", f, aim, BUZ_FIRE) for f in BUZ_FIRE]
    hits = [f + dist(tp, aim) / BUZ_SPEED for f, tp in zip(BUZ_FIRE, tips)]
    return aim, tips, hits


def buz_panel(var, t):
    aim, tips, hits = buz_times()
    F = ground_crop()
    U, Ov = Layer(), Layer()
    S = new_slimes()
    d = unit(tips[0], aim)
    ang = math.atan2(d[1], d[0])
    h1, h2, h3 = hits
    frozen = h2 <= t < h3
    dead = t >= h3
    # S1 yeniden doğar (döngü)
    if dead:
        S[0]["alpha"] = 0.0
        if t > BUZ_LOOP - 0.35:
            S[0]["alpha"] = B((t - (BUZ_LOOP - 0.35)) / 0.35)
    if frozen:
        S[0]["freeze"] = h2
    bc = body_c(0)
    shat = t - h3

    if var == "0":
        for f, tp in zip(BUZ_FIRE, tips):
            fl = flight(f, t, tp, aim, BUZ_SPEED)
            if fl:
                cur_projectile(F, "buz", 4, 12.0, 2, 12.0, -23.5, fl[1], ang, t - f)
        draw_scene(F, t, "buz_asasi", aim, BUZ_FIRE, S)
        for h in hits:
            cur_frames_dir(F, "assets/weapons/buz_asasi/impact", 5, t - h, 12.0, bc, 1.6)
        if frozen:
            age = t - h2
            fi = min(3, int(age / 0.45 * 4))
            if t > h3 - 0.0:
                fi = 3
            blit_world(F, strip("assets/generated/fx_freeze_variants.png", 27, fi), SL[0][0], SL[0][1] - 4, 1.1)
        if 0 <= shat < 0.5:
            cur_sheet(F, "assets/fx/enchant/crystal_burst_sheet.png", 7, shat, 14.0, bc, 100.0 / 24.0)
        if 0 <= shat < 0.4:
            q = shat / 0.4
            Ov.ring(bc[0], bc[1], 100 * (0.3 + 0.7 * q), 100 * (0.3 + 0.7 * q), 1, ICE[2], B(1 - q))
        composite(F, Ov)
        return F

    # ---- ortak: yavaşlatma / donma durumları
    slowed = [h1 <= t < h3, shat >= 0, shat >= 0]
    if var == "A":
        _buz_A(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat)
    elif var == "B":
        _buz_B(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat)
    else:
        _buz_C(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat)
    composite(F, U)
    draw_scene(F, t, "buz_asasi", aim, BUZ_FIRE, S)
    composite(F, Ov)
    return F


def _frost_spikes(L, i, t0, t, col_l=ICE[1], col_m=ICE[3], ol=ICE_OL):
    """A: tabanda kırağı dikenleri (yavaşlatma)."""
    x, y = SL[i]
    g = ease_out((t - t0) / 0.15)
    by = y + BODY_BOT - 0.5
    for j, (dx, hgt) in enumerate(((-9, 3), (-5, 5), (-1, 3), (3, 4), (7, 5), (10, 3))):
        hh = hgt * g
        if hh < 1.0:
            continue
        bx = x + 1 + dx
        L.shape([(0, -hh), (1.6, 0), (-1.6, 0)], 0.0, bx, by, tone2(col_l, col_m, -hh * 0.45), ol=ol)


def _buz_A(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat):
    aim = body_c(0)
    perp = (-d[1], d[0])
    shard = [(7, 0), (1, -2.6), (-6, 0), (1, 2.6)]
    for f, tp in zip(BUZ_FIRE, tips):
        age = t - f
        if 0 <= age < 0.16:  # namlu parıltısı
            r = 4.0 * math.sin(math.pi * age / 0.16)
            Ov.star4(tp[0], tp[1], r, WHITE, ICE[2])
        fl = flight(f, t, tp, aim, BUZ_SPEED)
        T_fl = dist(tp, aim) / BUZ_SPEED
        # kırağı tanecikleri (dünyada kalır, aşağı süzülür)
        k = 0
        while True:
            ts = f + k * 0.045
            if ts > t or ts > f + T_fl:
                break
            a = t - ts
            if a < 0.32:
                p0 = lerp(tp, aim, (ts - f) / T_fl)
                side = 2.0 if k % 2 else -2.0
                x = p0[0] - d[0] * 4 + perp[0] * side - 10 * a
                y = p0[1] - d[1] * 4 + perp[1] * side + 14 * a
                if a < 0.1:
                    Ov.star4(x, y, 1, ICE[1], ICE[2], 1.0)
                else:
                    Ov.px(x, y, ICE[2], B(1 - (a - 0.1) / 0.22, 3))
            k += 1
        if fl:
            u, p = fl
            for j, col in enumerate((WHITE, ICE[1], ICE[2], ICE[3])):  # 1 px iz çizgisi, 4 ton
                a0, a1 = 4 + j * 3, 7 + j * 3
                Ov.line(p[0] - d[0] * a0, p[1] - d[1] * a0, p[0] - d[0] * a1, p[1] - d[1] * a1, col, 1.0 - j * 0.2)
            Ov.shape(shard, ang, p[0], p[1], tone2(ICE[2], ICE[3]), ol=ICE_OL)
            Ov.line(p[0] - d[0] * 3, p[1] - d[1] * 3 - 1, p[0] + d[0] * 4, p[1] + d[1] * 4 - 1, WHITE, 1.0)
    # isabet: mermi 3 yüz parçasına bölünür
    for h in hits[:2]:
        a = t - h
        if 0 <= a < 0.25:
            for j, sp in enumerate((-0.9, 0.0, 0.9)):
                da = ang + math.pi + sp
                r = 3 + 50 * a
                cx, cy = aim[0] - d[0] * 6 + math.cos(da) * r, aim[1] - d[1] * 6 + math.sin(da) * r + 60 * a * a
                Ov.shape([(2.5, 0), (-1.5, -1.8), (-1.5, 1.8)], da + a * 12, cx, cy, tone2(ICE[1], ICE[3]), ol=ICE_OL, a=B(1 - a / 0.25))
            if a < 0.08:
                Ov.star4(aim[0] - d[0] * 7, aim[1] - d[1] * 7, 3, WHITE, ICE[1])
    # yavaşlatma: kırağı dikenleri
    if slowed[0] and not frozen:
        _frost_spikes(Ov, 0, hits[0], t)
    for i in (1, 2):
        if slowed[i] and shat < 1.3:
            _frost_spikes(Ov, i, hits[2] + 0.12, t)
    # donma: yüzlü buz bloğu (alttan büyür)
    x, y = SL[0]
    block = [(-12, -7), (-5, -15), (7, -14), (13, -5), (12, 8), (1, 12), (-11, 8)]
    if frozen:
        S[0]["tint"], S[0]["tint_a"] = ICE[3], 0.3
        g = ease_out((t - hits[1]) / 0.16)
        cx, cy = x + 1, y + BODY_DY
        top = cy + 12 - 27 * g

        def shade(LX, LY):
            out = np.empty(LX.shape + (3,), f32)
            out[:] = np.array(ICE[3], f32)
            out[LY < -6] = np.array(ICE[2], f32)
            out[(LX < -4) & (LY >= -6)] = np.array(ICE[2], f32)
            return out
        pts = [(px_, max(py_, top - cy)) for px_, py_ in block]
        Ov.shape(pts, 0.0, cx, cy, shade, ol=ICE_OL, a=0.55)
        if g >= 1.0:
            Ov.line(cx - 8, cy - 7, cx - 3, cy - 12, WHITE, 0.9)
            Ov.line(cx + 6, cy + 1, cx + 9, cy - 2, WHITE, 0.6)
            tw = 0.5 + 0.5 * math.sin(t * 9.0)
            Ov.star4(cx + 8, cy - 10, 2 if tw > 0.5 else 1, WHITE, ICE[1])
    # parçalanma: blok bütün parçalar halinde saçılır + yerde buz dalgası
    if 0 <= shat < 0.6:
        cx, cy = x + 1, y + BODY_DY
        n = len(block)
        pieces = []
        for j in range(n):  # her yüz iki parçaya: blok BÜTÜN parçalara bölünür (piksel saçılması değil)
            p1, p2 = block[j], block[(j + 1) % n]
            pm = ((p1[0] + p2[0]) / 2.0, (p1[1] + p2[1]) / 2.0)
            pieces += [[(0, 0), p1, pm], [(0, 0), pm, p2]]
        for j, pc in enumerate(pieces):
            ctr = (sum(q[0] for q in pc) / 3.0, sum(q[1] for q in pc) / 3.0)
            dl = math.hypot(ctr[0], ctr[1]) or 1.0
            sp = 70 + (j % 3) * 18
            vx, vy = ctr[0] / dl * sp, ctr[1] / dl * sp * 0.7 - 40
            ox, oy = vx * shat, vy * shat + 230 * shat * shat
            loc = [((q[0] - ctr[0]) * 0.62, (q[1] - ctr[1]) * 0.62) for q in pc]
            Ov.shape(loc, shat * (6 if j % 2 else -6), cx + ctr[0] + ox, cy + ctr[1] + oy, tone2(ICE[2], ICE[3]), ol=ICE_OL,
                     a=B(1 - shat / 0.6))
        if shat < 0.1:
            Ov.disc(cx, cy, 10 - 40 * shat, WHITE, 0.9)
    if 0 <= shat < 0.5:
        q = ease_out(shat / 0.45)
        r = 100 * (0.25 + 0.75 * q)
        cx, cy = x + 1, y + BODY_BOT
        U.ell(cx, cy, r, r * 0.55, ICE[1], B(0.16 * (1 - shat / 0.5)))
        U.ring(cx, cy, r, r * 0.55, 2, ICE[1], B(1 - shat / 0.5))
        U.ring(cx, cy, r * 0.75, r * 0.55 * 0.75, 1, WHITE, B(0.6 * (1 - shat / 0.5)))


def _snowflake(L, cx, cy, r, ang, arm=ICE[1], tip=ICE[2], core=WHITE, a=1.0):
    for j in range(6):
        aa = ang + j * TAU / 6
        ex, ey = cx + math.cos(aa) * r, cy + math.sin(aa) * r
        L.line(cx, cy, ex, ey, arm, a)
        if r >= 4:
            bx, by = cx + math.cos(aa) * r * 0.6, cy + math.sin(aa) * r * 0.6
            for sg in (-1, 1):
                ba = aa + sg * 0.9
                L.line(bx, by, bx + math.cos(ba) * r * 0.35, by + math.sin(ba) * r * 0.35, tip, a)
        L.px(ex, ey, tip, a)
    L.rect(cx - 0.5, cy - 0.5, 2, 2, core, a) if r >= 3 else L.px(cx, cy, core, a)


def _buz_B(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat):
    aim = body_c(0)
    for f, tp in zip(BUZ_FIRE, tips):
        age = t - f
        if 0 <= age < 0.2:
            q = age / 0.2
            Ov.disc(tp[0], tp[1], 2 + 4 * q, ICE[1], B(0.55 * (1 - q), 3))
        T_fl = dist(tp, aim) / BUZ_SPEED
        k = 0
        while True:
            ts = f + k * 0.05
            if ts > t or ts > f + T_fl:
                break
            a = t - ts
            if a < 0.45:
                p0 = lerp(tp, aim, (ts - f) / T_fl)
                x = p0[0] - 12 * a + math.sin(a * 10 + k) * 2.0
                y = p0[1] + 10 * a + (k % 3 - 1) * 2
                if a < 0.15:  # minik kar tanesi: + ile x yer değiştirir (pırıl pırıl, nokta gürültüsü değil)
                    if (k + int(a / 0.05)) % 2:
                        Ov.star4(x, y, 1, WHITE, WHITE, 1.0)
                    else:
                        Ov.line(x - 1, y - 1, x + 1, y + 1, WHITE, 1.0)
                        Ov.line(x - 1, y + 1, x + 1, y - 1, WHITE, 1.0)
                elif a < 0.3:
                    Ov.star4(x, y, 1, ICE[1], ICE[1], 0.75)
                else:
                    Ov.px(x, y, ICE[2], 0.5)
            k += 1
        fl = flight(f, t, tp, aim, BUZ_SPEED)
        if fl:
            p = fl[1]
            Ov.disc(p[0], p[1], 7.5, ICE[2], 0.3)
            Ov.disc(p[0], p[1], 5.0, ICE[1], 0.5)
            _snowflake(Ov, p[0], p[1], 5, age * 9.0)
    for h in hits[:2]:
        a = t - h
        if 0 <= a < 0.4:
            g = ease_out(a / 0.12)
            fade = B(1 - max(0.0, a - 0.12) / 0.28)
            Ov.disc(aim[0], aim[1], 6 + 7 * a / 0.4, ICE[1], B(0.45 * (1 - a / 0.4), 3))
            _snowflake(Ov, aim[0], aim[1], 4 + 9 * g, 0.3, a=fade)
    # yavaşlatma: başın üstünde dönen kar tanesi
    for i in range(3):
        if slowed[i] and not (i == 0 and frozen) and not (i > 0 and shat > 1.3):
            x, y = SL[i]
            ph = t * 3.0 + i
            cx, cy = x + 1 + math.cos(ph) * 8, y + BODY_TOP - 5 + math.sin(ph) * 2.5
            _snowflake(Ov, cx, cy, 3, t * 4, a=1.0)
    if frozen:
        x, y = SL[0]
        S[0]["tint"], S[0]["tint_a"] = ICE[1], 0.5
        g = ease_out((t - hits[1]) / 0.2)
        cx, cy = x + 1, y + BODY_DY
        br = 0.5 + 0.5 * math.sin(t * 5.0)
        Ov.ring(cx, cy + 1, 14 + br, 13 + br, 2, ICE[1], B(0.45 * g, 3))
        Ov.ell(cx, y + BODY_TOP + 3.5, 8.5 * g, 3.0 * g, ICE[2], 1.0)
        Ov.ell(cx, y + BODY_TOP + 2.5, 8.0 * g, 2.6 * g, WHITE, 1.0)
        for j in range(3):
            ph = t * 1.4 + j * TAU / 3
            _snowflake(Ov, cx + math.cos(ph) * 13, cy + math.sin(ph) * 5, 2, t, a=1.0)
    if 0 <= shat < 0.7:
        x, y = SL[0]
        cx, cy = x + 1, y + BODY_DY
        q = shat / 0.7
        g = ease_out(shat / 0.35)
        sh = 1 - 0.55 * max(0.0, (shat - 0.3) / 0.4)  # sis önce kabarır, sonra küçülerek söner (şekil değişimi)
        circ = [(cx + ox * (1 + g), cy + oy * (1 + g) - 4 * g, r0 * (1 + 0.8 * g) * sh)
                for (ox, oy, r0) in ((0, 0, 7), (-8, 2, 6), (8, 1, 6), (-3, -7, 6), (5, -6, 5), (-11, -3, 5), (11, -4, 5))]
        Ov.cloud(circ, (ICE[2], ICE[1], WHITE), (B(0.35 * (1 - q)), B(0.5 * (1 - q)), B(0.6 * (1 - q))))
        for j in range(8):
            aa = j * TAU / 8 + 0.2
            r = 10 + 55 * ease_out(shat / 0.5)
            _snowflake(Ov, cx + math.cos(aa) * r, cy + math.sin(aa) * r * 0.7, 3, shat * 8 + j, a=B(1 - q))
        rr = 100 * (0.3 + 0.7 * ease_out(shat / 0.5))
        U.ring(x + 1, y + BODY_BOT, rr, rr * 0.55, 2, ICE[1], B(0.7 * (1 - q), 3))
        U.ring(x + 1, y + BODY_BOT, rr * 0.8, rr * 0.55 * 0.8, 1, WHITE, B(0.4 * (1 - q), 2))


ICICLE = [(8, 0), (-5, -3.4), (-6.5, -1.6), (-6.5, 1.6), (-5, 3.4)]


def _icicle(L, cx, cy, ang, a=1.0, s=1.0):
    def shade(LX, LY):
        out = np.empty(LX.shape + (3,), f32)
        out[:] = np.array(ICE_C[2], f32)
        out[LY < 0.2] = np.array(ICE_C[1], f32)
        out[(LY < -0.8) & (LX > -4) & (LX < -1)] = np.array(ICE_C[0], f32)
        return out
    L.shape(ICICLE, ang, cx, cy, shade, ol=ICE_C_OL, olk=2, a=a, sx=s, sy=s)


def _pow(L, cx, cy, r, a=1.0, fill=WHITE, ol=ICE_C_OL):
    pts = []
    for j in range(8):
        aa = j * TAU / 8 + 0.2
        rr = r if j % 2 == 0 else r * 0.4
        pts.append((math.cos(aa) * rr, math.sin(aa) * rr))
    L.shape(pts, 0.0, cx, cy, lambda LX, LY: np.broadcast_to(np.array(fill, f32), LX.shape + (3,)).copy(), ol=ol, olk=2, a=a)


def _buz_C(t, U, Ov, S, tips, hits, ang, d, slowed, frozen, shat):
    aim = body_c(0)
    perp = (-d[1], d[0])
    for f, tp in zip(BUZ_FIRE, tips):
        age = t - f
        if 0 <= age < 0.12:
            _pow(Ov, tp[0], tp[1], 5 * math.sin(math.pi * age / 0.12))
        fl = flight(f, t, tp, aim, BUZ_SPEED)
        if fl:
            p = fl[1]
            for sg in (-1, 1):  # çizgi film hız çizgileri
                bx, by = p[0] - d[0] * 10 + perp[0] * 3 * sg, p[1] - d[1] * 10 + perp[1] * 3 * sg
                Ov.line(bx, by, bx - d[0] * 7, by - d[1] * 7, WHITE, 0.85)
            Ov.line(p[0] - d[0] * 9, p[1] - d[1] * 9, p[0] - d[0] * 18, p[1] - d[1] * 18, ICE_C[1], 0.6)
            _icicle(Ov, p[0], p[1], ang + 0.12 * math.sin(age * 30))
    # saplanan sarkıtlar (vuruş noktası: gövdenin atıcıya bakan kenarı)
    stuck = []
    for j, h in enumerate(hits[:2]):
        if h <= t and not (t >= hits[2]):
            stuck.append((j, h))
    for j, h in stuck:
        a = t - h
        off = (-3.0, 3.5)[j]
        da = (0.0, 0.3)[j]
        cx = aim[0] - d[0] * 5 + perp[0] * off
        cy = aim[1] - d[1] * 5 + perp[1] * off
        jig = 1.5 * math.sin(a * 40) * max(0.0, 1 - a / 0.2)
        _icicle(Ov, cx - d[0] * jig, cy - d[1] * jig, ang + da, s=0.75)
        if a < 0.14:
            _pow(Ov, aim[0] - d[0] * 7, aim[1] - d[1] * 7, 7 * math.sin(math.pi * a / 0.14))
    if frozen:
        x, y = SL[0]
        S[0]["tint"], S[0]["tint_a"] = ICE_C[2], 0.3
        g = ease_out((t - hits[1]) / 0.12)
        sc = 1.0 + 0.15 * math.sin(math.pi * min(1.0, (t - hits[1]) / 0.25))
        cx, cy = x + 1, y + BODY_DY + 1
        hw, hh = 12 * sc, 13 * sc * g

        def shade(LX, LY):
            out = np.empty(LX.shape + (3,), f32)
            out[:] = np.array(ICE_C[2], f32)
            out[(LX + LY) < -4] = np.array(ICE_C[1], f32)
            return out
        if hh > 1:
            box = [(-hw + 3, -hh), (hw - 3, -hh), (hw, -hh + 3), (hw, hh - 3), (hw - 3, hh), (-hw + 3, hh), (-hw, hh - 3), (-hw, -hh + 3)]
            Ov.shape(box, 0.0, cx, cy + (1 - g) * 12, shade, ol=ICE_C_OL, olk=2, a=0.6)
            if g >= 1:
                Ov.line(cx - 8, cy - 5, cx - 4, cy - 9, WHITE, 1.0, 2)
                Ov.px(cx - 2, cy - 10, WHITE)
        # sarkıtlar kütlenin üstünde
        for j, h in stuck:
            off = (-3.0, 3.5)[j]
            _icicle(Ov, aim[0] - d[0] * 5 + perp[0] * off, aim[1] - d[1] * 5 + perp[1] * off, ang + (0.0, 0.3)[j], s=0.75)
    # parçalanma: sarkıtlar yıldız gibi dışa fırlar; ikisi komşulara saplanır
    if shat >= 0:
        x, y = SL[0]
        c0 = (x + 1, y + BODY_DY)
        if shat < 0.16:
            _pow(Ov, c0[0], c0[1], 15 * math.sin(math.pi * shat / 0.16))
        targets = [body_c(1), body_c(2)]
        for j in range(8):
            aa = j * TAU / 8 + 0.25
            if shat < 0.45:
                r = 6 + 60 * ease_out(shat / 0.3)
                Ov_a = B(1 - max(0.0, shat - 0.25) / 0.2)
                _icicle(Ov, c0[0] + math.cos(aa) * r, c0[1] + math.sin(aa) * r * 0.8, aa, a=Ov_a, s=0.8)
        for k2, tg in enumerate(targets):
            dd = unit(c0, tg)
            aa = math.atan2(dd[1], dd[0])
            T2 = dist(c0, tg) / 260.0
            if shat < T2:
                p = lerp(c0, tg, shat / T2)
                _icicle(Ov, p[0], p[1], aa, s=0.8)
            elif shat < 1.3:
                p = (tg[0] - dd[0] * 5, tg[1] - dd[1] * 5)
                _icicle(Ov, p[0], p[1], aa, s=0.8)
                if shat - T2 < 0.12:
                    _pow(Ov, tg[0] - dd[0] * 7, tg[1] - dd[1] * 7, 6 * math.sin(math.pi * (shat - T2) / 0.12))
                    S[k2 + 1]["flash"] = 0.6


# ================================================================== ARCANE ASASI
ARC_FIRE = [0.10, 1.80]
ARC_SPEED = 400.0
ARC_LOOP = 3.4
ECHO_DELAY = 0.8
ECHO_R = 45.0


def arc_times():
    aim = body_c(0)
    tips = [tip_at("arcane", f, aim, ARC_FIRE) for f in ARC_FIRE]
    hits = [f + dist(tp, aim) / ARC_SPEED for f, tp in zip(ARC_FIRE, tips)]
    return aim, tips, hits


def arc_panel(var, t):
    aim, tips, hits = arc_times()
    F = ground_crop()
    U, Ov = Layer(), Layer()
    S = new_slimes()
    d = unit(tips[0], aim)
    ang = math.atan2(d[1], d[0])
    echo_age = t - hits[0]  # 0..0.8 yankı sayacı, 0.8 = patlama
    pop = echo_age - ECHO_DELAY
    # patlamaya yakalananlar (S1, S2 - S3 de 45 içinde) beyaz parlar
    if 0 <= pop < 0.12:
        for i in range(3):
            if dist(body_c(i), body_c(0)) <= ECHO_R:
                S[i]["flash"] = 0.7 * (1 - pop / 0.12)
    for h in hits:
        if 0 <= t - h < 0.08:
            S[0]["flash"] = 0.5
    if var == "0":
        for f, tp in zip(ARC_FIRE, tips):
            fl = flight(f, t, tp, aim, ARC_SPEED)
            if fl:
                cur_projectile(F, "arcane", 4, 14.0, 4, 14.0, -23.5, fl[1], ang, t - f)
        draw_scene(F, t, "arcane", aim, ARC_FIRE, S)
        for h in hits:
            cur_frames_dir(F, "assets/fx/hit_effects/purple_burst", 27, t - h, 30.0, aim, 0.84)
        if 0 <= echo_age < ECHO_DELAY:  # EnchantFx "ring": 33,75 yarıçap, 0,8 sn
            q = echo_age / ECHO_DELAY
            Ov.ring(aim[0], aim[1], ECHO_R * 0.75 * (0.4 + 0.6 * q), ECHO_R * 0.75 * (0.4 + 0.6 * q), 1, (224, 140, 255), B(1 - q, 3))
        if 0 <= pop < 0.8:  # blast = Korsan küçük patlaması (12 kare 124 px), ECHO_COLOR x1,6 modulate, ölçek TEXEL x 45/68
            i = int(pop * 15.0)
            if i < 12:
                fr = strip("assets/fx/korsan/explosion_small_sheet.png", 12, i).copy()
                fr[..., :3] = np.clip(fr[..., :3] * np.array([0.88 * 1.6, 0.55 * 1.6, 1.0 * 1.6], f32), 0, 255)
                blit_world(F, fr, aim[0], aim[1], 1.212 * ECHO_R / 68.0)
        composite(F, Ov)
        return F
    fn = {"A": _arc_A, "B": _arc_B, "C": _arc_C}[var]
    fn(t, U, Ov, S, tips, hits, ang, d, echo_age, pop)
    composite(F, U)
    draw_scene(F, t, "arcane", aim, ARC_FIRE, S)
    composite(F, Ov)
    return F


def _orb_A(L, cx, cy, t):
    L.disc(cx, cy, 4.5, ARC[4])
    L.disc(cx, cy, 3.6, ARC[2])
    L.disc(cx - 0.5, cy - 0.5, 2.4, ARC[1])
    L.rect(cx - 1.5, cy - 1.5, 2, 2, ARC[0])
    for j in range(2):
        aa = t * 14.0 + j * math.pi
        L.rect(cx + math.cos(aa) * 7 - 1, cy + math.sin(aa) * 4.5 - 1, 2, 2, ARC[0])


GLYPHS = [["#.#", ".#.", "#.#"], [".#.", "#.#", ".#."], ["###", ".#.", ".#."], ["#..", "###", "..#"]]


def _glyph(L, cx, cy, g, col=ARC[1], ol=ARC[4], a=1.0):
    rows = GLYPHS[g]
    for yy, r in enumerate(rows):
        for xx, ch in enumerate(r):
            if ch == "#":
                L.px(cx - 1 + xx, cy - 1 + yy, col, a)


def _arc_A(t, U, Ov, S, tips, hits, ang, d, echo_age, pop):
    aim = body_c(0)
    perp = (-d[1], d[0])
    for f, tp in zip(ARC_FIRE, tips):
        age = t - f
        if 0 <= age < 0.2:
            q = age / 0.2
            Ov.ring(tp[0], tp[1], 3 + 3 * q, 3 + 3 * q, 1, ARC[1], B(1 - q, 3))
            for j in range(4):
                aa = j * TAU / 4 + q
                Ov.px(tp[0] + math.cos(aa) * (6 + 3 * q), tp[1] + math.sin(aa) * (6 + 3 * q), ARC[0], B(1 - q, 3))
        fl = flight(f, t, tp, aim, ARC_SPEED)
        if fl:
            p = fl[1]
            trav = dist(tp, p)
            for s in range(3, int(min(30, trav))):  # sarmal iz: iki ince iplik (önde/arkada ton değişir)
                ph = s * 0.42 - age * 25.0
                w = math.sin(ph) * 3.0
                a = B(1.15 - s / 30.0, 3)
                bx, by = p[0] - d[0] * s, p[1] - d[1] * s
                front = math.cos(ph) > 0
                Ov.px(bx + perp[0] * w, by + perp[1] * w, ARC[1] if front else ARC_SAT, a)
                Ov.px(bx - perp[0] * w, by - perp[1] * w, ARC_SAT if front else ARC[1], a)
            _orb_A(Ov, p[0], p[1], age)
    for h in hits:
        a = t - h
        if 0 <= a < 0.25:
            q = a / 0.25
            Ov.ring(aim[0], aim[1], 4 + 6 * q, 4 + 6 * q, 1, ARC[1], B(1 - q, 3))
            for j in range(4):
                aa = j * TAU / 4 + 0.785
                r0 = 3 + 22 * q
                Ov.line(aim[0] + math.cos(aa) * r0, aim[1] + math.sin(aa) * r0, aim[0] + math.cos(aa) * (r0 + 4),
                        aim[1] + math.sin(aa) * (r0 + 4), ARC[0], B(1 - q, 3))
    # YANKI: yerde kendini saat gibi çizen rün dairesi
    x, y = SL[0]
    gx, gy = x + 1, y + BODY_BOT
    rx, ry = ECHO_R, ECHO_R * 0.55
    ## büyük yarı saydam mor dolgu YOK: mor + çimen yeşili tamamlayıcı -> griye döner (ilk denemede oldu). Yalnız opak çizgi/rün.
    if 0 <= echo_age < ECHO_DELAY:
        p = echo_age / ECHO_DELAY
        U.ring(gx, gy, rx, ry, 1, ARC[4], 0.35)  # silik kılavuz (sayaç nereye kadar dolacak)
        U.arc(gx, gy, rx, ry, -90, -90 + 360 * p, 2, ARC_SAT, 1.0)
        U.arc(gx, gy, rx - 1, ry - 1, -90, -90 + 360 * p, 1, ARC[1], 1.0)
        ha = (-90 + 360 * p) * D2R
        U.rect(gx + math.cos(ha) * rx - 1, gy + math.sin(ha) * ry - 1, 3, 3, WHITE)
        if p > 0.3:
            U.ring(gx, gy, rx * 0.62, ry * 0.62, 1, ARC_SAT, B((p - 0.3) / 0.3, 3))
        for j in range(4):
            if p >= j / 4.0:
                aa = (-90 + j * 90) * D2R
                gxx, gyy = gx + math.cos(aa) * rx * 0.81, gy + math.sin(aa) * ry * 0.81
                U.disc(gxx, gyy, 3.0, ARC[4], B((p - j / 4.0) / 0.1, 3))
                _glyph(U, gxx, gyy, j, col=ARC[0], a=B((p - j / 4.0) / 0.1, 3))
        if p > 0.78:  # hayalet küre yukarıdan düşer
            q = (p - 0.78) / 0.22
            _orb_A(Ov, gx, gy - 45 + 45 * q * q - 8, t)
    if 0 <= pop < 0.4:
        q = pop / 0.4
        e = ease_out(pop / 0.12)
        U.ring(gx, gy, rx + 5 * e, ry + 2.8 * e, 2, WHITE if pop < 0.1 else ARC[1], B(1 - q, 3))
        U.ring(gx, gy, rx * 0.62 * (1 - 0.6 * e), ry * 0.62 * (1 - 0.6 * e), 1, ARC_SAT, B(1 - q, 3))
        for j in range(8):
            aa = j * TAU / 8 + 0.39
            r0 = 8 + 38 * e
            Ov.line(gx + math.cos(aa) * r0, gy + math.sin(aa) * r0 * 0.55 - 6, gx + math.cos(aa) * (r0 + 8),
                    gy + math.sin(aa) * (r0 + 8) * 0.55 - 6, ARC[0] if j % 2 else ARC_SAT, B(1 - q, 3), 2 if pop < 0.12 else 1)
        if pop < 0.2:  # yukarı fışkıran ışık sütunu (kısa)
            h = 26 * ease_out(pop / 0.08) * (1 - pop / 0.2)
            Ov.rect(gx - 2, gy - 8 - h, 5, h, ARC_SAT, 0.9)
            Ov.rect(gx - 1, gy - 8 - h, 3, h, WHITE, 1.0)
        Ov.disc(gx, gy - 8, 7 * (1 - q), WHITE, B(1 - q, 3))
        Ov.ring(gx, gy - 8, 9 * (1 - q) + 1, 9 * (1 - q) + 1, 1, ARC_SAT, B(1 - q, 3))


def _star(L, cx, cy, r, ang, a=1.0, core=WHITE, arm=ARC[1], tip=ARC[2]):
    r = max(0.0, r)
    if r < 1:
        L.px(cx, cy, core, a)
        return
    for j in range(4):
        aa = ang + j * TAU / 4
        L.line(cx, cy, cx + math.cos(aa) * r, cy + math.sin(aa) * r, arm, a)
        L.px(cx + math.cos(aa) * r, cy + math.sin(aa) * r, tip, a)
    if r >= 3:
        L.disc(cx, cy, 1.6, core, a)
    else:
        L.px(cx, cy, core, a)


def _arc_B(t, U, Ov, S, tips, hits, ang, d, echo_age, pop):
    aim = body_c(0)
    perp = (-d[1], d[0])
    for f, tp in zip(ARC_FIRE, tips):
        age = t - f
        if 0 <= age < 0.18:
            _star(Ov, tp[0], tp[1], 5 * math.sin(math.pi * age / 0.18), 0.0)
        T_fl = dist(tp, aim) / ARC_SPEED
        k = 0
        while True:
            ts = f + k * 0.055
            if ts > t or ts > f + T_fl:
                break
            a = t - ts
            if a < 0.4:
                p0 = lerp(tp, aim, (ts - f) / T_fl)
                off = ((k * 37) % 7 - 3) * 1.0
                _star(Ov, p0[0] - d[0] * 3 + perp[0] * off, p0[1] - d[1] * 3 + perp[1] * off, 3.2 * math.sin(math.pi * a / 0.4), 0.0,
                      core=ARC[0], arm=ARC[2], tip=ARC[3])
            k += 1
        fl = flight(f, t, tp, aim, ARC_SPEED)
        if fl:
            p = fl[1]
            Ov.disc(p[0], p[1], 5.5, ARC_GLOW, 0.5)
            Ov.disc(p[0], p[1], 3.5, ARC[0], 0.75)
            _star(Ov, p[0], p[1], 6, age * 3.0)
    for h in hits:
        a = t - h
        if 0 <= a < 0.3:
            q = a / 0.3
            Ov.ring(aim[0], aim[1], 4 + 6 * q, 4 + 6 * q, 1, ARC_GLOW, B(1 - q, 3))
            for j in range(4):
                aa = j * TAU / 4 + 0.785
                r = 4 + 16 * ease_out(q)
                _star(Ov, aim[0] + math.cos(aa) * r, aim[1] + math.sin(aa) * r, 3 * (1 - q), 0.0, core=ARC[0], arm=ARC[2], tip=ARC[3])
    x, y = SL[0]
    hc = (x + 1, y + BODY_DY - 16)
    if 0 <= echo_age < ECHO_DELAY:
        p = echo_age / ECHO_DELAY
        g = ease_out(p / 0.15)
        col = 1.0 if p < 0.88 else max(0.0, 1 - (p - 0.88) / 0.12)
        br = 1 + 0.3 * math.sin(TAU * 2 * p)
        Ov.disc(hc[0], hc[1], 6.5 * br * g * col, ARC_GLOW, 0.45)
        Ov.disc(hc[0], hc[1], 4.0 * br * g * col, ARC[0], 0.7)
        _star(Ov, hc[0], hc[1], 8 * br * g * col, 0.785 * p, a=0.9)
        for j in range(6):
            rr = 26 * (1 - p)
            aa = j * TAU / 6 + p * 3.0
            if rr > 2:
                _star(Ov, hc[0] + math.cos(aa) * rr, hc[1] + math.sin(aa) * rr * 0.8, 2, 0.0, core=ARC[0], arm=ARC[2], tip=ARC[3])
        U.ring(x + 1, y + BODY_BOT, ECHO_R, ECHO_R * 0.55, 1, ARC_GLOW, B(0.25 + 0.5 * p, 4))
    if 0 <= pop < 0.45:
        q = pop / 0.45
        e = ease_out(pop / 0.1)
        fade = B(1 - q, 3)
        c = (hc[0], hc[1] + 8)
        if pop < 0.18:  # küçük beyaz çekirdek parlaması (büyük mor dolgu yok: çimende griye döner)
            Ov.disc(c[0], c[1], 10 * e * (1 - pop / 0.18), ARC_GLOW, 0.55)
            Ov.disc(c[0], c[1], 6 * e * (1 - pop / 0.18), WHITE, 0.9)
        Ov.ring(c[0], c[1], ECHO_R * 0.85 * ease_out(q * 1.6), ECHO_R * 0.7 * ease_out(q * 1.6), 1, ARC[0], fade)
        Ov.ring(c[0], c[1], ECHO_R * 0.6 * ease_out(q * 1.6), ECHO_R * 0.5 * ease_out(q * 1.6), 1, ARC_GLOW, fade * 0.8)
        for j in range(10):
            aa = j * TAU / 10
            r = 8 + 40 * ease_out(q * 1.4)
            _star(Ov, c[0] + math.cos(aa) * r, c[1] + math.sin(aa) * r * 0.8, (4.0 if j % 2 else 2.5) * (1 - q), 0.0)
        U.ring(x + 1, y + BODY_BOT, ECHO_R, ECHO_R * 0.55, 1, ARC_GLOW, fade * 0.8)


def _jag(L, x0, y0, x1, y1, seed, amp, n, col, a=1.0, w=1):
    pts = []
    for i in range(n + 1):
        u = i / n
        off = 0.0 if i in (0, n) else ((((seed * 31 + i * 17) % 7) - 3) / 3.0) * amp
        nx, ny = -(y1 - y0), (x1 - x0)
        nl = math.hypot(nx, ny) or 1.0
        pts.append((x0 + (x1 - x0) * u + nx / nl * off, y0 + (y1 - y0) * u + ny / nl * off))
    for i in range(n):
        L.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], col, a, w)


def _orb_C(L, cx, cy, t):
    L.disc(cx, cy, 5.0, VOID[1])
    L.disc(cx, cy, 4.0, VOID[2])
    L.disc(cx + 0.5, cy + 0.5, 2.5, VOID[3])
    L.px(cx - 3, cy - 3, VOID[0])
    st = int(t / 0.06)
    for j in range(3):
        aa = ((st * 7 + j * 13) % 12) / 12.0 * TAU
        _jag(L, cx + math.cos(aa) * 5, cy + math.sin(aa) * 5, cx + math.cos(aa) * 9, cy + math.sin(aa) * 9, st + j, 1.0, 2, VOID[1], 0.9)


def _arc_C(t, U, Ov, S, tips, hits, ang, d, echo_age, pop):
    aim = body_c(0)
    for f, tp in zip(ARC_FIRE, tips):
        age = t - f
        if 0 <= age < 0.15:
            q = age / 0.15
            Ov.disc(tp[0], tp[1], 3 * (1 - q) + 1, VOID[3], 0.9)
            Ov.ring(tp[0], tp[1], 4 + 3 * q, 4 + 3 * q, 1, VOID[1], B(1 - q, 3))
        fl = flight(f, t, tp, aim, ARC_SPEED)
        if fl:
            p = fl[1]
            st = int(age / 0.05)
            trav = dist(tp, p)
            L = min(26.0, trav - 4)
            if L > 4:
                for seg in range(3):  # kopuk yırtık iz: 3 parça, kuyruğa doğru söner
                    s0, s1 = 5 + seg * L / 3, 5 + (seg + 1) * L / 3 - 2
                    a = B(1 - seg / 3.0, 3)
                    x0, y0 = p[0] - d[0] * s0, p[1] - d[1] * s0
                    x1, y1 = p[0] - d[0] * s1, p[1] - d[1] * s1
                    _jag(Ov, x0, y0, x1, y1, st + seg, 1.8, 3, VOID[2], a, 2)
                    _jag(Ov, x0, y0 - 1, x1, y1 - 1, st + seg, 1.8, 3, VOID[1], a)
            _orb_C(Ov, p[0], p[1], age)
    for h in hits:
        a = t - h
        if 0 <= a < 0.22:
            q = a / 0.22
            for j in range(5):
                aa = j * TAU / 5 + 0.3
                _jag(Ov, aim[0], aim[1], aim[0] + math.cos(aa) * (5 + 4 * q), aim[1] + math.sin(aa) * (5 + 4 * q), j, 1.0, 2, VOID[1],
                     B(1 - q, 3))
            Ov.ring(aim[0], aim[1], 3 + 6 * q, 3 + 6 * q, 1, VOID[0], B(1 - q, 3))
    x, y = SL[0]
    rc = (x + 1, y + BODY_DY - 2)

    def rift(L, h, w, rim=VOID[1], a=1.0):
        if h < 2:
            return
        pts = [(math.sin(math.pi * (i / 12.0)) * w * (1 if s > 0 else -1), (i / 12.0 - 0.5) * h)
               for s in (1, -1) for i in (range(13) if s > 0 else range(12, -1, -1))]
        L.shape(pts, 0.0, rc[0], rc[1], lambda LX, LY: np.where((np.abs(LX) < 1.2)[..., None], np.array(VOID[2], f32),
                                                               np.array(VOID[3], f32)), ol=rim, a=a)
        L.px(rc[0], rc[1] - h / 2 - 1, VOID[0], a)
        L.px(rc[0], rc[1] + h / 2, VOID[0], a)

    if 0 <= echo_age < ECHO_DELAY:
        p = echo_age / ECHO_DELAY
        g = ease_out(p / 0.5)
        h = 28 * g
        w = 3.5 * g + 0.6 * math.sin(t * 20) * g
        for j in range(6):  # karanlık çekilir
            ph = ((t * 2.5 + j / 6.0) % 1.0)
            r = 32 * (1 - ph)
            aa = j * TAU / 6 + 0.4
            if r > 6:
                bx, by = rc[0] + math.cos(aa) * r, rc[1] + math.sin(aa) * r * 0.8
                Ov.line(bx, by, bx - math.cos(aa) * 3, by - math.sin(aa) * 3 * 0.8, VOID[2], B(g * 0.9, 3), 2)
                Ov.px(bx - math.cos(aa) * 3, by - math.sin(aa) * 3 * 0.8, VOID[1], B(g, 3))
        rift(Ov, h, w)
        st = int(t / 0.07)
        _jag(Ov, rc[0], rc[1] - h / 2, rc[0] + 3, rc[1] - h / 2 - 5 * g, st, 1.0, 2, VOID[1], g)
        _jag(Ov, rc[0], rc[1] + h / 2, rc[0] - 3, rc[1] + h / 2 + 5 * g, st + 3, 1.0, 2, VOID[1], g)
    if 0 <= pop < 0.4:
        q = pop / 0.4
        if pop < 0.15:
            rift(Ov, 28 * (1 - pop / 0.15), 5 * (1 - pop / 0.15), rim=VOID[0])
            Ov.disc(rc[0], rc[1], 10 * (1 - pop / 0.15), VOID[3], 0.7)
        r = 6 + (ECHO_R - 6) * ease_out(q * 1.3)
        for j in range(6):
            a0 = j * 60 + 10 + q * 30
            Ov.arc(rc[0], rc[1] + 4, r, r * 0.75, a0, a0 + 40, 2, VOID[1], B(1 - q, 3))
            Ov.arc(rc[0], rc[1] + 4, r - 2, (r - 2) * 0.75, a0 + 5, a0 + 35, 1, VOID[0], B(1 - q, 3))


# ================================================================== ZEHİR ASASI
ZEH_FIRE = [0.10, 1.80]
ZEH_SPEED = 460.0
ZEH_LOOP = 3.4
LEAP_T = 0.28


def zeh_times():
    aim = body_c(0)
    tips = [tip_at("tuftuf", f, aim, ZEH_FIRE) for f in ZEH_FIRE]
    hits = [f + dist(tp, aim) / ZEH_SPEED for f, tp in zip(ZEH_FIRE, tips)]
    return aim, tips, hits


def zeh_panel(var, t):
    aim, tips, hits = zeh_times()
    F = ground_crop()
    U, Ov = Layer(), Layer()
    S = new_slimes()
    d = unit(tips[0], aim)
    ang = math.atan2(d[1], d[0])
    death = t - hits[1]  # 2. isabet öldürür
    leap = death - 0.05  # damla cesetten kalkar
    land = leap - LEAP_T
    stacks = [2 + (1 if t >= hits[0] else 0) if death < 0 else 0, 1 if land >= 0 else 0, 0]
    if death >= 0:
        S[0]["alpha"] = 0.0 if death > 0.12 else 1.0
        if t > ZEH_LOOP - 0.35:
            S[0]["alpha"] = B((t - (ZEH_LOOP - 0.35)) / 0.35)
            stacks[0] = 0
    for h in hits:
        if 0 <= t - h < 0.07:
            S[0]["flash"] = 0.5
    if 0 <= land < 0.07:
        S[1]["flash"] = 0.5
    if var == "0":
        for f, tp in zip(ZEH_FIRE, tips):
            fl = flight(f, t, tp, aim, ZEH_SPEED)
            if fl:
                cur_projectile(F, "zehir", 1, 1.0, 0, 1.0, 0.0, fl[1], ang, t - f)
        draw_scene(F, t, "tuftuf", aim, ZEH_FIRE, S)
        regs = tres_regions("assets/fx/poison/poison_status_frames.tres")
        sheet = tex("assets/fx/poison/poison_status_sheet.png")
        for i in range(2):
            if stacks[i] > 0 and S[i]["alpha"] > 0:
                rx, ry, rw, rh = regs[int(t * 10) % len(regs)]
                blit_world(F, sheet[ry:ry + rh, rx:rx + rw], SL[i][0], SL[i][1] - 14, 0.5)
        for h in hits:
            cur_sheet(F, "assets/fx/poison/poison_hit_sheet.png", 17, t - h, 24.0, (aim[0], aim[1] - 12), 0.8)
        if 0 <= leap < LEAP_T:  # poison_drip_fx.leap (temsili): damla yay çizer
            u = leap / LEAP_T
            p = bez(body_c(0), lerp(body_c(0), body_c(1), 0.5), body_c(1), u)
            p = (p[0], p[1] - math.sin(math.pi * u) * 18)
            blit_world(F, tex("assets/fx/poison/zehir_damla_a.png"), p[0], p[1], 0.575)
        composite(F, Ov)
        return F
    fn = {"A": _zeh_A, "B": _zeh_B, "C": _zeh_C}[var]
    fn(t, U, Ov, S, tips, hits, ang, d, death, leap, land, stacks)
    composite(F, U)
    draw_scene(F, t, "tuftuf", aim, ZEH_FIRE, S)
    composite(F, Ov)
    return F


DROP = [(1, -3.6), (-5.5, 0), (1, 3.6)]


def _drop(L, cx, cy, ang, t, a=1.0, s=1.0):
    q = 1 + 0.12 * math.sin(t * 40.0)

    def shade(LX, LY):
        out = np.empty(LX.shape + (3,), f32)
        out[:] = np.array(POI[2], f32)
        out[LY < -1.0] = np.array(POI[1], f32)
        out[LY > 2.0] = np.array(POI[3], f32)
        out[(LY < -1.2) & (LY > -2.6) & (LX > 0.5) & (LX < 3.0)] = np.array(POI[0], f32)
        return out
    L.shape(DROP, ang, cx, cy, shade, ol=POI_OL, a=a, sx=q * s, sy=s / q, extra=[(1.4, 0.0, 3.8)])


def _leap_path(u):
    a, b = body_c(0), body_c(1)
    p = lerp(a, b, u)
    return (p[0], p[1] - math.sin(math.pi * u) * 22)


def _zeh_A(t, U, Ov, S, tips, hits, ang, d, death, leap, land, stacks):
    aim = body_c(0)
    for f, tp in zip(ZEH_FIRE, tips):
        age = t - f
        if 0 <= age < 0.14:
            Ov.disc(tp[0], tp[1], 3 * math.sin(math.pi * age / 0.14), POI[1], 0.9)
        T_fl = dist(tp, aim) / ZEH_SPEED
        k = 0
        while True:  # kopup düşen damlacıklar + yerde minik sıçrama (yerde KALMAZ)
            ts = f + k * 0.09
            if ts > t or ts > f + T_fl:
                break
            a = t - ts
            p0 = lerp(tp, aim, (ts - f) / T_fl)
            gy = p0[1] + 16
            yy = p0[1] + 4 + 0.5 * 320 * a * a
            xx = p0[0] - d[0] * 6 + 35 * a * d[0]
            if yy < gy:
                Ov.rect(xx, yy, 2, 2, POI[2])
                Ov.px(xx, yy, POI[1])
            else:
                ta = a - math.sqrt(2 * (gy - p0[1] - 4) / 320)
                if ta < 0.14:
                    q = ta / 0.14
                    U.px(xx - 1 - 2 * q, gy - 1 - 2 * math.sin(math.pi * q), POI[1], B(1 - q, 2))
                    U.px(xx + 2 + 2 * q, gy - 1 - 2 * math.sin(math.pi * q), POI[1], B(1 - q, 2))
                    U.rect(xx - 1, gy, 4, 1, POI[2], B(1 - q, 2))
            k += 1
        fl = flight(f, t, tp, aim, ZEH_SPEED)
        if fl:
            _drop(Ov, fl[1][0], fl[1][1], ang, age, s=1.15)
    for h in hits[:1]:
        a = t - h
        _splash_A(U, Ov, aim, SL[0][1] + BODY_BOT, a, 6)
    # zehir yükü: gövdeden süzülen damlalar (yük sayısı kadar) + kabarcık
    for i in range(3):
        n = stacks[i]
        if n <= 0 or S[i]["alpha"] <= 0:
            continue
        x, y = SL[i]
        # (yeşil tonlama kırmızı gövdeyi çamur rengine çeviriyordu: sayaç yalnız damlalar)
        for j in range(n):
            dx = (-5, 4, -1, 6, -7)[j]
            ph = (t / 0.9 + j * 0.31) % 1.0
            top = y + BODY_TOP + 6 + (j % 2) * 3
            if ph < 0.6:
                ln = 1 + 4 * ph / 0.6
                Ov.line(x + 1 + dx, top, x + 1 + dx, top + ln, POI[2])
                Ov.rect(x + 1 + dx, top + ln, 1, 2, POI[1])
            else:
                yy = top + 5 + (ph - 0.6) / 0.4 * (BODY_BOT - BODY_TOP - 8)
                Ov.rect(x + 1 + dx, yy, 2, 2, POI[2], B(1 - (ph - 0.6) / 0.4 * 0.6, 3))
        tk = (t % 1.0)
        if tk < 0.25:
            U.ring(x + 1, y + BODY_BOT, 11 + 3 * tk / 0.25, 4 + tk / 0.25, 1, POI[1], B(0.8 * (1 - tk / 0.25), 3))
    if death >= 0 and death < 0.5:
        x, y = SL[0]
        _splash_A(U, Ov, body_c(0), y + BODY_BOT, death, 9, big=True)
    if 0 <= leap < LEAP_T:
        u = leap / LEAP_T
        p = _leap_path(u)
        for s in range(1, 6):  # sürekli iz (titreşimsiz), bantlı sönüş
            uu = max(0.0, u - s * 0.035)
            q0 = _leap_path(uu)
            q1 = _leap_path(max(0.0, uu - 0.035))
            Ov.line(q0[0], q0[1], q1[0], q1[1], POI[2], B(1 - s / 6.0, 3), 2)
        pp = _leap_path(min(1.0, u + 0.02))
        _drop(Ov, p[0], p[1], math.atan2(pp[1] - p[1], pp[0] - p[0]), t, s=1.2)
    if land >= 0:
        _splash_A(U, Ov, body_c(1), SL[1][1] + BODY_BOT, land, 6)


def _splash_A(U, Ov, c, gy, a, n, big=False):
    if not (0 <= a < 0.45):
        return
    for j in range(n):
        aa = math.pi + (j + 0.5) / n * math.pi + (0.0 if not big else 0.0)
        v = (70 if big else 55) + (j % 3) * 12
        x = c[0] + math.cos(aa) * v * a
        y = c[1] + math.sin(aa) * v * a + 0.5 * 300 * a * a
        if y < gy + 2:
            Ov.rect(x, y, 2, 2, POI[2], B(1 - a / 0.45, 3))
            Ov.px(x, y, POI[1], B(1 - a / 0.45, 3))
    q = a / (0.4 if big else 0.25)
    if q < 1:
        r = (13 if big else 8) * (0.5 + 0.5 * ease_out(q * 2)) * (1 - q * 0.6)
        U.ell(c[0], gy, r, r * 0.45, POI[3], B(0.8 * (1 - q), 3))
        U.ell(c[0], gy - 0.5, r * 0.7, r * 0.3, POI[2], B(0.8 * (1 - q), 3))
        if a < 0.08:
            Ov.disc(c[0], c[1], 6 if big else 4, POI[0], 0.8)


def _bubble(L, cx, cy, r, t, a=1.0):
    wob = 0.5 * math.sin(t * 18.0)
    L.ell(cx, cy, r + wob, r - wob, POI[2], 0.35 * a)
    L.ring(cx, cy, r + wob, r - wob, 1, POI[1], 0.9 * a)
    L.px(cx - r * 0.5, cy - r * 0.55, WHITE, a)
    L.px(cx - r * 0.5 + 1, cy - r * 0.75, WHITE, a)
    aa = t * 14.0
    L.px(cx + math.cos(aa) * r * 0.45, cy + math.sin(aa) * r * 0.45, POI[0], a)


def _pop_ring(L, cx, cy, r0, a, life=0.2):
    if not (0 <= a < life):
        return
    q = a / life
    r = r0 + 5 * q
    for j in range(4):
        a0 = j * 90 + 20
        L.arc(cx, cy, r, r, a0, a0 + 50, 1, POI[1], B(1 - q, 3))


def _zeh_B(t, U, Ov, S, tips, hits, ang, d, death, leap, land, stacks):
    aim = body_c(0)
    for f, tp in zip(ZEH_FIRE, tips):
        age = t - f
        if 0 <= age < 0.2:
            q = age / 0.2
            Ov.disc(tp[0], tp[1], 2 + 3 * q, POI[1], B(0.5 * (1 - q), 3))
        T_fl = dist(tp, aim) / ZEH_SPEED
        k = 0
        while True:
            ts = f + k * 0.05
            if ts > t or ts > f + T_fl:
                break
            a = t - ts
            if a < 0.35:
                p0 = lerp(tp, aim, (ts - f) / T_fl)
                Ov.disc(p0[0] - d[0] * 4, p0[1] - d[1] * 4 - 6 * a, 1.5 + 2.5 * a / 0.35, POI[2], B(0.45 * (1 - a / 0.35), 3))
            k += 1
        fl = flight(f, t, tp, aim, ZEH_SPEED)
        if fl:
            _bubble(Ov, fl[1][0], fl[1][1], 4, age)
    for h in hits[:1]:
        a = t - h
        _pop_ring(Ov, aim[0], aim[1], 4, a)
        if 0 <= a < 0.4:  # bulut hedefe emilir (yerde kalmaz)
            q = a / 0.4
            g = 1 - q
            circ = [(aim[0] + ox * g, aim[1] + oy * g, (4 + 4 * ease_out(q * 3)) * g + 1) for (ox, oy) in ((-5, -2), (4, -4), (0, 3), (6, 2))]
            Ov.cloud(circ, (POI[2], POI[1]), (B(0.4 * g, 3), B(0.55 * g, 3)), grow=(1.0, 0.6))
    for i in range(3):
        n = stacks[i]
        if n <= 0 or S[i]["alpha"] <= 0:
            continue
        x, y = SL[i]
        br = 0.6 * math.sin(t * 4.0 + i)
        rx, ry = 9 + 1.6 * n + br, 3.2 + 0.6 * n + br * 0.4
        U.ell(x + 1, y + BODY_BOT, rx, ry, POI[2], 0.3)
        U.ell(x + 1, y + BODY_BOT, rx * 0.65, ry * 0.65, POI[1], 0.35)
        for j in range(n):
            ph = (t / 0.8 + j / max(1, n)) % 1.0
            bx = x + 1 + (-4, 3, -1, 5, -6)[j] + math.sin(ph * 9 + j) * 1.2
            by = y + BODY_TOP + 2 - 12 * ph
            if ph < 0.85:
                Ov.ring(bx, by, 1.6, 1.6, 1, POI[1], 0.9)
            else:
                Ov.ring(bx, by, 2.6, 2.6, 1, POI[0], 0.5)
        tk = t % 1.0
        if tk < 0.25:
            for (ox, oy) in ((-4, -1), (4, -2)):
                Ov.disc(x + 1 + ox, y + BODY_DY + oy, 2 + 4 * tk / 0.25, POI[1], B(0.4 * (1 - tk / 0.25), 3))
    if 0 <= death < 0.7:
        x, y = SL[0]
        c = body_c(0)
        S[0]["alpha"] = B(1 - death / 0.25) if death < 0.25 else 0.0
        q = death / 0.7
        g = ease_out(death / 0.4)
        sh = 1 - 0.5 * max(0.0, (death - 0.3) / 0.4)
        circ = [(c[0] + ox * (1 + 0.6 * g), c[1] + oy * (1 + 0.6 * g) - 4 * g, r0 * (1 + 0.6 * g) * sh)
                for (ox, oy, r0) in ((0, 0, 7), (-8, 2, 6), (8, 1, 6), (-3, -7, 6), (5, -6, 5), (-10, -3, 4), (11, -3, 4))]
        Ov.cloud(circ, (POI[3], POI[2], POI[1]), (B(0.35 * (1 - q)), B(0.5 * (1 - q)), B(0.6 * (1 - q))))
    if 0 <= leap < LEAP_T:
        u = leap / LEAP_T
        p = _leap_path(u)
        for s in range(1, 5):
            q0 = _leap_path(max(0.0, u - s * 0.05))
            Ov.disc(q0[0], q0[1], 1 + s * 0.6, POI[2], B(0.4 * (1 - s / 5.0), 3))
        _bubble(Ov, p[0], p[1], 4, t)
    if land >= 0:
        _pop_ring(Ov, body_c(1)[0], body_c(1)[1], 4, land)


def _blob_train(L, cx, cy, ang, t, a=1.0, s=1.0):
    w = 1.2 * math.sin(t * 30.0)

    def shade(LX, LY):
        out = np.empty(LX.shape + (3,), f32)
        out[:] = np.array(ACID[2], f32)
        out[LY < -0.5] = np.array(ACID[1], f32)
        out[(LY < -1.8) & (LY > -3.4) & (LX > -0.5) & (LX < 2.2)] = np.array(ACID[0], f32)
        return out
    ## üç AYRI damla (birleşince armut gibi okunuyordu): her biri kendi konturuyla
    for (ex, ey, er) in ((-12.5 * s, -w * 0.6, 1.5), (-7.5 * s, w, 2.4), (0, 0, 4.0)):
        c, sn = math.cos(ang), math.sin(ang)
        L.shape([], ang, cx + c * ex - sn * ey, cy + sn * ex + c * ey, shade, ol=ACID_OL, olk=2 if er > 2 else 1, a=a, sx=s, sy=s,
                extra=[(0, 0, er)])


def _splat(L, cx, cy, r, a=1.0, seed=0):
    pts = []
    for j in range(10):
        aa = j * TAU / 10 + seed
        rr = r * (1.0 if j % 2 == 0 else 0.62) * (0.9 + 0.1 * ((seed * 7 + j * 3) % 3))
        pts.append((math.cos(aa) * rr, math.sin(aa) * rr))

    def shade(LX, LY):
        out = np.empty(LX.shape + (3,), f32)
        out[:] = np.array(ACID[2], f32)
        out[LY < -r * 0.2] = np.array(ACID[1], f32)
        return out
    L.shape(pts, 0.0, cx, cy, shade, ol=ACID_OL, olk=2 if r > 4 else 1, a=a)


SPOTS = [(-4, -3), (4, 1), (-1, 4), (5, -5), (-6, 2)]


def _acid_spot(L, cx, cy, r, a=1.0):
    """Gövdede kalan asit lekesi: yuvarlak, 1 px kontur, üstü açık + 1 px parlama (yük sayacı)."""
    L.shape([], 0.0, cx, cy, tone2(ACID[1], ACID[2], -r * 0.2), ol=ACID_OL, a=a, extra=[(0, 0, r)])
    L.px(cx - 1, cy - r + 1, ACID[0], a)


def _zeh_C(t, U, Ov, S, tips, hits, ang, d, death, leap, land, stacks):
    aim = body_c(0)
    for f, tp in zip(ZEH_FIRE, tips):
        age = t - f
        if 0 <= age < 0.12:
            _splat(Ov, tp[0], tp[1], 4 * math.sin(math.pi * age / 0.12) + 0.5)
        fl = flight(f, t, tp, aim, ZEH_SPEED)
        if fl:
            _blob_train(Ov, fl[1][0], fl[1][1], ang, age)
    for h in hits[:1]:
        a = t - h
        if 0 <= a < 0.2:
            sc = 0.6 + 0.6 * math.sin(math.pi * min(1.0, a / 0.12)) if a < 0.12 else 1.0 - (a - 0.12) / 0.08 * 0.5
            _splat(Ov, aim[0] - d[0] * 3, aim[1] - d[1] * 3, 8 * sc, seed=1)
    for i in range(3):
        n = stacks[i]
        if n <= 0 or S[i]["alpha"] <= 0:
            continue
        x, y = SL[i]
        # (tonlama yok: sayaç yalnız lekeler)
        c = body_c(i)
        for j in range(n):
            sx_, sy_ = SPOTS[j]
            _acid_spot(Ov, c[0] + sx_, c[1] + sy_, 2.3)
            ph = (t / 0.6 + j * 0.37) % 1.0
            if ph < 0.7:  # buhar tüter
                q = ph / 0.7
                bx = c[0] + sx_ + math.sin(q * 7 + j) * 1.0
                by = c[1] + sy_ - 3 - 7 * q
                Ov.line(bx, by, bx + math.sin(q * 7 + j + 1) * 1.0, by - 2, ACID[0], B(0.75 * (1 - q), 3))
        tk = t % 1.0
        if tk < 0.08:
            for j in range(n):
                Ov.disc(c[0] + SPOTS[j][0], c[1] + SPOTS[j][1], 2, WHITE, 0.7)
    if 0 <= death < 0.6:
        x, y = SL[0]
        if death < 0.3:  # erir: tabana sabit ezilme
            q = death / 0.3
            S[0]["alpha"] = 1.0
            S[0]["sy"], S[0]["sx"] = 1 - 0.75 * q, 1 + 0.5 * q
            S[0]["tint"], S[0]["tint_a"] = ACID[2], 0.45 + 0.5 * q
        else:
            S[0]["alpha"] = 0.0
        q2 = (death - 0.22) / 0.38
        if 0 <= q2 < 1:  # eriyen gövdeden kısa ömürlü gölcük (hemen küçülür, yerde KALMAZ) + patlayan kabarcıklar
            r = 13 * (0.7 + 0.3 * ease_out(q2 * 3)) * (1 - 0.8 * q2)
            U.ell(x + 1, y + BODY_BOT, r + 1, r * 0.42 + 1, ACID_OL, 1.0)
            U.ell(x + 1, y + BODY_BOT, r, r * 0.42, ACID[2], 1.0)
            U.ell(x, y + BODY_BOT - 0.5, r * 0.6, r * 0.22, ACID[1], 1.0)
            for j, (bx, ph) in enumerate(((-5, 0.0), (3, 0.3), (7, 0.55))):
                qq = q2 - ph * 0.5
                if 0 <= qq < 0.35:
                    rr = 1.2 + 2.0 * qq / 0.35
                    Ov.ring(x + 1 + bx * (1 - 0.6 * q2), y + BODY_BOT - 2 - 3 * qq, rr, rr, 1, ACID[1] if qq < 0.28 else ACID[0], 1.0)
            for j in range(5):
                aa = math.pi + (j + 0.5) / 5 * math.pi
                a2 = death - 0.22
                bx = x + 1 + math.cos(aa) * 55 * a2
                by = y + BODY_DY + math.sin(aa) * 55 * a2 + 0.5 * 300 * a2 * a2
                if by < y + BODY_BOT:
                    _acid_spot(Ov, bx, by, 1.6)
    if 0 <= leap < LEAP_T:
        u = leap / LEAP_T
        p = _leap_path(u)
        pp = _leap_path(min(1.0, u + 0.02))
        _blob_train(Ov, p[0], p[1], math.atan2(pp[1] - p[1], pp[0] - p[0]), t)
    if 0 <= land < 0.2:
        c = body_c(1)
        sc = 0.6 + 0.6 * math.sin(math.pi * min(1.0, land / 0.12)) if land < 0.12 else 1.0 - (land - 0.12) / 0.08 * 0.5
        _splat(Ov, c[0] - 3, c[1], 8 * sc, seed=2)


# ================================================================== çıktılar
STAVES = {
    "buz": (buz_panel, BUZ_LOOP, "Buz Asası", "1,0 sn · her isabet yavaşlatır, her 2. isabet dondurur · donmuşken ölen parçalanır (100 birim)",
            {"0": "0  Şimdiki (oyunda)", "A": "A  Kırağı Bloğu", "B": "B  Kar Tanesi", "C": "C  Saplanan Sarkıt"}),
    "arcane": (arc_panel, ARC_LOOP, "Arcane Asası", "1,7 sn · Yankılanan Büyü: isabet yerinde 0,8 sn sonra 45 birimlik ikinci patlama",
               {"0": "0  Şimdiki (oyunda; yankı temsili)", "A": "A  Rün Küresi", "B": "B  Yıldız Tozu", "C": "C  Kaos Yarığı"}),
    "zehir": (zeh_panel, ZEH_LOOP, "Zehir Asası", "1,7 sn · zehir yükü (5'e kadar) · zehirli ölen düşmandan damla en yakına sıçrar",
              {"0": "0  Şimdiki (oyunda; sıçrama temsili)", "A": "A  Damla+", "B": "B  Kabarcık", "C": "C  Asit"}),
}
VARS = ["0", "A", "B", "C"]
KEY_T = {"buz": None, "arcane": None, "zehir": None}


def panel_img(fn, var, t, title):
    F = fn(var, t)
    im = Image.fromarray(np.clip(F, 0, 255).astype(np.uint8), "RGB")
    band = Image.new("RGB", (im.width, 20), (30, 34, 32))
    label(ImageDraw.Draw(band), 6, 3, title, 12, (240, 234, 218) if var != "0" else (190, 186, 172))
    return stack_v([band, im], 0)


def grid2(ims, gap=4):
    w, h = ims[0].size
    out = Image.new("RGB", (w * 2 + gap, h * 2 + gap), (18, 20, 20))
    for i, im in enumerate(ims):
        out.paste(im, ((i % 2) * (w + gap), (i // 2) * (h + gap)))
    return out


def build_gif(name):
    fn, loop, title, sub, names = STAVES[name]
    n = int(round(loop * FPS))
    frames = []
    for k in range(n):
        t = k / FPS
        g = grid2([panel_img(fn, v, t, names[v]) for v in VARS])
        hd = header(g.width, "%s  ·  yeni efekt prototipleri (oyun ölçeği 1080p, gerçek hız)" % title, sub)
        frames.append(stack_v([hd, g], 0))
    os.makedirs(OUT, exist_ok=True)
    save_gif(frames, os.path.join(OUT, name + ".gif"), FPS, [int(n * 0.15), int(n * 0.45), int(n * 0.75)])
    return frames


def key_times():
    _, _, bh = buz_times()
    _, _, ah = arc_times()
    _, _, zh = zeh_times()
    return {
        "buz": [bh[0] - 0.12, bh[1] + 0.35, bh[2] + 0.12],  # uçuş, donma, parçalanma
        "arcane": [ah[0] - 0.12, ah[0] + 0.5, ah[0] + ECHO_DELAY + 0.06],  # uçuş, yankı sayacı, patlama
        "zehir": [zh[0] - 0.12, zh[0] + 0.6, zh[1] + 0.05 + LEAP_T * 0.6],  # uçuş, yük, sıçrama
    }


def build_ozet():
    kt = key_times()
    rows = []
    for name in ("buz", "arcane", "zehir"):
        fn, loop, title, sub, names = STAVES[name]
        cols = [panel_img(fn, v, kt[name][2] if name != "arcane" else kt[name][1], names[v]) for v in VARS]
        w = sum(c.width for c in cols) + 4 * 3
        row = Image.new("RGB", (w, cols[0].height), (18, 20, 20))
        x = 0
        for c in cols:
            row.paste(c, (x, 0))
            x += c.width + 4
        rows.append(stack_v([header(w, title, "ödül anı (%s)" % ("yankı sayacı" if name == "arcane" else "parçalanma" if name == "buz" else "sıçrama")), row], 0))
    im = stack_v(rows, 6)  # tam boy (1080p oyun ölçeği): küçültme piksel sanatını bulandırır
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, "ozet.png"))
    print("png", os.path.join(OUT, "ozet.png"), im.size)


def build_yakin():
    """x4 yakın: her yön için uçuş, durum (donma / yankı / yük) ve ödül anı (dünya pikselleri x4, NEAREST)."""
    kt = key_times()
    rows = []
    crops = {"buz": [(70, 10, 200, 100), (150, 40, 240, 110), (110, 20, 250, 124)],
             "arcane": [(70, 10, 200, 100), (120, 30, 250, 120), (120, 20, 250, 124)],
             "zehir": [(70, 10, 200, 100), (150, 40, 240, 110), (140, 20, 250, 120)]}
    for name in ("buz", "arcane", "zehir"):
        fn, loop, title, sub, names = STAVES[name]
        parts = []
        for v in VARS[1:]:
            cells = []
            for j, tt in enumerate(kt[name]):
                F = fn(v, tt)
                x0, y0, x1, y1 = crops[name][j]
                c = F[y0 * Z:y1 * Z, x0 * Z:x1 * Z]
                im = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), "RGB")
                cells.append(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
            w = sum(c.width for c in cells) + 4 * (len(cells) - 1)
            row = Image.new("RGB", (w, max(c.height for c in cells) + 20), (18, 20, 20))
            label(ImageDraw.Draw(row), 6, 3, "%s · %s" % (title, names[v]), 12)
            x = 0
            for c in cells:
                row.paste(c, (x, 20))
                x += c.width + 4
            parts.append(row)
        rows.append(stack_v(parts, 4))
    im = stack_v(rows, 10)
    im.save(os.path.join(OUT, "yakin.png"))
    print("png", os.path.join(OUT, "yakin.png"), im.size)


if __name__ == "__main__":
    which = sys.argv[1:] or ["buz", "arcane", "zehir", "ozet"]
    for w in which:
        if w in STAVES:
            build_gif(w)
        elif w == "ozet":
            build_ozet()
            build_yakin()
