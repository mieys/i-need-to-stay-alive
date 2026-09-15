extends CharacterBody2D
class_name Enemy

@export var speed: float = 90.0
@export var max_health: float = 20.0
@export var contact_damage: float = 8.0
@export var contact_interval: float = 0.75
@export var xp_value: float = 5.0
@export var orb_count: int = 1

## Chance (0-1) to drop a gold pickup on death, and how much gold it's worth.
@export var gold_chance: float = 0.2
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
## ×0.2 ölçeklendi (0.00255 -> 0.00051). _drop_food()'daki
## _player_luck_drop_bonus() (bkz. orada, luck nerfi sonrası artık %0.2/
## puan) HÂLÂ ve TEK artış yolu, burada dokunulmadı.
@export var food_chance: float = 0.00051

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
## değer _process_ranged_attack/_process_homing_attack'taki 1.6x/2.5x
## çarpanlar sayesinde tetikleme mesafelerini de orantılı olarak küçültüyor.
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

var _ranged_timer: float = 0.0
var _normal_attack_timer: float = 0.0
const EnemyProjectileScene := preload("res://scenes/enemy_projectile.tscn")

## Only used for enemies whose visual is a plain Sprite2D with hframes/vframes
## set (e.g. the boss and the rat), instead of an AnimatedSprite2D with a
## SpriteFrames resource. Each grid is expected to have 4 rows in the order
## down, up, left, right (matches the Craftpix demon/rat packs) and however
## many frame columns fit in cell_size-wide cells.
@export var sprite_fps: float = 8.0
@export var cell_size: int = 128
@export var walk_texture: Texture2D
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

## Tüftüf'ün zehiri (bkz. weapon.gd/projectile.gd poison_tick_damage): isabet
## eden her dart bu düşmanı zehirler, saniyede bir tık hasar verir ve bu hasar
## süre boyunca her tık poison_ramp kadar artar. Yeni bir dart isabet ederse
## zehir YENİLENİR (süre ve tık hasarı sıfırdan başlar) - üst üste binmez,
## bkz. apply_poison().
var poison_tick_damage: float = 0.0 ## bu tıktaki hasar, bir sonraki tıkte poison_ramp kadar artar
var poison_ramp: float = 0.0 ## her tıkte poison_tick_damage'a eklenen miktar
var poison_time_left: float = 0.0
var _poison_tick_timer: float = 0.0
const POISON_TICK_INTERVAL := 1.0

## Zehir aktifken hedefin üzerinde sürekli oynayan döngülü efekt (bkz.
## scenes/fx_poison_status.tscn) - apply_poison() ile beliriyor, zehir bitince
## (_process_poison'da poison_time_left <= 0 olunca) kayboluyor. Yeni bir dart
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
const BOSS_CHILL_HITS_REQUIRED := 5

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
const RAGE_SPEED_MULT := 2.0

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

enum State { WALK, HURT, ATTACK, DEATH }

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

var _contact_timer: float = 0.0
var _player_in_hit_area: Node2D = null
var _frame_time: float = 0.0
var _flip_h: bool = false
var _sprite_row: int = ROW_DOWN

var _state: int = State.WALK
var _state_duration: float = 0.0

const FloatingText := preload("res://scenes/floating_text.tscn")
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
var _active_floating_text: Node2D = null
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
## yaratıklar bile normal "uzak dur" davranışını bırakıp üstüne yürür.
var _taunt_timer: float = 0.0


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
func apply_taunt(duration: float) -> void:
	_taunt_timer = max(_taunt_timer, duration)


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


