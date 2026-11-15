# Tabanca / Tüfek / Pompalı ŞARJÖR DOLDURMA parçaları + sesleri (2026-11-13, madde 645, kullanıcı: "şarjör doldururken mermi veya şarjör
# çıkarılıp eklenmiyor ... masaüstündeki ses efektleriyle"). Prototip: tools/proto_20261113/sarjor/index.html.
#
# Dokular (silahın KENDİ piksel ızgarasında; assets/fx/gun/reload/):
#   tabanca_mag.png (kabza eğiminde şarjör), tabanca_toggle.png (Luger kolu, gövdeden kesit), tabanca_toggle_open.png (kol kalkıkken gövde)
#   tufek_mag.png (kutu şarjör), tufek_nomag.png (şarjörsüz gövde), tufek_round.png (sürgü açıkken görünen pirinç mermi),
#   tufek_bolt_open.png (sürgü açık gövde), pompali_shell.png (kırmızı fişek), pompali_fore.png (kundak), pompali_nofore.png
#   makineli_mag.png (uzun düz şarjör, kullanıcının çiziminden kesit), makineli_nomag.png (şarjörsüz gövde) - madde 652
#   mags_drop.png: düşen boş şarjörün 8 dönüş karesi (satır 0 tabanca, 1 tüfek, 2 makineli; 24x24 hücre - makineli şarjörü 21 px
#   boyunda, 45 derecede ~19 px; shell_casing_fx.gd hücreyi doku boyutu / kare sayısından okur)
# Sesler (masaüstündeki 3 dosyadan kesilir, assets/audio/gun/reload/*.wav): her parçanın "anahtar anı" gun_reload_math.gd CLIPS'te.
#
# Kullanım (proje kökünden): python tools/gen_gun_reload_fx.py [--no-sound]
import os, subprocess, sys, wave
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DESK = os.path.join(os.path.expanduser("~"), "Desktop")
OUT_TEX = os.path.join(ROOT, "assets", "fx", "gun", "reload")
OUT_SND = os.path.join(ROOT, "assets", "audio", "gun", "reload")

PAL = {"a": "000000", "b": "262626", "c": "191919", "d": "575757", "e": "3a3a3a", "Y": "f8b844", "y": "9a7432", "z": "574018",
       "W": "7c4f3d", "w": "573326", "S": "1f1f1f", "T": "2e2e2e", "R": "a8282a", "r": "7a1a1e", "H": "f07660", "o": "360e10",
       "F": "0a0a0a", "D": "151515"}


