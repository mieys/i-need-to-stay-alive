"""Masaüstündeki yağmur/akarsu mp3'lerini DİKİŞSİZ döngü OGG'sine çevirir (2026-10-11, kullanıcı isteği: "loop smooth olsun,
başlangıç/son keskin bitmesin ya da sessizleşip sıfırdan başlamasın").

Yöntem: son X saniye, ilk X saniyeye EŞİT GÜÇLÜ (sqrt) çapraz geçişle karıştırılır, sonra o kuyruk atılır:
    out[i] = head[i]*sin(t) + tail[i]*cos(t),  t = 0..pi/2   (i < X)
Böylece döngü sonu -> döngü başı geçişi ses içinde zaten yumuşak (gürültü benzeri sesler için eşit güç = seviye çukuru yok).
Ayrıca uçlar 0 genlikte DEĞİL - sessizleşme yok. Çıktı: sabit tepe seviyesine normalize (-3 dBFS) değil, KAYNAK RMS'i korunur
(seviye oyunda dB ile ayarlanır); sadece kırpılma olursa ölçeklenir.

Kullanım: python tools/make_seamless_ambience.py   (imageio-ffmpeg: pip install imageio-ffmpeg)
"""
import subprocess, sys, os, struct
import numpy as np
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
DESK = os.path.join(os.path.expanduser("~"), "Desktop")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
JOBS = [
    # (kaynak, çıktı, çapraz geçiş sn, kenar kırpma sn (mp3 başındaki/sonundaki dolgu), örnekleme hızı)
    ("yağmur ambiyans.mp3", "rain_ambience_loop.ogg", 4.0, 0.15, 44100),
    ("akarsu hışırtı.mp3", "stream_loop.ogg", 2.5, 0.10, 44100, -26.0), # kaynak çok kısık (-44 dBFS): -26 RMS'e yükseltilir
]


def decode(path, rate):
    p = subprocess.run([FF, "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(rate), "-"], capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).reshape(-1, 2).copy()


def seamless(x, rate, xfade_s, trim_s):
    t = int(trim_s * rate)
    x = x[t:len(x) - t]
    X = int(xfade_s * rate)
    assert len(x) > 3 * X, "kaynak çapraz geçişe göre çok kısa"
    L = len(x) - X
    ph = np.linspace(0.0, np.pi / 2, X, dtype=np.float32)[:, None]
    head = x[:X]
    tail = x[L:]
    out = x[:L].copy()
    out[:X] = head * np.sin(ph) + tail * np.cos(ph)
    return out


def loop_error(out):
    """Döngü dikişi: son örnek ile ilk örnek arasındaki sıçrama, tipik komşu örnek farkına oranla (1'e yakın = pürüzsüz)."""
    seam = np.abs(out[0] - out[-1]).max()
    typical = np.abs(np.diff(out, axis=0)).mean() + 1e-9
    return float(seam / typical)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def main():
    for src, dst, xf, trim, rate, *target in JOBS:
        x = decode(os.path.join(DESK, src), rate)
        out = seamless(x, rate, xf, trim)
        if target:
            out *= 10 ** ((target[0] - rms_db(out)) / 20)
        peak = float(np.abs(out).max())
        if peak > 0.98:
            out *= 0.98 / peak
        wav = os.path.join(os.environ.get("TEMP", "."), dst + ".wav")
        pcm = (np.clip(out, -1, 1) * 32767).astype("<i2")
        with open(wav, "wb") as f:
            n = pcm.size * 2
            f.write(b"RIFF" + struct.pack("<I", 36 + n) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 2, rate, rate * 4, 4, 16) + b"data" + struct.pack("<I", n))
            f.write(pcm.tobytes())
        dst_path = os.path.normpath(os.path.join(OUT, dst))
        subprocess.run([FF, "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", dst_path], check=True)
        os.remove(wav)
        print(f"{dst}: {len(out)/rate:.2f} sn  RMS {rms_db(out):.1f} dBFS  tepe {20*np.log10(float(np.abs(out).max())):.1f} dBFS  "
              f"dikis/tipik fark orani {loop_error(out):.2f}  boyut {os.path.getsize(dst_path)//1024} KB")


if __name__ == "__main__":
    main()
