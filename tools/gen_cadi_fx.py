"""Cadı (karakter 15) yetenek efektleri - pixel-art sprite sayfaları -> assets/fx/cadi/ + ikonlar -> assets/skills/

Kullanıcı isteği (2026-10-13): yeni karakter Cadı; "pixel art birçok efektin yapılıp spritesheet haline getirilmesi
gerekiyor, eklemeden önce bana göster". Tasarımlar prototip turlarında onaylandı (tools/proto_20261013/out/cadi_*.gif):
  Q  Zehirli Duman   potion (şişe: loop = 45 derece eğik, down = ağzı aşağı) + stream (ağızdan dökülen duman, aynı iki
                     duruş) + smoke (bulut: intro / loop / outro). 1. tur koyu yeşil duman "çalı gibi" durdu, 2. tur
                     soluk dither bulut "pek duman gibi değil" bulundu -> TEMİZ, mor gölgeli "Kabaran Duman" (bkz. Q bölümü).
  E  Süpürge         broom_side (sola bakan, satır = yolcu sayısı 0..7; sağ = aynalanır), broom_vert (aşağı: öne uzanan
                     sap / yukarı: sarkan saman - DÜZ; çapraz hali "yamuk" bulundu), poof (biniş dumanı), spark (iz parıltısı)
  R  İksirler        bottles (5 şişe x 4 takla karesi), shatter (kırılma sıçraması), boom (3. iksir patlaması) ve 4 alan
                     (intro / loop / outro): zone_mad (dönen pembe sis + hipnoz sarmalları), zone_ice (kırağılı zemin +
                     dönen buz sisi), zone_heal (ışık çemberi), zone_fear (kara-mor sis + kuru kafalar). Delilik/Don/Şifa
                     için düz zemin şekilleri (buz yaması, girdap, birikinti, halka) İKİ KEZ reddedildi; onaylanan dil
                     Korku sisiyle aynı: kontursuz, dither kenarlı HACİMLİ kütle + belirgin simgeler.
                     mad_status: delirmiş yaratığın baş üstü göstergesi (enemy.gd apply_madness)
  İkonlar            pasif, Q, E, R + R'nin sıradaki iksire göre 5 çeşidi (48x48 karo dili, 3x kaydedilir)
Dil tools/pixfx.py ile aynı (5 ton, alfa yerine aşınma/dither). YOĞUNLUK: 1 sanat pikseli = KARAKTERİN pikseli (0,903 dünya
birimi = DEFS ölçeği 2.2368375 x EntityScale.SIZE x 0.5; Matthew şimşeğiyle aynı karar) - kodda CadiMath.WORLD_TEXEL.
Alanlar ZEMİN efektidir (kullanıcı: "zeminin üstünde olsun, yaratıkların üstünde olmasın") - EnemyAbilities.place_on_ground.

Kullanım (proje kökünden):
    python -I tools/gen_cadi_fx.py              -> oyun varlıkları (sayfalar + SpriteFrames .tres + ikonlar)
    python -I tools/gen_cadi_fx.py --onizleme   -> önizleme GIF'leri (tools/proto_20261013/out/)
Sonra: Godot --headless --path . --import
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
OUT = os.path.join(HERE, 'proto_20261013', 'out')
ASSET_DIR = os.path.join(PROJECT, 'assets', 'fx', 'cadi')
ICON_DIR = os.path.join(PROJECT, 'assets', 'skills')
RES = 'res://assets/fx/cadi/'
SHEETS = os.path.join(OUT, 'cadi_sayfalar')
PREVIEW = '--onizleme' in sys.argv
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
import pixfx as fx  # noqa: E402
from pixfx import Canvas, CREAM, TAU, WHITE, burst, dilate, disc_flash, ease_out, erode, facets, lerp, outline_of, puffs, ring_band, shock_ring, star, thick_line  # noqa: E402
from gen_elara_korsan_icons import C, tile as itile  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

# ---- paletler: [kontur, koyu, orta, açık, parlak]
POISON = [(20, 46, 16), (58, 116, 32), (112, 180, 46), (178, 228, 94), (234, 252, 184)]
SMK = [(60, 84, 40), (98, 138, 52), (152, 194, 64), (202, 230, 108), (240, 250, 184)]
FEARM = [(10, 4, 18), (28, 12, 50), (54, 28, 94), (88, 52, 146), (128, 90, 194)]
TOXIC_MOTE = (176, 124, 220)
FROST = [(60, 110, 170), (150, 196, 232), (196, 226, 246), (228, 242, 252), (250, 253, 255)]
MAD = [(58, 10, 46), (146, 26, 106), (224, 62, 158), (255, 142, 206), (255, 226, 242)]
ICE = fx.ICE
FIRE = fx.FIRE
HEAL = fx.HEAL
FEAR = [(14, 6, 24), (44, 20, 72), (84, 44, 134), (140, 96, 200), (206, 180, 246)]
MAGIC = [(40, 20, 70), (96, 58, 150), (150, 104, 210), (204, 170, 246), (244, 232, 255)]
MAGIC_SOFT = [(58, 40, 86), (120, 92, 160), (168, 142, 206), (212, 194, 238), (244, 236, 255)]
GOLD = [(96, 58, 10), (204, 140, 24), (250, 208, 60), (255, 240, 150), (255, 255, 230)]
WOODP = [(36, 20, 12), (96, 58, 32), (146, 96, 54), (192, 140, 84), (226, 184, 120)]
STRAW = [(64, 42, 12), (150, 104, 36), (204, 160, 60), (238, 206, 110), (252, 236, 170)]
GLASS_OUT = (24, 26, 40)
GLASS_FILL = (206, 232, 236)
CORK = (184, 132, 80)
CORK_D = (128, 84, 48)
BONE = (226, 214, 246)

POTIONS = [('round', MAD, 'Delilik'), ('vial', ICE, 'Don'), ('bomb', fx.EMBER, 'Patlama'), ('heart', HEAL, 'Şifa'), ('cone', FEAR, 'Korku')]


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeuib.ttf', r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


# ====================================================================== yardımcılar
def circle(cv, cx, cy, r, sq=1.0):
    X, Y = cv.grid()
    return (X - cx) ** 2 + ((Y - cy) / sq) ** 2 <= r * r


def ppx(cv, x, y, col):
    """Sürekli koordinattaki noktayı içeren piksel."""
    cv.px(x - 0.5, y - 0.5, col)


def bayer(cv):
    b = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    yy, xx = np.mgrid[0:cv.h, 0:cv.w]
    return b[yy % 4, xx % 4]


def ipix(cv):
    yy, xx = np.mgrid[0:cv.h, 0:cv.w]
    return xx, yy


def blob(cv, cx, cy, rx, ry, t, seed, wobble=0.13, lobes=6):
    """Düzensiz kenarlı elips; t (0..1) ile kenar dalgası DÖNGÜSEL oynar."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, TAU, 3)
    X, Y = cv.grid()
    th = np.arctan2((Y - cy) / ry, (X - cx) / rx)
    k = 1.0 + wobble * (0.5 * np.sin(lobes * th + ph[0] + TAU * t) + 0.3 * np.sin((lobes + 3) * th + ph[1] - TAU * t)
                        + 0.2 * np.sin(2 * th + ph[2] + TAU * t))
    return ((X - cx) / (rx * k)) ** 2 + ((Y - cy) / (ry * k)) ** 2 <= 1.0


def lnoise(cv, scale, seed, t, ysq=1.0):
    """Yumuşak gürültü (0..1), t'de TAM döngüsel (t ve t+1 aynı). ysq > 1: desen dikeyde basık (zemin perspektifi)."""
    rng = np.random.default_rng(seed)
    X, Y = cv.grid()
    Y = Y * ysq
    acc = np.zeros((cv.h, cv.w))
    amp = 0.0
    for o in range(3):
        f = (2 ** o) / scale
        a = 0.55 ** o
        th = rng.uniform(0, TAU)
        ph = rng.uniform(0, TAU, 2)
        u = X * math.cos(th) + Y * math.sin(th)
        v = -X * math.sin(th) + Y * math.cos(th)
        acc += a * np.sin(u * f * TAU + ph[0] + TAU * t) * np.sin(v * f * TAU * 0.83 + ph[1] - TAU * t)
        amp += a
    return 0.5 + 0.5 * acc / amp


def soft_cloud(cv, circles, pal, t, seed, squash=0.8, erosion=0.0, edge=0.2):
    """Gaz / sis kütlesi: KONTURSUZ, kenarı Bayer dither ile dağılır, ton tek tek kürelere göre değil bulutun
    yüksekliğine + akan gürültüye göre (üst açık, alt koyu, bantlar zamanla kayar). erosion (0..1): içinde delikler açılır."""
    X, Y = cv.grid()
    field = np.zeros((cv.h, cv.w))
    for (cx, cy, r) in circles:
        if r <= 0.5:
            continue
        d = np.sqrt((X - cx) ** 2 + ((Y - cy) / squash) ** 2) / r
        field = np.maximum(field, 1.0 - d)
    mask = field > 0.0
    if not mask.any():
        return mask
    by = bayer(cv)
    n1 = lnoise(cv, 22.0, seed, t)
    n2 = lnoise(cv, 9.0, seed + 1, t)
    mask &= (field > edge) | (by < field / edge)
    if erosion > 0.0:
        mask &= (n1 * 0.6 + n2 * 0.4 + field * 0.25) > erosion * 0.92
    if not mask.any():
        return mask
    rows = np.where(mask.any(axis=1))[0]
    top, bot = rows.min(), rows.max()
    h = (Y - 0.5 + cv.oy - top) / max(1.0, float(bot - top))
    v = h * 0.8 + (n1 - 0.5) * 0.85 + (n2 - 0.5) * 0.2 - (field - 0.3) * 0.3
    tone = np.where(v < 0.16, 4, np.where(v < 0.42, 3, np.where(v < 0.72, 2, 1)))
    for k in range(1, 5):
        cv.put(mask & (tone == k), pal[k])
    return mask


def check(name, frames):
    for i, f in enumerate(frames):
        a = f[:, :, 3] > 0
        if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
            print('  UYARI kenara değiyor:', name, 'kare', i)
            return


def strip(frames):
    h, w = frames[0].shape[:2]
    im = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        im[:, i * w:(i + 1) * w] = f
    return im


def save_strip(name, frames):
    check(name, frames)
    Image.fromarray(strip(frames), 'RGBA').save(os.path.join(SHEETS, name + '.png'))


