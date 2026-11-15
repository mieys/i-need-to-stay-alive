# -*- coding: utf-8 -*-
"""ÇAKRAM (eski Bumerang) sanatı + özel efekti (madde 589, 2026-11-11).

Kullanıcı: "boomerang da artık chakram oluyor onunla değiştir ve chakram için yeni özel efekt hazırla".
Kaynak: assets/weapons/yeni/chakram.png (kullanıcının 32x32 çizimi, Desktop\\chakram.png birebir). Hepsi aynı sanat ızgarasında:
1 piksel = WeaponTierArt.WORLD_PX x SIZE_MULT["boomerang"] = 0,575 x 1,3 = 0,7475 dünya px (kafadaki ikonla aynı).

Efekt dili oyunun onaylı kuralları: düz piksel, saydamlık 3-4 basamak (dither / nokta nokta zerre YOK), az ve biçimli parçacık
(kıvılcım = hız yönünde kısa çizgi), 1 px koyu kontur yalnız dolu kesikte; renkler çizimin kendi paletinden (çelik / buz / altın).

Çıktılar ("spin"/"whirl" kare = dönüş açısı, boomerang_projectile.gd kareyi açıya göre SEÇER; diğerleri "play" tek sefer):
  assets/weapons/chakram/spin_sheet.png + spin_frames.tres   24 x 36x36, 15 derece adım (RotSprite: EPX x2 -> döndür -> örnekle)
  assets/fx/chakram/whirl_sheet.png + whirl_frames.tres      24 x 40x40, dönen bıçak halkasının izi (gövdenin ARKASINDA çizilir:
                                                              bıçak aralarındaki çentikleri ve kenarın 1-2 px dışını doldurur)
  assets/fx/chakram/cut_sheet.png + cut_frames.tres          isabet "Çelik Kesik": ön kenarda dönme yönünde süpüren hilal +
                                                              temas yıldızı + dönme yönüne savrulan kıvılcımlar (+x = uçuş yönü)
  assets/fx/chakram/ping_sheet.png + ping_frames.tres        dönüş noktası parıltısı (altın göbekte 4 köşeli yıldız + ince halka)
  assets/fx/chakram/catch_sheet.png + catch_frames.tres      yakalama: daralan altın halka + parlama
  assets/fx/chakram/mill_sheet.png + mill_frames.tres        Seken Çelik finali "Çelik Değirmen" (madde 591): 24 x 96x96, yerinde
                                                              dönen testere kopyasının dış bıçak halkası (4 çelik diş + buz izi;
                                                              gövde + küçük girdap kodda üstüne biner, chakram_mill_fx.gd)
Çalıştırma: python -I tools/gen_chakram_fx.py [--onizleme <png>]   (sonra Godot --headless --import)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

SRC = os.path.join(ROOT, "assets", "weapons", "yeni", "chakram.png")
WDIR = os.path.join(ROOT, "assets", "weapons", "chakram")
FXDIR = os.path.join(ROOT, "assets", "fx", "chakram")

ROT_STEPS = 24
SPIN_CELL = 36
WHIRL_CELL = 40
CUT_CELL = 64
PING_CELL = 32
MILL_CELL = 96
FX_FPS = 30.0

## çizimin paleti
OUT = (7, 16, 24)
STEEL_D = (95, 108, 121)
STEEL = (122, 145, 160)
STEEL_L = (160, 195, 207)
ICE = (189, 248, 255)
ICE_L = (219, 255, 255)
WHITE = (255, 255, 255)
GOLD_D = (108, 91, 68)
GOLD = (173, 149, 100)
GOLD_L = (213, 191, 115)
GOLD_H = (251, 234, 123)
GOLD_W = (255, 255, 143)


# ------------------------------------------------------------------ RotSprite
def epx(im):
    """Scale2x/EPX (gen_weapon_fx_sprites.py ile aynı): kenarları yumuşatan 2x büyütme."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    o = out.load()

    def g(x, y):
        return src[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]

    for y in range(h):
        for x in range(w):
            P = g(x, y)
            A, B, C, D = g(x, y - 1), g(x + 1, y), g(x - 1, y), g(x, y + 1)
            o[2 * x, 2 * y] = A if (C == A and C != D and A != B) else P
            o[2 * x + 1, 2 * y] = B if (A == B and A != C and B != D) else P
            o[2 * x, 2 * y + 1] = C if (D == C and D != B and C != A) else P
            o[2 * x + 1, 2 * y + 1] = D if (B == D and B != A and D != C) else P
    return out


