# Buyuk test raporu (tam1)

## ISARETLENENLER (21)
- wt arcane: t5/t1 sapma 2.49
- wt boomerang: t5/t1 sapma 0.73; t5 < t1 !
- wt fire_staff: t5/t1 sapma 2.97
- wt fisek: t5/t1 sapma 3.54
- wt kalkan: t5/t1 sapma 2.74
- wt lightning_staff: t5/t1 sapma 4.70
- wt mizrak: t5/t1 sapma 2.47
- wt topuz: t5/t1 sapma 1.00; t5 < t1 !
- wt yay: t5/t1 sapma 3.29
- ch Buyucu Kiz skill2: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Buyucu Kiz skill3: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Assasin skill: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Korsan skill: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Korsan skill2: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Necromancer skill: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Necromancer skill2: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Shaman skill: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Vampir skill3: basinca durum 'ready' kaldi (ready>ready>ready)
- ch Cadi skill3: basinca durum 'ready' kaldi (ready>ready>ready)
- motor hatasi x1682: SCRIPT ERROR: Invalid type in function 'caster_disabled' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the 
- motor hatasi x4: WARNING: Camera2D overridden to physics process mode due to use of physics interpolation. | at: _update_process_callback (scene/2d/camera_2d.cpp:88)

## 1. Veri tutarliligi (data)

Isaretlenen: 7  | bilgi: 87

- char=2 Oakley eksik klip: sit_down,sit_left,sit_right,sit_up
- char=2 Oakley skill2 metin '16 sn bekleme' <-> kod cooldown=15.0 (id 10)
- char=4 Büyücü Kız skill3 id=24 zamanlama tablosunda YOK (SKILL3_TIMING)
- char=5 Assasin Çocuk skill id=5 zamanlama tablosunda YOK (SKILL_TIMING)
- char=5 Assasin Çocuk eksik: skill3_icon
- char=9 Korsan skill2 id=17 zamanlama tablosunda YOK (SKILL2_TIMING)
- char=11 Necromancer skill id=19 zamanlama tablosunda YOK (SKILL_TIMING)

Motor hata/uyari (data): 0, gecersiz UID uyarisi: 8


## 2. Silah x kademe (wt)

Yapilandirma: 114 / 114

| silah | t1 | t2 | t3 | t4 | t5 | t6(+5) | t5/t1 | not |
|---|---|---|---|---|---|---|---|---|
| arcane | 21 | 28 | 27 | 29 | 53 | 73 | 2.49 | t5/t1 sapma 2.49 |
| boomerang | 39 | 12 | 27 | 29 | 28 | 84 | 0.73 | t5/t1 sapma 0.73; t5 < t1 ! |
| buz_asasi | 15 | 18 | 20 | 24 | 23 | 48 | 1.59 |  |
| crossbow | 18 | 20 | 27 | 30 | 32 | 61 | 1.75 |  |
| dagger | 27 | 40 | 41 | 44 | 52 | 87 | 1.93 |  |
| fire_staff | 21 | 44 | 54 | 29 | 61 | 74 | 2.97 | t5/t1 sapma 2.97 |
| fisek | 10 | 21 | 26 | 19 | 34 | 48 | 3.54 | t5/t1 sapma 3.54 |
| gokkusagi | 53 | 61 | 73 | 93 | 104 | 184 | 1.96 |  |
| kalkan | 17 | 25 | 28 | 39 | 47 | 128 | 2.74 | t5/t1 sapma 2.74 |
| lightning_staff | 38 | 47 | 59 | 90 | 178 | 344 | 4.70 | t5/t1 sapma 4.70 |
| mizrak | 17 | 32 | 31 | 34 | 41 | 63 | 2.47 | t5/t1 sapma 2.47 |
| pence | 37 | 51 | 49 | 52 | 69 | 110 | 1.88 |  |
| tabanca | 26 | 29 | 32 | 38 | 44 | 60 | 1.68 |  |
| topuz | 59 | 52 | 45 | 76 | 59 | 265 | 1.00 | t5/t1 sapma 1.00; t5 < t1 ! |
| tufek | 29 | 37 | 35 | 38 | 52 | 77 | 1.75 |  |
| tuftuf | 24 | 27 | 34 | 32 | 34 | 59 | 1.42 |  |
| uzunkilic | 24 | 28 | 40 | 50 | 48 | 80 | 2.06 |  |
| yay | 24 | 30 | 28 | 30 | 77 | 67 | 3.29 | t5/t1 sapma 3.29 |
| yinyang | 20 | 22 | 26 | 27 | 39 | 50 | 1.93 |  |