## Tüftüf'ün dart'ı isabet ettiğinde çağrılır (bkz. projectile.gd). Zehir
## YENİLENİR: önceki zehrin kalan süresi/tık hasarı ne olursa olsun, bu
## çağrıyla süre ve tık hasarı sıfırdan başlar - aynı anda birden fazla zehir
## efekti üst üste binmez.
func apply_poison(initial_tick_damage: float, ramp_per_tick: float, duration: float) -> void:
	if is_dead:
		return
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		if net_id > 0:
			NetworkManager.request_enemy_effect.rpc_id(NetworkManager._host_peer_id(), net_id, "poison", initial_tick_damage, ramp_per_tick, duration)
		return
	poison_tick_damage = initial_tick_damage
	poison_ramp = ramp_per_tick
	poison_time_left = duration
	_poison_tick_timer = POISON_TICK_INTERVAL
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


func _process_burn(delta: float) -> void:
	if burn_time_left <= 0.0:
		return
	burn_time_left -= delta
	_burn_tick_timer -= delta
	if _burn_tick_timer <= 0.0:
		_burn_tick_timer += BURN_TICK_INTERVAL
		take_damage(burn_tick_damage)
	if burn_time_left <= 0.0:
		burn_tick_damage = 0.0
		## GÖRSEL: yakma bitti - alev sprite'ı kaldırılır (poison'ın
		## _process_poison'daki AYNI temizlik deseni) ve ağa haber verilir.
		if _burn_status_fx and is_instance_valid(_burn_status_fx):
			_burn_status_fx.queue_free()
			_burn_status_fx = null
			if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
				var net_id: int = int(get_meta("network_enemy_id", 0))
				if net_id > 0:
					NetworkManager.broadcast_enemy_vfx.rpc(net_id, "burn_stop")


func _process_poison(delta: float) -> void:
	if poison_time_left <= 0.0:
		return
	poison_time_left -= delta
	_poison_tick_timer -= delta
	if _poison_tick_timer <= 0.0:
		_poison_tick_timer += POISON_TICK_INTERVAL
		take_damage(poison_tick_damage)
		poison_tick_damage += poison_ramp
	if poison_time_left <= 0.0:
		poison_tick_damage = 0.0
		poison_ramp = 0.0
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
		return
	mark_stacks = min(mark_stacks + 1, max_stacks)
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
	bleed_tick_damage_per_stack = tick_damage_per_stack
	bleed_stacks = min(bleed_stacks + max(1, stacks_to_add), max_stacks)


func _process_bleed(delta: float) -> void:
	if bleed_stacks <= 0:
		return
	_bleed_tick_timer -= delta
	if _bleed_tick_timer <= 0.0:
		_bleed_tick_timer += BLEED_TICK_INTERVAL
		take_damage(bleed_tick_damage_per_stack * bleed_stacks)
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
		if _boss_chill_stacks >= BOSS_CHILL_HITS_REQUIRED:
			_boss_chill_stacks = 0
			_start_freeze(CHILL_DURATION)
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


func _process_root(delta: float) -> void:
	if _root_timer <= 0.0:
		return
	_root_timer -= delta
	if _root_timer <= 0.0:
		_root_timer = 0.0
		is_rooted = false


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
		take_damage(_bee_poison_stacks.size() * _bee_poison_per_tick_damage)


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
	return RAGE_SPEED_MULT if is_raging else 1.0


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
const TARGET_UPDATE_INTERVAL_FRAMES := 4
var _cached_target_player: Node2D = null

func _get_target_player() -> Node2D:
	var stale_dead: bool = _cached_target_player != null and (not is_instance_valid(_cached_target_player) or _cached_target_player.get("is_dead") == true)
	if stale_dead or Engine.get_physics_frames() % TARGET_UPDATE_INTERVAL_FRAMES == get_instance_id() % TARGET_UPDATE_INTERVAL_FRAMES:
		_cached_target_player = _find_closest_target_player()
	return _cached_target_player


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
	for ally: Node in get_tree().get_nodes_in_group("player_allies"):
		if not is_instance_valid(ally):
			continue
		var is_d2: bool = ally.get("is_dead") if "is_dead" in ally else false
		if not is_d2:
			var d2: float = global_position.distance_to(ally.global_position)
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
		is_frozen = false
		is_stunned = false
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
	is_feared = true
	_fear_source_pos = source_pos
	_fear_timer = max(duration, _fear_timer if is_feared else 0.0)


