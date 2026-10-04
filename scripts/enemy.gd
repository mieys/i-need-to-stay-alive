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
## EnemyWorld yolunda zamanlayıcı C++'ta (enemy_abilities.gd lazer onu dışarıdan erteliyor) - özellik oraya yönlendirir.
var _ranged_timer: float = 0.0:
	get:
		return _ew_world.get_ranged_timer(_ew_slot) if _ew_slot >= 0 else _ranged_timer
	set(v):
		_ranged_timer = v
		if _ew_slot >= 0:
			_ew_world.set_ranged_timer(_ew_slot, v)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
			if _ew_slot >= 0 and _ew_puppet:
				_ew_world.set_net_target(_ew_slot, to, Vector2.ZERO)
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


## EnemyWorld yolunda temas zamanlayıcısı C++'ta (enemy_abilities.gd hayalet/vampir dışarıdan yazıyor) - özellik yönlendirir.
var _contact_timer: float = 0.0:
	get:
		return _ew_world.get_contact_timer(_ew_slot) if _ew_slot >= 0 else _contact_timer
	set(v):
		_contact_timer = v
		if _ew_slot >= 0:
			_ew_world.set_contact_timer(_ew_slot, v)
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

## Her vuruş KENDİ hasar sayısını açar (kullanıcı bildirimi 2026-10-01: "hasar
## birikerek değil tek tek görünsün"). Kullanıcı isteği (aynı gün, son hal): "tek bi
## doğrultuda... tamamen rastgele konumlarda çıksın" - her sayı yaratığın üstünde
## DMG_SPAWN_OFFSET çevresinde DMG_SCATTER kutusu içinde RASTGELE bir noktada pop'la
## doğar ve oradan süzülerek yükselir (bkz. damage_numbers.gd RISE notu). Sayılar
## yaratığı takip etmez (itilip sallanan yaratıkla sallanmasın). Aynı anda en fazla
## DMG_MAX_LIVE sayı; dolunca EN ESKİSİ silinir (alan hasarında kayıt sayısı sınırlı).
const DMG_SPAWN_OFFSET := Vector2(0, -32)
const DMG_SCATTER := Vector2(22, 14) ## yarı genişlik / yarı yükseklik (px)
const DMG_MAX_LIVE := 5
var _dmg_ids: Array[int] = [] ## eskiden yeniye

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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	if _ew_slot >= 0:
		_taunt_timer = _ew_world.get_taunt_time(_ew_slot) ## EnemyWorld yolu: süre C++'ta azalıyor
	_taunt_timer = max(_taunt_timer, duration)
	if taunter != null and is_instance_valid(taunter):
		_taunt_target = taunter
	if _ew_slot >= 0:
		_ew_world.set_taunt(_ew_slot, taunter.get_instance_id() if (taunter != null and is_instance_valid(taunter)) else 0, duration)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_scale_body(scale_mult)


## Görseli ve çarpışmayı birlikte büyütür (boss ve elit yaratık - bkz. apply_boss_stats / make_elite).
func _scale_body(scale_mult: float) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if frame_sprite:
		frame_sprite.scale *= scale_mult
	if anim_sprite:
		anim_sprite.scale *= scale_mult
	if body_collision and body_collision.shape:
		var shape = body_collision.shape.duplicate()
		shape.radius *= scale_mult
		body_collision.shape = shape
		_body_radius = shape.radius ## body block mesafesi boyutla senkron kalsın
	if hit_area:
		var hit_collision: CollisionShape2D = hit_area.get_node_or_null("HitCollision")
		if hit_collision and hit_collision.shape:
			var hshape = hit_collision.shape.duplicate()
			hshape.radius *= scale_mult
			hit_collision.shape = hshape


## ELİT YARATIK (kullanıcı isteği 2026-10-02: "oyunda elit sandık düşürecek elit düşmanlar ekleyeceğiz"). Kurallar:
## görünüm AYNI kalır, sadece başının üstünde mor piksel yıldız (elite_star.gd) + ayaklarında aura (elite_aura.gd, kullanıcı
## seçimi "B - Yükselen Kıvılcımlar"); can ve kalkan "%300 daha fazla" (x4);
## hasar +%50 (yetenekler dahil - yaratık yetenekleri hasarını contact_damage/ranged_damage'den türetiyor, bkz.
## enemy_abilities.gd, enemy_*.gd mermi/alanlar); boyut +%50; yürüme %15 yavaş + yürüme animasyonu biraz yavaş ("büyük
## olduğu hissedilsin"); sersemletme/yavaşlatma/sabitlemeye BAĞIŞIK DEĞİL (is_boss'a bakan hiçbir korumaya girmez);
## ölünce garanti elit sandık (_drop_chest). Hangi yaratığın, ne zaman elit olacağını host seçer (enemy_spawner.gd
## ELİT YARATIK bloğu, kademe başına 1) ve istemcilere _rpc_client_spawn_creature'ın is_elite bayrağıyla bildirir - host
## ve istemci AYNI make_elite()'i çağırır (iki yerde ayrı formül yok, bkz. CLAUDE.md).
const ELITE_DEFENSE_MULT := 4.0
const ELITE_DAMAGE_MULT := 1.5
const ELITE_SCALE_MULT := 1.5
const ELITE_SPEED_MULT := 0.85
const ELITE_WALK_ANIM_MULT := 0.8
const EliteStarScript := preload("res://scripts/elite_star.gd")
## Aura "B - Yükselen Kıvılcımlar" (kullanıcı seçimi 2026-10-02) - bkz. elite_aura.gd.
const EliteAuraScript := preload("res://scripts/elite_aura.gd")
## Yıldızın başın görünen üst kenarından yukarı mesafesi (dünya birimi).
const ELITE_STAR_GAP := 10.0

var is_elite: bool = false
## Yürüme animasyonu kare hızı çarpanı (elitlerde < 1, bkz. _advance_frame_sprite).
var _walk_anim_mult: float = 1.0


## Kademe ölçeklemesi + global güçlendirmeden SONRA çağrılır (enemy_spawner.gd _apply_elite) - çarpanlar nihai değerlere biner.
func make_elite() -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if is_elite or is_boss:
		return
	is_elite = true
	add_to_group("elite_enemies")
	max_health *= ELITE_DEFENSE_MULT
	health = max_health
	if item_shield_max > 0.0:
		item_shield_max *= ELITE_DEFENSE_MULT
		item_shield_hp = item_shield_max
		item_shield_changed.emit(item_shield_hp, item_shield_max)
	contact_damage *= ELITE_DAMAGE_MULT
	if ranged_damage > 0.0:
		ranged_damage *= ELITE_DAMAGE_MULT
	speed *= ELITE_SPEED_MULT
	_walk_anim_mult = ELITE_WALK_ANIM_MULT
	_scale_body(ELITE_SCALE_MULT)
	health_changed.emit(health, max_health)
	var vis: Rect2 = _visual_bounds()
	var aura: Node2D = EliteAuraScript.new()
	aura.name = "EliteAura"
	add_child(aura)
	## Ayak (gölge) merkezi: görselin alt kenarından ~3 yaratık texel'i yukarı (sayfalarda gömülü gölgenin ortası).
	var texel: float = absf(frame_sprite.scale.y) if frame_sprite else 1.0
	aura.setup(self, Vector2(vis.get_center().x, vis.end.y - 3.0 * texel), vis.size.x)
	var star: Node2D = EliteStarScript.new()
	star.name = "EliteStar"
	star.set("base_y", vis.position.y - ELITE_STAR_GAP)
	add_child(star)


