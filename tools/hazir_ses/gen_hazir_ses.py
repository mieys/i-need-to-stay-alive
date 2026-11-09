"""Kullanıcının masaüstü "hazır ses" klasöründeki sesleri oyuna hazırlar (2026-11-09, madde 533).

Kaynaklar (birebir kopya, ASCII ad, Godot içe aktarmasın diye .gdignore'lu): tools/hazir_ses/kaynak/<anahtar>.mp3
Her ses için:
  1. Kırpma: baş = 5 ms pencerede tepeden ONSET_DB altındaki ilk sesten 5 ms önce (ya da elle "start"), son = 20 ms pencerede
     tepeden end_db üstündeki son sesten 20 ms sonra + kosinüs kapanış. Golem dosyaları 8 sn: ~1-2 sn ses + sonuna kadar
     tepeden ~-46 dB'lik sabit taban -> end_db -40 (taban kesilir).
  2. Hadime Kara Delik: dosyanın sonundaki ÇÖKÜŞ vuruşu (dosyada 5,26 sn) deliğin çöküş karesine (oyunda 6,25 sn = HOLE_DURATION 6
     + outro'nun 4. karesi / 16 fps, kıvılcım + şok halkası) otursun diye ortadaki uğultu iki yerden uzatılır (SPLICES): aynı
     uğultunun bir parçası korelasyonla hizalanmış çapraz geçişle bir kez daha çalar (perde/hız DEĞİŞMEZ). Baş 0,50 sn kırpılır
     -> sesin girişi delik doğduktan ~0,12 sn sonra (intro 0,4 sn içinde).
  3. Don Nova: baştaki çok sessiz 0,30 sn atılır -> sesin patlaması (dosyada ~1,30 sn) odaklanmanın bittiği ana (oyunda 1,0 sn)
     düşer; sesin bitişi (tepeden -38 dB, dosyada ~3,60 sn) oyunda 3,30 sn -> dalga süresi 2,3 sn (player.gd BUYUCU_NOVA_WAVE_TIME).
  4. Seviye: dosyanın tepesi -1 dBFS'e getirilir; oyundaki seviye volume_db ile. Hedef = değiştirilen eski
     sesin oyun içi gürlüğü (400 ms RMS + volume_db; tablo docs/notlar madde 533). Betik her ses için önerilen volume_db'yi yazar.
Çıktı: assets/audio/... (16 bit, 44,1 kHz, stereo wav).
Kullanım: python -I tools/hazir_ses/gen_hazir_ses.py [anahtar ...]  (anahtarsız = hepsi)
"""
import os
import sys

import miniaudio
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "hazir_ses", "kaynak")
SR = 44100

## anahtar -> (çıktı, hedef oyun içi gürlük dB (400 ms RMS + volume_db), ayarlar)
SOUNDS = {
	"level_atlama": ("assets/audio/level_atlama.wav", -24.7, {}),
	"level_kart_secme": ("assets/audio/level_kart_secme.wav", -22.0, {}),
	"evrim_kart_secme": ("assets/audio/evrim_kart_secme.wav", -21.0, {}),
	"seytan_ses": ("assets/audio/boss/seytan_ses.wav", -20.0, {}),
	"seytan_yetenek": ("assets/audio/boss/seytan_yetenek.wav", -19.0, {}),
	"melek_ulti": ("assets/audio/skills/melek_ulti.wav", -16.7, {}),
	"shaman_golem_q": ("assets/audio/skills/shaman_golem_q.wav", -13.8, {"end_db": -40.0, "fade_out": 0.08}),
	"shaman_golem_e": ("assets/audio/skills/shaman_golem_e.wav", -14.5, {"end_db": -40.0, "fade_out": 0.08}),
	"shaman_golem_oto": ("assets/audio/skills/shaman_golem_oto.wav", -24.0, {"end_db": -40.0, "fade_out": 0.08}),
	"buyucu_don_nova": ("assets/audio/skills/buyucu_don_nova.wav", -21.0, {"start": 0.30, "fade_in": 0.05}),
	"hadime_kara_delik": ("assets/audio/skills/hadime_kara_delik.wav", -15.0, {"start": 0.50, "fade_in": 0.03, "hadime": True}),
	## Assasin E odak sesi (kullanıcı klasör dışında verdi): 2,03 sn yükselen ses + sonuna kadar -45 dB taban -> taban kesilir;
	## sesin keskin bitişi dosyada 2,027 sn = oyunda ~2,01 sn = odak sonu (player.gd ASSASIN_INVIS_FOCUS_TIME 2,0), görünmez olunan an
	"assasin_gorunmezlik": ("assets/audio/skills/assasin_gorunmezlik.wav", -19.0, {"end_db": -40.0}),
}
ONSET_DB = -50.0
END_DB = -60.0
CLICK_FADE = 0.003
FADE_OUT = 0.04
PEAK_LIMIT_DB = -1.0

