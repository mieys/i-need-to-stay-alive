# -*- coding: utf-8 -*-
"""MIZRAK sanatı PROTOTİPLERİ (2026-10-19, oyuna bağlı DEĞİL). Kullanıcı: "silahın görünüşü ve efekti için 4 prototip üretmeye başla"
(yeni silah Mızrak: düz hatta delerek %120 saldırı gücü; özellik "Cirit" her 4. saplamada fırlatma).

Zanaatkâr seti (madde 196) altyapısıyla (silah_zanaat_proto.py: TA seviye merdiveni, Cv tuvali, 48x48 çapraz çerçeve), 4 silüet:
  A Yaprak Uç   - klasik yaprak biçimli baş + soket halkası (L4 kırmızı kumaş sargı, püskül yok)
  B Kanatlı     - geniş baş + soketin iki yanında kanat (domuz mızrağı), sapta demir bilezikler
  C Delici Şiş  - uzun, ince, dört köşe zırh delen sivri uç + yuvarlak durdurma diski (kargı)
  D Püsküllü    - ince yaprak uç + soketten sarkan büyük püskül (her seviyede; L4-5 kırmızı)
Seviye merdiveni (TA): 1 Paslı / 2 Demir / 3 Çelik + pirinç / 4 Kara Çelik + gümüş + kırmızı / 5 Yadigâr çelik + altın + lal.

Çıktılar (out/mizrak/): sanat/mizrak_<A..D>_L<n>.png (48x48), mizrak_sanat_sayfa.png (x4), mizrak_sanat_oyun.png (oyun ölçeği,
1 sanat px = 0,575 dünya px, zoom 2, karakterle boy kıyası, resim x2). Çalıştırma: python tools/proto_20261019/mizrak_sanat.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P16 = os.path.normpath(os.path.join(HERE, "..", "proto_20261016"))
sys.path.insert(0, P16)
import silah_zanaat_proto as Z  # noqa: E402
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, frame, LV, E, facet, spike, font, N  # noqa: E402

TA = Z.TA
bar, shiny, blade_tex2, tassel = Z.bar, Z.shiny, Z.blade_tex2, Z.tassel
OUT = os.path.join(HERE, "out", "mizrak")
ART = os.path.join(OUT, "sanat")

PE = -30.5  # sapın dip ucu (a ekseni; çapraz çerçevede ±31 tuvale sığar)


def _wd(lv):
    return "A_wood" if lv <= 3 else "A_dwood"


def _shaft(c, lv, s0, r=None, bands=0):
    """Ahşap sap PE -> s0 + dip başlığı + tutma sargısı. bands: sapa eşit aralıklı ince metal bilezik sayısı."""
    t = TA[lv]
    r = r if r is not None else LV(lv, 1.1, 1.25)
    c.tube([(PE + 1.0, 0), (s0, 0)], r, _wd(lv), tex=E.grain, shine=0.25)
    if lv == 1:
        c.sphere((PE + 1.0, 0), r * 1.05, "A_wood", shine=0.2)
    else:
        bar(c, PE + 0.4, PE + 2.2, (r * 1.15, r * 1.3), t["tr"] if lv >= 3 else "A_iron", shine=0.4)
        if lv == 5:
            c.sphere((PE + 0.4, 0), 1.25, "A_gold", shine=0.5)
    ## tutma sargısı (sapın arka üçte biri)
    gm = "A_rope" if lv == 1 else ("A_cloth" if lv == 4 else "A_leather")
    c.tube([(-17.5, 0), (-9.5, 0)], r * 1.22, gm, tex=E.wrap, shine=0.1)
    for k in range(bands):
        a = -5.0 + k * 5.5
        bar(c, a - 0.5, a + 0.5, r * 1.25, t["tr"] if lv >= 3 else "A_iron", shine=0.45)


def _socket(c, lv, s0, s1, r0=1.25, r1=1.55, mat=None):
    """Başın oturduğu soket (koni): s0 -> s1."""
    t = TA[lv]
    m = mat or ("A_iron" if lv <= 2 else (t["m"] if lv == 4 else t["tr"]))
    if lv == 1:
        ## L1: baş sapa iple bağlı (soket yok)
        c.tube([(s0 - 0.6, 0), (s1, 0)], (r0 * 1.05, r0 * 1.12), "A_rope", tex=E.wrap, shine=0.1)
        return
    c.tube([(s0, 0), (s1, 0)], (r0, r1), m, shine=0.45)
    if lv >= 3:
        bar(c, s0 - 0.3, s0 + 0.5, r0 * 1.2, t["tr"] if lv != 4 else "A_silver", shine=0.5)


def _leaf(c, lv, hb, ln, w, wpos=0.38, mid=0.72, mat=None, rib=True):
    """Yaprak biçimli baş: taban hb, boy ln, en geniş yer wpos'ta yarı genişlik w."""
    t = TA[lv]
    tip = hb + ln
    poly = [(hb, -0.95), (hb + ln * wpos, -w), (hb + ln * mid, -w * 0.62), (tip, 0), (hb + ln * mid, w * 0.62),
            (hb + ln * wpos, w), (hb, 0.95)]
    if lv == 1:  # dövme kaba: bir yan hafif içe çökük
        poly = [(hb, -0.95), (hb + ln * wpos, -w * 0.92), (hb + ln * 0.6, -w * 0.72), (tip, 0.2), (hb + ln * mid, w * 0.7),
                (hb + ln * wpos, w), (hb, 0.95)]
    c.plate(poly, mat or t["m"], bevel=1.1, shine=0.25,
            tex=blade_tex2(edge="A_silver" if lv == 4 else None, fuller=rib and lv in (3, 5), rust=lv == 1))
    return tip