func _process_fear(delta: float) -> void:
	if not is_feared:
		return
	_fear_timer -= delta
	if _fear_timer <= 0.0:
		is_feared = false


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
const GLOBAL_SPEED_SCALE := 0.48

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
## ayrımı için yapıyor - min_gap artık yarıçap toplamının YARISI (+ sabit
## boşluk), yani yaratıklar birbirlerinin gövdesine eskisinin iki katı kadar
## yakınlaşabiliyor (aralarındaki zorunlu mesafe %50 azaldı).
const ENEMY_SEPARATION_SCALE := 0.5

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


## GEÇİCİ OLARAK DEVRE DIŞI (kullanıcı isteği: "oyundaki collision shapeleri
## kaldır haritada istediğimiz yere hareket edebilelim sonra sıfırdan
## collision shape dizicem çünkü") - player.gd'deki AYNI isteğin BİREBİR
## eşleniği (bkz. orada _block_movement_into_terrain üstündeki DÜZELTME
## notu), ama o zaman SADECE oyuncu tarafı kapatılmış, yaratık tarafı
## unutulmuştu - bu yüzden "ben de yaratıklar da suyu geçemiyoruz" şikayeti
## hâlâ geçerliydi (yaratıklar su/ev karolarında hâlâ duruyordu, üstelik su
## kenarında yığılan yaratık gövdeleri oyuncuyu da fiziksel olarak geri
## itip suya giremiyormuş HİSSİ veriyordu). Artık yaratıklar da su/ev
## karolarına bakılmaksızın haritanın HER yerinde serbestçe hareket
## edebilir. Yeni collision shape'ler elle dizilince bu erken return
## SATIRI kaldırılıp fonksiyon eskisi gibi (aşağıdaki mantık hâlâ olduğu
## gibi duruyor) tekrar aktif edilmeli.
func _block_movement_into_terrain() -> void:
	return
	if velocity.length() < 0.1:
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0:
		var probe_x: Vector2 = global_position + Vector2(sign(velocity.x) * probe_dist, 0.0)
		if GameManager.is_position_blocked_by_terrain(probe_x):
			velocity.x = 0.0
	if velocity.y != 0.0:
		var probe_y: Vector2 = global_position + Vector2(0.0, sign(velocity.y) * probe_dist)
		if GameManager.is_position_blocked_by_terrain(probe_y):
			velocity.y = 0.0

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

func _compute_enemy_separation() -> Vector2:
	if Engine.get_physics_frames() % SEPARATION_UPDATE_INTERVAL_FRAMES == get_instance_id() % SEPARATION_UPDATE_INTERVAL_FRAMES:
		_cached_separation_push = _separation_push_from_group("enemies") * ENEMY_SEPARATION_FORCE
	return _cached_separation_push


## bkz. ENEMY_SEPARATION_GAP üstündeki DÜZELTME notu - ızgara (grid) kare
## başına TEK SEFER burada kuruluyor. static var olduğu için TÜM enemy.gd
## örnekleri arasında paylaşılıyor; hangi yaratık önce çağırırsa ızgarayı o
## kurar, aynı karedeki geri kalan herkes hazır ızgarayı bulur.
const SEPARATION_GRID_CELL_SIZE: float = 140.0 ## >= ENEMY_SEPARATION_CHECK_RADIUS olmalı (3x3 komşuluk taramasının menzili kaçırmaması için)
static var _separation_grid: Dictionary = {}
static var _separation_grid_frame: int = -1