# ====================================================================== Q: uçan zehir şişesi + duman
# 2026-10-13 yeniden tasarım (kullanıcı: "zehirli duman pek duman gibi değil ... parazitli olmayan"): prototip turları
# tools/proto_20261013/cadi_duman_proto.py (A-D noktalı, E-H temiz) -> seçilen F "Kabaran Duman": TEMİZ (dither/gürültü
# yok), toplar ressam sırasıyla tam daire, 4 düz ton, alt gölge MOR, içte açık renk hacim yayları; sönüş = toplar sırayla
# küçülür. Oyunda yaratıkların ÜSTÜNDE, bulut başına %50 saydam çizilir (cadi_smoke.gd).
POT_W, POT_H = 24, 24
POT_MOUTH = 11.4  # ağız = gövde merkezi + eksen x 11.4
# Şişe iki duruşta: 'side' ağzı sol alta 45 derece (sağa bakarken; sola bakarken aynalanır), 'down' ağzı dümdüz aşağı
# (yukarı/aşağı bakarken şişe cadının TAM arkasında durur; çapraz çizilen şey o bakışta "yamuk" duruyor).
POT_POSES = {'side': ((13.5, 9.5), (-0.70711, 0.70711)), 'down': ((12.0, 8.5), (0.0, 1.0))}
POT_CX, POT_CY = POT_POSES['side'][0]
POT_DROP = (-12.0, 26.0)  # 'side': dumanın yere indiği nokta gövde merkezine göre; 'down': (0, 26)
ST_W, ST_H = 24, 32
# Akış sayfasında ağzın yeri + ağızdan yere iniş vektörü (= POT_DROP - ağız)
ST_POSES = {'side': ((15.0, 5.0), (-3.94, 17.94)), 'down': ((12.0, 5.0), (0.0, 14.6))}
# [-, alt gölge (mor: çimenden/çalıdan ayırır), orta, gövde, ışık]
SMKF = [None, (116, 92, 152), (148, 186, 110), (194, 224, 144), (232, 247, 192)]
SMOKE_SQ = 0.92  # topların dikey basıklığı


def clean_cloud(cv, puffs, pal, scallop=False, under=2, shade=6, min_r=4.0, rim=(2, 1)):
    """Temiz duman kütlesi. puffs: (x, y, r) ressam sırasıyla (ilk = en arkada). Gölge top başına DEĞİL kütlenin
    bütününe göre (top başına parlaklık + hilal "baloncuk yığını" gibi durdu): gövde tek ton, sol-üst kenarda ışık bandı,
    altta 2 kademe gölge. scallop: öndeki her topun sol-üst kenarı da ışık alır (kütlenin içinde açık yaylar = hacim).
    min_r'den küçük top çizilmez (serpme piksel = "parazit")."""
    X, Y = cv.grid()
    sil = np.zeros((cv.h, cv.w), bool)
    tone = np.zeros((cv.h, cv.w), np.uint8)
    for (x, y, r) in puffs:
        if r < min_r:
            continue
        disc = (X - x) ** 2 + ((Y - y) / SMOKE_SQ) ** 2 <= r * r
        tone[disc] = 3
        if scallop and r >= 5.0:
            tx, ty = 0.06 * r + 0.5, 0.11 * r + 0.9
            tone[disc & ~((X - (x + tx)) ** 2 + ((Y - (y + ty)) / SMOKE_SQ) ** 2 <= r * r)] = 4
        sil |= disc
    tone[sil & ~np.roll(sil, rim, (0, 1))] = 4  # dış sol-üst kenar: ışık bandı (rim = kalınlık: aşağı, sağa)
    tone[sil & ~np.roll(sil, -shade, 0) & (tone == 3)] = 2  # alt gövde: orta ton
    tone[sil & ~np.roll(sil, -under, 0)] = 1  # en alt: gölge
    for k in range(1, 5):
        cv.put(tone == k, pal[k])
    return sil


def q_potion_frames(pose='side'):
    """Zehir şişesi (döngü). Sıvı dünyaya göre yatay kalır, boyun dolu - duman ağızdan dökülür (bkz. q_stream_frames)."""
    (cx, cy), (ax, ay) = POT_POSES[pose]
    frames = []
    for f in range(8):
        t = f / 8
        cv = Canvas(POT_W, POT_H)
        X, Y = cv.grid()
        dx, dy = X - cx, Y - cy
        v = dx * ax + dy * ay  # ağıza doğru
        u = dx * ay - dy * ax  # eksene dik
        body = dx ** 2 + dy ** 2 <= 6.3 ** 2
        neck = (np.abs(u) <= 1.45) & (v >= 5.0) & (v <= 10.2)
        lip = (np.abs(u) <= 2.5) & (v >= 9.6) & (v <= POT_MOUTH)
        glass = body | neck | lip
        cv.put(glass, GLASS_FILL)
        level = cy - 3.0 + dx * 0.14 * math.sin(TAU * t)
        liq = (body & (Y >= level)) | (neck & ~body)
        cv.put(liq, POISON[2])
        cv.put(liq & body & (dx < -1.2) & (dy < 3.0), POISON[3])
        cv.put(liq & body & ~erode(body) & ((dx > 1.0) | (dy > 2.5)), POISON[1])
        cv.put(body & (Y >= level) & (Y < level + 1.0), POISON[4])
        cv.put(lip & (v > 10.3), SMKF[3])
        for k in range(2):
            pp = (t + k * 0.5) % 1.0
            by = cy + 4.5 - pp * 5.5
            if by > cy - 2.2:
                ppx(cv, cx - 1.5 + k * 3.2 + math.sin(TAU * pp) * 0.7, by, POISON[4])
        ppx(cv, cx - 3.5, cy - 3.5, WHITE)
        ppx(cv, cx - 4.5, cy - 2.5, WHITE)
        ppx(cv, cx - 4.5, cy - 1.5, WHITE)
        cv.put(outline_of(glass) & ~cv.filled(), GLASS_OUT)
        frames.append(cv.rgba.copy())
    return frames


def q_stream_frames(pose='side'):
    """Şişenin ağzından yere inen duman akışı (döngü): ağızda ince, yere doğru büyüyen toplar yol boyunca AKAR.
    Yerdeki bulut bu akışın indiği noktada doğar - duman şişeden çıkıyor görünür."""
    (mx, my), (fx_, fy) = ST_POSES[pose]
    frames = []
    n = 5
    for f in range(8):
        t = f / 8
        cv = Canvas(ST_W, ST_H)
        puffs = []
        for k in range(n):
            s = (k + t) / n
            puffs.append((mx + fx_ * s + math.sin(TAU * (s + t)) * 0.8, my + fy * s ** 1.15, (1.5 + 3.6 * s) * min(1.0, (1.0 - s) / 0.2 + 0.3)))
        clean_cloud(cv, puffs, SMKF, under=1, shade=3, min_r=1.0, rim=(1, 1))  # ince akışta kalın ışık bandı her şeyi beyazlatıyordu
        frames.append(cv.rgba.copy())
    return frames


SMOKE_W, SMOKE_H = 104, 76
SMOKE_BX, SMOKE_BY = 52.0, 56.0  # top düzeninin başvuru noktası
SMOKE_OX, SMOKE_OY = 52.0, 53.0  # bulutun ORİJİNİ = zemindeki izin (hasar elipsi) merkezi; duman akışı buraya iner
SMOKE_IN, SMOKE_LOOP, SMOKE_OUT = 5, 8, 7


def _shrink(e, k):
    """Sönüşte toplar SIRAYLA küçülür (k: topa özgü 0..1)."""
    return max(0.0, min(1.0, 1.0 - (e * 1.55 - k * 0.55))) ** 0.8


def _smoke_puffs(g, t, e):
    """Tabanda kütle, ARKASINDAN toplar kopup yükselir ve küçülür (duman hissi buradan geliyor)."""
    rng = random.Random(5)
    out = []
    for k in range(3):
        ph, bx, R = (k + rng.random() * 0.5) / 3.0, (-15, 16, 1)[k], rng.uniform(9.0, 10.5)
        p = (t + ph) % 1.0
        r = R * (1.0 - p) ** 0.7 * min(1.0, p / 0.18) * g * _shrink(e, ph)
        out.append((SMOKE_BX + bx * (1.0 - 0.25 * p) * g + math.sin(TAU * (p * 0.8 + ph)) * 2.5, SMOKE_BY - 10 - p * 24.0 * g - 8.0 * e, r))
    for (x, y, r) in ((-8, -8, 13), (9, -7, 12), (-21, -2, 10), (23, -1, 9), (1, 1, 12)):
        ph = rng.random()
        out.append((SMOKE_BX + x * g + math.cos(TAU * (t + ph)) * 1.2, SMOKE_BY + y - 4 + math.sin(TAU * (t + ph)) * 0.8 - 8.0 * e,
                    r * (0.45 + 0.55 * g) * (1.0 + 0.06 * math.sin(TAU * (t + ph * 2.0))) * _shrink(e, ph)))
    return out


# DİKEY bulut (cadı yukarı/aşağı yürürken): kullanıcı 2026-10-13 "zehir dumanı yukarı ve aşağı pozisyonda kötü oluyor, ona
# göre bir uyumu yok". Yatay bulut 66 px geniş, 35 px yüksek: yan yana dizilince kesintisiz bir şerit olur ama alt alta
# (36 px arayla) dizilince geniş "kaburgalar" gibi durur. Dikey bulut DAR ve DERİN bir öbek (48 x 46): alt alta binince
# cadının arkasında kesintisiz bir sütun olur; sıralar arkadan öne (yukarıdan aşağı) boyanır.
SMOKE_VOX, SMOKE_VOY = 52.0, 46.0  # dikey bulutun orijini (izin merkezi)


def _smoke_puffs_v(g, t, e):
    rng = random.Random(9)
    out = []
    for k in range(2):
        ph, bx, R = (k + rng.random() * 0.5) / 2.0, (-8, 9)[k], rng.uniform(8.0, 9.5)
        p = (t + ph) % 1.0
        r = R * (1.0 - p) ** 0.7 * min(1.0, p / 0.18) * g * _shrink(e, ph)
        out.append((SMOKE_BX + bx * (1.0 - 0.25 * p) * g + math.sin(TAU * (p * 0.8 + ph)) * 2.0, SMOKE_BY - 24 - p * 20.0 * g - 8.0 * e, r))
    for (x, y, r) in ((-9, -19, 10), (8, -20, 9), (-14, -8, 11), (13, -9, 11), (0, -12, 12), (-9, 3, 11), (10, 2, 10), (0, 8, 10)):
        ph = rng.random()
        out.append((SMOKE_BX + x * g + math.cos(TAU * (t + ph)) * 1.2, SMOKE_BY - 4 + (y + 6) * g - 6 + math.sin(TAU * (t + ph)) * 0.8 - 8.0 * e,
                    r * (0.45 + 0.55 * g) * (1.0 + 0.06 * math.sin(TAU * (t + ph * 2.0))) * _shrink(e, ph)))
    return out