def rotsprite(im, deg):
    """Saat yönünde deg derece (Godot'nun pozitif dönüşü)."""
    up = epx(epx(im))
    rot = up.rotate(-deg, resample=Image.NEAREST, center=(up.width / 2, up.height / 2))
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = rot.load()
    for y in range(h):
        for x in range(w):
            out.putpixel((x, y), r[x * 4 + 2, y * 4 + 2])
    return out


# ------------------------------------------------------------------ çizim yardımcıları (düz piksel, basamaklı saydamlık)
class Lay:
    def __init__(self, w, h):
        self.a = np.zeros((h, w, 4), np.float32)
        self.h, self.w = h, w
        yy, xx = np.mgrid[0:h, 0:w]
        self.X = xx + 0.5
        self.Y = yy + 0.5

    def paint(self, mask, col, alpha):
        """mask'teki piksellere col'u alpha ile 'over' boyar (alpha 0..1)."""
        if alpha <= 0.0:
            return
        al = np.where(mask, float(alpha), 0.0)[..., None]
        c = np.array(list(col) + [255.0], np.float32)
        self.a = self.a * (1.0 - al) + c * al

    def put(self, x, y, col, alpha=1.0):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            m = np.zeros((self.h, self.w), bool)
            m[y, x] = True
            self.paint(m, col, alpha)

    def line(self, x0, y0, x1, y1, col, alpha=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, alpha)

    def image(self):
        return Image.fromarray(np.clip(self.a, 0, 255).astype(np.uint8), "RGBA")


def band(v, steps=(1.0, 0.72, 0.46, 0.22)):
    """0..1 -> basamaklı saydamlık (dither yok)."""
    v = min(max(v, 0.0), 1.0)
    if v <= 0.0:
        return 0.0
    n = len(steps)
    return steps[min(n - 1, int((1.0 - v) * n))]


def polar(L, cx, cy):
    dx, dy = L.X - cx, L.Y - cy
    return np.hypot(dx, dy), np.degrees(np.arctan2(dy, dx))  # y aşağı: açı artarken saat yönü


def behind(ang, ref):
    """ref açısından saat yönünün TERSİNE (geriye) kaç derece (0..360)."""
    return np.mod(ref - ang, 360.0)


def star4(L, cx, cy, size, core, arm, alpha=1.0):
    """4 köşeli yıldız: + kolları (size px), merkez 2x2 değil tek piksel + yanları."""
    if size <= 0:
        return
    for i in range(1, size + 1):
        c = arm if i > 1 else core
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            L.put(cx + dx, cy + dy, c, alpha)
    L.put(cx, cy, core, alpha)
    if size >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            L.put(cx + dx, cy + dy, arm, alpha * 0.72)


def ring(L, cx, cy, r, col, alpha, width=1.0):
    rr, _ = polar(L, cx, cy)
    L.paint((rr >= r - width * 0.5) & (rr < r + width * 0.5), col, alpha)


# ------------------------------------------------------------------ gövde: 24 dönüş karesi
def spin_frames(art):
    pad = Image.new("RGBA", (SPIN_CELL, SPIN_CELL), (0, 0, 0, 0))
    off = (SPIN_CELL - art.width) // 2
    pad.paste(art, (off, off))
    return [rotsprite(pad, 360.0 * k / ROT_STEPS) for k in range(ROT_STEPS)]


