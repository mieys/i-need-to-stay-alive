# Tetiklenen esya efekt prototipleri: esya_capture.gd karelerinden esya basina yan yana (SU AN / A / B) GIF (2026-11-16).
# Calistir: python -I tools/proto_20261116/esya_tetik/esya_gif.py
import os, json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "oyun")
OUT = os.path.join(HERE, "out")
CX, CY = 400, 307  # karakter (kare pikseli; 1 dunya birimi = 3 px)
# esya: (ad, kutu yari genislik, yukari, asagi [px], {kod: etiket})
ITEMS = {
    "olum": ("Ölüm Eşiği", 150, 200, 90, {"now": "ŞU AN", "A": "A  Kum Saati", "B": "B  Boynuz Kemeri"}),
    "gunes": ("Güneşin İradesi", 150, 260, 90, {"now": "ŞU AN", "A": "A  Güneş Halesi", "B": "B  Gün Işığı"}),
    "anka": ("Tanrının Eli", 150, 290, 110, {"now": "ŞU AN", "A": "A  Işık Eli", "B": "B  Diriliş Halkası"}),
    "urkek": ("Ürkek Yürek", 200, 190, 90, {"A": "A  Çarpan Kalp", "B": "B  Kaçış İzi"}),
    "zaman": ("Gündüz ve Gece", 330, 290, 210, {"now": "ŞU AN", "A": "A  Tutulma", "B": "B  Gece Kubbesi"}),
    "kemik": ("Kemik Kolye", 200, 190, 110, {"A": "A  Diş Halkası", "B": "B  Çene Mührü"}),
}
STEP = 40
HDR = 40


def font(sz):
    for p in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


F = font(24)
tm = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))


def frames_for(key, box, t_list):
    ts = tm["times"][key]
    tr = tm["trig"][key]
    out = []
    for T in t_list:
        best = 0
        for i, t in enumerate(ts):
            if t - tr <= T:
                best = i
        out.append(Image.open(os.path.join(SRC, "%s_%03d.png" % (key, best))).convert("RGB").crop(box))
    return out


def build(item):
    name, hw, up, dn, labels = ITEMS[item]
    box = (CX - hw, CY - up, CX + hw, CY + dn)
    codes = [c for c in labels if "%s_%s" % (item, c) in tm["times"]]
    span = min(tm["times"]["%s_%s" % (item, c)][-1] - tm["trig"]["%s_%s" % (item, c)] for c in codes)
    t_list = list(range(-160, span, STEP))
    cols = {c: frames_for("%s_%s" % (item, c), box, t_list) for c in codes}
    w, h = box[2] - box[0], box[3] - box[1]
    gifs = []
    for k in range(len(t_list)):
        g = Image.new("RGB", (w * len(codes) + 6 * (len(codes) - 1), h + HDR), (20, 14, 10))
        d = ImageDraw.Draw(g)
        for j, c in enumerate(codes):
            x = j * (w + 6)
            g.paste(cols[c][k], (x, HDR))
            d.text((x + 10, 7), labels[c], fill=(255, 226, 160), font=F)
        gifs.append(g)
    key_i = min(len(gifs) - 1, (400 + 160) // STEP)
    gifs[key_i].save(os.path.join(OUT, "esya_%s.png" % item))
    pal = gifs[key_i].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in gifs]
    path = os.path.join(OUT, "esya_%s.gif" % item)
    q[0].save(path, save_all=True, append_images=q[1:] + [q[-1]] * 12, duration=STEP, loop=0)
    print(path, gifs[0].size, len(gifs), "kare", "%.1f MB" % (os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    for it in ITEMS:
        build(it)