# ---------------------------------------------------------------- A Yaprak Uç
def A_spear(c, lv):
    t = TA[lv]
    s0 = LV(lv, 9.5, 7.5)
    _shaft(c, lv, s0 + 0.5)
    _socket(c, lv, s0 - 3.4, s0 + 0.6, 1.4, 1.8)
    tip = _leaf(c, lv, s0 + 0.2, LV(lv, 16.0, 21.0), LV(lv, 3.2, 4.2))
    if lv == 5:
        c.tube([(s0 + 1.8, 0), (s0 + 9.5, 0)], 0.42, "A_gold", shine=0.5, sep=False, outline=False)
        shiny(c, s0 - 1.3, 0, 0.85, "A_garnet")
        c.glint(s0 + 8.0, -1.4, "A_steel", 6)
    return tip


# ---------------------------------------------------------------- B Kanatlı
def B_spear(c, lv):
    t = TA[lv]
    s0 = LV(lv, 9.0, 7.5)
    _shaft(c, lv, s0 + 0.5, bands=0 if lv == 1 else (1 if lv < 4 else 2))
    _socket(c, lv, s0 - 3.6, s0 + 0.6, 1.45, 1.85)
    ## kanatlar (soketin hemen önü, iki yana; uçları hafif geriye eğik)
    wl = LV(lv, 4.2, 6.2)
    wm = "A_iron" if lv <= 2 else ("A_silver" if lv == 4 else t["tr"])
    if lv == 1:  # demir çubuk, iple çapraz bağlı
        c.tube([(s0 - 0.6, -wl), (s0 - 0.6, wl)], 0.6, "A_iron", shine=0.3)
        c.tube([(s0 - 1.6, -1.2), (s0 + 0.4, 1.2)], 0.45, "A_rope", shine=0.1, sep=False)
    else:
        for sg in (-1, 1):
            facet(c, spike((s0 + 0.2, sg * 1.0), (s0 - 1.6, sg * (wl + 0.6)), LV(lv, 1.1, 1.5), shoulder=0.35), wm)
    tip = _leaf(c, lv, s0 + 0.4, LV(lv, 14.5, 19.0), LV(lv, 3.7, 4.7), wpos=0.32, mid=0.66)
    if lv >= 4:
        Z.tassel(c, s0 - 4.5, 1.0, "A_cloth", cord=t["tr"], ln=2.6)
    if lv == 5:
        shiny(c, s0 - 0.6, 0, 0.9, "A_garnet")
        c.glint(s0 + 7.0, -1.8, "A_steel", 6)
    return tip