static var _visual_bounds_cache: Dictionary = {} ## doku yolu|hücre -> hücre içindeki dolu dikdörtgen (px, tüm kareler)


## Yaratık görselinin (yürüme sayfası, tüm kareler/yönler) dolu piksellerini saran dikdörtgen, kök koordinatında - yıldız
## kafanın hemen üstüne, aura ayağa otursun (sayfa hücreleri yaratıktan çok büyük olabiliyor, hücre kenarı kullanılamaz).
func _visual_bounds() -> Rect2:
	var fallback := Rect2(-20.0, get_overhead_bar_offset(), 40.0, -get_overhead_bar_offset())
	if frame_sprite == null:
		return fallback
	var tex: Texture2D = walk_texture if walk_texture else frame_sprite.texture
	if tex == null:
		return fallback
	var key: String = "%s|%d" % [tex.resource_path if tex.resource_path != "" else str(tex.get_rid()), cell_size]
	var used_px: Rect2i
	if _visual_bounds_cache.has(key):
		used_px = _visual_bounds_cache[key]
	else:
		var img: Image = tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var size_i: Vector2i = img.get_size()
			for r in range(maxi(1, size_i.y / cell_size)):
				for c in range(maxi(1, size_i.x / cell_size)):
					var cell := Rect2i(c * cell_size, r * cell_size, cell_size, cell_size).intersection(Rect2i(Vector2i.ZERO, size_i))
					var used: Rect2i = img.get_region(cell).get_used_rect()
					if used.size.x > 0:
						used_px = used if used_px.size.x == 0 else used_px.merge(used)
		_visual_bounds_cache[key] = used_px
	if used_px.size.x == 0:
		return fallback
	var half: Vector2 = Vector2(cell_size, cell_size) * 0.5 if frame_sprite.centered else Vector2.ZERO
	var local := Rect2(frame_sprite.offset + Vector2(used_px.position) - half, Vector2(used_px.size))
	var sc: Vector2 = frame_sprite.scale
	return Rect2(frame_sprite.position + local.position * sc, local.size * sc)


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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
var _shield_break_pct: float = 0.0 ## Arrow Rain Finali: süreli kalkan koruması düşüşü (bkz. "shield_break")
var _shield_break_until_msec: int = 0
var _vuln_until_msec: int = 0
var _contagious_timer: float = 0.0
var _linger_slow: float = 0.0 ## Ebedi Kış: donma bitince yavaşlama


func apply_element(kind: String, p: Dictionary) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
		## Efsun Arrow Rain Finali (2026-09-30, "zırhı %30 kırılır" = kalkan): süreli olarak TÜM kaynaklardan gelen isabetlerde
		## kalkan koruması bu oran kadar düşer (bkz. _apply_damage effective_protection).
		"shield_break":
			_shield_break_pct = maxf(_shield_break_pct if Time.get_ticks_msec() < _shield_break_until_msec else 0.0, float(p.get("pct", 0.3)))
			_shield_break_until_msec = Time.get_ticks_msec() + int(float(p.get("dur", 1.0)) * 1000.0)
		## Yetenek evrimi (2026-09-28) Korsan "Ganimet": bu kısa süre içinde ölürse bayrağı bırakan oyuncuya 1 altın (bkz.
		## _on_death_enchant_flags, korsan_bomb.gd - istemcide bayrak hasar RPC'sinden ÖNCE aynı güvenilir kanaldan gelir).
		"evo_gold":
			_enchant_flags["evo_gold"] = {"peer": attacker_peer, "until": Time.get_ticks_msec() + int(float(p.get("dur", 0.6)) * 1000.0)}
		## Yetenek evrimi (2026-09-30) Assasin "Av Zinciri": bu kısa süre içinde ölürse bayrağı bırakan oyuncuya p.event olayı
		## (player.gd on_enchant_event "assasin_dash_kill" - Şahin Hamlesi yükünün bekleme süresi kısalır). evo_gold ile aynı yol.
		"evo_kill":
			_enchant_flags["evo_kill"] = {"peer": attacker_peer, "event": str(p.get("event", "")),
				"until": Time.get_ticks_msec() + int(float(p.get("dur", 0.6)) * 1000.0)}
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
		## Büyücü Kız Don Nova (2026-10-04): %80'e kadar yavaşlatma + buz görünümü (bkz. _apply_frost_slow_host).
		"frost_slow":
			_apply_frost_slow_host(float(p.get("pct", FROST_SLOW_MAX)), float(p.get("dur", 6.0)))
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if seconds <= 0.0:
		return
	for i in range(_poison_stack_time.size()):
		_poison_stack_time[i] += seconds


func _apply_burn_stack(tick: float, duration: float, max_stacks: int) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	if f.has("evo_gold") and Time.get_ticks_msec() <= int(f["evo_gold"]["until"]):
		_notify_enchant_owner(int(f["evo_gold"]["peer"]), "gold", {"amount": 1})
		EnchantFxScript.play(tree, "text", pos, {"text": "+1", "color": Color("#ffd24a")})
	if f.has("evo_kill") and Time.get_ticks_msec() <= int(f["evo_kill"]["until"]) and str(f["evo_kill"]["event"]) != "":
		_notify_enchant_owner(int(f["evo_kill"]["peer"]), str(f["evo_kill"]["event"]), {})
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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


## Kitelama Seti pasifi - bkz. yukarıdaki _slow_percent/_slow_timer yorumu.
## percent: 0.05 = %5 hız azaltma. duration: etkinin süresi (sn).
## allow_boss: normalde bosslar yavaşlatmaya bağışıktır (aşağıdaki "is_boss"
## kontrolü) - Oakley'in Sarmaşıklar yeteneği (bkz. oakley_vine.gd,
## kullanıcı isteği: "bossları yere sabitleyemez ama %30 yavaşlatır") bu
## TEK istisna için true geçiyor, diğer TÜM çağıranlar (Kitelama Seti vb.)
## varsayılan false ile eski davranışı aynen koruyor.
func apply_slow(percent: float, duration: float, allow_boss: bool = false) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	if chill_stacks > 0:
		return CHILL_TINT_COLOR
	return FROST_SLOW_TINT_COLOR if _frost_chill_active() else Color(1.0, 1.0, 1.0, 1.0)


