"""Efsun kartı dokuları -> assets/ui/game/levelup_enchant_card_{1..5}.png + levelup_enchant_glow.png

Çalıştır:  python tools/gen_enchant_card.py   (sonra Godot'ta `--headless --import`)

Kullanıcının efsun sistemi için sakladığı "A9 - İpucu Tarzı" kart (hafıza: project-enchant-system-card-style), efsun
ekranında metin daha uzun olduğu için 120x180 sanat px'e (3x = 360x540) büyütüldü; oranlar/katmanlar aynı:
  - 1 px koyu kontur, 1 px tier renkli çerçeve (üst satır "hi", alt satır "dk"), 1 px tier "deep" iç çizgi,
    gövde = mix(#2b2a30, tier deep, 0.35)
  - sol üstte 26x26 ikon yuvası (9,9): kontur + tier "lt" halka + tier "dd" iç
  - altta gömük koyu metin alanı (x 10..110, y 41..170): #1f1e23, üst/sol #161519 gölge, alt/sağ #34323a ışık
  - Tier 1 GRİ, 2-4 TIER_FIELD (mavi/mor/kırmızı; Tier 4 çerçevesi altın), 5 = FİNAL kartı (altın çerçeve, koyu altın gövde)
Kartın yazıları (tier adı, kategori, ad, değer, açıklama) enchant_screen.gd'de kodla. "levelup_" öneki arayüz koyulaştırma
eğrisinden muaf (bkz. gen_menu_kit.DEEPEN_EXEMPT_PREFIXES).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_menu_kit as K  # noqa: E402
from ui_kit_lib import Art, hexc, mix  # noqa: E402

W, H = 120, 180
ICON_X, ICON_Y, ICON_S = 9, 9, 26
TEXT_X0, TEXT_X1, TEXT_Y0, TEXT_Y1 = 10, 110, 41, 170

FINAL_PAL = dict(hi=K.GOLD_L, lt=K.GOLD, md=K.GOLD, dk=K.GOLD_D, dd=hexc('#5a3d10'), deep=hexc('#3a2708'))


def _pal(t):
    if t == 5:
        return FINAL_PAL, dict(hi=K.GOLD_L, md=K.GOLD, dk=K.GOLD_D)
    f = K.LEVELUP_TIER.get(t, K.TIER_FIELD[t])
    rim = dict(hi=K.GOLD_L, md=K.GOLD, dk=K.GOLD_D) if t == 4 else dict(hi=f['hi'], md=f['md'], dk=f['dk'])
    return f, rim


def enchant_card(t):
    f, rim = _pal(t)
    body = mix(K.LEVELUP_BODY, f['deep'], 0.35 if t != 5 else 0.5)
    a = Art(W, H)
    for y in range(H):
        for x in range(W):
            d = min(x, y, W - 1 - x, H - 1 - y)
            if d == 0:
                c = K.OUTL
            elif d == 1:
                c = rim['hi'] if y == 1 else rim['dk'] if y == H - 2 else rim['md']
            elif d == 2:
                c = f['deep']
            else:
                c = body
            a.set(x, y, c)
    # ikon yuvası
    for y in range(ICON_Y, ICON_Y + ICON_S):
        for x in range(ICON_X, ICON_X + ICON_S):
            d = min(x - ICON_X, ICON_X + ICON_S - 1 - x, y - ICON_Y, ICON_Y + ICON_S - 1 - y)
            a.set(x, y, K.OUTL if d == 0 else f['lt'] if d == 1 else f['dd'])
    # gömük metin alanı
    for y in range(TEXT_Y0, TEXT_Y1):
        for x in range(TEXT_X0, TEXT_X1):
            if y == TEXT_Y0 or x == TEXT_X0:
                c = hexc('#161519')
            elif y == TEXT_Y1 - 1 or x == TEXT_X1 - 1:
                c = hexc('#34323a')
            else:
                c = hexc('#1f1e23')
            a.set(x, y, c)
    return a


def build():
    K.use_palette(K.GAME_PAL, os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'game'))
    os.makedirs(K.OUTDIR, exist_ok=True)
    for t in range(1, 6):
        K.save(enchant_card(t), 'levelup_enchant_card_%d.png' % t)
    K.save(K.tier_card_glow(W, H, 5, 0), 'levelup_enchant_glow.png')
    print('enchant cards written to', os.path.abspath(K.OUTDIR))


if __name__ == '__main__':
    build()