# ---------------------------------------------------------------- C Delici Şiş
def C_spear(c, lv):
    t = TA[lv]
    s0 = LV(lv, 7.5, 6.0)
    _shaft(c, lv, s0 + 0.5, r=LV(lv, 1.2, 1.35))
    _socket(c, lv, s0 - 4.0, s0 + 0.3, 1.55, 1.75)
    ## durdurma diski (L1 yok: sivri iple bağlı)
    if lv >= 2:
        dm = "A_iron" if lv == 2 else ("A_silver" if lv == 4 else t["tr"])
        rr = LV(lv, 2.8, 3.8)
        c.tube([(s0 + 0.4, -rr), (s0 + 0.4, rr)], 0.85, dm, shine=0.45)
        c.sphere((s0 + 0.4, 0), 1.45, dm, shine=0.5)
    ## dört köşe sivri: ince uzun, ortasında ışıklı sırt
    ln = LV(lv, 19.0, 23.5)
    w = LV(lv, 2.0, 2.4)
    hb = s0 + 0.9
    tip = hb + ln
    c.plate([(hb, -w * 0.85), (hb + ln * 0.18, -w), (tip - 2.4, -0.62), (tip, -0.18), (tip, 0.18), (tip - 2.4, 0.62),
             (hb + ln * 0.18, w), (hb, w * 0.85)], t["m"], bevel=0.9,
            shine=0.3, tex=blade_tex2(edge="A_silver" if lv == 4 else None, rust=lv == 1))
    c.tube([(hb + 1.0, -0.45), (tip - 3.5, -0.15)], 0.34, "A_steel" if lv != 4 else "A_silver", shine=0.7, sep=False, outline=False)
    if lv == 4:
        Z.tassel(c, s0 - 4.6, 1.1, "A_cloth", cord="A_silver", ln=2.4)
    if lv == 5:
        shiny(c, s0 + 0.4, 0, 0.9, "A_garnet")
        c.tube([(hb + 1.2, 0.5), (hb + ln * 0.45, 0.3)], 0.32, "A_gold", shine=0.5, sep=False, outline=False)
        c.glint(hb + ln * 0.55, -0.9, "A_steel", 6)
    return tip


# ---------------------------------------------------------------- D Püsküllü
D_TASSEL = {1: ("A_rope", "A_rope"), 2: ("A_leather", "A_leather"), 3: ("A_paper", "A_brass"), 4: ("A_cloth", "A_silver"),
            5: ("A_cloth", "A_gold")}


def big_tassel(c, a, b, m, cord, ln, wid):
    """Soketten EKRANDA AŞAĞI sarkan gür püskül: düğüm + iplik demeti (aşağıda genişler, alt kenarı tırtıklı, iplik dokulu)."""
    dn = (-0.72, 0.72)  # ekranda aşağı (a, b)
    rt = (0.72, 0.72)  # ekranda sağ
    def at(k, q):
        return (a + dn[0] * k + rt[0] * q, b + dn[1] * k + rt[1] * q)
    ## iplik demeti: düğümden yelpaze gibi açılan ayrı iplikler (tek çokgen "kese" gibi okunuyordu); dış iplikler kısa
    n = 5
    for i in range(n):
        f = (i / (n - 1.0)) * 2.0 - 1.0  # -1 .. 1 (soldan sağa)
        lk = ln * (1.0 - 0.16 * abs(f)) * (0.94 if i == 1 else 1.0)
        bend = f * wid
        pts = [at(0.6, f * 0.5), at(lk * 0.45, bend * 0.62), at(lk, bend)]
        c.tube(pts, (0.62, 0.4), m, shine=0.15, sep=False)
    c.tube([at(0.4, -1.0), at(0.4, 1.0)], 0.75, cord, shine=0.45)
    c.sphere(at(-0.3, 0.0), 0.9, cord, shine=0.45)