## ---------- Büyücü Kız "Don Nova" buz yavaşlatması (kullanıcı isteği 2026-10-04) ----------
## "büyücü kızın don novası artık düşmanları dondurmak yerine 6 saniyeliğine %80 yavaşlatıyor çünkü donma olayı geliştirmelere
## eklenecek" (R finali "Ateş ve Buz" ilk 3 sn dondurur - player.gd). apply_slow'un %75 tavanı eşya yığılması (Kitelama Seti) için;
## bu yetenek kendi oranını taşır (FROST_SLOW_MAX). Bosslar diğer yavaşlatmalardaki gibi bağışık (eski donma da işlemiyordu).
## Görsel (kullanıcı: "yavaşlatma için yaratıkların hafif mavimsi ve donuyormuş gibi görünmesi"): gövde buz mavisi ton
## (_status_tint_color) + gövdede buz kristalleri / ayakta kırağı (fx_frost_chill_status.gd, sayfa tools/gen_evolution_fx.py
## frost_chill). Host karar verir, istemcilere broadcast_enemy_vfx "frost_slow_start" (duration) - görselin ömrünü efekt kendisi
## sayar (istemci kuklası GDScript tikinde durum sayacı işlemez), bitince _on_frost_chill_fx_finished tonu geri alır.
const FROST_SLOW_MAX := 0.8
const FROST_SLOW_TINT_COLOR := Color(0.74, 0.88, 1.08, 1.0)
const FROST_CHILL_FX_PATH := "res://scenes/fx_frost_chill_status.tscn"
static var _frost_chill_scene: PackedScene = null
var _frost_chill_fx: Node2D = null


func apply_frost_slow(percent: float, duration: float) -> void:
	apply_element("frost_slow", {"pct": percent, "dur": duration})


func _apply_frost_slow_host(percent: float, duration: float) -> void:
	if is_dead or is_boss or percent <= 0.0 or duration <= 0.0:
		return
	_slow_percent = maxf(_slow_percent, minf(percent, FROST_SLOW_MAX))
	_slow_timer = maxf(_slow_timer, duration)
	_spawn_frost_chill_fx(duration)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "frost_slow_start", {"duration": duration})


func _frost_chill_active() -> bool:
	return _frost_chill_fx != null and is_instance_valid(_frost_chill_fx) and not _frost_chill_fx.is_queued_for_deletion()


## Yerel (host) ve ağdan gelen ("frost_slow_start") ortak giriş - zaten varsa süresi tazelenir.
func _spawn_frost_chill_fx(duration: float) -> void:
	if is_dead:
		return
	if _frost_chill_active():
		_frost_chill_fx.call("refresh", duration)
	else:
		if _frost_chill_scene == null and ResourceLoader.exists(FROST_CHILL_FX_PATH):
			_frost_chill_scene = load(FROST_CHILL_FX_PATH) as PackedScene
		if _frost_chill_scene == null:
			_frost_chill_fx = null
		else:
			_frost_chill_fx = _frost_chill_scene.instantiate() as Node2D
			add_child(_frost_chill_fx)
			_frost_chill_fx.call("setup", duration, _body_radius)
	_refresh_chill_tint()


## fx_frost_chill_status.gd kendi süresi bitince çağırır.
func _on_frost_chill_fx_finished() -> void:
	_frost_chill_fx = null
	_refresh_chill_tint()


func _remove_frost_chill_fx() -> void:
	if _frost_chill_active():
		_frost_chill_fx.queue_free()
	_frost_chill_fx = null
	_refresh_chill_tint()


## Rage modu tek seferlik bir anahtar - geri kapanmaz (ölene kadar sürer).
## Ton, _refresh_chill_tint (aslında genel "durum tonu" yenileyicisi) ile
## uygulanıyor, chill ile aynı boru hattı.
func _enter_rage_mode() -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
## allow_boss: Zaman Kıran (eşya) bossları da dondurur - diğer donduranlar bossa işlemez.
func apply_freeze_full(duration: float, allow_boss: bool = false) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if is_dead or (is_boss and not allow_boss):
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "freeze", duration, 1.0 if allow_boss else 0.0, 0.0)
		return
	_start_freeze(max(duration, _freeze_timer if is_frozen else 0.0))


func _start_freeze(duration: float = FREEZE_DURATION) -> void:
	## Efsun tepkimeleri (bkz. _legacy_element_touched): donma, uygulanmadan önceki yanma/zehir/kanama/şokla tepkimeye girer.
	var had_elements: Dictionary = {} if (_in_element_apply or (is_frozen and not is_stunned)) else _element_snapshot()
	_start_freeze_inner(duration)
	_legacy_element_touched("donma", had_elements)


func _start_freeze_inner(duration: float) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
## EnemyWorld yolunda "yeniden düşün" C++'a gider (vampir ışınlanması sonrası, enemy_abilities.gd).
var _ai_has_decision: bool = false:
	set(v):
		_ai_has_decision = v
		if not v and _ew_slot >= 0:
			_ew_world.force_think(_ew_slot)

## Necromancer yaratıklarının (player_allies) agro önceliği - bkz. _find_closest_target_player.
const ALLY_AGGRO_RADIUS := 160.0
const ALLY_AGGRO_BIAS := 0.35


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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	if _ew_slot >= 0:
		_ew_world.set_fear_source(_ew_slot, source_pos)
	_set_fear_visual(true, _fear_timer, not was_feared)


## Necromancer ULTİ (Lanetli Kafatası) korkusu: yaratık kaynaktan kaçmak yerine RASTGELE yönlerde yürür (her 0.45-1sn'de bir
## yön değiştirir, engellerden kayar) ve hasar veremez. affect_boss=false iken bosslar, Melek korkusundaki AYNI kuralla
## (bosslar korkmaz) muaf kalır - bkz. necro_skull.gd FEAR_AFFECTS_BOSSES. apply_fear ile AYNI host-yönlendirme deseni
## (network_manager.gd request_enemy_effect "fear_wander": param1=süre, param2=boss dahil mi).
func apply_fear_wander(duration: float, affect_boss: bool = false) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_set_fear_visual(true, _fear_timer, not was_feared)


func _process_fear(delta: float) -> void:
	if not is_feared:
		return
	_fear_timer -= delta
	if _fear_timer <= 0.0:
		is_feared = false
		_fear_wander = false
		_set_fear_visual(false)


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


## weapon.gd/projectile.gd tarafından çağrılır - dir yönünde force kadar bir
## itiş hızı ekler (üst üste birikebilir, ama toplam KNOCKBACK_MAX_SPEED'i
## aşamaz).
## BUG DÜZELTMESİ (çok oyunculu senkron denetimi 2026-09-25): bu fonksiyon apply_knockback_distance'ın aksine istemciden
## host'a HİÇ iletilmiyordu - istemcideki yaratık sadece host'un konum yayınını izleyen bir kukla olduğu için host olmayan
## oyuncunun itişleri tamamen kayboluyordu: sprey eşyası (_do_repel), Şovalye baloncuğunun kırılma itişi, Matthew kalkan
## patlamasının itişi ve oyuncunun gövdesiyle yaratık itmesi / sıkışınca kurtulma itişi (player.gd _block_movement_into_
## enemies - istemci kalabalığın ortasında kalınca hiçbir yöne gidemiyordu). Artık istemcide birikip host'a gider.
## Gövde itişi HER KAREDE geldiği için yaratık başına en fazla KNOCKBACK_FORCE_RPC_INTERVAL_MSEC'te bir, o ana kadar
## biriken toplam itiş olarak gönderilir.
const KNOCKBACK_FORCE_RPC_INTERVAL_MSEC := 100
var _pending_net_force: Vector2 = Vector2.ZERO
var _last_net_force_msec: int = -100000

