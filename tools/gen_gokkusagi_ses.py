"""Gökkuşağı Asası ışın sesi (madde 451): masaüstündeki tek parça "Laser beam Heat Vision Sound effect - PIXEL PRESS LAB.mp3" -> iki OGG.
  beam_start_loop.ogg = giriş (START_A - LOOP_A) + dikişsiz döngü gövdesi; Godot'ta loop=true, loop_offset=LOOP_A-START_A (fx_rainbow_beam.gd SFX_LOOP_START).
  beam_end.ogg        = kapanış (END_A -> END_B: yükselme + patlama), ışın bittiği anda çalınır.
Kaynak zamanları (sn): 0-1,03 sessizlik | 1,04-2,2 giriş vuruşu | 2,2-6,0 düz gövde | 6,0-7,1 yükselme + kapanış patlaması.
Kullanım: python -I tools/gen_gokkusagi_ses.py [kaynak.mp3]"""
import sys
import numpy as np
import miniaudio
import soundfile as sf

SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:/Users/perva/Desktop/Laser beam Heat Vision Sound effect - PIXEL PRESS LAB.mp3"
OUT = "assets/audio/gokkusagi/"
START_A = 1.04                  # baştaki sessizlik atılır: ses ateşleme anında başlar
LOOP_A, LOOP_B, XF = 2.20, 4.69, 0.12  # döngü gövdesi [A, B) - A/B kaynakta en iyi örtüşen (bağıntı 0,48) çift
XF_CORR = 0.48                  # çapraz geçişteki iki parçanın bağıntısı: gücü sabit tutmak için kazanç düzeltmesi
END_A, END_B = 6.35, 7.20       # kapanış: yükselmenin son kısmı + patlama (7,1'de bitiyor), kuyruk sessizliği atılır
FADE_IN, FADE_START, FADE_END = 0.025, 0.003, 0.03
END_GAIN = 0.85                 # kaynakta patlama tam 1,0 tepe; Vorbis sıkıştırması 1,12'ye taşıyıp kırpıyordu

d = miniaudio.decode(open(SRC, "rb").read(), output_format=miniaudio.SampleFormat.FLOAT32)
sr = d.sample_rate
a = np.array(d.samples, dtype=np.float32).reshape(-1, d.nchannels)
S = lambda t: int(round(t * sr))

ia, ib, x = S(LOOP_A), S(LOOP_B), S(XF)
body = a[ia:ib].copy()
n = len(body)
w = np.linspace(0.0, 1.0, x, dtype=np.float32)[:, None]
# döngü sonu: bitişe doğru, gövdenin doğal öncülü olan (A'dan önceki) malzemeye eriyip başa dikişsiz bağlanır;
# parçalar kısmen bağıntılı olduğundan ortada güç düşmesin diye kazanç düzeltilir
mix = (1.0 - w) * a[ib - x:ib] + w * a[ia - x:ia]
mix /= np.sqrt((1.0 - w) ** 2 + w ** 2 + 2.0 * w * (1.0 - w) * XF_CORR)
body[n - x:] = mix
head = a[S(START_A):ia].copy()
fs = S(FADE_START)
head[:fs] *= np.linspace(0.0, 1.0, fs, dtype=np.float32)[:, None]
start_loop = np.concatenate([head, body])
sf.write(OUT + "beam_start_loop.ogg", start_loop, sr, format="OGG", subtype="VORBIS")

end = a[S(END_A):S(END_B)].copy()
fi, fo = S(FADE_IN), S(FADE_END)
end[:fi] *= np.linspace(0.0, 1.0, fi, dtype=np.float32)[:, None]
end[-fo:] *= np.linspace(1.0, 0.0, fo, dtype=np.float32)[:, None]
end *= END_GAIN
sf.write(OUT + "beam_end.ogg", end, sr, format="OGG", subtype="VORBIS")
print("start_loop %.3f s (loop_offset %.3f), end %.3f s" % (len(start_loop) / sr, len(head) / sr, len(end) / sr))
