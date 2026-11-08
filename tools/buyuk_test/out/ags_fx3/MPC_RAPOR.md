# MP savas gorsel karmasa raporu: ags_fx3 (taban: ags_fx_solo)

## 1. Ekrandaki ogeler (ortalama, t=8-68 sn)

| oge | MP | tek oyunculu | fark |
|---|---|---|---|
| players | 3.0 | 1.0 | +2.0 |
| yaratiklar | 63.1 | 55.2 | +7.8 |
| yaratik saldirilari/efektleri | 6.6 | 6.1 | +0.5 |
| kendi silahlarim | 3.0 | 3.0 | +0.0 |
| DIGER oyuncularin silahlari | 5.9 | 0.0 | +5.9 |
| mermiler/isinlar | 1.1 | 1.0 | +0.1 |
| oyuncu yetenek + silah efektleri | 23.9 | 24.3 | -0.4 |
| hasar/altin yazilari | 4.1 | 5.7 | -1.6 |
| yer lekeleri (kan/catlak) | 2.2 | 2.2 | +0.0 |
| yerdeki esyalar (XP/altin/...) | 0.6 | 0.9 | -0.3 |
| can/kalkan cubuklari + durum ikonlari | 3.1 | 1.0 | +2.1 |
| evcil hayvanlar | 0.0 | 0.0 | +0.0 |
| cagrilanlar | 0.0 | 0.0 | +0.0 |
| draws | 705.1 | 524.1 | +181.0 |
| objs | 16006.8 | 12700.2 | +3306.6 |

Gorunen toplam 'oge' (yaratik + oyuncu haric): MP 51 / tek 44

## 2. Yanip sonme / hareket (10 sn, ~20 Hz ornek)

| olcu | MP | tek |
|---|---|---|
| lum_mean | 111.100 | 101.300 |
| lum_std | 1.290 | 1.360 |
| lum_jump_mean | 0.850 | 0.560 |
| lum_jump_p95 | 2.460 | 1.640 |
| diff_mean | 14.290 | 11.120 |
| diff_hi_frac | 0.122 | 0.091 |
| sat_frac | 0.041 | 0.021 |

(lum_jump = ardisik orneklerde ortalama isik farki; diff_hi_frac = karede ani degisen piksel orani; sat_frac = doygun renk orani)

## 3. Kategori katkisi (ablation, 4 an ortalamasi)

### MP (ags_fx3)

kenar yogunlugu: tum kare 16.46 | efektsiz 16.52 | bos dunya 12.58 ; doygun piksel: 0.036 -> 0.024 ; ekranin degisen alani: efektler 7.6%, hepsi 12.4%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 29.65 | 1.825 | 0.0057 | 0.0011 |
| yaratiklar | 9.37 | 2.721 | 0.0091 | 0.0069 |
| oyuncu yetenek + silah efektleri | 6.62 | -0.066 | 0.0102 | -0.0092 |
| mermiler/isinlar | 4.72 | -0.584 | -0.0012 | -0.0189 |
| yaratik saldirilari/efektleri | 4.57 | -0.519 | -0.0006 | -0.0179 |
| DIGER oyuncularin silahlari | 3.50 | -0.412 | -0.0008 | -0.0155 |
| kendi silahlarim | 2.39 | -0.266 | -0.0006 | -0.0069 |
| can/kalkan cubuklari + durum ikonlari | 1.95 | -0.116 | -0.0006 | -0.0052 |
| hasar/altin yazilari | 0.98 | -0.043 | -0.0008 | -0.0016 |

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
enemy:enemy=41 enemy:worm_limb=9 hud:CanvasLayer=5 weapons_puppet:Sprite2D=5 numbers:floating_text=3 player_fx:mana_shield_fx=3 bars:overhead_bar=3 weapons_own:weapon=3 player_fx:fx_enchant_sprite=2 players:remote_player=2 player_fx:melek_halo_fx=2 enemy_fx:enemy_projectile=2 hud:sun_clouds=1 hud:atmosphere_overlay=1 hud:vision_fog=1 hud:hud=1 players:player=1 weapons_puppet:AnimatedSprite2D=1 hud:downed_spectate=1 enemy:underground_boss=1 enemy_fx:creature_depth=1 enemy_fx:enemy_world_bridge=1 player_fx:water_fx=1 player_fx:fx_oneshot_sprite=1 player_fx:fx_melek_ascend=1 player_fx:melek_bond_fx=1 player_fx:fx_mage_swap=1 player_fx:gun_reload_fx=1 player_fx:dome_weapon_ring=1 player_fx:totem_shield=1 player_fx:totem_attack=1 player_fx:fx_animation_sequence=1
```

- kategori haritasi: kategori_haritasi_m1.jpg
- kategori haritasi: kategori_haritasi_m2.jpg