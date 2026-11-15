# Shaman Q (Saldırı Totemi) / E (Kalkan Totemi) yetenek ikonları KULLANICININ RÜN TAŞINDAN (madde 557/569 dokuları).
# Özne = oyundaki gibi: taş (<q|e>_tas.png) + akkor evrimsiz rün (runler sütun 0, satır 0) + 3 halkalı hale (sütun 1)
# + taşın dışındaki parıltı (<q|e>_tas_isik.png). Zemin = öteki ikonlarla aynı paket zemini (Genel iconlar önizlemesi,
# iksir_zemin ile aynı yol), YALNIZ TON rünün rengine döner. Biçim oyunun kuralı: 48x48 sanat x3 = 144.
# Kullanım: python -I shaman_ikon.py            -> out/ozet.png (seçenekler) + out/<q|e>_<A..D>.png
#           python -I shaman_ikon.py --uygula X -> X seçeneğini assets/skills/'e yazar (eskiler yetenek_ikon/yedek/'te)
import os, sys, shutil
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
IKON = os.path.join(HERE, "..", "..", "proto_20261109", "yetenek_ikon")
sys.path.insert(0, os.path.abspath(IKON))
import ikon_secim as K  # noqa: E402
import renk_ayar as R  # noqa: E402

ROOT = K.ROOT
STONE = os.path.join(ROOT, "assets", "shaman", "rune_stone")
SKILLS = os.path.join(ROOT, "assets", "skills")
YEDEK = os.path.join(os.path.abspath(IKON), "yedek")
OUT = os.path.join(HERE, "out")
ART, SCALE, WORK = 48, 3, 192

# yuva -> (dosya, zemin tonu = rünün hale rengi, oyundaki ikon)
SLOTS = {
    "q": ("shaman_saldiri_totemi_icon", (255, 122, 42)),   # Q hale #ff7a2a
    "e": ("shaman_kalkan_totemi_icon", (58, 124, 224)),    # E hale #3a7ce0
}

# seçenek -> (ad, paket zemini, özne ölçeği, zemin parlaklık çarpanı)
#   ölçek None = 1:1 piksel (48 ızgarada birebir, keskin); sayı = taşın yüksekliği karonun bu oranı (paket konuları gibi)
VARIANTS = {
    "A": ("Paket ölçeği, ışınlar", "PRI-C1", 0.80, 1.0),
    "B": ("Birebir piksel, ışınlar", "PRI-C1", None, 1.0),
    "C": ("Birebir piksel, ışık perdesi", "PRI-C2", None, 1.0),
    "D": ("Birebir piksel, kısık ışınlar", "PRI-C1", None, 0.62),
}


def subject(slot):
    """36x36 RGBA: taş parıltısı + taş + hale + akkor rün (oyundaki katman sırası), taşın kutusu da döner."""
    glow = Image.open(os.path.join(STONE, "%s_tas_isik.png" % slot)).convert("RGBA")
    tas = Image.open(os.path.join(STONE, "%s_tas.png" % slot)).convert("RGBA")
    runs = Image.open(os.path.join(STONE, "%s_runler.png" % slot)).convert("RGBA")
    hot, halo = runs.crop((0, 0, 32, 32)), runs.crop((32, 0, 64, 32))
    c = Image.new("RGBA", (36, 36), (0, 0, 0, 0))
    g = np.asarray(glow).copy()
    g[..., 3] = (g[..., 3] * 0.9).astype(np.uint8)
    c.alpha_composite(Image.fromarray(g, "RGBA"))
    for layer in (tas, halo, hot):
        c.alpha_composite(layer, (2, 2))
    bb = tas.getbbox()
    return c, (bb[0] + 2, bb[1] + 2, bb[2] + 2, bb[3] + 2)


def background(icons, slot, tmpl, val):
    bg = icons[tmpl].convert("RGB").resize((WORK, WORK), Image.LANCZOS)
    bg = R.rotate_hue(bg, SLOTS[slot][1])
    if val != 1.0:  # çerçeve (dış 2 sanat px) aynı kalır, yalnız iç kısılır
        a = np.asarray(bg).astype(float)
        m = np.zeros(a.shape[:2], bool)
        b = 3 * WORK // ART
        m[b:-b, b:-b] = True
        a[m] *= val
        bg = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    return bg.convert("RGBA")


