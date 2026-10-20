"""Yıldırım Asası VURUŞ sesi PROTOTİPLERİ (2026-10-19). Kullanıcı: "ses efektini daha tatmin edici tasarla, hasar
verdiğimizi hissettirsin" -> üç yön de istendi ("üçünü de dinlet").

Teşhis (ölçüm, K-ağırlıklı anlık ses, oyundaki volume_db dahil): ışın açıkken sadece sürekli uğultu
(assets/audio/lightning/electric_loop.mp3, -24,8 dB) duyuluyor; her hasar tikinde çalan ortak ateş sesi
(assets/audio/fire.mp3, -10 dB) -37,7 dB = uğultunun ~13 dB ALTINDA, pratikte duyulmuyor. Diğer silahların atış
sesleri oyunda -19 / -28,5 dB. Yani ışın "değiyor ama vurmuyor".

Tasarım (üç yönde ortak iskelet): hedefte her hasar tikinde kısa vuruş sesi (4 tohum, perde ±%6) + kritik tikte daha
ağır varyant + ışın hedefe kilitlenince başlangıç sesi; uğultu 3 dB geri (-4,5 -> -7,5) ve her tikte 120 ms 4 dB
çöker (yan zincir hissi). Saldırı hızı artınca tik sesi kısılır (sn başına enerji sabit: kazanç sqrt(aralık / 0,37)).
  A Çatırtı + Küt Darbe : sert çatlama + sık kıvılcım çıtırtısı + perdesi düşen tok gövde + kısa vızıltı kuyruğu
  B Tesla Zap           : vızıldayan ark ("bzzt", titreyen kare dalga + kesik kesik ark) + küçük çatlama + hafif tok
  C Gök Gürültüsü       : çoklu dönüş darbeli çatlama + kısa gürleme (kritikte uzun yuvarlanan gürleme)
Sınırlayıcı/doyurma YOK (feedback: tanh bozulması); tepe aşarsa bütün dosya kısılır. 120 Hz altı ve 150 Hz altı payı
ölçülür (dizüstü hoparlörde çamur).

Çalıştır: python tools/proto_20261019/yildirim_ses_proto.py  -> tools/proto_20261019/out/yildirim_ses/
  <X>_demo.wav  : oyundaki gibi (uğultu + kilitlenme + 0,37 sn tikler, 5. tik kritik; sonra 0,12 sn hızlı tikler)
  simdiki_demo.wav : bugünkü hâl (uğultu -4,5 dB + her tikte fire.mp3 -10 dB), aynı ortak kazançla
  parcalar/<X>_tik_1..4.wav, <X>_kritik.wav, <X>_kilit.wav : oyuna bağlanacak tek tek sesler (-14 K normalize)
  rapor.txt
Gerekir: numpy + miniaudio (mp3 çözümü; `python -m pip install --user miniaudio`). Oyuna bağlı DEĞİL.
"""

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "proto_20261017"))
import ses_proto as sp  # noqa: E402  (fft_filter, reverb, ölçüm, normalize, save)

SR = sp.SR
OUT = os.path.join(HERE, "out", "yildirim_ses")
PARTS = os.path.join(OUT, "parcalar")
sp.OUT = OUT

TICK_INTERVAL = 0.3703703      # weapon_lightning.tscn beam_tick_interval (taban)
HUM_DB_NOW = -4.5              # fx_lightning_beam.gd BEAM_SFX_DB bugün
HUM_DB_NEW = -7.5              # öneri: uğultu 3 dB geri
FIRE_DB = -10.0                # player.tscn FireSound
TICK_GAME_K = -23.5            # tik oyunda (ateş asası -22,5 / tabanca -24,7 / tüfek -19); uğultu -27,8
CRIT_GAME_K = -21.0
LOCK_GAME_K = -26.0
STRIKE_GAME_K = -21.0          # A'nın kilidi = İLK ÇAKIŞ (kullanıcı: "ilk yıldırım için de efekt istemiştim"), kritik kadar
STRIKE_GAP = 0.5              # ilk çakış en fazla 0,5 sn'de bir (kalabalıkta hedef sık değişir)
FILE_K = -14.0                 # parça dosyalarının normalize seviyesi (oyunda volume_db ile ayarlanır)
DUCK_DB = -4.0
DUCK_SEC = 0.12


# ---------- yapı taşları ----------
def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def decay(t, t60):
    return np.exp(-6.91 * t / t60)


