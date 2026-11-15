# KAFATASI KABARTMASI ALEV sayfası (madde 627, kullanıcı: "mavi gözlü tuzaklardan uzun ateş püskürtmeleri olmalıydı").
# Batık Nekropol'ün yüz kabartması (scull_bas-relief, Duvar süsü karosu, gözler karo animasyonu) artık tuzak: aşağıya ruh ateşi.
# Kaynak = ejder başının uzun alev sayfası (gen_ejder_alev.py çıktısı, aynı palet/dalga): her karede baş pikselleri (kare 0 ile aynı olanlar)
# silinir, alev kafatasının çenesine otursun diye CHIN_SHIFT px aşağı kaydırılır. Boyut/kare düzeni aynı (32 x 160, 8 kare) -> DungeonProps
# "tuzak_kafatasi" STYLE'ı ejderinkiyle aynı alanları kullanır.
# Kullanım: python -I tools/zindan/gen_kafatasi_alev.py  -> harita/zindan/{kemik_mahzeni,batik_nekropol}/runtime/skull_flame.png
import os

from PIL import Image

PROJECT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(PROJECT, 'harita', 'zindan', 'batik_nekropol', 'runtime', 'dragon_trap_long.png')
# iki klasör: DungeonProps sayfayı TEMA klasöründen okur (Batık Nekropol'ün teması kemik_mahzeni), dragon_trap_long.png gibi
DESTS = [os.path.join(PROJECT, 'harita', 'zindan', d, 'runtime', 'skull_flame.png') for d in ('kemik_mahzeni', 'batik_nekropol')]
FW, FH, FRAMES = 32, 160, 8
HEAD_ROWS = 32      # baş bu satırların içinde (ejder başı 0-24)
CHIN_SHIFT = 4      # ejder ağzı ~21. satır, kabartmanın çenesi ~23-25 (kabartma 2x2 bloğun 4-23. satırları)


def main():
    src = Image.open(SRC).convert('RGBA')
    assert src.size == (FW * FRAMES, FH), src.size
    head = src.crop((0, 0, FW, FH))   # kare 0 = sakin baş, alev yok
    out = Image.new('RGBA', src.size, (0, 0, 0, 0))
    for f in range(FRAMES):
        fr = src.crop((f * FW, 0, f * FW + FW, FH))
        px = fr.load()
        hp = head.load()
        for y in range(HEAD_ROWS):
            for x in range(FW):
                if px[x, y] == hp[x, y]:
                    px[x, y] = (0, 0, 0, 0)
        out.paste(fr.crop((0, 0, FW, FH - CHIN_SHIFT)), (f * FW, CHIN_SHIFT))
    for dest in DESTS:
        out.save(dest)
        print('yazıldı:', dest)


if __name__ == '__main__':
    main()