def compose(icons, slot, key):
    _, tmpl, scale, val = VARIANTS[key]
    bg = background(icons, slot, tmpl, val)
    s, bb = subject(slot)
    if scale is None:  # 48 ızgarada 1:1: zemin 48'e iner, özne birebir ortalanır (taş kutusuna göre)
        img = bg.resize((ART, ART), Image.LANCZOS)
        cx = (bb[0] + bb[2]) / 2.0
        cy = (bb[1] + bb[3]) / 2.0
        img.alpha_composite(s, (int(round(ART / 2.0 - cx)), int(round(ART / 2.0 - cy))))
        return img
    k = 8  # iksir_zemin.compose_pack yolu: en yakın x8, sonra hedef boya yumuşak iniş
    big = s.resize((s.width * k, s.height * k), Image.NEAREST)
    f = (WORK * scale) / ((bb[3] - bb[1]) * k)
    big = big.resize((round(big.width * f), round(big.height * f)), Image.LANCZOS)
    cx = (bb[0] + bb[2]) / 2.0 * k * f
    cy = (bb[1] + bb[3]) / 2.0 * k * f
    bg.alpha_composite(big, (int(round(WORK / 2.0 - cx)), int(round(WORK / 2.0 - cy))))
    return bg.resize((ART, ART), Image.LANCZOS)


def ozet(cur_icons, made):
    f, fb = K.font(14), K.font(16, True)
    S = 96
    keys = list(VARIANTS)
    cols = ["ÖNCEKİ"] + ["%s  %s" % (k, VARIANTS[k][0]) for k in keys]
    CW = 230
    im = Image.new("RGB", (60 + CW * len(cols), 64 + 2 * (S + 40) + 120), K.BG)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "SHAMAN Q / E İKONU rün taşından (burada x2; altta oyundaki 48 px, yanında Pasif + R)",
           fill=K.GOLD, font=K.font(18, True))
    for ci, c in enumerate(cols):
        d.text((60 + ci * CW, 44), c, fill=K.DIM, font=f)
    for ri, slot in enumerate(SLOTS):
        y = 64 + ri * (S + 40)
        d.text((14, y + S // 2 - 8), slot.upper(), fill=K.INK, font=fb)
        cur = cur_icons[slot].resize((S, S), Image.LANCZOS)
        im.paste(cur, (60, y), cur)
        for ki, k in enumerate(keys):
            n = made[(slot, k)].resize((S, S), Image.NEAREST)
            im.paste(n, (60 + (ki + 1) * CW, y), n)
    # oyundaki boy: her seçenek için P Q E R şeridi 48 px
    y = 64 + 2 * (S + 40) + 10
    d.text((14, y), "48 px", fill=K.DIM, font=f)
    p = Image.open(os.path.join(SKILLS, "shaman_passive_icon.png")).convert("RGBA").resize((ART, ART), Image.LANCZOS)
    r = Image.open(os.path.join(SKILLS, "shaman_elemental_golem_icon.png")).convert("RGBA").resize((ART, ART), Image.LANCZOS)
    for ki, k in enumerate(keys):
        x = 60 + (ki + 1) * CW
        for j, ic in enumerate([p, made[("q", k)], made[("e", k)], r]):
            im.paste(ic, (x + j * (ART + 4), y + 24), ic)
    im.save(os.path.join(OUT, "ozet.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = K.load_icons()
    # "ÖNCEKİ" = rün taşından önceki oyun ikonu (paket ikonu). Bir kez out/onceki_<q|e>.png'ye alınır; --uygula ezse de kalır.
    cur_icons = {}
    for slot, (name, _) in SLOTS.items():
        keep = os.path.join(OUT, "onceki_%s.png" % slot)
        if not os.path.exists(keep):
            shutil.copy2(os.path.join(SKILLS, name + ".png"), keep)
        cur_icons[slot] = Image.open(keep).convert("RGBA")
    made = {}
    for slot in SLOTS:
        for k in VARIANTS:
            ic = compose(icons, slot, k)
            made[(slot, k)] = ic
            ic.resize((ART * SCALE, ART * SCALE), Image.NEAREST).save(os.path.join(OUT, "%s_%s.png" % (slot, k)))
    if "--uygula" in sys.argv:
        k = sys.argv[sys.argv.index("--uygula") + 1].upper()
        os.makedirs(YEDEK, exist_ok=True)
        for slot, (name, _) in SLOTS.items():
            src = os.path.join(SKILLS, name + ".png")
            bak = os.path.join(YEDEK, name + ".png")
            if not os.path.exists(bak):
                shutil.copy2(src, bak)
            made[(slot, k)].resize((ART * SCALE, ART * SCALE), Image.NEAREST).save(src)
            print("yazıldı:", src)
    ozet(cur_icons, made)
    print("özet:", os.path.join(OUT, "ozet.png"))


if __name__ == "__main__":
    main()
