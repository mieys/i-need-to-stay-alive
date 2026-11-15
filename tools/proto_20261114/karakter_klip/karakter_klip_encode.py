"""Karakter tanitim klipleri: karakter_klip_capture.gd'nin JPG karelerini MP4'e cevirir (imageio-ffmpeg'in gomulu ffmpeg'i).

    python tools/proto_20261114/karakter_klip/karakter_klip_encode.py <kare_klasoru> <cikis_klasoru> [birlesik_ad.mp4]

<kare_klasoru>/<id>/f_0000.jpg ... -> <cikis>/<NN>_<Ad>.mp4 (her karakter ayri) + <cikis>/00_tum_karakterler.mp4 (hepsi arka arkaya,
aralarda 0,3 sn karartma). H.264 yuv420p (her oynaticida / telefonda acilir), 30 fps, 1920x1080.
"""
import os
import subprocess
import sys

import imageio_ffmpeg

NAMES = {1: "Talon", 2: "Oakley", 3: "Matthew", 4: "Lyra", 5: "Kestrel", 7: "Aldric", 8: "Elara", 9: "Flint", 10: "Seraphine",
         11: "Corvina", 12: "Ulric", 13: "Nox", 14: "Hadime", 15: "Hazel"}
FPS = 30
## JPG kareler tam aralik (yuvj420p) gelir; telefon/oynatici uyumu icin sinirli aralik yuv420p.
VF = "scale=in_range=pc:out_range=tv,format=yuv420p"


def main() -> None:
    src, out = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])  ## concat listesi yollari listeye gore cozer -> mutlak
    combined = sys.argv[3] if len(sys.argv) > 3 else "00_tum_karakterler.mp4"
    os.makedirs(out, exist_ok=True)
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    parts = []
    ## Karakter modu: klasor = karakter id'si (sayi); silah modu: klasor = "NN_Silah_Karakter" (adi dosya adi olur).
    dirs = [d for d in os.listdir(src) if os.path.isdir(os.path.join(src, d)) and os.path.exists(os.path.join(src, d, "f_0000.jpg"))]
    dirs.sort(key=lambda d: (0, int(d)) if d.isdigit() else (1, d))
    for n, d in enumerate(dirs, 1):
        frames = os.path.join(src, d, "f_%04d.jpg")
        stem = "%02d_%s" % (n, NAMES.get(int(d), d)) if d.isdigit() else d
        dst = os.path.join(out, stem + ".mp4")
        subprocess.run([ff, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", frames, "-c:v", "libx264", "-preset", "slow",
                        "-crf", "14", "-vf", VF, "-pix_fmt", "yuv420p", "-color_range", "tv", "-movflags", "+faststart", dst], check=True)
        parts.append(dst)
        print("MP4", dst)
    ## Hepsi bir arada: her klibe 0,3 sn karartma girisi/cikisi, sonra birlestir.
    tmp = []
    for p in parts:
        t = p.replace(".mp4", "_fade.mp4")
        dur = float(subprocess.run([ff, "-i", p], capture_output=True, text=True).stderr.split("Duration: ")[1].split(",")[0].split(":")[2])
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", p, "-vf", "fade=t=in:st=0:d=0.3,fade=t=out:st=%.2f:d=0.3,format=yuv420p" % (dur - 0.3),
                        "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-pix_fmt", "yuv420p", "-color_range", "tv", t], check=True)
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
