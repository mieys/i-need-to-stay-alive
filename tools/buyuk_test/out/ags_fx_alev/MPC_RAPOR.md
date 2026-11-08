# MP savas gorsel karmasa raporu: ags_fx_alev (taban: ags_fx_solo)

## 1. Ekrandaki ogeler (ortalama, t=8-68 sn)

| oge | MP | tek oyunculu | fark |
|---|---|---|---|
| players | 2.9 | 1.0 | +1.9 |
| yaratiklar | 62.4 | 55.2 | +7.1 |
| yaratik saldirilari/efektleri | 26.6 | 6.1 | +20.5 |
| kendi silahlarim | 3.0 | 3.0 | +0.0 |
| DIGER oyuncularin silahlari | 5.6 | 0.0 | +5.6 |
| mermiler/isinlar | 1.1 | 1.0 | +0.1 |
| oyuncu yetenek + silah efektleri | 24.4 | 24.3 | +0.1 |
| hasar/altin yazilari | 4.5 | 5.7 | -1.1 |
| yer lekeleri (kan/catlak) | 3.2 | 2.2 | +1.0 |
| yerdeki esyalar (XP/altin/...) | 0.6 | 0.9 | -0.3 |
| can/kalkan cubuklari + durum ikonlari | 2.9 | 1.0 | +1.9 |
| evcil hayvanlar | 0.0 | 0.0 | +0.0 |
| cagrilanlar | 0.0 | 0.0 | +0.0 |
| draws | 698.2 | 524.1 | +174.1 |
| objs | 16834.5 | 12700.2 | +4134.3 |

Gorunen toplam 'oge' (yaratik + oyuncu haric): MP 72 / tek 44

## 2. Yanip sonme / hareket (10 sn, ~20 Hz ornek)

| olcu | MP | tek |
|---|---|---|
| lum_mean | 111.300 | 101.300 |
| lum_std | 1.220 | 1.360 |
| lum_jump_mean | 1.130 | 0.560 |
| lum_jump_p95 | 2.810 | 1.640 |
| diff_mean | 16.210 | 11.120 |
| diff_hi_frac | 0.138 | 0.091 |
| sat_frac | 0.035 | 0.021 |

(lum_jump = ardisik orneklerde ortalama isik farki; diff_hi_frac = karede ani degisen piksel orani; sat_frac = doygun renk orani)

## 3. Kategori katkisi (ablation, 4 an ortalamasi)

### MP (ags_fx_alev)

kenar yogunlugu: tum kare 16.89 | efektsiz 16.71 | bos dunya 13.14 ; doygun piksel: 0.031 -> 0.022 ; ekranin degisen alani: efektler 8.3%, hepsi 12.0%

| kategori | ekran alani %% | kenar katkisi | doygun katkisi | parlak katkisi |
|---|---|---|---|---|
| HUD | 29.45 | 1.956 | 0.0068 | -0.0060 |
| yaratiklar | 9.62 | 2.625 | 0.0030 | 0.0044 |
| oyuncu yetenek + silah efektleri | 7.59 | 0.060 | 0.0085 | -0.0242 |
| yaratik saldirilari/efektleri | 5.96 | -0.222 | 0.0011 | -0.0246 |
| mermiler/isinlar | 5.51 | -0.242 | 0.0010 | -0.0241 |
| DIGER oyuncularin silahlari | 4.40 | -0.292 | 0.0008 | -0.0179 |
| kendi silahlarim | 4.11 | -0.231 | 0.0007 | -0.0173 |
| can/kalkan cubuklari + durum ikonlari | 3.51 | -0.178 | 0.0007 | -0.0150 |
| yer lekeleri (kan/catlak) | 2.76 | -0.212 | 0.0009 | -0.0116 |
| hasar/altin yazilari | 2.25 | -0.165 | 0.0005 | -0.0091 |

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
enemy:enemy=41 enemy_fx:fx_enemy_ability=25 enemy:worm_limb=9 player_fx:fx_enchant_sprite=8 weapons_puppet:Sprite2D=5 hud:CanvasLayer=5 weapons_own:weapon=3 bars:overhead_bar=3 player_fx:mana_shield_fx=3 players:remote_player=2 enemy_fx:enemy_projectile=2 numbers:floating_text=2 player_fx:fx_animation=2 player_fx:fx_lightning_chain=2 player_fx:melek_halo_fx=2 player_fx:fx_lich_flame_impact=1 weapons_puppet:AnimatedSprite2D=1 player_fx:fx_mage_swap=1 players:player=1 player_fx:gun_reload_fx=1 hud:sun_clouds=1 hud:atmosphere_overlay=1 hud:vision_fog=1 hud:hud=1 player_fx:fx_animation_sequence=1 hud:downed_spectate=1 projectile:fx_lightning_beam=1 enemy_fx:creature_depth=1 enemy_fx:enemy_world_bridge=1 player_fx:totem_attack=1 enemy_fx:enemy_bone=1 player_fx:totem_shield=1 enemy:underground_boss=1 player_fx:dome_weapon_ring=1 player_fx:fx_melek_ascend=1 decal:fx_hit_blood=1 player_fx:water_fx=1
```

- kategori haritasi: kategori_haritasi_m1.jpg
- kategori haritasi: kategori_haritasi_m2.jpg