func apply_knockback_force(dir: Vector2, force: float) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if force <= 0.0:
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id <= 0:
			return
		var now_msec: int = Time.get_ticks_msec()
		if now_msec - _last_net_force_msec > KNOCKBACK_FORCE_RPC_INTERVAL_MSEC * 3:
			_pending_net_force = Vector2.ZERO ## eski, gönderilmemiş kırıntı birikmesin
		_pending_net_force += d * force
		if now_msec - _last_net_force_msec >= KNOCKBACK_FORCE_RPC_INTERVAL_MSEC:
			_last_net_force_msec = now_msec
			var total: Vector2 = _pending_net_force
			_pending_net_force = Vector2.ZERO
			if total.length() > 0.001:
				NetworkManager.request_enemy_knockback_force.rpc_id(NetworkManager._host_peer_id(), net_id, total.normalized(), total.length())
		return
	if _ew_slot >= 0: ## EnemyWorld yolu: aynı formül C++'ta (enemy_world.cpp apply_knockback_force)
		_ew_world.apply_knockback_force(_ew_slot, d, force)
		return
	_knockback_velocity += d * force
	if _knockback_velocity.length() > KNOCKBACK_MAX_SPEED:
		_knockback_velocity = _knockback_velocity.normalized() * KNOCKBACK_MAX_SPEED


## YETENEK İTMESİ (kullanıcı bildirimi 2026-09-27: "matthewin Q yeteneği yaratıkları matthewdan uzağa itmiyor iyi oranda
## uzağa itmesi gerekiyordu"): apply_knockback_force HIZ alır ve KNOCKBACK_MAX_SPEED (400) ile kırpılır - sönümle (1400
## px/sn²) Q'nun 260'lık itişi ~24 px, tavanda bile en fazla ~57 px kaydırıyordu. Bu fonksiyon MESAFE alır: tam o mesafeyi
## kat edecek başlangıç hızı hesaplanır, tek bir güçlü yetenek itişi tavanı aşabilir (silah/gövde itmeleri değişmedi).
## Bosslar SKILL_PUSH_BOSS_MULT kadar. Çok oyunculuda istemci -> host'taki gerçek yaratık (NetworkManager.request_enemy_skill_push).
const SKILL_PUSH_BOSS_MULT := 0.4

func apply_skill_push(dir: Vector2, distance: float) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if distance <= 0.0 or is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_skill_push.rpc_id(NetworkManager._host_peer_id(), net_id, dir, distance)
		return
	if _ew_slot >= 0: ## EnemyWorld yolu: aynı formül C++'ta (boss x0,4 dahil)
		_ew_push_state() ## boss bayrağı doğumdan hemen sonra henüz yazılmamış olabilir
		_ew_world.apply_skill_push(_ew_slot, dir, distance)
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var dist: float = distance * (SKILL_PUSH_BOSS_MULT if is_boss else 1.0)
	var v0: float = sqrt(2.0 * KNOCKBACK_DECAY * dist)
	## Mevcut itişin bu yöndeki bileşeni sayılır (üst üste binince katlanmasın), dik bileşen korunur.
	var along: float = _knockback_velocity.dot(d)
	_knockback_velocity += d * maxf(v0 - maxf(along, 0.0), 0.0)


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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if distance <= 0.0:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_knockback.rpc_id(NetworkManager._host_peer_id(), net_id, dir, distance)
		return
	if _ew_slot >= 0: ## EnemyWorld yolu: aynı formül + tekrar penceresi C++'ta
		_ew_world.apply_knockback_distance(_ew_slot, dir, distance)
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
	## Yaratık yeniden yazımı: EnemyWorld açıkken C++ kova sorgusu (eski ızgarayı kurmak için her karede tüm grubu
	## taramaya gerek kalmaz) - bkz. enemy_world_bridge.gd enemies_near.
	var ew = EnemyWorldBridgeScript.enemies_near(tree, pos, radius)
	if ew != null:
		return ew
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
	_ew_try_register() ## yaratık yeniden yazımı: anahtar kapalıyken hiçbir şey yapmaz


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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if not is_boss or not _overhead_bar or not is_instance_valid(_overhead_bar):
		return
	_overhead_bar.set_health(health, max_health)
	_overhead_bar.set_shield(item_shield_hp, item_shield_max)
	_overhead_bar.visible = true


## Fizik interpolasyonu: bu adımdan ÖNCEKİ konum - _process'te buna yapışan görseller
## (hasar sayıları, auralar) çizilen konumu bulsun diye (bkz. PhysicsInterp.visual_position).
## EnemyWorld yolunda (aşağıda) her kare yazmak yerine C++'tan okunur (adım öncesi konum orada tutuluyor).
var _interp_prev_pos: Vector2 = Vector2.ZERO:
	get:
		return _ew_world.get_prev_position(_ew_slot) if _ew_slot >= 0 else _interp_prev_pos
var _interp_prev_frame: int = -1:
	get:
		return Engine.get_physics_frames() if _ew_slot >= 0 else _interp_prev_frame


# =====================================================================================================================
# EnemyWorld yolu (yaratık yeniden yazımı, docs/yaratik_yeniden_yazim/PLAN.md §4.1). SADECE EnemyWorldConfig.enabled()
# iken ve host / tek oyunculuda: hareket + AI (hedef, rota, itilme, geri itme, korku, tahrik, menzilli zamanlayıcı,
# temas) + yürüme/bekleme animasyonu C++'ta; bu yaratığın _physics_process'i KAPALI. Köprü (enemy_world_bridge.gd)
# olaylarda _ew_on_event / _ew_on_loco'yu, ve SADECE "uyanık" yaratıklarda (bir durum etkisi, saldırı animasyonu,
# vuruş parlaması, yetenek... sürüyorsa) _ew_tick'i çağırır. Yaratığı uyandıran her giriş noktası (apply_*, take_damage,
# _enter_state...) _ew_wake() çağırır; kaçan olursa köprünün seyrek taraması (8 karede bir) yakalar.
# Anahtar kapalıyken _ew_slot hep -1 ve aşağıdakilerin hiçbiri çalışmaz (eski yol aynen).
# =====================================================================================================================
const EnemyWorldConfigScript := preload("res://scripts/enemy_world/enemy_world_config.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")
## C++ EnemyWorld bayrakları / olayları / animasyon durumları (enemy_world.h ile AYNI)
const EW_F_FROZEN := 1 << 1
const EW_F_ROOTED := 1 << 2
const EW_F_ATTACK_LOCK := 1 << 3
const EW_F_ABILITY_LOCK := 1 << 4
const EW_F_RANGED := 1 << 5
const EW_F_BOSS := 1 << 6
const EW_F_GHOST_INVISIBLE := 1 << 7
const EW_F_FEAR_FLEE := 1 << 10
const EW_F_FEAR_WANDER := 1 << 11
const EW_F_UNTARGETABLE := 1 << 12 ## "untargetable" metası (görünmez hayalet) - silah hedeflemesi
const EW_F_PUPPET := 1 << 13 ## istemci kuklası: AI yok, C++ ağ konumunu ölü hesaplamayla izler
const EW_E_MELEE := 0
const EW_E_BARRIER_HIT := 1
const EW_E_GHOST_REVEAL := 2
const EW_E_RANGED_FIRE := 3
const EW_E_HOMING_FIRE := 4
const EW_E_TAUNT_LOST := 5
const EW_E_LOCO := 6
const EW_A_WALK := 0
const EW_A_IDLE := 1
const EW_A_OTHER := 2