## Hadime: dosya zamanı (sn). Çöküş vuruşu oyunda HOLE_OUTRO_HIT'e otursun.
HADIME_BOOM_FILE = 5.26
HADIME_OUTRO_HIT = 6.0 + 4.0 / 16.0
SPLICE_XFADE = 0.30
## iki uzatma bölgesi (KIRPILMIŞ zamanda, [en erken, en geç] - parçanın tamamı bu aralıkta kalır): 1. bölge dalgalı uğultu,
## 2. bölge sabit ~275 Hz'lik uğultu (dosyada 3,0-4,5 sn)
SPLICE_ZONES = [(0.90, 2.50), (2.50, 4.05)]


def load(key):
	with open(os.path.join(SRC, key + ".mp3"), "rb") as f:
		d = miniaudio.decode(f.read(), output_format=miniaudio.SampleFormat.FLOAT32, nchannels=2, sample_rate=SR)
	return np.frombuffer(d.samples, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def win_db(x, w_sec):
	mono = x.mean(axis=1)
	w = max(1, int(SR * w_sec))
	n = len(mono) // w
	r = np.sqrt(np.mean(mono[: n * w].reshape(n, w) ** 2, axis=1))
	return 20.0 * np.log10(r + 1e-12), w


def rms_db(x, w_sec):
	mono = x.mean(axis=1)
	w = int(SR * w_sec)
	if len(mono) < w:
		return 10.0 * np.log10(np.mean(mono ** 2) + 1e-12)
	c = np.convolve(mono ** 2, np.ones(w) / w, mode="valid")
	return 10.0 * np.log10(c.max() + 1e-12)


def fade(x, n_in, n_out):
	y = x.copy()
	if n_in > 0:
		y[:n_in] *= (0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, n_in)))[:, None]
	if n_out > 0:
		y[-n_out:] *= (0.5 + 0.5 * np.cos(np.linspace(0.0, np.pi, n_out)))[:, None]
	return y