def rgba(hexs):
    return tuple(int(hexs[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def grid(rows, shift=None):
    sh = shift or (lambda r: 0)
    mins = min(sh(i) for i in range(len(rows)))
    w = max(len(r) + sh(i) - mins for i, r in enumerate(rows))
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in PAL:
                im.putpixel((x + sh(y) - mins, y), rgba(PAL[ch]))
    return im


def variant(src, edits):
    im = src.copy()
    for x0, x1, y, col in edits:
        for x in range(x0, x1 + 1):
            im.putpixel((x, y), rgba(PAL[col]) if col else (0, 0, 0, 0))
    return im


TAB_MAG = [".aa.", "aYya", "adea", "adea", "adea", "adea", "adea", "aWwa", ".aa."]
TUF_MAG = [".aYya.", "aSSSSa", "aSTSSa", "aSSSSa", "aSSSaa", "aaaa.."]


def build_textures():
    os.makedirs(OUT_TEX, exist_ok=True)
    tab = Image.open(os.path.join(ROOT, "assets/weapons/yeni/tabanca.png")).convert("RGBA")
    tuf = Image.open(os.path.join(ROOT, "assets/weapons/yeni/tufek.png")).convert("RGBA")
    pom = Image.open(os.path.join(ROOT, "assets/weapons/pompali/icon.png")).convert("RGBA")
    mak = Image.open(os.path.join(ROOT, "assets/weapons/makineli/icon.png")).convert("RGBA")
    assert tab.size == (32, 32) and tuf.size == (64, 32) and pom.size == (64, 64) and mak.size == (64, 64), "silah çizimi değişmiş: koordinatları yeniden ölç"
    # Tabanca: kabza 2 satırda 1 px sola eğik -> şarjör aynı eğimde (gun_reload_math.gd TAB_MAG_AT)
    grid(TAB_MAG, lambda r: -(r // 2)).save(os.path.join(OUT_TEX, "tabanca_mag.png"))
    tab.crop((4, 8, 16, 11)).save(os.path.join(OUT_TEX, "tabanca_toggle.png"))
    variant(tab, [(6, 14, 9, "c"), (6, 14, 10, "c")]).save(os.path.join(OUT_TEX, "tabanca_toggle_open.png"))
    # Tüfek: alttaki kutu şarjör x30-35 y19-21 (üst satırları dipçik arkasında)
    grid(TUF_MAG).save(os.path.join(OUT_TEX, "tufek_mag.png"))
    variant(tuf, [(30, 35, 19, None), (30, 35, 20, None), (30, 35, 21, None)]).save(os.path.join(OUT_TEX, "tufek_nomag.png"))
    grid(["zYYYy", "zyyyz"]).save(os.path.join(OUT_TEX, "tufek_round.png"))
    variant(tuf, [(20, 23, 13, "c"), (21, 22, 14, "c")]).save(os.path.join(OUT_TEX, "tufek_bolt_open.png"))
    # Pompalı: kundak x41-48 y28-31, boru altında; fişek alttaki yuvadan (x30-35) girer
    grid(["zoooo.", "YHRRRo", "yrRRro", "zoooo."]).save(os.path.join(OUT_TEX, "pompali_shell.png"))
    pom.crop((41, 28, 49, 32)).save(os.path.join(OUT_TEX, "pompali_fore.png"))
    variant(pom, [(41, 48, 28, "F"), (41, 48, 29, "D"), (41, 48, 30, "a"), (41, 48, 31, None)]).save(os.path.join(OUT_TEX, "pompali_nofore.png"))
    # Makineli (madde 652): uzun düz şarjör x36-40 y27-47 (gun_reload_math.gd MAK_MAG_AT); y27 = şarjör yuvasının alt satırı (gövdede
    # kalır, şarjörsüz gövdede siyah çerçeveyle kapanır), şarjörün kendisi y28-47.
    mag_mak = mak.crop((36, 28, 41, 48))
    mag_mak.save(os.path.join(OUT_TEX, "makineli_mag.png"))
    nomag = mak.copy()
    for y in range(28, 48):
        for x in range(36, 41):
            nomag.putpixel((x, y), (0, 0, 0, 0))
    for x in range(36, 41):
        nomag.putpixel((x, 27), rgba(PAL["a"]))
    nomag.save(os.path.join(OUT_TEX, "makineli_nomag.png"))
    # Düşen şarjör: düz (eğimsiz) hâli 8 yönde, 24x24 hücre (makineli şarjörü sığsın); kare 0 = dik, k = k*45 derece saat yönünde
    cell = 24
    sheet = Image.new("RGBA", (cell * 8, cell * 3), (0, 0, 0, 0))
    for row, rows in enumerate([TAB_MAG, TUF_MAG, None]):
        base = grid(rows) if rows is not None else mag_mak
        for f in range(8):
            rot = base.rotate(-45 * f, resample=Image.NEAREST, expand=True)
            bb = rot.getbbox()
            rot = rot.crop(bb)
            ox = (cell - rot.width) // 2
            oy = (cell - rot.height) // 2
            sheet.alpha_composite(rot, (f * cell + max(0, ox), row * cell + max(0, oy)))
    sheet.save(os.path.join(OUT_TEX, "mags_drop.png"))
    print("dokular ->", OUT_TEX)


# kaynak dosya, [başlangıç, bitiş] sn (zarf analizi: tools/proto_20261113/sarjor; tüfek dosyasının 2,9 sn sonrası ATEŞ sesi - alınmaz)
CLIPS = {
    "tabanca_out": ("tabanca şarjör sesi.mp3", 0.37, 1.03),
    "tabanca_in": ("tabanca şarjör sesi.mp3", 1.37, 1.96),
    "tabanca_rack": ("tabanca şarjör sesi.mp3", 2.55, 3.20),
    "tufek_out": ("tüfek şarjör sesi.mp3", 0.04, 0.57),
    "tufek_in": ("tüfek şarjör sesi.mp3", 1.15, 1.60),
    "tufek_bolt": ("tüfek şarjör sesi.mp3", 1.96, 2.42),
    "pompali_shell": ("pompalı tüfek şarjör sesi.mp3", 1.665, 2.04),
    "pompali_pump": ("pompalı tüfek şarjör sesi.mp3", 3.33, 3.74),
}
SR = 44100


def build_sounds():
    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(OUT_SND, exist_ok=True)
    for name, (src, a, b) in CLIPS.items():
        path = os.path.join(DESK, src)
        raw = subprocess.run([ff, "-loglevel", "error", "-ss", "%.3f" % a, "-t", "%.3f" % (b - a), "-i", path, "-ac", "1", "-ar", str(SR),
                              "-f", "s16le", "-"], check=True, capture_output=True).stdout
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
        x = x - x.mean()
        fi, fo = int(0.004 * SR), int(0.025 * SR)
        x[:fi] *= np.linspace(0.0, 1.0, fi)
        x[-fo:] *= np.linspace(1.0, 0.0, fo)
        x *= (10 ** (-1.0 / 20.0)) / max(1e-6, np.abs(x).max()) # tepe -1 dBFS (seviye gun_reload_fx.gd SND_DB)
        with wave.open(os.path.join(OUT_SND, name + ".wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767.0).astype(np.int16).tobytes())
        print("%-14s %.3f sn" % (name, len(x) / SR))


if __name__ == "__main__":
    build_textures()
    if "--no-sound" not in sys.argv:
        build_sounds()
