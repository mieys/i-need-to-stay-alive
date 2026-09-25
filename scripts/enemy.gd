extends CharacterBody2D
class_name Enemy

const PhysicsInterp := preload("res://scripts/physics_interp.gd")

@export var speed: float = 90.0
@export var max_health: float = 20.0
@export var contact_damage: float = 8.0
@export var contact_interval: float = 0.75
@export var xp_value: float = 5.0
@export var orb_count: int = 1

## Chance (0-1) to drop a gold pickup on death, and how much gold it's worth.
## DÜZELTME (kullanıcı isteği: "yaratıkların altın düşürme şansını mevcut
## şanstan %20 arttır") - taban varsayılan ×1.2 (0.2 -> 0.24); her yaratık
## türünün kendi .tscn'de override ettiği GERÇEK değer de (bkz. scenes/
## creatures/enemy_*.tscn) AYNI oranla ayrı ayrı çarpıldı, buradaki sadece
## hiçbir .tscn'in override etmediği bir Enemy oluşursa kullanılacak taban.
@export var gold_chance: float = 0.288
@export var gold_min: int = 1
@export var gold_max: int = 1

## Chance (0-1) to drop a healing fruit on death.
## Kullanıcı isteği: "elma (yiyecek) düşme oranı çok yüksek, ciddi şekilde
## azalt - sadece şans (luck) statıyla artabilsin." Taban oran eskiden
## %5'ti, %1.5'e çekilmişti. DÜZELTME (kullanıcı isteği: "genel olarak
## oyundaki yemek düşme şansını %85 şans faktörüne göre scale et") - taban
## oran bir kez daha ×0.85 ölçeklendi (0.015 -> 0.01275). DÜZELTME (kullanıcı
## isteği: "Yemek düşme oranını %80 azalt.") - taban oran ×0.2 ölçeklendi
## (0.01275 -> 0.00255). DÜZELTME (kullanıcı isteği: "çok fazla yemek
## düşüyor, şuanki düşme ihtimalini %80 azalt") - taban oran BİR KEZ DAHA
## ×0.2 ölçeklendi (0.00255 -> 0.00051). _drop_food()'daki şans çarpanı
## (bkz. LUCK_DROP_MULT_PER_POINT - 2026-09-24'ten beri çarpımsal, 20 şans =
## 2 kat) HÂLÂ ve TEK artış yolu, burada dokunulmadı.
## DÜZELTME (kullanıcı bildirimi 2026-09-25: "şans kasmadığında ... yemek düşmüyor") - yukarıdaki iki %80 kesinti şans
## TOPLANARAK eklenirken yapılmıştı (şans puanı başına +%0,2 mutlak - şanslı oyuncuda yemek yağıyordu); 2026-09-24'ten
## beri şans ÇARPAN (puan başına x1,05) olunca şanssız oyuncuya ~25 dk'da 3-5 yemek kalmıştı. Son kesinti geri alındı
## (0.00051 -> 0.0025, x~5): şans 0'da ilk 5 dk'da ~1-2, oyun boyunca ~15-20 yemek; 20 şans hâlâ 2 kat.
@export var food_chance: float = 0.0025

## Chance (0-1) to drop a magnet pickup on death - bkz. yukarıdaki MagnetDrop
## sabiti üstündeki BUG DÜZELTMESİ notu. README'deki eski davranışla aynı
## ("daha nadir (%3) mıknatıs düşüyor") - food_chance ile aynı luck bonusunu
## paylaşır (bkz. _drop_magnet).
## kullanıcı isteğiyle %80 düşürüldü (0.03 -> 0.006), sonra kullanıcı isteği
## ("çok fazla mıknatıs düşüyor, %80 azalt") ile BİR KEZ DAHA %80 düşürüldü
## (0.006 -> 0.0012).
@export var magnet_chance: float = 0.0012

## Ranged casters (Demon, Lich, Röntgen, İblis) keep their distance instead of
## walking into the player, and periodically lob a projectile instead of/as
## well as contact damage. is_ranged = false means "melee as before".
@export var is_ranged: bool = false
## Kullanıcı isteği: menzilli yaratıklar artık ikinci, garanti isabetli
## (homing) bir "normal atış"a da sahip olduğu için (bkz. _process_homing_
## attack) büyünün (bu değer) menzili belirgin biçimde düşürüldü - eskiden
## 260'tı, artık daha yakına gelmeden büyü atamıyorlar.
## DÜZELTME (kullanıcı isteği #22: "menzilli karakter/yaratık menzilleri
## genel olarak çok uzun" - seçilen oran: %25 azalt): 150 -> 112.5. Bu tek
## değer _process_ranged_attack'taki 1.6x/2.5x çarpanlar sayesinde tetikleme
## mesafelerini de orantılı olarak küçültüyor.
@export var ranged_range: float = 112.5 ## preferred distance kept from the player
@export var ranged_attack_interval: float = 2.2
@export var ranged_damage: float = 0.0 ## 0 = reuse contact_damage
@export var projectile_tint: Color = Color(1.0, 0.55, 0.15, 1.0)
## Büyünün (yukarıdaki ranged_damage/contact_damage) uyguladığı gerçek çarpan
## - kullanıcı isteği: "büyülerinin hasarını %60 azalt (normal atışlarını
## değil)".
const RANGED_SPELL_DAMAGE_MULT := 0.4
## İKİNCİ, daha zayıf, GARANTİ İSABETLİ (homing) normal atış - büyüden
## tamamen bağımsız bir kd üzerinde çalışır, oyuncunun GÜNCEL konumunu her
## karede takip ederek asla ıskalamaz (bkz. enemy_projectile.gd homing) -
## sadece oyuncunun "sıyrılma" (dodge) stat'ı onu engelleyebilir, tıpkı
## normal isabetler gibi (take_damage() içindeki mevcut dodge zarı).
@export var normal_attack_interval: float = 1.15
@export var normal_attack_damage_mult: float = 0.35 ## büyü hasarının (yukarısı) bu oranı

## Kullanıcı bildirimi: "Menzilli düşmanlar hem aynı anda birden çok
## ateşleme yapıyor sadece 1 adet ateşleme yapsın" - büyü VE "garanti
## isabet" atışı eskiden ayrı zamanlayıcı kullanıyordu, artık ikisi de bu
## TEK paylaşılan sayacı kullanıyor (bkz. _process_ranged_attack).
var _ranged_timer: float = 0.0
const EnemyProjectileScene := preload("res://scenes/enemy_projectile.tscn")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

## Only used for enemies whose visual is a plain Sprite2D with hframes/vframes
## set (e.g. the boss and the rat), instead of an AnimatedSprite2D with a
## SpriteFrames resource. Each grid is expected to have 4 rows in the order
## down, up, left, right (matches the Craftpix demon/rat packs) and however
## many frame columns fit in cell_size-wide cells.
@export var sprite_fps: float = 8.0
@export var cell_size: int = 128
@export var walk_texture: Texture2D
## Kullanıcı bildirimi: "yaratıklar hareket etmediğinde / sabitlendiğinde / agrosu yokken
## idle pozisyonunda durmuyor, yürüme pozisyonunda takılı kalıyor" - kök neden: durum
## makinesinde IDLE HİÇ YOKTU (WALK/HURT/ATTACK/DEATH), yani durmuş bir yaratık da yürüme
## karelerini oynamaya devam ediyordu. Boşsa _ready() walk_texture'ın yolundan
## ("..._Walk_..." -> "..._Idle_...") türetir - 49 yaratık sahnesinin hepsinin klasöründe
## aynı düzende bir Idle sayfası var, sahneleri tek tek düzenlemek gerekmiyor.
@export var idle_texture: Texture2D
@export var hurt_texture: Texture2D
@export var death_texture: Texture2D
@export var attack_texture: Texture2D

## Item-shield, mirroring the player's own mechanic (see player.gd's
## item_shield_hp / shield_protection / take_damage): a separate HP pool that
## eats a fixed share of every hit before health does, and slowly regenerates
## after a few hitless seconds. Nothing here by default - granted at spawn
## time by enemy_spawner.gd via enable_item_shield(): Kademe 3+ regular
## enemies get SHIELD_PROTECTION (şu an %30), her boss BOSS_SHIELD_PROTECTION
## (şu an %85) kadarını emer. No shield VFX/hit-flash
## by design (kalkan efektine gerek yok) - just the numbers.
var shield_protection: float = 0.0 ## 0 = this enemy has no shield at all
var item_shield_max: float = 0.0
var item_shield_hp: float = 0.0
var item_shield_regen_delay: float = 0.0
const ITEM_SHIELD_REGEN_DELAY := 14.0 ## seconds of no hits before it starts regenerating - long on purpose
const ITEM_SHIELD_REGEN_RATE := 0.02 ## fraction of max shield regenerated per second - very slow on purpose

## Tüftüf'ün zehiri (bkz. weapon.gd/projectile.gd poison_tick_damage/
## poison_max_stacks/poison_duration). Kullanıcı isteği: "Tüftüfün zehri 100
## defaya kadar stacklenebilsin ve zehir 20 saniye boyunca her saniye saldırı
## gücünün %5'i kadar hasar versin" - isabet eden her dart bu düşmana bir
## YÜK ekler; her yük KENDİ süresini (poison_duration) bağımsız sayar ve o
## süre boyunca saniyede kendi hasarını (saldırı gücünün %5'i, yük eklendiği
## andaki değerle) verir. Eskiden tek bir zehir vardı: her isabet onu
## yeniliyor ve tık hasarı her saniye artıyordu (üst üste binmiyordu).
## Yük sayısı üst sınıra (max_stacks) ulaşınca yeni bir isabet en ESKİ yükü
## tazeler (süre yenilenir) - zehir sürekli vurulan hedefte kesilmez.
var _poison_stack_time: PackedFloat32Array = PackedFloat32Array() ## her yükün kalan ömrü (sn)
var _poison_stack_dps: PackedFloat32Array = PackedFloat32Array() ## her yükün saniyelik hasarı
var _poison_damage_accum: float = 0.0 ## henüz uygulanmamış birikmiş zehir hasarı (saniyede bir topluca uygulanır)
var _poison_tick_timer: float = 0.0
const POISON_TICK_INTERVAL := 1.0

## Zehir aktifken hedefin üzerinde sürekli oynayan döngülü efekt (bkz.
## scenes/fx_poison_status.tscn) - apply_poison() ile beliriyor, zehir bitince
## (_process_poison'da tüm yükler bitince) kayboluyor. Yeni bir dart
## isabet edip zehri yenilerse (efekt zaten varsa) tekrar oluşturulmaz, sadece
## kalmaya devam eder.
const PoisonStatusFxScene := preload("res://scenes/fx_poison_status.tscn")
var _poison_status_fx: Node2D = null

## Shaman pasifi (Totem Auraları): "totemlerine yakın müttefiklerin
## düşmanlara verdiği hasar, düşmana 3sn boyunca her saniye o müttefiğin
## saldırı gücünün %10'u kadar yakma hasarı bırakır." apply_poison() ile
## AYNI şablon (kendi vars + host-forward guard + _process_burn) - ramp YOK
## (sabit tik hasarı), bu yüzden poison'dan ayrı, kendi küçük durumu var.
## GÖRSEL (kullanıcı isteği: "Shaman skill efektlerini pixel-art yap"):
## hedefin üzerinde sürekli oynayan DÖNGÜLÜ piksel-art alev sprite'ı -
## poison_status ile BİREBİR AYNI desen: apply_burn'de belirir,
## _process_burn'de yakma bitince kaybolur, ağda broadcast_enemy_vfx
## "burn_start"/"burn_stop" ile TÜM client'lara senkronlanır.
## (Eskiden bu görsel hiç yoktu, sadece görünmez hasar tiki uygulanıyordu.)
const BurnStatusFxScene := preload("res://scenes/fx_burn_status.tscn")
var _burn_status_fx: Node2D = null
var burn_tick_damage: float = 0.0
var burn_time_left: float = 0.0
var _burn_tick_timer: float = 0.0
const BURN_TICK_INTERVAL := 1.0

## Tabanca'nın "yük" (mark) mekaniği: bu hedefe her isabette 1 yük eklenir
## (mark_max_stacks'e kadar, bkz. weapon.gd/projectile.gd), her yük SONRAKİ
## isabetlerde alınan hasarı %1 arttırır (bkz. get_mark_damage_mult). 20
## saniye boyunca hiç isabet almazsa yük tamamen sıfırlanır - poison gibi
## "yenilenen" değil, "biriken" bir sistem: her isabet mevcut yükü SIFIRLAMAZ,
## üstüne 1 daha ekler (tavana kadar) ve sadece süre sayacını tazeler.
var mark_stacks: int = 0
var _mark_timer: float = 0.0
const MARK_DURATION := 20.0
const MARK_PERCENT_PER_STACK := 0.01
## Kullanıcı isteği (2026-09-24 denge turu: Tabanca işareti "yük başına +%1 -> +%2, tavan %70 aynı") - her isabet 2 yük
## ekler (yük başı %1 ve yük tavanı aynı kaldığı için tavan birebir aynı: %70, dönüm noktalarıyla %90); tavana 70 yerine
## 35 isabette ulaşılır.
const MARK_STACKS_PER_HIT := 2

## Hançer'in kanama yükü: her isabette 1+ yük eklenir (bleed_max_stacks'e
## kadar, bkz. weapon.gd apply_bleed çağrısı) - poison'un aksine süresi
## yok/yenilenmez, biriken yük saniyede bir kendi başına hasar vermeye devam
## eder (enemy ölene kadar). Tik hasarı (saldırı gücüne bağlı olduğu için)
## HER isabette güncel değerle üzerine yazılır.
var bleed_stacks: int = 0
var bleed_tick_damage_per_stack: float = 0.0
var _bleed_tick_timer: float = 0.0
const BLEED_TICK_INTERVAL := 1.0
## Her kanama tikinde (bkz. _process_bleed) rastgele biri oynatılan, tek
## seferlik kan sıçraması efektleri - weapon.gd'nin yakın dövüş isabet
## efektleriyle (fx_hit_blood_*) aynı sahneler, fx_animation.gd script'i
## sayesinde "play" animasyonu bitince kendini otomatik siliyor.
const BleedFxScenes := [
	preload("res://scenes/fx_hit_blood_1.tscn"),
	preload("res://scenes/fx_hit_blood_2.tscn"),
	preload("res://scenes/fx_hit_blood_3.tscn"),
]

## Buz Asası'nın donma durumu: etkin her isabet boss olmayan hedefi
## CHILL_DURATION saniyeliğine tamamen dondurur. Yeni isabet donma süresini
## baştan başlatır; bosslar dondurulamaz.
var chill_stacks: int = 0
var _chill_timer: float = 0.0
const CHILL_DURATION := 3.0
const CHILL_MAX_STACKS := 1

## Kullanıcı isteği: "buz asası bossları da dondurabilsin ama 5 kez vurması
## gereksin" - normal yaratıklar TEK isabette donarken bosslar art arda
## BOSS_CHILL_HITS_REQUIRED isabet biriktirmeli (bkz. apply_chill). Isabetler
## arasında CHILL_DURATION'dan uzun süre geçerse (mark/bleed'deki AYNI "yük
## zaman aşımı" deseni, bkz. _process_boss_chill) sayaç sıfırlanır.
var _boss_chill_stacks: int = 0
var _boss_chill_timer: float = 0.0
## Kullanıcı isteği (2026-09-24 denge turu): 5 asayla boss zamanın %73-85'i donuk kalıyordu - eşik 5 -> 10 isabet,
## boss donması 3sn -> 1.5sn (BOSS_CHILL_FREEZE_DURATION). Normal yaratıkların 3sn donması (CHILL_DURATION) aynı.
const BOSS_CHILL_HITS_REQUIRED := 10
const BOSS_CHILL_FREEZE_DURATION := 1.5

## Kitelama Seti (bkz. scripts/items.gd/weapon.gd _apply_item_slow_on_hit):
## chill'den farklı olarak stack YAPMAZ - her isabet süreyi ve yüzdeyi
## baştan başlatarak (refresh) ÜZERİNE YAZAR (kullanıcı isteği: "hasar
## vermek bu etkiyi baştan başlatır").
var _slow_percent: float = 0.0
var _slow_timer: float = 0.0
## GÖRSEL (kullanıcı isteği: "Shaman skill efektlerini pixel-art yap") -
## yavaşlatılmış hedefin üzerinde dönen DÖNGÜLÜ piksel-art boşluk girdabı.
## Alan Totemi'nin yavaşlatması önceden hiçbir görsel bırakmıyordu.
## Ömür bilerek _slow_timer'dan AYRI tutulur: yavaşlatma HOST'ta hesaplanır
## (_slow_timer istemcilerde hiç dolmaz), ama bu gösterge ağdan gelen
## "slow_start" mesajıyla HER client'ta bağımsız sayar.
const SlowStatusFxScene := preload("res://scenes/fx_void_slow_status.tscn")
const SLOW_FX_DEFAULT_DURATION := 1.5
## Alan Totemi yavaşlatmayı saniyede bir yeniliyor - ağ spam'i olmasın diye
## gösterge mesajı en fazla bu aralıkta bir gönderilir (yenileme süresi
## 1.5sn olduğundan istemcideki sprite hiç sönmez).
const SLOW_FX_BROADCAST_INTERVAL := 1.0
var _slow_status_fx: Node2D = null
var _slow_fx_time_left: float = 0.0
var _slow_fx_broadcast_cooldown: float = 0.0
var is_frozen: bool = false
var _freeze_timer: float = 0.0
const FREEZE_DURATION := 5.0
const FreezeStatusFxScene := preload("res://scenes/fx_ice_freeze_status.tscn")
var _freeze_status_fx: Node2D = null

## Kullanıcı isteği: Melek'in yeni 3. yeteneği (Kutsal Korku) - freeze'in
## AYNI host-yönlendirme/süre deseni, ama hareket "dur" değil "kaynaktan
## uzağa kaç" (bkz. apply_fear/_process_fear, _physics_process'teki
## is_feared dalı).
var is_feared: bool = false
var _fear_timer: float = 0.0
var _fear_source_pos: Vector2 = Vector2.ZERO
const FEAR_DURATION := 4.0
## Necromancer ULTİ (Lanetli Kafatası, 2026-09-24): "korkan düşmanlar etrafa rasgele yönlerde yürümeye çalışır ve hasar
## veremez" - Melek'in "kaynaktan kaç" korkusundan AYRI bir mod (bkz. apply_fear_wander). Korkunun her iki modunda da yaratık
## hedef seçmez, saldırmaz, yeteneği tetiklenmez ve zaten başlamış bir yakın dövüş vuruşu da iptal olur (_schedule_melee_hit).
var _fear_wander: bool = false
var _fear_wander_dir: Vector2 = Vector2.RIGHT
var _fear_wander_retarget: float = 0.0
const FEAR_WANDER_SPEED_MULT := 0.7 ## "yürümeye çalışır" - koşmaz, normal hızının %70'iyle sendeleyerek dolaşır
const FEAR_WANDER_TURN_MIN := 0.45
const FEAR_WANDER_TURN_MAX := 1.0
## Korku göstergesi (başının üstünde titreyen küçük hayalet) - her iki korku modunda da, host'ta başlatılıp
## broadcast_enemy_vfx "fear_start"/"fear_stop" ile diğer istemcilere yayınlanır (bkz. _set_fear_visual).
const FearStatusFxScene := preload("res://scenes/fx_fear_status.tscn")
var _fear_status_fx: Node2D = null

## Sersemletme (Stun) takibi için değişkenler (bkz. apply_stun, _spawn_stun_status_fx)
var is_stunned: bool = false
const StunStatusFxScene := preload("res://scenes/fx_stun_stars.tscn")
var _stun_status_fx: Node2D = null

## apply_boss_stats() çağrılan HER yaratık boss'tur (bkz. enemy_spawner.gd) -
## Buz Asası'nın "bosslar hariç" donma istisnası bunu okur.
var is_boss: bool = false

## enemy_spawner.gd'nin apply_tier_scaling(tier) ile ilettiği Kademe (1-15) -
## RAGE MODU'nun "Kademe 2+" şartını kontrol edebilmek için burada saklanıyor
## (bkz. apply_tier_scaling, take_damage, RAGE_HP_THRESHOLD).
var _current_tier: int = 1

## Kullanıcı isteği: "Kademe 2+ yakın dövüşçü yaratıklar canı %30'un altına
## düşünce çılgına dönsün - hafif kırmızılaşsın ve çok daha hızlı hareket
## etsin." Bosslar (kendi ayrı dengesi zaten var, apply_boss_stats ile gelir)
## ve menzilliler bu moda GİRMEZ - bkz. take_damage'daki tetikleme şartı.
var is_raging: bool = false
const RAGE_HP_THRESHOLD := 0.30
## Kullanıcı bildirimi: "rage modu pek çalışıyormuş gibi görünmedi" - hem
## renk daha belirgin/doygun kırmızıya çekildi hem de hız çarpanı belirgin
## şekilde arttırıldı ("vahşice koşmaları gerekiyordu" isteğiyle) - artık
## normal yakın dövüşçü hızının neredeyse İKİ KATI (asıl görünmezlik sebebi
## ayrı bir tween çakışma hatasıydı, bkz. _flash()/_refresh_chill_tint()).
const RAGE_TINT_COLOR := Color(1.7, 0.3, 0.3, 1.0)
## Kullanıcı isteği: "canavarlar rage moduna girince daha yüksek hareket
## hızına sahip olsun" - 1.9'dan (neredeyse iki kat) 2.4'e (neredeyse iki
## buçuk kat) yükseltildi, "vahşice koşma" hissi daha da belirginleşti.
## DÜZELTME (kullanıcı bildirimi: "yaratıkların rage modu ilk kademelerde
## aşırı hızlı koşuyor") - 2.4 sabit çarpan tüm Kademelerde AYNI kalıyordu,
## ilk Kademelerin (düşük taban hız) yanında bile "aşırı" hissettiriyordu.
## Biraz aşağı çekildi.
## Kullanıcı isteği (2026-09-25): "yaratıkların hareket hızını %10 arttırıp rage hızlarını %10 azalt" - taban hız
## GLOBAL_SPEED_SCALE'de x1.1; öfke çarpanı x(0.9 / 1.1) ki öfkedeki SON hız (taban x çarpan) bugünkünün TAM %90'ı olsun
## (sadece x0.9 yapılsaydı taban hızdaki +%10 onu geri alırdı, öfke hızı neredeyse hiç değişmezdi).
const RAGE_SPEED_CUT_2026_09_25 := 0.9 / 1.1
const RAGE_SPEED_MULT := 2.0 * RAGE_SPEED_CUT_2026_09_25
## Kullanıcı isteği (2026-09-24 yaratık yetenekleri): "Orkların ragesi %50 canın altında gerçekleşir, bu esnada hareket
## hızları normal rageye göre 1.5 kat daha fazla artar" - normal öfke +%100 (x2.0) -> ork +%150 (x2.5); 2026-09-25 kesintisi
## ork öfkesine de aynı oranda uygulanır.
const ORK_RAGE_HP_THRESHOLD := 0.50
const ORK_RAGE_SPEED_MULT := (1.0 + (2.0 - 1.0) * 1.5) * RAGE_SPEED_CUT_2026_09_25

## ---------- Yaratık yetenekleri (kullanıcı isteği 2026-09-24, bkz. enemy_abilities.gd) ----------
const EnemyAbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const CreatureDeathSound := preload("res://scripts/creature_death_sound.gd")
## Görünmez hayaletin sprite opaklığı - kullanıcı tercihi (2026-09-24): "%25 soluk gölge" (hedef alınamaz ama nerede olduğu tahmin edilebilir).
const GHOST_INVISIBLE_ALPHA := 0.25
## Hayalet görünmezken hedef alınamaz (bkz. vision_fog.gd can_target) - bu meta ile işaretlenir.
const UNTARGETABLE_META := &"untargetable"
var _abilities = null ## EnemyAbilities (RefCounted) - sadece yetenekli ailelerde, bkz. _init_abilities
var _abilities_checked: bool = false
var _family_cache: String = ""
## >0 iken yaratık yetenek kanalındadır (Röntgen lazeri) - yerinde durur.
var ability_move_lock: float = 0.0
## Hayaletin yetenek görünmezliği: görünmez, hedef alınamaz, hasar almaz ve VEREMEZ (bkz. temas saldırısı dalı).
var is_ability_invisible: bool = false


## creature_id'nin (enemy_spawner.gd _spawn_creature meta'sı, ör. "vampire2") rakamsız kısmı - "vampire".
static func family_of_id(creature_id: String) -> String:
	var i: int = creature_id.length()
	while i > 0 and creature_id[i - 1] >= "0" and creature_id[i - 1] <= "9":
		i -= 1
	return creature_id.substr(0, i)


func creature_family() -> String:
	if _family_cache.is_empty() and has_meta("creature_id"):
		_family_cache = family_of_id(str(get_meta("creature_id")))
	return _family_cache


func _init_abilities() -> void:
	_abilities_checked = true
	if not has_meta("creature_id"):
		_abilities_checked = false ## meta henüz atanmadı (spawn'ın ilk karesi) - bir sonraki karede tekrar dene
		return
	var fam: String = creature_family()
	if EnemyAbilitiesScript.family_has_ability(fam):
		_abilities = EnemyAbilitiesScript.new()
		_abilities.setup(self, fam)


## Yetenek kullanırken saldırı animasyonu (host + istemciler) - lazer/ateş topu/diken.
func _play_ability_attack_anim() -> void:
	var dur: float = _anim_length_for(State.ATTACK)
	_enter_state(State.ATTACK, dur if dur > 0.0 else 0.4)
	_broadcast_attack_state()


## Hayaletin görünmezliği (host: enemy_abilities.gd; istemci: on_ability_vfx). Sprite'ın self_modulate'ı kullanılır -
## modulate durum tonu/vuruş parlaması (_refresh_chill_tint/_flash) ve kök visible sisin (vision_fog.gd) elinde.
func set_ability_invisible(on: bool) -> void:
	is_ability_invisible = on
	var a: float = GHOST_INVISIBLE_ALPHA if on else 1.0
	for spr: CanvasItem in [anim_sprite, frame_sprite]:
		if spr:
			spr.self_modulate.a = a
	if on:
		set_meta(UNTARGETABLE_META, true)
		if _overhead_bar and is_instance_valid(_overhead_bar):
			_overhead_bar.visible = false
	elif has_meta(UNTARGETABLE_META):
		remove_meta(UNTARGETABLE_META)


## İstemci tarafı: host'un broadcast_enemy_vfx ile gönderdiği yetenek olayları (bkz. network_manager.gd).
func on_ability_vfx(kind: String, data: Dictionary) -> void:
	var scene_root: Node = get_tree().current_scene if is_inside_tree() else null
	match kind:
		"ghost_vanish":
			set_ability_invisible(true)
			if scene_root:
				EnemyAbilitiesScript.FxScript.spawn(scene_root, global_position, EnemyAbilitiesScript.GHOST_FRAMES, &"vanish", 2)
		"ghost_reveal":
			set_ability_invisible(false)
			if scene_root:
				EnemyAbilitiesScript.FxScript.spawn(scene_root, global_position, EnemyAbilitiesScript.GHOST_FRAMES, &"appear", 2)
		"vampire_blink":
			var from: Vector2 = Vector2(data.get("from", global_position))
			var to: Vector2 = Vector2(data.get("to", global_position))
			## Ani ışınlanma: konum enterpolasyonu (lerp) yüzünden kayarak gitmesin, doğrudan yeni yere atlasın.
			global_position = to
			_network_target_position = to
			_network_velocity = Vector2.ZERO
			if scene_root:
				EnemyAbilitiesScript.FxScript.spawn(scene_root, from, EnemyAbilitiesScript.VAMPIRE_FRAMES, &"blink", 2)
				EnemyAbilitiesScript.FxScript.spawn(scene_root, to, EnemyAbilitiesScript.VAMPIRE_FRAMES, &"blink", 2)

## Flat armor scaling as Kademe rises - see apply_tier_scaling(). Kademe
## (tier) itself now ALSO scales health/damage directly (TIER_HEALTH_RAMP_*/
## TIER_DAMAGE_RAMP_*, quadratic so late Kademeler pull ahead a lot more than
## early ones) - this replaces most of what used to come from the raw-time
## ramp below (_apply_difficulty_scaling), which was nerfed hard because it
## made runs snowball just from sitting in one Kademe too long. The item
## shield's pool is a % of max_health so it inherits this same rise for free.
## Kullanıcı bildirimi: "yaratıkların zamanla hasarları aşırı artıyor ve tek
## atıyorlar ayrıca çok kırılganlar" - hasar artış oranı (LINEAR/QUAD) belirgin
## şekilde düşürüldü (özellikle QUAD, geç Kademelerde "tek vuruşta öldürme"
## hissinin asıl kaynağıydı), buna karşılık dayanıklılık (can + özellikle
## zırh) belirgin şekilde arttırıldı.
##
## Kullanıcı isteğiyle (2. tur): "global time scaling oyunun dengesini
## bozuyor, onun yerine dengeli olarak üst tier yaratıkları güçlendirelim" -
## aşağıdaki DIFFICULTY_* (saniyeye bağlı, sürekli/global) ramp neredeyse
## sıfıra indirildi (~dakikada %1), gücün asıl kaynağı artık TAMAMEN bu
## Kademe-bazlı (adım adım, sadece Kademe değiştiğinde atlayan) sistem.
## Üst Kademeleri "dengeli" güçlendirmek için QUAD (kareyle büyüyen)
## terimler arttırıldı - bu terimler SADECE geç Kademelerde belirgin hale
## gelir, ilk birkaç Kademe hemen hemen etkilenmez. Zırha da (kullanıcı
## isteği: "özellikle kalkan ve zırhlarını arttıralım") artık bir QUAD
## terimi eklendi (TIER_ARMOR_RAMP_QUAD) - üst Kademe yaratıkları belirgin
## şekilde daha zırhlı.
##
## Kullanıcı isteğiyle (3. tur): "yaratıklar çok hızlı güçlenip zorlaşıyor
## ve aşırı dayanıklılar öldürmek çok zorlaşıyor" - bir önceki turda
## dayanıklılık (can+zırh) belirgin şekilde arttırılmıştı, ama pendulum
## fazla ileri gitmiş: can ve zırh ramp'leri (hem LINEAR hem QUAD)
## belirgin şekilde AŞAĞI çekildi. Hasar ramp'i (TIER_DAMAGE_RAMP_*)
## bilinçli olarak DOKUNULMADI - kullanıcı bu turda hasarın fazla
## olduğundan değil, sadece öldürmenin çok uzun sürdüğünden şikayet etti.
## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
## oyundan kaldır") - eskiden burada TIER_ARMOR_RAMP/TIER_ARMOR_RAMP_QUAD
## (Kademe başına düz zırh artışı) da vardı, zırhla birlikte kaldırıldı.
const TIER_HEALTH_RAMP_LINEAR := 0.065 ## eskiden 0.10 - +6.5%/Kademe ...
const TIER_HEALTH_RAMP_QUAD := 0.011 ## eskiden 0.020 - ... plus +1.1%*(Kademe-1)^2
const TIER_DAMAGE_RAMP_LINEAR := 0.035 ## +3.5%/Kademe ...
const TIER_DAMAGE_RAMP_QUAD := 0.006 ## ... plus +0.6%*(Kademe-1)^2 (eskiden 0.004), ölçülü bir artış
## Kullanıcı isteği (2026-09-24 denge turu, "ilk 2 kademe zorlaşmamalı"): Kademe 3'ten itibaren EK hasar artışı -
## (Kademe-2) üzerinden hesaplandığı için Kademe 1-2'de tam 0. Kademe 3: +%2.8, Kademe 8: +%18, Kademe 15'te toplam
## hasar çarpanı x2.67 -> x3.6. Kök neden: yaratık hasarı 15 kademede sadece x2.67 büyürken oyuncu canı 15-30 kat.
const TIER_DAMAGE_RAMP_LATE_LINEAR := 0.0242
const TIER_DAMAGE_RAMP_LATE_QUAD := 0.0037
## Kullanıcı isteği (2026-09-24 denge turu: yaratık canı "zamana bağlı olarak giderek yavaşça artsın", Kademe 1-2
## zorlaşmasın): Kademe 3+ normal yaratıkların canı (kalkan da candan türediği için o da) oyun saatinin
## TIME_HEALTH_GROWTH_START'ı geçtiği her dakika için +%1 - 25. dakikada ~+%22. Bosslar hariç (apply_boss_stats
## bu fonksiyonu çağırmaz; boss canı kullanıcı tarafından defalarca ayrıca ayarlandı).
const TIME_HEALTH_GROWTH_MIN_TIER := 3
const TIME_HEALTH_GROWTH_START := 200.0 ## sn - Kademe 3'ün nominal başlangıcı (2 x tier_duration)
const TIME_HEALTH_GROWTH_PER_MIN := 0.01
## Kullanıcı isteği: "ileri kademedeki yaratıkların hareket hızını arttır" -
## eskiden Kademe hareket hızını HİÇ etkilemiyordu (sadece can/hasar
## ölçekleniyordu). Doğrusal, ölçülü bir artış - Kademe 15'te taban hızın
## ~%28 üstünde (steps=14 × %2), erken Kademelerde neredeyse fark edilmez.
const TIER_SPEED_RAMP_LINEAR := 0.02 ## +2%/Kademe (Kademe 1 üstü)

## Drives an overhead health/shield bar (see get_overhead_bar_offset) -
## artık SADECE bosslarda değil, TÜM yaratıklarda var (kullanıcı isteği:
## "hasar alan yaratığın üstünde can ve kalkan barı görünmeli"). Bosslarda
## kalıcı görünür (bkz. set_overhead_bar_always_visible/enemy_spawner.gd
## _attach_boss_bar), normal yaratıklarda ise SADECE hasar aldıktan sonra
## belirip 1 saniye hasarsız kalınca otomatik kayboluyor (bkz.
## _show_overhead_bar/OVERHEAD_BAR_HIDE_DELAY).
signal health_changed(current, max_value)
signal item_shield_changed(current, max_value)

var _overhead_bar: Node2D = null
var _overhead_bar_always_visible: bool = false
var _overhead_bar_hide_timer: float = 0.0
const OVERHEAD_BAR_HIDE_DELAY := 1.0

# Row index per facing direction, in the down/up/left/right grid layout.
const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3

## IDLE sona eklendi (mevcut sayısal değerler değişmesin diye).
## HURT artık hiç girilmiyor (kullanıcı isteğiyle kaldırıldı, bkz. _apply_damage) -
## değer sırası değişmesin diye enum'da duruyor.
enum State { WALK, HURT, ATTACK, DEATH, IDLE }

var health: float
var is_dead: bool = false
## DÜZELTME: network_manager.gd (request_enemy_damage) ve enemy_spawner.gd
## (_sync_enemy_positions) bu alanı ZATEN gönderiyordu (Korsan'ın "öldürdüğün
## düşman başına altın" pasifi için - bkz. o dosyalardaki last_attacker_
## peer_id yorumları) ama burada değişken hiç TANIMLANMAMIŞTI ve take_damage_
## host()/update_network_state() da bu ekstra parametreyi kabul etmiyordu -
## yani her katılımcı vuruşunda/senkron tikinde "too many arguments" hatası
## fırlatılıp o RPC çağrısı tamamen BAŞARISIZ oluyordu (hasar hiç işlenmiyor,
## can/ölüm senkronu hiç uygulanmıyordu) - katılımcıların yaratıkları
## göremeyip oyunun bozulmasının asıl nedeni muhtemelen buydu.
var last_attacker_peer_id: int = 0

## Ruhani Yetenek "Savaş Şevki"nin infaz kontrolü (bkz. _apply_damage() içindeki kullanımı) - "bu isabeti
## verenin seçtiği ruhani yetenek Savaş Şevki mi" sorusuna cevap verir. GameManager.selected_spiritual HER
## İSTEMCİDE SADECE KENDİ SEÇİMİNİ bilir (kasıtlı olarak ağa gitmez, bkz. lobby_menu.gd notu) - bu yüzden üç
## durum var: (1) tek oyunculu ya da vuran BU makinenin kendi oyuncusuysa (host kendi vuruşunu işliyor)
## doğrudan yerel oyuncuya sor; (2) vuran BAŞKA bir peer'sa (host bir istemcinin isabetini işliyor) o peer'ın
## RemotePlayer kuklasındaki senkronize bayrağa bak (bkz. main.gd extra dict "has_savas_sevki",
## remote_player.gd has_savas_sevki).
static var _local_savas_frame: int = -1
static var _local_savas_cached: bool = false

func _attacker_has_savas_sevki() -> bool:
	var local_id: int = multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0
	if last_attacker_peer_id <= 0 or last_attacker_peer_id == local_id or not NetworkManager.is_multiplayer_active:
		## PERF: yerel oyuncunun cevabı kare başına bir kez soruluyor (alan
		## hasarında 200 vuruşun her biri için ayrı grup araması + çağrı yerine).
		var f: int = Engine.get_physics_frames()
		if f != _local_savas_frame:
			_local_savas_frame = f
			var local_p: Node = get_tree().get_first_node_in_group("player")
			_local_savas_cached = local_p != null and local_p.has_method("has_savas_sevki") and local_p.call("has_savas_sevki") == true
		return _local_savas_cached
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == last_attacker_peer_id:
			return rp.get("has_savas_sevki") == true
	return false


var _contact_timer: float = 0.0
var _player_in_hit_area: Node2D = null
var _frame_time: float = 0.0
var _flip_h: bool = false
var _sprite_row: int = ROW_DOWN

var _state: int = State.WALK
var _state_duration: float = 0.0

## --- Hareket edip etmediğine göre WALK <-> IDLE (bkz. idle_texture üstündeki not) ---
## Hareket, hem host'ta hem istemci (puppet) dalında AYNI şekilde GERÇEK yer değiştirmeden
## ölçülür: donma/kök/sersemleme, duvara dayanma, min_separation'da bekleme, hedefsizken
## rastgele dolaşmadaki duraklamalar hepsi tek kuralla "durdu" sayılır.
const IDLE_SPEED_THRESHOLD := 6.0 ## px/sn: bunun altı "yürümüyor"
const IDLE_ENTER_DELAY := 0.12 ## sn: kısa duraksamalarda pozun titremesin diye bu kadar durunca IDLE
const IDLE_SPEED_SMOOTHING := 20.0 ## hız ölçümünün yumuşatma katsayısı (paket/kare gürültüsüne karşı)
var _loco_prev_pos: Vector2 = Vector2.ZERO
var _loco_initialized: bool = false
var _loco_speed: float = 0.0
var _idle_timer: float = 0.0

const DamageNumbersScript := preload("res://scripts/damage_numbers.gd")
const XpOrb := preload("res://scenes/xp_orb.tscn")
const GoldDrop := preload("res://scenes/gold_drop.tscn")
const FoodDrop := preload("res://scenes/food_drop.tscn")
const ChestDropScene := preload("res://scenes/chest_drop.tscn")
## BUG DÜZELTMESİ (kullanıcı bildirimi: "oyunda hiç mıknatıs düşmüyor") - kök
## neden bulundu: magnet_drop.gd'nin kendi dosya başı yorumu "bkz. enemy.gd
## _drop_magnet()" diyordu ama bu fonksiyon dosyada HİÇ yoktu (muhtemelen bir
## önceki düzenlemede kayboldu) - yaratıklar hiçbir zaman mıknatıs düşürecek
## bir kod yoluna sahip değildi. Aşağıdaki MagnetDrop/magnet_chance/
## _drop_magnet() üçlüsü _drop_food() ile BİREBİR AYNI desen kullanılarak
## yeniden eklendi.
const MagnetDrop := preload("res://scenes/magnet_drop.tscn")

## Çok hızlı ateş eden silahlerle (yüksek ateş hızı) art arda gelen vuruşlar
## ayrı ayrı hasar kutucukları olarak üst üste yığılıp "hasar sayıları hızlı
## hızlı yukarı/aşağı gidiyor ve hiç görünmüyor" görüntüsü vermesin diye
## (bkz. kullanıcı bildirimi) - önceki kutucuk hâlâ ekranda (henüz solup
## yok olmadıysa) YENİ bir vuruş asla yeni bir kutucuk açmaz, hep AYNI
## kutucuğun üzerine toplanır - bu yüzden aynı anda en fazla TEK bir hasar
## kutucuğu var olabilir (iki ayrı kutucuğun farklı yükseklikte görünüp
## "biri yukarı biri aşağı" hissi vermesi mümkün değil). O kutucuğun kendi
## yükselişi (RISE) da sadece İLK vuruşta bir kez oynar, sonraki
## toplamalarda tekrar tetiklenmez - bkz. _spawn_floating_text.
## Kutucuk artık ayrı bir sahne değil, DamageNumbers'taki bir kayıt (bkz.
## scripts/damage_numbers.gd) - burada sadece o kaydın kimliği tutuluyor.
var _floating_text_id: int = 0
var _floating_text_total: int = 0

@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var frame_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hit_area: Area2D = get_node_or_null("HitArea")
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")

## Body block mesafesi için önceden hesaplanmış gövde yarıçapı - her frame
## shape'e erişmek yerine _ready()'de bir kere okunuyor.
var _body_radius: float = 20.0
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false
## DÜZELTME (kullanıcı bildirimi: "yaratıklar bianda durup bianda hareket
## ediyor lag var hala katılımcılarda, üstelik yaratık kalabalığı bile
## yokken oluyor bu"): eskiden katılımcı ekranında yaratık SADECE en son
## alınan _network_target_position'a doğru sabit bir hızla (lerp) kayıyordu.
## Relay'in senkron paketleri (bkz. enemy_spawner.gd _sync_enemy_positions,
## "unreliable", ~0.15sn'de bir) DÜZENLİ arayla gelmiyor - bir paket
## gecikir/kaybolursa (ağ jitter'ı, salt yaratık sayısıyla ilgisi yok)
## yaratık bir SONRAKİ paket gelene kadar TAMAMEN donuk kalıyor, paket
## gelince de (lerp hızı zaten yüksek, ~18.0) aradaki farkı BİRDEN
## kapatıyordu - tam "birden duruyor, birden hareket ediyor" hissi bu
## ikisinin toplamıydı. Artık iki paket arasındaki GERÇEK zamandan
## (_network_time_since_update) türetilen bir hız tahminiyle (_network_
## velocity) hedef konum sürekli "ölü hesaplama" (dead reckoning) ile
## ileri taşınıyor - yeni paket gelmese bile yaratık son bilinen yönünde
## akıcı şekilde hareket etmeye devam ediyor, gerçek paket gelince hem
## hedef hem hız anında güncel veriyle düzeltiliyor.
var _network_velocity: Vector2 = Vector2.ZERO
var _network_time_since_update: float = 0.0

## Şovalye (Paladin) TEMEL yeteneği "Kışkırtma" tarafından ayarlanır (bkz.
## player.gd _skill_paladin_taunt/apply_taunt) - sıfırın üstündeyken is_ranged
## yaratıklar bile normal "uzak dur" davranışını bırakıp üstüne yürür VE hedef
## seçimi _taunt_target'a (kışkırtan oyuncu) kilitlenir (bkz. _get_target_player/
## _apply_aggro_overrides). Yalnızca host/tek oyunculuda anlamlı (yaratık AI'ı
## host'ta çalışır) - client'taki kuklalarda hiç ilerlemez.
var _taunt_timer: float = 0.0
var _taunt_target: Node2D = null
## Kışkırtma göstergesi (başın üstünde öfke damarı, kullanıcı isteği 2026-09-25) - korku göstergesiyle AYNI yaşam döngüsü:
## host/tek oyunculu karar verir, broadcast_enemy_vfx "taunt_start"/"taunt_stop" ile yayınlar (bkz. _set_taunt_visual).
const TauntStatusFxScene := preload("res://scenes/fx_taunt_status.tscn")
var _taunt_status_fx: Node2D = null


## Every enemy gets a LITTLE tougher the longer the run has been going, on
## top of the enemy-tier unlocks in enemy_spawner.gd. Kullanıcı isteğiyle
## ("global time scaling oyunun dengesini bozuyor") bu sürekli/global artış
## artık neredeyse tamamen kısıldı (~dakikada %1) - oyunun asıl güç eğrisi
## artık SADECE apply_tier_scaling()'den (Kademe değiştiğinde adım adım
## atlayan) geliyor, bu ikisi arasında sürekli/görünmez bir tırmanma yok.
const DIFFICULTY_HEALTH_RAMP := 0.00017 ## ~%1.0/dakika (eskiden 0.0016 = ~%9.6/dakika)
const DIFFICULTY_DAMAGE_RAMP := 0.00012 ## ~%0.7/dakika (eskiden 0.0004 = ~%2.4/dakika)


func _apply_difficulty_scaling() -> void:
	var t: float = GameManager.game_time
	if t <= 0.0:
		return
	max_health *= 1.0 + t * DIFFICULTY_HEALTH_RAMP
	contact_damage *= 1.0 + t * DIFFICULTY_DAMAGE_RAMP


## Yakından vuran bir yaratık oyuncuya her hasar verdiğinde çağrılır - bkz.
## MELEE_HIT_RECOIL notu. weapon.gd/projectile.gd'deki _apply_knockback ile
## aynı basit "hedeften uzağa doğru pozisyonu kaydır" mantığı kullanılıyor.
## Kullanıcı isteği: "kalkan yokken çarpınca itilmesinler, sadece kalkan
## varken itilecekler" - bu yüzden artık SADECE oyuncunun aktif bir kalkanı
## (item_shield_hp > 0) varken çağrılıyor, bkz. çağrı yeri (_physics_process).
## player.gd _skill_paladin_taunt() menzildeki her yaratıkta bunu çağırır -
## var olan bir kışkırtma varsa süreyi UZATIR, kısaltmaz (max ile).
## DÜZELTME (kullanıcı isteği: "şovalye adamın E yeteneğini aktifleştirdiğinde
## etrafındaki yaratıkların agrosunu 5 saniye boyunca kendine çekmelidir"):
## eskiden bu fonksiyon SADECE _taunt_timer'ı ayarlıyordu (menzilli davranışı) -
## kimi hedef aldığı hiç değişmiyordu; üstelik yaratık AI'ı host'ta çalıştığı
## için host olmayan bir Şovalye'nin çağrısı kukla yaratığa gidip kayboluyordu.
## Artık kışkırtan oyuncu (taunter) hatırlanıyor (bkz. _apply_aggro_overrides) ve
## client'tan gelen çağrı apply_root/apply_fear ile AYNI yolla host'a taşınıyor
## (bkz. network_manager.gd request_enemy_effect "taunt" - kışkırtanın peer id'si
## param2 olarak gidiyor, host oyuncu node'unu oradan bulur).
func apply_taunt(duration: float, taunter: Node2D = null) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			var taunter_peer: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
			if taunter != null and is_instance_valid(taunter) and "peer_id" in taunter:
				taunter_peer = int(taunter.peer_id)
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "taunt", duration, float(taunter_peer), 0.0)
		return
	_taunt_timer = max(_taunt_timer, duration)
	if taunter != null and is_instance_valid(taunter):
		_taunt_target = taunter
	_set_taunt_visual(true, _taunt_timer)


## Kışkırtma göstergesi: gösterge kendi süresiyle söner (fx_taunt_status.gd setup); kışkırtan ölür/hedef dışı kalırsa
## (_apply_aggro_overrides) erken kaldırılır. Her kışkırtmada (Şovalye Q'su, 25sn'de bir) yayınlanır - yenilemede süre
## uzadığı için uzak kopyaların da güncel süreyi alması gerekir, trafik önemsiz.
func _set_taunt_visual(on: bool, duration: float = 0.0) -> void:
	if on:
		_spawn_taunt_status_fx(duration)
	else:
		_remove_taunt_status_fx()
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			if on:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "taunt_start", {"duration": duration})
			else:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "taunt_stop")


func _spawn_taunt_status_fx(duration: float) -> void:
	if is_dead:
		return
	if not _taunt_status_fx or not is_instance_valid(_taunt_status_fx):
		_taunt_status_fx = TauntStatusFxScene.instantiate()
		add_child(_taunt_status_fx)
	if _taunt_status_fx.has_method("setup"):
		_taunt_status_fx.setup(duration)


func _remove_taunt_status_fx() -> void:
	if _taunt_status_fx and is_instance_valid(_taunt_status_fx):
		_taunt_status_fx.queue_free()
	_taunt_status_fx = null


## Kullanıcı isteği: yakın dövüşçülerin hasarı artık menzile girer girmez
## ANINDA değil, saldırı animasyonu başladıktan kısa bir süre sonra
## uygulanıyor - gerçek bir "vuruş anı" hissi için (bkz. çağrı yeri).
## Gecikme sırasında oyuncu kaçmış/ölmüş/enemy ölmüş olabilir, hepsi burada
## tekrar kontrol ediliyor - "havaya yumruk atıp yine de hasar verme" olmasın.
func _schedule_melee_hit(delay: float, target_player: Node) -> void:
	await get_tree().create_timer(delay).timeout
	if is_dead or not is_instance_valid(target_player):
		return
	if not target_player.has_method("take_damage"):
		return
	## Korkmuş yaratık hasar veremez (Necromancer ULTİ: "korkan düşmanlar ... hasar veremez") - saldırı başladıktan hemen
	## sonra korkutulduysa zamanlanmış vuruş da iptal.
	if is_feared:
		return
	## Necromancer yaratıkları (player_allies) hasarı KENDİ yakın-temas tikleriyle alır (skeleton_pet.gd/golem_pet.gd
	## _process_incoming_damage - sahibinin istemcisinde, yani çok oyunculuda da doğru yerde). Buradan da vurulursa tek
	## oyunculuda çift hasar olur, çok oyunculuda ise host'taki kozmetik kopyaya vurulur - yaratık saldırı animasyonunu
	## yapar ama hasarı yalnızca o tik verir.
	if target_player.is_in_group("player_allies"):
		return
	## DÜZELTME (kullanıcı bildirimi: "assasin çocuk görünmezken yaratıklara
	## dokununca hasar alabiliyor, sadece yaratıkların skillerinden hasar
	## alabilmeli") - vuruş çağrıldığı anda (bkz. _physics_process'teki
	## player_is_invisible kontrolü) hedef görünürdü, ama bu fonksiyon
	## en az 1 kare (delay=0 olsa bile create_timer bir kare bekletir)
	## SONRA çalışıyor - hedef bu arada görünmezliğe geçmiş olabilir. Temas
	## hasarı (bu fonksiyon) burada TEKRAR kontrol edip iptal ediyor;
	## yaratıkların yetenek/mermi hasarları bu kontrolden BAĞIMSIZ, onlar
	## görünmezken de isabet edebilmeye devam ediyor (istek sadece temas
	## hasarıyla ilgiliydi).
	var target_is_invisible: bool = (target_player.has_method("is_invisible_now") and target_player.is_invisible_now()) \
		or (target_player.has_method("is_indoors_now") and target_player.is_indoors_now()) \
		or (target_player.has_method("is_in_merchant_zone_now") and target_player.is_in_merchant_zone_now())
	if target_is_invisible:
		return
	var d: float = global_position.distance_to(target_player.global_position)
	## true_contact_separation _physics_process içinde yerel bir değişken -
	## burada aynı formülle (bkz. GameManager.BODY_BLOCK_SCALE notu) yeniden
	## hesaplanıyor.
	var true_contact_separation_now: float = (_body_radius + PLAYER_BODY_RADIUS) * GameManager.BODY_BLOCK_SCALE
	if d > true_contact_separation_now + 40.0:
		return
	target_player.take_damage(contact_damage, self)
	_apply_mutual_bounce(target_player)


## DÜZELTME (kullanıcı isteği: "oyunda bir düşman bize hasar verdiğinde
## karakterin itilmesini kaldır. karakterler hasar alınca bundan sonra
## itilmeyecek... onlar bizi asla itemez") - eskiden "mutual" (karşılıklı)
## bir sekme/itiş uyguluyordu: yaratık isabet ettiğinde HEM kendisi HEM DE
## oyuncu ters yönlere itiliyordu. Artık SADECE yaratık kendi tarafında
## sekiyor (vuruşun "ağırlığı" hissi için) - oyuncu tarafı tamamen
## kaldırıldı, isim yanıltıcı olmasın diye "mutual" değil.
func _apply_mutual_bounce(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (global_position - target.global_position).normalized()
	if dir.length() < 0.1:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	const BOUNCE_FORCE := 140.0
	apply_knockback_force(dir, BOUNCE_FORCE)


func _apply_melee_recoil(target: Node2D) -> void:
	_apply_mutual_bounce(target)



## DÜZELTME (kullanıcı bildirimi: "Bossların altın düşürme oranı hala çok
## bozuk, %92 azalt düşen expyi de %92 azalt") - kök neden BULUNDU: bu oranlar
## enemy_spawner.gd _apply_global_buff()'ta AYRI, BAĞIMSIZ bir kopya (0.34/
## 0.09/0.14 - iki tur ÖNCEKİ, güncellenmemiş değerler) olarak DUPLICATE
## edilmişti - apply_boss_stats() burada güncellendiğinde o kopya hiç
## değişmiyordu VE _apply_global_buff() apply_boss_stats()'tan SONRA çalışıp
## xp_value/gold_min/gold_max'ı KENDİ eski oranlarıyla ÜZERİNE YAZIYORDU
## (bkz. o dosyadaki yorum) - yani buradaki önceki azaltmalar (%50/%70)
## oyunda HİÇBİR ZAMAN gerçekten uygulanmıyordu. TAM OLARAK CLAUDE.md'nin
## uyardığı "aynı bilgiye iki ayrı yerden referans" hata sınıfı (VFX/animasyon
## değil ama BİREBİR aynı kök neden) - artık TEK kaynak burada, enemy_
## spawner.gd bu üç sabiti (Enemy.BOSS_*_HEALTH_RATIO) DOĞRUDAN okuyor, kendi
## kopyasını tutmuyor.
const BOSS_XP_HEALTH_RATIO := 0.02
const BOSS_GOLD_MIN_HEALTH_RATIO := 0.00336
const BOSS_GOLD_MAX_HEALTH_RATIO := 0.00528

## Called by enemy_spawner.gd right after instantiating a creature as a
## "Boss Kademe" or "Final Kademe" encounter. Unlike a plain multiplier, this
## OVERRIDES health/damage with numbers the spawner already computed fresh
## for the tier the boss event belongs to (see enemy_spawner.gd's
## _spawn_boss_group) - that keeps a boss's power tied to when it appears as
## a boss, independent of whatever P that same creature id normally uses as
## a regular-tier spawn elsewhere. Must be called after the node is already
## in the tree (so @onready vars like body_collision/hit_area are ready).
## DÜZELTME: bosslar apply_tier_scaling() çağrılmadığı için _current_tier
## HİÇBİR ZAMAN varsayılan 1'den ayrılmıyordu - bu da _get_orb_tier_from_
## enemy_tier()/_get_chest_tier_from_enemy_tier() gibi Kademe-tabanlı ödül
## seçimlerinin en güçlü yaratıklarda (bosslar) her zaman EN DÜŞÜK tier'ı
## seçmesine yol açardı (tam tersi istenen). Artık enemy_spawner.gd zaten
## elinde olan boss Kademe numarasını buraya da iletiyor.
func apply_boss_stats(new_max_health: float, new_damage: float, scale_mult: float, tier: int = -1) -> void:
	is_boss = true
	if tier > 0:
		_current_tier = tier
	max_health = new_max_health
	health = max_health
	contact_damage = new_damage
	if ranged_damage > 0.0 or is_ranged:
		ranged_damage = new_damage
	## DÜZELTME (kullanıcı isteği: "bosslar öldürmek ödüllendirici değil,
	## düşürdüğü kaynaklar artmalı") - bir önceki turda xp %22->%34,
	## gold_min %5->%9, gold_max %8->%14 yapılmıştı; şimdi tekrar belirgin
	## şekilde arttırıldı (xp %34->%50, gold_min %9->%14, gold_max %14->%22).
	## Bu değerler ayrıca enemy_spawner.gd _apply_global_buff() içinde, boss
	## canı SAVUNMA çarpanıyla (GLOBAL_DEFENSE_BUFF + multiplayer_defense_mult)
	## daha da büyütüldükten SONRA aynı oranlarla yeniden hesaplanıyor.
	## DÜZELTME (kullanıcı isteği: "bosslardan düşen exp oranını %50 azalt") -
	## 0.50 -> 0.25 (×0.5). SONRAKİ TUR (bkz. BOSS_XP_HEALTH_RATIO üstündeki
	## kök neden notu) - 0.25 -> 0.02 (×0.08, mevcut değerin %92'si düşüldü).
	xp_value = round(new_max_health * BOSS_XP_HEALTH_RATIO)
	## DÜZELTME (kullanıcı isteği: "bosslardan düşen altını %70 azalt") -
	## 0.14/0.22 -> 0.042/0.066 (×0.3). SONRAKİ TUR (bkz. BOSS_XP_HEALTH_RATIO
	## üstündeki kök neden notu) - 0.042/0.066 -> 0.00336/0.00528 (×0.08).
	gold_min = max(1, int(new_max_health * BOSS_GOLD_MIN_HEALTH_RATIO))
	gold_max = max(gold_min + 1, int(new_max_health * BOSS_GOLD_MAX_HEALTH_RATIO))
	gold_chance = 1.0
	health_changed.emit(health, max_health)

	if frame_sprite:
		frame_sprite.scale *= scale_mult
	if anim_sprite:
		anim_sprite.scale *= scale_mult
	if body_collision and body_collision.shape:
		var shape = body_collision.shape.duplicate()
		shape.radius *= scale_mult
		body_collision.shape = shape
		_body_radius = shape.radius ## body block mesafesi boss boyutuyla senkron kalsın
	if hit_area:
		var hit_collision: CollisionShape2D = hit_area.get_node_or_null("HitCollision")
		if hit_collision and hit_collision.shape:
			var hshape = hit_collision.shape.duplicate()
			hshape.radius *= scale_mult
			hit_collision.shape = hshape


## Called by enemy_spawner.gd right after a regular (non-boss) spawn, with
## the Kademe (1-15) the run is currently in. Bosses skip this - their
## health/damage is set fresh by apply_boss_stats() instead, using the boss
## event's own tier number the same way health/damage already are.
##
## Health/damage ramp is quadratic in `steps` (Kademe-1), on purpose: early
## Kademeler barely move (Kademe 2 is only a few % tougher) but late Kademeler
## pull away hard (Kademe 15 ends up multiple times tougher than Kademe 1),
## since _apply_difficulty_scaling()'s raw-time ramp no longer carries most of
## that load.
func apply_tier_scaling(tier: int) -> void:
	_current_tier = tier
	var steps: int = max(tier - 1, 0)
	if steps <= 0:
		return
	var health_mult: float = 1.0 + steps * TIER_HEALTH_RAMP_LINEAR + steps * steps * TIER_HEALTH_RAMP_QUAD
	var damage_mult: float = 1.0 + steps * TIER_DAMAGE_RAMP_LINEAR + steps * steps * TIER_DAMAGE_RAMP_QUAD
	## bkz. TIER_DAMAGE_RAMP_LATE_* üstündeki not - (steps - 1) Kademe 2'de 0, yani Kademe 1-2 hiç etkilenmez.
	var late_steps: int = max(steps - 1, 0)
	damage_mult += late_steps * TIER_DAMAGE_RAMP_LATE_LINEAR + late_steps * late_steps * TIER_DAMAGE_RAMP_LATE_QUAD
	if tier >= TIME_HEALTH_GROWTH_MIN_TIER:
		health_mult *= 1.0 + TIME_HEALTH_GROWTH_PER_MIN * maxf(0.0, GameManager.game_time - TIME_HEALTH_GROWTH_START) / 60.0
	max_health *= health_mult
	health = max_health
	contact_damage *= damage_mult
	if ranged_damage > 0.0:
		ranged_damage *= damage_mult
	## bkz. TIER_SPEED_RAMP_LINEAR üstündeki DÜZELTME notu.
	speed *= 1.0 + steps * TIER_SPEED_RAMP_LINEAR
	health_changed.emit(health, max_health)


## Grants (or replaces) this enemy's item shield. protection is the fraction
## of each hit the shield's own HP pool eats (SHIELD_PROTECTION for Kademe 3+
## regulars, BOSS_SHIELD_PROTECTION - şu an 0.85 - for bosses); shield_ratio
## sizes the pool as a fraction of the enemy's CURRENT max_health, so calling
## this after apply_boss_stats / apply_tier_scaling means the shield already
## reflects tier-scaled health.
func enable_item_shield(protection: float, shield_ratio: float) -> void:
	shield_protection = protection
	item_shield_max = max_health * shield_ratio
	item_shield_hp = item_shield_max
	item_shield_changed.emit(item_shield_hp, item_shield_max)


func _process_item_shield(delta: float) -> void:
	if item_shield_max <= 0.0:
		return
	if item_shield_regen_delay > 0.0:
		item_shield_regen_delay -= delta
		return
	if item_shield_hp < item_shield_max:
		item_shield_hp = min(item_shield_max, item_shield_hp + item_shield_max * ITEM_SHIELD_REGEN_RATE * delta)
		item_shield_changed.emit(item_shield_hp, item_shield_max)


## Tüftüf'ün dart'ı isabet ettiğinde çağrılır (bkz. projectile.gd) - bkz. yukarıdaki
## "yük" modeli notu. dps_per_stack: bu yükün saniyelik hasarı, max_stacks: bu
## düşmandaki toplam yük üst sınırı, duration: yükün ömrü (sn). (Parametreler
## network_manager.gd request_enemy_effect "poison" üzerinden aynı sırayla,
## float olarak taşınıyor.)
func apply_poison(dps_per_stack: float, max_stacks: float, duration: float) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "poison", dps_per_stack, max_stacks, duration)
		return
	var had_elements: Dictionary = {} if _in_element_apply else _element_snapshot()
	_apply_poison_stack(dps_per_stack, max_stacks, duration)
	_legacy_element_touched("zehir", had_elements)


func _apply_poison_stack(dps_per_stack: float, max_stacks: float, duration: float) -> void:
	var stack_cap: int = maxi(1, int(round(max_stacks)))
	if _poison_stack_time.size() >= stack_cap:
		## Üst sınırda: en eski (en az ömrü kalan) yükü tazele.
		var oldest: int = 0
		for i in range(1, _poison_stack_time.size()):
			if _poison_stack_time[i] < _poison_stack_time[oldest]:
				oldest = i
		_poison_stack_time[oldest] = duration
		_poison_stack_dps[oldest] = dps_per_stack
	else:
		if _poison_stack_time.is_empty():
			_poison_tick_timer = POISON_TICK_INTERVAL
		_poison_stack_time.append(duration)
		_poison_stack_dps.append(dps_per_stack)
	if not _poison_status_fx or not is_instance_valid(_poison_status_fx):
		_poison_status_fx = PoisonStatusFxScene.instantiate()
		_poison_status_fx.position = Vector2(0, get_overhead_bar_offset() * 0.5)
		add_child(_poison_status_fx)
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "poison_start")


## Public wrappers for network VFX sync — called by broadcast_enemy_vfx RPC.
func _spawn_poison_status_fx() -> void:
	if not _poison_status_fx or not is_instance_valid(_poison_status_fx):
		_poison_status_fx = PoisonStatusFxScene.instantiate()
		_poison_status_fx.position = Vector2(0, get_overhead_bar_offset() * 0.5)
		add_child(_poison_status_fx)

func _remove_poison_status_fx() -> void:
	if _poison_status_fx and is_instance_valid(_poison_status_fx):
		_poison_status_fx.queue_free()
		_poison_status_fx = null


## Ağ (broadcast_enemy_vfx "burn_start"/"burn_stop") tarafından çağrılır -
## poison'ın aynı isimli sarmalayıcılarıyla BİREBİR aynı desen: yakma
## SİMÜLASYONUNA dokunmaz, sadece görseli kurar/kaldırır.
func _spawn_burn_status_fx() -> void:
	if not _burn_status_fx or not is_instance_valid(_burn_status_fx):
		_burn_status_fx = BurnStatusFxScene.instantiate()
		## DÜZELTME (kullanıcı isteği: "efekt sistemi" - yaratıklar yanarken
		## VÜCUTLARINDA ateş/duman olmalı) - eskiden overhead_bar'a doğru
		## yukarı kaydırılıyordu, artık gövde merkezinde (bkz. fx_burn_status.gd
		## - iki katman kendi içinde doğru hizalanıyor).
		_burn_status_fx.position = Vector2.ZERO
		add_child(_burn_status_fx)

func _remove_burn_status_fx() -> void:
	if _burn_status_fx and is_instance_valid(_burn_status_fx):
		_burn_status_fx.queue_free()
		_burn_status_fx = null


## Ağ (broadcast_enemy_vfx "slow_start"/"slow_stop") tarafından çağrılır -
## yavaşlatma simülasyonuna DOKUNMAZ, sadece göstergeyi kurar/tazeler.
## fx_duration, istemcinin kendi başına sayacağı görsel ömürdür (host'un
## yenileme süresiyle aynı gönderilir, bkz. enemy.gd apply_slow).
##
## DÜZELTME (kullanıcı isteği: "karakterler slow yiyince üstlerinde çıkan
## mor şeyi kaldır") - mor girdap ikonu (fx_void_slow_status.tscn) artık
## gösterilmiyor. Yavaşlatma EFEKTİNİN kendisi (apply_slow/_process_slow,
## hareket hızı azaltması) tamamen aynı şekilde çalışmaya devam ediyor -
## kaldırılan SADECE bu görsel gösterge. Tek chokepoint burada olduğu için
## (apply_slow'un yerel çağrısı VE ağdan gelen "slow_start" ikisi de bu
## fonksiyona düşüyor) başka hiçbir yeri değiştirmeye gerek yok.
func _spawn_slow_status_fx(_fx_duration: float = SLOW_FX_DEFAULT_DURATION) -> void:
	return

func _remove_slow_status_fx() -> void:
	_slow_fx_time_left = 0.0
	if _slow_status_fx and is_instance_valid(_slow_status_fx):
		_slow_status_fx.queue_free()
		_slow_status_fx = null

## DÜZELTME (Büyücü Kız'ın "Don Nova" temel yeteneği): süre artık sabit
## FREEZE_DURATION değil, isteğe bağlı dışarıdan verilebiliyor - Buz
## Asası'nın soğuma zinciri (apply_chill/_start_freeze) hâlâ argümansız
## çağırıp varsayılanı (FREEZE_DURATION) kullanıyor, apply_freeze_full ise
## kendi süresini (6sn) buradan geçiriyor.
func _spawn_freeze_status_fx(duration: float = FREEZE_DURATION) -> void:
	if not _freeze_status_fx or not is_instance_valid(_freeze_status_fx):
		_freeze_status_fx = FreezeStatusFxScene.instantiate()
		add_child(_freeze_status_fx)
	if _freeze_status_fx.has_method("setup"):
		## DÜZELTME (kullanıcı isteği: "efekt sistemi" - donma efekti yaratığın
		## gövdesini doğru kaplasın) - _body_radius de veriliyor, yeni fx_ice_
		## freeze_status.gd bunu kullanarak gövde boyutuna göre ölçekleniyor.
		_freeze_status_fx.setup(duration, _body_radius)

func _remove_freeze_status_fx() -> void:
	if _freeze_status_fx and is_instance_valid(_freeze_status_fx):
		_freeze_status_fx.queue_free()
		_freeze_status_fx = null


func _spawn_stun_status_fx(duration: float) -> void:
	if not _stun_status_fx or not is_instance_valid(_stun_status_fx):
		_stun_status_fx = StunStatusFxScene.instantiate()
		add_child(_stun_status_fx)
		if _stun_status_fx.has_method("setup"):
			_stun_status_fx.setup(duration)

func _remove_stun_status_fx() -> void:
	if _stun_status_fx and is_instance_valid(_stun_status_fx):
		_stun_status_fx.queue_free()
		_stun_status_fx = null


## Shaman pasifi (Totem Auraları): "totemlerine yakın olan dostların SİLAH
## saldırıları düşmanlara yakma etkisi bırakır" - vuran (ATTACKER, yani bu
## vuruşu tetikleyen bu client'ın kendi oyuncusu) herhangi bir Shaman
## totemine yakınsa (kendi totemi ya da bir müttefiğin totemi - bkz.
## totem_base.gd "shaman_totems" grubu, kozmetik kopyalar da bu grupta),
## isabet ettiği düşmana yakma bırakır.
##
## DÜZELTME (kullanıcı isteği: "yetenekler şamanın pasifinden gelen buffla
## etkinleşmemeli, sadece her silahın her saldırısı başına 1 yaratıkta
## çalışacak şekilde olmalı") - eskiden bu kontrol take_damage()'ın genel
## chokepoint'indeydi, yani totem/ability/pet hasarı dahil HER take_damage()
## çağrısı yakma tetikliyordu (ör. Şaman'ın kendi Saldırı Totemi her zaman
## kendi totem yarıçapının içinde olduğu için HER totem vuruşu da otomatik
## yakma bırakıyordu - istenmeyen bir "double dip"). Artık bu fonksiyon
## take_damage()'tan ÇAĞRILMIYOR - SADECE gerçek silah saldırısı kod
## yollarının (weapon.gd/projectile.gd/boomerang_projectile.gd/
## firework_projectile.gd) bilerek çağırdığı ayrı bir fonksiyon. "Aynı
## saldırı birden fazla düşmanı yakmasın" kuralı çağıran tarafın
## sorumluluğunda: bir "saldırı" (bir kılıç savuruşu, bir mermi, bir ışın
## tiği) kapsamında bu fonksiyon EN FAZLA 1 düşmanda başarılı (true dönene
## kadar) çağrılmalı - dönüş değeri true olunca o saldırı için durdurulmalı.
func try_shaman_weapon_burn() -> bool:
	var dealer: Node = get_tree().get_first_node_in_group("player")
	if not (dealer and "damage_bonus" in dealer and dealer is Node2D):
		return false
	for totem in get_tree().get_nodes_in_group("shaman_totems"):
		if not is_instance_valid(totem) or not (totem is Node2D):
			continue
		var totem_r: float = float(totem.get("totem_radius")) if "totem_radius" in totem else 0.0
		if totem_r <= 0.0:
			continue
		if (totem as Node2D).global_position.distance_to((dealer as Node2D).global_position) <= totem_r:
			apply_burn(float(dealer.damage_bonus) * 0.10, 3.0)
			return true
	return false


## Shaman pasifi - bkz. burn_tick_damage üstündeki yorum. apply_poison()'un
## host-forward guard'ıyla BİREBİR AYNI desen.
func apply_burn(tick_damage: float, duration: float) -> void:
	if is_dead or tick_damage <= 0.0:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "burn", tick_damage, 0.0, duration)
		return
	var had_elements: Dictionary = {} if _in_element_apply else _element_snapshot()
	## Yeni bir isabet süreyi YENİLER ama tik hasarı en güçlüsünde kalır -
	## poison'un "üst üste binmez, yenilenir" davranışıyla tutarlı.
	burn_tick_damage = max(burn_tick_damage, tick_damage)
	burn_time_left = max(burn_time_left, duration)
	if _burn_tick_timer <= 0.0:
		_burn_tick_timer = BURN_TICK_INTERVAL
	## GÖRSEL: alev hedefte zaten varsa YENİDEN oluşturulmaz (poison'daki
	## AYNI "yenilenince çoğalmasın" kuralı) - sadece ilk seferde yaratılır
	## ve host bunu diğer client'lara bir kez bildirir.
	if not _burn_status_fx or not is_instance_valid(_burn_status_fx):
		_burn_status_fx = BurnStatusFxScene.instantiate()
		## DÜZELTME (kullanıcı isteği: "efekt sistemi" - yaratıklar yanarken
		## VÜCUTLARINDA ateş/duman olmalı) - eskiden overhead_bar'a doğru
		## yukarı kaydırılıyordu, artık gövde merkezinde (bkz. fx_burn_status.gd
		## - iki katman kendi içinde doğru hizalanıyor).
		_burn_status_fx.position = Vector2.ZERO
		add_child(_burn_status_fx)
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "burn_start")
	_legacy_element_touched("yanma", had_elements)


func _process_burn(delta: float) -> void:
	if burn_time_left <= 0.0:
		return
	burn_time_left -= delta
	_burn_tick_timer -= delta
	if _burn_tick_timer <= 0.0:
		_burn_tick_timer += BURN_TICK_INTERVAL
		## Efsun yanma yığını (Alevli Ok V): 0/1 yük = eski tek tik.
		_take_dot_damage(burn_tick_damage * float(maxi(1, _burn_stacks)))
	if burn_time_left <= 0.0:
		burn_tick_damage = 0.0
		_burn_stacks = 0
		## GÖRSEL: yakma bitti - alev sprite'ı kaldırılır (poison'ın
		## _process_poison'daki AYNI temizlik deseni) ve ağa haber verilir.
		if _burn_status_fx and is_instance_valid(_burn_status_fx):
			_burn_status_fx.queue_free()
			_burn_status_fx = null
			if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
				var net_id: int = int(get_meta("network_enemy_id", 0))
				if net_id > 0:
					NetworkManager.broadcast_enemy_vfx.rpc(net_id, "burn_stop")


## Yük sayısı (sadece host/tek oyunculuda anlamlı - AI ve hasar hostta işlenir).
func get_poison_stack_count() -> int:
	return _poison_stack_time.size()


## Bu düşman şu an zehirli mi - istemcilerde de (kukla yaratıklarda) doğru
## çalışsın diye yük dizisine DEĞİL, zehir efektinin varlığına bakıyor: efekt
## host'ta apply_poison ile, kuklalarda "poison_start"/"poison_stop" yayınıyla
## (bkz. _spawn_poison_status_fx/_remove_poison_status_fx) kurulup kaldırılıyor.
## weapon.gd/remote_player.gd Tüftüf hedef seçimi (bkz. tuftuf_targeting.gd) bunu okur.
func is_poisoned() -> bool:
	return _poison_status_fx != null and is_instance_valid(_poison_status_fx)


func _process_poison(delta: float) -> void:
	if _poison_stack_time.is_empty():
		return
	## Her yük kendi süresince (kalan ömrüyle sınırlı, karenin geri kalanı hariç)
	## hasar biriktirir - böylece bir yük tam olarak poison_duration sn boyunca
	## saniyede dps verir, süre tık sınırına denk gelmese bile son kesir kaybolmaz.
	for i in range(_poison_stack_time.size() - 1, -1, -1):
		var active_dt: float = minf(delta, _poison_stack_time[i])
		_poison_damage_accum += _poison_stack_dps[i] * active_dt
		_poison_stack_time[i] -= delta
		if _poison_stack_time[i] <= 0.0:
			_poison_stack_time.remove_at(i)
			_poison_stack_dps.remove_at(i)
	_poison_tick_timer -= delta
	var all_expired: bool = _poison_stack_time.is_empty()
	if _poison_tick_timer <= 0.0:
		_poison_tick_timer += POISON_TICK_INTERVAL
		## _apply_damage() her vuruşa EN AZ 1 hasar uyguluyor (max(remaining, 1.0)) -
		## küçük bir tık (ör. tek yük x düşük saldırı gücü = 0.5) 1'e şişirilir, yani
		## zehir yazılandan 2 kat vururdu. Bu yüzden SADECE tam sayı kısmı uygulanıp
		## kesir bir sonraki tike devrediliyor - toplam hasar birikenle birebir aynı.
		var whole_damage: float = floorf(_poison_damage_accum)
		if whole_damage >= 1.0:
			_poison_damage_accum -= whole_damage
			_take_dot_damage(whole_damage, 1.0 if _poison_true else 0.0)
	if all_expired:
		## Son kesir (<1): en yakın tam sayıya yuvarlanıp uygulanır (0.5+ ise 1).
		var rest_damage: float = roundf(_poison_damage_accum)
		_poison_damage_accum = 0.0
		if rest_damage >= 1.0:
			_take_dot_damage(rest_damage, 1.0 if _poison_true else 0.0)
		if _poison_status_fx and is_instance_valid(_poison_status_fx):
			_poison_status_fx.queue_free()
			_poison_status_fx = null
			if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
				var net_id: int = int(get_meta("network_enemy_id", 0))
				if net_id > 0:
					NetworkManager.broadcast_enemy_vfx.rpc(net_id, "poison_stop")


## Tabanca'nın mermisi (projectile.gd) her isabette çağırır - ÖNCE
## get_mark_damage_mult() ile mevcut yükün bonusu o vuruşa uygulanır, SONRA bu
## çağrılıp yeni yük eklenir (bkz. projectile.gd _on_body_entered) - yani bir
## hedefin İLK isabeti hiç bonus almaz, N'inci isabeti (N-1) yük kadar alır.
func apply_mark_stack(max_stacks: int) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "mark", float(max_stacks), 0.0, 0.0)
		## ÇOK OYUNCULU DÜZELTME (2026-09-24 senkron analizi): işaretin hasar bonusu vuran istemcinin KENDİ mermisinde
		## hesaplanıyor (projectile.gd get_mark_damage_mult) ama yükler sadece host'ta tutuluyordu - istemcideki kopyada
		## mark_stacks hep 0 kalıyor, host olmayan oyuncunun Tabancası pasifinden HİÇ faydalanmıyordu. Artık istemci kendi
		## isabetlerinin yükünü yerel kopyada da tutar (süresi istemci dalında _process_mark ile düşer).
		mark_stacks = min(mark_stacks + MARK_STACKS_PER_HIT, max_stacks)
		_mark_timer = MARK_DURATION
		return
	mark_stacks = min(mark_stacks + MARK_STACKS_PER_HIT, max_stacks)
	_mark_timer = MARK_DURATION


## Şu anki yükün verdiği hasar çarpanı (1.0 = bonus yok).
func get_mark_damage_mult() -> float:
	return 1.0 + mark_stacks * MARK_PERCENT_PER_STACK


func _process_mark(delta: float) -> void:
	if mark_stacks <= 0:
		return
	_mark_timer -= delta
	if _mark_timer <= 0.0:
		mark_stacks = 0


## ================================================================ EFSUN ELEMENT SİSTEMİ (2026-09-25)
## Tasarım belgesi "Element sistemi" bölümü. Efsun davranışları (scripts/enchants/*.gd) düşmana TEK giriş noktasından
## element uygular: apply_element(tür, parametreler). Çoklu oyuncuda istemci bunu host'a yönlendirir
## (NetworkManager.request_enemy_element) - durumlar ve tepkimeler (element_reactions.gd) SADECE host'ta çözülür.
## Mevcut (efsun dışı) kaynaklar da (Buz Asası donması, Şaman yakması, Oakley zehri...) apply_poison/apply_burn/
## apply_bleed/_start_freeze'in host dalındaki kancayla (_legacy_element_touched) aynı tepkime kontrolüne girer.
const ElementReactions := preload("res://scripts/element_reactions.gd")
const EnchantFxScript := preload("res://scripts/enchant_fx.gd")
const ShockStatusFxScript := preload("res://scripts/fx_shock_status.gd")
const EnchantAreaScript := preload("res://scripts/enchant_area.gd")
const SHOCK_JUMP_RANGE := 200.0
const SHOCK_JUMP_MIN_INTERVAL_MSEC := 120
const CRACK_DAMAGE_PER_STACK := 0.10

var _reaction_cd: Dictionary = {} ## tepkime anahtarı -> tekrar tetiklenebileceği an (msec)
var _reaction_ap: float = 0.0 ## son element uygulayanın SG'si (tepkime hasarı buradan)
var _reaction_power: float = 0.0 ## son element uygulayanın Tepkime Gücü
var _reaction_peer: int = 0 ## tepkime hasarının atfedileceği oyuncu
var _in_element_apply: bool = false ## apply_element_host içinden çağrılan apply_* kancaları tepkimeyi ikinci kez çözmesin
## Şok (yeni durum): şoklu düşmana gelen DOĞRUDAN isabetin bir kısmı en yakın düşman(lar)a sıçrar.
var shock_time_left: float = 0.0
var _shock_jump: float = 0.0
var _shock_jumps: int = 1
var _shock_spark: float = 0.0
var _shock_spark_timer: float = 0.0
var _shock_ap: float = 0.0
var _shock_peer: int = 0
var _shock_death_bolt: bool = false
var _shock_fx: Node2D = null
var _shock_last_jump_msec: int = 0
## Uyku (Tüftüf Uyku Okları): sersemletme üstüne kurulu, hasar alınca bozulabilir.
var _sleep_time: float = 0.0
var _sleep_break: bool = true
var _sleep_bonus: float = 0.0
var _sleep_vuln: float = 0.0
var _sleep_wake_slow: float = 0.0
## Kafatası Kırıcı (Topuz Ağır Darbe finali): her çatlak alınan TÜM hasarı +%10 artırır.
var crack_stacks: int = 0
## Yanma yığını (Alevli Ok V): 0/1 = eski davranış, >1 tik hasarı katlanır.
var _burn_stacks: int = 0
## Tepkime bayrakları (bkz. element_reactions.gd).
var _infected: bool = false
var _conductive: bool = false
var _blood_current: bool = false
var _bleed_double_until_msec: int = 0
## Salgın / Zehirli Ok ölüm yayılımları.
var _plague: Dictionary = {}
var _plague_cough_timer: float = 2.0
var _death_poison_burst: Dictionary = {}
## Efsunların düşmana bıraktığı "ölünce / sürerken" bayrakları (element parametrelerinden, host'ta). Her biri
## {"peer": vuran, "ap": SG, ...} taşır - ölüm etkisi (_on_death_elements) hasarı ona atfeder.
var _enchant_flags: Dictionary = {}
var _bleed_interval: float = BLEED_TICK_INTERVAL ## Kanlı Hançer IV / Keskin Kenar V: 0.5
var _poison_true: bool = false ## Engerek Dişi: zehir tikleri kalkanı deler
var _mark_duration: float = MARK_DURATION
var _mark_pct: float = MARK_PERCENT_PER_STACK
var _boss_chill_required: int = BOSS_CHILL_HITS_REQUIRED
var _vuln_pct: float = 0.0 ## Harpun / Sersemletici Bomba: süreli "tüm hasardan fazla alır"
var _vuln_until_msec: int = 0
var _contagious_timer: float = 0.0
var _linger_slow: float = 0.0 ## Ebedi Kış: donma bitince yavaşlama


func apply_element(kind: String, p: Dictionary) -> void:
	if is_dead or is_ability_invisible:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_element.rpc_id(NetworkManager._host_peer_id(), net_id, kind, p)
		return
	var peer: int = multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0
	apply_element_host(kind, p, peer)


## Host (ya da tek oyunculu). attacker_peer = elementi uygulayan oyuncu (tepkime/sıçrama hasarı ona atfedilir).
func apply_element_host(kind: String, p: Dictionary, attacker_peer: int) -> void:
	if is_dead:
		return
	if p.has("ap"):
		_reaction_ap = float(p["ap"])
		_reaction_power = float(p.get("rp", 0.0))
		_reaction_peer = attacker_peer
	var had: Dictionary = _element_snapshot()
	var element: String = ""
	_in_element_apply = true
	match kind:
		"poison":
			if bool(p.get("kobra", false)):
				_kobra_strike(attacker_peer)
			var dps: float = float(p.get("dps", 1.0))
			var cap: float = float(p.get("cap", 20.0))
			var dur: float = float(p.get("dur", 10.0))
			for i in range(clampi(int(p.get("stacks", 1)), 1, 50)):
				apply_poison(dps, cap, dur)
			if p.has("plague"):
				_plague = (p["plague"] as Dictionary).duplicate()
				_plague["peer"] = attacker_peer
				_plague["dps"] = dps
				_plague["cap"] = cap
				_plague["dur"] = dur
			if int(p.get("death_burst", 0)) > 0:
				_death_poison_burst = {"stacks": int(p["death_burst"]), "dps": dps, "cap": cap, "dur": dur}
			if bool(p.get("true_dmg", false)):
				_poison_true = true
			_store_flag(p, "death_cloud", attacker_peer, {"dps": dps})
			element = "zehir"
		"burn":
			_apply_burn_stack(float(p.get("tick", 1.0)), float(p.get("dur", 3.0)), int(p.get("max_stacks", 1)))
			_store_flag(p, "burn_spread", attacker_peer, {"tick": float(p.get("tick", 1.0)), "dur": float(p.get("dur", 3.0))})
			_store_flag(p, "burn_death_blast", attacker_peer, {})
			if p.has("steam"):
				_enchant_flags["steam"] = (p["steam"] as Dictionary).duplicate()
				_enchant_flags["steam"]["peer"] = attacker_peer
			element = "yanma"
		"bleed":
			var before: int = bleed_stacks
			apply_bleed(float(p.get("tick", 1.0)), int(p.get("stacks", 1)), int(p.get("cap", 10)))
			if bool(p.get("fast", false)):
				_bleed_interval = BLEED_TICK_INTERVAL * 0.5
			_store_flag(p, "bleed_transfer", attacker_peer, {"tick": float(p.get("tick", 1.0)), "cap": int(p.get("cap", 10))})
			_store_flag(p, "bleed_death_blast", attacker_peer, {})
			_store_flag(p, "bleed_kill", attacker_peer, {})
			if bool(p.get("burst", false)) and int(bleed_stacks / 10) > int(before / 10):
				_bleed_burst(attacker_peer, float(p.get("ap", 10.0)) * float(p.get("burst_pct", 0.5)))
			element = "kanama"
		"shock":
			_apply_shock_host(p, attacker_peer)
			element = "sok"
		"freeze":
			if not is_boss:
				apply_freeze_full(float(p.get("dur", 3.0)))
			elif int(p.get("boss_hits", 0)) > 0:
				_boss_chill_required = mini(_boss_chill_required, int(p["boss_hits"]))
			if float(p.get("linger_slow", 0.0)) > 0.0:
				_linger_slow = float(p["linger_slow"])
			_store_flag(p, "contagious", attacker_peer, {})
			_store_flag(p, "frozen_shards", attacker_peer, {"freeze": bool(p.get("shards_freeze", false))})
			element = "donma"
		"shatter":
			_try_shatter(p, attacker_peer)
		"mark":
			_mark_duration = maxf(_mark_duration, float(p.get("dur", MARK_DURATION)))
			_mark_pct = maxf(_mark_pct, float(p.get("pct", MARK_PERCENT_PER_STACK)))
			var cap_m: int = int(p.get("cap", 20))
			mark_stacks = mini(mark_stacks + int(p.get("stacks", 1)), cap_m)
			_mark_timer = _mark_duration
			_store_flag(p, "decree", attacker_peer, {})
			_store_flag(p, "mark_transfer", attacker_peer, {"cap": cap_m})
			_store_flag(p, "mark_soul", attacker_peer, {})
			_store_flag(p, "mark_death_blast", attacker_peer, {})
			_check_decree()
		"vuln":
			_vuln_pct = maxf(_vuln_pct if Time.get_ticks_msec() < _vuln_until_msec else 0.0, float(p.get("pct", 0.2)))
			_vuln_until_msec = Time.get_ticks_msec() + int(float(p.get("dur", 2.0)) * 1000.0)
		"chain_bomb":
			_enchant_flags["chain_bomb"] = {"peer": attacker_peer, "ap": float(p.get("ap", 10.0)),
				"until": Time.get_ticks_msec() + int(float(p.get("dur", 0.6)) * 1000.0), "gold": float(p.get("gold", 0.03))}
		"fear":
			apply_fear_wander(float(p.get("dur", 2.0)), false)
		"root":
			if is_boss:
				apply_slow(0.9, float(p.get("dur", 2.0)) * 0.5, true)
			else:
				apply_root(float(p.get("dur", 2.0)))
		"knock":
			apply_knockback_distance(Vector2(p.get("dir", Vector2.RIGHT)), float(p.get("dist", 60.0)))
		"sleep":
			_apply_sleep_host(p)
		"crack":
			crack_stacks += maxi(1, int(p.get("stacks", 1)))
		"stun":
			apply_stun(float(p.get("dur", 0.5)))
		"slow":
			apply_slow(float(p.get("pct", 0.3)), float(p.get("dur", 2.0)), bool(p.get("boss", false)))
	_in_element_apply = false
	## "quiet": alan etkilerinin (zehir bulutu, lav...) tekrarlayan uygulaması yeni tepkime zinciri başlatmasın.
	if element != "" and not bool(p.get("quiet", false)):
		ElementReactions.resolve(self, element, had)


## Parametrede bayrak true ise ölüm/süre etkisi için saklar (vuran + SG ile).
func _store_flag(p: Dictionary, key: String, peer: int, extra: Dictionary) -> void:
	if not bool(p.get(key, false)):
		return
	var d: Dictionary = extra.duplicate()
	d["peer"] = peer
	d["ap"] = float(p.get("ap", 10.0))
	d["power"] = float(p.get("power", 1.0))
	_enchant_flags[key] = d


## Kan Şelalesi: her 10 kanama yükünde hedef patlar, patlama hasarının %5'i vurana can.
func _bleed_burst(peer: int, dmg: float) -> void:
	var tree: SceneTree = get_tree()
	var pos: Vector2 = global_position
	for v in Enemy.get_enemies_near(tree, pos, 60.0):
		if is_instance_valid(v) and not v.is_dead:
			if peer > 0:
				v.last_attacker_peer_id = peer
			v._take_dot_damage(dmg)
	_notify_enchant_owner(peer, "heal", {"amount": dmg * 0.05})
	EnchantFxScript.play(tree, "burst", pos, {"palette": "fire", "count": 14, "speed": 110.0, "life": 0.4})
	EnchantFxScript.play(tree, "ring", pos, {"radius": 60.0, "color": Color(0.9, 0.2, 0.25)})


## Ölüm Fermanı: 50+ işaretli düşman canı %15'in altına inince ölür (boss yerine bir kez büyük hasar).
func _check_decree() -> void:
	if not _enchant_flags.has("decree") or mark_stacks < 50 or is_dead or max_health <= 0.0:
		return
	if health / max_health >= 0.15:
		return
	var f: Dictionary = _enchant_flags["decree"]
	if int(f["peer"]) > 0:
		last_attacker_peer_id = int(f["peer"])
	if is_boss:
		if not bool(f.get("used", false)):
			f["used"] = true
			_take_dot_damage(float(f["ap"]) * 2.0 * float(f["power"]))
		return
	EnchantFxScript.play(get_tree(), "text", global_position, {"text": "İnfaz", "color": Color("#c98cff")})
	_take_dot_damage(health + 1.0)


## Donmuş Kalp: donmuş (sersem değil) düşmanın canı eşiğin altındaysa paramparça (boss hariç).
func _try_shatter(p: Dictionary, peer: int) -> void:
	if is_boss or is_dead or not (is_frozen and not is_stunned) or max_health <= 0.0:
		return
	if health / max_health > float(p.get("th", 0.15)):
		return
	var tree: SceneTree = get_tree()
	var pos: Vector2 = global_position
	var ap: float = float(p.get("ap", 10.0)) * float(p.get("power", 1.0))
	if peer > 0:
		last_attacker_peer_id = peer
	EnchantFxScript.play(tree, "burst", pos, {"palette": "spark", "count": 26, "speed": 210.0, "life": 0.5})
	EnchantFxScript.play(tree, "text", pos, {"text": "Paramparça", "color": Color("#bfe6ff")})
	var shards: int = int(p.get("shards", 0))
	var freeze_r: float = float(p.get("freeze_aoe", 0.0))
	_take_dot_damage(health + 1.0)
	for v in ElementReactions._nearest(tree, self, pos, 140.0, shards):
		if peer > 0:
			v.last_attacker_peer_id = peer
		v._take_dot_damage(ap * 0.4)
		EnchantFxScript.play(tree, "chain", pos, {"to": v.global_position, "color": Color(0.75, 0.9, 1.0)})
	if freeze_r > 0.0:
		for v in Enemy.get_enemies_near(tree, pos, freeze_r):
			if is_instance_valid(v) and not v.is_dead and v != self:
				v.apply_freeze_full(2.0)
	if bool(p.get("throne", false)):
		_notify_enchant_owner(peer, "shatter", {})


## Uygulamadan ÖNCEKİ aktif element durumları (tepkime tespiti için).
func _element_snapshot() -> Dictionary:
	return {
		"yanma": burn_time_left > 0.0,
		"donma": is_frozen and not is_stunned,
		"zehir": not _poison_stack_time.is_empty(),
		"kanama": bleed_stacks > 0,
		"sok": shock_time_left > 0.0,
	}


## Efsun dışı kaynakların tepkime kancası (apply_poison/apply_burn/apply_bleed/_start_freeze host dalı).
func _legacy_element_touched(element: String, had: Dictionary) -> void:
	if _in_element_apply or had.is_empty():
		return
	ElementReactions.resolve(self, element, had)


func _reaction_attack_power() -> float:
	if _reaction_ap > 0.0:
		return _reaction_ap
	var p: Node = get_tree().get_first_node_in_group("player")
	return float(p.get("damage_bonus")) if p and "damage_bonus" in p else 10.0


func _reaction_damage(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	if _reaction_peer > 0:
		last_attacker_peer_id = _reaction_peer
	_take_dot_damage(amount)


func _end_freeze_now() -> void:
	if is_frozen and not is_stunned:
		_freeze_timer = 0.0
		_process_freeze(0.0)


func _poison_dps_total() -> float:
	var s: float = 0.0
	for d in _poison_stack_dps:
		s += d
	return s


func _poison_dps_average() -> float:
	return _poison_dps_total() / float(_poison_stack_dps.size()) if _poison_stack_dps.size() > 0 else 0.0


func _extend_poison(seconds: float) -> void:
	if seconds <= 0.0:
		return
	for i in range(_poison_stack_time.size()):
		_poison_stack_time[i] += seconds


func _apply_burn_stack(tick: float, duration: float, max_stacks: int) -> void:
	var was_burning: bool = burn_time_left > 0.0
	apply_burn(tick, duration)
	if max_stacks > 1:
		_burn_stacks = mini(max_stacks, (_burn_stacks if was_burning else 0) + 1)
	elif _burn_stacks < 1:
		_burn_stacks = 1


## İstemci kuklası da efekt varlığından bilir (burn_start/burn_stop yayınıyla kurulur) - silah tarafı bonusları için.
func is_burning() -> bool:
	return _burn_status_fx != null and is_instance_valid(_burn_status_fx)


func is_shocked() -> bool:
	return _shock_fx != null and is_instance_valid(_shock_fx)


## Donmuş mu (buz, sersemletme değil) - istemci kuklasında freeze_start ile kurulan görselden.
func is_frozen_now() -> bool:
	return (_freeze_status_fx != null and is_instance_valid(_freeze_status_fx)) or (is_frozen and not is_stunned)


func _apply_shock_host(p: Dictionary, peer: int) -> void:
	shock_time_left = maxf(shock_time_left, float(p.get("dur", 4.0)))
	_shock_jump = maxf(_shock_jump, float(p.get("jump", 0.25)))
	_shock_jumps = maxi(_shock_jumps, int(p.get("jumps", 1)))
	_shock_spark = maxf(_shock_spark, float(p.get("spark", 0.0)))
	_shock_ap = maxf(_shock_ap, float(p.get("ap", 0.0)))
	if bool(p.get("death_bolt", false)):
		_shock_death_bolt = true
	if peer > 0:
		_shock_peer = peer
	if not is_shocked():
		_spawn_shock_status_fx()
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "shock_start")


## Aşırı Yük tepkimesinin şok yayılması - kaynağın şok parametreleri kopyalanır, yeni tepkime zinciri başlatmaz.
func _apply_shock_from(src: Node) -> void:
	if is_dead or not is_instance_valid(src):
		return
	_in_element_apply = true
	_apply_shock_host({"dur": maxf(2.0, float(src.shock_time_left)), "jump": src._shock_jump, "jumps": src._shock_jumps,
		"spark": src._shock_spark, "ap": src._shock_ap}, int(src._shock_peer))
	_in_element_apply = false


func _spawn_shock_status_fx() -> void:
	if is_shocked():
		return
	_shock_fx = Node2D.new()
	_shock_fx.set_script(ShockStatusFxScript)
	_shock_fx.set("radius", _body_radius)
	add_child(_shock_fx)


func _remove_shock_status_fx() -> void:
	if is_shocked():
		_shock_fx.queue_free()
	_shock_fx = null


func _clear_shock() -> void:
	shock_time_left = 0.0
	_shock_jump = 0.0
	_shock_jumps = 1
	_shock_spark = 0.0
	_shock_death_bolt = false
	_conductive = false
	_blood_current = false
	if is_shocked():
		_remove_shock_status_fx()
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "shock_stop")


## Şoklu düşmana DOĞRUDAN isabet (silah/yetenek; DOT ve sıçramanın kendisi değil) -> en yakın düşman(lar)a sıçrama.
func _shock_on_direct_hit(amount: float) -> void:
	if _shock_jump <= 0.0 or amount <= 0.0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _shock_last_jump_msec < SHOCK_JUMP_MIN_INTERVAL_MSEC:
		return
	_shock_last_jump_msec = now
	var tree: SceneTree = get_tree()
	for t in ElementReactions._nearest(tree, self, global_position, SHOCK_JUMP_RANGE, _shock_jumps):
		var dmg: float = amount * _shock_jump
		if _blood_current and bleed_stacks > 0:
			dmg *= 1.0 + 0.05 * float(bleed_stacks)
			t.apply_bleed(bleed_tick_damage_per_stack, 1, maxi(t.bleed_stacks + 1, 5))
		if _conductive and not _poison_stack_time.is_empty():
			var avg: float = _poison_dps_average()
			for i in range(mini(_poison_stack_time.size() / 2, 50)):
				t.apply_poison(avg, 200.0, 10.0)
		if last_attacker_peer_id > 0:
			t.last_attacker_peer_id = last_attacker_peer_id
		t._take_dot_damage(dmg)
		EnchantFxScript.play(tree, "chain", global_position, {"to": t.global_position})


func _apply_sleep_host(p: Dictionary) -> void:
	if is_boss or is_dead:
		return
	var dur: float = float(p.get("dur", 1.5))
	apply_stun(dur)
	_sleep_time = maxf(_sleep_time, dur)
	_sleep_break = bool(p.get("break", true))
	_sleep_bonus = maxf(_sleep_bonus, float(p.get("bonus", 0.0)))
	_sleep_vuln = maxf(_sleep_vuln, float(p.get("vuln", 0.0)))
	_sleep_wake_slow = maxf(_sleep_wake_slow, float(p.get("wake_slow", 0.0)))


func _wake_up() -> void:
	if _sleep_time <= 0.0:
		return
	if is_frozen and is_stunned:
		_freeze_timer = 0.0
		_process_freeze(0.0)
	_on_sleep_end()


func _on_sleep_end() -> void:
	_sleep_time = 0.0
	if _sleep_wake_slow > 0.0 and not is_dead:
		apply_slow(_sleep_wake_slow, 3.0)
	_sleep_bonus = 0.0
	_sleep_vuln = 0.0
	_sleep_wake_slow = 0.0
	_sleep_break = true


## Çatlak + Derin Uyku: alınan TÜM hasarın çarpanı (bkz. _apply_damage).
func _damage_taken_mult() -> float:
	var m: float = 1.0
	if crack_stacks > 0:
		m += CRACK_DAMAGE_PER_STACK * float(crack_stacks)
	if _sleep_time > 0.0 and _sleep_vuln > 0.0:
		m += _sleep_vuln
	if _vuln_pct > 0.0 and Time.get_ticks_msec() < _vuln_until_msec:
		m += _vuln_pct
	## Efsun İşaret'i (element "mark"): yük başına alınan tüm hasar +%1 (Avcı İşareti ile +%1,5).
	if mark_stacks > 0 and _mark_pct > 0.0:
		m += _mark_pct * float(mark_stacks)
	return m


## Doğrudan isabetin ÖNCESİ (host): uyuyan düşmana ilk vuruş bonusu.
func _pre_direct_hit(amount: float) -> float:
	if _sleep_time > 0.0 and _sleep_bonus > 0.0:
		amount *= 1.0 + _sleep_bonus
		_sleep_bonus = 0.0
	return amount


## Doğrudan isabetin SONRASI (host): uykudan uyandırma, şok sıçraması.
func _post_direct_hit(amount: float) -> void:
	if is_dead:
		return
	if _sleep_time > 0.0 and _sleep_break:
		_wake_up()
	if shock_time_left > 0.0:
		_shock_on_direct_hit(amount)
	if _enchant_flags.has("decree"):
		_check_decree()


## Host'ta her karede (sadece bir efsun durumu aktifken çağrılır - bkz. _physics_process).
func _process_enchant_status(delta: float) -> void:
	if shock_time_left > 0.0:
		shock_time_left -= delta
		if _shock_spark > 0.0:
			_shock_spark_timer -= delta
			if _shock_spark_timer <= 0.0:
				_shock_spark_timer = 1.0
				var near: Array = ElementReactions._nearest(get_tree(), self, global_position, 160.0, 1)
				if not near.is_empty():
					var t: Node = near[0]
					if _shock_peer > 0:
						t.last_attacker_peer_id = _shock_peer
					t._take_dot_damage(_shock_ap * _shock_spark)
					EnchantFxScript.play(get_tree(), "chain", global_position, {"to": t.global_position})
		if shock_time_left <= 0.0:
			_clear_shock()
	if _sleep_time > 0.0:
		_sleep_time -= delta
		if _sleep_time <= 0.0:
			_on_sleep_end()
	## Ebedi Kış: donmuş düşmana değen (34 px) düşman da donar.
	if _enchant_flags.has("contagious") and is_frozen and not is_stunned:
		_contagious_timer -= delta
		if _contagious_timer <= 0.0:
			_contagious_timer = 0.5
			for v in Enemy.get_enemies_near(get_tree(), global_position, 34.0 + _body_radius):
				if is_instance_valid(v) and v != self and not v.is_dead and not v.is_frozen:
					v.apply_freeze_full(2.0)
					v._linger_slow = maxf(v._linger_slow, _linger_slow)
	if not _plague.is_empty() and bool(_plague.get("cough", false)) and _poison_stack_time.size() >= 10:
		_plague_cough_timer -= delta
		if _plague_cough_timer <= 0.0:
			_plague_cough_timer = 2.0
			var near_c: Array = ElementReactions._nearest(get_tree(), self, global_position, float(_plague.get("radius", 80.0)), 1)
			if not near_c.is_empty():
				near_c[0]._receive_plague(1, float(_plague.get("dps", 1.0)), float(_plague.get("cap", 10.0)), float(_plague.get("dur", 10.0)), _plague)


func _has_enchant_status() -> bool:
	return shock_time_left > 0.0 or _sleep_time > 0.0 or (not _plague.is_empty() and bool(_plague.get("cough", false)))


func _receive_plague(stacks: int, dps: float, cap: float, dur: float, plague: Dictionary) -> void:
	if is_dead or stacks <= 0:
		return
	var had: Dictionary = _element_snapshot()
	_in_element_apply = true
	for i in range(mini(stacks, 50)):
		apply_poison(dps, cap, dur)
	_plague = plague.duplicate()
	_in_element_apply = false
	ElementReactions.resolve(self, "zehir", had)


## Kobra Oku (Zehirli Ok finali): 20+ yüklü hedefe tüm yüklerin 3 sn'lik hasarı anında; hasarın %2'si vurana can.
func _kobra_strike(peer: int) -> void:
	if _poison_stack_time.size() < 20:
		return
	var dmg: float = _poison_dps_total() * 3.0
	if dmg <= 0.0:
		return
	if peer > 0:
		last_attacker_peer_id = peer
	_take_dot_damage(dmg)
	_notify_enchant_owner(peer, "heal", {"amount": dmg * 0.02})
	EnchantFxScript.play(get_tree(), "text", global_position, {"text": "Kobra", "color": Color("#8fd65a")})


## Host'ta olan ve bir oyuncuya ait efsun olayını o oyuncunun kendi istemcisine iletir (can, Veba sayacı...).
func _notify_enchant_owner(peer: int, event: String, data: Dictionary) -> void:
	var local_id: int = multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0
	if not NetworkManager.is_multiplayer_active or peer <= 0 or peer == local_id:
		var p: Node = get_tree().get_first_node_in_group("player")
		if p and p.has_method("on_enchant_event"):
			p.on_enchant_event(event, data)
		return
	NetworkManager.enchant_event.rpc_id(peer, event, data)


## Efsun bayraklarının ölüm etkileri (bkz. _enchant_flags). Hasar veren olanlar ertelenir (ölüm -> patlama -> ölüm
## zincirinde derin özyineleme olmasın) ve bayrağı bırakan oyuncuya atfedilir.
func _on_death_enchant_flags(tree: SceneTree, pos: Vector2, poison_stacks: int) -> void:
	if _enchant_flags.is_empty():
		return
	var f: Dictionary = _enchant_flags
	var was_frozen: bool = is_frozen and not is_stunned
	var deferred: Array = [] ## [yarıçap, hasar, peer, fx türü, renk]
	if f.has("death_cloud") and poison_stacks > 0:
		var dc: Dictionary = f["death_cloud"]
		EnchantAreaScript.spawn(tree, "poison_cloud", pos, {"radius": 100.0, "duration": 3.0, "dps": float(dc.get("dps", 1.0)),
			"peer": int(dc["peer"]), "ap": float(dc["ap"])}, true)
	if f.has("burn_spread") and burn_time_left > 0.0:
		var bs: Dictionary = f["burn_spread"]
		for v in ElementReactions._nearest(tree, self, pos, 60.0, 6):
			v.apply_element_host("burn", {"tick": float(bs["tick"]), "dur": float(bs["dur"]), "ap": float(bs["ap"]), "quiet": true}, int(bs["peer"]))
	if f.has("burn_death_blast") and burn_time_left > 0.0:
		var bb: Dictionary = f["burn_death_blast"]
		deferred.append([80.0, float(bb["ap"]) * 0.6 * float(bb["power"]), int(bb["peer"]), "explosion", Color(1.0, 0.55, 0.2)])
	if f.has("bleed_transfer") and bleed_stacks > 0:
		var bt: Dictionary = f["bleed_transfer"]
		for v in ElementReactions._nearest(tree, self, pos, 160.0, 1):
			v.apply_bleed(bleed_tick_damage_per_stack, bleed_stacks, maxi(int(bt.get("cap", 10)), bleed_stacks))
	if f.has("bleed_death_blast") and bleed_stacks > 0:
		var bd: Dictionary = f["bleed_death_blast"]
		deferred.append([60.0, float(bd["ap"]) * 0.4 * float(bd["power"]), int(bd["peer"]), "burst_blood", Color(0.9, 0.2, 0.25)])
	if f.has("bleed_kill") and bleed_stacks > 0:
		_notify_enchant_owner(int(f["bleed_kill"]["peer"]), "bleed_kill", {})
	if f.has("frozen_shards") and was_frozen:
		var fs: Dictionary = f["frozen_shards"]
		var shard_peer: int = int(fs["peer"])
		for v in ElementReactions._nearest(tree, self, pos, 140.0, 3):
			if shard_peer > 0:
				v.last_attacker_peer_id = shard_peer
			v._take_dot_damage(float(fs["ap"]) * 0.4 * float(fs["power"]))
			if bool(fs.get("freeze", false)):
				v.apply_freeze_full(2.0)
			EnchantFxScript.play(tree, "chain", pos, {"to": v.global_position, "color": Color(0.75, 0.9, 1.0)})
	if f.has("mark_transfer") and mark_stacks > 1:
		for v in ElementReactions._nearest(tree, self, pos, 160.0, 1):
			v.apply_element_host("mark", {"stacks": mark_stacks / 2, "cap": int(f["mark_transfer"].get("cap", 20)),
				"dur": _mark_duration, "pct": _mark_pct, "quiet": true}, int(f["mark_transfer"]["peer"]))
	if f.has("mark_soul") and mark_stacks > 0:
		_notify_enchant_owner(int(f["mark_soul"]["peer"]), "soul", {})
	if f.has("mark_death_blast") and mark_stacks > 0:
		var md: Dictionary = f["mark_death_blast"]
		deferred.append([80.0, float(md["ap"]) * 0.6 * float(md["power"]), int(md["peer"]), "explosion", Color(0.75, 0.45, 1.0)])
	if f.has("chain_bomb") and Time.get_ticks_msec() <= int(f["chain_bomb"]["until"]):
		var cb: Dictionary = f["chain_bomb"]
		deferred.append([60.0, float(cb["ap"]) * 0.6, int(cb["peer"]), "chain_bomb", Color(1.0, 0.7, 0.3)])
		if randf() < float(cb.get("gold", 0.03)):
			_notify_enchant_owner(int(cb["peer"]), "gold", {"amount": 1})
	if deferred.is_empty():
		return
	tree.create_timer(0.06).timeout.connect(func() -> void:
		for d in deferred:
			var radius: float = float(d[0])
			var dmg: float = float(d[1])
			var peer: int = int(d[2])
			var kind: String = str(d[3])
			if kind == "burst_blood":
				EnchantFxScript.play(tree, "burst", pos, {"palette": "fire", "count": 12, "speed": 100.0, "life": 0.4})
			else:
				EnchantFxScript.play(tree, "explosion", pos, {"radius": radius, "color": d[4]})
			for v in Enemy.get_enemies_near(tree, pos, radius):
				if not is_instance_valid(v) or v.is_dead:
					continue
				if kind == "chain_bomb":
					v.apply_element_host("chain_bomb", {"ap": dmg / 0.6, "dur": 0.6, "gold": 0.03}, peer)
				if peer > 0:
					v.last_attacker_peer_id = peer
				v._take_dot_damage(dmg))


## die() içinden, SADECE host/tek oyunculuda: Salgın, Zehirli Ok yayılımı, Enfeksiyon, Şimşek Çekici yıldırımı.
func _on_death_elements() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var pos: Vector2 = global_position
	var stacks: int = _poison_stack_time.size()
	if not _plague.is_empty() and stacks > 0:
		var n: int = int(round(float(stacks) * float(_plague.get("ratio", 0.5))))
		if n > 0:
			var dur: float = float(_plague.get("dur", 10.0))
			if not bool(_plague.get("refresh", false)) and stacks > 0:
				var rem: float = 0.0
				for t in _poison_stack_time:
					rem += t
				dur = maxf(1.0, rem / float(stacks))
			for v in ElementReactions._nearest(tree, self, pos, float(_plague.get("radius", 80.0)), 6):
				v._receive_plague(n, float(_plague.get("dps", 1.0)), float(_plague.get("cap", 10.0)), dur, _plague)
			EnchantFxScript.play(tree, "ring", pos, {"radius": float(_plague.get("radius", 80.0)), "color": Color(0.55, 0.9, 0.35, 0.9)})
		if bool(_plague.get("final", false)):
			_notify_enchant_owner(int(_plague.get("peer", 0)), "plague_death", {})
	if not _death_poison_burst.is_empty() and stacks > 0:
		for v in ElementReactions._nearest(tree, self, pos, 100.0, 8):
			v._receive_plague(int(_death_poison_burst["stacks"]), float(_death_poison_burst["dps"]), float(_death_poison_burst["cap"]), float(_death_poison_burst["dur"]), {})
		EnchantFxScript.play(tree, "burst", pos, {"palette": "void", "count": 12, "speed": 110.0, "life": 0.4})
	if _infected:
		var avg: float = _poison_dps_average()
		for v in ElementReactions._nearest(tree, self, pos, 150.0, 2):
			if stacks > 1:
				v._receive_plague(stacks / 2, avg, 200.0, 10.0, {})
			if bleed_stacks > 1:
				v.apply_bleed(bleed_tick_damage_per_stack, bleed_stacks / 2, maxi(v.bleed_stacks + bleed_stacks / 2, 5))
	_on_death_enchant_flags(tree, pos, stacks)
	if _shock_death_bolt and shock_time_left > 0.0:
		var ap: float = _shock_ap
		var peer: int = _shock_peer
		## Ertelenir: ölüm zincirinde (yıldırım -> ölüm -> yıldırım) derin özyineleme olmasın.
		tree.create_timer(0.05).timeout.connect(func() -> void:
			EnchantFxScript.play(tree, "bolt", pos, {})
			for v in Enemy.get_enemies_near(tree, pos, 60.0):
				if is_instance_valid(v) and not v.is_dead:
					if peer > 0:
						v.last_attacker_peer_id = peer
					v._take_dot_damage(ap * 0.5))


## Hançer'in mermisi (weapon.gd _fire_at) her isabette çağırır - yük ekler
## (max_stacks'e kadar) ve o anki saniye-başı-hasarı günceller (saldırı gücü
## büyüdükçe sonraki isabetlerde tik hasarı da büyür).
func apply_bleed(tick_damage_per_stack: float, stacks_to_add: int, max_stacks: int) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "bleed", tick_damage_per_stack, float(stacks_to_add), float(max_stacks))
		return
	var had_elements: Dictionary = {} if _in_element_apply else _element_snapshot()
	bleed_tick_damage_per_stack = tick_damage_per_stack
	bleed_stacks = min(bleed_stacks + max(1, stacks_to_add), max_stacks)
	_legacy_element_touched("kanama", had_elements)


func _process_bleed(delta: float) -> void:
	if bleed_stacks <= 0:
		return
	_bleed_tick_timer -= delta
	if _bleed_tick_timer <= 0.0:
		_bleed_tick_timer += _bleed_interval
		## Kristal Kan tepkimesi: donmuş kalan süre boyunca kanama tikleri x2 (bkz. element_reactions.gd).
		var bleed_mult: float = 2.0 if Time.get_ticks_msec() < _bleed_double_until_msec else 1.0
		_take_dot_damage(bleed_tick_damage_per_stack * bleed_stacks * bleed_mult)
		_spawn_bleed_fx()
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "bleed")


## Kanama tikinde bir kerelik kan sıçraması efekti oynatır (bkz. BleedFxScenes) -
## hedefin O ANKİ konumunda, ana sahneye eklenir (weapon.gd'nin
## _spawn_melee_hit_fx'iyle aynı yaklaşım) ki yaratık ölüp silinse bile efekt
## yarıda kesilmesin.
## Kullanıcı isteği: "kanama anında çıkan kan efektini %50 küçült" - bu
## sahneler (fx_hit_blood_*) başka silahlerle de PAYLAŞILIYOR (bkz.
## weapon.gd hit_impact_scale_mult notu), o yüzden .tscn'deki taban ölçek
## DEĞİŞTİRİLMEDİ - sadece burada, instantiate SONRASI, SADECE kanama
## efektine özel bir çarpan uygulanıyor.
const BLEED_FX_SCALE_MULT := 0.5

func _spawn_bleed_fx() -> void:
	var scene: PackedScene = BleedFxScenes[randi_range(0, BleedFxScenes.size() - 1)]
	var fx: Node2D = scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.rotation = randf_range(0.0, TAU)
	fx.scale *= BLEED_FX_SCALE_MULT


## Buz Asası'nın mermisi (projectile.gd) her isabette çağırır - zaten donmuşsa
## (veya boss'sa/ölmüşse) hiçbir şey yapmaz, aksi halde yük ekler ve tavana
## ulaşınca donmayı başlatır.
func apply_chill(_stacks_to_add: int) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "chill", 1.0, 0.0, 0.0)
		return
	if is_boss:
		_boss_chill_stacks += 1
		_boss_chill_timer = CHILL_DURATION
		if _boss_chill_stacks >= _boss_chill_required:
			_boss_chill_stacks = 0
			_start_freeze(BOSS_CHILL_FREEZE_DURATION)
		return
	_start_freeze(CHILL_DURATION)


## bkz. _boss_chill_stacks üstündeki yorum - mark/bleed'in yük zaman aşımı
## deseninin AYNISI, sadece boss'un chill yükü için.
func _process_boss_chill(delta: float) -> void:
	if _boss_chill_stacks <= 0:
		return
	_boss_chill_timer -= delta
	if _boss_chill_timer <= 0.0:
		_boss_chill_stacks = 0


## Mark ile birebir aynı desen (bkz. _process_mark) - CHILL_DURATION saniye
## boyunca hiç yeni isabet gelmezse yük tamamen sıfırlanır (ve mavimsi ton
## _refresh_chill_tint ile birlikte kalkar). Donmuşken (is_frozen) zaten
## chill_stacks sıfırlanmış oluyor (bkz. _start_freeze) - bu fonksiyon o
## durumda no-op (chill_stacks<=0 kontrolüyle) zaten hemen çıkar.
func _process_chill(delta: float) -> void:
	if chill_stacks <= 0:
		return
	_chill_timer -= delta
	if _chill_timer <= 0.0:
		chill_stacks = 0
		_refresh_chill_tint()


## Yük başına hareket hızını %20 azaltır (toplamsal: 1 yük=%80 hız, 2=%60,
## 3=%40, 4=%20 hız) - 5. yükte zaten _start_freeze tam donmayı başlatıp
## chill_stacks'i sıfırladığı için burada en fazla 4 yükle karşılaşılır
## (bkz. kullanıcı bildirimi: "donma yükü uyguladıkları hedefin donma yükü
## başına %20 yavaşlamasını istiyorum").
func _chill_speed_mult() -> float:
	return max(0.0, 1.0 - chill_stacks * 0.20)


## Kitelama Seti pasifi - bkz. yukarıdaki _slow_percent/_slow_timer yorumu.
## percent: 0.05 = %5 hız azaltma. duration: etkinin süresi (sn).
## allow_boss: normalde bosslar yavaşlatmaya bağışıktır (aşağıdaki "is_boss"
## kontrolü) - Oakley'in Sarmaşıklar yeteneği (bkz. oakley_vine.gd,
## kullanıcı isteği: "bossları yere sabitleyemez ama %30 yavaşlatır") bu
## TEK istisna için true geçiyor, diğer TÜM çağıranlar (Kitelama Seti vb.)
## varsayılan false ile eski davranışı aynen koruyor.
func apply_slow(percent: float, duration: float, allow_boss: bool = false) -> void:
	if is_dead or (is_boss and not allow_boss):
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "slow", percent, duration, 1.0 if allow_boss else 0.0)
		return
	## Aşırı eşya yığılmasında yavaşlatmanın %100'ü geçip hızın negatife
	## inmemesi için tavan (bkz. items.gd Kitelama Seti - her kopya %10
	## ekler, çok kopya alınırsa toplam kolayca %100'ü aşabilirdi).
	_slow_percent = max(_slow_percent, min(percent, 0.75)) ## aynı vuruşta en güçlüsü kalır
	_slow_timer = duration ## refresh - baştan başlar
	## GÖRSEL: hedefin üzerinde dönen boşluk girdabı göstergesi + ömrünün
	## tazelenmesi (Alan Totemi yavaşlatmayı her saniye yeniliyor).
	_spawn_slow_status_fx(duration)
	## Ağ: gösterge HER client'ta yaşasın diye host yayınlar - Alan Totemi
	## saniyede bir yenilediği için spam olmaması adına en fazla
	## SLOW_FX_BROADCAST_INTERVAL'de bir gönderilir.
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host and _slow_fx_broadcast_cooldown <= 0.0:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			_slow_fx_broadcast_cooldown = SLOW_FX_BROADCAST_INTERVAL
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "slow_start", {"duration": duration})


func _process_slow(delta: float) -> void:
	## GÖRSEL göstergenin ömrü KENDİ başına sayar - yavaşlatma host'ta
	## hesaplandığı için _slow_timer istemcilerde hiç dolmaz, ama bu sayaç
	## ağdan gelen "slow_start" ile her client'ta bağımsız çalışır (bkz.
	## _spawn_slow_status_fx). Yavaşlatma SİMÜLASYONUNA hiç dokunmaz.
	if _slow_fx_broadcast_cooldown > 0.0:
		_slow_fx_broadcast_cooldown = max(0.0, _slow_fx_broadcast_cooldown - delta)
	if _slow_fx_time_left > 0.0:
		_slow_fx_time_left -= delta
		if _slow_fx_time_left <= 0.0:
			_remove_slow_status_fx()
	if _slow_timer <= 0.0:
		return
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_percent = 0.0


## Oakley'in Sarmaşıklar yeteneği (E, bkz. oakley_vine.gd) - hareketi
## engeller ama SALDIRIYI engellemez: is_frozen'ın aksine hedef bulma/
## saldırı mantığına HİÇ dokunulmuyor, sadece _physics_process'in en sonunda
## (move_and_slide'dan hemen önce) hesaplanmış velocity sıfırlanıyor (bkz. o
## bloktaki "if is_rooted: velocity = Vector2.ZERO"). Bosslar SABİTLENEMEZ
## (kullanıcı isteği) - oakley_vine.gd zaten boss'a bunun yerine apply_slow
## çağırıyor, buradaki kontrol ek bir güvenlik.
var is_rooted: bool = false
var _root_timer: float = 0.0

func apply_root(duration: float) -> void:
	if is_dead or is_boss:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "root", duration, 0.0, 0.0)
		return
	is_rooted = true
	_root_timer = max(_root_timer, duration)
	_set_root_visual(true, _root_timer)


func _process_root(delta: float) -> void:
	if _root_timer <= 0.0:
		return
	_root_timer -= delta
	if _root_timer <= 0.0:
		_root_timer = 0.0
		is_rooted = false
		_set_root_visual(false)


## Kök salma görseli (Oakley Sarmaşıklar - bacaklara sarılan dikenli sarmaşık, bkz. fx_oakley_entangle.gd; kullanıcı isteği
## 2026-09-25). Korku/kışkırtma göstergeleriyle AYNI yaşam döngüsü: host/tek oyunculu karar verir, broadcast_enemy_vfx
## "root_start"/"root_stop" ile yayınlar (bkz. _set_taunt_visual).
const EntangleFxScene := preload("res://scenes/fx_oakley_entangle.tscn")
var _entangle_fx: Node2D = null

func _set_root_visual(on: bool, duration: float = 0.0) -> void:
	if on:
		_spawn_entangle_fx(duration)
	else:
		_remove_entangle_fx()
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			if on:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "root_start", {"duration": duration})
			else:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "root_stop")


func _spawn_entangle_fx(duration: float) -> void:
	if is_dead:
		return
	if _entangle_fx and is_instance_valid(_entangle_fx) and not _entangle_fx.is_queued_for_deletion():
		_entangle_fx.refresh(duration)
		return
	_entangle_fx = EntangleFxScene.instantiate()
	add_child(_entangle_fx)
	_entangle_fx.setup(duration, _body_radius)


func _remove_entangle_fx() -> void:
	if _entangle_fx and is_instance_valid(_entangle_fx):
		_entangle_fx.release()
	_entangle_fx = null


## Oakley'in Arı Sürüsü yeteneği (R, bkz. oakley_bee_swarm.gd) - her
## çağrıda (sürünün içindeyken saniyede bir) BİR yük ekler (en fazla
## BEE_POISON_MAX_STACKS), her yük KENDİ 4sn'lik ömrünü BAĞIMSIZ sayar (bkz.
## _process_bee_poison) - apply_bleed'deki "son isabet PAYLAŞILAN tik
## hasarını günceller" deseniyle aynı, tick_damage_per_stack her çağrıda
## güncellenen ortak bir çarpan.
const BEE_POISON_MAX_STACKS := 10
const BEE_POISON_STACK_DURATION := 4.0
const BEE_POISON_TICK_INTERVAL := 1.0
var _bee_poison_stacks: Array = [] ## her eleman: o yükün kalan ömrü (sn)
var _bee_poison_per_tick_damage: float = 0.0
var _bee_poison_tick_timer: float = 0.0

func apply_bee_poison(tick_damage_per_stack: float) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "bee_poison", tick_damage_per_stack, 0.0, 0.0)
		return
	_bee_poison_per_tick_damage = tick_damage_per_stack
	if _bee_poison_stacks.size() < BEE_POISON_MAX_STACKS:
		_bee_poison_stacks.append(BEE_POISON_STACK_DURATION)


func _process_bee_poison(delta: float) -> void:
	if _bee_poison_stacks.is_empty():
		return
	for i in range(_bee_poison_stacks.size() - 1, -1, -1):
		_bee_poison_stacks[i] -= delta
		if _bee_poison_stacks[i] <= 0.0:
			_bee_poison_stacks.remove_at(i)
	if _bee_poison_stacks.is_empty():
		return
	_bee_poison_tick_timer -= delta
	if _bee_poison_tick_timer <= 0.0:
		_bee_poison_tick_timer += BEE_POISON_TICK_INTERVAL
		_take_dot_damage(_bee_poison_stacks.size() * _bee_poison_per_tick_damage)


func _slow_speed_mult() -> float:
	return max(0.0, 1.0 - _slow_percent)


## Soğuma yükü VARKEN hafif mavimsi bir modulate uygular (bkz. kullanıcı
## bildirimi: "üstlerinde yük varken hafif mavimsi olmalarını istiyorum"),
## yük yokken normal renge döner. _flash() (hasar aldığında kırmızı yanıp
## sönme) bu tonu EZMESİN diye kendi bitiş rengini de buradan okuyor (bkz.
## _flash) - ikisi çakışmaz, flash bitince "normal" yerine "güncel soğuma
## tonu"na döner.
const CHILL_TINT_COLOR := Color(0.62, 0.8, 1.05, 1.0)

func _status_tint_color() -> Color:
	if is_raging:
		return RAGE_TINT_COLOR
	return CHILL_TINT_COLOR if chill_stacks > 0 else Color(1.0, 1.0, 1.0, 1.0)


## Rage modu tek seferlik bir anahtar - geri kapanmaz (ölene kadar sürer).
## Ton, _refresh_chill_tint (aslında genel "durum tonu" yenileyicisi) ile
## uygulanıyor, chill ile aynı boru hattı.
func _enter_rage_mode() -> void:
	is_raging = true
	_refresh_chill_tint()
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "rage_start")


func _rage_speed_mult() -> float:
	if not is_raging:
		return 1.0
	return ORK_RAGE_SPEED_MULT if creature_family() == "ork" else RAGE_SPEED_MULT


func _rage_hp_threshold() -> float:
	return ORK_RAGE_HP_THRESHOLD if creature_family() == "ork" else RAGE_HP_THRESHOLD


func _refresh_chill_tint() -> void:
	var target: CanvasItem = null
	if anim_sprite:
		target = anim_sprite
	else:
		target = frame_sprite
	if target:
		## BUG DÜZELTMESİ (kullanıcı bildirimi: "yaratıklar rage moduna girince
		## hasar alma modundaki beyaz parıltı efekti açık kalıyor üzerlerinde")
		## - burada eskiden _flash_tween (hasar alınca beyaz "pop" yapan hit-
		## flash shader tween'i, bkz. _flash()) öldürülüyordu. O kill çağrısı
		## modulate'in tween'le değil DOĞRUDAN atandığı ESKİ bir tasarımdan
		## kalmaydı (bkz. _flash() üstündeki "modulate rage/chill durum tonu
		## için hâlâ kullanılıyor, flash AYRI bir shader uniform'uyla" notu) -
		## artık _flash_tween SADECE flash_amount'u 1.0'dan 0.0'a indiren
		## tween, modulate'le hiç ilgisi yok. Rage'e giren bir vuruş _flash()'ı
		## BAŞLATIYOR, hemen ardından _enter_rage_mode() bu fonksiyonu
		## çağırıyordu - kill çağrısı o SIRADA çalışan flash tween'ini
		## flash_amount hâlâ 1.0'dayken öldürüyor, geri 0'a inecek tween'i
		## asla tamamlanmadan iptal edip beyaz parıltıyı KALICI bırakıyordu.
		## Modulate zaten aşağıda koşulsuz üzerine yazıldığı için bu kill'e
		## hiç gerek yoktu - kaldırıldı.
		target.modulate = _status_tint_color()


## Talon'un "Yer Sarsıntısı" gibi anlık, tam sersemletme (stun) yetenekleri
## için - Buz Asası'nın donma sistemiyle (is_frozen) AYNI mekanizmayı
## kullanır (hareket edemez, kimseye saldıramaz/hasar veremez), ama
## chill_stacks birikimine bağlı değildir - süresi doğrudan dışarıdan
## verilir ve anında tam sersemletme uygular. Bosslar donmaya bağışık
## olduğu gibi (bkz. apply_chill) bu sersemletmeye de bağışıktır.
##
## Görsel olarak, donma buz kütlesi yerine yaratığın kafasının üstünde dönen
## pikselsi yıldızlar efekti (res://scenes/fx_stun_stars.tscn) tetiklenir
## (kullanıcı isteği: "donma efekti kullanılıyor. onun yerine yaratıkların üstünde
## sersemli vaziyette oldukları sürece dönen yıldızlar tarzı pixel tarzı minimal
## bir sersemleme efekti eklemeni istiyorum").
func apply_stun(duration: float) -> void:
	if is_dead or is_boss:
		return
	## Diğer efektlerle (apply_poison/apply_bleed/apply_chill/apply_mark) AYNI
	## host-yetkili desen: çoklu oyuncuda sadece HOST yaratık simülasyonunu
	## çalıştırır (bkz. _physics_process başındaki "sadece host'ta çalışır"
	## notu) - host olmayan bir oyuncu (ör. Talon host değilse) burada
	## DOĞRUDAN çağırırsa sadece kendi ekranındaki geçici/salt-görsel yaratık
	## kopyasını dondurur, host'un gerçek yaratığı hiç etkilenmez ve bir
	## sonraki ağ senkronizasyonunda (bkz. enemy_spawner.gd _sync_enemy_
	## positions) o dondurma anında geri alınır - yaratık hiç sersemlememiş
	## gibi görünür (kullanıcı bildirimi: "yaratıklar sersemlemiyor"). Eskiden
	## bu yönlendirme apply_stun'da EKSİKTİ (diğer tüm CC efektlerinde vardı).
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "stun", duration, 0.0, 0.0)
		return
	is_frozen = true
	is_stunned = true
	chill_stacks = 0
	_freeze_timer = max(_freeze_timer, duration)
	velocity = Vector2.ZERO
	
	# Eğer üzerinde donma görseli varsa kaldır
	if _freeze_status_fx and is_instance_valid(_freeze_status_fx):
		_freeze_status_fx.queue_free()
		_freeze_status_fx = null
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "freeze_stop")

	# Sersemletme yıldızlarını oluştur
	if not _stun_status_fx or not is_instance_valid(_stun_status_fx):
		_stun_status_fx = StunStatusFxScene.instantiate()
		add_child(_stun_status_fx)
		if _stun_status_fx.has_method("setup"):
			_stun_status_fx.setup(duration)
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "stun_start", {"duration": duration})


## Büyücü Kız'ın "Don Nova" temel yeteneği (varyasyon 2, bkz. player.gd
## _skill_buyucu_frost_nova): apply_stun ile BİREBİR AYNI host-yetkili
## yönlendirme/boss-bağışıklık deseni, tek fark görsel/mekanik olarak
## Buz Asası'nın tam donma sistemini (is_frozen + buz kütlesi görseli)
## kullanması - "donan yaratıklar hiçbir şey yapamaz" isteğiyle zaten
## eşleşen mekanizma budur, sadece süresi yük birikimine değil doğrudan
## dışarıdan verilen bir değere bağlı.
func apply_freeze_full(duration: float) -> void:
	if is_dead or is_boss:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "freeze", duration, 0.0, 0.0)
		return
	_start_freeze(max(duration, _freeze_timer if is_frozen else 0.0))


func _start_freeze(duration: float = FREEZE_DURATION) -> void:
	## Efsun tepkimeleri (bkz. _legacy_element_touched): donma, uygulanmadan önceki yanma/zehir/kanama/şokla tepkimeye girer.
	var had_elements: Dictionary = {} if (_in_element_apply or (is_frozen and not is_stunned)) else _element_snapshot()
	_start_freeze_inner(duration)
	_legacy_element_touched("donma", had_elements)


func _start_freeze_inner(duration: float) -> void:
	is_frozen = true
	is_stunned = false
	chill_stacks = 0
	_freeze_timer = duration
	velocity = Vector2.ZERO

	# Eğer üzerinde sersemletme yıldızları varsa kaldır
	if _stun_status_fx and is_instance_valid(_stun_status_fx):
		_stun_status_fx.queue_free()
		_stun_status_fx = null
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "stun_stop")

	# Donma buz kütlesini oluştur veya mevcut efekti yeni süreyle tazele.
	if not _freeze_status_fx or not is_instance_valid(_freeze_status_fx):
		_freeze_status_fx = FreezeStatusFxScene.instantiate()
		add_child(_freeze_status_fx)
	if _freeze_status_fx.has_method("setup"):
		## DÜZELTME (kullanıcı isteği: "efekt sistemi" - donma efekti yaratığın
		## gövdesini doğru kaplasın) - _body_radius de veriliyor, yeni fx_ice_
		## freeze_status.gd bunu kullanarak gövde boyutuna göre ölçekleniyor.
		_freeze_status_fx.setup(duration, _body_radius)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "freeze_start", {"duration": duration})


## PERF DÜZELTMESİ (200+ yaratık hedefi - profiler: _find_closest_target_player
## 150 yaratıkta 150 kez/kare çağrılıyordu, her seferinde "player" +
## "remote_players" + "player_allies" gruplarını has_method/get() ile TEK TEK
## tarıyordu). _compute_enemy_separation'daki AYNI desen (bkz. yukarısı,
## SEPARATION_UPDATE_INTERVAL_FRAMES + instance_id'ye göre kaydırma)
## uygulandı: hedef artık HER karede değil, kare başına ~1/4 yaratıkta yeniden
## aranıyor, aradaki karelerde önbellekten kullanılıyor. Bu GÜVENLİ çünkü
## _physics_process'teki çağıran taraf (bkz. player_is_invisible kontrolü)
## seçilen hedefi zaten HER karede ayrıca doğruluyor - bayat bir hedef
## görünmez/ev içi/satıcı bölgesine girerse aynı kare içinde fark edilir.
## Tek istisna "is_dead": aşağıda AYRICA (ucuz, taramasız) kontrol ediliyor,
## bayat önbellek yeni ölmüş bir oyuncuyu KALICI hedef olarak tutmasın diye.
## bkz. _physics_process içindeki AI_THINK PERF DÜZELTMESİ notu.
const AI_THINK_INTERVAL_FRAMES := 3
var _ai_has_decision: bool = false
var _ai_wandering: bool = false
var _ai_player: Node2D = null
var _ai_velocity: Vector2 = Vector2.ZERO
var _ai_true_contact: float = 0.0
var _ai_min_sep: float = 0.0
var _ai_accum_delta: float = 0.0

const TARGET_UPDATE_INTERVAL_FRAMES := 4
## Necromancer yaratıklarının (player_allies) agro önceliği - bkz. _find_closest_target_player.
const ALLY_AGGRO_RADIUS := 160.0
const ALLY_AGGRO_BIAS := 0.35
var _cached_target_player: Node2D = null

func _get_target_player() -> Node2D:
	## LOD: hiçbir oyuncuya yakın olmayan (bkz. _ensure_lod_classification)
	## yaratıklar hedeflerini ENEMY_LOD_FAR_SLOWDOWN kat daha seyrek yeniler -
	## zaten görünmüyorlar, "en yakın oyuncu" birkaç saniye bayat kalsa fark
	## edilmez.
	_ensure_lod_classification(get_tree())
	var target_interval: int = TARGET_UPDATE_INTERVAL_FRAMES * (ENEMY_LOD_FAR_SLOWDOWN if _is_lod_far(get_instance_id()) else 1)
	## ÇÖKME DÜZELTMESİ (2026-09-25, "Invalid type in function '_apply_aggro_overrides'
	## ... (previously freed)" ile oyun durdu): Godot 4'te SİLİNMİŞ bir nesne "== null"
	## sorgusunda TRUE döner (4.7.2'de denendi), yani eski "_cached_target_player != null
	## and not is_instance_valid(...)" koruması silinmiş hedefte HİÇ tetiklenmiyordu -
	## hedef (ör. süresi biten Necromancer iskeleti) silinince önbellek yenileme karesine
	## kadar ölü referansı tutuyor, typed Node2D parametreli _apply_aggro_overrides'a
	## geçince betik hatası veriyordu. Silinmiş referans typeof OBJECT kalır, gerçek boş
	## (null) hedef NIL'dir - böylece boş hedefte her karede tarama yapılmıyor (perf).
	var cache_freed: bool = typeof(_cached_target_player) == TYPE_OBJECT and not is_instance_valid(_cached_target_player)
	var stale_dead: bool = cache_freed or (_cached_target_player != null and _cached_target_player.get("is_dead") == true)
	if stale_dead or Engine.get_physics_frames() % target_interval == get_instance_id() % target_interval:
		_cached_target_player = _find_closest_target_player()
	## "En yakın" seçimi (yukarıdaki önbellek) ucuzluk için 4 karede bir yenilenir,
	## ama aşağıdaki zorunlu agro kuralları (kışkırtma, Şovalye baloncuğu) HER
	## karede önbelleğin ÜSTÜNE uygulanır - önbelleği bozmadan, yani kural
	## biter bitmez yaratık kendiliğinden normal "en yakın hedef"ine döner.
	return _apply_aggro_overrides(_cached_target_player)


## Zorunlu agro kuralları - _find_closest_target_player()'ın "en yakın oyuncu"
## seçimini iki durumda ezer (öncelik sırasıyla):
## 1) KIŞKIRTMA (bkz. apply_taunt): _taunt_timer sürerken hedef, kışkırtan
##    oyuncudur - kim daha yakın olursa olsun. Kışkırtan ölmüş/görünmez/ev içi/
##    satıcı bölgesindeyse kural sessizce bırakılır (yaratık boş kalıp dolanmasın).
## 2) ŞOVALYE BALONCUĞU ODAĞI (bkz. _paladin_zone_focus_target): hedef bir
##    dostsa ve baloncuğun içindeyse hedef, baloncuğun sahibi Şovalye olur.
func _apply_aggro_overrides(target: Node2D) -> Node2D:
	## "Ağacı Koru" görevi (kullanıcı isteği: "Bu görev başladıktan sonra haritadaki
	## yaratıklar bu ağaca saldırmaya odaklanırlar") - bkz. GameManager.defend_tree_active
	## üstündeki not. EN YÜKSEK öncelik (taunt/paladin-zone'un bile önünde) - "odaklanırlar"
	## istisnasız bir yönlendirme gibi okundu.
	if GameManager.defend_tree_active and is_instance_valid(GameManager.defend_tree_ref):
		return GameManager.defend_tree_ref
	if _taunt_timer > 0.0 and _taunt_target != null:
		if _is_targetable_player(_taunt_target):
			target = _taunt_target
		else:
			_taunt_target = null
			_set_taunt_visual(false)
	var focus: Node2D = _paladin_zone_focus_target(target)
	return focus if focus != null else target


## _find_closest_target_player()'ın aday eleme koşullarıyla AYNI (ölü, görünmez,
## yerde yatan, ev içi, seyyar satıcı bölgesi) - yerel oyuncu (metot tabanlı) ve
## RemotePlayer kuklası (alan tabanlı) için ayrı ayrı bakılıyor.
func _is_targetable_player(p: Node) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if p.get("is_dead") == true or p.get("is_downed") == true:
		return false
	if p.has_method("is_invisible_now") and p.is_invisible_now():
		return false
	if p.has_method("is_indoors_now") and p.is_indoors_now():
		return false
	if p.has_method("is_in_merchant_zone_now") and p.is_in_merchant_zone_now():
		return false
	if p.get("is_invisible") == true or p.get("is_indoors") == true or p.get("is_in_merchant_zone") == true:
		return false
	return true


## Baloncuğun yarıçapına eklenen pay: hedefin bir adım dışına çıkıp girmesi her
## karede odağı açıp kapatmasın (sınırda titreme olmasın) diye.
const ZONE_FOCUS_MARGIN := 24.0

## Kullanıcı isteği: "kalkan baloncuğuna giren kim olursa olsun kalkan baloncuğuna
## doğru yürüyen TÜM düşmanların daima kalkan baloncuğuna focus atmaları
## gerekmektedir". Kök neden: hedef, "en yakın oyuncu" olarak seçiliyor - baloncuğa
## giren bir dost Şovalye'den daha yakınsa yaratık DOSTA doğru yürüyor, ama
## baloncuğun sert sınırı (bkz. _physics_process "sert yapıştırma") onu içeri
## sokmuyor: yaratık sınırda yürüyüp duruyor, üstelik "player" Şovalye olmadığı
## için kalkana saldırı bloğu (paladin_shield_up) hiç çalışmıyor ve yakın dövüş
## menzili de dosta yetmiyor - yani kimseye vurmuyordu.
## Artık hedef bir Şovalye baloncuğunun (+ZONE_FOCUS_MARGIN) İÇİNDEYSE hedef o
## baloncuğun sahibi yapılır: yaratık sahibe yürür, sınıra gelince kalkana saldırır.
## Birden fazla baloncuk varsa yaratığa en yakın olanı seçilir. Hedef zaten
## baloncuğun sahibiyse ya da hiçbir baloncuk açık değilse null (kural yok) döner.
func _paladin_zone_focus_target(target: Node2D) -> Node2D:
	if target == null or not is_instance_valid(target):
		return null
	var zone_owners: Array = _paladin_zone_owners()
	if zone_owners.is_empty():
		return null
	var best: Node2D = null
	var best_dist: float = INF
	for zone_owner in zone_owners:
		if not is_instance_valid(zone_owner) or zone_owner.get("is_dead") == true:
			continue
		if zone_owner == target:
			return null
		var zone_radius: float = float(zone_owner.get("paladin_zone_radius"))
		if zone_radius <= 0.0:
			continue
		if target.global_position.distance_to(zone_owner.global_position) > zone_radius + ZONE_FOCUS_MARGIN:
			continue
		var own_dist: float = global_position.distance_to(zone_owner.global_position)
		if own_dist < best_dist:
			best_dist = own_dist
			best = zone_owner as Node2D
	return best


## En yakın geçerli oyuncuyu (yerel oyuncu veya RemotePlayer kuklaları) bulur.
## Görünmez veya ölü olan oyuncuları atlar.
func _find_closest_target_player() -> Node2D:
	var closest: Node2D = null
	var min_d: float = INF
	
	# 1. Yerel oyuncuyu kontrol et
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p):
		var is_inv: bool = local_p.has_method("is_invisible_now") and local_p.is_invisible_now()
		## Ev içindeyken (bkz. player.gd is_indoors/house_interior.gd) oyuncu
		## görünmezmiş gibi tamamen hedef dışı bırakılır - yaratıklar ne
		## yürür ne saldırır (bkz. bu değerin aşağıdaki kullanımı ve
		## _physics_process'teki player_is_invisible ile AYNI desen).
		var is_indoors: bool = local_p.has_method("is_indoors_now") and local_p.is_indoors_now()
		## Seyyar satıcının güvenli bölgesi (bkz. player.gd is_in_merchant_zone
		## üstündeki yorum) - is_indoors ile BİREBİR AYNI muamele.
		var is_in_merchant_zone: bool = local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()
		var is_d: bool = local_p.get("is_dead") if "is_dead" in local_p else false
		if not is_inv and not is_indoors and not is_in_merchant_zone and not is_d:
			var d: float = global_position.distance_to(local_p.global_position)
			if d < min_d:
				min_d = d
				closest = local_p as Node2D
	
	# 2. Çok oyunculuda RemotePlayer'ları da kontrol et
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp):
				continue
			var is_d: bool = rp.get("is_dead") if "is_dead" in rp else false
			## Klasik canlanma sistemi (bkz. player.gd is_downed/_go_down):
			## downed bir katılımcı ağa BİLEREK "is_dead=false" olarak
			## bildirilir (bkz. main.gd state_snapshot yorumu - kuklasının
			## silinmesini önlemek için) - yani yukarıdaki is_d kontrolü tek
			## başına onu hariç TUTMAZ. remote_player.gd'nin AYRI is_downed
			## bayrağı (bkz. orada) burada da kontrol edilmeli, yoksa
			## yaratıklar yerde yatan/çaresiz bir oyuncuyu hedeflemeye devam
			## eder.
			var is_downed: bool = rp.get("is_downed") if "is_downed" in rp else false
			var is_inv: bool = rp.get("is_invisible") if "is_invisible" in rp else false
			## bkz. remote_player.gd is_indoors / main.gd state_snapshot -
			## ev içindeki bir katılımcı da AYNI şekilde hedef dışı.
			var rp_indoors: bool = rp.get("is_indoors") if "is_indoors" in rp else false
			## Seyyar satıcının güvenli bölgesi - rp_indoors ile AYNI desen.
			var rp_in_merchant_zone: bool = rp.get("is_in_merchant_zone") if "is_in_merchant_zone" in rp else false
			if not is_inv and not is_d and not is_downed and not rp_indoors and not rp_in_merchant_zone:
				var d: float = global_position.distance_to(rp.global_position)
				if d < min_d:
					min_d = d
					closest = rp as Node2D

	## DÜZELTME (kullanıcı isteği #33: "Necromancerın yaratıklarına
	## saldırmıyor diğer yaratıklar, ölmedikleri için de 10 taneden fazla
	## spawnlanamıyor, necromancer bir süre sonra hiçbir işe yaramıyor") -
	## kök neden: yaratıklar SADECE gerçek oyuncuları (yukarıdaki 1/2)
	## hedefliyordu, "player_allies" (necromancer'ın iskelet/hortlak
	## yaratıkları, bkz. skeleton_pet.gd/wraith_pet.gd) hiç aday bile
	## değildi - bu yüzden yaratıklar onların yanından geçip gidiyor,
	## onlara hiç yaklaşmıyordu. skeleton_pet.gd/wraith_pet.gd zaten
	## KENDİ _process_incoming_damage()'ıyla yakınındaki (40px) yaratıklardan
	## temas hasarı alıyor (bkz. o dosyadaki not - enemy.gd'nin asıl
	## saldırı/çarpışma koduna hiç dokunmadan) - eksik olan tek şey
	## yaratıkların onlara doğru YÜRÜMESİYDİ, bu da tam olarak burada
	## (hedef seçiminde) eksikti. Artık gerçek bir oyuncudan daha yakınsa
	## necromancer yaratığı da hedef olarak seçilebiliyor.
	## Kullanıcı isteği (2026-09-24): "necromancerın yaratıkları daha çok ilgi çeksin yaratıklardan onları görmezden
	## gelmemeliler yakınlarındalarsa" - eskiden müttefik SADECE oyuncudan kesinlikle daha yakınsa seçiliyordu; oyuncu biraz
	## daha yakınsa yaratık yanındaki iskeletin önünden geçip gidiyordu. Artık ALLY_AGGRO_RADIUS içindeki müttefiğin mesafesi
	## ALLY_AGGRO_BIAS ile küçültülerek karşılaştırılır: yakındaki iskelet/golem, oyuncu neredeyse temas mesafesinde değilse
	## hedef olur. Menzil dışındaki müttefik eski kuralla (gerçek mesafe) yarışır.
	for ally: Node in get_tree().get_nodes_in_group("player_allies"):
		if not is_instance_valid(ally):
			continue
		var is_d2: bool = ally.get("is_dead") if "is_dead" in ally else false
		if not is_d2:
			var d2: float = global_position.distance_to(ally.global_position)
			if d2 <= ALLY_AGGRO_RADIUS:
				d2 *= ALLY_AGGRO_BIAS
			if d2 < min_d:
				min_d = d2
				closest = ally as Node2D

	return closest


## Kalkan baloncuğu (Şovalye/Paladin ULTİ) aktif olan TÜM oyuncuları döner -
## yerel oyuncu VE multiplayer'daki tüm RemotePlayer'lar dahil (bkz.
## _physics_process'teki kullanım notu). Normalde en fazla bir tane olur ama
## teoride birden fazla Şovalye varsa hepsi ayrı ayrı kontrol edilir.
##
## PERF DÜZELTMESİ (profiler: Enemy._paladin_zone_owners 150 yaratıkta 150
## kez/kare çağrılıyordu, her seferinde "player" + "remote_players"
## gruplarını baştan tarıyordu - halbuki sonuç aynı karedeki TÜM yaratıklar
## için birebir aynı, ve ulti çoğu zaman hiç aktif değil). _rebuild_
## separation_grid_if_needed'daki AYNI desen (bkz. yukarısı, static var +
## Engine.get_physics_frames() ile kare-başına-bir-kez önbellekleme)
## uygulandı - liste artık kare başına 1 kez hesaplanıp tüm yaratıklar
## arasında paylaşılıyor.
static var _zone_owners_cache: Array = []
static var _zone_owners_cache_frame: int = -1

## Önbelleği elle sıfırlar - fizik karesi ilerlemeyen test ortamları (bkz. tests/
## test_paladin_aggro_talon_pose_and_stat_tweaks.gd) için; oyunda çağrılmaz.
static func reset_zone_owners_cache() -> void:
	_zone_owners_cache = []
	_zone_owners_cache_frame = -1

func _paladin_zone_owners() -> Array:
	var frame: int = Engine.get_physics_frames()
	if frame == _zone_owners_cache_frame:
		return _zone_owners_cache
	_zone_owners_cache_frame = frame
	var owners: Array = []
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p) and local_p.get("paladin_zone_active") == true:
		owners.append(local_p)
	if NetworkManager.is_multiplayer_active:
		for rp: Node in get_tree().get_nodes_in_group("remote_players"):
			if is_instance_valid(rp) and rp.get("paladin_zone_active") == true:
				owners.append(rp)
	_zone_owners_cache = owners
	return owners


func _process_freeze(delta: float) -> void:
	if not is_frozen:
		return
	_freeze_timer -= delta
	if _freeze_timer <= 0.0:
		var was_ice: bool = not is_stunned
		is_frozen = false
		is_stunned = false
		## Ebedi Kış: donma bitince yavaşlık kalır.
		if was_ice and _linger_slow > 0.0 and not is_dead:
			apply_slow(_linger_slow, 3.0)
		if _freeze_status_fx and is_instance_valid(_freeze_status_fx):
			_freeze_status_fx.queue_free()
		_freeze_status_fx = null
		if _stun_status_fx and is_instance_valid(_stun_status_fx):
			_stun_status_fx.queue_free()
		_stun_status_fx = null
		if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
			var net_id: int = int(get_meta("network_enemy_id", 0))
			if net_id > 0:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "freeze_stop")
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "stun_stop")


## Kullanıcı isteği: Melek'in yeni 3. yeteneği (Kutsal Korku) - apply_freeze_
## full() ile AYNI host-yönlendirme deseni (bkz. network_manager.gd
## request_enemy_effect "fear" case'i), ama etki "dur" değil "source_pos'tan
## uzağa kaç" (bkz. _physics_process'teki is_feared dalı).
func apply_fear(source_pos: Vector2, duration: float = FEAR_DURATION) -> void:
	if is_dead or is_boss:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "fear", duration, source_pos.x, source_pos.y)
		return
	## DÜZELTME: eskiden `max(duration, _fear_timer if is_feared else 0.0)` is_feared=true atamasından SONRA okunuyordu
	## (koşul hep doğru) - sonuç aynıydı ama niyet belirsizdi; artık açıkça "kalan süreden kısa bir korku onu kısaltmaz".
	var was_feared: bool = is_feared
	_fear_timer = max(duration, _fear_timer if is_feared else 0.0)
	is_feared = true
	_fear_wander = false
	_fear_source_pos = source_pos
	_set_fear_visual(true, _fear_timer, not was_feared)


## Necromancer ULTİ (Lanetli Kafatası) korkusu: yaratık kaynaktan kaçmak yerine RASTGELE yönlerde yürür (her 0.45-1sn'de bir
## yön değiştirir, engellerden kayar) ve hasar veremez. affect_boss=false iken bosslar, Melek korkusundaki AYNI kuralla
## (bosslar korkmaz) muaf kalır - bkz. necro_skull.gd FEAR_AFFECTS_BOSSES. apply_fear ile AYNI host-yönlendirme deseni
## (network_manager.gd request_enemy_effect "fear_wander": param1=süre, param2=boss dahil mi).
func apply_fear_wander(duration: float, affect_boss: bool = false) -> void:
	if is_dead or (is_boss and not affect_boss):
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "fear_wander", duration, 1.0 if affect_boss else 0.0, 0.0)
		return
	var was_feared: bool = is_feared
	_fear_timer = max(duration, _fear_timer if is_feared else 0.0)
	is_feared = true
	_fear_wander = true
	_fear_wander_retarget = 0.0
	_set_fear_visual(true, _fear_timer, not was_feared)


func _process_fear(delta: float) -> void:
	if not is_feared:
		return
	_fear_timer -= delta
	if _fear_timer <= 0.0:
		is_feared = false
		_fear_wander = false
		_set_fear_visual(false)


## Rastgele yürüme yönü (korku - apply_fear_wander): kısa aralıklarla yeni bir rastgele yön seçer.
func _fear_wander_velocity(delta: float) -> Vector2:
	_fear_wander_retarget -= delta
	if _fear_wander_retarget <= 0.0:
		_fear_wander_retarget = randf_range(FEAR_WANDER_TURN_MIN, FEAR_WANDER_TURN_MAX)
		_fear_wander_dir = Vector2.from_angle(randf() * TAU)
	var steered: Vector2 = _steer_around_obstacle(_fear_wander_dir)
	_update_facing(_fear_wander_dir)
	return steered * speed * FEAR_WANDER_SPEED_MULT * _chill_speed_mult() * _slow_speed_mult()


## Korku göstergesi: SADECE host (ya da tek oyunculu) karar verir, diğer istemcilere broadcast_enemy_vfx ile yayınlar.
## Ağ trafiği: kafatası aynı kalabalığa saniyede birkaç kez çarpıp korkuyu TAZELER - her tazelemede reliable RPC atmamak
## için yalnızca korku BAŞLARKEN (announce) ve BİTERKEN yayınlanır. Uzak kopyadaki gösterge bu yüzden kendi süresiyle
## değil "fear_stop" ile kalkar (FEAR_REMOTE_VISUAL_SAFETY sadece emniyet).
const FEAR_REMOTE_VISUAL_SAFETY := 30.0

func _set_fear_visual(on: bool, duration: float = 0.0, announce: bool = true) -> void:
	if on:
		_spawn_fear_status_fx(duration)
	else:
		_remove_fear_status_fx()
	if (announce or not on) and NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			if on:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "fear_start", {"duration": FEAR_REMOTE_VISUAL_SAFETY})
			else:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "fear_stop")


func _spawn_fear_status_fx(duration: float) -> void:
	if not _fear_status_fx or not is_instance_valid(_fear_status_fx):
		_fear_status_fx = FearStatusFxScene.instantiate()
		add_child(_fear_status_fx)
	if _fear_status_fx.has_method("setup"):
		_fear_status_fx.setup(duration)


func _remove_fear_status_fx() -> void:
	if _fear_status_fx and is_instance_valid(_fear_status_fx):
		_fear_status_fx.queue_free()
	_fear_status_fx = null


## Rough on-screen height (post any boss scale_mult) used to place a boss's
## overhead health/shield bar clear of its head - see enemy_spawner.gd's
## _attach_boss_bar, the only caller (regular enemies never get a bar).
func get_overhead_bar_offset() -> float:
	if frame_sprite:
		return -(cell_size * frame_sprite.scale.y * 0.5 + 26.0)
	return -70.0


## Genel hız ayarı: oyundaki her şeyin hareket hızı %20 düşürüldü, ardından
## düşmanlara %20 daha indirildi (0.8 * 0.8 = 0.64), en son da yaratıklara
## özel %25 daha indirildi (0.64 * 0.75 = 0.48, bkz. kullanıcı isteği).
## Düşman hızları sahne dosyalarında tek tek tanımlı olduğu için burada
## topluca çarpılıyor (30+ sahneyi elle değiştirmek yerine).
## 2026-09-25: "yaratıkların hareket hızını %10 arttır" - 0.48 -> 0.528 (x1.1), öfke çarpanı ayrıca kısıldı (bkz.
## RAGE_SPEED_CUT_2026_09_25).
const GLOBAL_SPEED_SCALE := 0.528

## "Body block" sistemi: yaratıklar artık oyuncunun tam üstüne/içine kadar
## yürüyemiyor - hedefe olan mesafe, düşmanın kendi gövde çember yarıçapı +
## oyuncunun gövde çember yarıçapı toplamına (bkz. player.tscn'deki
## CollisionShape2D, radius=16.0) indiğinde ilerleme durduruluyor (bkz.
## _physics_process, min_separation). Bu fiziksel collision layer/mask'a değil
## doğrudan mesafe koduna dayanıyor - farklı yaratıkların gövde yarıçapı çok
## değiştiği için (12.8'den 44.2'ye kadar) her sahnede tutarlı çalışıyor.
## ÖNEMLİ: yaratık sahnelerindeki collision_mask 1'den 0'a düşürüldü çünkü
## oyuncunun main.tscn'deki gerçek collision_layer'ı da (kazara) 1'di - bu
## rastlantısal eşleşme Godot'un kendi fizik motorunun da aynı anda ayrı bir
## itme/engelleme uygulamasına yol açıyordu, bu kod ile çakışıp karakterin
## yaratığa "yapışması"/sürüklenmesine ve hasar sinyalinin (HitArea
## enter/exit) titreşip kilitlenmesine sebep oluyordu. Artık tek otorite bu
## mesafe kodu.
## DÜZELTME (kullanıcı isteği: "body blockları ufalt") - player.gd'deki
## KOPYASIYLA (16->12) birebir aynı kalmalı.
## Kullanıcı isteği ("tüm oynanabilir karakterleri %5 küçült"): oyuncunun gövde
## çemberi %5 küçüldüğü için bu sabit de 12 -> 11.4 oldu - player.gd'deki
## kopyasıyla AYNI anda değiştirildi (ikisi eşit olmazsa iki taraf farklı
## body-block sınırında anlaşır).
const PLAYER_BODY_RADIUS := 11.4

## Yakından vuran (is_ranged=false) yaratıklar oyuncuya hasar verdiğinde
## hafifçe geri tepiliyor - body block tek başına oyuncunun etrafında sabit,
## sıkı bir yaratık halkası oluşturacağı için (bkz. yukarıdaki not), bu küçük
## geri tepme halkayı gevşetip oyuncunun yaratıkların arasında sıkışmış
## hissetmesini engelliyor.
const MELEE_HIT_RECOIL := 22.0


## Yaratıklar arası doğal boşluk: çok sayıda yaratık spawn olup oyuncuya
## akın edince gövdeleri üst üste yığılıp "iç içe geçmiş" gibi görünüyordu
## (kullanıcı bildirimi: "yaratıklar artınca çok fazla iç içe giriyorlar...
## aralarında biraz aralık olmalı doğal durmaları için"). Fiziksel
## collision_layer/mask'a dayanmıyor (mask=0, bkz. yukarıdaki PLAYER_BODY_
## RADIUS notu) - oyuncu-yaratık ayrımıyla aynı mantıkla saf mesafe temelli,
## YUMUŞAK bir itme: doğrudan position'ı teleport ETMEZ, velocity'ye eklenir
## ki hareket akıcı/organik kalsın, "titreme" olmasın. Sadece gerçekten
## yakın komşular etkiler (ENEMY_SEPARATION_CHECK_RADIUS).
## DÜZELTME (kullanıcı bildirimi: "yaratık sayısını arttırdıktan sonra oyun
## çok kasmaya başladı, singleplayerda da"): bu notun eski hali "max_
## concurrent_enemies=42 olduğu için O(n²) tarama bile performans sorunu
## yaratmaz" diyordu - o varsayım enemy sayısı sonraki turlarda 42'den
## 63'e, sonra denemelerde 126/158'e çıkınca geçersiz kaldı (kimse geri
## dönüp bu notu/algoritmayı güncellemedi - CLAUDE.md'nin "iki ayrı yer"
## uyardığı hatayla AYNI aile: BİR yerde sayı büyütüldü, performans
## varsayımının dayandığı BAŞKA bir yer unutuldu). Her yaratık HER fizik
## karesinde TÜM diğer yaratıklarla (mesafeden bağımsız, önce hesaplayıp
## SONRA eleyerek) karşılaştırıyordu - N yaratık için kare başına N² işlem
## (63'te ~4.000, 126'da ~16.000 - dörde katlanıyor, DOĞRUSAL değil
## KARESEL). Artık dünya, hücre boyutu ENEMY_SEPARATION_CHECK_RADIUS'u
## kapsayacak bir IZGARAYA bölünüyor (bkz. _rebuild_separation_grid_if_
## needed/_separation_push_from_enemy_grid) - her yaratık SADECE kendi
## hücresi + 8 komşusundaki (3x3) yaratıklarla karşılaştırılıyor, ki bu
## menzil dışındaki çoğunluğu baştan eler. Izgara kare başına TEK SEFER
## inşa ediliyor (fizik-karesi damgasıyla önbelleklenmiş), her yaratık ayrı
## ayrı yeniden kurmuyor.
const ENEMY_SEPARATION_GAP := 2.0
const ENEMY_SEPARATION_CHECK_RADIUS := 100.0
const ENEMY_SEPARATION_FORCE := 130.0
## Kullanıcı isteği: "yaratıklar body block olayı yüzünden birbirinden çok
## ayrı duruyor, şuanki halinden %50 daha yakın durabilmelerini sağla" -
## eskiden zorunlu minimum mesafe doğrudan iki yaratığın gövde yarıçapları
## TOPLAMIYDI (+ yukarıdaki 2.0 piksellik ihmal edilebilir boşluk), yani iki
## büyük yaratık birbirinden neredeyse kendi gövdeleri kadar uzakta
## duruyordu. GameManager.BODY_BLOCK_SCALE'in oyuncu-yaratık ayrımı için
## yaptığı AYNI şeyi (yarıçap toplamını küçültme) burada yaratık-yaratık
## ayrımı için yapıyor - min_gap yarıçap toplamının YARISI (+ sabit boşluk)
## olunca yaratıklar birbirlerinin gövdesine eskisinin iki katı kadar
## yakınlaşabiliyordu (aralarındaki zorunlu mesafe %50 azalmıştı).
## SONRAKİ TUR (kullanıcı bildirimi, ekran görüntüsüyle: "böyle üst üste
## görünmeleri çirkin oluyor, aralığı arttırmak gerek") - separation
## bug'ı (bkz. _cell_indices PackedInt32Array notu) düzelip yaratıklar
## GERÇEKTEN bu 0.5 sınırına oturunca 0.5'in görsel olarak FAZLA sıkı
## olduğu ortaya çıktı (önceden bug yüzünden hiç bu sınıra ulaşmıyorlardı,
## o yüzden fark edilmemişti). 0.5 -> 0.75 - eski (bug'lı) hissettirdiği
## "çok yakın" isteğinin bir kısmı korunuyor ama artık gövdeler görünür
## şekilde üst üste binmiyor.
const ENEMY_SEPARATION_SCALE := 0.75

## Knockback (Kitelama Seti vb.) artık ANINDA ışınlama değil (bkz. kullanıcı
## isteği: "itme yumuşak bir şekilde yavaşlayarak dursun, aniden ışınlanmasın")
## - weapon.gd/projectile.gd artık doğrudan global_position değiştirmek yerine
## apply_knockback_force() çağırıyor, bu da _compute_enemy_separation ile
## AYNI mantıkla (velocity'ye eklenen, her karede sönümlenen bir "itiş hızı")
## çalışıyor - hareket akıcı kalıyor ve doğal biçimde yavaşlayıp duruyor.
const KNOCKBACK_DECAY := 1400.0 ## px/sn^2 - itiş hızının sönümlenme oranı
const KNOCKBACK_MAX_SPEED := 400.0
var _knockback_velocity: Vector2 = Vector2.ZERO

## BUG DÜZELTMESİ (derin denetim bulgusu: "collision shapeden geçemediği
## için duvarda sıkışıyor doğru yolu bulmaya çalışmıyor") - kök neden:
## haritadaki engeller (su/ev, bkz. GameManager.is_position_blocked_by_
## terrain) gerçek fizik collision'ı DEĞİL, _block_movement_into_terrain()
## ile HER karede oyuncuya olan düz çizgi yönünü ekseni ekseni sıfırlayan
## bir sorgu - Godot'un move_and_slide() "duvar boyunca kayma" davranışı
## devreye giremiyor (kayacağı gerçek bir fizik şekli yok), yaratık oyuncuya
## neredeyse eksen-hizalı bakıyorsa velocity her karede ~0'a çöküp orada
## donuk kalıyordu. Bu üç değişken bunu tespit edip (bir süre gerçek yer
## değiştirme olmuyorsa) bir dik yönde "yan adım" atarak engeli dolanmayı
## dener - navmesh kurmak yerine hafif bir yönlendirme katmanı (bkz.
## _steer_around_obstacle çağrı yeri).
var _stuck_check_timer: float = 0.0
var _stuck_check_pos: Vector2 = Vector2.ZERO
var _is_stuck: bool = false
var _stuck_side_sign: float = 1.0
const STUCK_CHECK_INTERVAL := 0.4
const STUCK_MIN_DISPLACEMENT := 12.0 ## bu süre içinde bu kadar bile ilerlemediyse "sıkışmış" say

## --- Duvar dolanma / yol bulma (kullanıcı bildirimi: "yaratıklar collision
## shapelerin etrafından dolanıp beni bulmayı akıl edemiyor") ---
## Kök neden: yaratık oyuncuya DÜZ çizgide yürüyor, _block_movement_into_terrain
## sadece duvara giren ekseni iptal ediyor -> içbükey bir kayalığın önünde/cebinde
## sonsuza dek takılıyor (_steer_around_obstacle rastgele yana döner ama büyük bir
## duvarın ötesini göremez). Artık oyuncuya düz çizgi bir orman duvarıyla kesilince
## enemy_pathing.gd'nin A* yolunun dönüş noktaları izleniyor; çizgi AÇIKKEN hiçbir şey
## değişmez (bugünkü davranış). Simülasyon zaten sadece host'ta çalışıyor.
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const ROUTE_LINE_CHECK_INTERVAL := 0.2 ## düz çizgi engelli mi kontrolü (sn, yaratık başına faz kaydırmalı)
const ROUTE_REPLAN_INTERVAL := 1.0 ## engelliyken yolu yenileme aralığı (sn)
const ROUTE_RETRY_AFTER_FAIL := 2.5 ## yol bulunamazsa (kapalı cep vb.) tekrar deneme bekleme süresi
const ROUTE_WAYPOINT_REACHED := 10.0 ## dönüş noktasına bu kadar yaklaşınca sıradakine geç
const ROUTE_GOAL_MOVED_REPLAN := 48.0 ## hedef yol sonundan bu kadar uzaklaşırsa hemen yeniden planla
## PERF (kullanıcı bildirimi: "oyunda hâlâ drop/fps düşüklüğü", profilde yaratık
## fiziğinin ~yarısı yol bulma): hedef ROUTE_GOAL_MOVED_REPLAN kadar kayınca eskiden HER
## duvar-arkası yaratık baştan A* istiyordu - oyuncu duvarlar arasında YÜRÜDÜKÇE kare
## bütçesi (4 yol/adım, yol başına ~0.9 ms) hep doluydu. Ölçüm (190 yaratık, gerçek
## harita, oyuncu yürürken): yol bulma ~3.1 -> ~0.8 ms/fizik adımı (bkz. enemy_pathing.gd
## _cells_line_blocked'daki döngü düzeltmesiyle birlikte). Önceki perf testleri oyuncuyu
## hiç yürütmediği için bunu kaçırmıştı. Artık yolun son noktasından yeni hedef düz
## çizgiyle görünüyorsa hedef yola EKLENİR (tek kısa çizgi kontrolü); görünmüyorsa ya da
## yol ROUTE_MAX_POINTS'e ulaştıysa eskisi gibi yeniden planlanır. ROUTE_REPLAN_INTERVAL
## yenilemesi aynen duruyor, yani eklemeyle uzayan (dolambaçlı olabilecek) yol en geç
## ~1 sn'de yeniden düzelir. (Yakın yaratıklar arasında yol PAYLAŞMA da denendi: oyuncu
## dururken yaratıkların etrafında toplanmasını bozdu, kazancı gürültü seviyesindeydi -
## geri alındı.)
const ROUTE_MAX_POINTS := 24
var _route: PackedVector2Array = PackedVector2Array()
var _route_index: int = 0
var _route_goal_pos: Vector2 = Vector2.ZERO
var _route_line_timer: float = 0.0
var _route_replan_timer: float = 0.0
var _route_line_blocked: bool = false
## True iken bu karede hareket yönü dönüş noktasına doğru (bkz. _route_direction).
var _route_active: bool = false


## weapon.gd/projectile.gd tarafından çağrılır - dir yönünde force kadar bir
## itiş hızı ekler (üst üste birikebilir, ama toplam KNOCKBACK_MAX_SPEED'i
## aşamaz).
func apply_knockback_force(dir: Vector2, force: float) -> void:
	if force <= 0.0:
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_knockback_velocity += d * force
	if _knockback_velocity.length() > KNOCKBACK_MAX_SPEED:
		_knockback_velocity = _knockback_velocity.normalized() * KNOCKBACK_MAX_SPEED


## BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-24: "normal yaratıklarda geri tepme çalışmıyor sadece bosslarda ve
## kopyalarda çalışıyor"): silah/mermi itişi (Kitelama Seti knockback_stat = 40, öfke/kart bonusları) eskiden "bu kadar
## piksel ışınla" demekti; yumuşak itişe geçilirken AYNI sayı apply_knockback_force'a HIZ (px/sn) olarak verilmeye
## başlandı - KNOCKBACK_DECAY (1400 px/sn²) ile 40 px/sn'lik itiş toplam 40²/(2*1400) = 0.57 px kaydırıyordu (görünmez).
## Kopyanın apply_knockback_force'u olmadığı için hâlâ 40 px ışınlanıyordu - "kopyalarda çalışıyor" bundan. Artık silah/
## mermi itişi MESAFE olarak bu fonksiyondan gelir: sönümlemeyle tam o mesafeyi kat edecek başlangıç hızı hesaplanır
## (v0 = sqrt(2 * decay * mesafe) - 40 px ~0.24 sn'de yumuşakça). Diğer itişler (oyuncunun gövdeyle itmesi, yaratıkların
## çarpışma sekmesi) zaten hız cinsinden ayarlı, apply_knockback_force'ta kalıyor. Çok oyunculuda istemcinin vuruşu
## (burada kukla) host'taki GERÇEK yaratığa iletilir - eskiden kuklada kalıp host'un konum yayınıyla siliniyordu.
const KNOCKBACK_DISTANCE_MAX := 60.0 ## tek isabette en fazla bu kadar px (çok sayıda Kitelama Seti yığılsa bile) - 2026-09-24: 120 -> 60
## Kullanıcı isteği (2026-09-24): "geri tepme aşırı güçlenmiş gücünü %70 nerflemen gerekiyor" - mesafe tabanlı itişe
## geçince (yukarıdaki düzeltme) istenen px'in tamamı gerçekten kat edilir oldu; tüm silah/mermi itişleri %30'una iner.
## Host tarafında TEK kez uygulanır (istemci isteği RPC ile ham mesafeyi taşır).
## Kullanıcı bildirimi (2026-09-24, ikinci tur): "Geri tepme hala çok güçlü ve çok geriye itiyor". Kök neden tek vuruşun
## büyüklüğü değil BİRİKİMDİ: her isabet itişi baştan başlatıyordu - birkaç silah saniyede birkaç kez vurunca (1 kart =
## 70 x 0.3 = 21 px her ~0.2 sn) yaratık ~100 px/sn geriye kayıyordu, çoğu yaratığın yürüme hızından fazla -> hiç
## yaklaşamıyorlardı. Artık: taban çarpan 0.30 -> 0.20, tavan 120 -> 60 px, ve aynı yaratığa KNOCKBACK_REPEAT_WINDOW
## içinde gelen her ek itiş KNOCKBACK_REPEAT_MULT'la küçülür (ilk vuruş hissedilir, sürekli ateş yaratığı tutamaz:
## 1 kartla ilk vuruş 14 px, ardından ~3.5 px'lik küçük sarsıntılar).
const KNOCKBACK_DISTANCE_MULT := 0.20
const KNOCKBACK_REPEAT_WINDOW := 0.7 ## sn
const KNOCKBACK_REPEAT_MULT := 0.25
var _last_knockback_msec: int = -100000

func apply_knockback_distance(dir: Vector2, distance: float) -> void:
	if distance <= 0.0:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_knockback.rpc_id(NetworkManager._host_peer_id(), net_id, dir, distance)
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var now_msec: int = Time.get_ticks_msec()
	var repeat_mult: float = KNOCKBACK_REPEAT_MULT if (now_msec - _last_knockback_msec) < int(KNOCKBACK_REPEAT_WINDOW * 1000.0) else 1.0
	_last_knockback_msec = now_msec
	var v0: float = sqrt(2.0 * KNOCKBACK_DECAY * minf(distance * KNOCKBACK_DISTANCE_MULT * repeat_mult, KNOCKBACK_DISTANCE_MAX))
	## Birikim: mevcut itişin bu yöndeki bileşeninden hızlıysa eklenir, değilse (zaten daha hızlı itiliyorsa) dokunulmaz.
	var along: float = _knockback_velocity.dot(d)
	if along < v0:
		_knockback_velocity += d * (v0 - maxf(along, 0.0))


## Kullanıcı isteği: "yaratıkların hedefi yokken etrafta arada rasgele
## dolanmalı bazen de durmalılar ve doğal davranmalılar." - hedef yokken
## (kimse yakında yok, ya da herkes görünmez/ev içi/seyyar satıcı güvenli
## bölgesinde, bkz. _physics_process'teki "else" dalı) eskiden dümdüz
## velocity=ZERO ile donup kalıyorlardı. Basit bir "dolaş / dur" döngüsü:
## her karar noktasında ya kısa bir süre YERİNDE durur ya da yakın rastgele
## bir noktaya doğru YAVAŞÇA yürür - saldırı/kovalama hızından (speed'in
## kendisinden) BİLEREK daha yavaş (WANDER_MOVE_SPEED_MULT) ki "amaçsız
## dolaşma" hissi versin, "beni fark etmedi ama yine de tam hızla koşuyor"
## gibi garip görünmesin. Chill/slow/rage tonlarına (bkz. _chill_speed_mult
## vb.) hâlâ tabi - bir yaratık donmadan hemen önce/rage'e girerken bile
## hedefsiz kalabilir, o durumlarda da tutarlı hızda dolaşmalı.
const WANDER_MOVE_SPEED_MULT := 0.45
const WANDER_RADIUS := 120.0
const WANDER_ARRIVE_DIST := 12.0
const WANDER_MOVE_DURATION_MIN := 1.5
const WANDER_MOVE_DURATION_MAX := 3.5
const WANDER_PAUSE_DURATION_MIN := 1.0
const WANDER_PAUSE_DURATION_MAX := 3.0
## Her yeni karar noktasında dolaşmak yerine durma ihtimali.
const WANDER_PAUSE_CHANCE := 0.4

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _wander_moving: bool = false

func _compute_wander_velocity(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or (_wander_moving and global_position.distance_to(_wander_target) <= WANDER_ARRIVE_DIST):
		if randf() < WANDER_PAUSE_CHANCE:
			_wander_moving = false
			_wander_timer = randf_range(WANDER_PAUSE_DURATION_MIN, WANDER_PAUSE_DURATION_MAX)
		else:
			_wander_moving = true
			var angle: float = randf() * TAU
			var dist: float = randf_range(WANDER_RADIUS * 0.3, WANDER_RADIUS)
			_wander_target = global_position + Vector2(cos(angle), sin(angle)) * dist
			_wander_timer = randf_range(WANDER_MOVE_DURATION_MIN, WANDER_MOVE_DURATION_MAX)
	if not _wander_moving:
		return Vector2.ZERO
	var to_target: Vector2 = _wander_target - global_position
	if to_target.length() <= WANDER_ARRIVE_DIST:
		return Vector2.ZERO
	var wander_dir: Vector2 = _steer_around_obstacle(to_target.normalized())
	_update_facing(wander_dir)
	return wander_dir * speed * WANDER_MOVE_SPEED_MULT * _chill_speed_mult() * _slow_speed_mult() * _rage_speed_mult()


## Kullanıcı isteği: "haritamdaki 'su' ve 'ev' layerlarını collisionshape
## olarak atar mısın... yaratıklar orada spawnlanamaz içinden geçemez" -
## bkz. GameManager.is_position_blocked_by_terrain yorumu ve player.gd'deki
## BİREBİR AYNI teknik (_block_movement_into_terrain).
## DÜZELTME (kullanıcı bildirimi: "collision shapeler tam su layerının
## olduğu yerlerde değil... aşırı geniş olmuş") - yoklama mesafesi eskiden
## bu yaratığın _body_radius'una bağlıydı (12.8'den 44.2'ye kadar
## değişebiliyor); büyük gövdeli yaratıklar suyun GERÇEK sınırından 40+
## piksel (neredeyse 3 karo) önce duruyordu - kullanıcının şikayet ettiği
## "orada layer yokmuş gibi görünen ama geçilmeyen" fazladan tampon bölge
## tam olarak buydu. Artık gövde boyutundan bağımsız, sabit ve küçük bir
## tampon kullanılıyor (player.gd'deki AYNI değer) - blok alanı su/ev
## karolarının gerçek sınırına çok daha yakın.
## bkz. _is_stuck üstündeki BUG DÜZELTMESİ notu. `_physics_process`'te her
## karede çağrılır, ama gerçek kontrol sadece STUCK_CHECK_INTERVAL'da bir
## yapılır. Gerçekten hareket etmeye ÇALIŞIYORSAK (moving_intent) ama
## konumumuz neredeyse hiç değişmediyse "sıkışmış" sayılır.
func _update_stuck_state(delta: float, moving_intent: bool) -> void:
	_stuck_check_timer -= delta
	if _stuck_check_timer > 0.0:
		return
	_stuck_check_timer = STUCK_CHECK_INTERVAL
	var displacement: float = global_position.distance_to(_stuck_check_pos)
	_is_stuck = moving_intent and displacement < STUCK_MIN_DISPLACEMENT
	if _is_stuck and randf() < 0.5:
		## Sıkışma her tespit edildiğinde (yaklaşık %50 ihtimalle) yön
		## tarafını yeniden zar at - aynı tarafa kilitlenip o taraf da
		## kapalıysa sonsuza dek orada kalınmasın.
		_stuck_side_sign = -1.0 if _stuck_side_sign > 0.0 else 1.0
	_stuck_check_pos = global_position


## Sıkışmışken ham "oyuncuya doğrudan" yönü, engelin YANINDAN dolanacak
## şekilde büker - önce düz yönün gerçekten engelli olup olmadığı kontrol
## edilir (sıkışma yanlış pozitifse - ör. başka bir yaratık tarafından
## sıkıştırılmışsa - orijinal yön bozulmadan kalsın).
func _steer_around_obstacle(dir: Vector2) -> Vector2:
	if not _is_stuck or dir.length() < 0.01:
		return dir
	var probe_ahead: Vector2 = global_position + dir * 24.0
	if not GameManager.is_position_blocked_by_terrain(probe_ahead):
		return dir
	var perp: Vector2 = dir.rotated(PI * 0.5 * _stuck_side_sign)
	return (perp * 0.75 + dir * 0.25).normalized()


## Oyuncuya "doğrudan" yönü (dir) alır; aradaki orman duvarı yüzünden düz çizgi engelliyse
## A* yolunun sıradaki dönüş noktasına doğru yönü döndürür, değilse dir'i aynen. Bkz.
## dosya başındaki "Duvar dolanma" notu. Yol bulunamazsa/yoksa da dir döner (eski davranış).
func _route_direction(dir: Vector2, target_pos: Vector2, delta: float) -> Vector2:
	_route_active = false
	if not EnemyPathingScript.enabled:
		return dir
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: "ağacı koruma görevinde ... duvarlara doğru yürüyorlar dolanmak
	## yerine"): ağaç haritanın herhangi bir yerinde olabilir ve TÜM yaratıklar ona yürür - MAX_ROUTE_DISTANCE'tan
	## (oyuncu kovalamaya göre ayarlı, doğuş halkası ~640) uzaktakiler hiç yol aramadan düz çizgide duvara
	## dayanıyordu. Hedef sabit duran ağaçken mesafe sınırı yok (yol bir kez bulunup izleniyor, hedef kaymadığı
	## için yeniden planlama seyrek; kare bütçesi MAX_NEW_PATHS_PER_FRAME aynen geçerli).
	var static_mission_target: bool = false
	if GameManager.defend_tree_active and is_instance_valid(GameManager.defend_tree_ref):
		static_mission_target = target_pos == GameManager.defend_tree_ref.global_position
	if not static_mission_target and global_position.distance_to(target_pos) > EnemyPathingScript.MAX_ROUTE_DISTANCE:
		_route = PackedVector2Array()
		return dir
	## LOD: uzaktaki (bkz. _ensure_lod_classification) yaratıklar düz-çizgi/
	## A*-yeniden-planlama kontrollerini ENEMY_LOD_FAR_SLOWDOWN kat daha seyrek
	## yapar - oyuncu yaklaşıp "yakın" hale gelene kadar tam hassasiyete gerek yok.
	_ensure_lod_classification(get_tree())
	var lod_mult: float = float(ENEMY_LOD_FAR_SLOWDOWN) if _is_lod_far(get_instance_id()) else 1.0
	_route_line_timer -= delta
	if _route_line_timer <= 0.0:
		## Yaratıklar aynı karede hesaplamasın diye süre yaratık başına kaydırılıyor.
		_route_line_timer = ROUTE_LINE_CHECK_INTERVAL * lod_mult * randf_range(0.8, 1.2)
		_route_line_blocked = EnemyPathingScript.line_blocked(global_position, target_pos)
		if not _route_line_blocked:
			_route = PackedVector2Array()
	if not _route_line_blocked:
		return dir
	_route_replan_timer -= delta
	var goal_moved: bool = not _route.is_empty() and _route_goal_pos.distance_to(target_pos) > ROUTE_GOAL_MOVED_REPLAN
	if goal_moved and _route.size() < ROUTE_MAX_POINTS \
			and not EnemyPathingScript.line_blocked(_route[_route.size() - 1], target_pos):
		_route.append(target_pos)
		_route_goal_pos = target_pos
		goal_moved = false
	if (_route.is_empty() or _route_replan_timer <= 0.0 or goal_moved) and EnemyPathingScript.can_request():
		_route = EnemyPathingScript.find_path(global_position, target_pos)
		_route_index = 0
		_route_goal_pos = target_pos
		_route_replan_timer = (ROUTE_REPLAN_INTERVAL if not _route.is_empty() else ROUTE_RETRY_AFTER_FAIL) * lod_mult * randf_range(0.8, 1.3)
	if _route.is_empty():
		return dir
	while _route_index < _route.size() and global_position.distance_to(_route[_route_index]) < ROUTE_WAYPOINT_REACHED:
		_route_index += 1
	if _route_index >= _route.size():
		return dir
	_route_active = true
	return (_route[_route_index] - global_position).normalized()


## SU/EV İÇİN HÂLÂ KAPALI (kullanıcı isteği: "oyundaki collision shapeleri
## kaldır haritada istediğimiz yere hareket edebilelim sonra sıfırdan
## collision shape dizicem çünkü") - player.gd'deki AYNI isteğin BİREBİR
## eşleniği (bkz. orada _block_movement_into_terrain üstündeki not): yaratıklar
## su/ev karolarında serbest, ama yeniden dizmenin İLK ADIMI olan orman katmanı
## ("Orman parçaları/Orman parçaları" - kullanıcı isteği: "orman parçaları
## layerını collision shape ile kaplamanı istiyorum") geçilmez. Bu yüzden
## is_position_blocked_by_FOREST kullanılıyor, is_position_blocked_by_terrain
## (su+ev+orman) DEĞİL. Su/ev de açılacaksa üç çağrıyı ona çevirmek yeterli.
func _block_movement_into_terrain() -> void:
	if velocity.length_squared() < 0.01:
		return
	if not _refresh_forest_cache():
		return
	## Zaten duvarın İÇİNDEYSE (ör. eskiden kalma bir konum, knockback) engelleme
	## atlanır - yoksa prob her yönde yine karonun içine denk gelip yaratığı
	## SONSUZA DEK hapseder (bkz. player.gd'deki AYNI güvenlik ağı).
	if _forest_blocked(global_position):
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0:
		if _forest_blocked(global_position + Vector2(sign(velocity.x) * probe_dist, 0.0)):
			velocity.x = 0.0
	if velocity.y != 0.0:
		if _forest_blocked(global_position + Vector2(0.0, sign(velocity.y) * probe_dist)):
			velocity.y = 0.0


## PERF (kullanıcı bildirimi: 200 yaratıkta FPS çöküşü - profilde arazi+yapıştırma
## bölümü 200 yaratıkta ~2.5ms/fizik adımı): eskiden her prob GameManager.
## is_position_blocked_by_forest() üzerinden gidiyordu (autoload çağrısı +
## _find_terrain_layers + is_instance_valid + to_local/local_to_map/get_cell_
## source_id) - yaratık başına kare başına 3 kez. Orman katmanı ve ters dönüşümü
## artık fizik karesi başına TEK sefer alınıyor, prob sadece 2 yerel çağrı.
## Sonuç GameManager.is_position_blocked_by_forest ile BİREBİR aynı.
static var _forest_layer: TileMapLayer = null
static var _forest_inv: Transform2D = Transform2D.IDENTITY
static var _forest_frame: int = -1

static func _refresh_forest_cache() -> bool:
	var f: int = Engine.get_physics_frames()
	if f != _forest_frame:
		_forest_frame = f
		_forest_layer = GameManager.get_forest_layer()
		if _forest_layer != null:
			_forest_inv = _forest_layer.global_transform.affine_inverse()
	return _forest_layer != null

static func _forest_blocked(world_pos: Vector2) -> bool:
	return _forest_layer.get_cell_source_id(_forest_layer.local_to_map(_forest_inv * world_pos)) != -1


## GÖRÜŞ HATTI (kullanıcı bildirimi 2026-09-24: "yaratıklar duvarların arkasından ateş edebiliyor bunun olmaması
## gerekiyor onlar bizi göremediğinde ateş edememeliler"). Duvar = orman/uçurum katmanı - oyuncunun görüşünü
## (vision_fog) ve hareketini kesen AYNI katman (bkz. GameManager.get_forest_layer). Yaratıktan hedefe düz çizgi
## LOS_SAMPLE_STEP aralıkla örneklenir; uç noktaların LOS_END_IGNORE yakınındaki örnekler sayılmaz (duvara yaslanmış
## yaratık/oyuncu kendi karosunu "engel" saymasın). Sonuç hedef başına LOS_CACHE_MSEC boyunca önbellekte tutulur
## (hareket kararı her düşünme tikinde soruyor, 200 yaratıkta ucuz kalsın).
const LOS_SAMPLE_STEP := 10.0
const LOS_END_IGNORE := 10.0
const LOS_CACHE_MSEC := 150
var _los_target_id: int = 0
var _los_until_msec: int = 0
var _los_value: bool = true

func _has_line_of_sight(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var now: int = Time.get_ticks_msec()
	var tid: int = target.get_instance_id()
	if tid == _los_target_id and now < _los_until_msec:
		return _los_value
	_los_target_id = tid
	_los_until_msec = now + LOS_CACHE_MSEC
	_los_value = line_of_sight_clear(global_position, target.global_position)
	return _los_value


## Saf yardımcı (testler de çağırabilir): a ile b arasında orman/uçurum karosu yoksa true.
static func line_of_sight_clear(a: Vector2, b: Vector2) -> bool:
	if not _refresh_forest_cache():
		return true
	var length: float = a.distance_to(b)
	if length <= LOS_END_IGNORE * 2.0:
		return true
	var dir: Vector2 = (b - a) / length
	var d: float = LOS_END_IGNORE
	while d <= length - LOS_END_IGNORE:
		if _forest_blocked(a + dir * d):
			return false
		d += LOS_SAMPLE_STEP
	return true


## Hayalet (Vampir yarasa formu) durumu oyuncu başına fizik karesi başına TEK
## sefer soruluyor - eskiden her yaratık her karede has_method+çağrı yapıyordu.
static var _ghost_cache: Dictionary = {}
static var _ghost_cache_frame: int = -1

static func _is_ghost_cached(p: Node) -> bool:
	var f: int = Engine.get_physics_frames()
	if f != _ghost_cache_frame:
		_ghost_cache_frame = f
		_ghost_cache.clear()
	var id: int = p.get_instance_id()
	if _ghost_cache.has(id):
		return _ghost_cache[id]
	var v: bool = p.has_method("is_ghost_now") and p.is_ghost_now()
	_ghost_cache[id] = v
	return v

## DÜZELTME (kullanıcı isteği, sonraki tur: "necromancerin yaratıkları
## diğer yaratıklar itemez, onlar da necromancerı itemez") - "player_allies"
## grubuna (Necromancer'ın iskelet/golem/hortlakları) karşı olan karşılıklı
## itiş (bir önceki turda BİLEREK eklenmişti, bkz. skeleton_pet.gd/
## golem_pet.gd'deki eşleşen düzeltme notu) kaldırıldı - yaratıklar artık
## SADECE kendi türdeşleriyle ("enemies") ayrışıyor, Necromancer'ın
## müttefiklerinin içinden serbestçe geçebiliyor.
## DÜZELTME (kullanıcı sağladığı Profiler verisi): bu itiş HER fizik
## karesinde DEĞİL, her yaratık KENDİ fazında (get_instance_id()'ye göre
## kaydırılmış, hepsi AYNI karede tekrar hesaplamasın diye)
## SEPARATION_UPDATE_INTERVAL_FRAMES karede bir yeniden hesaplanıp aradaki
## karelerde önbelleğe alınan son değer kullanılıyor. Yumuşak/sürekli bir
## itiş kuvveti olduğu için birkaç karelik bayatlık gözle fark edilmez.
## DÜZELTME (kullanıcı bildirimi: "body block kalkmış, yaratıklar iç içe
## giriyor") - eskiden BUNUNLA BİRLİKTE bir komşu sayısı sınırı (16) da
## vardı; kalabalık kümelerde İLK BULUNAN 16 komşu dışındaki hiçbir
## yaratığa itiş uygulanmadığı için görünür şekilde iç içe giriyorlardı -
## o sınır TAMAMEN kaldırıldı (bkz. _separation_push_from_enemy_grid).
## Sınırsız komşu taraması yeniden CPU maliyetini geri getirdiği için (bkz.
## kullanıcı sağladığı 2. Profiler: 156 yaratıktan 50'si HÂLÂ ortalama ~100
## komşu kontrol ediyordu, tek başına kare süresinin %44'ü) bu sefer
## FREKANS ek olarak daha da düşürüldü (3 -> 6 kare, ~20Hz -> ~10Hz) - bu,
## komşu sınırının AKSİNE hiçbir yaratığı KALICI olarak es geçmiyor (her
## yaratık er ya da geç TAM/eksiksiz bir hesap alıyor, sadece daha seyrek),
## yani aynı "iç içe girme" hatasını YENİDEN yaratmıyor.
const SEPARATION_UPDATE_INTERVAL_FRAMES := 6
var _cached_separation_push: Vector2 = Vector2.ZERO
## DÜZELTME (kullanıcı bildirimi: "sürekli wiggle wiggle titriyorlar" - sıkı
## paketlenmiş kümede test edip doğrulandı, kontrollü A/B testte eski kodda da
## AYNI oranda var olan bir zayıflık, benim toplu geçişimin YENİ bir hatası
## değil). Kök neden: _cached_separation_push HER SEPARATION_UPDATE_INTERVAL_
## FRAMES(6) karede bir YENİ hedef değere ANİDEN "sıçrıyordu" - sıkışık/aşırı
## kısıtlı bir kümede komşu itiş yönleri kare kareye küçük konum farklarıyla
## ters dönebiliyor, bu da görünür bir "sallanma" oluşturuyor. Artık HEDEF
## değer (_target_separation_push) yine 6 karede bir yenileniyor ama
## UYGULANAN değer (_cached_separation_push) HER karede ona yumuşakça
## (lerp) yaklaşıyor - ani yön sıçramaları kayboluyor, ortalama davranış aynı.
var _target_separation_push: Vector2 = Vector2.ZERO
## DÜZELTME (kullanıcı bildirimi: "hala bitişikken titriyor bi o yana bi bu
## yana" - yumuşatma tek başına yetmedi). Kök neden farklı: sıkı paketlenmiş
## (altıgen benzeri) bir kümede her yaratık AYNI ANDA birden çok komşuya
## değiyor; komşular da KENDİ itişleriyle mikro hareket edince, hangi
## komşu-çiftinin "tam sınırda" sayılacağı kare kareye değişip net itiş
## yönünü gerçekten TERS ÇEVİREBİLİYOR (rastgele gürültü değil, gerçek
## salınan bir denge arayışı - sıkışık/aşırı kısıtlı sistemlerde beklenen bir
## davranış). İki parçalı düzeltme, ÖLÇÜLEREK (durgun/bitişik bir kümede
## kaç kez yön tersine döndüğünü sayan headless test) ayarlandı: (1) yumuşatma
## oranı ÖNEMLİ ÖLÇÜDE düşürüldü (0.35 -> 0.025 - ara değerler 0.18/0.06
## denendi, yön-tersine-dönme sayısı ancak bu kadar agresif bir sönümlemeyle
## belirgin şekilde azaldı: 30 yaratıklık bir kümede 3sn'de 124 -> 80 tersine
## dönüş, örtüşme kalitesi BOZULMADI/hatta iyileşti - worst_ratio 0.993'ten
## 1.0'ın üstüne çıktı), (2) itiş çok KÜÇÜKSE (yaratık zaten neredeyse doğru
## mesafede, sadece milimetrik bir ihlal varsa) hedef DOĞRUDAN SIFIRA
## yuvarlanıyor (bkz. ENEMY_SEPARATION_DEADZONE) - "neredeyse yerleşmiş" bir
## yaratığın gürültü seviyesindeki bir itişin peşinden sürekli sağa sola
## savrulmasını önlüyor, gerçek/belirgin bir çakışma varsa yine tam güçle
## tepki veriliyor. (Denendi ama İYİLEŞTİRMEDİ: lerp'in matematiksel olarak
## hiç sıfıra ulaşmayan "kuyruğunu" küçük değerlerde sıfıra yuvarlamak - bu
## kendi başına küçük bir süreksizlik/sıçrama kaynağı oldu, tersine dönüş
## sayısını azaltmak yerine artırdı, geri alındı.)
const ENEMY_SEPARATION_SMOOTH := 0.025 ## karede-karede hedefe yaklaşma oranı (1.0 = eski anlık sıçrama davranışı)
const ENEMY_SEPARATION_DEADZONE := 0.12 ## bu ham (kuvvet çarpanından ÖNCEKİ) büyüklüğün altındaki itişler SIFIR sayılır

## PERF DÜZELTMESİ (kullanıcı isteği: yaratık sayısını ciddi artır, solo'da da
## FPS düşüyordu) - eskiden HER "sırası gelen" yaratık kendi _physics_process'i
## içinden AYRI AYRI ızgarayı tarıyordu (Node.get()/global_position gibi yavaş
## dinamik erişimlerle). Artık aynı iş TEK bir toplu geçişte (bkz.
## _batch_compute_separation_if_needed) düz PackedVector2Array/PackedFloat32Array
## üzerinden hesaplanıp bir Dictionary'ye yazılıyor, burada sadece O(1) okunuyor.
## Kuvvet formülü ve frekans/faz kaydırma AYNEN korunuyor (bkz. _flat_pairwise_pair
## - _pairwise_separation_push ile BİREBİR aynı matematik), sadece Node yerine
## ham sayılar üzerinden çalışıyor.
## DÜZELTME (kullanıcı bildirimi: "yaratıklar birbirinin içine giriyor", 200
## limitiyle test sonrası) - uzak (LOD) yaratıklarda separation'ı TAMAMEN
## kapatmıştım; yaklaşan büyük bir sürü oyuncuya 1600px'den yakınlaşana kadar
## HİÇ ayrışmadan kümeleniyor, "yakın" olduklarında da zaten iç içe girmiş
## oluyorlardı - dosyadaki eski "16 komşu sınırı" hatasıyla (bkz. yukarısı,
## _separation_push_from_enemy_grid üstündeki not) AYNI hata sınıfı: bir grup
## yaratık separation'dan KALICI olarak muaf kalınca üst üste yığılıyor. Artık
## hedef/yol bulma ile AYNI desen - uzak yaratıklarda separation KAPANMIYOR,
## sadece ENEMY_LOD_FAR_SLOWDOWN kat daha seyrek (48 kare ~0.8sn) çalışıyor -
## hiçbir yaratık kalıcı olarak es geçilmiyor.
func _compute_enemy_separation() -> Vector2:
	_batch_compute_separation_if_needed(get_tree())
	var interval: int = SEPARATION_UPDATE_INTERVAL_FRAMES * (ENEMY_LOD_FAR_SLOWDOWN if _is_lod_far(get_instance_id()) else 1)
	if Engine.get_physics_frames() % interval == get_instance_id() % interval:
		var raw_push: Vector2 = _separation_results.get(get_instance_id(), Vector2.ZERO)
		_target_separation_push = Vector2.ZERO if raw_push.length() < ENEMY_SEPARATION_DEADZONE else raw_push * ENEMY_SEPARATION_FORCE
	_cached_separation_push = _cached_separation_push.lerp(_target_separation_push, ENEMY_SEPARATION_SMOOTH)
	return _cached_separation_push


## bkz. ENEMY_SEPARATION_GAP üstündeki DÜZELTME notu - ızgara (grid) kare
## başına TEK SEFER burada kuruluyor. static var olduğu için TÜM enemy.gd
## örnekleri arasında paylaşılıyor; hangi yaratık önce çağırırsa ızgarayı o
## kurar, aynı karedeki geri kalan herkes hazır ızgarayı bulur.
const SEPARATION_GRID_CELL_SIZE: float = 140.0 ## hücre boyutunun ÜST sınırı - gerçek boyut her karede _sep_cell'de (bkz. _rebuild_separation_grid_if_needed)
static var _sep_cell: float = SEPARATION_GRID_CELL_SIZE
static var _separation_grid: Dictionary = {}
static var _separation_grid_frame: int = -1

## Yukarıdaki _separation_grid (Node referanslı Dictionary) get_enemies_near
## için AYNEN korunuyor (çağıranlar gerçek Node referansı bekliyor, bkz.
## weapon.gd:take_damage çağrıları). Bunun YANINDA, SADECE _compute_enemy_
## separation'ın toplu geçişi için düz/paralel diziler de dolduruluyor - aynı
## TEK taramada, ikinci bir get_nodes_in_group maliyeti YOK.
static var _flat_positions: PackedVector2Array = PackedVector2Array()
static var _flat_radii: PackedFloat32Array = PackedFloat32Array()
static var _flat_nodes: Array = []
## DÜZELTME (kullanıcı bildirimi: "yaratıklar hâlâ iç içe giriyor" - test edip
## bulundu): bu ÖNCEDEN Dictionary değeri PackedInt32Array idi. GDScript'te
## Packed*Array bir "value type" (Vector2/Color gibi) - _cell_indices[cell] ile
## okumak KOPYA döndürür, o kopyaya .append() yapmak Dictionary'nin İÇİNDEKİ
## gerçek diziyi HİÇ değiştirmiyordu - her hücre sonsuza dek boş kalıyordu,
## yani _flat_pairwise_push HİÇBİR ZAMAN gerçek bir komşu bulamıyor, separation
## sessizce her zaman Vector2.ZERO dönüyordu. Düz Array'e (REFERENCE type,
## yukarıdaki _separation_grid'in ZATEN kullandığı desen) çevrildi.
static var _cell_indices: Dictionary = {}

static func _rebuild_separation_grid_if_needed(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _separation_grid_frame:
		return
	_separation_grid_frame = frame
	_separation_grid.clear()
	_flat_positions.resize(0)
	_flat_radii.resize(0)
	_flat_nodes.clear()
	_cell_indices.clear()
	var max_r: float = 0.0
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var r: float = 20.0
		var en: Enemy = e as Enemy
		if en != null:
			## Tipli erişim - dinamik get("...") yerine (PERF).
			if en.is_dead:
				continue
			r = en._body_radius
		else:
			if e.get("is_dead") == true:
				continue
			var r_variant = e.get("_body_radius")
			if r_variant != null:
				r = float(r_variant)
		_flat_positions.append((e as Node2D).global_position)
		_flat_radii.append(r)
		_flat_nodes.append(e)
		max_r = maxf(max_r, r)
	## PERF DÜZELTMESİ (kullanıcı bildirimi: 200 yaratık oyuncunun etrafını
	## sarınca 7-9 FPS - gerçek oyunda profillenip ölçüldü). Hücre eskiden SABİT
	## 140px'ti; oysa iki yaratık arasında itiş SADECE mesafe < min_gap iken
	## oluşuyor ve min_gap en büyük iki gövde için bile (2*max_r)*SCALE+GAP (fare/
	## slime/zombi ~20-35px). 140px'lik 3x3 komşuluk (420x420) oyuncuyu saran
	## yoğun bir kümede NEREDEYSE TÜM kümeyi kapsıyordu -> her yaratık ~200
	## komşuyu tarıyordu (O(n²)). Hücre artık bu karedeki mümkün olan EN BÜYÜK
	## min_gap'e eşit: 3x3 komşuluk hâlâ itiş verebilecek HER çifti kapsıyor
	## (davranış birebir aynı), ama taranan alan ~20 kat küçük. Üst sınır eski
	## 140 (dev bir boss varken eski davranıştan daha kötü olamaz).
	_sep_cell = clampf((2.0 * max_r) * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP, 24.0, SEPARATION_GRID_CELL_SIZE)
	for idx in range(_flat_positions.size()):
		var pos: Vector2 = _flat_positions[idx]
		var cell: Vector2i = Vector2i(floori(pos.x / _sep_cell), floori(pos.y / _sep_cell))
		if not _separation_grid.has(cell):
			_separation_grid[cell] = []
			_cell_indices[cell] = []
		(_separation_grid[cell] as Array).append(_flat_nodes[idx])
		(_cell_indices[cell] as Array).append(idx)


## --- LOD (uzak yaratıklar için ucuz mod) ---
## Kullanıcı isteği: yaratık sayısını ciddi artır. enemy_spawner.gd'nin ağ
## senkronu için zaten yaptığı "yakın/uzak" ayrımıyla (bkz. ENEMY_SYNC_NEAR_
## RADIUS) AYNI fikir - hiçbir oyuncuya yakın olmayan bir yaratık zaten
## görünmüyor, tam AI/separation/pathing hassasiyetine ihtiyacı yok. Bu SADECE
## bir perf sınıflandırması - hedef seçimindeki asıl "kim görünmez/ev içi"
## kurallarına (bkz. _find_closest_target_player) dokunmuyor, sadece NE SIKLIKLA
## yeniden hesaplanacaklarını etkiliyor.
const ENEMY_LOD_NEAR_RADIUS_SQ: float = 1600.0 * 1600.0
const ENEMY_LOD_FAR_SLOWDOWN: int = 8 ## uzaktaki yaratıklarda hedef/yol kontrol aralığı kaç kat seyrekleşsin
static var _lod_far_ids: Dictionary = {}
static var _lod_frame: int = -1

static func _ensure_lod_classification(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _lod_frame:
		return
	_lod_frame = frame
	_lod_far_ids.clear()
	var player_positions: Array[Vector2] = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p and is_instance_valid(local_p):
		player_positions.append((local_p as Node2D).global_position)
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp):
			player_positions.append((rp as Node2D).global_position)
	for ally in tree.get_nodes_in_group("player_allies"):
		if is_instance_valid(ally):
			player_positions.append((ally as Node2D).global_position)
	if player_positions.is_empty():
		## Hiç oyuncu bulunamadıysa (ör. çok erken bir kare) güvenli tarafta
		## kal - kimseyi "uzak" işaretleme, hepsi tam hızda simüle edilsin.
		return
	## PERF: ayrışma ızgarasının bu kare ZATEN topladığı canlı yaratık konumları
	## kullanılıyor (ikinci bir grup taraması + her yaratıkta get("is_dead") yok).
	_rebuild_separation_grid_if_needed(tree)
	for i in range(_flat_positions.size()):
		var pos: Vector2 = _flat_positions[i]
		var is_near: bool = false
		for p in player_positions:
			if pos.distance_squared_to(p) <= ENEMY_LOD_NEAR_RADIUS_SQ:
				is_near = true
				break
		if not is_near:
			_lod_far_ids[(_flat_nodes[i] as Node).get_instance_id()] = true

static func _is_lod_far(instance_id: int) -> bool:
	return _lod_far_ids.has(instance_id)


## --- Toplu (batched) ayrışma geçişi ---
## bkz. _compute_enemy_separation üstündeki PERF DÜZELTMESİ notu. Fizik karesi
## başına TEK SEFER çalışır (ızgara/LOD ile AYNI "lazy static" deseni) - hangi
## yaratık önce _compute_enemy_separation çağırırsa toplu geçişi o tetikler,
## aynı karedeki geri kalan herkes hazır sonucu Dictionary'den okur.
static var _separation_results: Dictionary = {}
static var _separation_batch_frame: int = -1

static func _batch_compute_separation_if_needed(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _separation_batch_frame:
		return
	_separation_batch_frame = frame
	_rebuild_separation_grid_if_needed(tree)
	_ensure_lod_classification(tree)
	_separation_results.clear()
	var count: int = _flat_nodes.size()
	for i in range(count):
		## Önbellek (ızgara) bu karede yenilenmediyse arada silinmiş (free) bir yaratık kalmış olabilir - tipli değişkene
		## atamadan önce atla ("Trying to assign invalid previously freed instance").
		if not is_instance_valid(_flat_nodes[i]):
			continue
		var e: Node = _flat_nodes[i]
		var instance_id: int = e.get_instance_id()
		var interval: int = SEPARATION_UPDATE_INTERVAL_FRAMES * (ENEMY_LOD_FAR_SLOWDOWN if _is_lod_far(instance_id) else 1)
		if frame % interval != instance_id % interval:
			continue
		_separation_results[instance_id] = _flat_pairwise_push(i)


## _pairwise_separation_push ile BİREBİR AYNI formül (bkz. orası) ama Node.get()
## yerine düz dizilerden okuyor - iki yerde asla sapmasın diye burada TEK
## ortak alt fonksiyona (_flat_pairwise_pair) çıkarıldı.
static func _flat_pairwise_push(i: int) -> Vector2:
	var pos: Vector2 = _flat_positions[i]
	var radius: float = _flat_radii[i]
	var my_cell: Vector2i = Vector2i(floori(pos.x / _sep_cell), floori(pos.y / _sep_cell))
	var push: Vector2 = Vector2.ZERO
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell: Vector2i = my_cell + Vector2i(dx, dy)
			if not _cell_indices.has(cell):
				continue
			var indices: Array = _cell_indices[cell]
			for j in indices:
				if j == i:
					continue
				push += _flat_pairwise_pair(pos, radius, _flat_positions[j], _flat_radii[j])
	return push


static func _flat_pairwise_pair(pos_a: Vector2, radius_a: float, pos_b: Vector2, radius_b: float) -> Vector2:
	var to_me: Vector2 = pos_a - pos_b
	var dist_sq: float = to_me.length_squared()
	if dist_sq >= ENEMY_SEPARATION_CHECK_RADIUS * ENEMY_SEPARATION_CHECK_RADIUS:
		return Vector2.ZERO
	var d: float = sqrt(dist_sq)
	if d < 0.001:
		to_me = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		d = to_me.length()
		if d < 0.001:
			return Vector2.ZERO
	var min_gap: float = (radius_a + radius_b) * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP
	if d < min_gap:
		var overlap: float = (min_gap - d) / min_gap
		return (to_me / d) * overlap
	return Vector2.ZERO


## DÜZELTME (kullanıcı bildirimi: "yaratıklara tam saldırırken anlık fps
## düşürüyor, saldırı hasarı gerçekleştiğinde") - kök neden buradaki grid
## DEĞİL, weapon.gd'nin yakın dövüş alan-hasarı gibi HER VURUŞTA (ayrıca
## player.gd'de ~18 benzer yer, çoğu daha seyrek/becerilere özel) TÜM
## "enemies" grubunu (158'e kadar) tek tek mesafe kontrolünden geçiren kod
## - kısa süreli ama sık tekrarlayan bir dalgalanma (spike) yaratıyordu.
## Bu, yukarıdaki ayrışma ızgarasının GENEL amaçlı bir sürümü: HERHANGİ bir
## script (weapon.gd, player.gd) "bu noktanın X yarıçapındaki yaratıklar"
## diye sormak istediğinde get_tree().get_nodes_in_group("enemies") ile TÜM
## yaratıkları taramak yerine bunu çağırabilir - sadece ilgili ızgara
## hücrelerini tarar. Izgara zaten fizik karesi başına TEK SEFER kuruluyor
## (bkz. _rebuild_separation_grid_if_needed), bu yüzden aynı karede birden
## çok sorgu (ör. birden fazla silah) ekstra maliyet eklemiyor. Dönen
## dizideki yaratıklar zaten canlı/geçerli (ızgara ölüleri hiç eklemiyor,
## bkz. yukarısı) - çağıran taraf is_dead/is_instance_valid'i tekrar
## kontrol etmek ZORUNDA değil.
static func get_enemies_near(tree: SceneTree, pos: Vector2, radius: float) -> Array:
	_rebuild_separation_grid_if_needed(tree)
	var result: Array = []
	if radius <= 0.0:
		return result
	var cell_radius: int = maxi(1, ceili(radius / _sep_cell))
	var center_cell: Vector2i = Vector2i(floori(pos.x / _sep_cell), floori(pos.y / _sep_cell))
	var radius_sq: float = radius * radius
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			if not _separation_grid.has(cell):
				continue
			for e in (_separation_grid[cell] as Array):
				## Izgara fizik karesi başına kurulur; fizik adımı olmayan bir çizim karesinde (yüksek FPS) o arada
				## serbest kalmış bir yaratık hâlâ içinde olabilir (efsun duman testinde yakalandı) - atla.
				if not is_instance_valid(e):
					continue
				if pos.distance_squared_to(e.global_position) <= radius_sq:
					result.append(e)
	return result


## İki yaratık arasındaki tek çift için itiş katkısı - hem ızgara-taramalı
## (bkz. _separation_push_from_enemy_grid) hem eski düz-taramalı (bkz.
## _separation_push_from_group, "enemies" DIŞINDAKİ küçük gruplar için hâlâ
## kullanılıyor) yol AYNI formülü buradan çağırır, iki yerde asla sapamaz.
## DÜZELTME (kullanıcı sağladığı 2. Profiler): bu, 5000+ kez/karede çağrılan
## en sıcak yol olduğu için - eskiden HER çağrıda (menzil içinde olsun
## olmasın) bir sqrt (Vector2.length()) hesaplıyordu. Artık önce ucuz
## (sqrt'siz) kare-mesafe ile menzil dışı çiftler eleniyor, sqrt SADECE
## gerçekten menzil içinde olan (asıl itiş hesabının ihtiyaç duyduğu) çiftler
## için hesaplanıyor - davranış birebir aynı, sadece daha az sqrt çağrısı.
func _pairwise_separation_push(e: Node) -> Vector2:
	if e == self or not is_instance_valid(e) or e.get("is_dead") == true:
		return Vector2.ZERO
	var to_me: Vector2 = global_position - e.global_position
	var dist_sq: float = to_me.length_squared()
	if dist_sq >= ENEMY_SEPARATION_CHECK_RADIUS * ENEMY_SEPARATION_CHECK_RADIUS:
		return Vector2.ZERO
	var d: float = sqrt(dist_sq)
	if d < 0.001:
		## Tam üst üste spawn olmuş olabilir (nadir) - rastgele küçük
		## bir yönde ayrışmayı başlat.
		to_me = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		d = to_me.length()
		if d < 0.001:
			return Vector2.ZERO
	var other_radius: float = 20.0
	var r_variant = e.get("_body_radius")
	if r_variant != null:
		other_radius = float(r_variant)
	var min_gap: float = (_body_radius + other_radius) * ENEMY_SEPARATION_SCALE + ENEMY_SEPARATION_GAP
	if d < min_gap:
		var overlap: float = (min_gap - d) / min_gap
		return (to_me / d) * overlap
	return Vector2.ZERO


## DÜZELTME (kullanıcı sağladığı Profiler verisi): ızgara WORKED ama TEK
## BAŞINA yetmedi - 157 yaratıklı bir karede _pairwise_separation_push TAM
## 6908 KEZ çağrılıyordu (yaratık başına ortalama ~44 komşu), sadece bu
## zincir (bkz. _compute_enemy_separation/_separation_push_from_group/bu
## fonksiyon/_pairwise_separation_push) kare süresinin (39.52ms) %47'sini
## (~18.6ms) yiyordu - oyuncuya akın eden yaratıklar zaten FİZİKSEL OLARAK
## kümelendiği için "yakın komşular" kümesi ızgarayla bile hâlâ büyük kalıyor
## (motorun kendi Physics 2D'si sadece 0.48ms - darboğaz GDScript tarafında).
## DÜZELTME (kullanıcı bildirimi: "body block kalkmış, yaratıklar iç içe
## giriyor, 100 tane fare iç içe duruyor") - burada eskiden bir SEPARATION_
## MAX_NEIGHBORS_CHECKED (16) sınırı vardı: kalabalık bir kümede bir yaratık
## SADECE ızgara hücresinde İLK BULUNAN 16 komşuyla karşılaştırılıp
## GERİ KALANLARDAN (100 fareli bir kümede ~84 tanesi) HİÇ itiş almıyordu -
## "yaklaşık ama fark edilmez" varsayımı YANLIŞTI, tam tersine tam bu
## kalabalık durumda görünür şekilde bozuyordu. Sınır kaldırıldı - artık
## hücre içindeki TÜM komşularla karşılaştırılıyor (yine sadece 3x3 hücre,
## N² değil), maliyet kontrolü SADECE aşağıdaki _compute_enemy_separation'daki
## güncelleme sıklığı azaltmasından (throttle) geliyor.
func _separation_push_from_enemy_grid() -> Vector2:
	_rebuild_separation_grid_if_needed(get_tree())
	var push: Vector2 = Vector2.ZERO
	var my_cell: Vector2i = Vector2i(floori(global_position.x / _sep_cell), floori(global_position.y / _sep_cell))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell: Vector2i = my_cell + Vector2i(dx, dy)
			if not _separation_grid.has(cell):
				continue
			for e in (_separation_grid[cell] as Array):
				if e == self:
					continue
				push += _pairwise_separation_push(e)
	return push


## bkz. yukarıdaki _compute_enemy_separation - tek bir grup için itiş
## hesabını tekrar kullanılabilir hale getiren yardımcı (eskiden bu kod
## sadece "enemies" grubu için tek bir döngü halindeydi, artık "player_allies"
## için de aynı mantık gerektiği için ortak fonksiyona çıkarıldı). "enemies"
## - asıl performans darboğazı, bkz. yukarıdaki DÜZELTME notu - artık ızgara
## üzerinden gidiyor; diğer (çok daha küçük) gruplar eski düz taramada kalıyor,
## onlarda O(n²) zaten hiç sorun değil.
func _separation_push_from_group(group_name: String) -> Vector2:
	if group_name == "enemies":
		return _separation_push_from_enemy_grid()
	var push: Vector2 = Vector2.ZERO
	for e in get_tree().get_nodes_in_group(group_name):
		push += _pairwise_separation_push(e)
	return push


## Kullanıcı isteği (bkz. EntityScale): TÜM yaratıklar %5 küçülür - görseli
## (frame_sprite veya anim_sprite) ve gövde/vuruş çemberleri orantılı.
##
## apply_boss_stats() ile AYNI dört düğüm ölçekleniyor (o da tam olarak bu
## dördünü büyütür) - ikisi ÇARPIMSAL olduğu için bosslar da küçülür
## (BOSS_SCALE_MULT 1.7 x 0.95 = 1.615). Sahne dosyalarındaki ölçek
## değerleri DEĞİŞTİRİLMEDİ (60+ yaratık sahnesini elle düzenlemek yerine
## tek çarpan - bkz. EntityScale üstündeki gerekçe).
func _apply_global_size_scale() -> void:
	if is_equal_approx(EntityScale.SIZE, 1.0):
		return
	if frame_sprite:
		frame_sprite.scale *= EntityScale.SIZE
	if anim_sprite:
		anim_sprite.scale *= EntityScale.SIZE
	EntityScale.shrink_collision(body_collision)
	if hit_area:
		EntityScale.shrink_collision(hit_area.get_node_or_null("HitCollision"))


func _ready() -> void:
	## Fizik interpolasyonu (bkz. physics_interp.gd): _physics_process'te hareket ediyor.
	PhysicsInterp.opt_in(self)
	add_to_group("enemies")
	## Kullanıcı isteği: "tüm ... yaratıkları v.s %5 küçültüp hareket hızlarını
	## %10 azaltmanı istiyorum" - EntityScale.SPEED buradaki zaten var olan
	## global çarpana EK olarak uygulanıyor (0.48 x 0.9 = 0.432); sahne
	## dosyalarındaki tek tek hızlar yine elle değiştirilmiyor.
	speed *= GLOBAL_SPEED_SCALE * EntityScale.SPEED
	## Kullanıcı isteği: yakın dövüşçü yaratıklar (is_ranged=false) menzillilere
	## göre %5 daha hızlı hareket etsin.
	if not is_ranged:
		speed *= 1.05
	_apply_difficulty_scaling()
	health = max_health
	health_changed.emit(health, max_health)

	## Boyut küçültme, _body_radius OKUNMADAN ÖNCE uygulanmalı: aşağıdaki satır
	## gövde çemberinin radius'unu okuyup body-block mesafesinde kullanıyor
	## (_body_radius), yoksa küçülmemiş değer kalırdı. apply_boss_stats() de
	## kendi ölçeklemesinde bu değeri elle güncelliyor (bkz. orası).
	_apply_global_size_scale()

	if body_collision and body_collision.shape is CircleShape2D:
		_body_radius = body_collision.shape.radius

	if frame_sprite and not walk_texture:
		walk_texture = frame_sprite.texture
	if frame_sprite and idle_texture == null:
		idle_texture = _derive_idle_texture(walk_texture)

	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("walk"):
		anim_sprite.play("walk")

	if hit_area:
		hit_area.body_entered.connect(_on_hit_area_body_entered)
		hit_area.body_exited.connect(_on_hit_area_body_exited)

	_create_overhead_bar()


## TÜM yaratıklara (boss/normal fark etmeksizin) tek tip bir can+kalkan
## çubuğu ekler - bkz. sınıf üstündeki _overhead_bar notu. Normal
## yaratıklarda başlangıçta gizli, ilk hasarda görünür olur.
func _create_overhead_bar() -> void:
	# Only bosses keep an overhead health/shield bar.
	if not is_boss:
		return
	if _overhead_bar and is_instance_valid(_overhead_bar):
		return
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(preload("res://scripts/overhead_bar.gd"))
	_overhead_bar.set("health_color", _overhead_bar.HEALTH_COLOR_ENEMY) ## düşman boss: kırmızı can barı
	add_child(_overhead_bar)
	_overhead_bar.set_offset(get_overhead_bar_offset())
	_overhead_bar.set_health(health, max_health)
	_overhead_bar.set_shield(item_shield_hp, item_shield_max)
	_overhead_bar.visible = _overhead_bar_always_visible


## Bosslar için çubuk kalıcı görünür kalır (bkz. enemy_spawner.gd
## _attach_boss_bar) - hasarsız 1sn sonra otomatik kaybolma zamanlayıcısı
## bosslarda hiç işletilmez.
func set_overhead_bar_always_visible() -> void:
	if not is_boss:
		return
	_overhead_bar_always_visible = true
	_create_overhead_bar()
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.visible = true


## Hasar aldığında (can VEYA kalkan azaldığında) çağrılır - çubuğu günceller,
## görünür yapar ve (boss değilse) 1sn'lik otomatik kaybolma sayacını
## baştan başlatır (bkz. OVERHEAD_BAR_HIDE_DELAY, _physics_process).
func _show_overhead_bar() -> void:
	if not is_boss or not _overhead_bar or not is_instance_valid(_overhead_bar):
		return
	_overhead_bar.set_health(health, max_health)
	_overhead_bar.set_shield(item_shield_hp, item_shield_max)
	_overhead_bar.visible = true


## Fizik interpolasyonu: bu adımdan ÖNCEKİ konum - _process'te buna yapışan görseller
## (hasar sayıları, auralar) çizilen konumu bulsun diye (bkz. PhysicsInterp.visual_position).
var _interp_prev_pos: Vector2 = Vector2.ZERO
var _interp_prev_frame: int = -1


func _physics_process(delta: float) -> void:
	_interp_prev_pos = global_position ## bkz. PhysicsInterp.visual_position
	_interp_prev_frame = Engine.get_physics_frames()
	if _flash_time_left > 0.0:
		_tick_hit_flash(delta)
	## Relay multiplayer'da yaratık simülasyonu yalnızca host'ta çalışır.
	## İstemciler kendi oyuncularına göre tekrar hareket ettirirse her peer'de
	## farklı hedef/çarpışma sonucu oluşur ve yaratıklar ayrışır.
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		if _network_state_received and not is_dead:
			## DÜZELTME (kullanıcı bildirimi: "yaratıkların animasyonları
			## katılımcılarda yanlış görünüyor"): pozisyon senkronu zaten
			## vardı ama YÖN/BAKIŞ (facing) hiç güncellenmiyordu -
			## _update_facing() eskiden SADECE aşağıdaki host-only hareket
			## bloğunda çağrılıyordu. Katılımcı ekranında yaratık host'un
			## bildirdiği hedefe doğru kayarken sprite'ı hep başlangıç
			## yönünde/satırında (ör. hep "aşağı bakan", hiç flip_h
			## değişmeyen) kalıyordu - host'taki gerçek hareket yönüyle hiç
			## eşleşmiyordu. Artık aynı host-bildirimli konum farkından
			## türetilen yönle senkronize ediliyor (frame_sprite'lı Rat/Boss
			## için doğru satır, anim_sprite'lı orklar için doğru flip_h).
			## DÜZELTME (kullanıcı bildirimi: "yaratıklar bianda durup bianda
			## hareket ediyor lag var hala katılımcılarda"): _network_target_
			## position artık her karede _network_velocity ile "ölü hesaplama"
			## (dead reckoning) yapılarak ileri taşınıyor (bkz. update_network_
			## state'teki _network_velocity notu) - iki gerçek paket arasında
			## yaratık son bilinen yönünde akıcı hareket etmeye devam ediyor,
			## sadece paket gelene kadar donup kalmak yerine. 0.4sn'yi aşan
			## bir boşlukta tahmin durdurulur (bkz. min() sınırı) - o kadar
			## uzun bir kesintide yaratığın gerçekten durmuş/yön değiştirmiş
			## olma ihtimali yüksektir, kör tahmin daha kötü bir sıçramaya yol açar.
			_network_time_since_update += delta
			## DÜZELTME (kullanıcı bildirimi: "yaratıklar 3 saniyede bir
			## laglanıyor anlık durup devam ediyorlar") - bu sınır, UZAK
			## yaratıkların gerçek senkron aralığından (bkz. enemy_spawner.gd
			## ENEMY_SYNC_FAR_TIER_SKIP*0.15sn ≈ 0.6sn) KISAYDI (0.4sn):
			## tahmin 0.4sn'de durduğu için, 0.4-0.6sn arası her pakette
			## yaratık donup sonraki paketle sıçrıyordu. 0.4 -> 0.7 (uzak
			## senkron aralığını güvenle kapsayan, biraz paylı bir sınır).
			var extrap_time: float = min(_network_time_since_update, 0.7)
			var predicted_target: Vector2 = _network_target_position + _network_velocity * extrap_time
			var to_target: Vector2 = predicted_target - global_position
			## DÜZELTME (kullanıcı bildirimi: "katılımcılarda yaratıklar bazen
			## sağ sol yapıyor random bir şekilde") - _network_velocity iki
			## pozisyon paketi arasındaki FARKTAN türetilen bir TAHMİN (dead
			## reckoning); host gerçekte dururken/ufak AI salınımlarıyla
			## kıpırdarken bile küçük, rastgele işaretli bir kalıntı hız
			## taşıyabiliyordu - bu da her yeni paket geldiğinde yönün
			## (flip_h) anlamsızca sağa/sola zıplamasına yol açıyordu. Artık
			## sadece GERÇEKTEN anlamlı bir hareket varken (hız eşiği de
			## eklendi) yön güncelleniyor.
			if _network_velocity.length() > 15.0 and to_target.length() > 2.0:
				_update_facing(to_target.normalized())
			elif Engine.get_physics_frames() % AI_THINK_INTERVAL_FRAMES == get_instance_id() % AI_THINK_INTERVAL_FRAMES:
				## BUG DÜZELTMESİ (kullanıcı bildirimi, ekran görüntüsüyle: "bazı yaratıklar sıkıştıklarında
				## arkalarına yana falan bakıp saldırı hareketi yapıyor" - host tarafı yukarıdaki "not think"
				## dalında düzeltildi, ama bu SADECE host'un KENDİ ekranını düzeltiyordu). Katılımcı ekranında
				## yaratığın yönü konum paketleri arasındaki farktan (_network_velocity) türetiliyor - host'taki
				## yaratık DURUP saldırıya geçtiğinde (velocity=0, bkz. yukarısı) paketler arası fark küçülüp bu
				## eşiğin (15.0) altına düşer, yani yön GÜNCELLENMEYİ TAMAMEN BIRAKIR ve yaratık SON GERÇEK
				## hareketinin (kalabalıkta ayrışma/knockback'le saptırılmış olabilen) yönünde donup kalır -
				## saldırdığı oyuncuya değil rastgele bir yöne bakıyormuş gibi görünür. Host'un kendi mantığıyla
				## AYNI kural (durunca GERÇEK hedefe bak) burada da - AI_THINK_INTERVAL_FRAMES'te bir (host'un
				## kendi throttle'ıyla AYNI kaydırma deseni), sadece kozmetik/ucuz bir oyuncu araması.
				## DÜZELTME (kullanıcı bildirimi 2026-09-24: "ağacı koruma görevinde ... bazılarının yüzü oyunculara
				## dönüyor"): "Ağacı Koru" sürerken host'taki yaratıklar AĞACI hedefler (bkz. _apply_aggro_overrides) ama
				## bu kozmetik dal hep en yakın OYUNCUYA baktırıyordu - ağaca yürürken yavaşlayan/duvara takılan ya da
				## ağaca vuran (durmuş) yaratıklar istemcide oyuncuya dönüyordu. İstemcideki kozmetik ağaç main.gd'de
				## GameManager.defend_tree_ref'e yazılır (defend_tree_active sadece host'ta).
				var facing_target: Node2D = null
				if is_instance_valid(GameManager.defend_tree_ref):
					facing_target = GameManager.defend_tree_ref
				else:
					facing_target = _find_closest_target_player()
				if facing_target and is_instance_valid(facing_target):
					var to_facing: Vector2 = facing_target.global_position - global_position
					if to_facing.length() > 2.0:
						_update_facing(to_facing.normalized())
			global_position = global_position.lerp(predicted_target, min(1.0, delta * 18.0))
		## Görsel animasyon durumu (yürüme/saldırı) sadece kozmetiktir ve
		## host'tan _enter_state_networked() ile tetiklenir (bkz. o fonksiyon
		## ve NetworkManager.broadcast_enemy_vfx "attack_state") - burada
		## sadece o durumun süresini işletip (host'taki gibi zamanla WALK'a
		## geri dönsün diye) kare ilerlemesini sürdürüyoruz. AnimatedSprite2D
		## tabanlı yaratıklar zaten kendi kendine oynatıyor (bkz. _enter_state
		## içindeki anim_sprite.play çağrısı) - bu sadece Sprite2D/frame_sprite
		## tabanlı yaratıkların (Rat, Boss/Golem vb.) istemcide de
		## animasyonlanması için gerekli.
		## DÜZELTME (kullanıcı bildirimi: "yaratıkların ölüm animasyonu
		## katılımcılarda farklı görünüyor"): bu çağrılar eskiden "not is_dead"
		## şartına bağlıydı - yaratık öldüğü anda (is_dead = true) frame_sprite
		## tabanlı yaratıklarda (Rat, Boss/Golem) kare ilerlemesi TAMAMEN
		## DURUYORDU, yani ölüm animasyonu katılımcının ekranında daha ilk
		## karede donup kalıyordu. Host'taki AYNI kod ise (aşağıdaki, ~1375.
		## satır civarı host dalı) is_dead şartı OLMADAN her karede
		## çağrılıyor - host'ta ölüm animasyonu düzgün oynarken katılımcıda
		## donuk kalması tam olarak bu asimetriden kaynaklanıyordu. Artık
		## host'la BİREBİR aynı şekilde is_dead'den bağımsız çağrılıyor
		## (_update_state_timer zaten State.DEATH'te kendi kendine no-op).
		_update_locomotion_state(delta)
		_update_state_timer(delta)
		if mark_stacks > 0:
			_process_mark(delta) ## bkz. apply_mark_stack istemci dalı
		if frame_sprite:
			_advance_frame_sprite(delta)
		return
	if _overhead_bar and is_instance_valid(_overhead_bar) and not _overhead_bar_always_visible and _overhead_bar_hide_timer > 0.0:
		_overhead_bar_hide_timer -= delta
		if _overhead_bar_hide_timer <= 0.0:
			_overhead_bar.visible = false

	if not is_dead:
		_process_freeze(delta)
		_process_fear(delta)
		var player: Node2D = null
		var dist: float = INF
		var min_separation: float = 0.0
		var true_contact_separation: float = 0.0
		## Buz Asası: donmuşken hareket etmez, düşmana dönmez ve saldırmaz -
		## tamamen "duraklamış" gibi davranır (bkz. apply_chill/_start_freeze).
		if is_frozen:
			velocity = Vector2.ZERO
		elif is_feared and _fear_wander:
			## Lanetli Kafatası korkusu (Necromancer ULTİ, bkz. apply_fear_wander) - rastgele yönlerde yürür; hedef
			## seçimi/saldırı YOK (Melek korkusuyla aynı şekilde kovalama mantığının tamamen dışında).
			velocity = _fear_wander_velocity(delta)
		elif is_feared:
			## Kutsal Korku (Melek skill3, bkz. apply_fear) - hedefe doğru
			## DEĞİL, korku kaynağından UZAĞA kaçar; hedef seçimi/saldırı YOK,
			## donmuşta olduğu gibi tamamen kovalama mantığının dışında.
			var away_dir: Vector2 = global_position - _fear_source_pos
			var flee_dir: Vector2 = away_dir.normalized() if away_dir.length() > 0.1 else Vector2.from_angle(randf() * TAU)
			var steered_flee: Vector2 = _steer_around_obstacle(flee_dir)
			velocity = steered_flee * speed * _chill_speed_mult() * _slow_speed_mult() * _rage_speed_mult()
			_update_facing(flee_dir)
		else:
			if _taunt_timer > 0.0:
				_taunt_timer = max(0.0, _taunt_timer - delta)
			_ai_accum_delta += delta
			## PERF DÜZELTMESİ (kullanıcı bildirimi: 200 yaratıkta 7-9 FPS - gerçek oyunda
			## profillendi: bu karar bloğu 200 yaratıkta fizik adımı başına ~4.3ms, tek başına
			## en büyük kalem). Hedef seçimi, oyuncunun görünmez/ev içi/satıcı bölgesi
			## kontrolleri, yol bulma ve bakış yönü artık yaratık başına AI_THINK_INTERVAL_
			## FRAMES karede bir (instance_id'ye göre kaydırmalı) hesaplanıyor; aradaki
			## karelerde son karar (hız/hedef/mesafe sınırları) kullanılıyor. Mesafe, gövde
			## engelleme, saldırı-anında-durma ve menzilli saldırı sayacı HER karede taze.
			## Aradaki kare süreleri biriktirilip (_ai_accum_delta) karar anında takılma/rota
			## zamanlayıcılarına veriliyor - o zamanlayıcıların gerçek süresi değişmiyor.
			var think: bool = not _ai_has_decision or Engine.get_physics_frames() % AI_THINK_INTERVAL_FRAMES == get_instance_id() % AI_THINK_INTERVAL_FRAMES
			if not think and not _ai_wandering and (_ai_player == null or not is_instance_valid(_ai_player) or _ai_player.get("is_dead") == true):
				think = true
			if not think:
				if _ai_wandering:
					velocity = _compute_wander_velocity(delta)
				else:
					player = _ai_player
					var to_p: Vector2 = player.global_position - global_position
					dist = to_p.length()
					true_contact_separation = _ai_true_contact
					min_separation = _ai_min_sep
					velocity = _ai_velocity
					if dist <= min_separation or _state == State.ATTACK:
						velocity = Vector2.ZERO
					if is_ranged:
						_process_ranged_attack(delta, player, dist, to_p.normalized() if dist > 0.1 else Vector2.ZERO)
					## BUG DÜZELTMESİ (kullanıcı bildirimi, ekran görüntüsüyle: "bazı yaratıklar sıkıştıklarında
					## arkalarına yana falan bakıp saldırı hareketi yapıyor"): _update_facing eskiden SADECE
					## yukarıdaki "think" dalında (AI_THINK_INTERVAL_FRAMES'te 1 kez, kaydırmalı) çağrılıyordu -
					## bu "not think" dalındaki diğer 2 karede yön HİÇ güncellenmiyordu. Kalabalıkta ayrışma/
					## knockback (_compute_enemy_separation, aşağıda) yaratığı oyuncuya göre HIZLA farklı bir
					## açıya itebiliyor; dist/saldırı tetiği HER karede taze olduğu için (yukarısı) yaratık
					## gerçekte oyuncunun yanındayken/arkasındayken bile 2 kare önceki bakışla saldırı animasyonuna
					## giriyordu. Artık think dalıyla AYNI kural (rota takip ediliyorsa hareket yönü, aksi halde
					## oyuncu yönü) HER karede tazeleniyor - sadece ucuz vektör/satır hesabı, grup taraması YOK.
					var not_think_face_dir: Vector2 = to_p.normalized() if dist > 0.1 else Vector2.ZERO
					if _route_active and _ai_velocity.length() > 0.1:
						not_think_face_dir = _ai_velocity.normalized()
					_update_facing(not_think_face_dir)
			else:
				var think_delta: float = _ai_accum_delta
				_ai_accum_delta = 0.0
				_ai_has_decision = true
				_ai_wandering = false
				## Hedef bul: Yerel oyuncu ve canlı RemotePlayer'lar arasından en yakınını seç
				var target_player: Node2D = _get_target_player()
				player = target_player
				var player_is_invisible: bool = player != null and is_instance_valid(player) \
					and ((player.has_method("is_invisible_now") and player.is_invisible_now()) \
					or (player.has_method("is_indoors_now") and player.is_indoors_now()) \
					or (player.has_method("is_in_merchant_zone_now") and player.is_in_merchant_zone_now()))
				if player and is_instance_valid(player) and not player_is_invisible:
					var to_player: Vector2 = player.global_position - global_position
					dist = to_player.length()
					var dir: Vector2 = to_player.normalized() if dist > 0.1 else Vector2.ZERO
					var face_dir: Vector2 = dir
					## Body block: gövde yarıçapları toplamının altına inince
					## artık oyuncuya doğru ilerlemiyor - bkz. PLAYER_BODY_RADIUS
					## notu, karakterin içine girmesini engelliyor. _true_contact_
					## separation gerçek (zon ile şişirilmemiş) dokunma mesafesi -
					## aşağıdaki melee_range hesabı BUNU kullanmalı, yoksa Şovalye
					## ultisiyle genişleyen min_separation'ı yakın dövüş menzili
					## sanıp yaratıklar 280px öteden "temas" hasarı vermeye
					## başlıyor (bkz. kullanıcı bildirimi: "kendi kendine hasar
					## almaya başlıyor"). GameManager.BODY_BLOCK_SCALE ile küçültülüyor
					## (bkz. kullanıcı bildirimi: "daha dokunmadan dokunmuşum gibi
					## itiliyor yaratıklar") - player.gd'nin kendi engelleme kodu da
					## AYNI çarpanı kullanıyor, iki taraf hep tutarlı kalsın diye.
					true_contact_separation = (_body_radius + PLAYER_BODY_RADIUS) * GameManager.BODY_BLOCK_SCALE
					min_separation = true_contact_separation
					## Şovalye (Paladin) ultisi aktifken oyuncunun etrafında
					## hiçbir yaratığın giremeyeceği daha geniş bir alan var -
					## bkz. player.gd paladin_zone_active/paladin_zone_radius.
					## Bu SADECE hareketi durdurur, yakın dövüş menzilini değil.
					if "paladin_zone_active" in player and player.paladin_zone_active:
						min_separation = max(min_separation, player.paladin_zone_radius)
					## Kışkırtılmışsa (bkz. apply_taunt) menzilli yaratıklar bile
					## normal "uzak dur" davranışını bırakıp yakın dövüşçü gibi
					## doğrudan üstüne yürür.
					## Görüş hattı yoksa (duvar arkasındaysa) menzilli yaratık durup beklemez, yakın dövüşçü
					## gibi yürümeye/dolanmaya devam eder - bkz. _has_line_of_sight.
					if is_ranged and dist <= ranged_range and _taunt_timer <= 0.0 and _has_line_of_sight(player):
						velocity = Vector2.ZERO
						_update_stuck_state(think_delta, false)
					elif dist <= min_separation:
						velocity = Vector2.ZERO
						_update_stuck_state(think_delta, false)
					else:
						## bkz. _is_stuck üstündeki BUG DÜZELTMESİ notu - oyuncuya
						## gerçekten yaklaşmaya çalışırken engele sıkışmışsak
						## (su/ev tile'ı, bkz. GameManager.is_position_blocked_by_
						## terrain) yönü hafifçe engelin yanından dolanacak şekilde
						## büküyoruz, aksi halde her karede aynı düz yönü deneyip
						## sonsuza dek orada kalırdı.
						_update_stuck_state(think_delta, true)
						var routed_dir: Vector2 = _route_direction(dir, player.global_position, think_delta)
						## Rota izlenirken _steer_around_obstacle ATLANIR: yol zaten duvarı
						## hesaba katıyor, üstelik yavaş yaratıklar (28 px/s x 0.4 sn < 12 px)
						## sürekli "sıkışmış" sayılıp yönü rastgele yana büküyor ve rotadan
						## saptırıyordu. Rota yokken (düz çizgi açık ya da yol bulunamadı)
						## eski davranış aynen.
						var steered_dir: Vector2 = routed_dir if _route_active else _steer_around_obstacle(routed_dir)
						velocity = steered_dir * speed * _chill_speed_mult() * _slow_speed_mult() * _rage_speed_mult()
						## Duvarı dolanırken hedefe değil yürüdüğü yöne baksın.
						if _route_active:
							face_dir = steered_dir
					## DÜZELTME (kullanıcı isteği #35: "yaratıklar saldırırken
					## hareket ediyor, saldırı animasyonu anında hareket
					## edememeliler") - _state == State.ATTACK süresince (bkz.
					## _enter_state çağrıları, _state_duration ile otomatik WALK'a
					## döner) yürüme hızı burada iptal ediliyor; ayrışma/knockback
					## (aşağıda ayrıca eklenen) buna dokunmuyor, yani vurulunca
					## yine itilebiliyor, sadece kendi isteğiyle yürüyemiyor.
					if _state == State.ATTACK:
						velocity = Vector2.ZERO
					_update_facing(face_dir)
					if is_ranged:
						_process_ranged_attack(delta, player, dist, dir)
				else:
					## Kullanıcı isteği: "yaratıkların hedefi yokken etrafta
					## arada rasgele dolanmalı bazen de durmalılar ve doğal
					## davranmalılar" - eskiden burada dümdüz velocity=ZERO ile
					## donup kalıyorlardı (hedef yok/tüm oyuncular görünmez-ev
					## içi-seyyar satıcı bölgesinde). Artık bkz. _compute_wander_
					## velocity().
					_ai_wandering = true
					velocity = _compute_wander_velocity(delta)
				_ai_player = player if (not _ai_wandering and player != null and is_instance_valid(player)) else null
				_ai_velocity = velocity
				_ai_true_contact = true_contact_separation
				_ai_min_sep = min_separation
		## Yaratıklar arası doğal boşluk (bkz. _compute_enemy_separation
		## yorumu) - donmuşken uygulanmaz, donuk yaratık tam "duraklamış"
		## kalmalı.
		if not is_frozen:
			velocity += _compute_enemy_separation()
			velocity += _knockback_velocity
		## Oakley'in Sarmaşıklar yeteneği (bkz. apply_root üstündeki
		## not) - is_frozen'ın aksine yukarıdaki hedef bulma/saldırı mantığı
		## HİÇ atlanmadı, SADECE en sonda hesaplanmış hız (ayrışma/knockback
		## dahil) sıfırlanıyor - "hareket edemez ama saldırabilir".
		if is_rooted:
			velocity = Vector2.ZERO
		## Yaratık yetenekleri (bkz. enemy_abilities.gd) - host/tek oyunculu. Donmuş/korkmuş/sersemlemişken kullanılmaz.
		if not _abilities_checked:
			_init_abilities()
		if _abilities != null and not is_frozen and not is_feared and not is_stunned:
			_abilities.process(delta, player, dist)
		elif is_ability_invisible and _abilities != null:
			_abilities.ghost_reveal(false) ## donan/korkan/sersemleyen hayalet görünmez kalmasın
		if ability_move_lock > 0.0:
			ability_move_lock -= delta
			velocity = Vector2.ZERO
		_block_movement_into_terrain()
		## PERF DÜZELTMESİ (kullanıcı bildirimi: "kasmanın asıl nedeni physics" -
		## araştırma sonucu): move_and_slide() burada boşa gidiyordu. Yaratıkların
		## collision_mask'ı 0 (bkz. scenes/creatures/*.tscn ve PLAYER_BODY_RADIUS
		## üstündeki DÜZELTME notu: Godot'un fizik motoru enemy-enemy/enemy-player
		## çarpışmasında BİLİNÇLİ olarak devre dışı - tüm itiş/engelleme zaten
		## mesafe-tabanlı özel kodla (_compute_enemy_separation, body-block)
		## yapılıyor). move_and_slide()'ın çarpışma sonuçları (get_slide_
		## collision_count/is_on_wall vs.) kodun HİÇBİR yerinde okunmuyor - yani
		## sadece motorun broad-phase/slide/floor-snap hesaplarını boşuna
		## çalıştırıyordu. mask=0 olduğu sürece move_and_slide zaten SADECE
		## velocity*delta kadar engelsiz ilerletiyordu, bu yüzden davranış
		## BİREBİR AYNI kalacak şekilde doğrudan pozisyon güncellemesine
		## geçildi - 150+ yaratıkta her fizik karesi bu kadar gereksiz motor
		## çağrısından kurtuluyor.
		global_position += velocity * delta

		## Knockback hızı her karede sönümlenerek doğal biçimde sıfıra iner
		## (bkz. KNOCKBACK_DECAY yorumu) - donmuşken bile sönümleniyor ki
		## donma bitince birikmiş eski bir itiş aniden patlak vermesin.
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

		## Görünen baloncuk ile gerçek giremezlik sınırı HER ZAMAN birebir
		## eşleşsin diye sert bir garanti: move_and_slide sonrası hâlâ
		## min_separation'ın altındaysa (herhangi bir sebeple - itme,
		## knockback, vs.) doğrudan pozisyonu sınırın TAM üstüne yapıştırır.
		## (bkz. kullanıcı bildirimi: "gerçek menzil baloncuktan 2 kat fazla")
		## Aktif bir knockback sürerken (itiş hızı hâlâ belirginken) bu sert
		## yapıştırma ATLANIR - yoksa yumuşak itiş her karede bu klemensle
		## boğuşup yine "ışınlanma" hissi verirdi.
		## Yarasa Formu'ndaki Vampir'in içinden geçilebilir (player.gd/remote_player.gd is_ghost_now): sert yapıştırma onu
		## "gövde" saymamalı, yoksa yarasa üstünden geçerken yaratık dışarı fırlatılırdı.
		var target_is_ghost: bool = player != null and is_instance_valid(player) and _is_ghost_cached(player)
		if not is_frozen and player and is_instance_valid(player) and not target_is_ghost and min_separation > 0.0 and _knockback_velocity.length() < 40.0:
			var post_to_player: Vector2 = player.global_position - global_position
			var post_dist: float = post_to_player.length()
			if post_dist < min_separation:
				var away: Vector2 = -post_to_player.normalized() if post_dist > 0.5 else Vector2(1.0, 0.0)
				global_position = player.global_position + away * min_separation

		## DÜZELTME (kullanıcı bildirimi: "yaratıklar şovalye kalkan
		## baloncuğuna girebiliyor, girmemeleri gerekiyor asla") - kök neden:
		## yukarıdaki min_separation/sert-yapıştırma SADECE bu yaratığın o
		## anki EN YAKIN hedef oyuncusuna (_find_closest_target_player) göre
		## hesaplanıyordu. Oyuncular kümelenip bir yaratık aslında Şovalye'ye
		## DEĞİL de yanındaki başka bir oyuncuya saldırıyorsa, Şovalye'nin
		## aktif baloncuğu HİÇ kontrol edilmiyordu - yaratık o oyuncuyu
		## kovalarken baloncuğun içinden geçip gidebiliyordu. Artık hedeften
		## bağımsız olarak, aktif baloncuğu olan HERHANGİ bir oyuncuya karşı
		## da aynı sert "sınırın hemen dışına yapıştır" garantisi ayrıca
		## uygulanıyor (yukarıdaki zaten işlenmiş asıl hedef hariç).
		if not is_frozen:
			for zone_owner in _paladin_zone_owners():
				if zone_owner == player:
					continue
				var zone_radius: float = float(zone_owner.get("paladin_zone_radius"))
				if zone_radius <= 0.0:
					continue
				var to_owner: Vector2 = zone_owner.global_position - global_position
				var owner_dist: float = to_owner.length()
				if owner_dist < zone_radius:
					var away_owner: Vector2 = -to_owner.normalized() if owner_dist > 0.5 else Vector2(1.0, 0.0)
					global_position = zone_owner.global_position + away_owner * zone_radius

		## Seyyar satıcının güvenli bölgesi (kullanıcı isteği: "Yaratıklar
		## bariyerin içine giremezler") - yukarıdaki Şovalye baloncuğunun
		## AYNI "sert yapıştırma" tekniği, ama bir OYUNCUYA değil SABİT bir
		## dünya konumuna göre (bkz. GameManager.merchant_zone_pos/_radius/
		## _active, traveling_merchant.gd tarafından doldurulur). Hedef
		## seçimi zaten bölgedeki oyuncuları hariç tuttuğu için (bkz.
		## _find_closest_target_player) bu blok SADECE konumsal sınırı
		## garanti ediyor - Şovalye'nin kalkan-hasarı/damage-redirect
		## mekaniğiyle hiç ilgisi yok, yaratık bölgeye asla giremiyor.
		if not is_frozen and GameManager.merchant_zone_active:
			var to_merchant: Vector2 = GameManager.merchant_zone_pos - global_position
			var merchant_dist: float = to_merchant.length()
			if merchant_dist < GameManager.MERCHANT_ZONE_RADIUS:
				var away_merchant: Vector2 = -to_merchant.normalized() if merchant_dist > 0.5 else Vector2(1.0, 0.0)
				global_position = GameManager.merchant_zone_pos + away_merchant * GameManager.MERCHANT_ZONE_RADIUS

		## PERF: her fonksiyonun KENDİ ilk satırındaki "aktif değilse çık"
		## koşulu burada çağrı ÖNCESİ kontrol ediliyor - 200 yaratıkta kare
		## başına 2000 boş fonksiyon çağrısı yerine 2000 basit karşılaştırma.
		## Davranış birebir aynı; bir koşulu değiştirirsen fonksiyonun içindekini de değiştir.
		if item_shield_max > 0.0:
			_process_item_shield(delta)
		if not _poison_stack_time.is_empty():
			_process_poison(delta)
		if burn_time_left > 0.0:
			_process_burn(delta)
		if mark_stacks > 0:
			_process_mark(delta)
		if bleed_stacks > 0:
			_process_bleed(delta)
		if shock_time_left > 0.0 or _sleep_time > 0.0 or not _plague.is_empty() or not _enchant_flags.is_empty():
			_process_enchant_status(delta) ## efsun: şok / uyku / Salgın öksürüğü / bulaşıcı donma
		if chill_stacks > 0:
			_process_chill(delta)
		if _boss_chill_stacks > 0:
			_process_boss_chill(delta)
		if _slow_timer > 0.0 or _slow_fx_time_left > 0.0 or _slow_fx_broadcast_cooldown > 0.0:
			_process_slow(delta)
		if _root_timer > 0.0:
			_process_root(delta)
		if not _bee_poison_stacks.is_empty():
			_process_bee_poison(delta)

		## Oyuncuya olan yakın dövüş hasarı artık HitArea'nın (Area2D,
		## mask=2) "temas halinde" algılamasına DEĞİL, doğrudan mesafeye
		## bağlı - saldırı menzili boşluğuna (min_separation'ın biraz
		## üstü) girer girmez, kd bekleme süresi (contact_interval) hazırsa
		## anında hasar veriyor. Eskiden HitArea'ya bağlıydı ama oyuncunun
		## gerçek collision_layer'ı (main.tscn'de 1) o Area'nın mask'ıyla
		## (2) hiçbir zaman eşleşmiyordu (bkz. player_pet.gd:65 - "aynı
		## layer" yorumu artık yanlış, pet hâlâ layer=2'de) - yani oyuncuya
		## temas hasarı fiilen hiç tetiklenmiyordu. Bu artık tamamen
		## fiziksel layer/mask'tan bağımsız, güvenilir çalışıyor.
		##
		## Şovalye ultisi (paladin_zone_active) aktifken bu blok TAMAMEN
		## devre dışı - kullanıcı bildirimi: "ulti açıkken hasar alırken
		## üstünde gereksiz 0 yazıları çıkıyor, aslında kalkan canı %100
		## koruyor". Eskiden bir yaratık ulti açılmadan HEMEN ÖNCE zaten
		## true_contact_separation içindeyse (ör. tam saldırı anında),
		## min_separation onu iterek uzaklaştırana kadar birkaç karede bu
		## genel blok hâlâ tetiklenip normal take_damage() akışına (kalkan
		## emilimi %90-100 olmayabilir, cana da sızabilir, yuvarlanan
		## sayı "0" görünebilir) giriyordu. Artık ulti aktifken TÜM temas
		## hasarı (yakınlık farketmeksizin) aşağıdaki özel bloktan,
		## SADECE take_paladin_barrier_damage() üzerinden işleniyor.
		var paladin_shield_up: bool = player and is_instance_valid(player) and "paladin_zone_active" in player and player.paladin_zone_active
		if not is_frozen and not paladin_shield_up and player and is_instance_valid(player):
			_contact_timer -= delta
			## true_contact_separation kullanılıyor (min_separation DEĞİL) -
			## min_separation Şovalye ultisiyle 280px'e kadar şişebiliyor,
			## bu ise SADECE gerçek gövde-gövdeye dokunma mesafesi.
			## Kullanıcı isteği: "yakın dövüşçülerin saldırı menzili biraz
			## uzasın" - sadece is_ranged=false yaratıklarda +10 yerine +26.
			var melee_range: float = true_contact_separation + (26.0 if not is_ranged else 10.0)
			if dist <= melee_range and _contact_timer <= 0.0 and is_ability_invisible and _abilities != null:
				## Hayalet: "görünmezken saldıramazlar ve hasar veremezler" + "saldırdığı anda görünmezliği gider" -
				## saldırı mesafesine girince önce görünür olur, asıl vuruş GHOST_REVEAL_ATTACK_DELAY sonra gelir.
				_abilities.ghost_reveal(true)
			elif dist <= melee_range and _contact_timer <= 0.0:
				_contact_timer = contact_interval
				if not is_ranged:
					## Kullanıcı isteği (1. tur): "hasar anlık değme yerine
					## gerçek bir saldırı sırasında verilsin, oyuncu menzile
					## girince tetiklensin" - saldırı animasyonu HEMEN başlar.
					## DÜZELTME (2. tur, kullanıcı isteği #35: "saldırı
					## animasyonu başlar başlamaz hasar vermeliler ki insanlar
					## kolayca kaçamasın") - hasar artık animasyonun ORTASINA
					## (attack_dur * 0.45) değil, BAŞINA denk getiriliyor. Artık
					## yaratıklar saldırı animasyonu sırasında hareket
					## edemediği için (bkz. yukarıdaki State.ATTACK velocity
					## kilidi) eski orta-gecikme, oyuncunun gecikme süresi
					## içinde uzaklaşıp hasardan tamamen kaçmasına izin
					## veriyordu.
					var dur: float = _anim_length_for(State.ATTACK)
					var attack_dur: float = dur if dur > 0.0 else 0.35
					_enter_state(State.ATTACK, attack_dur)
					_broadcast_attack_state()
					_schedule_melee_hit(0.0, player)
				elif player.has_method("take_damage"):
					## Menzilliler burada SADECE oyuncu gövdeye tam yapışmışsa
					## (nadir) düşer - onlar için davranış eskisi gibi anlık.
					player.take_damage(contact_damage, self)
					var dur2: float = _anim_length_for(State.ATTACK)
					var attack_dur2: float = dur2 if dur2 > 0.0 else 0.35
					_enter_state(State.ATTACK, attack_dur2)
					_broadcast_attack_state()

		## Şovalye ultisi aktifken oyuncuya dokunan/dokunamayan TÜM yakın
		## dövüşçü yaratıklar KALKANA SALDIRIYOR: attack animasyonu oynatıp
		## periyodik olarak (contact_interval'da) kalkana hasar veriyor - bu
		## hasar PALADIN_ULTI_SHIELD_COST_MULT sayesinde zaten %95 azaltılmış
		## şekilde kalkana işleniyor, ayrıca baloncukta bir "isabet" parlaması
		## tetikliyor (bkz. player.gd flash_paladin_barrier). Menzilliler
		## normalde kendi projectile'larıyla saldırır (bkz. _process_ranged_
		## attack) - ama menzilli saldırılar zaten bölgeye giremiyor (bkz.
		## enemy_projectile.gd), o yüzden kışkırtılmış (bkz. apply_taunt)
		## menzilliler de - tıpkı yakın dövüşçüler gibi - kalkana yakın
		## dövüşle saldırabilsin diye buraya dahil edildi (kullanıcı isteği:
		## "şovalye adam temel yeteneğini kullanıp yaratıkların dikkatini
		## çekse bile kalkana saldırmalılar ulti açıkken"). Alt sınır
		## (true_contact_separation) KALDIRILDI - artık gövdeye tam yapışık
		## duran bir yaratık bile normal take_damage() DEĞİL, doğrudan bu
		## kalkan hasarı akışına giriyor (bkz. yukarıdaki not).
		##
		## Tolerans (min_separation + X): eskiden 16px'ti - kalabalık
		## yaratık gruplarında birbirini iten ayrışma kuvveti (bkz.
		## _compute_enemy_separation) yaratıkları tam sınırın hemen dışında
		## sıkıştırıp "dışarda takılı kalıp içeri girmeye çalışıyorlar ama
		## kalkana hiç vuramıyorlar" hissi veriyordu (kullanıcı bildirimi) -
		## bu jitter'ı tolere etmek için belirgin şekilde genişletildi.
		## DÜZELTME (kullanıcı bildirimi: "yaratıklar şovalye adamın kalkan
		## baloncuğu skiline uzaktan vuruyor, direk baloncuğun efekt sınırına
		## göre vurmuyor") - 60.0'ın toleransı yaratıkların baloncuğun görünen
		## kenarından 60px DIŞARIDAYKEN bile kalkana hasar vermesine izin
		## veriyordu (min_separation zaten baloncuk yarıçapına eşit, yani
		## saldırı menzili 126+60=186px'e kadar çıkıyordu). Tolerans 24.0'a
		## indirildi: yaratık kendisini baloncuk sınırına yapıştırdığı anda
		## (dist <= min_separation) zaten saldırıyor, 24px'lik pay sadece
		## kalabalık itişmesindeki küçük jitter'ı tolere ediyor - artık görünür
		## baloncuğun dışından saldıramıyorlar.
		var can_attack_barrier: bool = not is_ranged or _taunt_timer > 0.0
		# The barrier attack timer must continue ticking while the Paladin zone is active.
		if paladin_shield_up:
			_contact_timer = max(0.0, _contact_timer - delta)
		if not is_frozen and can_attack_barrier and paladin_shield_up:
			if dist <= min_separation + 24.0 and _contact_timer <= 0.0:
				_contact_timer = contact_interval
				## take_damage() DEĞİL - o akış shield_protection stat'ına bağlı ve
				## kalkan item'ı yoksa hasarı direkt cana geçiriyordu (bkz. kullanıcı
				## bildirimi). take_paladin_barrier_damage() sabit oranla (PALADIN_ULTI_SHIELD_COST_MULT) SADECE
				## gerçek kalkanı (item_shield_hp) yıpratır, cana hiç dokunmaz.
				if player.has_method("take_paladin_barrier_damage"):
					player.take_paladin_barrier_damage(contact_damage, self)
					var shield_dur: float = _anim_length_for(State.ATTACK)
					var shield_attack_dur: float = shield_dur if shield_dur > 0.0 else 0.35
					_enter_state(State.ATTACK, shield_attack_dur)
					_broadcast_attack_state()

		## NOT: Evcil hayvana (player_ally, bkz. player_pet.gd) eskiden buradan
		## HitArea yoluyla tesadüfi temas hasarı veriliyordu - kullanıcı
		## isteği üzerine pet artık ölümsüz + yaratıklar onu tamamen
		## görmezden geliyor (bkz. _on_hit_area_body_entered), o yüzden bu
		## dal kaldırıldı.

	_update_locomotion_state(delta)
	_update_state_timer(delta)

	if frame_sprite:
		_advance_frame_sprite(delta)


## Casts periodically once the player is roughly within range - a bit of
## slack (1.6x) beyond ranged_range so it keeps firing while the player is
## drifting in and out rather than needing to be exactly in the sweet spot.
## DÜZELTME (kullanıcı bildirimi: "Menzilli düşmanlar hem aynı anda birden
## çok ateşleme yapıyor sadece 1 adet ateşleme yapsın") - eskiden bu fonksiyon
## VE _process_homing_attack (aşağıda kaldırıldı) TAMAMEN BAĞIMSIZ iki ayrı
## zamanlayıcıydı (_ranged_timer/_normal_attack_timer), ikisi de 0.0'dan
## başladığı için oyuncu her iki menzile de girer girmez AYNI karede iki
## mermi (büyü + "garanti isabet" atışı) birden fırlıyordu. Artık TEK bir
## paylaşılan zamanlayıcı (_ranged_timer) var - her tikte İKİSİNDEN SADECE
## BİRİ ateşleniyor: oyuncu büyü menzilindeyse (1.6x) büyü, sadece daha
## geniş "garanti isabet" menzilindeyse (2.5x, büyü menzili dışında) o -
## ikisinin "geniş ağ" amacı (kaçarak menzil dışına çıkan oyuncuyu hâlâ
## tehdit etme) korunuyor, sadece artık aynı anda değil.
func _process_ranged_attack(delta: float, _player: Node2D, dist: float, dir: Vector2) -> void:
	if dist > ranged_range * 2.5:
		return
	_ranged_timer -= delta
	if _ranged_timer > 0.0:
		return
	## Kullanıcı bildirimi (2026-09-24): "yaratıklar duvarların arkasından ateş edebiliyor... onlar bizi göremediğinde
	## ateş edememeliler" - hedefi göremiyorsa ateş etmez; sayaç hazır bekler, görüş açılınca hemen ateşler.
	if not _has_line_of_sight(_player):
		_ranged_timer = 0.0
		return
	if dist <= ranged_range * 1.6:
		_ranged_timer = ranged_attack_interval
		_fire_ranged_attack(dir)
	else:
		_ranged_timer = normal_attack_interval
		_fire_homing_attack()


func _fire_ranged_attack(dir: Vector2) -> void:
	var dur: float = _anim_length_for(State.ATTACK)
	var attack_dur: float = dur if dur > 0.0 else 0.4
	_enter_state(State.ATTACK, attack_dur)
	_broadcast_attack_state()
	var proj = EnemyProjectileScene.instantiate()
	proj.global_position = global_position
	proj.direction = dir
	## Kullanıcı isteği: büyü hasarı %60 azaltıldı (normal atış AYRI, bkz.
	## _fire_homing_attack) - RANGED_SPELL_DAMAGE_MULT = 0.4.
	proj.damage = (ranged_damage if ranged_damage > 0.0 else contact_damage) * RANGED_SPELL_DAMAGE_MULT
	proj.source = self
	proj.tint = projectile_tint
	## call_deferred: EnemyProjectile eskiden (XpOrb/GoldDrop gibi) Area2D idi ve _physics_process içinden
	## eklenmesi fizik sorgu taşması riski taşıyordu. Artık fizik nesnesi olmayan düz bir Node2D (bkz.
	## enemy_projectile.gd PERF notu) - erteleme zararsız olduğu için savunma amaçlı korunuyor.
	get_tree().current_scene.call_deferred("add_child", proj)
	
	## Multiplayer: düşman mermisini client'lara broadcast et (görsel kopya)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		NetworkManager.broadcast_enemy_projectile.rpc(global_position, dir, false, projectile_tint, net_id)


## İKİNCİ, daha zayıf, GARANTİ İSABETLİ atış - büyüden farklı hasar/görsel
## kullanır ama artık AYRI bir zamanlayıcısı yok (bkz. _process_ranged_attack
## üstündeki DÜZELTME notu - ikisi artık paylaşılan _ranged_timer'dan sırayla
## tetikleniyor, hiç aynı anda değil).
## DÜZELTME (kullanıcı bildirimi: "uzaktan kesin bir şekilde hasar
## verebilen büyücü düşmanlar var hala garanti vuran menzilli silahları
## var") - bu "ikinci, zayıf ama garanti isabetli" atış artık homing=true
## İLE ateşlenmiyor: oyuncunun o anki konumuna doğru düz bir mermi olarak
## fırlatılıyor, tıpkı büyü atışı gibi - hareket ederek kaçınılabilir hale
## geldi. (homing alanı/enemy_projectile.gd'deki takip mantığı ileride
## başka bir amaç için lazım olursa diye kaldırılmadı, sadece kullanılmıyor.)
## Ayrıca hedef artık SADECE host'un kendi yerel oyuncusu değil, en yakın
## oyuncu (yerel VEYA uzak) - bkz. _find_closest_target_player, diğer tüm
## saldırı mantığıyla tutarlı olsun diye.
func _fire_homing_attack() -> void:
	var player := _find_closest_target_player()
	if not player or not is_instance_valid(player):
		return
	if not _has_line_of_sight(player): ## en yakın oyuncu çağıranın hedefinden farklı olabilir - onu da görmeli
		return
	var proj = EnemyProjectileScene.instantiate()
	proj.global_position = global_position
	proj.direction = (player.global_position - global_position).normalized()
	proj.damage = (ranged_damage if ranged_damage > 0.0 else contact_damage) * normal_attack_damage_mult
	proj.source = self
	## Büyüden görsel olarak ayırt edilsin diye biraz soluk/açık tonu.
	proj.tint = projectile_tint.lightened(0.35)
	get_tree().current_scene.call_deferred("add_child", proj)
	
	## Multiplayer: mermiyi client'lara broadcast et (görsel kopya) - artık
	## homing DEĞİL (bkz. yukarıdaki düzeltme notu), o yüzden 3. argüman da
	## false: kozmetik kopyalar kendi ekranlarındaki yerel oyuncuya doğru
	## yanlışlıkla dönmesin.
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		NetworkManager.broadcast_enemy_projectile.rpc(global_position, proj.direction, false, proj.tint, net_id)


## walk_texture'ın yolundan ("..._Walk_..." -> "..._Idle_...") aynı klasördeki Idle sayfasını
## bulur; yoksa null (o zaman IDLE, walk sayfasının 0. karesinde bekler). Dosya adı yazımı
## yaratığa göre değişiyor (Ent1_Walk_with_shadow / orc1_walk_with_shadow ...), dört varyant denenir.
static func _derive_idle_texture(walk: Texture2D) -> Texture2D:
	if walk == null:
		return null
	var path: String = walk.resource_path
	if path.is_empty():
		return null
	for pair: Array in [["_Walk_", "_Idle_"], ["_walk_", "_idle_"], ["Walk", "Idle"], ["walk", "idle"]]:
		if not path.contains(String(pair[0])):
			continue
		var candidate: String = path.replace(String(pair[0]), String(pair[1]))
		if candidate != path and ResourceLoader.exists(candidate):
			return load(candidate) as Texture2D
	return null


## Gerçek yer değiştirmeye bakıp WALK <-> IDLE geçişini yapar (bkz. IDLE_SPEED_THRESHOLD üstündeki
## not). HURT/ATTACK/DEATH önceliklidir: onlar sürerken durum değişmez ama ölçüm sürer, böylece
## saldırı/vuruş bitip WALK'a dönünce yaratık hâlâ duruyorsa hemen IDLE'a geçer (saldırılar
## arasında yürüme pozunda takılmaz). Host'ta ve istemci (puppet) dalında AYNI çağrılır.
func _update_locomotion_state(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _loco_initialized:
		_loco_prev_pos = global_position
		_loco_initialized = true
		return
	var moved_speed: float = global_position.distance_to(_loco_prev_pos) / delta
	_loco_prev_pos = global_position
	_loco_speed = lerpf(_loco_speed, moved_speed, minf(1.0, delta * IDLE_SPEED_SMOOTHING))
	if _loco_speed < IDLE_SPEED_THRESHOLD:
		_idle_timer += delta
	else:
		_idle_timer = 0.0
	if _state == State.WALK and _idle_timer >= IDLE_ENTER_DELAY:
		_enter_state(State.IDLE)
	elif _state == State.IDLE and _idle_timer <= 0.0:
		_enter_state(State.WALK)


func _update_state_timer(delta: float) -> void:
	if _state == State.DEATH:
		return
	if _state_duration > 0.0:
		_state_duration -= delta
		if _state_duration <= 0.0:
			_enter_state(State.WALK)


func _update_facing(dir: Vector2) -> void:
	if dir.length() < 0.1:
		return

	# frame_sprite enemies (boss, rat, ...) have real down/up/left/right art,
	# so just pick the matching row - no mirroring needed.
	if frame_sprite:
		if abs(dir.x) > abs(dir.y):
			_sprite_row = ROW_RIGHT if dir.x > 0.0 else ROW_LEFT
		else:
			_sprite_row = ROW_DOWN if dir.y > 0.0 else ROW_UP

	# anim_sprite enemies (the orc sheets) only have one facing baked in
	# (drawn facing right), so mirror it when moving left instead.
	if anim_sprite and abs(dir.x) >= 0.15:
		var moving_left: bool = dir.x < 0.0
		if moving_left != _flip_h:
			_flip_h = moving_left
			anim_sprite.flip_h = _flip_h


## Switches the current animation state. duration > 0 means "play this and
## automatically fall back to WALK after `duration` seconds"; 0 means it
## persists until something else changes it (used for DEATH).
func _enter_state(new_state: int, duration: float = 0.0) -> void:
	if _state == State.DEATH:
		return
	## PERF: zaten bu durumdaysa (ör. alan hasarında art arda "hurt") sadece
	## süreyi/kareyi yeniden başlat - doku/kare ızgarası/animasyon zaten doğru.
	var same_state: bool = _state == new_state
	_state = new_state
	_state_duration = duration
	_frame_time = 0.0
	if same_state:
		return

	if frame_sprite:
		var tex: Texture2D = _texture_for_state(new_state)
		if tex:
			frame_sprite.texture = tex
			frame_sprite.hframes = max(int(tex.get_width() / float(cell_size)), 1)
			frame_sprite.vframes = 4

	if anim_sprite and anim_sprite.sprite_frames:
		var anim_name: String = _anim_name_for_state(new_state)
		if anim_sprite.sprite_frames.has_animation(anim_name):
			anim_sprite.play(anim_name)


## Host bu yaratığın saldırı animasyonuna girdiği anı (yukarıdaki üç
## _enter_state(State.ATTACK, ...) çağrı noktası) istemcilere yayınlar, ki
## karşı tarafın ekranında da gerçek saldırı pozu oynasın - eskiden sadece
## pozisyon/can senkronize oluyordu, saldırı animasyonu istemcide hiç
## tetiklenmiyordu (yaratık istemci ekranında sürekli yürüme animasyonunda
## kalıyordu). NetworkManager.broadcast_enemy_vfx'teki "attack_state" case'i
## bunu alıp _enter_state_networked() üzerinden uygular.
## DÜZELTME (mimari sadeleştirme): süre (duration) artık ağdan GÖNDERİLMİYOR -
## _anim_length_for(State.ATTACK) bu yaratığın KENDİ sabit doku/animasyon
## verisinden hesaplanan, host'ta da istemcide de birebir AYNI sonucu veren
## saf bir fonksiyon (hangi textürün kaç kare olduğu değişmiyor). Süreyi
## sayı olarak taşımak yerine istemci de tıpkı host gibi kendi hesaplıyor -
## hem bir alan daha az trafik hem de iki tarafın süresi asla birbirinden
## sapamaz.
func _broadcast_attack_state() -> void:
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "attack_state", {})


## broadcast_enemy_vfx RPC'sinin çağırdığı istemci tarafı karşılığı - süreyi
## host'un hesapladığı AYNI saf fonksiyonla (_anim_length_for) kendisi
## hesaplar, bkz. yukarıdaki not.
func _enter_state_networked() -> void:
	var dur: float = _anim_length_for(State.ATTACK)
	_enter_state(State.ATTACK, dur if dur > 0.0 else 0.4)


## Host'ta bir yaratık hasar alınca istemcilerde de beyaz vuruş parlaması (_flash)
## oynasın diye yayınlanır (eskiden "hurt_state" adıyla HURT animasyonunu da
## tetikliyordu - HURT kaldırıldı, bkz. _apply_damage). Bu yayın SİLİNMEMELİ: host'un
## _flash() çağrısı sadece host'ta çalışır, istemciler parlamayı YALNIZCA buradan alır.
func _broadcast_hit_flash() -> void:
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		## DÜZELTME (kullanıcı bildirimi: "multiplayerda katılımcılar yine lag
		## sorunları yaşıyor yaratıklar bir yürüyüp bir duruyor ve bazen
		## arkalarına dönüyorlar" + "multiplayerda katılımcıların fpsi çok
		## düşüyor") - "damage_number" (bkz. _apply_damage) ZATEN should_
		## throttle ile sınırlanmıştı ama bu yayın ("hurt_state") hiç sınırlanmamıştı:
		## hızlı ateş eden silahler/DOT tikleri aynı yaratığa saniyede onlarca
		## "hurt_state" RPC'si (reliable) gönderebiliyordu. Bu, relay'in
		## bağlantı başına mesaj/byte bütçesini pozisyon senkronuyla
		## (_sync_enemy_positions, unreliable) paylaşıp tüketiyor - bütçe
		## dolunca pozisyon paketleri gecikip/kaybolduğu için katılımcılarda
		## yaratıklar "bir yürüyüp bir duruyor, bazen arkasına dönüyor" gibi
		## görünüyordu; ayrıca her RPC katılımcı tarafında bir animasyon
		## durumu değişimi tetiklediği için çok sayıda yaratık aynı anda
		## vurulunca istemci FPS'i de düşüyordu. "damage_number" ile AYNI
		## desenle sınırlandı - kozmetik olduğu için kayıp fark edilmez.
		if net_id > 0 and not NetworkManager.should_throttle("hitflash_%d" % net_id, 0.1):
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "hit_flash", {})


## _broadcast_attack_state/_broadcast_hit_flash İLE BİREBİR AYNI desen -
## die()'ın en başından, tam "attack_state"/"hit_flash" gibi anında ve
## reliable olarak çağrılır (bkz. die() içindeki not). Karşı taraf
## broadcast_enemy_vfx'teki "death_state" case'i bunu alıp doğrudan
## target_enemy.die() çağırıyor - die() zaten en başta is_dead kontrolüyle
## korunduğu için periyodik senkrondan gelecek olası bir ikinci çağrıyla
## çakışmaz.
func _broadcast_death_state() -> void:
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "death_state", {})


## broadcast_enemy_vfx RPC'sinin "hit_flash" case'inin çağırdığı istemci
## tarafı karşılığı (HURT animasyonu kaldırıldı, sadece parlama).
## DÜZELTME (bkz. proje köküdeki CLAUDE.md - "kaster kendi ekranında doğru
## görür, diğer oyuncularda hiçbir şey görünmez" hata sınıfı): _flash()
## (beyaz hit-flash) SADECE host'ta çalışan _apply_damage()'dan
## çağrılıyordu, host-olmayan istemciler bu senkronu
## alıyordu ama flaşı HİÇ tetiklemiyordu - bu yüzden onlarda yaratıklar
## hasar alırken hiç beyazlamıyordu. Artık host'un _apply_damage()'taki
## çağrısıyla AYNI şekilde burada da tetikleniyor.
func _play_hit_flash_networked() -> void:
	_flash()


func _texture_for_state(state: int) -> Texture2D:
	match state:
		State.DEATH:
			return death_texture if death_texture else walk_texture
		State.ATTACK:
			return attack_texture if attack_texture else walk_texture
		State.IDLE:
			return idle_texture if idle_texture else walk_texture
		_:
			return walk_texture


func _anim_name_for_state(state: int) -> String:
	match state:
		State.DEATH:
			return "death"
		State.ATTACK:
			return "attack1"
		State.IDLE:
			return "idle"
		_:
			return "walk"


## How long (seconds) a full cycle of the given state's animation takes,
## used both to time HURT/ATTACK before falling back to WALK, and to know
## how long to let DEATH play before the corpse is actually removed.
func _anim_length_for(state: int) -> float:
	if frame_sprite:
		var tex: Texture2D = _texture_for_state(state)
		if tex:
			var cols: int = max(int(tex.get_width() / float(cell_size)), 1)
			return cols / max(sprite_fps, 1.0)
	if anim_sprite and anim_sprite.sprite_frames:
		var anim_name: String = _anim_name_for_state(state)
		if anim_sprite.sprite_frames.has_animation(anim_name):
			var frame_count: int = anim_sprite.sprite_frames.get_frame_count(anim_name)
			var anim_speed: float = anim_sprite.sprite_frames.get_animation_speed(anim_name)
			if anim_speed > 0.0:
				return frame_count / anim_speed
	return 0.0


func _advance_frame_sprite(delta: float) -> void:
	var cols: int = max(frame_sprite.hframes, 1)
	_frame_time += delta * sprite_fps
	var col: int
	if _state == State.WALK:
		col = int(_frame_time) % cols
	elif _state == State.IDLE:
		## Idle sayfası varsa döngüde oynar; yoksa (yedek: walk sayfası) yürüme karelerini
		## döndürmek yerine duruş karesinde (0) bekler.
		col = int(_frame_time) % cols if idle_texture else 0
	else:
		col = min(int(_frame_time), cols - 1)
	frame_sprite.frame = _sprite_row * cols + col


func _on_hit_area_body_entered(body: Node) -> void:
	# player_ally (Matthew'in yaratığı, bkz. player_pet.gd) artık burada
	# ELENİYOR - kullanıcı isteği: "yaratıklar onu görmezden gelmeli". Pet
	# ölümsüz + yakın dövüşçü oldu, düşmanlar ona hiç tepki vermiyor.
	if is_instance_valid(body) and body.is_in_group("player"):
		_player_in_hit_area = body
		_contact_timer = 0.0


func _on_hit_area_body_exited(body: Node) -> void:
	if body == _player_in_hit_area:
		_player_in_hit_area = null


func update_network_state(net_position: Vector2, net_dead: bool = false, net_health: float = -1.0, net_shield: float = -1.0, net_raging: bool = false, net_chill: int = -1, net_attacker_id: int = 0) -> void:
	## DÜZELTME: enemy_spawner.gd _sync_enemy_positions bu fonksiyonu 7
	## argümanla çağırıyordu (bkz. net_attacker_id) ama imza sadece 6 kabul
	## ediyordu - "too many arguments" hatasıyla ÇAĞRININ TAMAMI (yani bu
	## yaratığın konum/can/ölüm senkronunun HEPSİ) başarısız oluyordu. Bkz.
	## last_attacker_peer_id yorumu (üstteki değişken tanımı).
	if net_attacker_id > 0:
		last_attacker_peer_id = net_attacker_id
	## Dead reckoning hız tahmini (bkz. _network_velocity üstündeki dosya
	## başı notu) - iki gerçek paket arasında GEÇEN GERÇEK süreden
	## (_network_time_since_update, _physics_process'te her karede
	## biriktiriliyor) türetiliyor. Ağır bir aşırı-hesaplama/"ışınlanma"
	## riskine karşı (ör. bir paket uzun süre gecikip sonra çok büyük bir
	## konum farkıyla gelirse) yaratığın gerçekçi azami hızıyla sınırlanıyor
	## - rage modu (RAGE_SPEED_MULT = 2.4) dahil en hızlı durumun bile
	## bolca üzerinde, ama bir "gecikme + ışınlanma" sıçramasını sonsuz
	## hıza çıkarmayacak kadar sıkı bir tavan.
	if _network_state_received and _network_time_since_update > 0.02:
		var raw_velocity: Vector2 = (net_position - _network_target_position) / _network_time_since_update
		var max_speed: float = max(speed, 40.0) * 3.5
		if raw_velocity.length() > max_speed:
			raw_velocity = raw_velocity.normalized() * max_speed
		_network_velocity = raw_velocity
	else:
		_network_velocity = Vector2.ZERO
	_network_time_since_update = 0.0
	_network_target_position = net_position
	_network_state_received = true
	if net_health >= 0.0:
		# Flash on damage taken (health decreased)
		if health > net_health and health > 0.0:
			_flash()
		health = net_health
		_show_overhead_bar()
	if net_shield >= 0.0:
		# Flash when shield takes a hit too
		if item_shield_hp > net_shield and item_shield_hp > 0.0:
			_flash()
		item_shield_hp = net_shield
		_show_overhead_bar()
	if net_raging and not is_raging:
		_enter_rage_mode()
	if net_chill >= 0 and net_chill != chill_stacks:
		chill_stacks = net_chill
		_refresh_chill_tint()
	if net_dead and not is_dead:
		# Trigger full death sequence so clients see death animation, drops, etc.
		die()


## is_area: bu isabet bir ALAN hasarından mı geliyor (patlama, sıçrama, dönen kılıç, çoklu hedefli yetenek...). Sadece CAN EMME
## hesabı için (bkz. player.gd on_dealer_hit): alan hasarında can emme GameManager.LIFESTEAL_EFFECTIVENESS (%33) kadar geçerli.
func take_damage(amount: float, is_crit: bool = false, shield_pen_percent: float = 0.0, is_area: bool = false) -> void:
	if is_dead:
		return
	## Görünmez hayalet hedef alınamaz VE vurulamaz (alan hasarı dahil) - bkz. set_ability_invisible.
	if is_ability_invisible:
		return

	## Oyun sonu istatistik ekranı (bkz. player.gd match_damage_dealt üstündeki
	## yorum): take_damage() TAM OLARAK vuran client'ın kendi kodunun çağırdığı
	## fonksiyon - host'ta mı yoksa bir istemcide mi çalıştığından BAĞIMSIZ
	## olarak, bu satır HER ZAMAN "beni çağıran bu makinedeki yerel oyuncu"
	## tarafına doğru şekilde hasar ekler (host-yetkili _apply_damage'ın
	## aksine, o SADECE host'ta çalışır ve istemci vuruşlarını host'a yanlış
	## atfederdi - can çalma pasifinin ZATEN düştüğü aynı tuzak).
	var _dealer: Node = get_tree().get_first_node_in_group("player")
	if amount > 0.0 and _dealer and "match_damage_dealt" in _dealer:
		_dealer.match_damage_dealt += amount
	## Vampir Çocuk'un pasif can emmesi (verilen hasarın %4'ü) - bkz. player.gd on_dealer_hit. Genel
	## on_damage_dealt (aşağıdaki _apply_damage) SADECE host'ta çalıştığı için istemci Vampir'i
	## iyileştiremezdi; burası tam vuran istemcide çalışıyor.
	if amount > 0.0 and _dealer and _dealer.has_method("on_dealer_hit"):
		_dealer.on_dealer_hit(amount, is_area)

	## Multiplayer: non-host clients route damage through the host so there is
	## a single authoritative enemy health pool. Without this every peer fights
	## its own local copy of each enemy and nothing stays in sync.
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			var host_id: int = NetworkManager._host_peer_id()
			NetworkManager.request_enemy_damage.rpc_id(host_id, net_id, amount, is_crit, shield_pen_percent)
		return

	## DÜZELTME (Korsan/Necromancer öldürme pasifleri multiplayer'da sadece
	## host bizzat o karakterleri oynarken çalışıyordu): last_attacker_peer_id
	## eskiden SADECE istemci vuruşlarında (take_damage_host üzerinden) set
	## ediliyordu - host kendi silahıyla BURADAN doğrudan vurduğunda hiç
	## güncellenmiyordu, yani host'un attığı gerçek öldürücü darbe ondan ÖNCE
	## vurmuş bir istemciye yanlış atfedilebilirdi (bkz. die()). Artık "son
	## vuran" tutarlı şekilde her iki yoldan da (istemci RPC'si / host'un
	## kendi yerel vuruşu) güncelleniyor.
	if NetworkManager.is_multiplayer_active:
		last_attacker_peer_id = multiplayer.get_unique_id()
	## Efsun durumları (bkz. "EFSUN ELEMENT SİSTEMİ"): uyku bonusu, uyandırma, şok sıçraması - doğrudan isabetlerde.
	amount = _pre_direct_hit(amount)
	_apply_damage(amount, is_crit, shield_pen_percent)
	_post_direct_hit(amount)


## Called by NetworkManager.request_enemy_damage RPC on the host only.
## ÇOK OYUNCULU DÜZELTME (2026-09-24 senkron analizi): yaratığın ÜSTÜNDEKİ sürekli hasarlar (zehir/yanma/kanama/arı
## zehri) sadece host'ta tikliyor. Eskiden bu tikler take_damage()'ı çağırıyordu - o da HER tikte last_attacker_peer_id'yi
## host'a yazıyor, tik hasarını host'un maç istatistiğine ekliyor ve host'a can emme şansı veriyordu. Yani bir İSTEMCİNİN
## Tüftüf zehriyle ölen yaratıkta öldürme ödülü (şans, Korsan altını, Necromancer ruhu, Savaş Şevki) ve can emme host'a
## gidiyordu. Artık tik, son DOĞRUDAN vuranın kimliğini korur (etkiyi genelde o uygulamıştır); istatistik/can emme sadece
## o kişi bu makinenin oyuncusuysa (tek oyunculu ya da host'un kendi vuruşu) burada işlenir.
func _take_dot_damage(amount: float, shield_pen: float = 0.0) -> void:
	if is_dead or is_ability_invisible or amount <= 0.0:
		return
	var local_owner: bool = not NetworkManager.is_multiplayer_active or last_attacker_peer_id <= 0 \
			or (multiplayer.has_multiplayer_peer() and last_attacker_peer_id == multiplayer.get_unique_id())
	if local_owner:
		var dealer: Node = get_tree().get_first_node_in_group("player")
		if dealer and "match_damage_dealt" in dealer:
			dealer.match_damage_dealt += amount
		if dealer and dealer.has_method("on_dealer_hit"):
			dealer.on_dealer_hit(amount, false)
	_apply_damage(amount, false, shield_pen)


func take_damage_host(amount: float, is_crit: bool, shield_pen_percent: float, attacker_id: int = 0) -> void:
	if is_dead or is_ability_invisible:
		return
	if attacker_id > 0:
		last_attacker_peer_id = attacker_id
	amount = _pre_direct_hit(amount)
	_apply_damage(amount, is_crit, shield_pen_percent)
	_post_direct_hit(amount)


## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
## oyundan kaldır. gerçek hasar artık kalkanı görmezden gelerek vuruyor
## eskisi gibi") - eskiden kalkan emiliminden SONRA bir de "effective_armor"
## (armor_pen_percent/armor_pen_flat ile delinen düz zırh) düşülüyordu; zırh
## tamamen kaldırıldığı için o katman de gitti - kalkanı geçen hasar artık
## doğrudan (en az 1 hasar garantisiyle) cana işliyor.
func _apply_damage(amount: float, is_crit: bool, shield_pen_percent: float) -> void:
	## Efsun: Kafatası Kırıcı çatlakları + Derin Uyku - alınan TÜM hasar (DOT dahil).
	if crack_stacks > 0 or _sleep_vuln > 0.0 or _vuln_pct > 0.0 or mark_stacks > 0:
		amount *= _damage_taken_mult()
	var remaining: float = amount
	var effective_protection: float = shield_protection * (1.0 - clamp(shield_pen_percent, 0.0, 1.0))
	if item_shield_hp > 0.0 and effective_protection > 0.0:
		# Shield only ever eats its protection share of the hit - the rest
		# always reaches health, same split as the player's own shield.
		# Delicilik Modu's shield_pen_percent shrinks that share per-hit.
		var absorbed: float = min(item_shield_hp, amount * effective_protection)
		item_shield_hp -= absorbed
		remaining -= absorbed
		item_shield_regen_delay = ITEM_SHIELD_REGEN_DELAY
		item_shield_changed.emit(item_shield_hp, item_shield_max)

	_flash()
	_show_overhead_bar()

	if remaining <= 0.0:
		return

	## DÜZELTME: zırh kaldırılırken bu satır "health -= effective_amount"
	## (aşağıdaki lifesteal/hasar yazısı/ağ yayınında da kullanılan tek bir
	## değişken) yerine doğrudan "max(remaining, 1.0)" ifadesine
	## dönüştürülmüştü ama effective_amount'un TANIMI silinmişti - script hiç
	## derlenemiyordu (bkz. kullanıcı bildirimi: "oyuna giremiyorum ...
	## yaratıklar da donuyordu").
	var effective_amount: float = max(remaining, 1.0)
	health -= effective_amount
	health_changed.emit(health, max_health)
	_show_overhead_bar()
	## Rage modu tetikleyicisi (bkz. is_raging üstündeki yorum) - Kademe 2+,
	## yakın dövüşçü, boss olmayan bir yaratık canı %30'un altına düşünce BİR
	## KEZE mahsus tetiklenir.
	if not is_raging and not is_ranged and not is_boss and _current_tier >= 2 \
			and health > 0.0 and health <= max_health * _rage_hp_threshold():
		_enter_rage_mode()
	## Can çalma (kart/eşya/silah): oyuncuya, yaratığın gerçekten yediği
	## hasar üzerinden bildirim - pasifsiz karakterlerde no-op.
	## Can emme artık VURAN istemcide (take_damage -> player.on_dealer_hit) hesaplanıyor: burası SADECE host'ta çalıştığı için
	## istemci vuruşları host oyuncusuna yanlış atfediliyor ve alan hasarı ayırt edilemiyordu.
	## Kullanıcı isteği (2026-09-25): "başka oyuncuların hasar sayısını görmemeliyiz" - sayı SADECE vuranın
	## ekranında çıkar. Vuran = last_attacker_peer_id (take_damage/take_damage_host her isabette günceller, DOT tiki
	## son doğrudan vuranınkini korur - bkz. _take_dot_damage). Bilinmiyorsa (0: tek oyunculu ya da oyuncu dışı
	## bir kaynak) eskisi gibi herkese.
	var dmg_owner: int = last_attacker_peer_id if NetworkManager.is_multiplayer_active else 0
	var my_peer: int = multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0
	if dmg_owner <= 0 or dmg_owner == my_peer:
		_spawn_floating_text(effective_amount, is_crit)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host and dmg_owner != my_peer:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		## Relay'in saniyelik mesaj/byte bütçesini aşıp bağlantıyı KAPATMASINI
		## önlemek için sınırlanıyor (bkz. NetworkManager.should_throttle
		## üzerindeki not) - çok hızlı vuran silahlar/DOT tikleri aynı
		## yaratığa saniyede onlarca "damage_number" göndermeye çalışabilir,
		## bu salt kozmetik olduğu için kayıp fark edilmez ama flood'u önler.
		## Kısıtlama vuran başına: aynı yaratığa vuran iki oyuncu birbirinin sayısını yutmasın.
		if net_id > 0 and not NetworkManager.should_throttle("dmgnum_%d_%d" % [net_id, dmg_owner], 0.1):
			var dmg_payload: Dictionary = {"amount": effective_amount, "is_crit": is_crit}
			if dmg_owner > 0:
				NetworkManager.broadcast_enemy_vfx.rpc_id(dmg_owner, net_id, "damage_number", dmg_payload)
			else:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "damage_number", dmg_payload)
	## Ruhani Yetenek "Savaş Şevki": bu isabeti verenin seçtiği ruhani yetenek buysa, normal hasardan sonra
	## hâlâ hayattaysa ama kalan can oranı eşiğin altındaysa anında öldürülür (bkz. _attacker_has_savas_sevki,
	## spiritual_skills.gd SAVAS_SEVKI_EXECUTE_PERCENT*). die() zaten aşağıda "health <= 0" ile tetiklenir,
	## burada SADECE canı sıfırlıyoruz - ikinci bir ölüm yolu açmıyoruz.
	if health > 0.0 and max_health > 0.0 and _attacker_has_savas_sevki():
		var execute_percent: float = SpiritualSkillsScript.SAVAS_SEVKI_EXECUTE_PERCENT_BOSS if is_boss else SpiritualSkillsScript.SAVAS_SEVKI_EXECUTE_PERCENT
		if (health / max_health) < execute_percent:
			health = 0.0
	if health <= 0:
		die()
	else:
		## Kullanıcı isteği (2026-09-23): "yaratıkların hurt animasyonlarına gerek yok
		## onları komple kaldıralım" - vuruş alınca artık HURT pozuna girilmiyor (hareketi
		## zaten etkilemiyordu, salt görseldi). Beyaz vuruş parlaması (_flash) kalıyor;
		## istemcilerde de görünsün diye sadece o yayınlanıyor.
		_broadcast_hit_flash()



## Kullanıcı isteği: "hasar alan yaratıkların anlık beyazlaması ... pixel
## oyunlarda kullanılan hasar alıncaki beyazlama efekti" - DÜZELTME: eskiden
## bu efekt modulate'i kırmızıya (Color(1.0, 0.4, 0.4)) çekip GERİ getiriyordu
## (kırmızı "flaş", beyaz değil). modulate rage/chill durum tonu için hâlâ
## _refresh_chill_tint()/_status_tint_color() tarafından kullanıldığından,
## anlık beyaz "pop" tamamen AYRI bir shader uniform'uyla (flash_amount,
## bkz. shaders/hit_flash.gdshader) yapılıyor - böylece flaş ile durum tonu
## ASLA aynı property üzerinde çakışmıyor/birbirinin üstüne binmiyor.
const HitFlashShader: Shader = preload("res://shaders/hit_flash.gdshader")
const HIT_FLASH_DURATION := 0.12
var _hit_flash_material: ShaderMaterial = null


func _flash() -> void:
	var target: CanvasItem = null
	if anim_sprite:
		target = anim_sprite
	else:
		target = frame_sprite
	if not target:
		return
	if not _hit_flash_material:
		_hit_flash_material = ShaderMaterial.new()
		_hit_flash_material.shader = HitFlashShader
		target.material = _hit_flash_material
	## PERF (kullanıcı bildirimi: alan hasarında 200 yaratıkta FPS 60->40): eskiden
	## HER vuruşta yeni bir Tween nesnesi oluşturuluyordu (200 yaratıklık bir alan
	## hasarı = tek karede 200 Tween). Aynı 1.0 -> 0.0 doğrusal sönüm artık
	## _tick_hit_flash() içinde basit bir sayaçla yapılıyor - görünüm birebir aynı.
	_hit_flash_material.set_shader_parameter("flash_amount", 1.0)
	_flash_time_left = HIT_FLASH_DURATION


var _flash_time_left: float = 0.0

func _tick_hit_flash(delta: float) -> void:
	_flash_time_left = maxf(0.0, _flash_time_left - delta)
	if _hit_flash_material:
		_hit_flash_material.set_shader_parameter("flash_amount", _flash_time_left / HIT_FLASH_DURATION)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	## Yaratık yetenekleri (2026-09-24): görünmez ölen hayalet ölüm animasyonunu görünür oynatsın; zombi ölünce
	## patlayıp yere 4 sn zehirli asit bırakır (sadece host/tek oyunculu yetkili örnek doğurur ve yayınlar - istemcide
	## die() de çalıştığı için orada ikinci bir göl DOĞMAZ, görsel kopya RPC ile gelir).
	if is_ability_invisible:
		set_ability_invisible(false)
	## Korku göstergesi ölüm animasyonunda kalmasın (her istemcide yerel - die() istemcide de çalışır).
	is_feared = false
	_fear_wander = false
	_remove_fear_status_fx()
	_remove_entangle_fx()
	## Aileye özgü kısık ölüm sesi (kullanıcı isteği 2026-09-25) - her istemcide yerel, bkz. creature_death_sound.gd.
	if is_inside_tree():
		CreatureDeathSound.play(get_tree(), creature_family(), global_position, is_boss)
	if creature_family() == "zombie" and (not NetworkManager.is_multiplayer_active or NetworkManager.is_host) and is_inside_tree():
		EnemyAbilitiesScript.spawn_zombie_acid(get_tree(), global_position, contact_damage, self)
	## Görev sistemi (bkz. world_event_manager.gd "Alanı Güvenceye Al") - bkz. GameManager.
	## enemy_died üstündeki not.
	GameManager.enemy_died.emit(global_position)

	## DÜZELTME (kullanıcı bildirimi: "yaratıkların ölüm animasyonu
	## katılımcılarda farklı görünüyor"): host'un ölümü katılımcılara
	## eskiden SADECE enemy_spawner.gd'nin periyodik (0.15sn'de bir),
	## "unreliable" _sync_enemy_positions paketindeki net_dead bayrağıyla
	## ulaşıyordu - saldırı/vuruş animasyonlarının (bkz. _broadcast_attack_
	## state/_broadcast_hit_flash) tersine, ölüm anında ANINDA/güvenilir
	## (reliable) bir bildirim YOKTU. Bu da katılımcının ölümü host'tan
	## 150ms'ye kadar GEÇ öğrenmesine (ve o sürede yaratığın host'ta zaten
	## durmuş olmasına rağmen katılımcıda hâlâ eski hedefe doğru kaymaya
	## devam etmesine) yol açıyordu - "farklı görünme" hissinin bir parçası.
	## Artık diğer durum yayınlarıyla AYNI desende, anında ve güvenilir bir
	## "death_state" bildirimi de gönderiliyor; periyodik senkron hâlâ
	## yedek/garanti olarak duruyor (is_dead koruması sayesinde iki çağrı da
	## güvenle üst üste binebilir).
	_broadcast_death_state()

	if hit_area:
		hit_area.set_deferred("monitoring", false)
	if body_collision:
		body_collision.set_deferred("disabled", true)

	## Korsan (öldürmede altın şansı) / Necromancer (ruh biriktirme) pasifleri:
	## oyuncuya bu yaratığın öldüğünü bildir - bkz. player.gd on_enemy_killed
	## (on_damage_dealt İLE AYNI desen). Pasifi olmayan
	## karakterlerde no-op.
	## DÜZELTME (multiplayer KRİTİK): die() SADECE host'ta çalışır (bkz. dosya
	## başı host-authoritative notu), bu yüzden get_first_node_in_group
	## ("player") HER ZAMAN host'un KENDİ karakteriydi - Korsan'ı veya
	## Necromancer'ı bir İSTEMCİ oynuyorsa öldürme pasifleri (altın şansı /
	## ruh kazanımı) o istemcide ASLA tetiklenmiyordu, sadece host bizzat o
	## karakterleri oynarken çalışıyordu. Artık gerçek öldüren host DEĞİLSE
	## (bkz. last_attacker_peer_id, take_damage()'da her hasarda güncelleniyor)
	## notify_kill_passive RPC'siyle DOĞRUDAN o istemciye bildiriliyor, orada
	## kendi yetkili Player node'u üzerinde tetikleniyor.
	## DÜZELTME (Büyücü Kız'ın "her öldürdüğü yaratık patlar" pasifi):
	## ölüm konumu (global_position) artık bu RPC'ye üçüncü parametre olarak
	## ekleniyor - eskiden SADECE is_boss_kill taşınıyordu, bu yüzden asıl
	## öldüren bir İSTEMCİYSE (host değilse) patlamanın nereye
	## konumlandırılacağı hiç bilinemiyordu (bkz. player.gd
	## on_enemy_killed_remote/_buyucu_on_kill).
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "birisi bianda çok fazla yaratık öldürünce oyun laglanıyor" araştırması
	## sırasında bulundu): die() İSTEMCİDE de çalışıyor (death_state RPC'si / periyodik net_dead, bkz.
	## update_network_state) ama bu blok host kapısı olmadan ÖNCEKİ yorumun "SADECE host'ta çalışır" varsayımıyla
	## yazılmıştı. İstemcide last_attacker_peer_id kendi id'si ya da henüz 0 ise on_enemy_killed() yerel olarak
	## BİR KEZ DAHA tetikleniyordu (host'un notify_kill_passive'ine EK olarak - Savaş Şevki yükü, Vampir Dişi
	## iyileşmesi, Büyücü'nün öldürme patlaması, Necromancer ruhu çift sayılıyordu; üstelik host'un öldürdüğü
	## yaratıklar bile istemciye "senin öldürmen" sayılıyordu); başkasının id'siyse o peer'e fazladan bir
	## notify_kill_passive gönderiyordu. Toplu ölümde her istemci ölen HER yaratık için bunu yapıyordu (Büyücü'de
	## her biri yeni bir alan hasarı = yeni RPC seli). Öldürme ödülü tek kaynaktan, host'tan dağıtılır.
	var is_boss_kill: bool = is_boss
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		pass
	elif NetworkManager.is_multiplayer_active and last_attacker_peer_id > 0 and last_attacker_peer_id != multiplayer.get_unique_id():
		NetworkManager.notify_kill_passive.rpc_id(last_attacker_peer_id, is_boss_kill, global_position)
	else:
		var killer_player := get_tree().get_first_node_in_group("player")
		if killer_player and killer_player.has_method("on_enemy_killed"):
			killer_player.on_enemy_killed(self)

	## Efsun ölüm yayılımları (Salgın, Enfeksiyon, Şimşek Çekici...) - durumlar host'ta tutulduğu için sadece host/tek oyunculu.
	## (Boss ölümü artık doğrudan efsun hakkı vermez - garanti düşen ELİT sandık herkese efsun verir, bkz. _drop_chest.)
	if not NetworkManager.is_multiplayer_active or NetworkManager.is_host:
		_on_death_elements()

	_drop_xp()
	_drop_gold()
	_drop_food()
	_drop_magnet()
	_drop_chest()
	_enter_state(State.DEATH)

	var death_time: float = _anim_length_for(State.DEATH)
	if death_time <= 0.0:
		death_time = 0.4
	## DÜZELTME (kullanıcı bildirimi: "biri anlık herkese alan hasarı veren bir
	## skill kullandığında oyun drop yiyor" - ölçülüp doğrulandı, headless
	## harness'te AoE sonrası 45 aynı-tür yaratık TAM AYNI karede _on_death_
	## anim_done'a giriyordu, 39.5ms'lik normal kareyi ~135ms'ye çıkarıyordu).
	## death_time aynı türdeki her yaratık için DETERMİNİSTİK/ÖZDEŞ (sadece
	## dokudan hesaplanıyor) - AoE ile aynı karede ölen onlarca yaratık bu
	## yüzden hepsi TAM AYNI karede tween+queue_free() tetikliyordu. _route_
	## line_timer/_route_replan_timer'daki AYNI desen (randf_range ile faz
	## kaydırma, bkz. _route_direction) - küçük bir rastgele gecikme
	## eşzamanlılığı kırar, tek bir yaratıkta gözle fark edilmez.
	death_time += randf_range(0.0, 0.15)
	get_tree().create_timer(death_time).timeout.connect(_on_death_anim_done)


func _on_death_anim_done() -> void:
	if not is_instance_valid(self):
		return
	var target: CanvasItem = null
	if anim_sprite:
		target = anim_sprite
	else:
		target = frame_sprite
	if target:
		var tw := create_tween()
		tw.tween_property(target, "modulate:a", 0.0, 0.25)
		tw.tween_callback(_free_when_drops_done)
	else:
		_free_when_drops_done()


## bkz. _queue_drop_spawn üstündeki DÜZELTME notu - kuyrukta bu yaratığa ait
## düşürme bekliyorsa (kapanışlar ona bağlı) silinmeyi kısa aralıklarla ertele.
var _pending_queued_spawns: int = 0

func _free_when_drops_done() -> void:
	if _pending_queued_spawns > 0:
		visible = false
		get_tree().create_timer(0.1).timeout.connect(_free_when_drops_done)
		return
	queue_free()


## Kullanıcı isteği: "5 adet orb ... her orbun kendi tierı var ve yaratıklar
## güçlendikçe daha üst tier orblar düşürecekler. 10 yaratık tierı ve 5 orb
## tierı var ona göre dengele" - _get_chest_tier_from_enemy_tier() (bkz. aşağı)
## ile AYNI 2'şerlik merdiven (Kademe 1-10, 5 basamak), tek fark chest'in
## ayrı bir "11+" basamağı varken (0-5, 6 basamak) burada sadece 5 orb tier'ı
## olduğu için en üst iki basamak (9-10 VE 11+) TEK tier'a (5=kırmızı) birleşti.
##
## DÜZELTME (kullanıcı isteği: "sonraki tierlarda ille üst seviye orbların
## çıkması şart değil bazen aynı değerde düşük seviye orb da düşebilsin yoksa
## hep aynı renkler düşüyor") - bu artık kesin sonucu DEĞİL, o Kademe'nin
## ulaşabileceği EN YÜKSEK tier'ı (bir tavan) veriyor. Gerçek düşen tier
## _roll_orb_tier() tarafından bu tavana kadar (1..tavan) ağırlıklı rastgele
## seçiliyor - tavanın ÜSTÜNE asla çıkmaz (zayıf bir yaratık şansla OP bir
## orb vermesin), ama tavanın ALTINDAKİ tier'ler de düzenli aralıklarla
## çıkabilir, böylece aynı Kademe aralığında hep aynı renk düşmez.
func _max_orb_tier_for_enemy_tier() -> int:
	if _current_tier <= 2:
		return 1
	elif _current_tier <= 4:
		return 2
	elif _current_tier <= 6:
		return 3
	elif _current_tier <= 8:
		return 4
	else:
		return 5


## Her basamak bir üstünün ~%35'i kadar olası (geometrik azalan ağırlık) -
## ör. tavan=5 (Kademe 9+) için: %65 kırmızı, %23 sarı, %8 mor, %3 mavi,
## %1 yeşil gibi bir dağılım - en olası SONUÇ hâlâ o Kademe'nin "beklenen"
## tier'ı ama garanti değil.
const ORB_TIER_FALLOFF := 0.35

func _roll_orb_tier() -> int:
	var max_tier: int = _max_orb_tier_for_enemy_tier()
	if max_tier <= 1:
		return 1
	var weights: Array[float] = []
	var total: float = 0.0
	for t in range(1, max_tier + 1):
		var w: float = pow(ORB_TIER_FALLOFF, max_tier - t)
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if roll <= acc:
			return i + 1
	return max_tier


## Kullanıcı isteği: "Yüksek tierdaki exp orbların verdiği exp oranını %100
## arttır. her tier (1. tier hariç) %100 daha fazla exp versin." - tier
## eskiden SADECE görsel/renk seçiyordu (bkz. xp_orb.gd xp_tier üstündeki
## yorum - "hangi GÖRSEL/renk kullanılacağını belirler"), gerçek xp
## değerine hiç etkisi yoktu (her orb, tier'ı ne olursa olsun, aynı
## per_orb payını alıyordu). Artık 2-5. tier'ler taban payın İKİ KATI xp
## veriyor, 1. tier (en düşük/en olası renk) DEĞİŞMEDİ.
const ORB_TIER_XP_MULT := {1: 1.0, 2: 2.0, 3: 2.0, 4: 2.0, 5: 2.0}

## PERF DÜZELTMESİ (kullanıcı bildirimi: "20-30 yaratık aynı anda öldüğünde
## oyun anlık donuyor") - kök neden: her ölüm _drop_xp/_drop_gold/_drop_food/
## _drop_magnet/_drop_chest üzerinden instantiate()+add_child ile YENİ bir
## fizik gövdeli node yaratıyordu; aynı karede 20-30 yaratık birden ölünce
## (ör. kümelenmiş bir sürüyü tek bir AOE/zincir saldırı aynı anda vurunca,
## bkz. kullanıcının paylaştığı ekran görüntüsü) 30-60+ node aynı karede
## sahneye ekleniyor, bu da tek karelik bir donmaya yol açıyordu.
## Artık ölüm anında SADECE değerler (tier/miktar/konum, hepsi ucuz) hemen
## hesaplanıp bir kuyruğa ekleniyor - gerçek instantiate()/add_child işi
## enemy_spawner.gd _process()'te kare başına DROP_SPAWN_PER_FRAME ile
## sınırlı şekilde kuyruktan çekiliyor (bkz. drain_drop_spawn_queue). 30
## ölümlük bir patlama artık birkaç kareye yayılıyor (gözle fark edilmeyen
## bir gecikme), tek karelik donma kalkıyor. Kuyruk static olduğu için TÜM
## Enemy örnekleri paylaşıyor; enemy_spawner.gd sahnede hep var olan bir
## node olduğu için (spawn döngüsünü o yönetiyor), son yaratık ölse bile
## kuyruk asla tıkanmaz - drenaj enemy.gd'nin kendi _process'ine değil,
## enemy_spawner.gd'ye bağlı.
##
## Kuyruğa eklenen callable'lar `self`'e (ölen yaratığa) HİÇ bağımlı değil -
## sadece değer türünde yakalanmış lokal değişkenler (drop_pos, tier, vs.)
## ve önceden yakalanmış `scene_root` referansı kullanıyor. Bu YÜZDEN
## callable, ölen yaratık node'u kuyruk boşalana kadar zaten (~0.65sn sonra,
## bkz. die()/_on_death_anim_done) queue_free() ile silinmiş olsa BİLE
## güvenle çalışır.
static var _drop_spawn_queue: Array[Callable] = []
const DROP_SPAWN_PER_FRAME := 8

## DÜZELTME (200 yaratıkla toplu ölümde bulundu - test "call on a null instance"
## hatası yakaladı): bu kapanışlar _drop_* instance metodlarında oluşturulduğu
## için GDScript onları yaratığa BAĞLIYOR - sadece değer yakalasalar bile yaratık
## kuyruk boşalmadan silinirse çağrı patlıyor ve o XP/altın/yemek HİÇ düşmüyordu
## (200 yaratıklık bir alan hasarı kuyruğa yüzlerce kapanış ekler). Artık her
## yaratık kuyrukta bekleyen kendi ödül sayısını tutuyor (_pending_queued_spawns)
## ve ölüm animasyonu bitince sayı sıfırlanana kadar (görünmez hâlde) silinmeyi
## erteliyor - bkz. _free_when_drops_done.
static func _queue_drop_spawn(spawn_cb: Callable) -> void:
	var owner_obj: Object = spawn_cb.get_object()
	if owner_obj is Enemy:
		(owner_obj as Enemy)._pending_queued_spawns += 1
	_drop_spawn_queue.append(spawn_cb)

static func drain_drop_spawn_queue() -> void:
	var drained: int = 0
	while drained < DROP_SPAWN_PER_FRAME and not _drop_spawn_queue.is_empty():
		var cb: Callable = _drop_spawn_queue.pop_front()
		if not cb.is_valid():
			continue
		var owner_obj: Object = cb.get_object()
		cb.call()
		if is_instance_valid(owner_obj) and owner_obj is Enemy:
			(owner_obj as Enemy)._pending_queued_spawns -= 1
		drained += 1


func _drop_xp() -> void:
	## In multiplayer only the host spawns drops; clients see the death
	## animation but don't create duplicate orbs/gold/food on their side.
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var count: int = max(orb_count, 1)
	var per_orb: float = xp_value / float(count)
	## Kullanıcı isteği (2026-09-24 denge turu): ortak takım seviyesinde HER oyuncu her seviyede tam kart/stat alıyor ama
	## havuz TÜM oyuncuların öldürmeleriyle doluyordu - 2 oyuncuda seviyeler ~2.3 kat hızlı geliyordu. Kademe 3+
	## yaratıklarının XP'si oyuncu sayısına bölünür (oyuncu başı seviye hızı tek oyuncuya eşitlenir); Kademe 1-2 aynen.
	if NetworkManager.is_multiplayer_active and _current_tier >= MP_XP_SPLIT_MIN_TIER:
		per_orb /= float(maxi(1, NetworkManager.lobby_players.size()))
	var scene_root: Node = get_tree().current_scene
	for i in range(count):
		## Her orb KENDİ tier'ını ayrı ayrı zar atarak seçiyor (bkz.
		## _roll_orb_tier) - tek bir yaratık aynı anda birden fazla orb
		## düşürdüğünde (orb_count>1) hepsi zorunlu olarak aynı renk olmasın.
		var orb_tier: int = _roll_orb_tier()
		var tiered_value: float = per_orb * float(ORB_TIER_XP_MULT.get(orb_tier, 1.0))
		var drop_pos: Vector2 = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		## _die() genelde bir fizik sorgu taşması (physics query flush)
		## SIRASINDA çağrılıyor (ör. bir Area2D/HitArea çarpışma sinyali
		## içinden) - add_child() SENKRON çağrılırsa orb._ready() ->
		## _setup_visual() içindeki CollisionShape2D değişikliği bu taşma
		## sırasında yasak olduğu için "Can't change this state while
		## flushing queries" hatası verip birkaç saniye sonra oyunu
		## çökertiyordu (bkz. kullanıcı bildirimi: "oyun birden kapandı, 5sn
		## oynadıktan sonra"). call_deferred ile güvenli bir ana ertelenir.
		_queue_drop_spawn(func() -> void:
			var orb = XpOrb.instantiate()
			orb.xp_value = tiered_value
			orb.xp_tier = orb_tier
			orb.global_position = drop_pos
			if NetworkManager.is_multiplayer_active:
				var drop_id: int = NetworkManager._gen_drop_id()
				orb.set_meta("drop_network_id", drop_id)
				## amount alanı burada GERÇEK xp değeri değil, görsel tier (1-5)
				## taşıyor - bkz. network_manager.gd broadcast_drop "xp" dalı.
				## Gerçek değer (tiered_value) ayrıca 5. parametre olarak
				## taşınıyor - bkz. broadcast_drop üstündeki host migrasyonu
				## DÜZELTME notu.
				NetworkManager.broadcast_drop.rpc("xp", orb.global_position, orb_tier, drop_id, tiered_value)
			scene_root.call_deferred("add_child", orb)
		)


## ŞANS - YENİDEN TASARIM (kullanıcı isteği 2026-09-24 denge turu: "şans çok bozuk", "10 şans 2 kat değil 20 şans
## 2 kat yapsın", "öldüren oyuncunun şansı").
## KÖK NEDEN: şans eskiden düşme ihtimaline DÜZ +%0.2/puan ekliyordu; yemek (%0.051) ve mıknatıs (%0.12) tabanları
## defalarca nerf'lenip çok küçüldüğü için tek bir şans puanı yemeği +%390, mıknatısı +%167 arttırıyordu (10 şans =
## 40 kat yemek). Artık ÇARPIMSAL: yemek/mıknatıs/sandık = taban x (1 + %5 x şans) -> 20 şans = 2 kat; altın = taban x
## (1 + %1 x şans) (altın tabanı zaten büyük, %13-%59). Eski düz toplama (_player_luck_drop_bonus/
## LUCK_CHEST_BONUS_PER_POINT) kaldırıldı.
## ÇOK OYUNCULU HATA DÜZELTMESİ: eskiden get_first_node_in_group("player") kullanılıyordu - düşme kararı SADECE host'ta
## verildiği için her zaman HOST'un şansı sayılıyor, diğer oyuncuların şansı boşa gidiyordu. Artık yaratığı öldüren
## oyuncunun (last_attacker_peer_id) şansı - uzak oyuncununki durum kanalından kuklasına senkronlanan değer
## (bkz. main.gd extra dict "luck", remote_player.gd luck).
const LUCK_DROP_MULT_PER_POINT := 0.05
const LUCK_GOLD_MULT_PER_POINT := 0.01
## bkz. _drop_xp - çok oyunculu XP bölmesi bu Kademe'den itibaren.
const MP_XP_SPLIT_MIN_TIER := 3


## Bu yaratığı öldüren oyuncu: tek oyunculuda / öldüren bu makinenin kendisiyse yerel Player, uzak bir peer ise
## host'taki RemotePlayer kuklası. Bulunamazsa (ör. öldüren oyundan çıktı) yerel oyuncuya düşer.
func _killer_node() -> Node:
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if not NetworkManager.is_multiplayer_active or last_attacker_peer_id <= 0:
		return local_p
	if multiplayer.has_multiplayer_peer() and last_attacker_peer_id == multiplayer.get_unique_id():
		return local_p
	for rp in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and "peer_id" in rp and int(rp.peer_id) == last_attacker_peer_id:
			return rp
	return local_p


func _killer_stat(stat_name: String) -> float:
	var killer: Node = _killer_node()
	if killer and is_instance_valid(killer) and stat_name in killer:
		return float(killer.get(stat_name))
	return 0.0


func _luck_mult(per_point: float) -> float:
	return 1.0 + maxf(0.0, _killer_stat("luck")) * per_point


## NOT: GoldDrop/FoodDrop de (XpOrb gibi) Area2D+CollisionShape2D kökenli -
## bunları bir fizik sorgu taşması (physics query flush) SIRASINDA (ör.
## enemy._die() genelde bir çarpışma/hasar akışının içinden çağrılıyor)
## add_child ile SENKRON eklemek "Can't change this state while flushing
## queries" hatası verip oyunu dondurup çökertiyordu (bkz. kullanıcı
## bildirimi: "oyunun ortasında bir anda kod penceresine atıyor... genel bir
## sorun var gibi" - haklıydı, TÜM düşme türlerinde aynı kökten hataydı).
## call_deferred ile hepsi güvenli bir ana ertelenir - bkz. _drop_xp'deki
## birebir aynı düzeltme.
func _drop_gold() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var chance: float = gold_chance * _luck_mult(LUCK_GOLD_MULT_PER_POINT)
	if chance > 0.0 and randf() <= chance:
		var amount: int = randi_range(gold_min, max(gold_min, gold_max))
		var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		var scene_root: Node = get_tree().current_scene
		_queue_drop_spawn(func() -> void:
			var drop = GoldDrop.instantiate()
			drop.amount = amount
			drop.is_boss_gold = is_boss ## boss altını çok oyunculuda eşit paylaşılır (bkz. gold_drop.gd)
			drop.global_position = drop_pos
			if NetworkManager.is_multiplayer_active:
				var drop_id: int = NetworkManager._gen_drop_id()
				drop.set_meta("drop_network_id", drop_id)
				NetworkManager.broadcast_drop.rpc("gold", drop.global_position, drop.amount, drop_id)
			scene_root.call_deferred("add_child", drop)
		)
	_roll_extra_item_gold()


## Şanslı Zar: temel altın düşme şansından TAMAMEN BAĞIMSIZ - "düşmanlar %4
## ihtimalle FAZLADAN 1 altın düşürür" (kullanıcı isteği), yani üsttekinin
## tetiklenip tetiklenmediğine bakılmaksızın ayrıca kendi şansını dener.
## DÜZELTME (2026-09-24 denge turu, şansla birlikte): eskiden host'un kendi Şanslı Zar'ı okunuyordu (bkz. yukarıdaki
## "öldüren oyuncunun şansı" notu) ve çok oyunculuda bu ekstra altın HİÇ yayınlanmıyordu - sadece host'un ekranında
## vardı, bir istemci göremiyor/toplayamıyordu. Artık öldürenin eşyası sayılır ve normal altınla AYNI şekilde yayınlanır.
func _roll_extra_item_gold() -> void:
	var extra_chance: float = _killer_stat("item_extra_gold_chance")
	if extra_chance <= 0.0 or randf() > extra_chance:
		return
	var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var scene_root: Node = get_tree().current_scene
	_queue_drop_spawn(func() -> void:
		var drop = GoldDrop.instantiate()
		drop.amount = 1
		drop.global_position = drop_pos
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = NetworkManager._gen_drop_id()
			drop.set_meta("drop_network_id", drop_id)
			NetworkManager.broadcast_drop.rpc("gold", drop.global_position, drop.amount, drop_id)
		scene_root.call_deferred("add_child", drop)
	)


## Kullanıcı isteği: "Tierlara göre yemek düşme şansını azaltarak ilerle" -
## _roll_orb_tier() ile AYNI geometrik azalan ağırlık deseni (bkz. yukarıda
## ORB_TIER_FALLOFF): her tier bir alttakinin %85'i kadar olası (kullanıcı
## isteği: "...%85 şans faktörüne göre scale et"). Orb'un aksine burada
## Kademeye göre bir tavan YOK - 5 yemek tier'inin (bkz. food_drop.gd
## FOOD_TIERS) hepsi her zaman mümkün, sadece üst tier'ler (daha çok can
## yeniler) orantılı olarak daha nadir düşer.
const FOOD_TIER_COUNT := 5
const FOOD_TIER_FALLOFF := 0.85

func _roll_food_tier() -> int:
	var weights: Array[float] = []
	var total: float = 0.0
	for t in range(1, FOOD_TIER_COUNT + 1):
		var w: float = pow(FOOD_TIER_FALLOFF, t - 1)
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if roll <= acc:
			return i + 1
	return FOOD_TIER_COUNT


func _drop_food() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var chance: float = food_chance * _luck_mult(LUCK_DROP_MULT_PER_POINT)
	if chance <= 0.0 or randf() > chance:
		return
	var food_tier: int = _roll_food_tier()
	var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var scene_root: Node = get_tree().current_scene
	_queue_drop_spawn(func() -> void:
		var drop = FoodDrop.instantiate()
		drop.tier = food_tier
		drop.global_position = drop_pos
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = NetworkManager._gen_drop_id()
			drop.set_meta("drop_network_id", drop_id)
			## amount alanı burada GERÇEK bir heal miktarı değil, görsel/heal
			## tier numarası (1-5) taşıyor - bkz. network_manager.gd
			## broadcast_drop "food" dalı ve xp_orb.gd'deki AYNI desen.
			NetworkManager.broadcast_drop.rpc("food", drop.global_position, food_tier, drop_id)
		scene_root.call_deferred("add_child", drop)
	)


## bkz. MagnetDrop sabiti üstündeki BUG DÜZELTMESİ notu - _drop_food() ile
## BİREBİR AYNI desen (tier'ı yok, "amount" alanı magnet_drop.gd'de hiç
## kullanılmadığı için 0 gönderiliyor).
func _drop_magnet() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var chance: float = magnet_chance * _luck_mult(LUCK_DROP_MULT_PER_POINT)
	if chance <= 0.0 or randf() > chance:
		return
	var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var scene_root: Node = get_tree().current_scene
	_queue_drop_spawn(func() -> void:
		var drop = MagnetDrop.instantiate()
		drop.global_position = drop_pos
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = NetworkManager._gen_drop_id()
			drop.set_meta("drop_network_id", drop_id)
			NetworkManager.broadcast_drop.rpc("magnet", drop.global_position, 0, drop_id)
		scene_root.call_deferred("add_child", drop)
	)


## DÜZELTME (kullanıcı isteği: "sandık düşme oranını ... azalt") - normal
## yaratıkların temel ihtimal merdiveni ~%40 azaltıldı. CHEST_DROP_RATE_MULT
## tek bir yerden ayarlanabilsin diye ayrı bir çarpan olarak tutuluyor.
## DÜZELTME (kullanıcı isteği: "bosslar öldürmek ödüllendirici değil,
## düşürdüğü kaynaklar artmalı") - bosslardan sandık düşme oranı bu
## çarpandan MUAF tutulup tekrar GARANTİ (%100) yapıldı (bkz. _drop_chest);
## bu çarpan artık SADECE normal (boss olmayan) yaratıkları etkiliyor.
## DÜZELTME (kullanıcı isteği: "çok fazla sandık düşüyor, şuanki düşme
## ihtimalini %80 azalt") - 0.6 -> 0.12 (×0.2). Boss'ların GARANTİ (%100)
## sandık düşürmesi bilinçli olarak bu çarpandan MUAF kalmaya devam ediyor
## (yukarıdaki not), o yüzden bu değişiklik SADECE normal yaratıkları
## etkiliyor.
## DÜZELTME (kullanıcı bildirimi 2026-09-25: "şans kasmadığında ... sandık düşmüyor") - 0.12 de yemekteki gibi toplamalı
## şans döneminde verilmişti; şans 0'da ~25 dk'da ~5 sandık kalıyordu. 0.12 -> 0.25 (x~2): ilk 5 dk'da ~0,75, oyun boyunca
## ~12-14 normal sandık (bosslar/elit sandıklar ayrı, bu çarpandan etkilenmez).
const CHEST_DROP_RATE_MULT := 0.25
## Elit sandık (kullanıcı isteği 2026-09-25: "elitler bosslardan ve güçlü yaratıklardan nadiren düşsün ... bossdan düşen
## sandık garantidir", "güçlü yaratık kademesi yüksek yaratık demek"): boss her zaman 1 ELİT sandık düşürür (eskiden
## normal sandık + herkese efsun hakkı); Kademe >= ELITE_CHEST_MIN_TIER olan sıradan yaratıklarda ayrı, nadir bir elit
## zarı (şansla çarpılır). Normal sandık zarı eskisiyle aynı ("şanslar değişmeyecek").
const ELITE_CHEST_MIN_TIER := 7
const ELITE_CHEST_CHANCE := 0.0006


func _drop_chest() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	if is_boss:
		_spawn_chest_drop(true)
		return
	var base_chance: float = 0.005
	if _current_tier <= 2:
		base_chance = 0.005
	elif _current_tier <= 4:
		base_chance = 0.006
	elif _current_tier <= 6:
		base_chance = 0.007
	elif _current_tier <= 8:
		base_chance = 0.008
	elif _current_tier <= 10:
		base_chance = 0.009
	else:
		base_chance = 0.010

	## Şans artık çarpımsal (bkz. LUCK_DROP_MULT_PER_POINT) - 20 şans = 2 kat sandık.
	var luck: float = _luck_mult(LUCK_DROP_MULT_PER_POINT)
	if randf() <= base_chance * luck * CHEST_DROP_RATE_MULT:
		_spawn_chest_drop(false)
	if _current_tier >= ELITE_CHEST_MIN_TIER and randf() <= ELITE_CHEST_CHANCE * luck:
		_spawn_chest_drop(true)


func _spawn_chest_drop(elite: bool) -> void:
	var chest_tier: int = _get_chest_tier_from_enemy_tier()
	var drop_pos: Vector2 = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	var scene_root: Node = get_tree().current_scene
	_queue_drop_spawn(func() -> void:
		var chest = ChestDropScene.instantiate()
		chest.chest_tier = chest_tier
		chest.is_elite = elite
		chest.global_position = drop_pos
		if NetworkManager.is_multiplayer_active:
			var drop_id: int = NetworkManager._gen_drop_id()
			chest.set_meta("drop_network_id", drop_id)
			NetworkManager.broadcast_drop.rpc("elite_chest" if elite else "chest", chest.global_position, chest.chest_tier, drop_id)
		scene_root.call_deferred("add_child", chest)
	)


func _get_chest_tier_from_enemy_tier() -> int:
	if _current_tier <= 2:
		return 0
	elif _current_tier <= 4:
		return 1
	elif _current_tier <= 6:
		return 2
	elif _current_tier <= 8:
		return 3
	elif _current_tier <= 10:
		return 4
	else:
		return 5


## Hasar sayıları düz beyaz, kritik vuruşlar kolay okunabilen kırmızı - işaret
## (-/+) hiç yazılmıyor (bkz. kullanıcı bildirimi).
const DAMAGE_COLOR := Color(1.0, 1.0, 1.0)
const CRIT_COLOR := Color(1.0, 0.25, 0.2)

func _spawn_floating_text(amount: float, is_crit: bool) -> void:
	var color: Color = CRIT_COLOR if is_crit else DAMAGE_COLOR
	var amt: int = int(round(amount))
	var dn = DamageNumbersScript.get_instance(get_tree())
	if dn == null:
		return
	if _floating_text_id != 0 and dn.is_alive(_floating_text_id):
		_floating_text_total += amt
		dn.update_text(_floating_text_id, "%d" % _floating_text_total, color)
		return
	## DÜZELTME (kullanıcı bildirimi: "alan hasarı alınca FPS 60'tan 40'a düşüyor" -
	## gerçek oyunda 200 yaratıkla ölçüldü): her sayı eskiden ayrı bir floating_text
	## sahnesiydi (6 node + 2 Tween); 200 yaratığa vuran bir alan hasarından sonra
	## ~35 kare 20ms'yi aşıyordu, sayılar kapatılınca bu ~1'e iniyordu. Önce oluşturma
	## kuyruğa alınmıştı, yetmedi - asıl maliyet 1000 Label'ın yaşaması/çizilmesiydi.
	## Artık tüm yaratık hasar sayıları TEK bir DamageNumbers düğümünde kayıt olarak
	## tutulup tek _draw'da çiziliyor (görünüm floating_text ile aynı). Node
	## oluşturmadığı için fizik sorgu taşması sırasında da güvenle çağrılabilir.
	_floating_text_total = amt
	_floating_text_id = dn.spawn(self, Vector2(0, -30), "%d" % amt, color)