# ------------------------------------------------------------------ dönen bıçak halkasının izi
## Bıçaklar köşegenlerde (merkez açıları -45/45/135/225), ~80 derece; aralarında eksenlerde çentik. Dönüş saat yönünde: her bıçağın
## ARKA ucu (merkez - 40) geride bıraktığı yayı çizer. Hilal bıçağın ucunda kalın (kenarın 1,5 px dışına taşar), geriye doğru
## incelip söner. Gövdenin ARKASINDA çizildiği için yalnız çentiklerde + kenarın dışında görünür (bıçağın kendisini kirletmez).
WHIRL_SPAN = 70.0  # derece, arka uçtan geriye
BLADE_HALF = 40.0
## (iz, kenarın dışına taşan yarıçap, iç yarıçap, saydamlık basamakları) - ilk deneme (0,62/0,40/0,20, dış 17,6) oyun ölçeğinde
## seçilmiyordu: dış kenar 18,6'ya, çekirdek buz rengine çıktı.
WHIRL_BANDS = ((0.0, 0.28, 0.82), (0.28, 0.6, 0.56), (0.6, 1.0, 0.3))


def whirl_frame(k):
    L = Lay(WHIRL_CELL, WHIRL_CELL)
    c = WHIRL_CELL / 2.0
    rr, ang = polar(L, c, c)
    rot = 360.0 * k / ROT_STEPS
    for i in range(4):
        tail = -45.0 + 90.0 * i - BLADE_HALF + rot
        d = behind(ang, tail) / WHIRL_SPAN  # 0 = bıçağın arka ucu, 1 = izin sonu
        on = d < 1.0
        r_out = 18.6 - 2.2 * d
        r_in = 12.0 + 3.0 * d
        m = on & (rr >= r_in) & (rr < r_out)
        for lo, hi, a in WHIRL_BANDS:
            sel = m & (d >= lo) & (d < hi)
            edge = sel & (rr >= r_out - 1.0)
            L.paint(sel & ~edge, ICE, a)
            L.paint(edge, WHITE if lo == 0.0 else ICE_L, a)
    return L.image()


# ------------------------------------------------------------------ Seken Çelik finali: Çelik Değirmen (madde 591)
## Çakramın bıraktığı, yerinde dönen kopyanın DIŞ halkası: 4 dolu çelik diş (1 px koyu kontur, dış yarısı açık, dış kenarda buz
## parıltısı, uçta beyaz) + her dişin arkasından gövdeye doğru SARMAL inen, incelen basamaklı buz izi (dither yok; ilk deneme
## düz halka gövdeden kopuk "çember içinde çakram" gibi okunuyordu). Dönüş saat yönünde (whirl ile
## aynı). Dış kenar ~41,5 px x 0,7475 = ~31 dünya px = testerenin hasar yarıçapı (weapon_traits.gd "mill_radius" 32).
MILL_R = 39.0
MILL_BLADES = 4
MILL_SPAN = 130.0  # derece: dişin ucundan izin sonuna
MILL_TH = 5.0
MILL_HEAD = 0.12  # izin baştaki dolu diş kısmı (oran)
MILL_IN = 19.0  # izin sonunda içe inme (px): 39 -> 20, gövdenin girdabına değer
MILL_TRAIL = ((MILL_HEAD, 0.4, 0.62), (0.4, 0.7, 0.4), (0.7, 1.0, 0.2))


def _dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def mill_frame(k):
    L = Lay(MILL_CELL, MILL_CELL)
    c = MILL_CELL / 2.0
    rr, ang = polar(L, c, c)
    rot = 360.0 * k / ROT_STEPS
    blades = np.zeros((MILL_CELL, MILL_CELL), bool)
    trails = np.zeros((MILL_CELL, MILL_CELL), bool)
    parts = []
    for i in range(MILL_BLADES):
        head = 45.0 + 90.0 * i + rot
        d = behind(ang, head) / MILL_SPAN  # 0 = dişin ucu, 1 = izin sonu
        on = d < 1.0
        th = MILL_TH * (1.0 - 0.75 * d)
        r_c = MILL_R - MILL_IN * d
        m = on & (np.abs(rr - r_c) < th * 0.5)
        blade = m & (d < MILL_HEAD)
        trail = m & (d >= MILL_HEAD)
        blades |= blade
        trails |= trail
        parts.append((d, r_c, th, blade, trail))
    for d, r_c, th, blade, trail in parts:
        for lo, hi, a in MILL_TRAIL:
            L.paint(trail & (d >= lo) & (d < hi), ICE, a)
    L.paint(_dilate(blades) & ~blades & ~trails, OUT, 0.85)
    for d, r_c, th, blade, trail in parts:
        L.paint(blade, STEEL, 1.0)
        L.paint(blade & (rr >= r_c), STEEL_L, 1.0)
        L.paint(blade & (rr >= r_c + th * 0.5 - 1.0), ICE_L, 1.0)
        L.paint(blade & (d < 0.035), WHITE, 1.0)
    return L.image()


