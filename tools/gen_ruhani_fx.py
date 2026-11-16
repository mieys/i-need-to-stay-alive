"""Ruhani yetenek efektlerinin pişmiş dokuları (madde 734; kullanıcı seçimi 2026-11-16: Can A, Adc B, Tank B, Taktiksel A,
Kalkan Bağı A - prototip tools/proto_20261116/ruhani_fx/, madde 730). Çizim kalıpları prototipten alınır (aynı şekil/renk/bant).
1 doku pikseli = 1 dünya birimi (FX kökleri scale 2 ile 0,5 ölçekli Player/RemotePlayer'ın içinde dünya birimine çıkar).
TİTREŞİM YOK: yumuşaklık yalnız düz alfa bantları. Oyunda modulate ile renk/sönüm verilenler BEYAZ pişer.
Çıktı assets/fx/ruhani/:
  ring_ground.png  23 kare, rx 4..26 (ry = 0,42 rx), 1 px beyaz yer halkası (Can iniş halkası, Adc açılış, Taktiksel varış)
  ring_tall.png    10 kare, rx 5..14 (ry = 1,25 rx), 1 px beyaz dikey halka (Kalkan Bağı varış)
  shell_white.png  rx 12 ry 18 kenara koyulaşan (fresnel) 3 bantlı beyaz kabuk (Kalkan Bağı varış parlaması)
  can_shell.png    6 kare: açılış s 0,25/0,5/0,75/1 + nefes -0,6/+0,6; altın kabuk + kenar (üst krem)
  can_glow.png     iniş ışık havuzu (altın -> krem, 3 bant)
  adc_sigil.png    5 kare: kızıl mühür çizilerek açılır (0,2..1,0 tur) + iç ışık
  tank_hex.png     30 kare: 6 çizim karesi (kenar kenar) + 24 dönüş karesi (60 derece = tam döngü), köşelerde altın perçin
  kb_dot.png       3 kare: boncuk r 4,5 / uç ışığı r 3,5 / r 4,1 (mavi -> krem, 3 bant, alfa 1; oyunda modulate)
Kullanım (proje kökünden): python -I tools/gen_ruhani_fx.py
"""
import importlib.util
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
_spec = importlib.util.spec_from_file_location('rf', os.path.join(HERE, 'proto_20261116', 'ruhani_fx', 'ruhani_fx_proto.py'))
RF = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(RF)
OUT = os.path.join(PROJECT, 'assets', 'fx', 'ruhani')
WHITE = (255, 255, 255)
TAU = math.tau


def frame(w, h):
    """(w x h) katman; merkez (w/2, h/2) dünya (0, 0)'a denk."""
    return RF.Layer(-w // 2, -h // 2, w, h)


def sheet(frames, path):
    w, h = frames[0].w, frames[0].h
    out = Image.new('RGBA', (w * len(frames), h))
    for i, L in enumerate(frames):
        out.alpha_composite(L.img(), (i * w, 0))
    arr = np.array(out)[:, :, 3]
    for i in range(len(frames)):
        f = arr[:, i * w:(i + 1) * w]
        assert not (f[0].any() or f[-1].any() or f[:, 0].any() or f[:, -1].any()), (path, i, 'kenara değiyor')
    out.save(os.path.join(OUT, path))
    print(path, out.size, len(frames), 'kare')


def ring_ground():
    fs = []
    for rx in range(4, 27):
        L = frame(58, 28)
        L.pm(RF.m_ring(0.0, 0.0, rx, rx * 0.42), WHITE, 1.0)
        fs.append(L)
    sheet(fs, 'ring_ground.png')


def ring_tall():
    fs = []
    for rx in range(5, 15):
        L = frame(34, 42)
        L.pm(RF.m_ring(0.0, 0.0, rx, rx * 1.25), WHITE, 1.0)
        fs.append(L)
    sheet(fs, 'ring_tall.png')


def shell_white():
    L = frame(30, 42)
    RF.shell(L, 0.0, 0.0, 12, 18, WHITE, 1.0, 3, 3.0)
    sheet([L], 'shell_white.png')


def can_shell():
    fs = []
    for (s, br) in ((0.25, 0.0), (0.5, 0.0), (0.75, 0.0), (1.0, 0.0), (1.0, -0.6), (1.0, 0.6)):
        L = frame(30, 44)
        rx, ry = (11 + br) * s, (18 + br) * s
        RF.shell(L, 0.0, 0.0, rx, ry, RF.GOLD[4], 0.25, 3, 3.0)
        x0, y0, m = RF.m_ell(0.0, 0.0, rx, ry)
        rim = m & ~RF.ero(m)
        ys = np.arange(m.shape[0])[:, None] + y0 + 0.5
        L.put(x0, y0, rim & (ys < -ry * 0.35), RF.CREAM, 0.75)
        L.put(x0, y0, rim & (ys >= -ry * 0.35), RF.GOLD[3], 0.5)
        fs.append(L)
    sheet(fs, 'can_shell.png')


def can_glow():
    L = frame(34, 18)
    RF.glow(L, 0.0, 0.0, 14, 5.5, RF.GOLD[2], RF.CREAM, 0.6, 3)
    sheet([L], 'can_glow.png')


def adc_sigil():
    fs = []
    a0 = -math.pi / 2
    for f in (0.2, 0.4, 0.6, 0.8, 1.0):
        L = frame(42, 22)
        RF.glow(L, 0.0, 0.0, 18, 7.5, RF.FIRE[2], RF.FIRE[3], 0.2 * f, 2)
        L.pm(RF.m_arc(0.0, 0.0, 18, 7.5, a0, a0 + f * TAU), RF.FIRE[3], 1.0)
        L.pm(RF.m_arc(0.0, 0.0, 13.5, 5.6, a0, a0 + f * TAU), RF.FIRE[2], 0.75)
        fs.append(L)
    sheet(fs, 'adc_sigil.png')


def tank_hex():
    fs = []

    def draw(L, rot, edges):
        V = [(18 * math.cos(rot + k * TAU / 6), 8 * math.sin(rot + k * TAU / 6)) for k in range(6)]
        for k in range(edges):
            L.pm(RF.m_line(V[k], V[(k + 1) % 6]), RF.STEEL[3], 0.85)
        for k in range(min(6, edges + 1)):
            RF.sparkle(L, V[k][0], V[k][1], 1, RF.GOLD[4], RF.GOLD[2], 1.0)
    for e in range(1, 7):
        L = frame(44, 24)
        draw(L, 0.0, e)
        fs.append(L)
    for i in range(24):
        L = frame(44, 24)
        draw(L, i * (TAU / 6) / 24, 6)
        fs.append(L)
    sheet(fs, 'tank_hex.png')


def kb_dot():
    fs = []
    for r in (4.5, 3.5, 4.1):
        L = frame(14, 14)
        RF.glow(L, 0.0, 0.0, r, r, RF.MANA[3], RF.CREAM, 1.0, 3)
        fs.append(L)
    sheet(fs, 'kb_dot.png')


def main():
    os.makedirs(OUT, exist_ok=True)
    ring_ground()
    ring_tall()
    shell_white()
    can_shell()
    can_glow()
    adc_sigil()
    tank_hex()
    kb_dot()


if __name__ == '__main__':
    main()