def crack(rng, dur=0.03, t60=0.007, hp=1500, lp=9000):
    """Çatlama: geniş bantlı gürültü patlaması ("çat", tık değil: 6-8 ms söner, 9 kHz üstü yumuşak)."""
    t = t_axis(dur)
    x = rng.randn(len(t)) * decay(t, t60)
    return sp.attack_ramp(sp.fft_filter(x, hp=hp, lp=lp, hp_order=2, lp_order=2), 0.0005)


def crackle(rng, dur, rate0, t60, hp=2000, lp=9000, grain=(12, 36), level=0.06):
    """Kıvılcım çıtırtısı: düzensiz aralıklı kısa gürültü taneleri (Poisson), hızı ve gücü zamanla söner.
    Tane genliği sınırlı + ilk 60 ms RMS = level: tohumlar arası ses farkı / tek tanenin sivri tepesi olmasın."""
    n = int(SR * dur)
    x = np.zeros(n)
    tt = 0.0
    while True:
        rate = rate0 * decay(tt, t60) + 1e-3
        tt += rng.exponential(1.0 / rate)
        if tt >= dur:
            break
        g = int(rng.randint(grain[0], grain[1]))
        s = int(tt * SR)
        e = min(n, s + g)
        amp = np.clip(np.exp(rng.randn() * 0.35), 0.5, 1.6) * decay(tt, t60)
        x[s:e] += rng.randn(e - s) * np.hanning(g)[: e - s] * amp
    x = sp.fft_filter(x, hp=hp, lp=lp, hp_order=2, lp_order=2)
    head = x[: int(SR * 0.06)]
    return x * (level / (np.sqrt(np.mean(head ** 2)) + 1e-9))


def thump(f_hi, f_lo, dur, t60, glide=0.025):
    """Perdesi düşen sinüs gövde (vuruşun 'tok'u)."""
    t = t_axis(dur)
    f = f_lo + (f_hi - f_lo) * np.exp(-t / glide)
    ph = np.cumsum(sp.TWO_PI * f / SR)
    return sp.attack_ramp(np.sin(ph) * decay(t, t60), 0.0008)


def knock(rng, dur, t60, hp, lp):
    """Orta bant tok gürültü (gövdenin 'tahta' kısmı)."""
    t = t_axis(dur)
    return sp.attack_ramp(sp.fft_filter(rng.randn(len(t)), hp=hp, lp=lp) * decay(t, t60), 0.0008)


def buzz(rng, f0, dur, t60, attack=0.003, jitter=0.12, chop=0.0, hp=180, lp=7000, f_end=None):
    """Elektrik vızıltısı: perdesi titreyen kare dalga (bant sınırlı) + isteğe bağlı kesik kesik ark (chop)."""
    t = t_axis(dur)
    f = np.full(len(t), float(f0)) if f_end is None else f0 + (f_end - f0) * (t / dur) ** 0.6
    walk = np.cumsum(rng.randn(len(t))) / np.sqrt(SR * 0.004)
    walk = sp.fft_filter(walk, lp=60, lp_order=2)
    walk /= np.abs(walk).max() + 1e-9
    f = f * (1.0 + jitter * walk)
    ph = np.cumsum(sp.TWO_PI * f / SR)
    x = np.zeros(len(t))
    for k in range(1, 40, 2):  # tek harmonikler = kare dalga; harmonikler Nyquist'i aşmasın
        x += np.where(k * f < SR * 0.45, np.sin(k * ph) / k, 0.0)
    env = np.minimum(1.0, t / attack) * decay(np.maximum(0.0, t - attack), t60)
    if chop > 0.0:  # arkın kopup bağlanması: rastgele kapı (yumuşak kenarlı)
        gate = (rng.rand(int(dur * 300) + 2) > chop).astype(float)
        gate = np.interp(t * 300, np.arange(len(gate)), gate)
        gate = sp.fft_filter(gate, lp=900, lp_order=1)
        env = env * np.clip(0.25 + 0.75 * gate, 0.0, 1.0)
    return sp.fft_filter(x * env, hp=hp, lp=lp, hp_order=2, lp_order=2)


def fizz(rng, dur, t60, mod_hz=110.0, hp=3000, lp=8000):
    """Vızıltı kuyruğu: şebeke uğultusu gibi genliği titreyen yüksek bantlı gürültü."""
    t = t_axis(dur)
    m = 0.5 + 0.5 * np.sin(sp.TWO_PI * mod_hz * t) ** 2
    return sp.fft_filter(rng.randn(len(t)), hp=hp, lp=lp) * m * decay(t, t60)