var _ew_slot: int = -1
## İstemci (host olmayan) kuklası olarak kayıtlı: C++ sadece ağ konumunu izler (step_puppet), tik = _ew_tick_puppet.
var _ew_puppet: bool = false
var _ew_bridge: Node = null
var _ew_world: Object = null
var _ew_awake: bool = false
var _ew_tick_stamp: int = -1 ## bu fizik karesinde tiklendi mi (aynı karede yeniden uyanınca çift tik olmasın)
## C++'a en son yazılan değerler - sadece değişince yazılır
var _ew_sent_flags: int = -1
var _ew_sent_speed: float = -1.0
var _ew_sent_speed_mult: float = -1.0
var _ew_sent_rage_mult: float = -1.0
var _ew_sent_radius: float = -1.0
var _ew_sent_contact_interval: float = -1.0
var _ew_sent_ranged: Vector3 = Vector3(-1.0, -1.0, -1.0)
var _ew_sent_walk_mult: float = -1.0
var _ew_sent_hit_radius: float = -1.0
var _ew_hit_collision: CollisionShape2D = null


## _ready sonunda: anahtar açık + host/tek oyunculu ise C++'a kaydol ve kendi _physics_process'ini kapat.
## Kaydı olmayan canlı yaratık (host / tek oyunculu): eklenti yoksa ya da sahne kayda hazır değilse hareket etmez - sessizce
## donmasın, bir kez yazsın.
static var _ew_warned_unregistered: bool = false

func _ew_warn_unregistered() -> void:
	if _ew_warned_unregistered:
		return
	_ew_warned_unregistered = true
	push_warning("Yaratık C++ EnemyWorld'e kaydolamadı (eklenti yüklü mü? %s, current_scene: %s) - kayıtsız yaratıklar hareket etmez"
			% [str(ClassDB.class_exists("EnemyWorld")), str(get_tree().current_scene != null if is_inside_tree() else false)])


func _ew_try_register() -> void:
	if _ew_slot >= 0:
		return ## zaten kayıtlı (ör. _ready ikinci kez çağrıldı) - ikinci slot açma
	if not EnemyWorldConfigScript.enabled():
		return
	## İstemcide de kayıt (2026-10-03): kukla modunda - AI host'ta kalır, C++ sadece ağ konumunu izler; böylece istemci de
	## C++ sorgularını / sisi / y-sıralamasını / minimapi kullanır (eskiden her kukla GDScript _physics_process'iydi).
	_ew_puppet = NetworkManager.is_multiplayer_active and not NetworkManager.is_host
	if _ew_puppet and not EnemyWorldConfigScript.puppets_enabled():
		return ## A/B / yedek: istemci eski GDScript kukla dalını kullanır (_physics_process istemci dalı)
	if is_dead or not is_inside_tree():
		return
	_ew_bridge = EnemyWorldBridgeScript.get_or_create(get_tree())
	if _ew_bridge == null:
		return
	_ew_world = _ew_bridge.world
	_ew_hit_collision = hit_area.get_node_or_null("HitCollision") as CollisionShape2D if hit_area else null
	_ew_sent_hit_radius = _ew_hit_radius()
	_ew_slot = _ew_bridge.register(self, frame_sprite, {"hit_radius": _ew_sent_hit_radius,"radius": _body_radius, "speed": speed,
			"contact_interval": contact_interval, "ranged_range": ranged_range,
			"ranged_interval": ranged_attack_interval, "homing_interval": normal_attack_interval,
			"anim_sprite": anim_sprite, "walking": frame_sprite != null,
			"cols": frame_sprite.hframes if frame_sprite else 1, "fps": sprite_fps, "walk_mult": _walk_anim_mult,
			"idle_tex": idle_texture != null, "flags": EW_F_PUPPET if _ew_puppet else 0})
	if _ew_puppet and _network_state_received:
		_ew_world.set_net_target(_ew_slot, _network_target_position, _network_velocity)
	_ew_sent_flags = -1
	_ew_sent_speed = speed
	_ew_sent_radius = _body_radius
	_ew_sent_contact_interval = contact_interval
	_ew_sent_ranged = Vector3(ranged_range, ranged_attack_interval, normal_attack_interval)
	_ew_sent_walk_mult = _walk_anim_mult
	set_physics_process(false)
	## Fizik gövdesi + HitArea KAPALI (PLAN §4.3): mermiler EnemyWorld.query_* ile bulur (enemy_world_hits.gd), HitArea'nın
	## "oyuncu girince temas zamanlayıcısını sıfırla"sı C++'ta (hit_radius). Yaratık-yaratık / yaratık-oyuncu fizik çarpışması
	## zaten yoktu (collision_mask 0). Ölümde die() bunları eskisi gibi zaten kapatıyor.
	if body_collision:
		body_collision.set_deferred("disabled", true)
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	## PERF: şekiller kapalıyken de CollisionObject2D her konum değişiminde fizik sunucusuna dönüşüm yazıyordu (1000
	## yaratıkta ~0,9 ms). Fizik tarafı artık kullanılmadığı için bildirimi kapat (kayıt silinince geri açılır).
	set_notify_transform(false)
	if hit_area:
		hit_area.set_notify_transform(false)
	_ew_awake = false
	_ew_wake() ## ilk tik: yetenek kurulumu + durum bayrakları


## Ölümde / sahneden çıkışta: C++ kaydını sil, eski _physics_process'i geri aç (ölüm animasyonu oradan oynar).
func _ew_unregister() -> void:
	if _ew_slot < 0:
		return
	## Yön ve kare C++'taydı - eski yol kaldığı yerden devam etsin
	_sprite_row = _ew_world.get_facing_row(_ew_slot)
	_flip_h = _ew_world.get_face_left(_ew_slot)
	_interp_prev_pos = global_position
	if _ew_bridge != null and is_instance_valid(_ew_bridge):
		_ew_bridge.unregister(_ew_slot)
	_ew_slot = -1
	_ew_world = null
	_ew_awake = false
	set_notify_transform(true)
	if hit_area:
		hit_area.set_notify_transform(true)
	set_physics_process(true)


