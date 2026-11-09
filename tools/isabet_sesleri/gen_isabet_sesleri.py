"""Kalkan / Mızrak / Tırpan İSABET sesleri (2026-11-09): kullanıcının masaüstü "burası" klasöründeki dosyaları varyantlarına ayırır.

Kullanıcı: "ses efektlerinin 2-3 parçaya ayrılması gerekiyor onları dikkatlice ayarla. her ses dosyasında 2-3 varyantı var".
Kaynaklar (birebir kopya, Godot içe aktarmasın diye .gdignore'lu): tools/isabet_sesleri/kaynak/{kalkan,mizrak,tirpan}_isabet.mp3
  kalkan  2,05 sn -> 2 varyant, mızrak 2,84 sn -> 3 varyant, tırpan 2,86 sn -> 3 varyant (aralarda -55 dBFS altı boşluk).
Her varyant için (sınırlar SEGS'te elle, 5 ms zarf ölçümüyle seçildi - bkz. docs/notlar madde 505):
  1. Başlangıç: ilk -45 dB (varyantın tepesine göre) örneğinden 5 ms önce. Vuruştan (-6 dB'ye ilk ulaştığı an) önceki giriş en çok
     MAX_LEAD_MS kalır: kalkan/tırpanda 50-75 ms'lik sürtünme girişi vardı -> ses görüntüdeki temastan geç patlıyordu. Kısaltılan girişe
     FADE_IN_MS yumuşak açılış (yükselen giriş zaten kısıktır, kesik duyulmaz); kısaltılmayan başa 3 ms (tık önleme).
  2. Bitiş: son -60 dB örneğinden 20 ms sonra (sonraki varyantın başlangıcını geçmez) + FADE_OUT_MS kosinüs kapanış.
  3. Seviye: bir silahın varyantları en kısık olanın 100 ms RMS'ine EŞİTLENİR (yalnız kısma - kırpılma olmaz); rastgele seçilen
     isabetler birbirinden yüksek/kısık duyulmaz. Oyundaki seviye sahnedeki volume_db ile (madde 441 ölçüsü: 100 ms RMS + volume_db).
Çıktı: assets/audio/{kalkan,mizrak,tirpan}_isabet_<n>.wav (16 bit, 44,1 kHz, stereo).
Kullanım: python -I tools/isabet_sesleri/gen_isabet_sesleri.py
"""
import os

import miniaudio
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(ROOT, "tools", "isabet_sesleri", "kaynak")
OUT_DIR = os.path.join(ROOT, "assets", "audio")

## Varyant arama pencereleri (sn): her pencerede tek bir isabet var; pencere sınırları iki varyant arasındaki sessizliğin içinde.
SEGS = {
	"kalkan": [(0.0, 1.037), (1.037, 2.052)],
	"mizrak": [(0.0, 1.0), (1.0, 2.1), (2.1, 2.835)],
	"tirpan": [(0.03, 1.12), (1.12, 2.045), (2.045, 2.861)],  ## 0-0,03 sn: dosya başındaki -43 dB'lik tık, alınmaz
}
ONSET_DB = -45.0
ATTACK_DB = -6.0
END_DB = -60.0
PRE_MS = 5.0
MAX_LEAD_MS = 45.0
FADE_IN_MS = 20.0
CLICK_FADE_MS = 3.0
TAIL_MS = 20.0
FADE_OUT_MS = 25.0


def load(path):
	d = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.FLOAT32)
	x = np.frombuffer(d.samples, dtype=np.float32).reshape(-1, d.nchannels).astype(np.float64)
	return x, d.sample_rate


def rms100(y, sr):
	mono = y.mean(axis=1)
	w = int(sr * 0.1)
	if len(mono) < w:
		return 10.0 * np.log10(np.mean(mono ** 2) + 1e-12)
	c = np.convolve(mono ** 2, np.ones(w) / w, mode="valid")
	return 10.0 * np.log10(c.max() + 1e-12)


def cut(x, sr, a, b):
	"""Arama penceresi [a, b) içindeki varyantı keser: (ses, bilgi)."""
	ia, ib = int(a * sr), min(len(x), int(b * sr))
	y = x[ia:ib]
	m = np.abs(y).max(axis=1)
	pk = m.max()
	on = int(np.argmax(m > pk * 10 ** (ONSET_DB / 20)))
	att = int(np.argmax(m > pk * 10 ** (ATTACK_DB / 20)))
	last = len(m) - 1 - int(np.argmax(m[::-1] > pk * 10 ** (END_DB / 20)))
	start = max(0, on - int(sr * PRE_MS / 1000))
	trimmed = False
	if att - start > int(sr * MAX_LEAD_MS / 1000):
		start = att - int(sr * MAX_LEAD_MS / 1000)
		trimmed = True
	end = min(len(y), last + int(sr * TAIL_MS / 1000))
	z = y[start:end].copy()
	n_in = int(sr * (FADE_IN_MS if trimmed else CLICK_FADE_MS) / 1000)
	n_in = min(n_in, len(z))
	z[:n_in] *= (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n_in)))[:, None]
	n_out = min(int(sr * FADE_OUT_MS / 1000), len(z))
	z[len(z) - n_out:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n_out)))[:, None]
	info = {"start": (ia + start) / sr, "end": (ia + end) / sr, "lead_ms": (att - start) / sr * 1000, "trimmed": trimmed}
	return z, info


def main():
	for name, segs in SEGS.items():
		x, sr = load(os.path.join(SRC_DIR, name + "_isabet.mp3"))
		parts = [cut(x, sr, a, b) for a, b in segs]
		levels = [rms100(z, sr) for z, _ in parts]
		ref = min(levels)
		for i, ((z, info), lv) in enumerate(zip(parts, levels), 1):
			g = 10 ** ((ref - lv) / 20)
			z = z * g
			out = os.path.join(OUT_DIR, "%s_isabet_%d.wav" % (name, i))
			sf.write(out, np.clip(z, -1.0, 1.0).astype(np.float32), sr, subtype="PCM_16")
			print("%s_%d  %.3f-%.3f sn (%.0f ms)  giriş %.0f ms%s  kazanç %+.1f dB  RMS100 %.1f  tepe %.1f dBFS" % (
				name, i, info["start"], info["end"], (info["end"] - info["start"]) * 1000, info["lead_ms"],
				" (kısaltıldı)" if info["trimmed"] else "", 20 * np.log10(g), rms100(z, sr), 20 * np.log10(np.abs(z).max() + 1e-12)))


if __name__ == "__main__":
	main()
