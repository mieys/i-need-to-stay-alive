# DERİN ORMAN son görünüm sayfaları (madde 360): final_capture.gd yakalamalarından
#   out/final/genel_harita.png   - tüm oyun alanı (4096 dünya px -> 1536 px, kutu filtresi) + bölge adları
#   out/final/bolge_<ad>.png     - bölge başına iki yakın çekim (oyun görüşü, 1 px = 1 dünya px) alt alta, başlıklı
#   out/final/*_1080p.png        - yakın çekimler 2x (1080p oyun görünüşü)
# Kullanım: python tools/derin_orman/final_sheet.py
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, 'out', 'final')
FONT_B = 'C:/Windows/Fonts/arialbd.ttf'
FONT = 'C:/Windows/Fonts/arial.ttf'
ZONES = [
    ('kuzey', 'KUZEY - Kadim Kara Orman', 'gri kül zemin, ölü ağaçlar, taçlı dev, zindan: Kemik Mahzeni', (150, 22), ['kuzey_mahzen', 'kuzey_dev']),
    ## madde 385: Batı/Doğu kaldırıldı, Kuzey kuzeybatıya uzadı; zindan girişleri yerinde
    ('kuzeybati', 'KUZEYBATI - Kadim Kara Orman', 'kuzeyle aynı derinlik, zindan: Et Kuyusu', (36, 22), ['kuzeybati_kuyu', 'kuzeybati_orman']),
    ('eski', 'ESKİ HARİTA (Batı/Doğu kaldırıldı)', 'zindan girişi yerinde: Boynuzlu Kapı', (214, 110), ['eski_bati', 'boynuzlu_kapi']),
    ('guney', 'GÜNEY - Sisli Sazlık', 'yosunlu bataklık, yaşayan yaşlı ağaç, kulübe, ateş böcekleri', (145, 205), ['guney_agac', 'guney_kulube']),
    ## madde 387: Güney batısındaki çayıra uzadı; toprak yol/açıklık + maden toprağı olduğu gibi
    ('guneybati', 'GÜNEYBATI - Sisli Sazlık', 'batı çayırı; toprak yol ve açıklık olduğu gibi', (62, 215), ['guneybati_cayir', 'guneybati_yol']),
]
SHOT_TITLES = {
    'kuzey_mahzen': 'Zindan girişi: Kemik Mahzeni', 'kuzey_dev': 'Kemik taht açıklığı ve taçlı dev',
    'kuzeybati_kuyu': 'Zindan girişi: Et Kuyusu (Kadim Kara Orman içinde)', 'kuzeybati_orman': 'Kuzeybatı ormanı',
    'eski_bati': 'Eski Batı - eski harita', 'boynuzlu_kapi': 'Zindan girişi: Boynuzlu Kapı (eski harita üstünde)',
    'guney_agac': 'Yaşayan yüzlü ağaç', 'guney_kulube': 'Bataklık kulübesi',
    'guneybati_cayir': 'Batı çayırı (yeni sazlık)', 'guneybati_yol': 'Çayırın toprak yolu ve açıklığı (toprak kaldı)',
}


