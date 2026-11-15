# MAKİNELİ sesleri (madde 652, 2026-11-13; kullanıcı: "bu ses efektini kullan bu silah için ihtiyacın olan herşey var").
# Kaynak: masaüstündeki "ses efekti.mp3" (6,77 sn, 48 kHz mono) - zarf analizi:
#   0,00-0,45 şarjör çıkar (tepe 0,119) | 0,95-1,45 şarjör tak (tepe 1,191) | 1,65-2,35 kurma kolu geri (tepe 2,041)
#   2,55-3,10 kurma kolu ileri (tepe 2,694) | 3,608 tek atış (tepe 3,641) | 4,4-4,8 kısa seri | 5,35-6,2 uzun seri (alınmaz:
#   oyunda her mermi kendi tek atışını çalar, seri hızı silahın kendi hızlanmasından gelir).
# Kaynağın kopyası tools/makineli_kaynak/ses_efekti.mp3 (.gdignore)'te durur (masaüstü dosyası silinse de yeniden üretilebilsin).
#
# Çıktı: assets/audio/makineli_atis.wav (tek atış, kuyruğu kısaltılmış - saniyede 12+ atışta üst üste binmesin) +
#        assets/audio/gun/reload/makineli_{out,in,back,fwd}.wav (anahtar anlar gun_reload_math.gd sounds()).
# Kesim gen_gun_reload_fx.py ile aynı: DC kaldır, 4 ms giriş / 25 ms çıkış sönümü, tepe -1 dBFS (sınırlayıcı yok; seviye oyunda).
#
# Kullanım (proje kökünden): python -I tools/gen_makineli_ses.py
import os, shutil, subprocess, wave
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DESK_SRC = os.path.join(os.path.expanduser("~"), "Desktop", "ses efekti.mp3")
KEEP = os.path.join(ROOT, "tools", "makineli_kaynak", "ses_efekti.mp3") # .gdignore: Godot içe aktarmaz / exe’ye girmez
SR = 44100

# ad -> (çıkış yolu, başlangıç sn, bitiş sn, çıkış sönümü sn)
CLIPS = {
    "atis": (os.path.join(ROOT, "assets", "audio", "makineli_atis.wav"), 3.600, 3.920, 0.12),
    "out": (os.path.join(ROOT, "assets", "audio", "gun", "reload", "makineli_out.wav"), 0.00, 0.45, 0.025),
    "in": (os.path.join(ROOT, "assets", "audio", "gun", "reload", "makineli_in.wav"), 0.95, 1.45, 0.025),
    "back": (os.path.join(ROOT, "assets", "audio", "gun", "reload", "makineli_back.wav"), 1.65, 2.35, 0.025),
    "fwd": (os.path.join(ROOT, "assets", "audio", "gun", "reload", "makineli_fwd.wav"), 2.55, 3.10, 0.025),
}


def main():
    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(os.path.dirname(KEEP), exist_ok=True)
    if os.path.exists(DESK_SRC):
        shutil.copyfile(DESK_SRC, KEEP)
    src = KEEP
    for name, (out, a, b, fade) in CLIPS.items():
        raw = subprocess.run([ff, "-loglevel", "error", "-ss", "%.3f" % a, "-t", "%.3f" % (b - a), "-i", src, "-ac", "1", "-ar", str(SR),
                              "-f", "s16le", "-"], check=True, capture_output=True).stdout
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
        x = x - x.mean()
        fi, fo = int(0.004 * SR), int(fade * SR)
        x[:fi] *= np.linspace(0.0, 1.0, fi)
        x[-fo:] *= np.linspace(1.0, 0.0, fo)
        x *= (10 ** (-1.0 / 20.0)) / max(1e-6, np.abs(x).max())
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with wave.open(out, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767.0).astype(np.int16).tobytes())
        print("%-5s %.3f sn -> %s" % (name, len(x) / SR, os.path.relpath(out, ROOT)))


if __name__ == "__main__":
    main()