# ------------------------------------------------------------------ isabet: Çelik Kesik
## Kare merkezi = çakramın merkezi (isabet anı), +x = uçuş yönü (kod döndürür; sola uçuşta flip_v - dönme yönü aynı kalsın).
## Ön kenar (açı 0, yarıçap R) düşmana değer; dönme saat yönünde -> kenar AŞAĞI süpürür: hilal -55'ten +55'e süpürür, kuyruğu
## incelir; temas noktasında yıldız; kıvılcımlar kenarın aşağı-ileri teğetine savrulur.
CUT_R = 17.0
## ilk deneme (yarıçap 15, 110 derece, en kalın 3 px) oyun ölçeğinde ~14 ekran px'lik çizik kalıyordu -> 150 derece, 4,6 px.
CUT_HEAD = [-28.0, 30.0, 72.0, 76.0, 76.0, 76.0, 76.0, 76.0, 76.0]
CUT_TAIL = [-76.0, -72.0, -50.0, -10.0, 30.0, 56.0, 70.0, 76.0, 76.0]
CUT_FADE = [1.0, 1.0, 1.0, 1.0, 0.72, 0.46, 0.22, 0.0, 0.0]
CUT_TH = 4.6
FLASH = [2, 4, 3, 1, 0, 0, 0, 0, 0]


def make_sparks(seed=7):
    rng = random.Random(seed)
    out = []
    for i in range(5):
        a = math.radians(rng.uniform(40.0, 100.0))  # aşağı-ileri (dönme teğeti)
        sp = rng.uniform(2.0, 3.0)  # px / kare
        out.append((1 + (i % 2), math.cos(a) * sp, math.sin(a) * sp, rng.uniform(-4.0, 4.0), rng.choice((4, 5, 6))))
    return out


SPARKS = make_sparks()


def cut_frame(f):
    L = Lay(CUT_CELL, CUT_CELL)
    c = CUT_CELL / 2.0
    rr, ang = polar(L, c, c)
    fade = CUT_FADE[f]
    if fade > 0.0:
        head, tail = CUT_HEAD[f], CUT_TAIL[f]
        span = max(1.0, head - tail)
        u = np.clip((ang - tail) / span, 0.0, 1.0)  # 0 kuyruk -> 1 baş
        inside = (ang >= tail) & (ang <= head)
        th = 1.0 + (CUT_TH - 1.0) * np.sqrt(u)  # kalınlık: kuyruk 1 px -> baş CUT_TH
        m = inside & (rr >= CUT_R - th * 0.5) & (rr < CUT_R + th * 0.5)
        outline = inside & ~m & (rr >= CUT_R - th * 0.5 - 1.0) & (rr < CUT_R + th * 0.5 + 1.0) & (u > 0.25)
        L.paint(outline, OUT, fade * 0.85)
        L.paint(m, STEEL_L, fade)
        L.paint(m & (rr >= CUT_R - th * 0.5 + 1.0), ICE, fade)
        L.paint(m & (rr >= CUT_R - th * 0.5 + 1.0) & (rr < CUT_R + th * 0.5 - 1.0), ICE_L, fade)
        L.paint(m & (u > 0.55) & (np.abs(rr - CUT_R - 0.3) < 0.8), WHITE, fade)
    if FLASH[f] > 0:
        star4(L, c + CUT_R, c + 1.0, FLASH[f], WHITE, ICE, 1.0)
    for (age0, vx, vy, gy, life) in SPARKS:
        age = f - age0
        if age < 0 or age >= life:
            continue
        k = age / float(life)
        x = c + CUT_R + vx * (age + 0.5)
        y = c + 2.0 + vy * (age + 0.5) + 0.15 * gy * age * age * 0.1
        ln = 3.0 if k < 0.4 else (2.0 if k < 0.75 else 1.0)
        n = math.hypot(vx, vy)
        col = WHITE if k < 0.3 else (ICE if k < 0.65 else STEEL_L)
        L.line(x, y, x - vx / n * ln, y - vy / n * ln, col, 1.0 if k < 0.65 else 0.72)
    return L.image()