def rumble(rng, dur, attack, t60, lp=320, hp=45, rolls=14.0):
    """Gürleme: alçak geçiren gürültü, yavaş rastgele yuvarlanma (genlik dalgalanması)."""
    t = t_axis(dur)
    x = sp.fft_filter(rng.randn(len(t)), hp=hp, lp=lp, hp_order=2, lp_order=3)
    roll = sp.fft_filter(rng.randn(len(t)), lp=rolls, lp_order=2)
    roll = 0.55 + 0.45 * roll / (np.abs(roll).max() + 1e-9)
    env = np.minimum(1.0, t / attack) ** 2 * decay(np.maximum(0.0, t - attack), t60)
    return x * env * roll


def zip_up(rng, dur, f0, f1, t60):
    """Kilitlenme 'zip'i: merkezi yükselen dar bant gürültü."""
    t = t_axis(dur)
    x = rng.randn(len(t))
    out = np.zeros(len(t))
    seg = int(SR * 0.006)
    win = np.hanning(seg * 2)
    for i in range(0, len(t) - seg * 2, seg):
        fc = f0 * (f1 / f0) ** (i / len(t))
        out[i:i + seg * 2] += sp.fft_filter(x[i:i + seg * 2], hp=fc * 0.7, lp=fc * 1.4) * win
    env = np.minimum(1.0, t / (dur * 0.6)) * decay(np.maximum(0.0, t - dur * 0.6), t60)
    return out * env


def mix(length, *layers):
    buf = np.zeros(int(SR * length))
    for start, sig, gain_db in layers:
        sp.place(buf, sig, start, 10 ** (gain_db / 20))
    return buf


def finish(x, hp=70, lp=11000, room_t60=0.22, room_db=-17.0):
    x = sp.reverb(x, t60=room_t60, wet_db=room_db, pre=0.006, lp=5000)
    return sp.finish(x, hp=hp, lp=lp, tail_db=-62)


# ---------- A: Çatırtı + Küt Darbe ----------
def a_tick(seed):
    r = np.random.RandomState(100 + seed)
    return finish(mix(0.36,
        (0.000, crack(r), -2.0),
        (0.002, crackle(r, 0.12, 1100, 0.05), 0.0),
        (0.000, thump(230, 85, 0.2, 0.11), -7.0),
        (0.000, knock(r, 0.06, 0.03, 300, 1000), 0.0),
        (0.010, fizz(r, 0.16, 0.09), -10.0)), hp=90)


def a_crit():
    r = np.random.RandomState(150)
    return finish(mix(0.62,
        (0.000, crack(r, t60=0.009, hp=1200), -4.0),
        (0.028, crack(r), -7.0),                          # çift çatlama
        (0.002, crackle(r, 0.20, 1400, 0.08), 1.0),
        (0.000, thump(210, 70, 0.32, 0.19), -5.0),
        (0.000, knock(r, 0.08, 0.04, 250, 900), 0.0),
        (0.004, rumble(r, 0.5, 0.006, 0.24, lp=420, hp=90), -10.0),
        (0.010, fizz(r, 0.3, 0.16), -9.0)), hp=80, room_t60=0.3)


def a_strike():
    """İLK ÇAKIŞ (ışın hedefe ilk değdiği an): kısa kabarma + 3 dönüş darbeli çatlama + kıvılcım patlaması + tok gövde + kısa gürleme."""
    r = np.random.RandomState(180)
    return finish(mix(0.75,
        (0.000, zip_up(r, 0.045, 1800, 7000, 0.03), -9.0),
        (0.040, crack(r, t60=0.010, hp=1000), -2.0),
        (0.058, crack(r, t60=0.007), -6.0),
        (0.079, crack(r, t60=0.006), -9.0),
        (0.042, crackle(r, 0.28, 1500, 0.11), 1.0),
        (0.040, thump(250, 72, 0.4, 0.22), -3.0),
        (0.040, knock(r, 0.1, 0.05, 250, 1000), 1.0),
        (0.046, rumble(r, 0.55, 0.008, 0.3, lp=450, hp=90), -7.0),
        (0.050, fizz(r, 0.4, 0.22), -7.0)), hp=80, room_t60=0.35, room_db=-15.0)


def a_lock():
    r = np.random.RandomState(170)
    return finish(mix(0.28,
        (0.000, zip_up(r, 0.07, 1500, 7000, 0.05), -4.0),
        (0.060, crack(r), -9.0),
        (0.062, crackle(r, 0.12, 600, 0.06), -6.0),
        (0.060, thump(260, 120, 0.12, 0.07), -12.0)))


