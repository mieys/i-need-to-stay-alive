#!/usr/bin/env python3
"""Buyucu Kiz pasif ikonu "Buyu Dalgasi" -> assets/skills/buyucu_passive_icon.png

Kullanim (repo kokunden):
    python tools/gen_buyucu_passive_icon.py      (sonra Godot'ta `--headless --import`)

Kullanici istegi (2026-10-04): yeni pasif - "her yetenek kullandiginda silahlari aniden sertce ileri itilip ayni anda atis
yaparak verdikleri sonraki atisin hasarini %30 arttirir". Eski "Kadim Patlama" ikonu (buyucu_passive_kadim_patlama_icon.png,
128 px boyama) yeni pasifi anlatmiyor. Dil gen_elara_korsan_icons.py ile ayni (48x48 sanat izgarasi, 1 px kontur, kare zemin,
3x NEAREST -> 144 px): mor arcane zemin; capraz yukari SERTCE itilen asa (arkasinda hiz cizgileri), ucundaki mor tastan
firlayan parlak arcane mermisi ve namlu halkasi.
"""
import os
import sys

from PIL import ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_elara_korsan_icons import C, canvas, finish, put, sparkle, tile  # noqa: E402


def buyucu_pasif():
    base = tile(C('#6a3aa8'), C('#1c0c36'), C('#8a5ad0'), C('#b48ae8'), C('#120626'))
    e = canvas()
    d = ImageDraw.Draw(e)
    WL, WM, WD = C('#e0ad70'), C('#a8703e'), C('#5e3a1e')       # asa (isik, orta, golge)
    GL, GM, GD = C('#ffe9a0'), C('#e8b440'), C('#9a6a1c')       # altin halka / pencer
    VL, VM, VD = C('#e6c8ff'), C('#a668f0'), C('#5a2aa0')       # mor tas
    # asa govdesi: sol alttan sag uste, 3 px kalin (ust-sol isik, alt-sag golge)
    d.polygon([(7, 38), (10, 41), (29, 22), (26, 19)], fill=WM)
    d.line((7, 38, 26, 19), fill=WL)
    d.line((10, 41, 29, 22), fill=WD)
    # sap ucundaki altin topuz + sargi
    d.rectangle((6, 39, 8, 41), fill=GM)
    put(e, [(6, 39)], GL)
    d.line((15, 31, 18, 34), fill=GD)
    d.line((16, 30, 19, 33), fill=GM)
    # bas: altin pencer + mor tas (elmas)
    d.polygon([(25, 19), (28, 16), (31, 19), (28, 22)], fill=GM)
    put(e, [(25, 19), (28, 16)], GL)
    d.polygon([(28, 12), (33, 15), (33, 20), (28, 18)], fill=VM)
    d.polygon([(28, 12), (31, 14), (28, 18)], fill=VL)
    d.line((33, 15, 33, 20), fill=VD)
    put(e, [(29, 13)], C('#ffffff'))
    # firlayan arcane mermisi (uste cizilecek, konturlu kutle)
    d.ellipse((35, 4, 43, 12), fill=VM)
    d.ellipse((36, 5, 41, 10), fill=VL)
    d.ellipse((37, 6, 39, 8), fill=C('#ffffff'))
    fx = canvas()
    f = ImageDraw.Draw(fx)
    # namlu halkasi (tas ile mermi arasinda yassi hilal)
    put(fx, [(33, 11), (34, 10), (35, 13), (36, 14), (34, 13)], C('#d8b4ff'))
    put(fx, [(32, 12), (35, 15)], C('#f4e6ff'))
    # asanin arkasindaki hiz cizgileri (itilme yonune paralel, kontursuz)
    for (x0, y0, x1, y1, col) in ((3, 33, 9, 27, C('#c9a2f6')), (11, 45, 16, 40, C('#c9a2f6')), (5, 43, 8, 40, C('#9d6ee0')),
                                  (14, 27, 17, 24, C('#9d6ee0'))):
        f.line((x0, y0, x1, y1), fill=col)
    # merminin izi (geriye dogru incelen 2 cizgi)
    f.line((32, 16, 35, 13), fill=C('#e6c8ff'))
    sparkle(fx, 44, 17, C('#ffffff'), C('#e6c8ff'), 1)
    sparkle(fx, 40, 32, C('#ffffff'), C('#c9a2f6'), 2)
    sparkle(fx, 22, 8, C('#ffffff'), C('#c9a2f6'), 1)
    finish(base, e, fx, "buyucu_passive_icon.png")


if __name__ == "__main__":
    print("Buyucu pasif ikonu:")
    buyucu_pasif()