static func _rebuild_separation_grid_if_needed(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _separation_grid_frame:
		return
	_separation_grid_frame = frame
	_separation_grid.clear()
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var cell: Vector2i = Vector2i(floori(e.global_position.x / SEPARATION_GRID_CELL_SIZE), floori(e.global_position.y / SEPARATION_GRID_CELL_SIZE))
		if not _separation_grid.has(cell):
			_separation_grid[cell] = []
		(_separation_grid[cell] as Array).append(e)


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
	var cell_radius: int = maxi(1, ceili(radius / SEPARATION_GRID_CELL_SIZE))
	var center_cell: Vector2i = Vector2i(floori(pos.x / SEPARATION_GRID_CELL_SIZE), floori(pos.y / SEPARATION_GRID_CELL_SIZE))
	var radius_sq: float = radius * radius
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			if not _separation_grid.has(cell):
				continue
			for e in (_separation_grid[cell] as Array):
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
	var my_cell: Vector2i = Vector2i(floori(global_position.x / SEPARATION_GRID_CELL_SIZE), floori(global_position.y / SEPARATION_GRID_CELL_SIZE))
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


func _physics_process(delta: float) -> void:
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
		_update_state_timer(delta)
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
				if is_ranged and dist <= ranged_range and _taunt_timer <= 0.0:
					velocity = Vector2.ZERO
					_update_stuck_state(delta, false)
				elif dist <= min_separation:
					velocity = Vector2.ZERO
					_update_stuck_state(delta, false)
				else:
					## bkz. _is_stuck üstündeki BUG DÜZELTMESİ notu - oyuncuya
					## gerçekten yaklaşmaya çalışırken engele sıkışmışsak
					## (su/ev tile'ı, bkz. GameManager.is_position_blocked_by_
					## terrain) yönü hafifçe engelin yanından dolanacak şekilde
					## büküyoruz, aksi halde her karede aynı düz yönü deneyip
					## sonsuza dek orada kalırdı.
					_update_stuck_state(delta, true)
					var steered_dir: Vector2 = _steer_around_obstacle(dir)
					velocity = steered_dir * speed * _chill_speed_mult() * _slow_speed_mult() * _rage_speed_mult()
				## DÜZELTME (kullanıcı isteği #35: "yaratıklar saldırırken
				## hareket ediyor, saldırı animasyonu anında hareket
				## edememeliler") - _state == State.ATTACK süresince (bkz.
				## _enter_state çağrıları, _state_duration ile otomatik WALK'a
				## döner) yürüme hızı burada iptal ediliyor; ayrışma/knockback
				## (aşağıda ayrıca eklenen) buna dokunmuyor, yani vurulunca
				## yine itilebiliyor, sadece kendi isteğiyle yürüyemiyor.
				if _state == State.ATTACK:
					velocity = Vector2.ZERO
				_update_facing(dir)
				if is_ranged:
					_process_ranged_attack(delta, player, dist, dir)
					_process_homing_attack(delta, player, dist)
			else:
				## Kullanıcı isteği: "yaratıkların hedefi yokken etrafta
				## arada rasgele dolanmalı bazen de durmalılar ve doğal
				## davranmalılar" - eskiden burada dümdüz velocity=ZERO ile
				## donup kalıyorlardı (hedef yok/tüm oyuncular görünmez-ev
				## içi-seyyar satıcı bölgesinde). Artık bkz. _compute_wander_
				## velocity().
				velocity = _compute_wander_velocity(delta)
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
		if not is_frozen and player and is_instance_valid(player) and min_separation > 0.0 and _knockback_velocity.length() < 40.0:
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

		_process_item_shield(delta)
		_process_poison(delta)
		_process_burn(delta)
		_process_mark(delta)
		_process_bleed(delta)
		_process_chill(delta)
		_process_boss_chill(delta)
		_process_slow(delta)
		_process_root(delta)
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
			if dist <= melee_range and _contact_timer <= 0.0:
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
		## hasar PALADIN_ULTI_SHIELD_COST_MULT sayesinde zaten %90 azaltılmış
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
				## bildirimi). take_paladin_barrier_damage() sabit %10 oranla SADECE
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

	_update_state_timer(delta)

	if frame_sprite:
		_advance_frame_sprite(delta)


## Casts periodically once the player is roughly within range - a bit of
## slack (1.6x) beyond ranged_range so it keeps firing while the player is
## drifting in and out rather than needing to be exactly in the sweet spot.
func _process_ranged_attack(delta: float, _player: Node2D, dist: float, dir: Vector2) -> void:
	if dist > ranged_range * 1.6:
		return
	_ranged_timer -= delta
	if _ranged_timer <= 0.0:
		_ranged_timer = ranged_attack_interval
		_fire_ranged_attack(dir)


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
	## EnemyProjectile de (XpOrb/GoldDrop/FoodDrop gibi) Area2D+CollisionShape2D
	## kökenli - bu da _physics_process içinden tetiklendiği için (bkz. kullanıcı
	## bildirimi: "genel bir sorun var gibi") aynı fizik sorgu taşması riskine
	## karşı savunma amaçlı call_deferred kullanılıyor.
	get_tree().current_scene.call_deferred("add_child", proj)
	
	## Multiplayer: düşman mermisini client'lara broadcast et (görsel kopya)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		NetworkManager.broadcast_enemy_projectile.rpc(global_position, dir, false, projectile_tint, net_id)


## İKİNCİ, daha zayıf, GARANTİ İSABETLİ (homing) normal atış - büyüden (yukarısı)
## tamamen ayrı bir kd üzerinde çalışır. Büyünün 1.6x menzil toleransından daha
## geniş bir alanda tetiklenir ki yaratık büyü menzili dışındayken de oyuncuyu
## bu zayıf ama kaçınılmaz saldırıyla tehdit etsin.
func _process_homing_attack(delta: float, _player: Node2D, dist: float) -> void:
	if dist > ranged_range * 2.5:
		return
	_normal_attack_timer -= delta
	if _normal_attack_timer <= 0.0:
		_normal_attack_timer = normal_attack_interval
		_fire_homing_attack()


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
	_state = new_state
	_state_duration = duration
	_frame_time = 0.0

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


## Host bu yaratığın HURT (vuruş alma) pozuna girdiği anı istemcilere
## yayınlar - _broadcast_attack_state ile BİREBİR AYNI mantık, sadece
## "attack_state" yerine "hurt_state". DÜZELTME: network_manager.gd'nin
## broadcast_enemy_vfx'inde "hurt_state" case'i VE bunun beklediği
## _enter_hurt_state_networked() ismi ZATEN VARDI, ama bu tarafta (enemy.gd)
## ne bu yayın çağrısı ne de hedef fonksiyon hiç tanımlıydı - yani mekanizma
## kabloları hazırdı ama uçları hiç birleştirilmemişti, katılımcılar
## yaratığın vuruş alma animasyonunu (host'un kendi ekranında oynayan,
## sadece can/kalkan renkli yanıp sönmesiyle ["_flash"] eşlik eden) hiç
## görmüyordu - bkz. kullanıcı bildirimi: "yaratıkların animasyonları
## katılımcılarda yanlış görünüyor". Süre burada da (attack_state ile aynı
## gerekçeyle) ağdan gönderilmiyor, istemci kendi hesaplıyor.
func _broadcast_hurt_state() -> void:
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		## DÜZELTME (kullanıcı bildirimi: "multiplayerda katılımcılar yine lag
		## sorunları yaşıyor yaratıklar bir yürüyüp bir duruyor ve bazen
		## arkalarına dönüyorlar" + "multiplayerda katılımcıların fpsi çok
		## düşüyor") - "damage_number" (bkz. _apply_damage) ZATEN should_
		## throttle ile sınırlanmıştı ama "hurt_state" hiç sınırlanmamıştı:
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
		if net_id > 0 and not NetworkManager.should_throttle("hurt_%d" % net_id, 0.1):
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "hurt_state", {})