# ---------- B: Tesla Zap ----------
def b_tick(seed):
    r = np.random.RandomState(200 + seed)
    f0 = 128.0 * (1.0 + 0.06 * (seed - 1.5))
    return finish(mix(0.30,
        (0.000, crack(r, t60=0.005, hp=1800), -9.0),
        (0.000, buzz(r, f0, 0.15, 0.11, chop=0.35, hp=320, lp=10000), -1.0),
        (0.000, thump(260, 110, 0.12, 0.07), -10.0),
        (0.004, crackle(r, 0.1, 700, 0.05, hp=3000), -3.0)), hp=100, room_t60=0.18)


def b_crit():
    r = np.random.RandomState(250)
    return finish(mix(0.48,
        (0.000, buzz(r, 95.0, 0.09, 0.2, attack=0.03, chop=0.2, f_end=210.0, hp=250, lp=10000), -6.0),  # "bzz-"
        (0.085, crack(r, t60=0.008, hp=1300), -6.0),                                                  # "-ZAP"
        (0.085, buzz(r, 165.0, 0.22, 0.15, chop=0.3, hp=300, lp=10000), -1.0),
        (0.085, thump(220, 80, 0.26, 0.15), -6.0),
        (0.088, crackle(r, 0.18, 1100, 0.07), -1.0)), hp=90, room_t60=0.26)


def b_lock():
    r = np.random.RandomState(270)
    return finish(mix(0.24,
        (0.000, buzz(r, 90.0, 0.16, 0.14, attack=0.04, f_end=230.0, chop=0.25, hp=250, lp=10000), -3.0),
        (0.000, zip_up(r, 0.08, 2000, 6500, 0.05), -10.0)), room_t60=0.16)


# ---------- C: Gök Gürültüsü Vuruşu ----------
def c_tick(seed):
    r = np.random.RandomState(300 + seed)
    gaps = [0.0, 0.009 + 0.004 * r.rand(), 0.021 + 0.006 * r.rand()]  # yıldırımın dönüş darbeleri
    layers = [(g, crack(r, t60=0.006, hp=1100), -5.0 - 1.5 * i) for i, g in enumerate(gaps)]
    layers += [
        (0.002, crackle(r, 0.09, 800, 0.04), -3.0),
        (0.000, thump(200, 78, 0.24, 0.14), -6.0),
        (0.006, rumble(r, 0.36, 0.01, 0.2, lp=360, hp=85), -6.0),
    ]
    return finish(mix(0.40, *layers), hp=90, room_t60=0.3, room_db=-15.0)


def c_crit():
    r = np.random.RandomState(350)
    gaps = [0.0, 0.011, 0.024, 0.045]
    layers = [(g, crack(r, t60=0.008, hp=1000), -4.0 - 1.0 * i) for i, g in enumerate(gaps)]
    layers += [
        (0.002, crackle(r, 0.22, 1200, 0.09), -1.0),
        (0.000, thump(180, 82, 0.4, 0.24), -6.0),
        (0.008, rumble(r, 0.95, 0.02, 0.6, lp=340, hp=90, rolls=9.0), -9.0),
    ]
    return finish(mix(1.0, *layers), hp=90, room_t60=0.45, room_db=-14.0)


def c_lock():
    r = np.random.RandomState(370)
    return finish(mix(0.40,
        (0.000, zip_up(r, 0.06, 1200, 5000, 0.04), -8.0),
        (0.050, crack(r, hp=1100), -7.0),
        (0.056, rumble(r, 0.3, 0.01, 0.18, lp=320, hp=85), -10.0)), hp=85, room_t60=0.3)


VARIANTS = {
    "A": ("Çatırtı + Küt Darbe", a_tick, a_crit, a_strike),
    "B": ("Tesla Zap", b_tick, b_crit, b_lock),
    "C": ("Gök Gürültüsü", c_tick, c_crit, c_lock),
}


# ---------- demo (oyundaki gibi) ----------
def decode_mp3(rel):
    import miniaudio
    d = miniaudio.decode_file(os.path.join(ROOT, rel), output_format=miniaudio.SampleFormat.FLOAT32,
                              nchannels=1, sample_rate=SR)
    return np.frombuffer(d.samples, dtype=np.float32).astype(np.float64)


def k_gain(x, game_k):
    """Dosyayı oyundaki hedef anlık K seviyesine getiren doğrusal kazanç."""
    return 10 ** ((game_k - sp.max_momentary_db(x)) / 20)


