# Şarjör doldurma prototipi (2026-11-13): index.html sayfası, bu betik oyun dokularını + masaüstündeki 3 sesi assets.js içine gömer
# Kullanım: python tools/proto_20261113/sarjor/build.py   (proje kökünden)
import base64, json, os, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HERE = os.path.dirname(os.path.abspath(__file__))
DESK = os.path.join(os.path.expanduser("~"), "Desktop")


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def to_mp3(src):
    out = os.path.join(tempfile.mkdtemp(), "x.mp3")
    subprocess.run([ffmpeg(), "-y", "-loglevel", "error", "-i", src, "-b:a", "128k", out], check=True)
    return out


img = {
    "tabanca": os.path.join(ROOT, "assets/weapons/yeni/tabanca.png"),
    "tufek": os.path.join(ROOT, "assets/weapons/yeni/tufek.png"),
    "pompali": os.path.join(ROOT, "assets/weapons/pompali/icon.png"),
    "char": os.path.join(ROOT, "assets/characters/elara/sheets/idle.png"),
}
snd = {
    "s_tabanca": os.path.join(DESK, "tabanca şarjör sesi.mp3"),
    "s_tufek": os.path.join(DESK, "tüfek şarjör sesi.mp3"),
    "s_pompali": os.path.join(DESK, "pompalı tüfek şarjör sesi.mp3"),
    "f_tabanca": os.path.join(ROOT, "assets/audio/tabanca_fire_v2.mp3"),
    "f_tufek": os.path.join(ROOT, "assets/audio/tufek_fire.mp3"),
    "f_pompali": to_mp3(os.path.join(ROOT, "assets/audio/pompali_atis.wav")),
    "f_pompa": to_mp3(os.path.join(ROOT, "assets/audio/pompali_pompa.wav")),
}
assets = {"img": {k: b64(v) for k, v in img.items()}, "snd": {k: b64(v) for k, v in snd.items()}}
js = "window.SARJOR_ASSETS = " + json.dumps(assets) + ";\n"
out = os.path.join(HERE, "assets.js")
with open(out, "w", encoding="utf-8") as f:
    f.write(js)
print(out, len(js) // 1024, "KB")