def smoke_frame(g, t, e, vert=False):
    """g büyüme (0..1), t döngü evresi, e sönüş (0..1)."""
    cv = Canvas(SMOKE_W, SMOKE_H)
    clean_cloud(cv, (_smoke_puffs_v if vert else _smoke_puffs)(g, t, e), SMKF, scallop=True)
    return cv.rgba.copy()


def smoke_frames(vert=False):
    out = {'in': [], 'loop': [], 'out': []}
    for i in range(SMOKE_IN):
        out['in'].append(smoke_frame(lerp(0.25, 1.0, ease_out((i + 1) / SMOKE_IN)), ((i - SMOKE_IN) % SMOKE_LOOP) / SMOKE_LOOP, 0.0, vert))
    for i in range(SMOKE_LOOP):
        out['loop'].append(smoke_frame(1.0, i / SMOKE_LOOP, 0.0, vert))
    for i in range(SMOKE_OUT):
        out['out'].append(smoke_frame(1.0, (i % SMOKE_LOOP) / SMOKE_LOOP, (i + 1) / (SMOKE_OUT + 0.6), vert))
    return out


# ====================================================================== E: süpürge
BW, BH = 176, 64  # süpürge tuvali (7 yolcuya kadar); karakterin 48x48 hücresinin sol üstü (AX, AY)
AX, AY = 16, 8
MAX_PASS = 7  # 8 kişilik oda: cadı + 7 yolcu
BROOM_Y0, BROOM_H = AY + 26, 24  # oyun sayfasına kırpılan satır aralığı (hücre satırı 26..49)
SEAT = 14  # yolcu başına sap uzaması (karakter pikseli)
SIT_DROP = 2  # binenler süpürgeye göre bu kadar aşağı çizilir (kullanıcı 2026-10-13: "azıcık havada duruyorlar")


def broom_side(n_pass, f):
    """SOLA bakan süpürge (uç solda, saman sağda). Sağ = aynalanır. Tek katman: karakterin ARKASINDA çizilir.
    Toplam boy 48 px (kullanıcı 2026-10-13: "%10 daha kısa olabilir" - 53'ten)."""
    cv = Canvas(BW, BH)
    x0 = AX + 8
    xb = AX + 38 + SEAT * n_pass
    ys = AY + 35
    m = np.zeros((cv.h, cv.w), bool)
    hi = np.zeros_like(m)
    lo = np.zeros_like(m)
    for x in range(x0, xb + 1):
        up = 1 if x < x0 + 8 else 0
        m[ys - up, x] = True
        m[ys + 1 - up, x] = True
        hi[ys - up, x] = True
        lo[ys + 1 - up, x] = True
    cv.put(hi, WOODP[3])
    cv.put(lo, WOODP[1])
    cv.rgba[ys - 1, x0] = (*WOODP[4], 255)
    band = np.zeros_like(m)
    band[ys - 1:ys + 3, xb + 1:xb + 4] = True
    cv.put(band, (150, 40, 44))
    cv.rgba[ys - 1, xb + 1:xb + 4] = (*GOLD[2], 255)
    cv.rgba[ys + 2, xb + 1:xb + 4] = (96, 22, 30, 255)
    br = np.zeros_like(m)
    for i in range(14):
        x = xb + 4 + i
        half = 2.4 + i * 0.4
        yc = ys + 0.5 + i * 0.1
        for y in range(int(math.ceil(yc - half)), int(math.floor(yc + half)) + 1):
            length = 12 + int(round(1.4 * math.sin(TAU * f / 4.0 + y * 1.3)))
            if i <= length:
                br[y, x] = True
                tone = (2, 3, 2, 1, 2, 3, 1)[(y * 3 + 1) % 7]
                if i < 2:
                    tone = 1
                if y <= yc - half + 1.0:
                    tone = min(4, tone + 1)
                cv.rgba[y, x] = (*STRAW[tone], 255)
    cv.put(outline_of(m | band | br) & ~cv.filled(), WOODP[0])
    return cv.rgba.copy()


def _stick(cv, x0, y0, x1, y1):
    m = thick_line(cv, x0, y0, x1, y1, 2.2, WOODP[2])
    cv.put(m & ~np.roll(m, 1, axis=0), WOODP[3])
    cv.put(m & ~np.roll(m, -1, axis=0) & np.roll(m, 1, axis=0), WOODP[1])
    return m


def _fan(cv, bx, by, dx, dy, length, w0, w1, f):
    """Saman yelpazesi: (bx, by) bağ noktasından (dx, dy) yönünde açılır; uçlar kare kare dalgalanır."""
    m = np.zeros((cv.h, cv.w), bool)
    L = math.hypot(dx, dy)
    dx, dy = dx / L, dy / L
    for k2 in range(length * 2 + 1):
        k = k2 * 0.5
        half = lerp(w0, w1, k / length)
        j = -half
        while j <= half + 0.01:
            reach = length - 2.0 + 1.4 * math.sin(TAU * f / 4.0 + j * 1.6)
            if k <= reach:
                x = int(math.floor(bx + dx * k - dy * j + cv.ox))
                y = int(math.floor(by + dy * k + dx * j + cv.oy))
                if 0 <= x < cv.w and 0 <= y < cv.h:
                    tone = (2, 3, 2, 1, 2, 3, 1)[int(round(j * 2 + 40)) % 7]
                    if k < 1.5:
                        tone = 1
                    m[y, x] = True
                    cv.rgba[y, x] = (*STRAW[tone], 255)
            j += 0.5
    return m


def _band(cv, x, y):
    m = circle(cv, x, y, 1.9)
    cv.put(m, (150, 40, 44))
    ppx(cv, x - 0.5, y - 1.0, GOLD[2])
    return m


def broom_down(f):
    """AŞAĞI bakan (kameraya uçar): süpürge DÜZ durur (kullanıcı 2026-10-13: çapraz hali "yamuk duruyor"). Görünen
    tek parça ÖNDE: kucağın altından kameraya uzanan sap (ucu açık renk = bize bakan yüz). Saman gövdenin tam arkasında
    kaldığı için çizilmez (yandan taşan saman uçları denendi, kanat gibi durdu); arka katman boş."""
    back, front = Canvas(BW, BH), Canvas(BW, BH)
    cx = AX + 24
    m = np.zeros((front.h, front.w), bool)
    m[AY + 35:AY + 44, cx - 1:cx + 1] = True
    front.put(m, WOODP[2])
    front.rgba[AY + 35:AY + 44, cx - 1] = (*WOODP[3], 255)
    front.rgba[AY + 35:AY + 44, cx] = (*WOODP[1], 255)
    front.rgba[AY + 42:AY + 44, cx - 1:cx + 1] = (*WOODP[4], 255)
    front.put(outline_of(m) & ~front.filled(), WOODP[0])
    return back.rgba.copy(), front.rgba.copy()


def broom_up(f):
    """YUKARI bakan (kameradan uzaklaşır): süpürge DÜZ; görünen parça ÖNDE: kısa sap + bağ + kameraya dönük saman
    yelpazesi (ayakların altından sarkar). Sap gövdenin arkasında gizli."""
    back, front = Canvas(BW, BH), Canvas(BW, BH)
    cx = AX + 24
    st = np.zeros((front.h, front.w), bool)
    st[AY + 33:AY + 35, cx - 1:cx + 1] = True
    front.put(st, WOODP[2])
    front.rgba[AY + 33:AY + 35, cx - 1] = (*WOODP[3], 255)
    band = np.zeros_like(st)
    band[AY + 35:AY + 37, cx - 2:cx + 2] = True
    front.put(band, (150, 40, 44))
    front.rgba[AY + 35, cx - 2:cx + 2] = (*GOLD[2], 255)
    br = np.zeros_like(st)
    for j in range(9):
        y = AY + 37 + j
        half = 2.0 + j * 0.5
        for x in range(int(math.ceil(cx - half - 0.5)), int(math.floor(cx + half - 0.5)) + 1):
            length = 7 + int(round(1.2 * math.sin(TAU * f / 4.0 + x * 1.3)))
            if j <= length:
                br[y, x] = True
                tone = (2, 3, 2, 1, 2, 3, 1)[(x * 3 + 2) % 7]
                if j < 1:
                    tone = 1
                if x <= cx - half + 0.6:
                    tone = min(4, tone + 1)
                front.rgba[y, x] = (*STRAW[tone], 255)
    front.put(outline_of(st | band | br) & ~front.filled(), WOODP[0])
    return back.rgba.copy(), front.rgba.copy()


def poof_frames():
    frames = []
    n = 8
    rng = random.Random(3)
    stars = [(rng.uniform(0, TAU), rng.uniform(0.8, 1.2)) for _ in range(6)]
    for i in range(n):
        t = (i + 0.5) / n
        cv = Canvas(72, 60)
        burst(cv, 36, 34, 19, t, MAGIC, MAGIC_SOFT, 5, n_puffs=7, squash=0.82, shards=False)
        if 0.1 < t < 0.85:
            for k, (a, sp) in enumerate(stars):
                d = 19 * (0.55 + 0.85 * ease_out(t)) * sp
                size = 2 if t < 0.5 else 1
                star(cv, int(36 + math.cos(a) * d), int(34 + math.sin(a) * d * 0.82 - 4 * t), size, core=WHITE, arm=GOLD[2] if k % 2 else MAGIC[4])
        frames.append(cv.rgba.copy())
    return frames


def spark_frames(col):
    frames = []
    for size in (1, 3, 2, 1, 0):
        cv = Canvas(9, 9)
        star(cv, 4, 4, size, core=WHITE, arm=col, diag=size >= 3)
        frames.append(cv.rgba.copy())
    return frames