# ------------------------------------------------------------------ dönüş noktası parıltısı / yakalama
PING_STAR = [2, 4, 5, 4, 2, 1]
PING_RING = [(7.0, 0.72), (10.0, 0.46), (12.5, 0.3), (14.0, 0.18), (0.0, 0.0), (0.0, 0.0)]


def ping_frame(f):
    L = Lay(PING_CELL, PING_CELL)
    c = PING_CELL / 2.0
    r, a = PING_RING[f]
    if a > 0.0:
        ring(L, c, c, r, ICE_L, a)
    star4(L, c, c, PING_STAR[f], GOLD_W, GOLD_H, 1.0 if f < 4 else 0.72)
    return L.image()


CATCH_RING = [(14.0, 0.3), (11.5, 0.46), (9.0, 0.72), (6.5, 1.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0)]
CATCH_STAR = [0, 0, 0, 2, 5, 3, 1]


def catch_frame(f):
    L = Lay(PING_CELL, PING_CELL)
    c = PING_CELL / 2.0
    r, a = CATCH_RING[f]
    if a > 0.0:
        ring(L, c, c, r, GOLD_L, a, 1.4)
        ring(L, c, c, r + 1.0, GOLD_D, a * 0.6)
    star4(L, c, c, CATCH_STAR[f], WHITE, GOLD_H, 1.0 if f < 6 else 0.72)
    return L.image()


# ------------------------------------------------------------------ kayıt
def save_sheet(frames, out_dir, name, anim, fps, loop):
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        assert im.size == (w, h)
        bb = im.getbbox()
        if bb:
            assert bb[0] > 0 and bb[1] > 0 and bb[2] < w and bb[3] < h, "%s kare %d tuvale sığmıyor: %s" % (name, i, bb)
        sheet.paste(im, (i * w, 0))
    os.makedirs(out_dir, exist_ok=True)
    png = os.path.join(out_dir, "%s_sheet.png" % name)
    sheet.save(png)
    res = "res://" + os.path.relpath(png, ROOT).replace("\\", "/")
    write_sprite_frames(os.path.join(out_dir, "%s_frames.tres" % name), res, w, h, [(anim, (0, 0), len(frames), loop, float(fps))])
    print("wrote", png, sheet.size, "kare", len(frames))
    return sheet


def preview(path, sheets):
    """Koyu çimen zemininde x6 önizleme (her sayfa bir satır)."""
    Z = 6
    rows = []
    for sh in sheets:
        rows.append(sh.resize((sh.width * Z, sh.height * Z), Image.NEAREST))
    W = max(r.width for r in rows)
    H = sum(r.height for r in rows) + 8 * len(rows)
    out = Image.new("RGBA", (W, H), (58, 84, 52, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height + 8
    out.save(path)
    print("önizleme", path)


def main():
    art = Image.open(SRC).convert("RGBA")
    assert art.size == (32, 32), art.size
    sheets = []
    sheets.append(save_sheet(spin_frames(art), WDIR, "spin", "spin", 0.0, False))
    sheets.append(save_sheet([whirl_frame(k) for k in range(ROT_STEPS)], FXDIR, "whirl", "spin", 0.0, False))
    sheets.append(save_sheet([cut_frame(f) for f in range(len(CUT_HEAD))], FXDIR, "cut", "play", FX_FPS, False))
    sheets.append(save_sheet([ping_frame(f) for f in range(len(PING_STAR))], FXDIR, "ping", "play", FX_FPS, False))
    sheets.append(save_sheet([catch_frame(f) for f in range(len(CATCH_STAR))], FXDIR, "catch", "play", FX_FPS, False))
    sheets.append(save_sheet([mill_frame(k) for k in range(ROT_STEPS)], FXDIR, "mill", "spin", 0.0, False))
    if "--onizleme" in sys.argv:
        preview(sys.argv[sys.argv.index("--onizleme") + 1], sheets)


if __name__ == "__main__":
    main()