func _exit_tree() -> void:
	if _ew_slot >= 0:
		_ew_unregister()


## Bu yaratığın GDScript tikine ihtiyacı var (durum etkisi başladı, hasar aldı, saldırıya geçti...).
func _ew_wake() -> void:
	if _ew_slot >= 0 and not _ew_awake:
		_ew_awake = true
		_ew_bridge.wake(self)


## Uyanık kalması gerekiyor mu? _ew_tick'teki her "aktifse çağır" koşulunun VEYA'sı - birini değiştirirsen burayı da.
func _ew_still_active() -> bool:
	if _ew_puppet:
		return _flash_time_left > 0.0 or mark_stacks > 0 or _state_duration > 0.0 or (_state != State.WALK and _state != State.IDLE)
	return _flash_time_left > 0.0 or is_frozen or is_feared or _abilities != null or not _abilities_checked \
			or ability_move_lock > 0.0 or _state_duration > 0.0 or (_state != State.WALK and _state != State.IDLE) \
			or (_overhead_bar_hide_timer > 0.0 and _overhead_bar != null and not _overhead_bar_always_visible) \
			or (item_shield_max > 0.0 and (item_shield_regen_delay > 0.0 or item_shield_hp < item_shield_max)) \
			or not _poison_stack_time.is_empty() or burn_time_left > 0.0 or mark_stacks > 0 or bleed_stacks > 0 \
			or shock_time_left > 0.0 or _sleep_time > 0.0 or not _plague.is_empty() or not _enchant_flags.is_empty() \
			or chill_stacks > 0 or _boss_chill_stacks > 0 \
			or _slow_timer > 0.0 or _slow_fx_time_left > 0.0 or _slow_fx_broadcast_cooldown > 0.0 \
			or _root_timer > 0.0 or not _bee_poison_stacks.is_empty()


## C++ olayı (köprü çağırır). target = olayın hedef adayı (oyuncu / uzak oyuncu / müttefik / ağaç). Gövdeler
## _physics_process'teki temas / kalkan / menzilli dallarının BİREBİR kopyası; zamanlayıcılar C++'ta.
func _ew_on_event(type: int, target: Node2D) -> void:
	if is_dead:
		return
	match type:
		EW_E_MELEE:
			if target == null:
				return
			if not is_ranged:
				var dur: float = _anim_length_for(State.ATTACK)
				_enter_state(State.ATTACK, dur if dur > 0.0 else 0.35)
				_broadcast_attack_state()
				_schedule_melee_hit(0.0, target)
			elif target.has_method("take_damage"):
				target.take_damage(contact_damage, self)
				var dur2: float = _anim_length_for(State.ATTACK)
				_enter_state(State.ATTACK, dur2 if dur2 > 0.0 else 0.35)
				_broadcast_attack_state()
		EW_E_BARRIER_HIT:
			if target != null and target.has_method("take_paladin_barrier_damage"):
				target.take_paladin_barrier_damage(contact_damage, self)
				var shield_dur: float = _anim_length_for(State.ATTACK)
				_enter_state(State.ATTACK, shield_dur if shield_dur > 0.0 else 0.35)
				_broadcast_attack_state()
		EW_E_GHOST_REVEAL:
			if _abilities != null:
				_abilities.ghost_reveal(true)
		EW_E_RANGED_FIRE:
			if target != null:
				var to_t: Vector2 = target.global_position - global_position
				_fire_ranged_attack(to_t.normalized() if to_t.length() > 0.1 else Vector2.ZERO)
		EW_E_HOMING_FIRE:
			_fire_homing_attack()
		EW_E_TAUNT_LOST:
			_taunt_target = null
			_set_taunt_visual(false)


## C++ yürüme/bekleme geçişi (enemy.gd _update_locomotion_state'in karşılığı C++'ta ölçülüyor).
func _ew_on_loco(new_anim_state: int) -> void:
	if is_dead:
		return
	_enter_state(State.IDLE if new_anim_state == EW_A_IDLE else State.WALK)


## _enter_state'ten: C++'a yeni animasyon durumunu ve doku ızgarasını bildir (WALK/IDLE karesini C++ yazar).
func _ew_anim_state_changed() -> void:
	var s: int = EW_A_WALK if _state == State.WALK else (EW_A_IDLE if _state == State.IDLE else EW_A_OTHER)
	_ew_world.set_anim_state(_ew_slot, s, frame_sprite.hframes if frame_sprite else 1, sprite_fps, _walk_anim_mult,
			idle_texture != null)
	_ew_sent_walk_mult = _walk_anim_mult
	if s == EW_A_OTHER:
		_ew_wake()


## Uyanık yaratıkta her fizik karesi (köprü, C++ adımından SONRA): _physics_process'in hareket/AI/yürüme animasyonu
## dışındaki host işleri - aynı sıra ve aynı "aktif değilse çağırma" korumalarıyla. Bir koşulu orada değiştirirsen
## burada ve _ew_still_active'de de değiştir.
func _ew_tick(delta: float) -> void:
	if _ew_puppet:
		_ew_tick_puppet(delta)
		return
	if _flash_time_left > 0.0:
		_tick_hit_flash(delta)
	if _overhead_bar_hide_timer > 0.0 and _overhead_bar and is_instance_valid(_overhead_bar) and not _overhead_bar_always_visible:
		_overhead_bar_hide_timer -= delta
		if _overhead_bar_hide_timer <= 0.0:
			_overhead_bar.visible = false
	if is_frozen:
		_process_freeze(delta)
	if is_feared:
		_process_fear(delta)
	## Yetenekler: hedef/mesafe C++'ın BU karedeki kararı (korku/donma/dolaşmada null / INF - enemy.gd ile aynı)
	if not _abilities_checked:
		_init_abilities()
	if _abilities != null:
		var player: Node2D = null
		var dist: float = INF
		var ti: int = _ew_world.get_target(_ew_slot)
		if ti >= 0:
			player = _ew_bridge.target_node(ti)
			dist = _ew_world.get_target_dist(_ew_slot)
		if not is_frozen and not is_feared and not is_stunned:
			_abilities.process(delta, player, dist)
		elif is_ability_invisible:
			_abilities.ghost_reveal(false)
	if is_dead or _ew_slot < 0:
		return ## yetenek öldürdü / kaydı sildi
	if ability_move_lock > 0.0:
		ability_move_lock -= delta
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
		_process_enchant_status(delta)
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
	if is_dead or _ew_slot < 0:
		return ## durum etkisi (DOT) öldürdü
	if _state_duration > 0.0:
		_update_state_timer(delta)
	## Saldırı/hasar karesi GDScript'te (WALK/IDLE'ı C++ yazar); yön C++'ın kararı.
	if frame_sprite and _state != State.WALK and _state != State.IDLE:
		_sprite_row = _ew_world.get_facing_row(_ew_slot)
		_advance_frame_sprite(delta)
	## EN SONDA: bu tikte biten saldırı/donma/korku/kilit, uykuya geçmeden önce C++'a yazılsın
	_ew_push_state()
	_ew_awake = _ew_still_active()