Motor hata/uyari (wt): 1 (gecersiz UID: 13)

Kare suresi (p95 ortanca 8.09 ms) - sapmalar: fisek t2 p95=10.3 max=49


## 3. Karakter yetenekleri (ch)

| karakter | slot | durum gecisi | bekleme | dps | taban dps | fark | kare p95 |
|---|---|---|---|---|---|---|---|
| Talon | skill | ready>active>cooldown | 0.3 | 195 | 63 | +132 | 8.4 |
| Talon | skill2 | ready>active>cooldown | 3.0 | 78 | 63 | +15 | 10.0 |
| Talon | skill3 | ready>active>active | 15.0 | 119 | 63 | +56 | 7.9 |
| Oakley | skill | ready>active>active | 10.0 | 31 | 55 | -25 | 11.7 |
| Oakley | skill2 | ready>active>active | 6.0 | 65 | 55 | +9 | 10.6 |
| Oakley | skill3 | ready>active>active | 11.9 | 44 | 55 | -12 | 8.0 |
| Matthew | skill | ready>active>cooldown | 0.3 | 83 | 55 | +28 | 7.7 |
| Matthew | skill2 | ready>active>cooldown | 3.0 | 6 | 55 | -49 | 8.1 |
| Matthew | skill3 | ready>active>active | 15.0 | 29 | 55 | -26 | 10.7 |
| Buyucu Kiz | skill | ready>active>ready | 0.2 | 48 | 59 | -11 | 11.1 |
| Buyucu Kiz | skill2 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 118 | 59 | +60 | 8.3 |
| Buyucu Kiz | skill3 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 166 | 59 | +108 | 7.8 |
| Assasin | skill | ready>ready>ready DURUM DEGISMEDI | 0.0 | 128 | 72 | +57 | 10.1 |
| Assasin | skill2 | ready>active>active | 6.0 | 93 | 72 | +21 | 9.6 |
| Assasin | skill3 | ready>active>active | 10.0 | 583 | 72 | +512 | 11.1 |
| Sovalye | skill | ready>active>active | 6.0 | 20 | 33 | -13 | 6.8 |
| Sovalye | skill2 | ready>active>active | 15.0 | 26 | 33 | -7 | 10.5 |
| Sovalye | skill3 | ready>active>active | 60.0 | 58 | 33 | +24 | 8.5 |
| Elara | skill | ready>active>cooldown | 3.0 | 64 | 54 | +10 | 7.6 |
| Elara | skill2 | ready>active>active | 6.0 | 72 | 54 | +18 | 8.2 |
| Elara | skill3 | ready>active>active | 15.0 | 85 | 54 | +31 | 8.9 |
| Korsan | skill | ready>ready>ready DURUM DEGISMEDI | 0.0 | 59 | 54 | +5 | 8.3 |
| Korsan | skill2 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 50 | 54 | -4 | 9.0 |
| Korsan | skill3 | ready>active>active | 8.0 | 208 | 54 | +154 | 8.0 |
| Melek | skill | ready>active>active | 6.0 | 63 | 60 | +3 | 10.7 |
| Melek | skill2 | ready>active>active | 6.0 | 32 | 60 | -28 | 9.6 |
| Melek | skill3 | ready>active>cooldown | 2.0 | 5 | 60 | -55 | 9.3 |
| Necromancer | skill | ready>ready>ready DURUM DEGISMEDI | 0.0 | 62 | 54 | +8 | 9.6 |
| Necromancer | skill2 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 46 | 54 | -8 | 8.5 |
| Necromancer | skill3 | ready>active>active | 10.0 | 56 | 54 | +2 | 10.3 |
| Shaman | skill | ready>ready>ready DURUM DEGISMEDI | 0.0 | 112 | 62 | +50 | 10.1 |
| Shaman | skill2 | ready>cooldown>cooldown | 43.6 | 155 | 62 | +93 | 11.2 |
| Shaman | skill3 | ready>active>active | 20.0 | 98 | 62 | +35 | 13.7 |
| Vampir | skill | ready>active>cooldown | 0.4 | 60 | 71 | -11 | 10.3 |
| Vampir | skill2 | ready>active>active | 5.0 | 0 | 71 | -71 | 7.6 |
| Vampir | skill3 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 50 | 71 | -21 | 8.1 |
| Hadime | skill | ready>active>active | 9999.0 | 126 | 66 | +60 | 9.1 |
| Hadime | skill2 | ready>active>active | 6.0 | 216 | 66 | +150 | 8.3 |
| Hadime | skill3 | ready>active>active | 12.0 | 246 | 66 | +180 | 10.1 |
| Cadi | skill | ready>active>active | 9999.0 | 22 | 60 | -38 | 10.6 |
| Cadi | skill2 | ready>active>active | 8.0 | 29 | 60 | -32 | 8.7 |
| Cadi | skill3 | ready>ready>ready DURUM DEGISMEDI | 0.0 | 29 | 60 | -32 | 9.2 |