# ====================================================================== R: şişeler
def draw_bottle(cv, kind, pal, cx, cy, s=1.0):
    """Dik duran şişe; (cx, cy) şişe merkezi, s ölçek (ikonlar için büyütülür - piksel büyümez, biçim büyür)."""
    X, Y = cv.grid()
    u = (X - cx) / s
    v = (Y - cy) / s
    nw = max(1.05, 0.9 * s) / s  # boyun yarı genişliği
    cork = (np.abs(u) <= nw) & (v >= -6.5) & (v < -4.5)
    if kind == 'round':
        body = u ** 2 + (v - 2.5) ** 2 <= 4.6 ** 2
        neck = (np.abs(u) <= nw) & (v >= -4.5) & (v <= -1.5)
        mid = 2.5
    elif kind == 'vial':
        body = (np.abs(u) <= 3.6) & (v >= -2.0) & (v <= 6.2) & ~((np.abs(u) > 2.6) & ((v < -1.0) | (v > 5.2)))
        neck = (np.abs(u) <= nw) & (v >= -4.5) & (v <= -2.0)
        mid = 2.2
    elif kind == 'bomb':
        body = u ** 2 + (v - 2.0) ** 2 <= 5.2 ** 2
        neck = (np.abs(u) <= 1.6) & (v >= -4.6) & (v <= -2.5)
        cork = np.zeros_like(body)
        mid = 2.0
    elif kind == 'heart':
        hu = u / 4.9
        hv = -(v - 2.6) / 4.9 + 0.1
        body = (hu * hu + hv * hv - 1.0) ** 3 - hu * hu * hv ** 3 <= 0.0
        neck = (np.abs(u) <= nw) & (v >= -4.5) & (v <= -1.2)
        mid = 2.0
    else:  # cone
        body = (v >= -2.0) & (v <= 6.2) & (np.abs(u) <= 1.2 + (v + 2.0) * 0.62) & ~((v > 5.4) & (np.abs(u) > 5.2))
        neck = (np.abs(u) <= nw) & (v >= -4.5) & (v <= -2.0)
        mid = 3.0
    glass = body | neck
    cv.put(glass, GLASS_FILL)
    level = {'round': -1.6, 'vial': -1.4, 'bomb': -2.4, 'heart': -1.8, 'cone': -1.2}[kind]
    liq = body & (v >= level)
    cv.put(liq, pal[2])
    cv.put(liq & (u < -1.2) & (v < mid + 1.5), pal[3])
    inner = erode(body) if s < 1.8 else erode(erode(body))
    cv.put(liq & ~inner & ((u > 0.8) | (v > mid + 2.5)), pal[1])
    cv.put(liq & (v < level + 1.0 / s), pal[4])
    if cork.any():
        cv.put(cork, CORK)
        cv.put(cork & (u > 0.0), CORK_D)
    hs = max(1, int(round(s * 0.7)))
    for k in range(hs + 1):
        for j in range(hs):
            ppx(cv, cx - 2.7 * s + j, cy + (mid - 1.8) * s + k, WHITE)
    if kind == 'bomb':
        for k in range(int(3 * s)):
            ppx(cv, cx + 0.6 * s + k * 0.8, cy - 5.0 * s - k * 0.75, (60, 44, 36))
        star(cv, int(cx + 3.0 * s), int(cy - 6.3 * s), 1 if s < 1.8 else 2, core=WHITE, arm=GOLD[2])
    elif kind == 'heart':
        a = max(1, int(round(s)))
        for d in range(-a, a + 1):
            ppx(cv, cx + d, cy + 2.6 * s, WHITE)
            ppx(cv, cx, cy + 2.6 * s + d, WHITE)
    elif kind == 'cone':
        for sx in (-1.9, 1.9):
            for k in range(max(1, int(s))):
                for j in range(max(1, int(s))):
                    ppx(cv, cx + sx * s + j - (max(1, int(s)) - 1) / 2.0, cy + 3.2 * s + k, pal[4])
    elif kind == 'vial':
        if s >= 1.8:
            star(cv, int(cx), int(cy + 2.4 * s), 2, core=WHITE, arm=pal[4], diag=True)
        else:
            ppx(cv, cx + 1.5, cy + 3.5, pal[4])
            ppx(cv, cx + 0.5, cy + 4.5, pal[4])
    elif kind == 'round':
        for (du, dv) in ((1.0, 1.4), (-0.6, 3.6), (1.8, 4.0)):
            ppx(cv, cx + du * s, cy + dv * s, pal[4])
    cv.put(outline_of(glass | cork) & ~cv.filled(), GLASS_OUT)


def bottle_frames(kind, pal):
    cv = Canvas(18, 18)
    draw_bottle(cv, kind, pal, 9.0, 9.0)
    return [np.rot90(cv.rgba, -k).copy() for k in range(4)]


def shatter_frames(pal, seed):
    rng = random.Random(seed)
    shards = [(rng.uniform(0, TAU), rng.uniform(9, 19), rng.uniform(14, 28)) for _ in range(7)]
    drops = [(rng.uniform(0, TAU), rng.uniform(8, 22), rng.uniform(10, 24)) for _ in range(10)]
    frames = []
    n = 6
    for i in range(n):
        t = (i + 0.5) / n
        cv = Canvas(64, 48)
        cx, cy = 32.0, 34.0
        if i == 0:
            disc_flash(cv, cx, cy - 1, 4.6, core=CREAM, rim=pal[4], squash=0.8)
        else:
            u = (i - 1) / (n - 2)
            ring_r = 4 + 10 * ease_out(u)
            mult = fx.break_mult(cv, cx, cy, 0.5, max(0.0, (u - 0.45) / 0.55), float(seed), lobes=7) if u > 0.45 else None
            ring_band(cv, cx, cy, ring_r + 2, max(1.2, 3.6 - 2.6 * u), pal, squash=0.5, mult=mult)
            if u < 0.55:
                puffs(cv, [(cx, cy - 1 - 3 * u, 4.6 * (1.0 - u * 1.6)), (cx - 3, cy - 2 * u, 3.0 * (1.0 - u * 1.7)), (cx + 3, cy - 1, 2.8 * (1.0 - u * 1.7))], pal, squash=0.85)
        for (a, vh, vv) in drops:
            x = cx + math.cos(a) * vh * t
            y = cy + math.sin(a) * vh * 0.5 * t - vv * t + 30 * t * t
            if t < 0.85:
                ppx(cv, x, y, pal[3])
                if t < 0.5:
                    ppx(cv, x + 1, y, pal[2])
                    ppx(cv, x, y + 1, pal[1])
        for (a, vh, vv) in shards:
            x = cx + math.cos(a) * vh * t * 1.2
            y = cy + math.sin(a) * vh * 0.5 * t - vv * t * 1.1 + 34 * t * t
            if t < 0.7:
                ppx(cv, x, y, WHITE)
                ppx(cv, x + 1, y + (1 if int(a * 3) % 2 else 0), GLASS_FILL)
        frames.append(cv.rgba.copy())
    return frames


# ====================================================================== R: alanlar
ZW, ZH = 160, 108
ZCX, ZCY = 80.0, 70.0
RX, RY = 58.0, 30.0
Z_IN, Z_LOOP, Z_OUT = 5, 8, 6
ZONE_ALPHA = [0.9, 0.9, 1.0, 1.0, 0.88]  # iksir sırasıyla (3 = patlama, alan yok); oyunda da aynı saydamlık


def zparams(state, i):
    if state == 'in':
        return lerp(0.3, 1.0, ease_out((i + 1) / Z_IN)), ((i - Z_IN) % Z_LOOP) / Z_LOOP, 0.0
    if state == 'loop':
        return 1.0, i / Z_LOOP, 0.0
    return 1.0, (i % Z_LOOP) / Z_LOOP, (i + 1) / (Z_OUT + 1.0)


def _erode_noise(cv, e, seed):
    if e > 0.0:
        holes = fx.value_noise(cv, 18, seed) < 0.18 + e * 0.78
        cv.rgba[holes] = 0


def _plus(cv, x, y, arm):
    x, y = int(x), int(y)
    pts = [(x, y)]
    for d in range(1, arm + 1):
        pts += [(x + d, y), (x - d, y), (x, y + d), (x, y - d)]
    m = np.zeros((cv.h, cv.w), bool)
    for (px_, py_) in pts:
        if 0 <= px_ < cv.w and 0 <= py_ < cv.h:
            m[py_, px_] = True
    cv.put(outline_of(m), HEAL[0])
    cv.put(m, HEAL[4])
    if 0 <= x < cv.w and 0 <= y < cv.h:
        cv.rgba[y, x] = (*WHITE, 255)


_HEAL_PLUS = [(-34, 6), (-14, -10), (8, 12), (26, -4), (-22, 14), (38, 8), (2, -14)]


_SKULL = ["..wwwww..", ".wwwwwww.", "wwwwwwwww", "wddwwwddw", "wddwwwddw", "wwwwdwwww", ".wwwwwww.", "..wdwdw..", "..wwwww.."]


def _skull(cv, x, y, fade, by):
    x, y = int(x), int(y)
    m = np.zeros((cv.h, cv.w), bool)
    dk = np.zeros_like(m)
    for r, row in enumerate(_SKULL):
        for c, ch in enumerate(row):
            xx, yy = x - 4 + c, y - 4 + r
            if ch != '.' and 0 <= xx < cv.w and 0 <= yy < cv.h and by[yy, xx] >= fade:
                m[yy, xx] = True
                dk[yy, xx] = ch == 'd'
    if not m.any():
        return
    if fade < 0.3:
        cv.put(outline_of(m) & ~m, FEAR[0])
    cv.put(m & ~dk, BONE)
    cv.put(m & ~dk & (np.roll(m, -1, axis=1) == 0), FEAR[4])
    cv.put(dk, FEAR[0])


def _fear_layout():
    rng = random.Random(31)
    items = []
    n = 12
    for k in range(n):
        a = TAU * k / n + rng.uniform(-0.12, 0.12)
        items.append((math.cos(a) * RX * 0.72, math.sin(a) * RY * 0.62, rng.uniform(12, 17), rng.random(), rng.random()))
    for (x, y, r) in ((-22, -2, 20), (0, 4, 22), (22, -3, 20), (-6, -8, 17), (10, 8, 17), (-36, 5, 15), (36, 6, 15)):
        items.append((x, y, r, rng.random(), rng.random()))
    return items


def zone_fear(state, i):
    g, t, e = zparams(state, i)
    cv = Canvas(ZW, ZH)
    circles = []
    for (x, y, r, p1, p2) in _fear_layout():
        xx = ZCX + x * g + math.cos(TAU * (t + p1)) * 2.4
        yy = ZCY + y * g + math.sin(TAU * (t + p1)) * 1.1 - 4.0 * e
        rr = r * (0.4 + 0.6 * g) * (1.0 + 0.1 * math.sin(TAU * (t + p2))) * (1.0 - 0.25 * e)
        circles.append((xx, yy, rr))
    soft_cloud(cv, circles, FEARM, t, 61, squash=0.6, erosion=e, edge=0.26)
    # sisin içinde yanıp sönen gözler
    if g > 0.8 and e < 0.3:
        for k, (ex, ey) in enumerate(((-16, 6), (20, -6), (40, 4), (-40, -2))):
            ph = (int(round(t * 8)) + k * 3) % 8
            if ph < 3:
                for sx in (-2, 1):
                    ppx(cv, ZCX + ex + sx, ZCY + ey, (255, 96, 120) if ph == 1 else (188, 52, 92))
    if g > 0.75 and e < 0.5:
        by = bayer(cv)
        for k, (sx, sy) in enumerate(((-28, 2), (4, -4), (30, 4))):
            p = (t + k / 3.0) % 1.0
            x = ZCX + sx + math.sin(TAU * p + k * 2) * 2.0
            y = ZCY + sy - 8 - p * 26
            fade = max(0.0, (p - 0.55) / 0.45) + e
            for q in range(1, 7):
                if q * 0.14 < 1.0 - fade:
                    ppx(cv, x + math.sin(q * 0.9 + TAU * p) * 1.2, y + 4 + q, FEAR[3] if q < 4 else FEAR[2])
            _skull(cv, x, y, fade, by)
    return cv.rgba.copy()


