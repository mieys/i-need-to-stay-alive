# KARAKTERE OZEL PORTRE ARKA PLANLARI prototipi (2026-11-08, madde 459 devami; oyuna bagli DEGIL). Kullanici: "portre arkaplanlari karakterin
# temasiyla uyumlu olacak sekilde her karaktere uygun portre arkaplani tasarlamani istiyorum bu ornekleri bana sun onayladigimda ekleriz".
# Her arka plan 28x28 SANAT PIKSELI = yuz kirpiminin (24x24, LobbyUI.face_texture) piksel izgarasi; oyunda yuzle ayni 2x cizilir.
# Kurallar: duz bantlar + karakterin kitinden TEK basit motif, dither / hale / parilti yok (sandik v3 dersi); yuzun baskin renginin
# karsiti secilir (mor sapka -> gece mavisi, siyah sac -> acik gok) ki yuz okunsun.
# Cikti: out/bg/<id>.png (28x28) + out/ozet.png (panel portresi + grup satiri, gercek yuz ve tepsi dokulariyla, 2x buyutulmus)
#   python -I tools/proto_20261108/portre_tema/gen_portre_tema.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
os.makedirs(os.path.join(OUT, "bg"), exist_ok=True)
N = 28


def C(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def bands(cols, weights):
    im = Image.new("RGBA", (N, N))
    tot = sum(weights)
    edges, acc = [], 0
    for w in weights:
        acc += w
        edges.append(round(N * acc / tot))
    for y in range(N):
        i = next(k for k, e in enumerate(edges) if y < e)
        for x in range(N):
            im.putpixel((x, y), C(cols[i]))
    return im


def px(im, pts, col):
    c = C(col)
    for x, y in pts:
        if 0 <= x < N and 0 <= y < N:
            im.putpixel((x, y), c)


def rect(im, x, y, w, h, col):
    px(im, [(i, j) for i in range(x, x + w) for j in range(y, y + h)], col)


def disc(im, cx, cy, r, col):
    px(im, [(x, y) for x in range(N) for y in range(N) if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r], col)


def star(im, x, y, col):  # 4 koseli kucuk yildiz (3x3 arti)
    px(im, [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], col)


def silhouette(im, heights, col):  # her sutun icin alttan yukseklik
    for x, h in enumerate(heights[:N]):
        rect(im, x, N - h, 1, h, col)


# ---------------------------------------------------------------- karakterler
def talon():  # Ayna Formu kirmizi-siyah, guc yiginlari: koyu tugla kirmizi + iki ayna kiymigi cizgisi
    im = bands(["#9c4436", "#7e3229", "#5e241f", "#3f1916"], [3, 3, 3, 2])
    for k in range(9):
        px(im, [(3 + k, 13 - k), (17 + k, 22 - k)], "#c97a62")
        px(im, [(4 + k, 13 - k), (18 + k, 22 - k)], "#b25c48")
    return im


def oakley():  # ari surusu, sarmasik, cicek: acik cayir + alt koselerde kucuk cicekler
    im = bands(["#cfe0b0", "#b8d096", "#9cbc7a", "#7fa060", "#66874c"], [3, 3, 3, 2, 2])
    for (x, y, c) in [(2, 24, "#f4e06a"), (5, 26, "#f6f0e0"), (23, 25, "#f4e06a"), (26, 23, "#e9a0b0")]:
        star(im, x, y, c)
        px(im, [(x, y)], "#c27a2a")
    return im


def matthew():  # simsek kiti, sari-altin: firtina arduvazi + sagda zikzak yildirim
    im = bands(["#6d7b8e", "#5b6878", "#4a5564", "#3b4450"], [3, 3, 3, 2])
    bolt = [(22, 2), (22, 3), (21, 4), (21, 5), (20, 6), (20, 7), (21, 7), (22, 7), (22, 8), (21, 9), (21, 10), (20, 11), (20, 12),
            (19, 13), (20, 13), (21, 13), (21, 14), (20, 15), (20, 16), (19, 17)]
    px(im, bolt, "#f6d27e")
    px(im, [(x + 1, y) for x, y in bolt], "#c8962e")
    return im


def buyucu():  # mor sapka/sac -> karsit gece mavisi, meteor (R) + soguk/sicak set: ufukta sicak bant + birkac yildiz
    im = bands(["#202a4e", "#2a3762", "#344478", "#4a4a7e", "#a8664a"], [3, 3, 3, 2, 1])
    for (x, y) in [(4, 4), (23, 6), (25, 15), (3, 15)]:
        star(im, x, y, "#e8e4f6")
    px(im, [(19 + k, 2 + k) for k in range(5)], "#f0b070")  # meteor izi
    px(im, [(24, 7)], "#fff0d0")
    return im


def assasin():  # siyah sac -> acik ay isigi; gece kesigi: kizil capraz kesik
    im = bands(["#a7b0c0", "#8e98aa", "#768094", "#5e677c"], [3, 3, 3, 2])
    for k in range(26):
        px(im, [(1 + k, 26 - k)], "#b8323a")
        if 0 < k < 25:
            px(im, [(2 + k, 26 - k)], "#e06a62")
    return im


def sovalye():  # mavi zirh + sari sac -> sicak gri tas duvar; kenarda kirmizi sancak
    im = bands(["#9a948a", "#8e887e", "#817b72"], [1, 1, 1])
    for y in range(0, N, 5):
        rect(im, 0, y, N, 1, "#6c675f")
        off = 0 if (y // 5) % 2 == 0 else 4
        for x in range(off, N, 8):
            rect(im, x, y, 1, 5, "#6c675f")
    rect(im, 22, 0, 5, 16, "#9e3a34")
    rect(im, 22, 0, 1, 16, "#c25a4c")
    px(im, [(22, 16), (23, 17), (24, 18), (26, 16), (25, 17)], "#9e3a34")
    return im


def elara():  # okcu, ruzgar (turkuaz), orman: acik nane gok + koyu cam siluetleri
    im = bands(["#cfe6dc", "#b2d6c8", "#94c2b2", "#7aac9a"], [3, 3, 2, 2])
    h = []
    for x in range(N):
        t = x % 7
        h.append([4, 6, 9, 12, 9, 6, 4][t] + (2 if x // 7 % 2 else 0))
    silhouette(im, h, "#3e6a4e")
    silhouette(im, [max(0, v - 4) for v in h], "#2f553e")
    px(im, [(3 + k, 5) for k in range(6)] + [(9, 4), (10, 4)], "#e8f4ee")  # ruzgar cizgisi
    return im


def korsan():  # deniz, ufuk, dalga sirtlari; siyah sapka -> acik gok
    im = bands(["#a9d0e6", "#c4e0ee", "#3f7aa0", "#336a8e", "#285a7c"], [6, 4, 2, 2, 2])
    for (x, y) in [(3, 19), (12, 21), (21, 19), (7, 24), (17, 25), (25, 23)]:
        px(im, [(x, y), (x + 1, y), (x + 2, y), (x + 1, y - 1)], "#e8f4f8")
    return im


def melek():  # isik, hale: sakin gok mavisi + ust koselerde beyaz bulut (kanatlar beyaz -> bulut altta degil)
    im = bands(["#8fb6dc", "#a3c4e4", "#b8d3ec", "#cde0f2"], [3, 3, 3, 2])
    for (cx, cy) in [(4, 4), (23, 3)]:
        rect(im, cx - 3, cy, 7, 2, "#f4f8fc")
        rect(im, cx - 1, cy - 1, 3, 1, "#f4f8fc")
        rect(im, cx - 3, cy + 2, 7, 1, "#d8e6f4")
    return im


def necromancer():  # mezarlik gecesi: koyu yesil-gri sis + soluk ay + mezar taslari
    im = bands(["#3e4a44", "#46544b", "#526256", "#5e7060", "#2e3a32"], [3, 3, 3, 2, 1])
    disc(im, 22, 6, 3.2, "#d8dcc4")
    for (x, h) in [(2, 7), (9, 5), (19, 6)]:
        rect(im, x, N - h, 4, h, "#24302a")
        rect(im, x + 1, N - h - 1, 2, 1, "#24302a")
    rect(im, 0, 20, N, 1, "#7a8e7a")  # sis cizgisi
    return im


def shaman():  # elementler (ates cekirdegi), tas totem, boynuz -> turuncu gun batimi + kahve dag siluetleri
    im = bands(["#e3a462", "#d68a4c", "#c0723c", "#a45e32"], [3, 3, 3, 2])
    h = [5, 6, 8, 10, 12, 13, 12, 10, 9, 8, 9, 11, 13, 15, 16, 15, 13, 11, 9, 8, 7, 8, 10, 11, 10, 8, 7, 6]
    silhouette(im, h, "#6a4228")
    silhouette(im, [max(0, v - 6) for v in h[::-1]], "#4e2f1e")
    return im


def vampir():  # kan, yarasa, gece: mor-lacivert + buyuk soluk ay + iki yarasa
    im = bands(["#2c2440", "#3a2e52", "#4a3862", "#3a2a4c"], [3, 3, 3, 2])
    disc(im, 14, 9, 7.5, "#e8d8c8")
    disc(im, 16, 8, 2, "#d4c2b0")
    for (x, y) in [(3, 5), (22, 17)]:
        px(im, [(x, y), (x + 1, y + 1), (x + 2, y), (x + 3, y + 1), (x + 4, y), (x + 2, y + 1)], "#1a1424")
    return im


def hadime():  # lanet kitabi: eski sayfa (siyah ortu -> acik zemin) + soluk mor rün halkasi
    im = bands(["#e8d6b0", "#dcc69c", "#cfb588", "#bea173"], [3, 3, 3, 2])
    ring = [(x, y) for x in range(N) for y in range(N) if 9.2 <= ((x - 13.5) ** 2 + (y - 13.5) ** 2) ** 0.5 <= 10.2]
    px(im, ring, "#9a7ca8")
    for (x, y) in [(13, 2), (24, 13), (13, 24), (2, 13)]:
        rect(im, x, y, 2, 2, "#6e4e80")
    return im


def cadi():  # zehirli duman, iksir, supurge: bataklik gecesi + yesil duman bandi + hilal
    im = bands(["#2e3e4a", "#34505a", "#3e6060", "#5a8a5e", "#3a5a40"], [3, 3, 2, 2, 2])
    disc(im, 22, 6, 3.5, "#e6e2c0")
    disc(im, 23.5, 5, 3.0, "#34505a")  # hilal
    for x in range(N):  # dalgali duman ust kenari
        if x % 4 in (1, 2):
            px(im, [(x, 18)], "#78a870")
    return im


CHARS = [
    (1, "Talon", "talha", talon, "Ayna Formu kırmızı-siyahı + ayna kıymıkları"),
    (2, "Oakley", "oyku", oakley, "Çayır + küçük çiçekler (arı, sarmaşık, çiçek kiti)"),
    (3, "Matthew", "matthew", matthew, "Fırtına arduvazı + altın yıldırım"),
    (4, "Büyücü Kız", "buyucu", buyucu, "Gece mavisi + yıldızlar + meteor izi"),
    (5, "Assasin Çocuk", "assasin", assasin, "Ay ışığı + kızıl kesik"),
    (7, "Şovalye Adam", "sovalye", sovalye, "Taş kale duvarı + kırmızı sancak"),
    (8, "Elara", "elara", elara, "Nane gök + çam ormanı + rüzgâr çizgisi"),
    (9, "Korsan", "korsan", korsan, "Gök + ufuk + dalga sırtları"),
    (10, "Melek", "melek", melek, "Sakin gök mavisi + üstte bulutlar"),
    (11, "Necromancer", "necromancer", necromancer, "Mezarlık sisi + soluk ay + mezar taşları"),
    (12, "Shaman", "shaman", shaman, "Turuncu gün batımı + dağ siluetleri"),
    (13, "Vampir Çocuk", "vampir", vampir, "Gece moru + büyük ay + yarasalar"),
    (14, "Hadime", "hadime", hadime, "Lanet kitabının eski sayfası + rün halkası"),
    (15, "Cadı", "cadi", cadi, "Bataklık gecesi + zehir dumanı + hilal"),
]


def face(path):
    im = Image.open(path).convert("RGBA")
    bb = im.getchannel("A").getbbox()
    w, h = im.size
    size = min(24, w, h)
    x = max(0, min(bb[0] + (bb[2] - bb[0]) // 2 - size // 2, w - size))
    y = max(0, min(bb[1] - 1, h - size))
    return im.crop((x, y, x + size, y + size))


def main():
    tray = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_avatar_tray.png")).convert("RGBA")
    plaque = Image.open(os.path.join(ROOT, "assets/ui/kit/hud_level_tray.png")).convert("RGBA")
    font = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 32)
    font16 = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/m5x7.ttf"), 16)
    Z = 2  # sunum buyutmesi
    card_w, card_h = 200, 150
    cols = 7
    lab_h = 36
    W = cols * (card_w * Z // 2 + 16) + 16
    rows = (len(CHARS) + cols - 1) // cols
    cell_h = (card_h + lab_h) * Z // 2 + 96
    sheet = Image.new("RGBA", (W * 1, rows * cell_h + 16), C("#17110c"))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for i, (cid, name, key, fn, desc) in enumerate(CHARS):
        bg = fn()
        bg.save(os.path.join(OUT, "bg", "%d.png" % cid))
        f = face(os.path.join(ROOT, "assets/characters/%s_portrait.png" % key))
        # 1) panel portresi: tepsi kutusu (84) + ic 60 alanina arka plan 56 (28x2) + yuz 48 (24x2) + seviye levhasi
        card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
        card.alpha_composite(tray, (0, 0))
        card.alpha_composite(bg.resize((56, 56), Image.NEAREST), (14, 14))
        card.alpha_composite(f.resize((48, 48), Image.NEAREST), (18, 18))
        card.alpha_composite(plaque, (15, 65))
        cd = ImageDraw.Draw(card)
        cd.fontmode = "1"
        cd.text((15 + 27 - 10, 65 + 9), "12", font=font, fill=C("#f3e6cc"))
        # 2) grup satiri avatari: 2 px koyu cerceve + arka planin alt-orta 24x24'u (2x) + yuz (2x)
        ax, ay = 100, 14
        cd.rectangle((ax, ay, ax + 51, ay + 51), fill=C("#20150d"))
        crop = bg.crop((2, 4, 26, 28))
        card.alpha_composite(crop.resize((48, 48), Image.NEAREST), (ax + 2, ay + 2))
        card.alpha_composite(f.resize((48, 48), Image.NEAREST), (ax + 2, ay + 2))
        cd.text((ax, ay + 58), name.split(" ")[0], font=font16, fill=C("#f3e6cc"))
        big = card.resize((card_w * Z, card_h * Z), Image.NEAREST)
        cx = 16 + (i % cols) * (card_w * Z // 2 + 16)
        cy = 16 + (i // cols) * cell_h
        # kart buyuk (2x) sigmazsa 1x sunulur: once 1x yerlestir
        sheet.alpha_composite(card.resize((card_w * Z // 2, card_h * Z // 2), Image.NEAREST), (cx, cy + lab_h))
        d.text((cx, cy), name, font=font, fill=C("#f0c070"))
        d.text((cx, cy + lab_h + card_h * Z // 2 + 4), desc, font=font16, fill=C("#c4b090"))
        big.save(os.path.join(OUT, "kart_%02d.png" % cid))
    sheet.save(os.path.join(OUT, "ozet_1x.png"))
    # 2x ozet: kart yalniz dolu alani kadar (portre kutusu + levha + grup avatari), aciklama kart altinda 2 satira sarilir
    crop_box = (0, 0, 156, 106)
    cw, ch = crop_box[2] * Z, crop_box[3] * Z
    Wz = cols * (cw + 24) + 24
    cell_hz = lab_h + ch + 8 + 2 * 22 + 24
    sheet2 = Image.new("RGBA", (Wz, rows * cell_hz + 24), C("#17110c"))
    d2 = ImageDraw.Draw(sheet2)
    d2.fontmode = "1"
    for i, (cid, name, key, fn, desc) in enumerate(CHARS):
        big = Image.open(os.path.join(OUT, "kart_%02d.png" % cid)).crop((0, 0, cw, ch))
        cx = 24 + (i % cols) * (cw + 24)
        cy = 24 + (i // cols) * cell_hz
        d2.text((cx, cy), name, font=font, fill=C("#f0c070"))
        sheet2.alpha_composite(big, (cx, cy + lab_h))
        words, lines, cur = desc.split(" "), [], ""
        for w_ in words:
            t = (cur + " " + w_).strip()
            if d2.textlength(t, font=font) > cw and cur:
                lines.append(cur)
                cur = w_
            else:
                cur = t
        lines.append(cur)
        for j, ln in enumerate(lines[:2]):
            d2.text((cx, cy + lab_h + ch + 8 + j * 22), ln, font=font, fill=C("#c4b090"))
    sheet2.save(os.path.join(OUT, "ozet.png"))
    print("ok", sheet2.size)


if __name__ == "__main__":
    main()