Motor hata/uyari (ch): 1 (UID: 13)


## 4. Kademe kalabaligi (crowd)

| kademe | yakin | dugum | mean | p95 | max |
|---|---|---|---|---|---|
| 1 | 70 | 2682 | 7.9 | 13.8 | 23 |
| 2 | 70 | 2733 | 8.2 | 13.9 | 26 |
| 3 | 69 | 2808 | 8.7 | 17.9 | 34 |
| K3 BOSS ["minotaur1"] | boss_nodes=1 | | 8.0 | 12.5 | 38 |
| 4 | 70 | 2850 | 8.7 | 15.4 | 30 |
| 5 | 70 | 2811 | 8.3 | 12.6 | 23 |
| K5 BOSS ["underground1"] | boss_nodes=1 | | 9.7 | 19.5 | 30 |
| 6 | 70 | 2831 | 9.2 | 16.7 | 56 |
| 7 | 73 | 2987 | 10.0 | 19.2 | 34 |
| 8 | 70 | 2864 | 9.0 | 15.2 | 26 |
| K8 BOSS ["balkabagi1"] | boss_nodes=1 | | 10.0 | 18.5 | 34 |
| 9 | 70 | 2837 | 9.5 | 17.8 | 39 |
| 10 | 70 | 2816 | 8.7 | 14.0 | 28 |
| 11 | 79 | 2919 | 9.6 | 16.3 | 28 |
| 12 | 70 | 3351 | 9.3 | 17.3 | 29 |
| K12 BOSS ["wendigo1"] | boss_nodes=1 | | 10.0 | 18.5 | 34 |
| 13 | 70 | 2853 | 8.9 | 14.1 | 27 |
| 14 | 70 | 2866 | 9.1 | 16.1 | 30 |
| 15 | 70 | 2869 | 9.5 | 16.1 | 28 |
| K15 BOSS ["banshee1"] | boss_nodes=1 | | 10.9 | 17.5 | 35 |

Motor hata/uyari (crowd): 1683 (UID: 13)


## 5. Karakter x silah (cw), kademe 1

Yapilandirma: 266 / 266. Sapma = karakterin AP'ye bolunmus dps'i, silahin ortanca degerinden <%35 ya da 0.


Motor hata/uyari (cw): 1 (UID: 13)


## 6. Motor hata / uyarilari (tekilleştirilmiş)

- x1682  SCRIPT ERROR: Invalid type in function 'caster_disabled' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class. | at: _process (res://scripts/enemy_thorns.gd:47)  ( crowd:crowd tier 12 roster=["agac2", "bitki3", "golem2", "mantar2"] )
- x4  WARNING: Camera2D overridden to physics process mode due to use of physics interpolation. | at: _update_process_callback (scene/2d/camera_2d.cpp:88)  ( ch:(baslangic); crowd:(baslangic); cw:(baslangic) )

## Gorsel sayfalar

- sayfa_silah_1.jpg
- sayfa_silah_2.jpg
- sayfa_silah_3.jpg
- sayfa_silah_4.jpg
- sayfa_karakter_1.jpg
- sayfa_karakter_2.jpg
- sayfa_karakter_3.jpg
- sayfa_karakter_4.jpg
- sayfa_kalabalik.jpg
- sayfa_boss.jpg
- sayfa_cw_01_Talon.jpg
- sayfa_cw_02_Oakley.jpg
- sayfa_cw_03_Matthew.jpg
- sayfa_cw_04_Buyucu Kiz.jpg
- sayfa_cw_05_Assasin.jpg
- sayfa_cw_07_Sovalye.jpg
- sayfa_cw_08_Elara.jpg
- sayfa_cw_09_Korsan.jpg
- sayfa_cw_10_Melek.jpg
- sayfa_cw_11_Necromancer.jpg
- sayfa_cw_12_Shaman.jpg
- sayfa_cw_13_Vampir.jpg
- sayfa_cw_14_Hadime.jpg
- sayfa_cw_15_Cadi.jpg