# ---- sis alanlarının paletleri + simgeleri
MADM = [(40, 8, 34), (116, 20, 88), (184, 42, 132), (232, 92, 172), (255, 158, 212)]
ICEM = [(30, 60, 120), (98, 150, 214), (150, 198, 242), (204, 232, 252), (246, 252, 255)]
_FLAKE = ["...#...", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "...#..."]


def _mixc(a, b, k):
    return tuple(int(round(a[j] + (b[j] - a[j]) * k)) for j in range(3))


def _spiral_bold(cv, x, y, R, phase, core, dark):
    """Dönen hipnoz sarmalı: açık çizgi + koyu kontur (çimende de sıvının üstünde de okunur)."""
    m = np.zeros((cv.h, cv.w), bool)
    n = int(R * 16)
    for q in range(n):
        sv = q / float(n)
        th = phase + sv * TAU * 1.5
        r = R * (0.12 + 0.88 * sv)
        iy, ix = cv.idx(x + math.cos(th) * r - 0.5, y + math.sin(th) * r - 0.5)
        if 0 <= ix < cv.w and 0 <= iy < cv.h:
            m[iy, ix] = True
    cv.put(outline_of(m) & ~m, dark)
    cv.put(m, core)


def _stamp(cv, x, y, rows, core, dark):
    h, w = len(rows), len(rows[0])
    m = np.zeros((cv.h, cv.w), bool)
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            iy, ix = cv.idx(x - w // 2 + c, y - h // 2 + r)
            if ch == '#' and 0 <= ix < cv.w and 0 <= iy < cv.h:
                m[iy, ix] = True
    cv.put(outline_of(m) & ~m, dark)
    cv.put(m, core)


def _dizzy(cv, t, yoff=-32):
    for k in range(4):
        ang = TAU * (k / 4.0 + t / 2.0)
        x = ZCX + math.cos(ang) * 36
        y = ZCY + yoff + math.sin(ang) * 9
        col = GOLD[2] if k % 2 else MAD[3]
        if math.sin(ang) > 0:
            star(cv, int(x), int(y), 2, core=WHITE, arm=col, diag=True)
        else:
            star(cv, int(x), int(y), 1, core=col, arm=col)


def _rising_spirals(cv, t, e):
    for k, (sx, sy) in enumerate(((-30, 2), (4, -6), (32, 6))):
        pq = (t + k / 3.0) % 1.0
        R = 4.6 if pq < 0.6 else 4.6 * (1.0 - (pq - 0.6) / 0.4 * 0.6)
        if R > 1.6 and e < 0.45:
            _spiral_bold(cv, ZCX + sx + math.sin(TAU * pq + k) * 2.0, ZCY + sy - 10 - pq * 24, R, -TAU * t * 2 + k, MAD[4], MAD[0])




def _mist_circles(g, t, e, ring_r=14.5, spin=True):
    circles = []
    n = 12
    for k in range(n):
        a = TAU * (k + (t if spin else 0.0)) / n  # bir döngüde bir yuva döner (eş toplar -> dikişsiz)
        circles.append((ZCX + math.cos(a) * RX * 0.7 * g, ZCY + math.sin(a) * RY * 0.6 * g - 4.0 * e, ring_r * (0.4 + 0.6 * g) * (1.0 - 0.25 * e)))
    for (x, y, r, p1, p2) in _fear_layout()[12:]:
        circles.append((ZCX + x * g + math.cos(TAU * (t + p1)) * 2.4, ZCY + y * g + math.sin(TAU * (t + p1)) * 1.1 - 4.0 * e,
                        r * (0.4 + 0.6 * g) * (1.0 + 0.1 * math.sin(TAU * (t + p2))) * (1.0 - 0.25 * e)))
    return circles


def zone_mad(state, i):
    """Delilik: kendi etrafında dönen pembe sis (Korku sisiyle aynı dil). İçinden dönen hipnoz sarmalları yükselir,
    üstünde baş dönmesi yıldızları döner."""
    g, t, e = zparams(state, i)
    cv = Canvas(ZW, ZH)
    soft_cloud(cv, _mist_circles(g, t, e), MADM, t, 91, squash=0.6, erosion=e, edge=0.26)
    if g > 0.75 and e < 0.5:
        _rising_spirals(cv, t, e)
        _dizzy(cv, t)
    return cv.rgba.copy()


def zone_ice(state, i):
    """Don: kırağı tutmuş zemin + dönen buz sisi (tipi). Kar taneleri sisin çevresinde döner, rüzgâr çizgileri akar."""
    g, t, e = zparams(state, i)
    cv = Canvas(ZW, ZH)
    X, Y = cv.grid()
    by = bayer(cv)
    d = np.sqrt(((X - ZCX) / (RX * g)) ** 2 + ((Y - ZCY) / (RY * g)) ** 2)
    th = np.arctan2((Y - ZCY) / RY, (X - ZCX) / RX)
    cv.put((d < 1.04) & (by < np.clip(1.1 - d, 0, 1) * 0.6 * (1.0 - e) ** 1.5), FROST[4])
    soft_cloud(cv, _mist_circles(g, t, e, ring_r=13.0), ICEM, t, 97, squash=0.6, erosion=e, edge=0.3)
    if g > 0.75 and e < 0.5:
        for k in range(3):
            a0 = TAU * (k + t) / 3.0
            rk = (0.55, 0.8, 0.95)[k]
            rel = np.mod(th - a0, TAU)
            cv.put((np.abs(d - rk) < 0.022) & (rel < 0.85), WHITE)
        for k in range(6):
            ang = TAU * (k + 2.0 * t) / 6.0
            x = ZCX + math.cos(ang) * RX * 0.78
            y = ZCY + math.sin(ang) * RY * 0.78 - 14 - 5 * math.sin(ang * 2.0)
            if k % 2 == 0:
                _stamp(cv, x, y, _FLAKE, WHITE, ICE[1])
            else:
                star(cv, int(x), int(y), 1, core=WHITE, arm=FROST[3], diag=True)
    return cv.rgba.copy()


def zone_heal(state, i):
    """Şifa: ışık çemberi. Alanın kenarından yukarı dalgalanarak yükselen ışık ışınları (arka yarı soluk, ön yarı
    parlak - alan bir ışık silindiri gibi durur), içi neredeyse boş (zemin görünür), yükselen artılar + altın zerreler."""
    g, t, e = zparams(state, i)
    cv = Canvas(ZW, ZH)
    X, Y = cv.grid()
    Xi, Yi = ipix(cv)
    by = bayer(cv)
    rx, ry = RX * g, RY * g
    d = np.sqrt(((X - ZCX) / rx) ** 2 + ((Y - ZCY) / ry) ** 2)
    fade = (1.0 - e) ** 1.3
    cv.put((d < 0.96) & (by < 0.13 * fade), HEAL[2])
    cv.put((d < 0.96) & (np.abs(d - t) < 0.05) & ((Xi + Yi) % 2 == 0) & (e < 0.01), HEAL[3])

    def rays(front):
        for xi in range(int(ZCX - rx) + 1, int(ZCX + rx)):
            if xi % 2:
                continue
            u = (xi + 0.5 - ZCX) / rx
            if abs(u) >= 1.0:
                continue
            yr = ZCY + (1 if front else -1) * ry * math.sqrt(1.0 - u * u)
            hgt = 10.0 + 7.0 * math.sin(xi * 0.55 + TAU * t) + 5.0 * math.sin(xi * 0.21 - TAU * t + (0.0 if front else 2.0))
            hgt = max(0.0, hgt) * fade * min(1.0, g * 1.2) * (1.0 if front else 0.8)
            for q in range(int(hgt)):
                a = q / max(1.0, hgt)
                if a > 0.7 and q % 2:
                    continue
                if front:
                    col = HEAL[4] if a < 0.3 else (HEAL[3] if a < 0.65 else HEAL[2])
                else:
                    col = HEAL[3] if a < 0.3 else HEAL[2]
                iy, ix = cv.idx(xi, yr - q)
                if 0 <= ix < cv.w and 0 <= iy < cv.h:
                    cv.rgba[iy, ix] = (*col, 255)

    rays(False)
    cv.put((np.abs(d - 1.0) < 0.022) & (by < 0.9 * fade), HEAL[3])
    rays(True)
    if g > 0.75 and e < 0.45:
        for k, (px_, py_) in enumerate(_HEAL_PLUS):
            pq = (t + (k * 3 % 7) / 7.0) % 1.0
            arm = 3 if pq < 0.45 else (2 if pq < 0.75 else (1 if pq < 0.92 else 0))
            _plus(cv, ZCX + px_, ZCY + py_ - 6 - pq * 28, arm)
        for k in range(6):
            pq = (t + k / 6.0) % 1.0
            ang = TAU * (pq + k / 6.0)
            star(cv, int(ZCX + math.cos(ang) * RX * 0.6), int(ZCY + math.sin(ang) * RY * 0.6 - 6 - pq * 24), 1 if pq < 0.7 else 0, core=WHITE, arm=GOLD[3])
    return cv.rgba.copy()


def mad_status_frames():
    """Delirmiş yaratığın başının üstündeki gösterge (enemy.gd apply_madness -> fx_cadi_mad_status.gd): dönen hipnoz sarmalı +
    çevresinde dönen iki baş dönmesi yıldızı. 20x16, 8 kare döngü (oyunda TEXEL 1,212 - yaratık göstergeleriyle aynı doku)."""
    frames = []
    for f in range(8):
        t = f / 8.0
        cv = Canvas(20, 16)
        for k in range(2):
            ang = TAU * (k / 2.0 + t)
            if math.sin(ang) <= 0:
                star(cv, int(10 + math.cos(ang) * 7.5), int(8 + math.sin(ang) * 2.5), 1, core=GOLD[2], arm=GOLD[2])
        _spiral_bold(cv, 10.0, 8.0, 4.4, -TAU * t, MAD[4], MAD[0])
        for k in range(2):
            ang = TAU * (k / 2.0 + t)
            if math.sin(ang) > 0:
                star(cv, int(10 + math.cos(ang) * 7.5), int(8 + math.sin(ang) * 2.5), 1, core=WHITE, arm=GOLD[2])
        frames.append(cv.rgba.copy())
    return frames


def zone_frames(fn):
    return {'in': [fn('in', i) for i in range(Z_IN)], 'loop': [fn('loop', i) for i in range(Z_LOOP)], 'out': [fn('out', i) for i in range(Z_OUT)]}


BOOM_W, BOOM_H = 176, 164
SMOKE_WARM = [(40, 34, 40), (78, 68, 72), (122, 108, 106), (170, 154, 146), (216, 202, 188)]
BOOM_N = 12


def boom_frames():
    """Patlama (tek sefer): parlama -> dolu ateş topu -> yükselip küçülen duman topları + zeminde şok halkası + közler."""
    rng = random.Random(4)
    frames = []
    cx, cy, R = BOOM_W / 2.0, 88.0, 50.0
    blobs = [(TAU * k / 7 + rng.uniform(-0.2, 0.2), rng.uniform(0.8, 1.1), rng.uniform(0.85, 1.15), rng.random()) for k in range(7)]
    blobs += [(rng.uniform(0, TAU), rng.uniform(0.1, 0.4), rng.uniform(1.0, 1.25), rng.random()) for _ in range(3)]
    embers = [(rng.uniform(0, TAU), rng.uniform(0.7, 1.25), rng.uniform(0.2, 0.9)) for _ in range(14)]
    for i in range(BOOM_N):
        t = (i + 0.5) / BOOM_N
        cv = Canvas(BOOM_W, BOOM_H)
        if t > 0.08:
            u = (t - 0.08) / 0.92
            shock_ring(cv, cx, cy + 8, 20 + 50 * ease_out(u), max(1.5, 5.0 * (1.0 - u)), u, FIRE, 0.5, 3.0)
        if t < 0.1:
            disc_flash(cv, cx, cy, R * 0.36, core=CREAM, rim=FIRE[4], squash=0.9)
            for q in range(8):
                a = q * TAU / 8
                for d in range(int(R * 0.36) + 1, int(R * (0.62 if q % 2 else 0.5))):
                    ppx(cv, cx + math.cos(a) * d, cy + math.sin(a) * d * 0.9, FIRE[4] if d < R * 0.48 else FIRE[3])
            frames.append(cv.rgba.copy())
            continue
        u = (t - 0.1) / 0.9
        spread = ease_out(min(1.0, u * 1.7))
        rise = R * 0.4 * max(0.0, u - 0.25)
        circles = []
        for (a, dk, rk, dl) in blobs:
            shrink = 1.0 - min(1.0, max(0.0, (u - 0.42 - dl * 0.22) / 0.5)) ** 1.4
            r = R * (0.3 + 0.13 * spread) * rk * shrink
            d = R * (0.14 + 0.5 * spread) * dk
            circles.append((cx + math.cos(a) * d, cy + math.sin(a) * d * 0.85 - rise * (0.6 + 0.8 * dl), r))
        if u < 0.4:
            m = puffs(cv, circles, FIRE, squash=0.92)
        else:
            # duman: kontursuz, dither kenarlı (kaya gibi durmasın); ortada kısa süre sönen ateş çekirdeği
            k = (u - 0.4) / 0.6
            m = soft_cloud(cv, [(x, y, r * 1.12) for (x, y, r) in circles], SMOKE_WARM, k * 0.5, 71, squash=0.92, erosion=k * 0.8, edge=0.24)
            if k < 0.4:
                puffs(cv, [(cx + math.cos(a) * R * 0.2 * dk, cy - rise + math.sin(a) * R * 0.16, R * 0.22 * rk * (1.0 - k * 2.4)) for (a, dk, rk, _dl) in blobs[:5]],
                      [FIRE[0], FIRE[1], FIRE[1], FIRE[2], FIRE[3]], squash=0.9)
        if u < 0.3:
            X, Y = cv.grid()
            cv.put(m & (np.hypot(X - cx, (Y - cy) / 0.9) < R * (0.34 - 0.9 * u)), CREAM)
        if u < 0.8:
            for (a, sp, up_) in embers:
                d = R * (0.5 + 0.75 * spread) * sp
                x = cx + math.cos(a) * d
                y = cy + math.sin(a) * d * 0.8 - up_ * 18 * u + 22 * u * u
                ppx(cv, x, y, FIRE[4] if u < 0.4 else FIRE[3])
                if u < 0.45:
                    ppx(cv, x - math.cos(a), y - math.sin(a) * 0.8, FIRE[2])
        frames.append(cv.rgba.copy())
    return frames


# ====================================================================== ikonlar
def _emblem():
    return Canvas(48, 48)


def _finish_icon(base, cv, fxl=None):
    em = Image.fromarray(cv.rgba, 'RGBA')
    base.alpha_composite(em)
    if fxl is not None:
        base.alpha_composite(Image.fromarray(fxl.rgba, 'RGBA'))
    return base


def icon_passive():
    base = itile(C('#1f4a2a'), C('#08160e'), C('#2f7a3c'), C('#7ac884'), C('#040a06'), glow_center=(24, 22))
    cv = _emblem()
    X, Y = cv.grid()
    cx, cy = 24.0, 21.0
    # sap
    for k in range(12):
        ppx(cv, cx + 1 + k * 0.55 + math.sin(k * 0.5) * 1.2, cy + 6 + k, HEAL[1])
        ppx(cv, cx + 2 + k * 0.55 + math.sin(k * 0.5) * 1.2, cy + 6 + k, HEAL[0])
    leaf = np.zeros((48, 48), bool)
    for (ox, oy) in ((-5.6, -5.6), (5.6, -5.6), (-5.6, 5.6), (5.6, 5.6)):
        a = math.atan2(oy, ox)
        for s in (-1, 1):
            leaf |= circle(cv, cx + ox + math.cos(a + s * math.pi / 2) * 2.6, cy + oy + math.sin(a + s * math.pi / 2) * 2.6, 4.4)
        leaf |= circle(cv, cx + ox * 0.5, cy + oy * 0.5, 3.4)
    cv.put(leaf, HEAL[2])
    lit = leaf & ((X - cx) + (Y - cy) < -1.0)
    cv.put(lit, HEAL[3])
    cv.put(leaf & ~erode(leaf) & ((X - cx) + (Y - cy) > 4.0), HEAL[1])
    for (ox, oy) in ((-5.6, -5.6), (5.6, -5.6), (-5.6, 5.6), (5.6, 5.6)):
        for q in range(2, 8):
            ppx(cv, cx + ox * q / 7.5, cy + oy * q / 7.5, HEAL[1])
    cv.put(circle(cv, cx - 7, cy - 8, 1.6), HEAL[4])
    cv.put(outline_of(cv.filled()) & ~cv.filled(), (10, 26, 12))
    f2 = _emblem()
    star(f2, 37, 10, 3, core=WHITE, arm=GOLD[3], diag=True)
    star(f2, 10, 34, 2, core=WHITE, arm=GOLD[3])
    star(f2, 39, 30, 1, core=GOLD[4], arm=GOLD[2])
    return _finish_icon(base, cv, f2)


def icon_q():
    base = itile(C('#2c1a4a'), C('#0c0716'), C('#3e6a2a'), C('#8a6ac0'), C('#06030c'), glow_center=(26, 20), glow_r=(16, 14))
    cv = _emblem()
    soft_cloud(cv, [(28, 18, 7.0), (34, 13, 8.5), (38, 21, 6.5), (30, 9, 6.0), (40, 9, 5.0), (22, 13, 4.2), (21, 22, 3.0)], SMK, 0.2, 51, squash=0.95, edge=0.3)
    draw_bottle(cv, 'round', POISON, 17.0, 31.0, s=2.0)
    f2 = _emblem()
    star(f2, 41, 31, 1, core=WHITE, arm=TOXIC_MOTE)
    star(f2, 10, 13, 1, core=WHITE, arm=TOXIC_MOTE)
    ppx(f2, 33.5, 30.5, TOXIC_MOTE)
    return _finish_icon(base, cv, f2)


def icon_e():
    base = itile(C('#1c2a5a'), C('#080a1c'), C('#3a4a9a'), C('#7a8ad8'), C('#04050e'), glow_center=(24, 22))
    cv = _emblem()
    X, Y = cv.grid()
    moon = circle(cv, 12, 12, 6.5) & ~circle(cv, 14.6, 10.4, 5.6)
    cv.put(moon, GOLD[3])
    cv.put(moon & ~erode(moon) & (Y > 12), GOLD[2])
    # uç sağ üstte (uçuş yönü), saman sol altta
    _stick(cv, 19, 30, 41, 12)
    _fan(cv, 18.0, 30.5, -1.0, 0.8, 12, 2.2, 6.0, 1)
    _band(cv, 19.0, 30.0)
    cv.put(outline_of(cv.filled()) & ~cv.filled(), (16, 12, 24))
    f2 = _emblem()
    star(f2, 36, 30, 2, core=WHITE, arm=GOLD[3])
    star(f2, 27, 9, 1, core=WHITE, arm=MAGIC[3])
    star(f2, 40, 39, 1, core=WHITE, arm=MAGIC[3])
    return _finish_icon(base, cv, f2)


def icon_r(which=None):
    if which is None:
        base = itile(C('#3a1c4e'), C('#100618'), C('#6a3a8a'), C('#a47ac8'), C('#07030c'), glow_center=(24, 24), glow_r=(17, 14))
        cv = _emblem()
        draw_bottle(cv, 'vial', ICE, 12.5, 23.0, s=1.6)
        draw_bottle(cv, 'bomb', fx.EMBER, 35.5, 24.0, s=1.5)
        draw_bottle(cv, 'round', MAD, 24.0, 29.0, s=2.1)
        f2 = _emblem()
        star(f2, 38, 9, 2, core=WHITE, arm=GOLD[3])
        star(f2, 9, 10, 1, core=WHITE, arm=MAD[3])
        return _finish_icon(base, cv, f2)
    kind, pal, _name = POTIONS[which]
    dark = tuple(int(c * 0.42) for c in pal[1])
    top = tuple(int(c * 0.75) for c in pal[1])
    base = itile((*top, 255), (*tuple(int(c * 0.3) for c in dark), 255), (*pal[2], 255), (*pal[3], 255), (*tuple(int(c * 0.2) for c in dark), 255),
                 glow_center=(24, 25), glow_r=(15, 14))
    cv = _emblem()
    draw_bottle(cv, kind, pal, 24.0, 25.5, s=2.6)
    f2 = _emblem()
    star(f2, 38, 10, 2, core=WHITE, arm=pal[4])
    star(f2, 9, 36, 1, core=WHITE, arm=pal[4])
    return _finish_icon(base, cv, f2)


# ====================================================================== önizleme sahneleri
def load_game_sheet(key, name):
    a = np.array(Image.open(os.path.join(PROJECT, 'assets', 'characters', key, 'sheets', name + '.png')).convert('RGBA'))
    return [[a[r * 48:(r + 1) * 48, c * 48:(c + 1) * 48] for c in range(a.shape[1] // 48)] for r in range(4)]


def blit(dst, src, x, y, alpha=1.0, flip=False):
    if flip:
        src = src[:, ::-1]
    x, y = int(round(x)), int(round(y))
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x].astype(np.float32)
    a = s[:, :, 3:4] / 255.0 * alpha
    d = dst[y0:y1, x0:x1].astype(np.float32)
    dst[y0:y1, x0:x1] = (d * (1 - a) + s[:, :, :3] * a + 0.5).astype(np.uint8)


def grass(w, h, seed=1):
    rng = np.random.default_rng(seed)
    a = np.empty((h, w, 3), np.uint8)
    a[:] = (112, 160, 78)
    n = rng.random((h, w))
    a[n > 0.94] = (122, 170, 86)
    a[n < 0.06] = (103, 150, 72)
    return a


def shadow(dst, cx, cy, rx, ry):
    H, W = dst.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    m = ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0
    dst[m] = (dst[m].astype(np.float32) * 0.68).astype(np.uint8)


def up(a, z):
    return Image.fromarray(np.repeat(np.repeat(a, z, 0), z, 1), 'RGB')


def label(im, x, y, text, size=15, fill=(255, 255, 255)):
    d = ImageDraw.Draw(im)
    f = font(size)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        d.text((x + dx, y + dy), text, font=f, fill=(20, 28, 16))
    d.text((x, y), text, font=f, fill=fill)


def save_gif(ims, path, ms):
    step = max(1, len(ims) // 8)
    sample = ims[::step][:8]
    mont = Image.new('RGB', (sample[0].width * len(sample), sample[0].height))
    for i, s in enumerate(sample):
        mont.paste(s, (i * s.width, 0))
    pal = mont.quantize(255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = [im.quantize(palette=pal, dither=Image.Dither.NONE) for im in ims]
    out[0].save(path, save_all=True, append_images=out[1:], duration=ms, loop=0, optimize=False)
    print('  ', os.path.relpath(path, PROJECT), '%d kare' % len(ims), '%.0f KB' % (os.path.getsize(path) / 1024.0))


def char_at(dst, frame, fx_, fy, flip=False):
    """Karakter karesi: ayak (hücre satırı 40, sütun 24) (fx_, fy)'de."""
    blit(dst, frame, fx_ - 24, fy - 40, flip=flip)


# ---------------------------------------------------------------------- Q sahnesi
def scene_q(walk, potion, stream, smoke):
    Z = 3
    fps = 20
    n = 72  # 3,6 sn: bulut aralığının (8 kare) ve yürüme döngüsünün (12 kare) katı -> dikişsiz
    W, H = 328, 96
    speed = W / n  # 4,56 px/kare = 91 sanat px/sn (82 dünya/sn)
    drop_every = 8  # 0,4 sn
    life = 3.0  # önizlemede; oyunda 6 sn
    bot_dx, bot_dy = -15, -27  # şişe gövde merkezi (cadının ayağına göre) - cadi_math.gd POTION_BODY_SIDE_ART
    land_dx, land_dy = bot_dx + POT_DROP[0], bot_dy + POT_DROP[1]  # duman akışının yere indiği nokta = bulutun orijini
    (smx, smy), _flow = ST_POSES['side']
    mouth = POT_MOUTH * 0.70711
    ims = []
    key = None
    for f in range(n):
        dst = grass(W, H)
        wx = (40 + f * speed) % W
        wy = 70
        bob = round(math.sin(TAU * f / 24.0) * 1.5)
        for off in (-W, 0, W):
            shadow(dst, wx + off, wy + 1, 8, 2.6)
            bcx, bcy = wx + off + bot_dx, wy + bot_dy + bob
            blit(dst, stream[(f // 2) % 8], bcx - mouth - smx, bcy + mouth - smy, alpha=0.9)
            blit(dst, potion[(f // 2) % 8], bcx - POT_CX, bcy - POT_CY)
            char_at(dst, walk[2][(f // 2) % 6], wx + off, wy)
        clouds = []
        for back in range(n):
            ff = f - back
            if ff % drop_every != 0:
                continue
            age = back / fps
            if age > life:
                break
            clouds.append((age, ((40 + ff * speed) % W) + land_dx, (ff % n) // drop_every))
        for (age, cxp, ci) in sorted(clouds, reverse=True):
            fi = int(age * 10 + 1e-6)
            t_out = life - SMOKE_OUT / 10.0
            if fi < SMOKE_IN:
                fr = smoke['in'][fi]
            elif age >= t_out:
                fr = smoke['out'][min(SMOKE_OUT - 1, int((age - t_out) * 10 + 1e-6))]
            else:
                fr = smoke['loop'][(fi - SMOKE_IN) % SMOKE_LOOP]
            flip = random.Random(ci * 7 + 3).random() < 0.5  # oyunda: bulut başına rastgele aynalama
            for off in (-W, 0, W):
                blit(dst, fr, cxp + off - SMOKE_OX, wy + land_dy - SMOKE_OY, alpha=0.5, flip=flip)
        im = up(dst, Z)
        label(im, 8, 6, 'Q · Zehirli Duman  (karakterlerin üstünde %50; bulut burada 3 sn, oyunda 6 sn; gerçek yürüme hızı)', 15)
        ims.append(im)
        if f == n // 2:
            key = im
    save_gif(ims, os.path.join(OUT, 'cadi_q.gif'), 1000 // fps)
    return key


# ---------------------------------------------------------------------- E sahnesi
def scene_e(sit, idle, pass1, pass2, poof, spark_g, spark_m):
    Z = 4
    PW, PH = 72, 76
    fps = 10
    n = 16
    widths2 = (72, 100, 116)
    W = PW * 4
    H = PH * 2
    ims = []
    key = None
    rng = random.Random(9)
    sparks = {k: [] for k in range(7)}
    for f in range(n + 8):  # ilk 8 kare ısınma (parıltılar dolsun)
        dst = grass(W, H, 2)
        bob = round(math.sin(TAU * f / 16.0) * 1.5)
        lift = 8 + bob
        ff = f % 4

        def trail(pid, sx, sy, vx, vy):
            if f % 2 == 0:
                sparks[pid].append([sx + rng.uniform(-2, 2), sy + rng.uniform(-3, 3), 0, rng.random() < 0.5])
            for s in sparks[pid]:
                fr = (spark_g if s[3] else spark_m)[min(4, s[2])]
                blit(dst, fr, s[0] - 4, s[1] - 4)
                s[0] += vx
                s[1] += vy
                s[2] += 1
            sparks[pid][:] = [s for s in sparks[pid] if s[2] < 5]

        # --- üst sıra: 4 yön
        for p, d in enumerate(('down', 'left', 'right', 'up')):
            ox = p * PW
            fxp, fyp = ox + PW // 2, 58
            shadow(dst, fxp, fyp + 1, 9, 3)
            cx0, cy0 = fxp - 24 - AX, fyp - 40 - AY - lift
            if d == 'down':
                back, front = broom_down(ff)
                trail(p, fxp, fyp - 26 - lift, 0, -3.5)
                blit(dst, back, cx0, cy0)
                char_at(dst, sit[0][3], fxp, fyp - lift + SIT_DROP)
                blit(dst, front, cx0, cy0)
            elif d == 'up':
                back, front = broom_up(ff)
                blit(dst, back, cx0, cy0)
                char_at(dst, sit[3][3], fxp, fyp - lift + SIT_DROP)
                blit(dst, front, cx0, cy0)
                trail(p, fxp, fyp + 8 - lift, 0, 3.5)
            elif d == 'left':
                trail(p, fxp + 31, fyp - 4 - lift, 4.5, 0)
                blit(dst, broom_side(0, ff), cx0, cy0)
                char_at(dst, sit[1][3], fxp, fyp - lift + SIT_DROP)
            else:
                trail(p, fxp - 31, fyp - 4 - lift, -4.5, 0)
                blit(dst, broom_side(0, ff), fxp - 24 - (BW - AX - 48), cy0, flip=True)
                char_at(dst, sit[2][3], fxp, fyp - lift + SIT_DROP)
        # --- alt sıra: biniş, 1 yolcu, 2 yolcu
        oy = PH
        # biniş
        fxp, fyp = 36, oy + 58
        shadow(dst, fxp, fyp + 1, 9, 3)
        g = f % n
        riding = g >= 7
        if riding:
            blit(dst, broom_side(0, ff), fxp - 24 - AX, fyp - 40 - AY - lift)
            char_at(dst, sit[1][3], fxp, fyp - lift + SIT_DROP)
        else:
            char_at(dst, idle[1][g % 4], fxp, fyp)
        if 4 <= g < 12:
            blit(dst, poof[g - 4], fxp - 36, fyp - 16 - 34)
        # yolcular
        x_acc = widths2[0]
        for pi, npass in enumerate((1, 2)):
            pw = widths2[pi + 1]
            fxp = x_acc + 30
            fyp = oy + 58
            for k in range(npass + 1):
                shadow(dst, fxp + k * SEAT, fyp + 1, 9, 3)
            trail(4 + pi, fxp + 31 + npass * SEAT, fyp - 4 - lift, 4.5, 0)
            blit(dst, broom_side(npass, ff), fxp - 24 - AX, fyp - 40 - AY - lift)
            riders = [sit[1][3], pass1[1][3], pass2[1][3]][:npass + 1]
            for k in reversed(range(npass + 1)):
                char_at(dst, riders[k], fxp + k * SEAT, fyp - lift + SIT_DROP)
            x_acc += pw
        if f < 8:
            continue
        im = up(dst, Z)
        for p, t in enumerate(('aşağı', 'sol', 'sağ', 'yukarı')):
            label(im, p * PW * Z + 8, 6, t, 15)
        label(im, 8, PH * Z + 6, 'biniş', 15)
        label(im, widths2[0] * Z + 8, PH * Z + 6, '1 yolcu', 15)
        label(im, (widths2[0] + widths2[1]) * Z + 8, PH * Z + 6, '2 yolcu', 15)
        ims.append(im)
        if f == 8 + 9:
            key = im
    save_gif(ims, os.path.join(OUT, 'cadi_e.gif'), 1000 // fps)
    return key


# ---------------------------------------------------------------------- R sahnesi
def scene_r(idle, shrug, bottles, shatters, zones, boom):
    Z = 3
    CW, CH = 164, 132
    fps = 10
    n = 44
    W, H = CW * 3, CH * 2
    ims = []
    keys = []
    for f in range(n):
        dst = grass(W, H, 3)
        for p in range(5):
            ox, oy = (p % 3) * CW, (p // 3) * CH
            wx, wy = ox + 16, oy + 96
            zx, zy = ox + 97, oy + 92
            kind, pal, name = POTIONS[p]
            # alan (karakterlerin altında)
            if p == 2:
                bi = f - 5
            else:
                zi = f - 5
                z = zones[p]
                fr = None
                if 0 <= zi < Z_IN:
                    fr = z['in'][zi]
                elif Z_IN <= zi < Z_IN + Z_LOOP * 3:
                    fr = z['loop'][(zi - Z_IN) % Z_LOOP]
                elif Z_IN + Z_LOOP * 3 <= zi < Z_IN + Z_LOOP * 3 + Z_OUT:
                    fr = z['out'][zi - Z_IN - Z_LOOP * 3]
                if fr is not None:
                    blit(dst, fr, zx - ZCX, zy - ZCY, alpha=ZONE_ALPHA[p])
            shadow(dst, wx, wy + 1, 8, 2.6)
            if f < 4:
                char_at(dst, shrug[2][f], wx, wy)
            else:
                char_at(dst, idle[2][(f // 2) % 4], wx, wy)
            if f < 5:
                u = (f + 0.5) / 5.0
                bx = lerp(wx + 8, zx, u)
                by_ = lerp(wy - 24, zy - 4, u) - 30 * math.sin(math.pi * u)
                blit(dst, bottles[p][f % 4], bx - 9, by_ - 9)
            if 5 <= f < 11:
                blit(dst, shatters[p][f - 5], zx - 32, zy - 34)
            if p == 2 and 0 <= bi < BOOM_N:
                blit(dst, boom[bi], zx - BOOM_W / 2.0, zy - 88)
        # 6. hücre: şişeler (2 kat büyük)
        ox, oy = 2 * CW, CH
        for p in range(5):
            b = bottles[p][(f // 2) % 4]
            blit(dst, np.repeat(np.repeat(b, 2, 0), 2, 1), ox + 6 + p * 31, oy + 44)
        im = up(dst, Z)
        for p in range(5):
            label(im, (p % 3) * CW * Z + 8, (p // 3) * CH * Z + 6, '%d · %s' % (p + 1, POTIONS[p][2]), 16)
        label(im, 2 * CW * Z + 8, CH * Z + 6, 'şişeler (takla, 2x)', 16)
        for p in range(5):
            label(im, (2 * CW + 6 + p * 31) * Z + 6, (CH + 82) * Z, str(p + 1), 15)
        ims.append(im)
        if f in (3, 7, 12, 22, 41):
            keys.append(im)
    save_gif(ims, os.path.join(OUT, 'cadi_r.gif'), 1000 // fps)
    return keys


def _grid(name, rows, anims):
    """rows: her satır bir animasyonun kareleri; anims: [(ad, döngü, fps)]. PNG + SpriteFrames yazar."""
    h, w = rows[0][0].shape[:2]
    cols = max(len(r) for r in rows)
    im = np.zeros((h * len(rows), w * cols, 4), np.uint8)
    for r, frames in enumerate(rows):
        check('%s/%s' % (name, anims[r][0]), frames)
        for c, f in enumerate(frames):
            assert f.shape[:2] == (h, w), (name, f.shape)
            im[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    Image.fromarray(im, 'RGBA').save(os.path.join(ASSET_DIR, name + '_sheet.png'))
    write_sprite_frames(os.path.join(ASSET_DIR, name + '_frames.tres'), RES + name + '_sheet.png', w, h,
                        [(a, (0, r), len(rows[r]), loop, fps) for r, (a, loop, fps) in enumerate(anims)])
    print('   %-12s %dx%d  %s' % (name, w, h, ' '.join('%s:%d' % (a[0], len(rows[r])) for r, a in enumerate(anims))))


def build():
    b = {}
    b['potion'] = {p: q_potion_frames(p) for p in POT_POSES}
    b['stream'] = {p: q_stream_frames(p) for p in ST_POSES}
    b['smoke'] = smoke_frames()
    b['smoke_v'] = smoke_frames(True)
    b['poof'] = poof_frames()
    b['spark_g'], b['spark_m'] = spark_frames(GOLD[2]), spark_frames(MAGIC[3])
    b['bottles'] = [bottle_frames(k, p) for (k, p, _n) in POTIONS]
    b['shatters'] = [shatter_frames(FIRE if k == 'bomb' else p, 50 + i) for i, (k, p, _n) in enumerate(POTIONS)]
    b['zones'] = {0: zone_frames(zone_mad), 1: zone_frames(zone_ice), 3: zone_frames(zone_heal), 4: zone_frames(zone_fear)}
    b['boom'] = boom_frames()
    return b


def write_assets(b):
    """Oyun varlıkları: assets/fx/cadi/<ad>_sheet.png + <ad>_frames.tres, assets/skills/cadi_*_icon.png."""
    os.makedirs(ASSET_DIR, exist_ok=True)
    print('Cadı efekt sayfaları ->', os.path.relpath(ASSET_DIR, PROJECT))
    _grid('potion', [b['potion']['side'], b['potion']['down']], [('loop', True, 10.0), ('down', True, 10.0)])
    _grid('stream', [b['stream']['side'], b['stream']['down']], [('loop', True, 10.0), ('down', True, 10.0)])
    sm, sv = b['smoke'], b['smoke_v']
    _grid('smoke', [sm['in'], sm['loop'], sm['out'], sv['in'], sv['loop'], sv['out']],
          [('intro', False, 10.0), ('loop', True, 10.0), ('outro', False, 10.0), ('intro_v', False, 10.0), ('loop_v', True, 10.0), ('outro_v', False, 10.0)])
    _grid('poof', [b['poof']], [('default', False, 16.0)])
    _grid('spark', [b['spark_g'], b['spark_m']], [('gold', False, 12.0), ('lilac', False, 12.0)])
    side = [[broom_side(n, f)[BROOM_Y0:BROOM_Y0 + BROOM_H, :] for f in range(4)] for n in range(MAX_PASS + 1)]
    _grid('broom_side', side, [('side_%d' % n, True, 8.0) for n in range(MAX_PASS + 1)])
    vert = [[broom_down(f)[1][BROOM_Y0:BROOM_Y0 + BROOM_H, AX:AX + 48] for f in range(4)], [broom_up(f)[1][BROOM_Y0:BROOM_Y0 + BROOM_H, AX:AX + 48] for f in range(4)]]
    _grid('broom_vert', vert, [('down', True, 8.0), ('up', True, 8.0)])
    _grid('bottles', b['bottles'], [('b%d' % (i + 1), True, 14.0) for i in range(5)])
    _grid('shatter', b['shatters'], [('s%d' % (i + 1), False, 12.0) for i in range(5)])
    for i, nm in ((0, 'zone_mad'), (1, 'zone_ice'), (3, 'zone_heal'), (4, 'zone_fear')):
        z = b['zones'][i]
        _grid(nm, [z['in'], z['loop'], z['out']], [('intro', False, 10.0), ('loop', True, 10.0), ('outro', False, 10.0)])
    _grid('boom', [b['boom']], [('default', False, 15.0)])
    _grid('mad_status', [mad_status_frames()], [('loop', True, 10.0)])
    icons = [('cadi_passive_icon', icon_passive()), ('cadi_zehirli_duman_icon', icon_q()), ('cadi_supurge_icon', icon_e()), ('cadi_iksir_icon', icon_r())]
    icons += [('cadi_iksir_%d_icon' % (i + 1), icon_r(i)) for i in range(5)]
    for nm, ic in icons:
        ic.resize((144, 144), Image.NEAREST).save(os.path.join(ICON_DIR, nm + '.png'))
    print('   ikonlar:', ', '.join(nm for nm, _ic in icons))
    # kodun kullandığı ölçüler (scripts/cadi_math.gd ile aynı olmalı)
    for p in POT_POSES:
        print('   ÖLÇÜ potion %-4s gövde merkezi %s / %dx%d, ağız = merkez + eksen %s x %.1f; stream ağız %s / %dx%d, iniş = ağız + %s'
              % (p, POT_POSES[p][0], POT_W, POT_H, POT_POSES[p][1], POT_MOUTH, ST_POSES[p][0], ST_W, ST_H, ST_POSES[p][1]))
    print('   ÖLÇÜ smoke orijin (%.1f, %.1f), dikey (_v) orijin (%.1f, %.1f) / %dx%d' % (SMOKE_OX, SMOKE_OY, SMOKE_VOX, SMOKE_VOY, SMOKE_W, SMOKE_H))
    print('   ÖLÇÜ zone merkez (%.1f, %.1f) / %dx%d, yarıçap %dx%d px' % (ZCX, ZCY, ZW, ZH, RX, RY))
    print('   ÖLÇÜ boom merkez (%.1f, 88.0) / %dx%d' % (BOOM_W / 2.0, BOOM_W, BOOM_H))
    print('   ÖLÇÜ broom_side: karakter hücresi merkezi sayfa karesinde (%d, %d) / %dx%d; broom_vert: (24, %d) / 48x%d; oturuş %d px aşağı'
          % (AX + 24, 24 - BROOM_Y0 + AY, BW, BROOM_H, 24 - BROOM_Y0 + AY, BROOM_H, SIT_DROP))


def write_previews(b):
    os.makedirs(SHEETS, exist_ok=True)
    print('Cadı önizlemeleri ->', os.path.relpath(OUT, PROJECT))
    walk, idle = load_game_sheet('cadi', 'walk'), load_game_sheet('cadi', 'idle')
    sit, shrug = load_game_sheet('cadi', 'sit'), load_game_sheet('cadi', 'shrug')
    pass1, pass2 = load_game_sheet('hadime', 'sit'), load_game_sheet('korsan', 'sit')
    scene_q(walk, b['potion']['side'], b['stream']['side'], b['smoke'])
    scene_e(sit, idle, pass1, pass2, b['poof'], b['spark_g'], b['spark_m'])
    scene_r(idle, shrug, b['bottles'], b['shatters'], b['zones'], b['boom'])
    icons = [icon_passive(), icon_q(), icon_e(), icon_r()] + [icon_r(i) for i in range(5)]
    names = ['Pasif', 'Q', 'E', 'R', 'R1', 'R2', 'R3', 'R4', 'R5']
    sheet = Image.new('RGB', (len(icons) * 156 + 12, 250), (38, 34, 46))
    d = ImageDraw.Draw(sheet)
    for i, ic in enumerate(icons):
        sheet.paste(ic.resize((144, 144), Image.NEAREST), (12 + i * 156, 34))
        sheet.paste(ic, (12 + i * 156 + 48, 190))
        d.text((12 + i * 156, 8), names[i], font=font(17), fill=(240, 236, 250))
    sheet.save(os.path.join(OUT, 'cadi_ikonlar.png'))


def main():
    b = build()
    if PREVIEW:
        write_previews(b)
    else:
        write_assets(b)


if __name__ == '__main__':
    main()
