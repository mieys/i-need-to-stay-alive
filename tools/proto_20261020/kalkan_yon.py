# -*- coding: utf-8 -*-
"""ŞÖVALYE KALKANI yönlü görünüşleri (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı B "Şövalye"yi seçti: "kalkanın yan pozisyonları
olmalı sanırım, böyle vurunca vurduğu hissedilmez".

Kalkan dikey eksen etrafında döndürülen hafif dışbükey bir levha gibi çizilir: yüz z(u) = C (1 - (u/W)^2), kalınlık T.
Açı (yaw) 0 = yüz kameraya (hedef aşağıda), 90 = yüz sağa (hedef sağda, profil), 180 = arka yüz görünür (hedef yukarıda).
Sola bakanlar sağdakilerin aynası. Görünüşler: 0 / 50 / 72 / 130 / 180 derece -> 8 yön (aşağı, sağ-aşağı, sağ, sağ-yukarı, yukarı + aynalar).
Ön yüz süsü kalkan_sanat.py B ile aynı merdiven (L1 kalas + ip, L2 kalas + demir kuşak/kenar, L3 çelik + pirinç, L4 kırmızı alan +
gümüş çavuş + kara çelik kenar, L5 çelik + altın haç + lal). Arka yüz: kalas + iki deri kayış + tutamak.

Çıktılar (out/kalkan/): yon/kalkan_B_L<n>_<aci>.png, kalkan_yon_sayfa.png (x4), kalkan_yon_oyun.png (8 yön karakterin çevresinde,
oyun ölçeği). Çalıştırma: python tools/proto_20261020/kalkan_yon.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kalkan_sanat as KS  # noqa: E402
from kalkan_sanat import S, E, P, LV, Cv, frame, font, N, TA, hsh  # noqa: E402

OUT = KS.OUT
YON = os.path.join(OUT, "yon")
ANGLES = [0, 50, 72, 130, 180]  # yan = 72 (tam profil 90 oyun ölçeğinde çubuk gibi ince kalıyordu)
LIGHT = (-0.45, 0.72)  # (x, z) ışık: sol + kameradan
T_THICK = 2.4


class Shield:
    def __init__(self, lv, yaw):
        self.lv = lv
        self.W = LV(lv, 10.5, 14.0)
        self.top, self.bot = -LV(lv, 12.5, 16.0), LV(lv, 14.0, 19.0)
        self.H = self.bot - self.top
        self.ys = self.top + self.H * 0.42
        self.cy = self.bot - self.H * 0.12
        self.C = LV(lv, 2.8, 3.4)
        th = math.radians(yaw)
        self.cs, self.sn = math.cos(th), math.sin(th)

    def w(self, v):
        """v satırındaki yarı genişlik."""
        if v <= self.ys:
            return self.W
        lo, hi = 0.0, 1.0
        for _ in range(30):
            t = (lo + hi) * 0.5
            vt = (1 - t) ** 2 * self.ys + 2 * (1 - t) * t * self.cy + t * t * self.bot
            if vt < v:
                lo = t
            else:
                hi = t
        t = (lo + hi) * 0.5
        return self.W * (1 - t * t)

    def z(self, u):
        return self.C * (1.0 - (u / self.W) ** 2)

    def X(self, u, zoff=0.0):
        return u * self.cs + (self.z(u) + zoff) * self.sn

    def depth(self, u, zoff=0.0):
        return -u * self.sn + (self.z(u) + zoff) * self.cs

    def face_poly(self, zoff):
        left, right = [], []
        v = self.top
        while v <= self.bot + 1e-6:
            ww = max(self.w(v), 0.05)
            xs = [self.X(-ww + 2 * ww * i / 24.0, zoff) for i in range(25)]
            left.append((min(xs), v))
            right.append((max(xs), v))
            v += 0.5
        return left + right[::-1]

    def outline_uv(self, inset=0.0):
        """Kalkan kenarı (u, v) çoklu çizgisi, saat yönünde, kapalı. inset: içe kaydırma."""
        pts = []
        v = self.top + inset
        n = 40
        for i in range(n + 1):  # sağ kenar yukarıdan aşağı
            vv = self.top + inset + (self.bot - inset * 1.6 - self.top - inset) * i / n
            pts.append((max(self.w(vv) - inset, 0.0), vv))
        left = [(-u, vv) for u, vv in reversed(pts[:-1])]
        return pts + left + [pts[0]]

    def inv_u(self, a, v, zoff):
        """Ekran a -> yüzdeki u (kameraya en yakın çözüm)."""
        ww = max(self.w(v), 0.05)
        best, bd = None, None
        for i in range(97):
            u = -ww + 2 * ww * i / 96.0
            e = abs(self.X(u, zoff) - a)
            dp = self.depth(u, zoff)
            if e < 0.6:
                if best is None or dp > bd:
                    best, bd = u, dp
        if best is None:
            best = min((-ww + 2 * ww * i / 96.0 for i in range(97)), key=lambda u: abs(self.X(u, zoff) - a))
        return best

    def lit(self, u, back=False):
        """Yüz normaline göre ışık indeksi 2..5."""
        nlx = 2 * self.C * u / (self.W ** 2)
        nlz = 1.0
        if back:
            nlx, nlz = -nlx, -1.0
        nx = nlx * self.cs + nlz * self.sn
        nz = -nlx * self.sn + nlz * self.cs
        L = math.hypot(nx, nz) or 1.0
        d = (nx * LIGHT[0] + nz * LIGHT[1]) / L
        return max(2, min(5, int(round(2.6 + d * 2.4))))

    def P(self, u, v, zoff=0.0):
        return (self.X(u, zoff), v)


def _front_mats(lv):
    t = TA[lv]
    face = {1: "A_wood", 2: "A_wood", 3: "A_steel", 4: "A_cloth", 5: "A_steel"}[lv]
    rim = {1: None, 2: "A_iron", 3: t["tr"], 4: "A_black", 5: "A_gold"}[lv]
    edge = {1: "A_wood", 2: "A_iron", 3: t["tr"], 4: "A_black", 5: "A_gold"}[lv]
    return face, rim, edge


def draw_view(c, lv, yaw):
    sh = Shield(lv, yaw)
    face, rim, edge = _front_mats(lv)
    front_visible = sh.cs >= -0.05
    near_off, far_off = (0.0, -T_THICK) if front_visible else (-T_THICK, 0.0)
    ## 1) uzak yüz = kalınlık/kenar
    c.plate(sh.face_poly(far_off), edge, bevel=1.0, shine=0.35)
    ## 2) yakın yüz
    planks = (lv <= 2) if front_visible else True
    back_wood = "A_wood" if lv <= 3 else "A_dwood"
    mat = face if front_visible else back_wood

    def tex(idx, a, b, x, y, d):
        u = sh.inv_u(a, b, near_off)
        base = sh.lit(u, back=not front_visible)
        if d < 1.0:
            return idx
        if planks:
            ## kalas: u ekseninde 4'lük, sıkışmış açıda (ekranda < 0,5 px/u) çizgi yok
            dxdu = abs(sh.cs - 2 * sh.C * u / sh.W ** 2 * sh.sn)
            if dxdu > 0.5:
                k = (u + 40.0) / 4.0
                if abs(k - round(k)) * 4.0 * dxdu < 0.5:
                    return 1
                if hsh(int(math.floor(k)), int((b + 64) // 3), 7) < 0.16:
                    base -= 1
        if lv == 1 and front_visible and hsh(x // 2, y // 2, 13) < 0.12:
            return P["A_rust"][max(2, min(5, base))]
        return base

    c.plate(sh.face_poly(near_off), mat, bevel=1.1, shine=0.25, tex=tex)

    if not front_visible:
        ## arka: iki deri kayış + tutamak (+ L2+ kenar metal arkadan da görünür)
        for su in (-0.38, 0.38):
            u0 = su * sh.W
            pts = [sh.P(u0, sh.top + sh.H * 0.2, near_off - 0.3), sh.P(u0, sh.top + sh.H * 0.58, near_off - 0.3)]
            c.tube(pts, 0.85, "A_leather", tex=E.wrap, shine=0.15)
        hv = sh.top + sh.H * 0.4
        c.tube([sh.P(-0.38 * sh.W, hv, near_off - 0.6), sh.P(0.38 * sh.W, hv, near_off - 0.6)], 0.75,
               "A_rope" if lv == 1 else ("A_cloth" if lv == 4 else "A_leather"), tex=E.wrap, shine=0.15)
        if rim:
            c.tube([sh.P(u, v, near_off) for u, v in sh.outline_uv(0.5)], LV(lv, 0.8, 1.1), rim, shine=0.45)
        return

    ## ön süsler
    if lv <= 2:
        bb = sh.top + sh.H * 0.2
        ww = sh.w(bb) - 0.3
        pts = [sh.P(-ww + 2 * ww * i / 10.0, bb, 0.2) for i in range(11)]
        if lv == 1:
            c.tube(pts, 0.7, "A_rope", tex=E.wrap, shine=0.1, sep=False)
            KS.rivets(c, [sh.P(-ww * 0.6, bb, 0.6), sh.P(ww * 0.6, bb, 0.6)], "A_iron", 0.6)
            return
        c.tube(pts, 0.9, "A_iron", shine=0.35)
        c.tube([sh.P(u, v, 0.2) for u, v in sh.outline_uv(0.45)], 0.95, "A_iron", shine=0.45)
        KS.rivets(c, [sh.P(-ww * 0.62, bb, 0.8), sh.P(ww * 0.62, bb, 0.8), sh.P(0, bb, 0.8)], "A_iron", 0.7)
        return
    if lv == 4:
        my = sh.top + sh.H * 0.45
        W = sh.W
        chev = [(-W * 0.86, my + W * 0.5), (-W * 0.43, my + W * 0.075), (0, my - W * 0.35), (W * 0.43, my + W * 0.075), (W * 0.86, my + W * 0.5)]
        c.tube([sh.P(u, v, 0.3) for u, v in chev], 1.15, "A_silver", shine=0.5)
    if lv == 5:
        cy = sh.top + sh.H * 0.4
        W = sh.W
        c.tube([sh.P(0, v, 0.3) for v in (sh.top + 2.6, cy, sh.bot - 5.5)], 1.15, "A_gold", shine=0.5)
        c.tube([sh.P(-W + 3.0 + (2 * W - 6.0) * i / 8.0, cy, 0.3) for i in range(9)], 1.15, "A_gold", shine=0.5)
    c.tube([sh.P(u, v, 0.2) for u, v in sh.outline_uv(0.5)], LV(lv, 1.05, 1.35), rim, shine=0.45)
    if lv == 3:
        bp = sh.P(0, sh.top + sh.H * 0.4, 1.2)
        c.sphere(bp, 2.6, rim, shine=0.5)
    if lv == 5:
        bp = sh.P(0, sh.top + sh.H * 0.4, 1.0)
        c.sphere(bp, 2.0, "A_gold", shine=0.5)
        c.sphere((bp[0] - 0.2, bp[1] - 0.2), 1.0, "A_garnet", shine=0.7, sep=False)
        if yaw <= 45:
            c.glint(*sh.P(-sh.W * 0.55, sh.top + 3.5, 0.3), "A_steel", 6)


def build():
    os.makedirs(YON, exist_ok=True)
    frame("horiz")
    imgs = {}
    for lv in range(1, 6):
        for yaw in ANGLES:
            cv = Cv(lv)
            draw_view(cv, lv, yaw)
            img = cv.render()
            img.save(os.path.join(YON, "kalkan_B_L%d_%03d.png" % (lv, yaw)))
            imgs[(lv, yaw)] = img
    return imgs


YAW_NAMES = {0: "aşağı (0°)", 50: "sağ-aşağı (50°)", 72: "sağ (72°)", 130: "sağ-yukarı (130°)", 180: "yukarı (180°)"}


def sheet(imgs, path, z=4):
    cell = N * z
    lw, gap, top = 150, 14, 40
    W = lw + len(ANGLES) * (cell + gap) + gap
    H = top + 5 * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for ci, yaw in enumerate(ANGLES):
        d.text((lw + gap + ci * (cell + gap), 10), "hedef " + YAW_NAMES[yaw], fill=(235, 230, 215), font=font(18, True))
    for lv in range(1, 6):
        y0 = top + (lv - 1) * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(18, True))
        for ci, yaw in enumerate(ANGLES):
            x0 = lw + gap + ci * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(lv, yaw)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)
    print("sayfa", path, im.size)


def view_for(dx, dy, imgs, lv):
    """Hedef yönü (dx, dy) -> (görünüş, ayna?) - 8 yön."""
    ang = math.degrees(math.atan2(dx, dy))  # 0 = aşağı, 90 = sağ, 180 = yukarı, -90 = sol
    mirror = ang < 0
    a = abs(ang)
    yaw = ANGLES[int(round(a / 45.0))]  # 8 dilim: 0/45/90/135/180 -> görünüş sırası
    img = imgs[(lv, yaw)]
    return img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img


def context(imgs):
    """Oyun ölçeği: karakterin çevresinde 8 yönde kalkan (L3 ve L5), resim x2."""
    zoom, wpp = 2.0, 0.575
    cwp = 2.2368375 * 0.8075 * 0.5
    ch_img = Image.open(os.path.join(E.GAME, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 96, 48, 144))
    pw, ph = 220, 200
    W = 2 * pw + 30
    H = ph + 30
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    for k, lv in enumerate((3, 5)):
        pc = Image.new("RGB", (pw, ph), S.BG)
        cx, cy = pw // 2, ph // 2 + 4
        E.blit_world(pc, ch_img, cx, cy, cwp, zoom)
        for i in range(8):
            th = math.radians(i * 45)
            dx, dy = math.sin(th), math.cos(th)
            img = view_for(dx, dy, imgs, lv)
            E.blit_world(pc, img, cx + dx * 72, cy - 6 + dy * 64, wpp, zoom)
        im.paste(pc, (10 + k * (pw + 10), 24))
        d.text((14 + k * (pw + 10), 4), "L%d %s - 8 yön (yüz hedefe döner)" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(12, True))
    path = os.path.join(OUT, "kalkan_yon_oyun.png")
    im.resize((W * 2, H * 2), Image.NEAREST).save(path)
    print("oyun", path)


if __name__ == "__main__":
    imgs = build()
    sheet(imgs, os.path.join(OUT, "kalkan_yon_sayfa.png"))
    context(imgs)