def overview():
    big = Image.new('RGB', (4096, 4096), (20, 30, 20))
    for line in open(os.path.join(D, 'genel_meta.txt')).read().split('\n'):
        i, j, wx, wy, ox, oy, s100 = line.split(',')
        im = Image.open(os.path.join(D, 'genel_%s_%s.png' % (i, j))).convert('RGB')
        s = float(s100) / 100.0
        assert abs(s - 1.0) < 0.01, s
        w, h = im.width - int(round(float(ox))), im.height - int(round(float(oy)))
        crop = im.crop((int(round(float(ox))), int(round(float(oy))), int(round(float(ox))) + w, int(round(float(oy))) + h))
        big.paste(crop, (int(round(float(wx))), int(round(float(wy)))))
    small = big.resize((1536, 1536), Image.BOX)
    d = ImageDraw.Draw(small, 'RGBA')
    fb = ImageFont.truetype(FONT_B, 26)
    fs = ImageFont.truetype(FONT, 17)
    k = 1536 / 256.0
    for _key, title, sub, (cx, cy), _shots in ZONES:
        x, y = cx * k, cy * k
        tw = max(d.textlength(title, font=fb), d.textlength(sub, font=fs))
        d.rounded_rectangle([x - tw / 2 - 12, y - 8, x + tw / 2 + 12, y + 56], 8, fill=(15, 12, 10, 170))
        d.text((x - d.textlength(title, font=fb) / 2, y - 4), title, font=fb, fill=(255, 238, 200))
        d.text((x - d.textlength(sub, font=fs) / 2, y + 28), sub, font=fs, fill=(225, 215, 190))
    d.text((12, 1536 - 30), 'Bütün oyun alanı, oyunun kendi çizicisi (gündüz). Orta bölge, sol alt madenler ve sağ alt düşman üssü değişmedi.',
           font=fs, fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
    small.save(os.path.join(D, 'genel_harita.png'))
    big.save(os.path.join(D, 'genel_harita_tam.png'))
    print('genel', small.size)


def world_sample(name):
    ox, oy, s = [float(v) for v in open(os.path.join(D, 'yakin_%s.txt' % name)).read().split(',')]
    im = np.asarray(Image.open(os.path.join(D, 'yakin_%s.png' % name)).convert('RGB'))
    h, w = im.shape[:2]
    p = s / 16.0
    k0x, k0y = int(np.ceil(-ox / p)), int(np.ceil(-oy / p))
    nx, ny = int((w - (ox + k0x * p)) // p), int((h - (oy + k0y * p)) // p)
    xs = (ox + (k0x + np.arange(nx) + 0.5) * p).astype(int)
    ys = (oy + (k0y + np.arange(ny) + 0.5) * p).astype(int)
    return Image.fromarray(im[ys][:, xs])


def zone_sheets():
    fb = ImageFont.truetype(FONT_B, 20)
    fs = ImageFont.truetype(FONT, 15)
    for key, title, sub, _c, shots in ZONES:
        panels = []
        for sh in shots:
            im = world_sample(sh)
            im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(D, '%s_1080p.png' % sh))
            d = ImageDraw.Draw(im)
            d.text((10, 8), SHOT_TITLES[sh], font=fs, fill=(255, 245, 215), stroke_width=3, stroke_fill=(15, 12, 10))
            panels.append(im)
        W = panels[0].width
        head = 40
        out = Image.new('RGB', (W, head + sum(p.height for p in panels) + 6 * (len(panels) - 1)), (18, 14, 12))
        d = ImageDraw.Draw(out)
        d.text((10, 8), title, font=fb, fill=(255, 238, 200))
        d.text((20 + d.textlength(title, font=fb), 12), '- ' + sub, font=fs, fill=(200, 190, 170))
        y = head
        for p in panels:
            out.paste(p, (0, y))
            y += p.height + 6
        out.save(os.path.join(D, 'bolge_%s.png' % key))
        print('bölge', key, out.size)


def gifs():
    """madde 361: kapı / yaşlı ağaç GIF'leri - yakın çekim karelerinin ortası (oyun görüşü, 1 px = 1 dünya px, 2x büyütülmüş)."""
    ## (yakın çekim, odak hücresi) - final_capture.gd SHOTS merkezine göre kaydırılır
    targets = {'kuzey_mahzen': ((203, 19), (207, 16)), 'boynuzlu_kapi': ((235, 54), (241, 52)), 'guney_agac': ((106, 230), (106, 232))}
    for name, (center, focus) in targets.items():
        frames = sorted(f for f in os.listdir(D) if f.startswith('gif_%s_' % name))
        if not frames:
            continue
        ox, oy, s = [float(v) for v in open(os.path.join(D, 'yakin_%s.txt' % name)).read().split(',')]
        ims = []
        for f in frames:
            im = Image.open(os.path.join(D, f)).convert('RGB')
            w, h = im.size
            ## dünya pikseline örnekle (world_sample ile aynı), orta 360x220 dünya px
            p = s / 16.0
            k0x, k0y = int(np.ceil(-ox / p)), int(np.ceil(-oy / p))
            nx, ny = int((w - (ox + k0x * p)) // p), int((h - (oy + k0y * p)) // p)
            xs = (ox + (k0x + np.arange(nx) + 0.5) * p).astype(int)
            ys = (oy + (k0y + np.arange(ny) + 0.5) * p).astype(int)
            a = Image.fromarray(np.asarray(im)[ys][:, xs])
            cx, cy = a.width // 2 + (focus[0] - center[0]) * 16, a.height // 2 + (focus[1] - center[1]) * 16
            a = a.crop((cx - 180, cy - 130, cx + 180, cy + 90)).resize((720, 440), Image.NEAREST)
            ims.append(a)
        ims[0].save(os.path.join(D, 'anim_%s.gif' % name), save_all=True, append_images=ims[1:], duration=100, loop=0)
        print('gif', name, len(ims))


if __name__ == '__main__':
    overview()
    zone_sheets()
    gifs()