## İstemci kuklasının uyanık tiki: eski _physics_process istemci dalının konum/yön/yürüme DIŞINDA kalan işleri (onları
## C++ step_puppet + E_LOCO yapıyor) - vuruş parlaması, işaret görseli, durum süresi (saldırı -> yürüme dönüşü), saldırı/
## hasar karesi. Durum etkileri / yetenekler istemcide işlenmez (host yetkili; eski dal da işlemiyordu).
func _ew_tick_puppet(delta: float) -> void:
	if _flash_time_left > 0.0:
		_tick_hit_flash(delta)
	if mark_stacks > 0:
		_process_mark(delta)
	if is_dead or _ew_slot < 0:
		return
	_update_state_timer(delta)
	if frame_sprite and _state != State.WALK and _state != State.IDLE:
		_sprite_row = _ew_world.get_facing_row(_ew_slot)
		_advance_frame_sprite(delta)
	_ew_push_state()
	_ew_awake = _ew_still_active()

## Hareketi etkileyen GDScript durumunu C++'a yazar (sadece değişeni).
func _ew_push_state() -> void:
	var f: int = 0
	if is_frozen:
		f |= EW_F_FROZEN
	if is_rooted:
		f |= EW_F_ROOTED
	if _state == State.ATTACK:
		f |= EW_F_ATTACK_LOCK
	if ability_move_lock > 0.0:
		f |= EW_F_ABILITY_LOCK
	if is_ranged:
		f |= EW_F_RANGED
	if is_boss:
		f |= EW_F_BOSS
	if is_ability_invisible and _abilities != null:
		f |= EW_F_GHOST_INVISIBLE
	if is_feared:
		f |= EW_F_FEAR_WANDER if _fear_wander else EW_F_FEAR_FLEE
	if is_ability_invisible:
		f |= EW_F_UNTARGETABLE
	if _ew_puppet:
		f |= EW_F_PUPPET
	if f != _ew_sent_flags:
		_ew_sent_flags = f
		_ew_world.set_flags(_ew_slot, f)
	if speed != _ew_sent_speed:
		_ew_sent_speed = speed
		_ew_world.set_speed(_ew_slot, speed)
	var sm: float = maxf(0.0, 1.0 - chill_stacks * 0.20) * maxf(0.0, 1.0 - _slow_percent) ## _chill_speed_mult x _slow_speed_mult
	if sm != _ew_sent_speed_mult:
		_ew_sent_speed_mult = sm
		_ew_world.set_speed_mult(_ew_slot, sm)
	var rm: float = _rage_speed_mult() if is_raging else 1.0
	if rm != _ew_sent_rage_mult:
		_ew_sent_rage_mult = rm
		_ew_world.set_rage_mult(_ew_slot, rm)
	if _body_radius != _ew_sent_radius:
		_ew_sent_radius = _body_radius
		_ew_world.set_radius(_ew_slot, _body_radius)
	if contact_interval != _ew_sent_contact_interval:
		_ew_sent_contact_interval = contact_interval
		_ew_world.set_contact(_ew_slot, contact_interval, 0.0)
	var rv := Vector3(ranged_range, ranged_attack_interval, normal_attack_interval)
	if rv != _ew_sent_ranged:
		_ew_sent_ranged = rv
		_ew_world.set_ranged(_ew_slot, ranged_range, ranged_attack_interval, normal_attack_interval)
	if _walk_anim_mult != _ew_sent_walk_mult:
		_ew_anim_state_changed()
	var hr: float = _ew_hit_radius()
	if hr != _ew_sent_hit_radius:
		_ew_sent_hit_radius = hr
		_ew_world.set_hit_radius(_ew_slot, hr)


## HitArea temas çemberinin dünya yarıçapı (elit/boss büyütmesi _scale_body şekli değiştirir).
func _ew_hit_radius() -> float:
	if _ew_hit_collision == null or not (_ew_hit_collision.shape is CircleShape2D):
		return 0.0
	return (_ew_hit_collision.shape as CircleShape2D).radius * absf(_ew_hit_collision.global_scale.x)


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
		## Yaratık yeniden yazımı (2026-10-03, docs/yaratik_yeniden_yazim/): canlı yaratığın host / tek oyunculu simülasyonu
		## (hedef, yol, itilme, saldırı tespiti, menzilli atış zamanlayıcısı) C++ EnemyWorld'de; durum etkileri / yetenekler
		## _ew_tick'te. Kayıtlı yaratığın bu fonksiyonu KAPALIDIR (die() ölüm animasyonu için geri açar). Buraya canlı bir
		## yaratık ancak kaydı OLMADAN gelir (kayıt anında sahne/eklenti hazır değildi) - her karede yeniden denenir.
		if _ew_slot < 0:
			_ew_try_register()
		if _ew_slot >= 0:
			return
		_ew_warn_unregistered()
	_update_locomotion_state(delta)
	_update_state_timer(delta)

	if frame_sprite:
		_advance_frame_sprite(delta)


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
	if _ew_slot >= 0: ## EnemyWorld yolu: yön C++'ta (kare/flip oradan yazılır) - yetenek nişanı
		_ew_world.set_face(_ew_slot, dir)
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
		if _ew_slot >= 0:
			_ew_anim_state_changed()
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
	if _ew_slot >= 0:
		_ew_anim_state_changed() ## EnemyWorld yolu: WALK/IDLE karesini C++ yazar


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
	_frame_time += delta * sprite_fps * (_walk_anim_mult if _state == State.WALK else 1.0)
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
	## Kukla C++'a kayıtlıysa paketten beri geçen süreyi C++ sayıyor (_physics_process kapalı).
	if _ew_slot >= 0:
		_network_time_since_update = _ew_world.get_net_time(_ew_slot)
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
	if _ew_slot >= 0:
		_ew_world.set_net_target(_ew_slot, net_position, _network_velocity)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	if is_dead or is_ability_invisible:
		return
	if attacker_id > 0:
		last_attacker_peer_id = attacker_id
	amount = _pre_direct_hit(amount)
	_apply_damage(amount, is_crit, shield_pen_percent)
	_post_direct_hit(amount)


