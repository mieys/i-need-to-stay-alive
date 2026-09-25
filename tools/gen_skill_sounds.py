"""Sesi olmayan karakter yeteneklerinin ses efektleri -> assets/audio/skills/*.wav

Kullanici istegi (2026-09-25): "bazi karakterlerin bazi yeteneklerinin ses efekti yok skillerine uygun ses efekti
hazirlar misin". Tarama (her _skill_* fonksiyonu + cagirdigi yardimcilar + olusturdugu FX sahneleri) su yeteneklerin
HIC ses calmadigini gosterdi: Talon Q/E/R, Oakley E/R, Buyucu Arcane Lanet, Sovalye Q/E, Elara Q, Korsan E (bomba
koyma) / R (bombardiman vuruslari), Melek R, Necromancer Q/E/R (R'de yalniz carpisma sesi vardi), Vampir Q/E/R.

Yontem: projedeki telifsiz "Sound FX Starter Pack Vol. 1" kayitlarindan uygun parcalar KISA tek seferlik seslere
kirpilir (vurus kismi + yumusak sonum), perde/filtreyle yetenegin karakterine uydurulur, gerektiginde numpy ile
sentezlenen katmanlar eklenir (yarasa kanat cirpisi/ciyaklama, cam isiltisi, arcane "zing", yer alti gumburtusu).
DONGU / UZUN ses YOK (bkz. hafiza: yaydaki 9 sn'lik dongu sesi takili ugultu yapmisti) - hepsi 1.5 sn'nin altinda,
basi/sonu fade'li (tik yok), -1 dBFS tepeye normalize, mono 16-bit 44.1 kHz (konumlu AudioStreamPlayer2D icin).
Calma seviyesi player.gd SKILL_SFX tablosunda (_play_networked_sound -> diger oyunculara da gider).

Calistir:  python tools/gen_skill_sounds.py      (sonra Godot: --headless --import ya da editoru ac)
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "Sound FX Starter Pack Vol. 1")
OUT = os.environ.get("SKILL_SFX_OUT") or os.path.join(ROOT, "assets", "audio", "skills")
RNG = np.random.default_rng(20260925)


# ------------------------------------------------------------------ temel araclar
def load(rel, start=0.0, dur=None):
    """Paketteki kaydi mono float olarak okur, [start, start+dur) araligini dondurur."""
    w = wave.open(os.path.join(PACK, rel))
    ch, sw, sr = w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(w.getnframes())
    assert sw == 2, rel
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    x = x.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x)
    a = int(start * SR)
    b = len(x) if dur is None else min(len(x), a + int(dur * SR))
    return x[a:b].copy()


def pitch(x, factor):
    """Hiz/perde degisimi (yeniden ornekleme): factor > 1 tiz ve kisa, < 1 pes ve uzun."""
    idx = np.arange(0, len(x) - 1, factor)
    return np.interp(idx, np.arange(len(x)), x)


def lowpass(x, hz):
    a = (1.0 / SR) / (1.0 / (2 * np.pi * hz) + 1.0 / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x, hz):
    return x - lowpass(x, hz)


def fade(x, fin=0.004, fout=0.12, curve=2.0):
    x = x.copy()
    n_in, n_out = min(len(x), int(fin * SR)), min(len(x), int(fout * SR))
    if n_in > 1:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out > 1:
        x[-n_out:] *= np.linspace(1, 0, n_out) ** curve
    return x


def db(g):
    return 10 ** (g / 20.0)


def mix(dur, layers):
    """layers: [(sinyal, baslangic_sn, kazanc_db)]"""
    out = np.zeros(int(dur * SR))
    for sig, off, g in layers:
        a = int(off * SR)
        n = min(len(sig), len(out) - a)
        if n > 0:
            out[a:a + n] += sig[:n] * db(g)
    return out


def reverb(x, amount=0.22, room=1.0):
    """Hafif oda yankisi: 4 geri beslemeli gecikme (Schroeder benzeri), kuru sinyalle karisir."""
    out = x.copy()
    for d_ms, fb in ((29.7, 0.55), (37.1, 0.5), (41.1, 0.45), (43.7, 0.42)):
        d = int(d_ms * room * SR / 1000)
        buf = np.zeros(len(x) + d * 8)
        buf[:len(x)] = x
        for i in range(d, len(buf)):
            buf[i] += buf[i - d] * fb
        out += buf[:len(x)] * amount * 0.25
    return out


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def env_exp(n, attack=0.003, decay=0.2):
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay, 1e-4))
    a = int(attack * SR)
    if a > 1:
        e[:a] *= np.linspace(0, 1, a)
    return e


def noise(sec):
    return RNG.uniform(-1, 1, int(sec * SR))


def band(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def sine_sweep(f0, f1, sec, curve=1.0):
    t = t_axis(sec)
    f = f0 + (f1 - f0) * (t / sec) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


# ------------------------------------------------------------------ sentez katmanlari
def glass_shimmer(sec=1.0, base=2093.0):
    """Cam/ayna isiltisi: kademeli giren parlak kismi-harmonikler (hafif tremolo)."""
    t = t_axis(sec)
    out = np.zeros_like(t)
    for k, (mult, on, dec) in enumerate(((1.0, 0.0, 0.35), (1.26, 0.06, 0.3), (1.5, 0.12, 0.28), (2.0, 0.18, 0.22),
                                          (2.52, 0.26, 0.2))):
        a = int(on * SR)
        seg = np.sin(2 * np.pi * base * mult * t[:len(t) - a]) * env_exp(len(t) - a, 0.002, dec)
        seg *= 1.0 + 0.15 * np.sin(2 * np.pi * 9.0 * t[:len(t) - a])
        out[a:] += seg * (0.9 ** k)
    return out


def arcane_zing(sec=0.22):
    """Arcane sekme: asagi kayan FM 'zing' + kisa parlak tik."""
    t = t_axis(sec)
    f = 1500.0 * np.exp(-t * 9.0) + 380.0
    mod = np.sin(2 * np.pi * f * 2.01 * t) * 2.2 * np.exp(-t * 14.0)
    car = np.sin(2 * np.pi * np.cumsum(f) / SR + mod)
    click = band(noise(0.02), 2500, 9000) * env_exp(int(0.02 * SR), 0.0005, 0.004)
    return mix(sec, [(car * env_exp(len(t), 0.002, 0.07), 0.0, 0.0), (click, 0.0, -6.0)])


def thump(freq=60.0, sec=0.35, decay=0.09):
    t = t_axis(sec)
    f = freq * (1.0 + 1.2 * np.exp(-t * 30.0))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.002, decay)


def wing_flap(sec=0.07, lo=500.0, hi=2600.0):
    """Tek kanat cirpisi: bant gecirenli gurultu, cok hizli atak, kisa sonum."""
    x = band(noise(sec), lo, hi)
    return x * env_exp(len(x), 0.004, sec * 0.35)


def squeak(f0=6200.0, f1=7600.0, sec=0.035):
    x = sine_sweep(f0, f1, sec, 0.6)
    return x * env_exp(len(x), 0.003, sec * 0.45)


# ------------------------------------------------------------------ yetenek sesleri
def talon_dash():
    """Talon Q - Hamle Vurusu: ileri atilma - agir kilic savurusu + kisa celik cinlamasi."""
    wh = pitch(load("Medieval/Weapon Whoosh.wav", 0.0, 0.55), 0.9)
    tw = load("Medieval/Metal Twang.wav", 0.0, 0.4)
    return fade(mix(0.6, [(wh, 0.0, 0.0), (fade(tw, fout=0.2), 0.03, -12.0)]), fout=0.15)


def talon_salvo():
    """Talon E - Silah Salvosu: silahlar etrafinda donmeye baslar - celik 'shing' + ust uste iki savrulma."""
    sh = load("Medieval/Weapon Upgrade.wav", 0.0, 0.35)
    wh = load("Motions and Impacts/Whoosh Medieval.wav", 0.05, 0.7)
    wh2 = pitch(wh, 1.18)
    return fade(mix(0.95, [(fade(sh, fout=0.15), 0.0, -3.0), (fade(wh, fout=0.25), 0.02, 0.0),
                           (fade(wh2, fout=0.2), 0.2, -5.0)]), fout=0.2)


def talon_mirror():
    """Talon R - Ayna Formu: silahlarin aynali kopyalari belirir - celik parlamasi + cam/ayna isiltisi."""
    sh = load("Medieval/Weapon Upgrade.wav", 0.0, 0.4)
    gl = glass_shimmer(1.1, 1760.0)
    return fade(reverb(mix(1.2, [(fade(sh, fout=0.2), 0.0, -2.0), (gl, 0.05, -9.0)]), 0.3), fout=0.35)


def oakley_vines():
    """Oakley E - Sarmasiklar: topraktan firlayan sarmasiklar - toprak/kok catirtisi (tizler kisik, dogal)."""
    ea = lowpass(load("Magic/Earth Attack.wav", 0.95, 0.95), 4200.0)
    return fade(ea, fin=0.01, fout=0.35)


def oakley_bond():
    """Oakley R - Koruyucu Buyu: dosta koruyucu buyu - yumusak, parlak iyilesme isiltisi."""
    hh = pitch(load("Magic/Holy Healing.wav", 0.05, 1.6), 1.06)
    return fade(hh, fin=0.02, fout=0.5)


def buyucu_arcane_bounce():
    """Buyucu E (Arcane Lanet): HER sekmede calan kisa mor 'zing' (4 kez art arda - kisa ve hafif)."""
    return fade(reverb(arcane_zing(0.26), 0.18, 0.6), fout=0.08)


def sovalye_taunt():
    """Sovalye Q - Kiskirtma: kilicla kalkana iki kez vurup meydan okuma - iki kalkan darbesi + alcak gumleme."""
    b1 = pitch(load("Medieval/Shield Block.wav", 0.0, 0.32), 1.06)
    b2 = pitch(load("Medieval/Shield Block.wav", 0.0, 0.32), 0.94)
    return fade(reverb(mix(0.75, [(b1, 0.0, -3.0), (b2, 0.19, 0.0), (thump(70.0, 0.4, 0.1), 0.19, -8.0)]), 0.2),
                fout=0.2)


def sovalye_barrier():
    """Sovalye E - Koruma Bariyeri: dostlarin etrafinda bariyer kurulur - yukselen koruma alani ugultusu."""
    fa = load("Sci-Fi/Force Armor.wav", 0.15, 1.15)
    return fade(lowpass(fa, 7000.0), fin=0.02, fout=0.35)


def elara_evasion():
    """Elara Q - Sivisma: hafif ve cevik - hizli rüzgar suzulmesi."""
    wh = pitch(load("Medieval/Weapon Whoosh.wav", 0.0, 0.5), 1.25)
    air = load("Magic/Air Attack.wav", 0.3, 0.6)
    return fade(mix(0.65, [(wh, 0.0, -2.0), (fade(air, 0.05, 0.3), 0.04, -6.0)]), fout=0.2)


def korsan_bomb_place():
    """Korsan E - Saatli Bomba: bomba birakilir - fitil tutusma cizirtisi."""
    ig = load("Steampunk/Steampunk Gas Ignite.wav", 0.0, 0.65)
    return fade(highpass(ig, 300.0), fout=0.25)


def korsan_bombardment_strike():
    """Korsan R - Bombardiman: HER top gulleesi isabeti - kisa, tok patlama (cok kez calar: kuyrugu kisa)."""
    mb = load("Hollywood/Mega Bomb.wav", 0.0, 1.1)
    return fade(lowpass(mb, 6000.0), fout=0.55, curve=2.4)


def melek_fear():
    """Melek R - Kutsal Korku: dusmanlari korkutan kutsal patlama - parlak kutsal vurus + alcak buyu muhru."""
    hm = load("Magic/Holy Missile.wav", 0.0, 1.35)
    ms = lowpass(load("Magic/Magic Seal.wav", 0.0, 1.35), 2500.0)
    return fade(mix(1.4, [(hm, 0.0, 0.0), (ms, 0.0, -5.0)]), fout=0.45)


def necro_skeleton():
    """Necromancer Q - Iskelet Cagir: karanlik cagri + kemik takirtisi."""
    na = load("Magic/Necromantic Attack.wav", 0.0, 0.95)
    ab = pitch(load("Community Requests/Abacus.wav", 0.03, 0.4), 0.72)
    return fade(mix(1.05, [(fade(na, fout=0.35), 0.0, -2.0), (fade(ab, fout=0.1), 0.22, -3.0),
                           (fade(pitch(ab, 1.1), fout=0.1), 0.42, -6.0)]), fout=0.25)


def necro_golem():
    """Necromancer E - Golem Cagir: yer sarsilir, agir tas golem dogrulur - gumburtu + agir darbe + alt bas."""
    rumble = lowpass(load("Hollywood/Earthquake Loop.wav", 0.4, 1.2), 420.0)
    hit = pitch(load("Community Requests/Hammer Fall.wav", 0.0, 0.7), 0.62)
    return fade(mix(1.25, [(fade(rumble, 0.15, 0.4), 0.0, 0.0), (fade(hit, fout=0.3), 0.18, -1.0),
                           (thump(48.0, 0.6, 0.18), 0.2, -4.0)]), fin=0.02, fout=0.3)


def necro_skull():
    """Necromancer R - Lanetli Kafatasi: kafatasi firlatilir - hayaletimsi ugultulu savrulma + karanlik yarik."""
    wr = load("Horror/Wind Of Rotting.wav", 1.2, 1.1)
    rr = load("Horror/Reality Rift.wav", 0.0, 0.5)
    return fade(mix(1.2, [(fade(rr, fout=0.25), 0.0, -5.0), (fade(wr, 0.08, 0.4), 0.02, 0.0)]), fout=0.3)


def vampir_drain():
    """Vampir Q - Kan Emme: islak emme + iki alcak kalp atisi."""
    gore = band(load("Horror/Gore And Larvae Loop.wav", 2.0, 0.6), 150.0, 5000.0)
    suck = lowpass(load("Magic/Necromantic Healing.wav", 0.05, 0.7), 2000.0)
    return fade(mix(0.95, [(fade(gore, 0.03, 0.25), 0.0, 0.0), (fade(suck, 0.05, 0.3), 0.0, -8.0),
                           (thump(58.0, 0.25, 0.07), 0.36, -10.0), (thump(55.0, 0.25, 0.07), 0.56, -12.0)]), fout=0.2)


def vampir_bat_form():
    """Vampir E - Yarasa Formu: karanlik 'puf' donusum + birkac kanat cirpisi ve ciyaklama."""
    rr = lowpass(load("Horror/Reality Rift.wav", 0.0, 0.45), 3500.0)
    layers = [(fade(rr, fout=0.25), 0.0, -3.0)]
    for i, tt in enumerate((0.12, 0.23, 0.33, 0.42, 0.5)):
        layers.append((wing_flap(0.07, 450.0, 2400.0), tt, -4.0 - i * 1.6))
    layers.append((squeak(6400.0, 7800.0), 0.2, -14.0))
    layers.append((squeak(5600.0, 7000.0), 0.38, -17.0))
    return fade(mix(0.75, layers), fout=0.2)


def vampir_bats():
    """Vampir R - Kan Yarasalari: yarasa surusu salinir - ust uste binen kanat cirpislari + tiz ciyaklamalar."""
    layers = []
    for i in range(14):
        tt = 0.02 + i * 0.065 + RNG.uniform(-0.015, 0.015)
        layers.append((wing_flap(RNG.uniform(0.05, 0.08), RNG.uniform(380, 600), RNG.uniform(2000, 3000)), tt,
                       -3.0 - 6.0 * (i / 14.0) + RNG.uniform(-2, 1)))
    for i in range(6):
        f0 = RNG.uniform(5200, 7200)
        layers.append((squeak(f0, f0 * RNG.uniform(1.1, 1.3), RNG.uniform(0.025, 0.045)), RNG.uniform(0.05, 0.8),
                       RNG.uniform(-18, -13)))
    return fade(mix(1.1, layers), fout=0.3)


SOUNDS = [
    ("talon_dash", talon_dash), ("talon_salvo", talon_salvo), ("talon_mirror", talon_mirror),
    ("oakley_vines", oakley_vines), ("oakley_bond", oakley_bond), ("buyucu_arcane_bounce", buyucu_arcane_bounce),
    ("sovalye_taunt", sovalye_taunt), ("sovalye_barrier", sovalye_barrier), ("elara_evasion", elara_evasion),
    ("korsan_bomb_place", korsan_bomb_place), ("korsan_bombardment_strike", korsan_bombardment_strike),
    ("melek_fear", melek_fear), ("necro_skeleton", necro_skeleton), ("necro_golem", necro_golem),
    ("necro_skull", necro_skull), ("vampir_drain", vampir_drain), ("vampir_bat_form", vampir_bat_form),
    ("vampir_bats", vampir_bats),
]


def save(name, x, peak_db=-1.0):
    ## DC kaymasi yuksek geciren filtreyle alinir (ortalamayi CIKARMAK fade'lenmis uclara sabit bir kayma ekleyip tik
    ## yapiyordu), sonra uclar yeniden kisa fade'le sifira indirilir.
    x = fade(highpass(x, 25.0), 0.003, 0.012, 1.0)
    pk = np.max(np.abs(x)) or 1.0
    x = x / pk * db(peak_db)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    print("   %-28s %.2f sn  RMS %.1f dB" % (name + ".wav", len(x) / SR, rms))


if __name__ == "__main__":
    for nm, fn in SOUNDS:
        save(nm, fn())
