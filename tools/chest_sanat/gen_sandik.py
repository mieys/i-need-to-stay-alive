"""Sandik + envanter cantasi sanati (madde 557, 2026-11-11). Kullanici cizimleri 32x32 piksel (tools/chest_sanat/*.png):
siradan_kapali / siradan_acik / elit_kapali / elit_acik / envanter_canta. Cizime DOKUNULMAZ - yalniz diziliyor:
  - assets/sprites/chests/sandik_normal.png, sandik_elit.png = 64x32, kare 0 KAPALI, kare 1 ACIK. Acik sandik cizimi kapaliya gore
    3 px asagida durdugu icin (govde tabani 31, kapali 28) KAPALI kare 3 px asagi kaydirilir; ikisinin tabani y=31 (chest_art.gd
    CHEST_ANCHOR_PX (16, 31)) - sandik acilirken yerinde kalir. Kaydirma dogrulanir: govde alt satirlari piksel piksel eslesmeli.
  - assets/ui/kit/hud_icon_bag.png = envanter cantasi (ENVANTER dugmesi), 32x32 oldugu gibi.
Kullanim: python -I tools/chest_sanat/gen_sandik.py   (repo kokunden)"""
import os
from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CHESTS = os.path.join(ROOT, "assets", "sprites", "chests")
KIT = os.path.join(ROOT, "assets", "ui", "kit")
SHIFT = 3


def load(name):
    im = Image.open(os.path.join(HERE, name)).convert("RGBA")
    assert im.size == (32, 32), (name, im.size)
    return im


def sheet(kind):
    closed, opened = load(kind + "_kapali.png"), load(kind + "_acik.png")
    shifted = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    shifted.paste(closed, (0, SHIFT))
    a, b = np.array(shifted), np.array(opened)
    reg = (slice(22, 32), slice(0, 32))
    same = (a[reg] == b[reg]).all(axis=2).sum()
    assert same >= 280, "%s: kapali/acik govde hizasi tutmuyor (%d/320)" % (kind, same)
    assert closed.getbbox()[3] + SHIFT == opened.getbbox()[3] == 31, (kind, closed.getbbox(), opened.getbbox())
    out = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out.paste(shifted, (0, 0))
    out.paste(opened, (32, 0))
    return out


def main():
    os.makedirs(CHESTS, exist_ok=True)
    sheet("siradan").save(os.path.join(CHESTS, "sandik_normal.png"))
    sheet("elit").save(os.path.join(CHESTS, "sandik_elit.png"))
    load("envanter_canta.png").save(os.path.join(KIT, "hud_icon_bag.png"))
    print("yazildi sandik_normal.png / sandik_elit.png / hud_icon_bag.png")


if __name__ == "__main__":
    main()