## _broadcast_attack_state/_broadcast_hurt_state İLE BİREBİR AYNI desen -
## die()'ın en başından, tam "attack_state"/"hurt_state" gibi anında ve
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


## broadcast_enemy_vfx RPC'sinin "hurt_state" case'inin çağırdığı istemci
## tarafı karşılığı.
## DÜZELTME (bkz. proje köküdeki CLAUDE.md - "kaster kendi ekranında doğru
## görür, diğer oyuncularda hiçbir şey görünmez" hata sınıfı): _flash()
## (beyaz hit-flash) SADECE host'ta çalışan _apply_damage()'dan
## çağrılıyordu, host-olmayan istemciler bu "hurt_state" senkronunu
## alıyordu ama flaşı HİÇ tetiklemiyordu - bu yüzden onlarda yaratıklar
## hasar alırken hiç beyazlamıyordu. Artık host'un _apply_damage()'taki
## çağrısıyla AYNI şekilde burada da tetikleniyor.
func _enter_hurt_state_networked() -> void:
	_flash()
	var dur: float = _anim_length_for(State.HURT)
	_enter_state(State.HURT, dur if dur > 0.0 else 0.3)


func _texture_for_state(state: int) -> Texture2D:
	match state:
		State.HURT:
			return hurt_texture if hurt_texture else walk_texture
		State.DEATH:
			return death_texture if death_texture else walk_texture
		State.ATTACK:
			return attack_texture if attack_texture else walk_texture
		_:
			return walk_texture


