extends RefCounted

## Korsan'ın yetenek görsellerinin (bomba, patlama, bombardıman alanı, düşen mermiler) player.gd (yetkili/gerçek) ile
## efekt scriptleri ARASINDA paylaşılan sayıları - aynı sayı iki dosyada elle kopyalanmasın diye tek kaynak
## (bkz. CLAUDE.md "iki ayrı yerde aynı bilgi" hata sınıfı). player.gd bunları KORSAN_* sabitlerine bağlar.

## Bombardıman (R) alanı yarıçapı ve süresi (fx_korsan_zone.gd halkayı bu yarıçapta çizer).
const BOMBARDMENT_RADIUS := 380.0
const BOMBARDMENT_DURATION := 8.0
## Bombardıman mermisinin düşme süresi: mermi gökten bu sürede iner, hasar VE patlama aynı anda gerçekleşir.
const STRIKE_FALL_TIME := 0.34
## Tek bir bombardıman mermisinin patlama yarıçapı (görsel).
const STRIKE_RADIUS := 68.0
## Bir bombardıman tikinde (1sn) düşen mermi sayısı.
const STRIKES_PER_TICK := 3
## Patlat (Q): bombalar en yakından uzağa bu aralıkla zincirleme patlar.
const CHAIN_DELAY := 0.09
## Bomba patlama yarıçapı varsayılanı (korsan_bomb.gd radius ile aynı).
const BOMB_RADIUS := 150.0