## Hasar sayısı: kalkanın emdiği kısım DAHİL tam vuruş (bkz. _apply_damage). Sadece sayıyı gösterir/yayınlar.
func _show_hit_number(shown_amount: float, is_crit: bool) -> void:
	## Kullanıcı isteği (2026-09-25): "başka oyuncuların hasar sayısını görmemeliyiz" - sayı SADECE vuranın
	## ekranında çıkar. Vuran = last_attacker_peer_id (take_damage/take_damage_host her isabette günceller, DOT tiki
	## son doğrudan vuranınkini korur - bkz. _take_dot_damage). Bilinmiyorsa (0: tek oyunculu ya da oyuncu dışı
	## bir kaynak) eskisi gibi herkese.
	var dmg_owner: int = last_attacker_peer_id if NetworkManager.is_multiplayer_active else 0
	var my_peer: int = multiplayer.get_unique_id() if (NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer()) else 0
	if dmg_owner <= 0 or dmg_owner == my_peer:
		_spawn_floating_text(shown_amount, is_crit)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host and dmg_owner != my_peer:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		## Relay'in saniyelik mesaj/byte bütçesini aşıp bağlantıyı KAPATMASINI
		## önlemek için sınırlanıyor (bkz. NetworkManager.should_throttle
		## üzerindeki not) - çok hızlı vuran silahlar/DOT tikleri aynı
		## yaratığa saniyede onlarca "damage_number" göndermeye çalışabilir,
		## bu salt kozmetik olduğu için kayıp fark edilmez ama flood'u önler.
		## Kısıtlama vuran başına: aynı yaratığa vuran iki oyuncu birbirinin sayısını yutmasın.
		if net_id > 0 and not NetworkManager.should_throttle("dmgnum_%d_%d" % [net_id, dmg_owner], 0.1):
			var dmg_payload: Dictionary = {"amount": shown_amount, "is_crit": is_crit}
			if dmg_owner > 0:
				NetworkManager.broadcast_enemy_vfx.rpc_id(dmg_owner, net_id, "damage_number", dmg_payload)
			else:
				NetworkManager.broadcast_enemy_vfx.rpc(net_id, "damage_number", dmg_payload)


## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
## oyundan kaldır. gerçek hasar artık kalkanı görmezden gelerek vuruyor
## eskisi gibi") - eskiden kalkan emiliminden SONRA bir de "effective_armor"
## (armor_pen_percent/armor_pen_flat ile delinen düz zırh) düşülüyordu; zırh
## tamamen kaldırıldığı için o katman de gitti - kalkanı geçen hasar artık
## doğrudan (en az 1 hasar garantisiyle) cana işliyor.
func _apply_damage(amount: float, is_crit: bool, shield_pen_percent: float) -> void:
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
	## Efsun: Kafatası Kırıcı çatlakları + Derin Uyku - alınan TÜM hasar (DOT dahil).
	if crack_stacks > 0 or _sleep_vuln > 0.0 or _vuln_pct > 0.0 or mark_stacks > 0:
		amount *= _damage_taken_mult()
	var remaining: float = amount
	if _shield_break_pct > 0.0 and Time.get_ticks_msec() < _shield_break_until_msec:
		shield_pen_percent = 1.0 - (1.0 - clamp(shield_pen_percent, 0.0, 1.0)) * (1.0 - _shield_break_pct)
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
	## Kullanıcı isteği (2026-09-28): "hasar sayıları kalkanın hasar azaltmasından hesaplanmasın direk kaç vurduğumuz
	## yazsın" - eskiden sayı sadece cana ulaşan kısmı (remaining) gösteriyordu; %90 soğuran boss kalkanında 100'lük
	## vuruş "10" yazıyor, boss zırhlıymış gibi görünüyordu. Artık kalkandan ÖNCEKİ tam vuruş (hasar alma çarpanları
	## dahil) yazılır; can/kalkan hesabı değişmedi.
	_show_hit_number(max(amount, 1.0), is_crit)

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
	_ew_wake() ## EnemyWorld yolu: uyuyan yaratığı uyandır (anahtar kapalıyken boş)
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
	_ew_unregister() ## EnemyWorld yolu: C++ kaydı silinir, ölüm animasyonu eski _physics_process'ten
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
	_remove_frost_chill_fx() ## Don Nova buz kristalleri ölüm animasyonunda kalmasın
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
## Kullanıcı bildirimi (2026-09-26): "erken oyunda yaratıklardan nerdeyse hiç sandık çıkmıyor" - kök neden: Kademe 1-2 zarı
## 0.005 x 0.25 = öldürme başına %0.125; erken oyunda doğuş aralığı ~0.6 sn (dakikada <=100 öldürme), yani ilk 10 dk'da
## ortalama ~1 sandık. Sadece ERKEN oyuna çarpan: ilk EARLY_CHEST_BOOST_UNTIL sn x EARLY_CHEST_BOOST (~3-4 sandık/10 dk),
## sonra EARLY_CHEST_BOOST_FADE sn içinde doğrusal olarak x1'e iner (geç oyun sandık sayısı değişmez).
const EARLY_CHEST_BOOST := 3.0
const EARLY_CHEST_BOOST_UNTIL := 600.0
const EARLY_CHEST_BOOST_FADE := 300.0


static func early_chest_boost(game_time: float) -> float:
	if game_time <= EARLY_CHEST_BOOST_UNTIL:
		return EARLY_CHEST_BOOST
	var t: float = clampf((game_time - EARLY_CHEST_BOOST_UNTIL) / EARLY_CHEST_BOOST_FADE, 0.0, 1.0)
	return lerpf(EARLY_CHEST_BOOST, 1.0, t)
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
	## Elit yaratık (bkz. make_elite): garanti elit sandık; normal sandık zarı da aşağıda her yaratıktaki gibi atılır.
	if is_elite:
		_spawn_chest_drop(true)
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
	if randf() <= base_chance * luck * CHEST_DROP_RATE_MULT * early_chest_boost(GameManager.game_time):
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
	## DÜZELTME (kullanıcı bildirimi: "alan hasarı alınca FPS 60'tan 40'a düşüyor" -
	## gerçek oyunda 200 yaratıkla ölçüldü): her sayı eskiden ayrı bir floating_text
	## sahnesiydi (6 node + 2 Tween); 200 yaratığa vuran bir alan hasarından sonra
	## ~35 kare 20ms'yi aşıyordu, sayılar kapatılınca bu ~1'e iniyordu. Önce oluşturma
	## kuyruğa alınmıştı, yetmedi - asıl maliyet 1000 Label'ın yaşaması/çizilmesiydi.
	## Artık tüm yaratık hasar sayıları TEK bir DamageNumbers düğümünde kayıt olarak
	## tutulup tek _draw'da çiziliyor (görünüm floating_text ile aynı). Node
	## oluşturmadığı için fizik sorgu taşması sırasında da güvenle çağrılabilir.
	var alive: Array[int] = []
	for id in _dmg_ids:
		if dn.is_alive(id):
			alive.append(id)
	while alive.size() >= DMG_MAX_LIVE:
		dn.remove(alive.pop_front())
	var jitter := Vector2(randf_range(-DMG_SCATTER.x, DMG_SCATTER.x), randf_range(-DMG_SCATTER.y, DMG_SCATTER.y))
	alive.append(dn.spawn_fixed(self, PhysicsInterp.visual_position(self) + DMG_SPAWN_OFFSET + jitter, "%d" % amt, color))
	_dmg_ids = alive