func _anim_name_for_state(state: int) -> String:
	match state:
		State.HURT:
			return "hurt"
		State.DEATH:
			return "death"
		State.ATTACK:
			return "attack1"
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


func take_damage(amount: float, is_crit: bool = false, shield_pen_percent: float = 0.0) -> void:
	if is_dead:
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
	_apply_damage(amount, is_crit, shield_pen_percent)


## Called by NetworkManager.request_enemy_damage RPC on the host only.
func take_damage_host(amount: float, is_crit: bool, shield_pen_percent: float, attacker_id: int = 0) -> void:
	if is_dead:
		return
	if attacker_id > 0:
		last_attacker_peer_id = attacker_id
	_apply_damage(amount, is_crit, shield_pen_percent)


## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
## oyundan kaldır. gerçek hasar artık kalkanı görmezden gelerek vuruyor
## eskisi gibi") - eskiden kalkan emiliminden SONRA bir de "effective_armor"
## (armor_pen_percent/armor_pen_flat ile delinen düz zırh) düşülüyordu; zırh
## tamamen kaldırıldığı için o katman de gitti - kalkanı geçen hasar artık
## doğrudan (en az 1 hasar garantisiyle) cana işliyor.
func _apply_damage(amount: float, is_crit: bool, shield_pen_percent: float) -> void:
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
			and health > 0.0 and health <= max_health * RAGE_HP_THRESHOLD:
		_enter_rage_mode()
	## Can çalma pasifi (Kurt Adam): oyuncuya, yaratığın gerçekten yediği
	## hasar üzerinden bildirim - pasifsiz karakterlerde no-op.
	var lifesteal_player := get_tree().get_first_node_in_group("player")
	if lifesteal_player and lifesteal_player.has_method("on_damage_dealt"):
		lifesteal_player.on_damage_dealt(effective_amount)
	_spawn_floating_text(effective_amount, is_crit)
	# Broadcast damage number to clients
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		var net_id: int = int(get_meta("network_enemy_id", 0))
		## Relay'in saniyelik mesaj/byte bütçesini aşıp bağlantıyı KAPATMASINI
		## önlemek için sınırlanıyor (bkz. NetworkManager.should_throttle
		## üzerindeki not) - çok hızlı vuran silahlar/DOT tikleri aynı
		## yaratığa saniyede onlarca "damage_number" göndermeye çalışabilir,
		## bu salt kozmetik olduğu için kayıp fark edilmez ama flood'u önler.
		if net_id > 0 and not NetworkManager.should_throttle("dmgnum_%d" % net_id, 0.1):
			NetworkManager.broadcast_enemy_vfx.rpc(net_id, "damage_number", {"amount": effective_amount, "is_crit": is_crit})
	if health <= 0:
		die()
	else:
		var dur: float = _anim_length_for(State.HURT)
		var hurt_duration: float = dur if dur > 0.0 else 0.3
		_enter_state(State.HURT, hurt_duration)
		_broadcast_hurt_state()


