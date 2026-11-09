"""Tanıtım videolarının senaryosu (kurgu.py okur). Her video = bölüm listesi.
Bölüm: src=(plan, çekim), at=çekim başından (rel="cast": yeteneğe basılan kareden) saniye, dur=süre, speed<1 yavaş çekim,
flash=beyaz parlamayla aç, style=story/big/name/tier, cap={"tr": [...], "en": [...]}, cap_in<0 = yazı solmadan hazır gelir.
Kapanış kartı: bg=(plan, çekim), dur, sound (assets/audio altı).
"""

HERO = {  # id: (tr ad, en ad, tr R, en R)
    1: ("TALON", "TALON", "Ayna Formu", "Mirror Form"),
    2: ("OAKLEY", "OAKLEY", "Hayat Ağacı", "Tree of Life"),
    3: ("MATTHEW", "MATTHEW", "Yıldırım Kalkanı", "Thunder Shield"),
    4: ("BÜYÜCÜ KIZ", "SORCERESS", "Don Nova", "Frost Nova"),
    5: ("ASSASİN", "ASSASSIN", "Gölge Hücumu", "Shadow Assault"),
    7: ("ŞÖVALYE", "KNIGHT", "Koruma Baloncuğu", "Guardian Bubble"),
    8: ("ELARA", "ELARA", "Çift Tetik", "Double Trigger"),
    9: ("KORSAN", "PIRATE", "Bombardıman", "Bombardment"),
    10: ("MELEK", "ANGEL", "Kutsal Korku", "Holy Dread"),
    11: ("NECROMANCER", "NECROMANCER", "Lanetli Kafatası", "Cursed Skull"),
    12: ("SHAMAN", "SHAMAN", "Elemental Golem", "Elemental Golem"),
    13: ("VAMPİR", "VAMPIRE KID", "Kan Yarasaları", "Blood Bats"),
    14: ("HADİME", "HADIME", "Karabasan", "Nightmare"),
    15: ("CADI", "WITCH", "İksir Çantası", "Potion Bag"),
}

BOSS = {  # çekim: (tr ad, en ad, kademe)
    "minotaur1": ("MİNOTAUR", "MINOTAUR", 3),
    "underground1": ("YERALTI CANAVARI", "UNDERWORLD BEAST", 5),
    "balkabagi1": ("BALKABAĞI KAFA", "PUMPKIN HEAD", 8),
    "wendigo1": ("WENDIGO", "WENDIGO", 12),
    "banshee1": ("BANSHEE", "BANSHEE", 15),
    "ucansetan1": ("UÇAN ŞEYTAN", "FLYING DEMON", "FİNAL"),
}

ROMAN = {1: "I", 5: "V", 10: "X", 15: "XV"}

## Tek tek ayarlanan çekim zamanları (bak_*.jpg sayfalarına göre). at = R'ye basıldıktan sonra kaçıncı saniyeden başlar.
HERO_AT = {1: 0.3, 2: 1.6, 3: -0.1, 4: 0.0, 5: 0.3, 7: 0.2, 8: 0.4, 9: 0.4, 10: -0.1, 11: 0.4, 12: 0.3, 13: 0.6, 14: 0.3, 15: 1.6}
HERO_ORDER = [7, 5, 2, 4, 3, 10, 12, 15, 13, 1, 9, 8, 11, 14]
MONTAGE = [(5, 0.3), (7, 0.3), (2, 2.0), (4, 0.0)]
BOSS_AT = {"minotaur1": 1.0, "underground1": 3.0, "balkabagi1": 1.8, "wendigo1": 4.6, "banshee1": 2.4, "ucansetan1": 4.5}


def hero(cid, dur, cap=True, flash=True, at=None, cap_in=0.06):
    tr, en, rtr, ren = HERO[cid]
    s = {"src": ("kahraman", f"c{cid}_skill3"), "rel": "cast", "at": HERO_AT.get(cid, -0.15) if at is None else at,
         "dur": dur, "flash": flash, "style": "name", "cap_in": cap_in}
    if cap:
        s["cap"] = {"tr": [tr, rtr], "en": [en, ren]}
    return s


def boss(bid, dur, at=None, sub=True, flash=True):
    tr, en, k = BOSS[bid]
    s = {"src": ("dunya", "boss_" + bid), "at": BOSS_AT.get(bid, 1.0) if at is None else at, "dur": dur, "flash": flash,
         "style": "name"}
    if sub:
        ktr = "Final bossu" if k == "FİNAL" else f"Kademe {k} bossu"
        ken = "Final boss" if k == "FİNAL" else f"Tier {k} boss"
        s["cap"] = {"tr": [tr, ktr], "en": [en, ken]}
    else:
        s["cap"] = {"tr": [tr], "en": [en]}
    return s


