"""Karakter tanitim klipleri: karakter_klip_capture.gd'nin JPG karelerini MP4'e cevirir (imageio-ffmpeg'in gomulu ffmpeg'i).

    python tools/proto_20261114/karakter_klip/karakter_klip_encode.py <kare_klasoru> <cikis_klasoru> [birlesik_ad.mp4] [crf] [--avi yol.avi]
    python tools/proto_20261114/karakter_klip/karakter_klip_encode.py <kare_klasoru> --avi yol.avi --extract-only   (yalniz audio.wav kes)

<kare_klasoru>/<id>/f_0000.jpg ... -> <cikis>/<NN>_<Ad>.mp4 (her klip ayri) + <cikis>/<birlesik_ad> (hepsi arka arkaya, aralarda 0,3 sn
karartma). H.264 yuv420p (her oynaticida / telefonda acilir), 30 fps, 1920x1080.

SES (kullanici 2026-11-16: "kliplerin sesi yok"): --avi verilirse klasordeki audio.json'a (yakalama betigi yazar: p0 = ilk kaydedilen karenin
oyun karesi, frames = kare sayisi) gore Movie Maker AVI'sinden o klibin sesi kesilir: AVI karesi k = oyun karesi k + 1 -> baslangic
(p0 - 1) / 30 sn; kesilen ses klasore audio.wav olarak yazilir (iki ayri yakalamanin klipleri ayni kodlamada birlesebilsin:
once her yakalama --extract-only ile kendi AVI'sinden, sonra tek kodlama audio.wav'lari kullanir). Ses AAC 192k, 48 kHz stereo; klip basinda/sonunda kisa ses yumusatmasi; birlesik videoda karartmayla birlikte ses de soner.
"""
import json
import os
import subprocess
import sys

import imageio_ffmpeg

NAMES = {1: "Talon", 2: "Oakley", 3: "Matthew", 4: "Lyra", 5: "Kestrel", 7: "Aldric", 8: "Elara", 9: "Flint", 10: "Seraphine",
         11: "Corvina", 12: "Ulric", 13: "Nox", 14: "Hadime", 15: "Hazel"}
FPS = 30
## JPG kareler tam aralik (yuvj420p) gelir; telefon/oynatici uyumu icin sinirli aralik yuv420p.
VF = "scale=in_range=pc:out_range=tv,format=yuv420p"
## Klipler arasi ses seviyesi esit olsun (tek gecis loudnorm; tepe -1,5 dB).
AF_NORM = "loudnorm=I=-17:TP=-1.5:LRA=11"


def _dur(ff: str, p: str) -> float:
    s = subprocess.run([ff, "-i", p], capture_output=True, text=True, encoding="utf-8", errors="replace").stderr
    h, m, sec = s.split("Duration: ")[1].split(",")[0].split(":")
    return int(h) * 3600 + int(m) * 60 + float(sec)


def main() -> None:
    args = sys.argv[1:]
    avi = ""
    extract_only = "--extract-only" in args
    args = [a for a in args if a != "--extract-only"]
    if "--avi" in args:
        i = args.index("--avi")
        avi = os.path.abspath(args[i + 1])
        args = args[:i] + args[i + 2:]
    src = os.path.abspath(args[0])
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    if avi:
        for d in sorted(os.listdir(src)):
            aj = os.path.join(src, d, "audio.json")
            if not os.path.exists(aj):
                continue
            meta = json.load(open(aj, encoding="utf-8"))
            t0 = (int(meta["p0"]) - 1) / FPS
            subprocess.run([ff, "-y", "-loglevel", "error", "-ss", "%.4f" % t0, "-t", "%.4f" % (int(meta["frames"]) / FPS), "-i", avi, "-vn",
                            "-ac", "2", "-ar", "48000", "-c:a", "pcm_s16le", os.path.join(src, d, "audio.wav")], check=True)
            print("WAV", d)
    if extract_only:
        return
    out = os.path.abspath(args[1])  ## concat listesi yollari listeye gore cozer -> mutlak
    combined = args[2] if len(args) > 2 else "00_tum_karakterler.mp4"
    crf = args[3] if len(args) > 3 else "14"  ## hareketli kamera (silah kaçış klipleri) crf 14 ile ~10 Mbit/sn -> 20-21 yeterli
    os.makedirs(out, exist_ok=True)
    parts = []
    has_audio = False
    ## Karakter modu: klasor = karakter id'si (sayi); silah modu: klasor = "NN_Silah_Karakter" (adi dosya adi olur).
    dirs = [d for d in os.listdir(src) if os.path.isdir(os.path.join(src, d)) and os.path.exists(os.path.join(src, d, "f_0000.jpg"))]
    dirs.sort(key=lambda d: (0, int(d)) if d.isdigit() else (1, d))
    for n, d in enumerate(dirs, 1):
        frames = os.path.join(src, d, "f_%04d.jpg")
        stem = "%02d_%s" % (n, NAMES.get(int(d), d)) if d.isdigit() else d
        dst = os.path.join(out, stem + ".mp4")
        wav = os.path.join(src, d, "audio.wav")
        cmd = [ff, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", frames]
        if os.path.exists(wav):
            dur = len([f for f in os.listdir(os.path.join(src, d)) if f.endswith(".jpg")]) / FPS
            cmd += ["-i", wav, "-map", "0:v", "-map", "1:a",
                    "-af", "%s,afade=t=in:d=0.06,afade=t=out:st=%.3f:d=0.12,aresample=48000" % (AF_NORM, max(0.0, dur - 0.12)),
                    "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-shortest"]
            has_audio = True
        cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", crf, "-vf", VF, "-pix_fmt", "yuv420p", "-color_range", "tv",
                "-movflags", "+faststart", dst]
        subprocess.run(cmd, check=True)
        parts.append(dst)
        print("MP4", dst)
    ## Hepsi bir arada: her klibe 0,3 sn karartma girisi/cikisi (sesle birlikte), sonra birlestir.
    tmp = []
    for p in parts:
        t = p.replace(".mp4", "_fade.mp4")
        dur = _dur(ff, p)
        cmd = [ff, "-y", "-loglevel", "error", "-i", p, "-vf",
               "fade=t=in:st=0:d=0.3,fade=t=out:st=%.2f:d=0.3,format=yuv420p" % (dur - 0.3)]
        if has_audio:
            cmd += ["-af", "afade=t=in:d=0.3,afade=t=out:st=%.2f:d=0.3" % (dur - 0.3), "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2"]
        cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", crf, "-pix_fmt", "yuv420p", "-color_range", "tv", t]
        subprocess.run(cmd, check=True)
        tmp.append(t)
    lst = os.path.join(out, "_list.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for t in tmp:
            f.write("file '%s'\n" % t.replace("\\", "/"))
    allp = os.path.join(out, combined)
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", allp],
                   check=True)
    for t in tmp:
        os.remove(t)
    os.remove(lst)
    print("MP4", allp)


if __name__ == "__main__":
    main()