def tick_times():
    """0,05 sn kilitlenme; ilk tik bir tam aralık sonra (weapon.gd: anında hasar yok). 8 normal tik (5. kritik),
    0,5 sn ara, ikinci kilitlenme + 0,12 sn aralıklı 14 hızlı tik (saldırı hızı ~x3)."""
    seq = []
    lock1 = 0.05
    for i in range(8):
        seq.append((lock1 + TICK_INTERVAL * (i + 1), i == 4, TICK_INTERVAL))
    end1 = lock1 + TICK_INTERVAL * 8 + 0.12
    lock2 = end1 + 0.5
    for i in range(14):
        seq.append((lock2 + 0.12 * (i + 1), i == 9, 0.12))
    end2 = lock2 + 0.12 * 14 + 0.12
    return [(lock1, end1), (lock2, end2)], seq


def hum_bed(hum, total, beams, ticks, hum_db, duck):
    out = np.zeros(int(SR * total))
    fade = int(SR * 0.03)
    for (s, e) in beams:
        n = int(SR * (e - s))
        bed = np.tile(hum, n // len(hum) + 1)[:n].copy()
        bed[:fade] *= np.linspace(0, 1, fade)
        bed[-fade:] *= np.linspace(1, 0, fade)
        out[int(SR * s):int(SR * s) + n] += bed
    gain = np.full(len(out), 10 ** (hum_db / 20))
    if duck:
        t = np.arange(len(out)) / SR
        g_db = np.zeros(len(out))
        for (tt, _crit, _iv) in ticks:
            m = (t >= tt) & (t < tt + DUCK_SEC)
            rel = (t[m] - tt) / DUCK_SEC
            g_db[m] = np.minimum(g_db[m], DUCK_DB * (1.0 - rel) ** 2)
        gain *= 10 ** (g_db / 20)
    return out * gain


def demo(tick_set, crit, lock, hum, hum_db, duck=True, legacy=None):
    beams, ticks = tick_times()
    total = beams[-1][1] + 1.0
    out = hum_bed(hum, total, beams, ticks, hum_db, duck)
    rng = np.random.RandomState(7)
    if lock is not None:
        for (s, _e) in beams:
            sp.place(out, lock[0], s, lock[1])
    last = -1
    for (tt, is_crit, iv) in ticks:
        if legacy is not None:
            sig, g = legacy
            sp.place(out, resample(sig, rng.uniform(0.92, 1.08)), tt, g)
            continue
        rate_gain = np.sqrt(min(1.0, iv / TICK_INTERVAL))  # saldırı hızı artınca sn başına enerji sabit
        if is_crit:
            sig, g = crit
        else:
            k = rng.randint(len(tick_set))
            if k == last:
                k = (k + 1) % len(tick_set)
            last = k
            sig, g = tick_set[k]
        sp.place(out, resample(sig, rng.uniform(0.94, 1.06)), tt, g * rate_gain)
    return out


def resample(x, pitch):
    """Godot pitch_scale gibi: hız + perde birlikte."""
    n = int(len(x) / pitch)
    return np.interp(np.arange(n) * pitch, np.arange(len(x)), x)


def crest_db(x):
    return 20 * np.log10(np.abs(x).max() + 1e-12) - sp.max_momentary_db(x)


def best_ticks(tick_fn, n=4, pool=10):
    """10 tohumdan tepe/ses oranı en düşük 4'ü: tek bir tohumun sivri tepesi (tık) oyunda diğerlerinden sert çıkmasın."""
    cands = sorted((crest_db(tick_fn(i)), i) for i in range(pool))
    return [tick_fn(i) for _c, i in sorted(cands[:n], key=lambda c: c[1])], [i for _c, i in cands[:n]]


def lock_k(key):
    return STRIKE_GAME_K if key == "A" else LOCK_GAME_K


def export_a():
    """Seçilen A -> assets/audio/lightning/ (vurus_1..4, kritik, ilk_cakis .wav). Dört vuruş AYNI anlık K'ya (ortalama; tepe 0,89'u
    aşan kısılır) çekilir ki oyunda tek volume_db yetsin; oyun volume_db'leri yazdırılır (fx_lightning_beam.gd sabitleri)."""
    dest = os.path.join(ROOT, "assets", "audio", "lightning")
    ticks, _seeds = best_ticks(a_tick)
    ## önce dördü aynı K'ya, sonra hepsine TEK ortak kazanç (en sivri tepe 0,89) - eşitlik bozulmasın.
    ks = [sp.max_momentary_db(t) for t in ticks]
    eq = [t * 10 ** ((ks[0] - ks[i]) / 20) for i, t in enumerate(ticks)]
    g = 0.89 / max(np.abs(y).max() for y in eq)
    for i, y in enumerate(eq):
        y = y * g
        sp.save(os.path.join(dest, f"vurus_{i + 1}.wav"), y)
        print(f"vurus_{i + 1}.wav K {sp.max_momentary_db(y):.1f} tepe {np.abs(y).max():.2f}")
    print(f"HIT_DB = {TICK_GAME_K - sp.max_momentary_db(eq[0] * g):+.1f}")
    for name, sig, game_k in (("kritik", a_crit(), CRIT_GAME_K), ("ilk_cakis", a_strike(), STRIKE_GAME_K)):
        n, note = sp.normalize(sig, FILE_K, peak_cap=0.89)
        sp.save(os.path.join(dest, f"{name}.wav"), n)
        print(f"{name}.wav K {sp.max_momentary_db(n):.1f} tepe {np.abs(n).max():.2f} -> volume_db {game_k - sp.max_momentary_db(n):+.1f}")
        print("  " + sp.analyze(n, name))


def main():
    os.makedirs(PARTS, exist_ok=True)
    hum = decode_mp3("assets/audio/lightning/electric_loop.mp3")
    fire = decode_mp3("assets/audio/fire.mp3")
    lines = ["Yıldırım Asası vuruş sesi prototipleri - ölçüm (K = K-ağırlıklı anlık ses, 400 ms pencere)", ""]
    lines.append(sp.analyze(hum, "uğultu (electric_loop)") + f" | oyunda K {sp.max_momentary_db(hum) + HUM_DB_NOW:6.1f}")
    lines.append(sp.analyze(fire, "tik şimdi (fire.mp3)") + f" | oyunda K {sp.max_momentary_db(fire) + FIRE_DB:6.1f}")
    lines.append("")
    demos = {}
    for key, (name, tick_fn, crit_fn, lock_fn) in VARIANTS.items():
        ticks, seeds = best_ticks(tick_fn)
        crit = crit_fn()
        lock = lock_fn()
        tick_set = [(t, k_gain(t, TICK_GAME_K)) for t in ticks]
        demos[key] = demo(tick_set, (crit, k_gain(crit, CRIT_GAME_K)), (lock, k_gain(lock, lock_k(key))),
                          hum, HUM_DB_NEW)
        lines.append(f"{key} - {name} (seçilen tohumlar {sorted(seeds)})")
        for i, t in enumerate(ticks):
            n, note = sp.normalize(t, FILE_K, peak_cap=0.89)
            sp.save(os.path.join("parcalar", f"{key}_tik_{i + 1}.wav"), n)
            vol = TICK_GAME_K - sp.max_momentary_db(n)
            lines.append("  " + sp.analyze(n, f"{key}_tik_{i + 1}") + f" | oyun volume_db {vol:+.1f}{note}")
        for label, sig, game_k in (("kritik", crit, CRIT_GAME_K), ("kilit", lock, lock_k(key))):
            n, note = sp.normalize(sig, FILE_K, peak_cap=0.89)
            sp.save(os.path.join("parcalar", f"{key}_{label}.wav"), n)
            vol = game_k - sp.max_momentary_db(n)
            lines.append("  " + sp.analyze(n, f"{key}_{label}") + f" | oyun volume_db {vol:+.1f}{note}")
        lines.append("")
    demos["simdiki"] = demo(None, None, None, hum, HUM_DB_NOW, duck=False, legacy=(fire, 10 ** (FIRE_DB / 20)))
    # Tüm demolar AYNI ortak kazançla (karşılaştırma dürüst kalsın): en yüksek tepe 0,89.
    common = 0.89 / max(np.abs(d).max() for d in demos.values())
    lines.append(f"Demolar ortak kazanç {20 * np.log10(common):+.1f} dB (en yüksek tepe 0,89; sınırlayıcı yok)")
    for key, d in demos.items():
        d = d * common
        name = "simdiki_demo.wav" if key == "simdiki" else f"{key}_demo.wav"
        sp.save(name, d)
        lines.append(f"  {name:<18} anlık K maks {sp.max_momentary_db(d):6.1f} dB, tepe {np.abs(d).max():.2f}")
    with open(os.path.join(OUT, "rapor.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    if "--oyuna" in sys.argv:
        export_a()
    else:
        main()
