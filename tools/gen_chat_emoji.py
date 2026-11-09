# SOHBET EMOJILERI (madde 499, 2026-11-08; kullanici: "chate emoji butonu ve biraz emoji ekle"): 12 piksel emoji, 9x9, 1 doku pikseli = 1 sanat
# pikseli (pencerede 3x = 27 px, balonda 1 dunya pikseli). Dis hat HUD'un OUTLINE'i, sari yuz altin/pirinc tonlari (hud_theme PRICE/ACCENT/SPOT),
# kalp grup panelinin kalp paleti. Anahtar listesi scripts/chat_emoji.gd LIST ile AYNI sirada olmali.
#   python -I tools/gen_chat_emoji.py           -> assets/ui/emoji/<anahtar>.png  (+ tools/proto_20261108/sohbet/out/emoji_onizleme.png, 8x)
# Yeni PNG'den sonra: Godot --headless --path <proje> --import
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
OUT = os.path.join(ROOT, "assets", "ui", "emoji")

PAL = {
    "o": "#20150d",  # dis hat (HudTheme.OUTLINE)
    "e": "#3a2210",  # goz / agiz
    "y": "#f6d27e",  # yuz (PRICE)
    "h": "#fff0c8",  # isik
    "s": "#d09848",  # golge (ACCENT -> SPOT arasi)
    "a": "#f08a5a", "A": "#b8503a", "H": "#ffc0a0",  # kizgin yuz
    "p": "#f49a9a",  # dil / yanak
    "b": "#8cc4e8", "B": "#4a7fae",  # gozyasi, kol agzi
    "r": "#d8434e", "R": "#8e2230", "q": "#f49a9a", "w": "#fbf4e4",  # kalp / unlem
    "g": "#efe4c8", "G": "#b8a37e",  # kemik
    "f": "#f0a040", "F": "#d8574a", "Y": "#ffe08a",  # ates
    "m": "#d8dee6", "M": "#7a8694", "k": "#8a5a30", "K": "#f0c070",  # kilic: celik, kabza, balcak (ACCENT)
}

EMOJI = [
    ("gul", [
        "..ooooo..",
        ".ohyyyyo.",
        "ohyyyyyso",
        "oyyeyeyso",
        "oyyeyeyso",
        "oyeyyyeso",
        "oyyeeeyso",
        ".osyyyso.",
        "..ooooo..",
    ]),
    ("kahkaha", [
        "..ooooo..",
        ".ohyyyyo.",
        "ohyyyyyso",
        "oyeeyeeso",
        "oyyyyyyso",
        "oyeeeeeso",
        "oyeppeeso",
        ".oseeeso.",
        "..ooooo..",
    ]),
    ("uzgun", [
        "..ooooo..",
        ".ohyyyyo.",
        "ohyyyyyso",
        "oyyeyeyso",
        "oyybyeyso",
        "oyybyyyso",
        "oyyeeeyso",
        ".oeyyyeo.",
        "..ooooo..",
    ]),
    ("kizgin", [
        "..ooooo..",
        ".oHaaaao.",
        "oHeaaaeAo",
        "oaaeaeaAo",
        "oaaeaeaAo",
        "oaaaaaaAo",
        "oaaeeeaAo",
        ".oAaaaAo.",
        "..ooooo..",
    ]),
    ("saskin", [
        "..ooooo..",
        ".ohyyyyo.",
        "ohyeyeyso",
        "oyyeyeyso",
        "oyyyyyyso",
        "oyyyeyyso",
        "oyyeyeyso",
        ".osyeyso.",
        "..ooooo..",
    ]),
    ("kirp", [
        "..ooooo..",
        ".ohyyyyo.",
        "ohyyyeyso",
        "oyeeyeyso",
        "oyyyyyyso",
        "oyeyyyeso",
        "oyyeeeyso",
        ".osyppso.",
        "..ooooo..",
    ]),
    ("kalp", [
        ".........",
        ".oo...oo.",
        "oqwo.orro",
        "oqrrorrRo",
        "orrrrrrRo",
        ".orrrrRo.",
        "..orrRo..",
        "...oRo...",
        "....o....",
    ]),
    ("begen", [
        "....oo...",
        "...ohyo..",
        "...oyyo..",
        "oooyyyooo",
        "oBoyyyyyo",
        "oBoyyyyso",
        "oBoyyyyso",
        "oBoyyysso",
        "ooooooooo",
    ]),
    ("kafa", [
        "..ooooo..",
        ".oggggGo.",
        "oggggggGo",
        "oeeggeeGo",
        "oeeggeeGo",
        "ogggegggo",
        ".oGgggGo.",
        ".ogegegо.",
        "..ooooo..",
    ]),
    ("ates", [
        "....o....",
        "...oFo...",
        "..oFFo.o.",
        ".oFFfFoFo",
        ".oFffYfFo",
        "oFffYYfFo",
        "oFfYYYfFo",
        ".oFfYfFo.",
        "..ooooo..",
    ]),
    ("kilic", [
        "......ooo",
        ".....omMo",
        "....omMo.",
        "...omMo..",
        "o.omMo...",
        "oKoMo....",
        ".oKo.....",
        "oko.Ko...",
        "oo...o...",
    ]),
    ("yardim", [
        "..ooooo..",
        ".orrwrro.",
        "orrrwrrRo",
        "orrrwrrRo",
        "orrrwrrRo",
        "orrrrrrRo",
        "orrrwrrRo",
        ".oRRRRRo.",
        "..ooooo..",
    ]),
]


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def main():
    os.makedirs(OUT, exist_ok=True)
    prev = Image.new("RGBA", (len(EMOJI) * 11 * 8, 11 * 8), (39, 26, 17, 255))
    for i, (key, rows) in enumerate(EMOJI):
        assert len(rows) == 9, key
        im = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            row = row.replace("о", "o")  # kiril o yazim hatasina karsi
            assert len(row) == 9, (key, y, row)
            for x, ch in enumerate(row):
                if ch != ".":
                    im.putpixel((x, y), hex2rgba(PAL[ch]))
        im.save(os.path.join(OUT, key + ".png"))
        prev.paste(im.resize((72, 72), Image.NEAREST), (i * 88 + 8, 8), im.resize((72, 72), Image.NEAREST))
    PREV = os.path.join(HERE, "proto_20261108", "sohbet", "out")
    os.makedirs(PREV, exist_ok=True)
    prev.save(os.path.join(PREV, "emoji_onizleme.png"))
    print("ok", len(EMOJI))


if __name__ == "__main__":
    main()