def best_splice(x, lo, hi, lag, lag_tol):
	"""[lo, hi] (sn) içinde: x[A-c/2 .. A+c/2] ile x[A-lag-c/2 ..] en çok benzeşen (A, lag). Parça [A-lag-c/2, A+c/2] aralıkta kalır."""
	c = int(SPLICE_XFADE * SR)
	mono = x.mean(axis=1)
	best = (-2.0, 0, 0)
	lags = range(int((lag - lag_tol) * SR), int((lag + lag_tol) * SR) + 1, 22)
	for L in lags:
		a_min = int(lo * SR) + L + c // 2
		a_max = int(hi * SR) - c // 2
		for A in range(a_min, a_max, 88):
			p = mono[A - c // 2: A + c // 2]
			q = mono[A - L - c // 2: A - L + c // 2]
			den = np.sqrt(np.dot(p, p) * np.dot(q, q)) + 1e-12
			r = float(np.dot(p, q) / den)
			if r > best[0]:
				best = (r, A, L)
	return best


def splice(segs):
	"""segs: [(dizi, xfade_n, eş_güç?)] - art arda çapraz geçişle birleştirir."""
	out = segs[0][0]
	for seg, n, power in segs[1:]:
		t = np.linspace(0.0, 1.0, n)
		if power:
			fo, fi = np.cos(t * np.pi / 2.0), np.sin(t * np.pi / 2.0)
		else:
			fo, fi = 1.0 - t, t
		mid = out[-n:] * fo[:, None] + seg[:n] * fi[:, None]
		out = np.concatenate([out[:-n], mid, seg[n:]])
	return out


def hadime_extend(x, start):
	"""x: kırpılmış ses (start sn atılmış). İki bölgeden toplam D uzatır; dönüş (ses, rapor)."""
	D = HADIME_OUTRO_HIT - (HADIME_BOOM_FILE - start)
	c = int(SPLICE_XFADE * SR)
	r1, A1, L1 = best_splice(x, SPLICE_ZONES[0][0], SPLICE_ZONES[0][1], D / 2.0, 0.012)
	## ikinci ek sabit ~275 Hz'lik uğultuda: +-4 ms pay (bir periyot 3,6 ms) faz hizası bulsun; vuruş en çok 4 ms kayar
	r2, A2, L2 = best_splice(x, SPLICE_ZONES[1][0], SPLICE_ZONES[1][1], D - L1 / SR, 0.004)
	seg1 = x[: A1 + c // 2]
	seg2 = x[A1 - L1 - c // 2: A2 + c // 2]
	seg3 = x[A2 - L2 - c // 2:]
	## yüksek korelasyon = eş fazlı -> doğrusal geçiş (toplam genlik sabit); düşük = bağımsız gürültü -> eş güç
	y = splice([(seg1, 0, False), (seg2, c, r1 < 0.6), (seg3, c, r2 < 0.6)])
	boom = HADIME_BOOM_FILE - start + (L1 + L2) / SR
	rep = "uzatma %.3f sn (hedef %.3f): ek1 A=%.3f lag=%.3f r=%.2f, ek2 A=%.3f lag=%.3f r=%.2f, vuruş oyunda %.3f sn" % (
		(L1 + L2) / SR, D, A1 / SR, L1 / SR, r1, A2 / SR, L2 / SR, r2, boom)
	return y, rep


def process(key):
	out_rel, target, cfg = SOUNDS[key]
	x = load(key)
	db5, w5 = win_db(x, 0.005)
	peak5 = db5.max()
	if "start" in cfg:
		i0 = int(cfg["start"] * SR)
	else:
		on = np.where(db5 > peak5 + ONSET_DB)[0]
		i0 = max(0, int(on[0]) * w5 - int(0.005 * SR))
	db20, w20 = win_db(x, 0.02)
	end_db = cfg.get("end_db", END_DB)
	act = np.where(db20 > db20.max() + end_db)[0]
	i1 = min(len(x), (int(act[-1]) + 2) * w20)
	y = x[i0:i1]
	rep = ""
	if cfg.get("hadime"):
		y, rep = hadime_extend(y, cfg["start"])
	n_in = int(cfg.get("fade_in", CLICK_FADE if i0 > 0 else 0.0) * SR)
	y = fade(y, n_in, int(cfg.get("fade_out", FADE_OUT) * SR))
	## tepe -1 dBFS'e (kısık dosyalar yükseltilir: 16 bitte çözünürlük kaybolmasın; seviye volume_db ile)
	peak = 20.0 * np.log10(np.abs(y).max() + 1e-12)
	y *= 10.0 ** ((PEAK_LIMIT_DB - peak) / 20.0)
	r400 = rms_db(y, 0.4)
	vol = target - r400
	path = os.path.join(ROOT, out_rel)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	sf.write(path, y.astype(np.float32), SR, subtype="PCM_16")
	print("%-18s %5.2f -> %5.2f sn (baş %.3f sn atıldı)  tepe %5.1f dBFS  rms400 %5.1f  önerilen volume_db %+5.1f  %s" % (
		key, len(x) / SR, len(y) / SR, i0 / SR, 20.0 * np.log10(np.abs(y).max() + 1e-12), r400, vol, rep))


if __name__ == "__main__":
	for k in sys.argv[1:] or list(SOUNDS):
		process(k)