def D_spear(c, lv):
    t = TA[lv]
    s0 = LV(lv, 9.5, 8.0)
    _shaft(c, lv, s0 + 0.5, r=LV(lv, 1.05, 1.2))
    m, cord = D_TASSEL[lv]
    _socket(c, lv, s0 - 3.0, s0 + 0.5, 1.3, 1.6)
    big_tassel(c, s0 - 2.4, 0.9, m, cord, LV(lv, 9.0, 12.0), LV(lv, 2.4, 3.2))
    tip = _leaf(c, lv, s0 + 0.2, LV(lv, 16.0, 20.5), LV(lv, 2.7, 3.5), wpos=0.3, mid=0.6)
    if lv == 5:
        c.tube([(s0 + 1.6, 0), (s0 + 9.0, 0)], 0.4, "A_gold", shine=0.5, sep=False, outline=False)
        shiny(c, s0 - 1.2, 0, 0.8, "A_garnet")
        c.glint(s0 + 8.5, -1.2, "A_steel", 6)
    return tip


DIRS = [("A", "A - Yaprak Uç", A_spear), ("B", "B - Kanatlı", B_spear), ("C", "C - Delici Şiş", C_spear), ("D", "D - Püsküllü", D_spear)]
TIPS = {}  # (yön, seviye) -> uç (a ekseni) - animasyon betiği uç ofsetini buradan okur


def build():
    os.makedirs(ART, exist_ok=True)
    for p in (os.path.join(HERE, "out", ".gdignore"),):
        if not os.path.exists(p):
            open(p, "w").close()
    imgs = {}
    frame("diag")
    for did, _, fn in DIRS:
        for lv in range(1, 6):
            cv = Cv(lv)
            TIPS[(did, lv)] = fn(cv, lv)
            img = cv.render()
            img.save(os.path.join(ART, "mizrak_%s_L%d.png" % (did, lv)))
            bb = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
            if bb and (bb[0] == 0 or bb[1] == 0 or bb[2] == N or bb[3] == N):
                print("KENAR!", did, lv, bb)
            imgs[(did, lv)] = img
    return imgs


def sheet(imgs, path, z=4):
    cell = N * z
    lw, gap, top = 170, 14, 40
    W = lw + 5 * (cell + gap) + gap
    H = top + len(DIRS) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        x0 = lw + gap + (lv - 1) * (cell + gap)
        d.text((x0, 10), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(20, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(did, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)
    print("sayfa", path, im.size)


def context(imgs):
    """Oyun ölçeği: 1 sanat px = 0,575 dünya px x zoom 2, Talon + Uzunkılıç L3 boy kıyası, resim x2."""
    zoom, wpp = 2.0, 0.575
    cwp = 2.2368375 * 0.8075 * 0.5
    ch_img = Image.open(os.path.join(E.GAME, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 96, 48, 144))
    sword = Image.open(os.path.join(E.GAME, "assets/weapons/zanaat/uzunkilic_L3.png")).convert("RGBA")
    cw, chh, lw, top = 50, 70, 120, 24
    W = lw + 110 + 5 * cw + 10
    H = top + len(DIRS) * (chh + 6)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 4), "Mızrak - oyun ölçeği (zoom 2)  ·  solda Talon + Uzunkılıç L3", fill=(235, 230, 215), font=font(12, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (chh + 6)
        d.text((8, y0 + chh // 2 - 8), label, fill=(235, 230, 215), font=font(12, True))
        pc = Image.new("RGB", (110 + 5 * cw, chh), S.BG)
        E.blit_world(pc, ch_img, 34, chh // 2 + 4, cwp, zoom)
        E.blit_world(pc, sword, 80, chh // 2, wpp, zoom)
        for lv in range(1, 6):
            E.blit_world(pc, imgs[(did, lv)], 110 + (lv - 1) * cw + cw // 2, chh // 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    path = os.path.join(OUT, "mizrak_sanat_oyun.png")
    im.resize((W * 2, H * 2), Image.NEAREST).save(path)
    print("oyun", path)


if __name__ == "__main__":
    imgs = build()
    sheet(imgs, os.path.join(OUT, "mizrak_sanat_sayfa.png"))
    context(imgs)
    print("uclar", {k: round(v, 1) for k, v in TIPS.items() if k[1] == 3})
