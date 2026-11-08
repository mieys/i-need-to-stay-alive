# MP savas gorsel karmasa raporu: ags_den3 (taban: ags_den_solo)

## 1. Ekrandaki ogeler (ortalama, t=8-68 sn)

| oge | MP | tek oyunculu | fark |
|---|---|---|---|
| players | 2.7 | 1.0 | +1.7 |
| yaratiklar | 66.6 | 69.8 | -3.2 |
| yaratik saldirilari/efektleri | 5.3 | 7.8 | -2.5 |
| kendi silahlarim | 3.0 | 3.0 | +0.0 |
| DIGER oyuncularin silahlari | 6.5 | 0.0 | +6.5 |
| mermiler/isinlar | 2.2 | 0.5 | +1.7 |
| oyuncu yetenek + silah efektleri | 14.5 | 4.2 | +10.2 |
| hasar/altin yazilari | 4.3 | 6.9 | -2.7 |
| yer lekeleri (kan/catlak) | 6.6 | 9.2 | -2.6 |
| yerdeki esyalar (XP/altin/...) | 3.0 | 0.2 | +2.8 |
| can/kalkan cubuklari + durum ikonlari | 3.5 | 1.0 | +2.5 |
| evcil hayvanlar | 0.0 | 0.0 | +0.0 |
| cagrilanlar | 0.0 | 0.0 | +0.0 |
| draws | 671.3 | 540.8 | +130.5 |
| objs | 13459.2 | 12701.9 | +757.4 |

Gorunen toplam 'oge' (yaratik + oyuncu haric): MP 49 / tek 33

## 2. Yanip sonme / hareket (10 sn, ~20 Hz ornek)

| olcu | MP | tek |
|---|---|---|
| lum_mean | 112.000 | 102.500 |
| lum_std | 1.430 | 0.510 |
| lum_jump_mean | 0.730 | 0.260 |
| lum_jump_p95 | 1.700 | 0.660 |
| diff_mean | 15.170 | 9.780 |
| diff_hi_frac | 0.131 | 0.079 |
| sat_frac | 0.024 | 0.022 |

(lum_jump = ardisik orneklerde ortalama isik farki; diff_hi_frac = karede ani degisen piksel orani; sat_frac = doygun renk orani)

## 3. Kategori katkisi (ablation, 4 an ortalamasi)

### MP (ags_den3)

kenar yogunlugu: tum kare 17.33 | efektsiz 16.88 | bos dunya 13.11 ; doygun piksel: 0.017 -> 0.016 ; ekranin degisen alani: efektler 8.5%, hepsi 14.0%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 26.69 | 2.422 | 0.0064 | -0.0004 |
| yaratiklar | 9.59 | 2.943 | 0.0011 | 0.0017 |
| oyuncu yetenek + silah efektleri | 7.89 | 0.374 | 0.0001 | -0.0136 |
| yaratik saldirilari/efektleri | 4.44 | 0.006 | 0.0004 | -0.0140 |
| mermiler/isinlar | 3.90 | -0.001 | 0.0004 | -0.0122 |
| DIGER oyuncularin silahlari | 3.87 | 0.039 | 0.0004 | -0.0114 |
| kendi silahlarim | 2.90 | 0.013 | 0.0003 | -0.0063 |
| can/kalkan cubuklari + durum ikonlari | 2.54 | -0.008 | 0.0004 | -0.0049 |
| yer lekeleri (kan/catlak) | 2.29 | -0.012 | 0.0003 | -0.0051 |
| yerdeki esyalar (XP/altin/...) | 1.53 | -0.026 | 0.0002 | -0.0047 |
| hasar/altin yazilari | 1.32 | -0.001 | 0.0002 | -0.0058 |

### TEK (ags_den_solo)

kenar yogunlugu: tum kare 13.48 | efektsiz 13.34 | bos dunya 10.38 ; doygun piksel: 0.014 -> 0.014 ; ekranin degisen alani: efektler 0.5%, hepsi 8.3%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 46.65 | 1.992 | 0.0053 | 0.0019 |
| yaratiklar | 7.87 | 2.770 | 0.0005 | 0.0005 |
| yaratik saldirilari/efektleri | 0.39 | 0.108 | 0.0001 | 0.0001 |
| kendi silahlarim | 0.32 | 0.058 | -0.0000 | 0.0000 |
| oyuncu yetenek + silah efektleri | 0.30 | 0.038 | 0.0000 | 0.0001 |
| yer lekeleri (kan/catlak) | 0.24 | 0.032 | -0.0000 | 0.0000 |
| can/kalkan cubuklari + durum ikonlari | 0.23 | 0.038 | 0.0000 | 0.0000 |
| hasar/altin yazilari | 0.19 | 0.013 | -0.0000 | 0.0000 |
| yerdeki esyalar (XP/altin/...) | 0.13 | 0.005 | 0.0000 | -0.0000 |

## 4. Envanter (MP, 3. an) - kategori:betik=adet

```
enemy:enemy=58 enemy:worm_limb=10 weapons_puppet:Sprite2D=7 projectile:projectile=5 hud:CanvasLayer=5 weapons_own:weapon=3 bars:overhead_bar=3 decal:fx_hit_blood=3 projectile:yinyang_projectile=3 player_fx:mana_shield_fx=2 enemy_fx:enemy_projectile=2 player_fx:yinyang_light=2 players:remote_player=2 drops:gold_drop=1 drops:xp_orb=1 player_fx:dome_weapon_ring=1 players:player=1 hud:sun_clouds=1 hud:atmosphere_overlay=1 hud:vision_fog=1 hud:hud=1 player_fx:fx_talon_form=1 hud:downed_spectate=1 enemy:underground_boss=1 player_fx:fx_paladin_barrier=1 player_fx:fx_sovalye_guard=1 enemy_fx:creature_depth=1 enemy_fx:enemy_world_bridge=1 player_fx:water_fx=1 player_fx:fx_paladin_barrier_link=1
```

- kategori haritasi: kategori_haritasi_m1.jpg
- kategori haritasi: kategori_haritasi_m2.jpg