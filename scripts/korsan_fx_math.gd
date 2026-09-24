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
## Patlat: bombalar Korsan'a en yakından uzağa doğru, ondan yayılan bir "patlama dalgası" gibi zincirleme patlar.
## Kullanıcı isteği (2026-09-24): "korsan aynı anda çok fazla bomba bıraktığında ve hepsini aynı anda patlattığında fps
## problemi yaşamamak için bombaların korsanın yakınlarından uzaklarındaki bombalara doğru hafif gecikmeli olarak
## patlaması gerekiyor" - eskiden sabit 0.09 sn arayla patlıyordu (20 bomba ~1.8 sn'de, üst üste bırakılmışlar da aynı
## hızla). Artık her bombanın gecikmesi Korsan'a UZAKLIĞIYLA orantılı (CHAIN_WAVE_SPEED px/sn'lik dalga) ve iki patlama
## arasında en az CHAIN_MIN_GAP var (aynı yere yığılmış bombalar da art arda, tek karede değil). Kare başına en fazla
## 1 patlama: hasar taraması + yaratık ölümleri + patlama efekti/sesi karelere yayılır. Toplam süre CHAIN_MAX_TOTAL ile
## sınırlı - çok fazla bombada aralık bu süreye sığacak şekilde daralır (ama CHAIN_MIN_GAP_FLOOR'un altına inmez).
const CHAIN_WAVE_SPEED := 650.0
const CHAIN_MIN_GAP := 0.08
const CHAIN_MIN_GAP_FLOOR := 0.04
const CHAIN_MAX_TOTAL := 3.0
## Bomba patlama yarıçapı varsayılanı (korsan_bomb.gd radius ile aynı).
const BOMB_RADIUS := 150.0