## BUG DÜZELTMESİ: rage/chill tonu artık HER ZAMAN doğru görünüyor. Eskiden
## bu tween'in HEDEF rengi (ikinci tween_property, _status_tint_color())
## fonksiyon çağrıldığı ANDA sabitleniyordu - yani tam rage'e giren vuruşta
## (health %30'un altına düşen o vuruşta) _flash() ÖNCE (eski, "beyaz/normal"
## tonla) çalışıyor, _enter_rage_mode() SONRA tetiklenip modulate'i anında
## kırmızıya çeviriyordu, ama bu ESKİ tween hâlâ arka planda çalışmaya devam
## edip 0.15sn sonra modulate'i sessizce ESKİ (rage öncesi) tona geri
## döndürüyordu - "rage rengi hiç görünmüyor/hemen kayboluyor" hissi buradan
## geliyordu (bkz. kullanıcı bildirimi). Artık tween referansı saklanıp
## _refresh_chill_tint() (rage/chill'in tek gerçek kaynağı) her çağrıldığında
## bu YARIM KALMIŞ tween varsa öldürülüyor, tona asla tekrar üstüne binmiyor.
var _flash_tween: Tween = null

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
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_hit_flash_material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_hit_flash_material, "shader_parameter/flash_amount", 0.0, HIT_FLASH_DURATION)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO

	## DÜZELTME (kullanıcı bildirimi: "yaratıkların ölüm animasyonu
	## katılımcılarda farklı görünüyor"): host'un ölümü katılımcılara
	## eskiden SADECE enemy_spawner.gd'nin periyodik (0.15sn'de bir),
	## "unreliable" _sync_enemy_positions paketindeki net_dead bayrağıyla
	## ulaşıyordu - saldırı/vuruş animasyonlarının (bkz. _broadcast_attack_
	## state/_broadcast_hurt_state) tersine, ölüm anında ANINDA/güvenilir
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
	## (on_damage_dealt/Kurt Adam can çalma İLE AYNI desen). Pasifi olmayan
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
	var is_boss_kill: bool = is_boss
	if NetworkManager.is_multiplayer_active and last_attacker_peer_id > 0 and last_attacker_peer_id != multiplayer.get_unique_id():
		NetworkManager.notify_kill_passive.rpc_id(last_attacker_peer_id, is_boss_kill, global_position)
	else:
		var killer_player := get_tree().get_first_node_in_group("player")
		if killer_player and killer_player.has_method("on_enemy_killed"):
			killer_player.on_enemy_killed(self)

	_drop_xp()
	_drop_gold()
	_drop_food()
	_drop_magnet()
	_drop_chest()
	_enter_state(State.DEATH)

	var death_time: float = _anim_length_for(State.DEATH)
	if death_time <= 0.0:
		death_time = 0.4
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
		tw.tween_callback(queue_free)
	else:
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

static func _queue_drop_spawn(spawn_cb: Callable) -> void:
	_drop_spawn_queue.append(spawn_cb)

static func drain_drop_spawn_queue() -> void:
	var drained: int = 0
	while drained < DROP_SPAWN_PER_FRAME and not _drop_spawn_queue.is_empty():
		var cb: Callable = _drop_spawn_queue.pop_front()
		cb.call()
		drained += 1


func _drop_xp() -> void:
	## In multiplayer only the host spawns drops; clients see the death
	## animation but don't create duplicate orbs/gold/food on their side.
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var count: int = max(orb_count, 1)
	var per_orb: float = xp_value / float(count)
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


