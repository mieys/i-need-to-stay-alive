# Üç Kardeş boss sprite/efekt hazırlığı: craftpix lvl9 sayfaları -> assets/enemies/kardesler/
# Karakter sayfaları: paket satırları (ön, sol, sağ, arka) -> enemy.gd (aşağı, yukarı, sol, sağ).
# Efektler: tek satırlık şeritler (mermiler SAĞA bakan satır; kod döndürür).
import os, sys
from PIL import Image

RAW = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)


SHADOW = Image.open(os.path.join(RAW, "archer", "shadow_single.png")).convert("RGBA")


def char_sheet(src, dst, cell=64):
    im = Image.open(src).convert("RGBA")
    rows = [im.crop((0, r * cell, im.width, (r + 1) * cell)) for r in range(4)]
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    # paketin kendi gölgesi (With_shadow sayfalarıyla aynı yer: hücrede (16, 36)) - oyundaki yaratık sayfalarında gölge gömülü
    for y in range(4):
        for x in range(im.width // cell):
            out.alpha_composite(SHADOW, (x * cell + 16, y * cell + 36))
    for i, r in enumerate([0, 3, 1, 2]):
        out.alpha_composite(rows[r], (0, i * cell))
    out.save(os.path.join(OUT, dst))
    print(dst, out.size)


def strip(src, dst, fw, fh, row, frames=None):
    im = Image.open(src).convert("RGBA")
    n = im.width // fw if frames is None else frames
    out = im.crop((0, row * fh, n * fw, (row + 1) * fh))
    out.save(os.path.join(OUT, dst))
    print(dst, out.size, n, "kare")


j = os.path.join
S, A, M, F = j(RAW, "sword"), j(RAW, "archer"), j(RAW, "mage"), j(RAW, "fx")
# Kılıç Kardeş (hızlı yakın dövüşçü: yürüme = koşu sayfası)
char_sheet(j(S, "lvl9_Run_without_shadow.png"), "kilic_walk.png")
char_sheet(j(S, "lvl9_Idle_without_shadow.png"), "kilic_idle.png")
char_sheet(j(S, "lvl9_Hurt_without_shadow.png"), "kilic_hurt.png")
char_sheet(j(S, "lvl9_Death_without_shadow.png"), "kilic_death.png")
char_sheet(j(S, "lvl9_attack_normal_without_shadow.png"), "kilic_attack.png")
char_sheet(j(S, "lvl9_Run_Attack_without_shadow.png"), "kilic_dash.png")
char_sheet(j(S, "lvl9_attack_without_shadow.png"), "kilic_spin.png")
char_sheet(j(F, "Swordsman_lvl9_Magic_without_shadow.png"), "kilic_cast.png")
# Ok Kardeş (vur-kaç: yürüme = koşu)
char_sheet(j(A, "Archer_lvl9_Run_full_without_shadow.png"), "ok_walk.png")
char_sheet(j(A, "Archer_lvl9_Idle_full_without_shadow.png"), "ok_idle.png")
char_sheet(j(A, "Archer_lvl9_Hurt_full_without_shadow.png"), "ok_hurt.png")
char_sheet(j(A, "Archer_lvl9_Death_full_without_shadow.png"), "ok_death.png")
char_sheet(j(A, "Archer_lvl9_Attack_full_without_shadow.png"), "ok_attack.png")
char_sheet(j(F, "Archer_lvl9_Magic_without_shadow.png"), "ok_cast.png")
# Büyü Kardeş
char_sheet(j(M, "Mage9_Walk_full_without_shadow.png"), "buyu_walk.png")
char_sheet(j(M, "Mage9_Idle_full_without_shadow.png"), "buyu_idle.png")
char_sheet(j(M, "Mage9_Hurt_full_without_shadow.png"), "buyu_hurt.png")
char_sheet(j(M, "Mage9_Death_full_without_shadow.png"), "buyu_death.png")
char_sheet(j(M, "Mage9_attack_full_without_shadow.png"), "buyu_attack.png")
char_sheet(j(F, "Mage_lvl9_Magic_without_shadow.png"), "buyu_cast.png")

# Efektler
arrow = Image.open(j(A, "Arrow.png")).convert("RGBA").crop((70, 0, 92, 32))  # 3. ok (sağa bakan, 10x3)
arrow = arrow.crop(arrow.getbbox())
arrow.save(j(OUT, "fx_arrow.png")); print("fx_arrow.png", arrow.size)
strip(j(F, "Fireball_cycle.png"), "fx_fireball.png", 64, 64, 2)
strip(j(F, "Fireball_explosion.png"), "fx_fireball_boom.png", 64, 64, 2)
strip(j(F, "Ice_arrow_left-right.png"), "fx_ice_arrow.png", 80, 48, 1)
strip(j(F, "Ice_arrow_explosion_left-right.png"), "fx_ice_boom.png", 80, 48, 1)
strip(j(F, "Lightning_front-back.png"), "fx_lightning.png", 64, 96, 0)
strip(j(F, "Falling_flaming_stones.png"), "fx_meteor.png", 64, 96, 0)
strip(j(F, "Ice _spikes_front-back.png"), "fx_ice_spikes.png", 64, 80, 0)
strip(j(S, "lvl9_attack_aoe.png"), "fx_sword_aoe.png", 64, 64, 0)
strip(j(M, "Fire_explosion.png"), "fx_fire_burst.png", 64, 64, 0)
