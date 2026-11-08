# MP savas gorsel karmasa raporu: ags_fx_az (taban: ags_fx_solo)

## 1. Ekrandaki ogeler (ortalama, t=8-68 sn)

| oge | MP | tek oyunculu | fark |
|---|---|---|---|
| players | 2.9 | 1.0 | +1.9 |
| yaratiklar | 62.6 | 55.2 | +7.3 |
| yaratik saldirilari/efektleri | 14.5 | 6.1 | +8.3 |
| kendi silahlarim | 3.0 | 3.0 | +0.0 |
| DIGER oyuncularin silahlari | 5.5 | 0.0 | +5.5 |
| mermiler/isinlar | 1.0 | 1.0 | +0.1 |
| oyuncu yetenek + silah efektleri | 25.5 | 24.3 | +1.2 |
| hasar/altin yazilari | 4.7 | 5.7 | -1.0 |
| yer lekeleri (kan/catlak) | 2.2 | 2.2 | +0.0 |
| yerdeki esyalar (XP/altin/...) | 5.0 | 0.9 | +4.0 |
| can/kalkan cubuklari + durum ikonlari | 3.0 | 1.0 | +2.0 |
| evcil hayvanlar | 0.0 | 0.0 | +0.0 |
| cagrilanlar | 0.0 | 0.0 | +0.0 |
| draws | 709.6 | 524.1 | +185.5 |
| objs | 16546.6 | 12700.2 | +3846.4 |

Gorunen toplam 'oge' (yaratik + oyuncu haric): MP 64 / tek 44

## 2. Yanip sonme / hareket (10 sn, ~20 Hz ornek)

| olcu | MP | tek |
|---|---|---|
| lum_mean | 109.300 | 101.300 |
| lum_std | 1.150 | 1.360 |
| lum_jump_mean | 0.780 | 0.560 |
| lum_jump_p95 | 2.180 | 1.640 |
| diff_mean | 13.690 | 11.120 |
| diff_hi_frac | 0.115 | 0.091 |
| sat_frac | 0.040 | 0.021 |

(lum_jump = ardisik orneklerde ortalama isik farki; diff_hi_frac = karede ani degisen piksel orani; sat_frac = doygun renk orani)

## 3. Kategori katkisi (ablation, 4 an ortalamasi)

### MP (ags_fx_az)

kenar yogunlugu: tum kare 16.01 | efektsiz 15.94 | bos dunya 12.64 ; doygun piksel: 0.039 -> 0.028 ; ekranin degisen alani: efektler 7.6%, hepsi 11.1%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 32.84 | 2.089 | 0.0063 | -0.0028 |
| yaratiklar | 8.67 | 2.287 | 0.0102 | 0.0032 |
| oyuncu yetenek + silah efektleri | 6.95 | -0.077 | 0.0097 | -0.0111 |
| yaratik saldirilari/efektleri | 5.31 | -0.315 | 0.0017 | -0.0180 |
| mermiler/isinlar | 4.56 | -0.505 | -0.0008 | -0.0111 |
| DIGER oyuncularin silahlari | 4.11 | -0.408 | 0.0002 | -0.0121 |
| kendi silahlarim | 3.91 | -0.400 | 0.0003 | -0.0122 |
| can/kalkan cubuklari + durum ikonlari | 3.06 | -0.244 | 0.0003 | -0.0086 |
| yer lekeleri (kan/catlak) | 2.95 | -0.344 | -0.0002 | -0.0065 |
| yerdeki esyalar (XP/altin/...) | 2.58 | -0.169 | 0.0003 | -0.0079 |
| hasar/altin yazilari | 1.71 | -0.076 | 0.0003 | -0.0050 |

### TEK (ags_fx_solo)

kenar yogunlugu: tum kare 14.40 | efektsiz 14.17 | bos dunya 11.46 ; doygun piksel: 0.014 -> 0.013 ; ekranin degisen alani: efektler 0.7%, hepsi 7.9%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 47.77 | 1.311 | 0.0054 | 0.0012 |
| yaratiklar | 7.15 | 2.457 | 0.0001 | 0.0012 |
| yaratik saldirilari/efektleri | 0.38 | 0.043 | 0.0004 | 0.0001 |
| oyuncu yetenek + silah efektleri | 0.29 | 0.099 | -0.0000 | 0.0001 |
| mermiler/isinlar | 0.15 | 0.048 | 0.0001 | 0.0001 |
| kendi silahlarim | 0.12 | 0.016 | -0.0000 | -0.0000 |
| can/kalkan cubuklari + durum ikonlari | 0.06 | 0.026 | 0.0000 | 0.0000 |
| hasar/altin yazilari | 0.05 | 0.022 | -0.0000 | 0.0000 |
| yer lekeleri (kan/catlak) | 0.04 | 0.007 | 0.0000 | 0.0001 |
| yerdeki esyalar (XP/altin/...) | 0.02 | 0.012 | 0.0001 | 0.0000 |

## 4. Envanter (MP, 3. an) - kategori:betik=adet

```
enemy:enemy=46 enemy:worm_limb=6 weapons_puppet:Sprite2D=5 hud:CanvasLayer=5 player_fx:fx_enchant_sprite=5 drops:xp_orb=3 player_fx:mana_shield_fx=3 bars:overhead_bar=3 weapons_own:weapon=3 drops:gold_drop=2 player_fx:melek_halo_fx=2 players:remote_player=2 weapons_puppet:AnimatedSprite2D=1 players:player=1 hud:sun_clouds=1 hud:atmosphere_overlay=1 hud:vision_fog=1 hud:hud=1 player_fx:fx_animation_sequence=1 hud:downed_spectate=1 enemy:underground_boss=1 player_fx:totem_attack=1 player_fx:totem_shield=1 enemy_fx:creature_depth=1 enemy_fx:enemy_world_bridge=1 enemy_fx:enemy_projectile=1 player_fx:water_fx=1 player_fx:fx_mage_swap=1 player_fx:gun_reload_fx=1 player_fx:fx_melek_ascend=1 player_fx:dome_weapon_ring=1
```

- kategori haritasi: kategori_haritasi_m1.jpg
- kategori haritasi: kategori_haritasi_m2.jpg