## Oyuncunun "şans" statı artık ÇARPIMSAL değil DÜZ ekleniyor - her 1 şans
## puanı (bkz. player.gd apply_upgrade "luck" dalı, artık +1/kart) yaratığın
## birşey (altın/meyve) düşürme ihtimalini düz +%1 arttırır (kullanıcı isteği:
## "Her 1 şans yaratıkların birşey düşürme ihtimalini %1 arttırır").
## DÜZELTME (kullanıcı isteği: "şans çok güçlü, %80 nerflemen gerekiyor") -
## oran (her luck puanı için altın/yemek/mıknatıs düşme şansına eklenen
## bonus) 0.01 -> 0.002 (×0.2).
func _player_luck_drop_bonus() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and "luck" in player:
		return player.luck * 0.002
	return 0.0


## Kullanıcı isteği: "şans statı sandık düşme ihtimalini de arttırsın, ama
## %1 değil %0.2 arttırsın her 1 şans başına" - yukarıdaki genel
## _player_luck_drop_bonus() (altın/meyve için %1/şans) ile KARIŞTIRILMASIN,
## sandığa özel, daha küçük bir oran - bkz. _drop_chest().
## DÜZELTME (kullanıcı isteği: "şans çok güçlü, %80 nerflemen gerekiyor") -
## 0.002 -> 0.0004 (×0.2).
const LUCK_CHEST_BONUS_PER_POINT := 0.0004

func _player_luck_chest_bonus() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and "luck" in player:
		return player.luck * LUCK_CHEST_BONUS_PER_POINT
	return 0.0


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
	var chance: float = gold_chance + _player_luck_drop_bonus()
	if chance > 0.0 and randf() <= chance:
		var amount: int = randi_range(gold_min, max(gold_min, gold_max))
		var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		var scene_root: Node = get_tree().current_scene
		_queue_drop_spawn(func() -> void:
			var drop = GoldDrop.instantiate()
			drop.amount = amount
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
func _roll_extra_item_gold() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player) or not ("item_extra_gold_chance" in player):
		return
	var extra_chance: float = player.item_extra_gold_chance
	if extra_chance <= 0.0 or randf() > extra_chance:
		return
	var drop_pos: Vector2 = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var scene_root: Node = get_tree().current_scene
	_queue_drop_spawn(func() -> void:
		var drop = GoldDrop.instantiate()
		drop.amount = 1
		drop.global_position = drop_pos
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
	var chance: float = food_chance + _player_luck_drop_bonus()
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
	var chance: float = magnet_chance + _player_luck_drop_bonus()
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
const CHEST_DROP_RATE_MULT := 0.12
func _drop_chest() -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	var bonus: float = _player_luck_chest_bonus()
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

	var chance: float = 1.0 if is_boss else (base_chance + bonus) * CHEST_DROP_RATE_MULT
	if randf() <= chance:
		var chest_tier: int = _get_chest_tier_from_enemy_tier()
		var drop_pos: Vector2 = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		var scene_root: Node = get_tree().current_scene
		_queue_drop_spawn(func() -> void:
			var chest = ChestDropScene.instantiate()
			chest.chest_tier = chest_tier
			chest.global_position = drop_pos
			if NetworkManager.is_multiplayer_active:
				var drop_id: int = NetworkManager._gen_drop_id()
				chest.set_meta("drop_network_id", drop_id)
				NetworkManager.broadcast_drop.rpc("chest", chest.global_position, chest.chest_tier, drop_id)
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
	if _active_floating_text and is_instance_valid(_active_floating_text):
		_floating_text_total += amt
		_active_floating_text.update_text("%d" % _floating_text_total, color)
		return
	var ft = FloatingText.instantiate()
	get_tree().current_scene.add_child(ft)
	ft.follow_target = self
	ft.follow_offset = Vector2(0, -30)
	ft.global_position = global_position + Vector2(0, -30)
	_floating_text_total = amt
	ft.setup("%d" % amt, color)
	_active_floating_text = ft