def end(bg=("dunya", "kalabalik_gece"), at=3.0, dur=3.2):
    return {"bg": bg, "at": at, "dur": dur, "sound": "başlangıç sesi.mp3", "sound_gain": 0.9}


def coop(at, dur, tr, en, sub_tr="", sub_en=""):
    """Gerçek 4 oyunculu çekim (tools/tanitim/coop.ps1). Takılmalar ~6,2 ve 11,8-12,5 sn: pencereler onlardan kaçar."""
    return {"src": ("coop", "coop"), "at": at, "dur": dur, "flash": True, "style": "tier",
            "cap": {"tr": [tr] + ([sub_tr] if sub_tr else []), "en": [en] + ([sub_en] if sub_en else [])}}


def _fragman():
    seq = [
        {"src": ("dunya", "ev_huzur"), "at": 0.3, "dur": 2.6, "cap": {"tr": ["Her şey çok sakindi..."], "en": ["It was a quiet night..."]},
         "fadein": 0.3, "mask_bottom": 1480},
        {"src": ("dunya", "ev_deprem"), "at": 0.3, "dur": 2.4, "cap": {"tr": ["...ta ki yer", "sallanana kadar."], "en": ["...until the", "ground shook."]},
         "mask_bottom": 1480},
        {"src": ("dunya", "kademe_15"), "at": 1.6, "dur": 2.2, "flash": True, "style": "big", "cap": {"tr": ["ONLAR GELDİ"], "en": ["THEY'RE HERE"]}},
        {"src": ("dunya", "kalabalik_gece"), "at": 1.0, "dur": 2.2, "flash": True, "style": "big", "cap": {"tr": ["HAYATTA KAL"], "en": ["STAY ALIVE"]}},
        coop(8.3, 2.6, "ARKADAŞLARINLA", "WITH FRIENDS", "8 kişiye kadar co-op", "Co-op for up to 8"),
    ]
    for i, (cid, at) in enumerate(MONTAGE):
        s = hero(cid, 1.3, cap=False, at=at, cap_in=0.06 if i == 0 else -1)
        s["style"] = "big"
        s["cap"] = {"tr": ["14 KAHRAMAN"], "en": ["14 HEROES"]}
        seq.append(s)
    for i, bid in enumerate(["balkabagi1", "wendigo1", "ucansetan1"]):
        s = boss(bid, 1.3)
        s["style"] = "big"
        s["cap"] = {"tr": ["DEV BOSSLAR"], "en": ["GIANT BOSSES"]}
        s["cap_in"] = 0.06 if i == 0 else -1
        seq.append(s)
    seq.append({"src": ("dunya", "kalabalik_gece"), "at": 4.4, "dur": 2.4, "flash": True,
                "cap": {"tr": ["Kaç kademe", "dayanabilirsin?"], "en": ["How long can", "you survive?"]}})
    seq.append(end())
    return seq


def _kahramanlar():
    seq = [{"src": ("dunya", "kalabalik_aksam"), "at": 4.2, "dur": 1.8, "style": "big",
            "cap": {"tr": ["14 KAHRAMAN", "HANGİSİ SENSİN?"], "en": ["14 HEROES", "WHICH ONE ARE YOU?"]}}]
    for cid in HERO_ORDER:
        seq.append(hero(cid, 1.65))
    seq.append(coop(0.6, 2.4, "EKİBİNİ KUR", "BUILD YOUR TEAM"))  ## alt yazı kapanış kartında ("8 kişiye kadar co-op")
    seq.append(end(("dunya", "kalabalik_aksam"), 2.0))
    return seq


def _kademeler():
    seq = []
    subs = {1: ("Başta kolay...", "Easy at first..."), 5: ("", ""), 10: ("", ""), 15: ("Sonra cehennem.", "Then it's hell.")}
    for k, dur, at in [(1, 2.0, 1.4), (5, 1.8, 2.0), (10, 1.8, 0.4), (15, 2.6, 1.4)]:
        tr, en = subs[k]
        cap = {"tr": [f"KADEME {ROMAN[k]}"] + ([tr] if tr else []), "en": [f"TIER {ROMAN[k]}"] + ([en] if en else [])}
        seq.append({"src": ("dunya", f"kademe_{k:02d}"), "at": at, "dur": dur, "style": "tier", "cap": cap, "flash": k != 1})
    for bid in ["minotaur1", "underground1", "balkabagi1", "wendigo1", "banshee1", "ucansetan1"]:
        seq.append(boss(bid, 1.7))
    seq.append(coop(3.4, 2.4, "YALNIZ DEĞİLSİN", "YOU'RE NOT ALONE"))
    seq.append(end(("dunya", "kademe_15"), 3.0))
    return seq


SHORTS = {
    "fragman": _fragman(),
    "kahramanlar": _kahramanlar(),
    "kademeler": _kademeler(),
}
