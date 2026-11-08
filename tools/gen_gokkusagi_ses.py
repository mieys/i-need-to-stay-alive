"""Gökkuşağı Asası ışın sesi (madde 451): masaüstündeki tek parça "gökkuşağı asası.mp3" -> iki OGG.
  beam_start_loop.ogg = giriş (0 - LOOP_A) + dikişsiz döngü gövdesi; Godot'ta loop=true, loop_offset=LOOP_A (fx_rainbow_beam.gd).
  beam_end.ogg        = kapanış patlaması (OUT_A -> son), ışın bittiği anda çalınır.
Kullanım: python -I tools/gen_gokkusagi_ses.py [kaynak.mp3]"""
import sys
import numpy as np
import miniaudio
import soundfile as sf

SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/perva/Desktop/gökkuşağı asası.mp3"
OUT = "assets/audio/gokkusagi/"
LOOP_A, LOOP_B, XF = 1.00, 1.92, 0.12  # döngü gövdesi [A, B), kaynak sürekli kısım 0,95 - 1,95
OUT_A, FADE_IN = 2.30, 0.025            # kapanış: patlamadan hemen önce başlar

d = miniaudio.decode(open(SRC, "rb").read(), output_format=miniaudio.SampleFormat.FLOAT32)
sr = d.sample_rate
a = np.array(d.samples, dtype=np.float32).reshape(-1, d.nchannels)
S = lambda t: int(round(t * sr))

ia, ib, x = S(LOOP_A), S(LOOP_B), S(XF)
body = a[ia:ib].copy()
n = len(body)
w = np.linspace(0.0, 1.0, x, dtype=np.float32)[:, None]
# döngü sonu: bitişe doğru, gövdenin doğal öncülü olan (A'dan önceki) malzemeye eriyip başa dikişsiz bağlanır
body[n - x:] = (1.0 - w) * a[ib - x:ib] + w * a[ia - x:ia]
start_loop = np.concatenate([a[:ia], body])
sf.write(OUT + "beam_start_loop.ogg", start_loop, sr, format="OGG", subtype="VORBIS")

end = a[S(OUT_A):].copy()
fi = S(FADE_IN)
end[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)[:, None]
sf.write(OUT + "beam_end.ogg", end, sr, format="OGG", subtype="VORBIS")
print("start_loop %.3f s (loop_offset %.2f), end %.3f s" % (len(start_loop) / sr, LOOP_A, len(end) / sr))
