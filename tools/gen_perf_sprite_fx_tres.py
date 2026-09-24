#!/usr/bin/env python3
"""tools/gen_perf_sprite_fx.py'nin urettigi PNG sheet'leri icin SpriteFrames .tres kaynaklarini
yazar (AtlasTexture bolgeleri + animasyon tanimlari). PNG boyutlari degismedigi surece bir kez
calistirilir; sheet'ler yeniden uretilirse (gen_perf_sprite_fx.py) burasi da yeniden calistirilmali.
Kullanim: python tools/gen_perf_sprite_fx_tres.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def write_sprite_frames(path, png_res_path, cell_w, cell_h, animations):
    """animations: list of (name, cols_row, frame_count, loop, speed) where cols_row is the
    (col0, row) top-left grid cell the animation's frames start at (frames laid out left-to-right)."""
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    lines.append('[ext_resource type="Texture2D" path="%s" id="1"]' % png_res_path)
    lines.append("")
    at_id = 0
    anim_frame_ids = []
    for name, (col0, row), count, loop, speed in animations:
        ids = []
        for i in range(count):
            lines.append('[sub_resource type="AtlasTexture" id="AT_%d"]' % at_id)
            lines.append('atlas = ExtResource("1")')
            lines.append("region = Rect2(%d, %d, %d, %d)" % ((col0 + i) * cell_w, row * cell_h, cell_w, cell_h))
            lines.append("")
            ids.append(at_id)
            at_id += 1
        anim_frame_ids.append((name, ids, loop, speed))

    lines.append("[resource]")
    anim_blocks = []
    for name, ids, loop, speed in anim_frame_ids:
        frame_entries = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("AT_%d")\n}' % i for i in ids)
        block = '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (
            frame_entries, "true" if loop else "false", name, speed,
        )
        anim_blocks.append(block)
    lines.append("animations = [%s]" % ", ".join(anim_blocks))
    lines.append("")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote", path)


def main():
    # --- Kalkan catlama efekti: 3 varyant x 24 kare, tek seferlik (loop=false) ---
    write_sprite_frames(
        os.path.join(ROOT, "assets", "fx", "shield_hit", "hit_frames.tres"),
        "res://assets/fx/shield_hit/hit_sheet.png",
        96, 96,
        [("hit_%d" % v, (0, v), 24, False, 24 / 0.55) for v in range(3)],
    )
    # --- Oakley ari: 2 kareli kanat cirpma dongusu (loop=true) ---
    write_sprite_frames(
        os.path.join(ROOT, "assets", "fx", "oakley_bee_ring", "bee_flap_frames.tres"),
        "res://assets/fx/oakley_bee_ring/bee_flap.png",
        12, 12,
        [("flap", (0, 0), 2, True, 16.0)],
    )
    # --- Ruhani "Adc" alev dili: 12 kareli, FLAME_PERIOD (2pi/11) boyunca seamless loop (bkz. gen_spirit_perf_sprites.py) ---
    write_sprite_frames(
        os.path.join(ROOT, "assets", "fx", "spirit_adc", "flames_frames.tres"),
        "res://assets/fx/spirit_adc/flames.png",
        96, 96,
        [("loop", (0, 0), 12, True, 12.0 / (2.0 * 3.14159265 / 11.0))],
    )
    # --- Buyucu hortum: 36 kareli, TORNADO_LOOP_PERIOD (2pi/6) boyunca seamless loop (bkz. gen_heavy_fx_perf_sprites.py) ---
    write_sprite_frames(
        os.path.join(ROOT, "assets", "fx", "buyucu_tornado", "loop_frames.tres"),
        "res://assets/fx/buyucu_tornado/loop_sheet.png",
        140, 140,
        [("loop", (0, 0), 36, True, 36.0 / (2.0 * 3.14159265 / 6.0))],
    )
    # --- Matthew kalkani: 2026-09-24'ten beri tools/gen_matthew_shield_fx.py kendi .tres'lerini yaziyor (burada yazilirsa
    #     yeni sayfa boyutlariyla uyusmayan eski bolgeler olusurdu).



if __name__ == "__main__":
    main()
    print("ok")
