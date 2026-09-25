extends Node2D

const PhysicsInterp := preload("res://scripts/physics_interp.gd")

signal fired(direction: Vector2)

@export var projectile_scene: PackedScene
@export var fire_rate: float = 1.0
@export var damage: float = 10.0
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.5

## Max distance to a target before this weapon will consider it at all.
## 0 = unlimited attack_range.
@export var attack_range: float = 0.0

## When true, this weapon skips the travelling projectile entirely and hits
## the target instantly (e.g. a lightning strike) - impact_scene (if set) is
## spawned at the target's position as the visual feedback.
@export var hitscan: bool = false
@export var impact_scene: PackedScene

## Şimşek Asası (2026 güncellemesi): "kesintisiz ışın" modu - FireTimer/
## fire_rate tabanlı AYRIK atışlar tamamen devre dışı kalır (bkz.
## _on_fire_timer_timeout), bunun yerine _process() her karede menzildeki bir
## hedefe sürekli bir ışın (beam_scene) tutar ve beam_tick_interval saniyede
## BİR DEĞİL, saniyede 3 kez hasar uygular (taban değer artık 1.0 değil
## 1.0/3.0 - bkz. weapon_lightning.tscn, _deal_beam_tick'teki
## BEAM_TICK_DAMAGE_RATIO) - hedef menzilden çıkana/ölene kadar ışın hiç
## kaybolmaz. Diğer tüm silahlerde false (no-op) - bkz.
## _process_continuous_beam, Şimşek asası özellikleri.txt.
@export var continuous_beam: bool = false
@export var beam_scene: PackedScene
@export var beam_tick_interval: float = 0.3333333
## Işığın birincil hedeften sıçradığı EK düşman sayısı (0 = hiç sıçramaz) ve
## her sıçramanın verdiği hasar oranı (birincil hedefin o tikteki hasarına
## göre). player.gd _apply_lightning_tier() tier'e göre günceller.
var chain_jump_count: int = 1
var chain_damage_percent: float = 0.5
## Kullanıcı isteği: "yıldırım asasının sekmesi sadece hedefin yakınındaki
## yaratıklara olmalı, çok uzaktaki yaratıklara bile sekiyor" - eskiden
## _apply_chain_jumps ekrandaki/haritadaki TÜM düşmanlar arasından mesafeye
## göre en yakın olanları seçiyordu ama bir MENZİL sınırı hiç yoktu, yani
## haritanın öbür ucundaki tek düşmana bile sıçrayabiliyordu. Artık sadece bu
## yarıçap içindeki düşmanlar aday sayılıyor.
## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
const WeaponTargetPriorityScript := preload("res://scripts/weapon_target_priority.gd")
const TuftufTargetingScript: GDScript = preload("res://scripts/tuftuf_targeting.gd")

const CHAIN_JUMP_RANGE := 220.0

## Zincir sıçrama görsel efekti (bkz. _apply_chain_jumps) - her sıçramada
## bir önceki hedeften yeni hedefe zikzak çizen kısa ömürlü bir elektrik arkı.
## Daha önce hiç kullanılmıyordu (sıçrama sessizce sadece hasar veriyordu) -
## kullanıcı bildirimi: "diğer yaratıklara sıçrarken çıkan efektler bozulmuş"
## aslında hiç efekt ÇIKMIYOR olmasıydı.
const FxLightningChainScene := preload("res://scenes/fx_lightning_chain.tscn")

var _beam_target: Node2D = null
var _beam_fx: Node = null
var _beam_tick_timer: float = 0.0

## Menzilli silahların ateşleme anında bir kerelik oynayan görsel (ör.
## Tabanca'nın ateşleme efekti) - saldırı yönüne döner. "" /null = efekt yok,
## davranış değişmez (ör. Ateş/Yıldırım Asası hiç ayarlamıyor).
## ÖNEMLİ: bu efekt tepede süzülen silah ikonundan DEĞİL, merminin de tam
## olarak başladığı noktadan (bu silahın kendi global_position'ı) çıkar -
## yoksa efekt kafanın üstündeki ikonda, mermi ise gövdeden çıkıyormuş gibi
## görünüp birbirinden kopuk dururdu. muzzle_flash_offset, efekti bu noktadan
## saldırı yönünde ne kadar öne kaydıracağını belirler (0 = tam merkezde).
@export var muzzle_flash_scene: PackedScene
@export var muzzle_flash_offset: float = 0.0

## Tüftüf: en yakın düşman yerine zehir önceliğine göre hedefler - kullanıcı
## isteği: "canı yüksek > hiç zehirlenmemiş > tüm yaratıklar" (bkz. tuftuf_
## targeting.gd; alan adı eski "en yüksek can" isteğinden kaldı). Hedef her
## ateşte tazelendiği için hedefin canı düştükçe/yeni yaratıklar geldikçe
## kendiliğinden "sürekli hedef değiştirir" hissi verir.
@export var target_highest_health: bool = false

## Buz Asası: DONMAMIŞ düşmanlara öncelik verir - menzildeki en yakın donmamış
## düşmanı hedefler, hepsi donmuşsa (veya menzilde donmamış yoksa) normal en
## yakın düşman mantığına düşer (bkz. _get_nearest_unfrozen_enemy).
@export var target_prefer_unfrozen: bool = false

## Kullanıcı isteği: "birden fazla buz asasına sahip olunca hepsi aynı
## yaratığa ateş ediyor, donmamış hedeflere ayrı ayrı hedef almalılar aynı
## hedefe odaklanmamalı hepsi bir anda (bosslar hariç)" - bu değişken, o anki
## karede _get_nearest_unfrozen_enemy()'nin seçtiği hedefi tutar; AYNI
## oyuncudaki DİĞER Buz Asası kopyaları (bkz. _get_sibling_frost_targets)
## bu değeri okuyup kendi seçimlerinde o hedefi (boss DEĞİLSE) hariç tutar.
var _claimed_frost_target: Node2D = null

## Buz Asası: her isabette hedefi dondurması için kullanılan etkinin açık
## olup olmadığını belirler (bkz. projectile.gd chill_stacks, enemy.gd apply_chill).
## 0 = bu silah donma uygulamaz.
var chill_stacks_per_hit: int = 0

## Ateş Asası pasifi: her isabette hedefi 3sn yakar (bkz. projectile.gd
## burn_on_hit_tick_damage, enemy.gd apply_burn) - saniye başına hasar,
## saldırı gücünün (damage_bonus) FIRE_STAFF_BURN_ATTACK_POWER_RATIO'su
## olarak player.gd _refresh_fire_staff_burn()'de hesaplanıp buraya
## yazılır (Hançer'in bleed_tick_damage_per_stack'iyle AYNI desen). 0 = bu
## silah yakma uygulamaz (diğer tüm silahler).
var burn_on_hit_tick_damage: float = 0.0

## Tüftüf'ün zehiri: isabet eden mermi hedefi zehirler (bkz. projectile.gd,
## enemy.gd apply_poison) - 0 = bu silah zehir uygulamaz (diğer tüm silahler).
## Kullanıcı isteği: "Tüftüfün zehri 100 defaya kadar stacklenebilsin ve zehir
## 20 saniye boyunca her saniye saldırı gücünün %5'i kadar hasar versin" -
## poison_tick_damage HER YÜKÜN saniyelik hasarı (player.gd _refresh_tuftuf_
## poison saldırı gücünden hesaplar), poison_max_stacks bir düşmandaki toplam
## yük üst sınırı, poison_duration bir yükün ömrü (sn) - bkz. enemy.gd
## apply_poison. (Eskiden poison_ramp_per_tick vardı: tek zehir + saniyede
## artan hasar; yük modeliyle kaldırıldı.)
@export var poison_tick_damage: float = 0.0
@export var poison_max_stacks: int = 0
@export var poison_duration: float = 0.0

## Kullanıcı isteği: "Tüftüfün hasarını gerçek hasara çevir" - bu silahın
## hasarı artık kalkanı TAMAMEN yok sayar (bkz. _fire_at() içindeki
## shield_pen = 1.0 ataması, Elara'nın Gerçek Hasar'ıyla (elara_true_damage_active) AYNI
## mekanizma - sadece Elara'daki gibi geçici bir hak DEĞİL, Tüftüf'te
## KALICI/her zaman açık). Diğer tüm silahlerde false, davranış değişmez.
@export var always_true_damage: bool = false

## Tüftüf: hem silahın kendi ikonu HEM DE attığı dart'ın görseli 10 tier'e
## (=dükkan seviyesine) kadar değişir - bkz. set_weapon_tier(), player.gd'nin
## _apply_tuftuf_tier() çağrısı. Diğer tüm silahlerde boş kalır, davranış
## değişmez.
@export var tier_icon_textures: Array[Texture2D] = []
@export var tier_dart_textures: Array[Texture2D] = []
var _current_tier: int = 1

## Tabanca (Revolver): sınırlı mermi + reload sistemi. max_ammo = 0
## (varsayılan, diğer tüm silahler - Tüfek dahil) sınırsız mermi demektir -
## hiçbir davranış değişmez. max_ammo > 0 olan bir silah mermisi biterse
## reload_duration kadar süren bir reload'a girer, o sırada ateş edemez
## (bkz. _on_fire_timer_timeout).
@export var max_ammo: int = 0
@export var reload_duration: float = 0.0
## reload_frames animasyonunun DOĞAL (1x hız, .tres'teki "speed") süresi -
## reload_duration tier'le kısaldıkça (bkz. player.gd _apply_tabanca_tier)
## animasyon da orantılı hızlandırılır ki sabit kare sayısı her zaman tam
## reload_duration'a sığsın. 0 = hızlandırma yapılmaz, doğal hızında oynar.
@export var reload_anim_base_duration: float = 0.0
var current_ammo: int = 0
var is_reloading: bool = false
var _reload_timer: float = 0.0
@onready var reload_anim: AnimatedSprite2D = get_node_or_null("ReloadAnim")

## DÜZELTME (kullanıcı isteği: "zırh delme olmadığından yerini kalkan delme
## alacak") - Tüfek/Topuz/Uzunkılıç'ın dükkan tier'inden gelen silaha özel
## delme bonusları artık TEK bir stat'ta birleşiyor: weapon_shield_pen_bonus
## (bkz. _fire_at, player.gd _apply_tufek_tier/_apply_topuz_tier/
## _apply_uzunkilic_tier). Eskiden ayrı weapon_armor_pen_bonus (yüzdesel) ve
## weapon_armor_pen_flat_bonus (düz) vardı - zırh kaldırılınca ikisi de
## silindi, düz olanın kalkan tarafında doğal bir karşılığı olmadığı için
## sadece yüzdesel (Uzunkılıç'ın zaten kullandığı) stat kaldı.
var weapon_shield_pen_bonus: float = 0.0

## Elara TEMEL (E) "Gerçek Hasar". Kullanıcı isteği (2026-09-25): "6 saldırı yerine 6 saniye sürsün", "bonus hasarını
## kaldır, saldırı hızını %30 TOPLAM saldırı hızı olarak güncelle (mevcut saldırı hızını güncel haliyle %30 arttıracak),
## bekleme süresi 25 sn". Eskiden silah başına 6 hak sayacı (+%50 hasar, x2 saldırı hızı) vardı - kaldırıldı. Artık
## oyuncudaki elara_true_damage_active bayrağı (elara_double_fire_active ile AYNI desen, süreyi player.gd'nin skill2
## makinesi yönetir): açıkken her atış kalkanı TAMAMEN yok sayar (gerçek hasar - kalan tek hasar etkisi) ve o anki
## TOPLAM atış hızı (kartlar/eşyalar/pasif/diğer yetenekler dahil, _effective_fire_wait'in geri kalanı) %30 artar.
## fire_rate_multiplier'a YAZILMIYOR (o alanı Matthew/Talon yetenekleri de kullanıyor, bitişte 1.0'a sıfırlıyorlar).
const TRUE_DAMAGE_ATTACK_SPEED_BONUS := 0.30


func _elara_true_damage_active() -> bool:
	return _player_flag("elara_true_damage_active")


## Tüm atış aralığı hesaplarının (FireTimer, yay çekilişi, şimşek ışını tiki) TEK kaynağı.
func _effective_fire_wait() -> float:
	var wait: float = fire_rate * fire_rate_multiplier
	if _elara_true_damage_active():
		wait /= 1.0 + TRUE_DAMAGE_ATTACK_SPEED_BONUS ## saldırı hızı x1.3 = aralık /1.3
	return wait
## Elara ULTİ (R): 25sn boyunca her atış bu oranda hasar verir (%60) - "2 kez
## tetiklenir" kısmı _on_fire_timer_timeout/_process'teki draw-ready dalında
## _fire_at()'in İKİ KEZ çağrılmasıyla sağlanıyor (bkz. player.gd
## elara_double_fire_active).
const ELARA_DOUBLE_FIRE_DAMAGE_MULT := 0.6

## "2 kez tetiklenir" ikinci atışını AYNI karede değil, kısa bir gecikmeyle
## tetikler (bkz. _fire_at_delayed) - kullanıcı bildirimi: "2şer 2şer atıyor
## gibi görünmüyor". Sebep: yakın dövüş silahlarında _do_melee_swing() ikinci
## çağrıda önceki tween'i anında öldürüp SIFIRDAN başlatıyor (bkz. o
## fonksiyondaki "_melee_swing_tween.kill()"), yani aynı karede iki kez
## çağrılınca görsel olarak SADECE TEK bir savuruş oynuyordu - hasar aslında
## 2 kez uygulanıyordu (float text 2 kez çıkıyordu) ama göze tek vuruş gibi
## görünüyordu. Menzilli silahlerde de iki mermi tam üst üste spawn olup
## görsel olarak ayırt edilemiyordu. Küçük bir gecikmeyle iki atış artık
## gözle de ayrı ayrı seçilebiliyor.
const DOUBLE_FIRE_VISUAL_DELAY := 0.16
## Aynı atışta HEM Elara ulti'si HEM Kaos Kitabı şansı tetiklenirse (nadir
## ama mümkün), üçüncü atış bununla daha da ertelenir - ikisi de aynı gecikmeye
## denk gelip yine üst üste binmesin diye.
const ITEM_DOUBLE_FIRE_VISUAL_DELAY := 0.32


## Elara ulti'si / Kaos Kitabı pasifi için gecikmeli ikinci (veya üçüncü) atış
## - bkz. yukarıdaki DOUBLE_FIRE_VISUAL_DELAY yorumu. Hedef bu süre içinde
## ölür/geçersiz olursa ya da silah sahneden kaldırılırsa sessizce no-op olur.
func _fire_at_delayed(target: Node2D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if not is_instance_valid(target) or target.get("is_dead") == true:
		return
	_fire_at(target)


## _player_stat()/_player_stat_default() sayısal (float) dönüyor - bool bir
## bayrağı (ör. elara_double_fire_active) okumak için ayrı, tip-güvenli bir
## yardımcı.
func _player_flag(stat_name: String) -> bool:
	var parent := get_parent()
	if parent and stat_name in parent:
		return bool(parent.get(stat_name))
	return false

## Tabanca: aynı hedefe her isabette hedefin üzerinde bir "yük" (mark)
## biriktirir - her yük o hedefe verilen hasarı %1 arttırır, isabet başına
## +1 yük (20 saniye boyunca isabet almazsa yük sıfırlanır - bkz. enemy.gd
## apply_mark_stack/get_mark_damage_mult). Bu değer, o hedefte birikebilecek
## AZAMİ yük sayısını (=yüzde tavanını, 1 yük = %1) belirler - tier'e göre
## büyür (bkz. player.gd _apply_tabanca_tier). 0 = bu silah mark uygulamaz
## (diğer tüm silahler).
var mark_max_stacks: int = 0

## Hançer: her saldırıda düşmanda "kanama yükü" bırakır - bleed_stacks_per_hit
## kadar yük eklenir (bleed_max_stacks'e kadar, aşmaz), her yük saniyede bir
## bleed_tick_damage_per_stack kadar hasar verir (bkz. enemy.gd apply_bleed).
## bleed_max_stacks = 0 -> bu silah kanama uygulamaz (diğer tüm silahler).
var bleed_tick_damage_per_stack: float = 0.0
var bleed_stacks_per_hit: int = 1
var bleed_max_stacks: int = 0

## Pençe: SADECE bu silahın kendi hasarından can çalar - oyuncunun genel
## lifesteal_percent/on_damage_dealt pasifinden (bkz. player.gd, kart/eşya
## can çalması) TAMAMEN bağımsız, ayrı bir silaha-özel yüzde. Ön-mitigasyon
## (zırhtan ÖNCEKİ) final_damage üzerinden hesaplanır - enemy.take_damage()'ı
## mitigasyon SONRASI değeri geri döndürecek şekilde değiştirmek çok daha
## invaziv olacağı için bilinçli bir basitleştirme (bkz. Pençeler
## Özellikleri.txt). 0 = bu silah can emmez (diğer tüm silahler).
## Kullanıcı isteği: "Pençenin can çalması can emme olarak gösterilecek ve
## hesaplanacak, yani verilen hasarın %'liği olarak can yenileyecek" - bu alan
## artık ("Can Emme") verilen hasarın YÜZDESİ (0.011 = %1.1): her isabette
## hasar * lifesteal_percent kadar can yenilenir (bkz. _apply_weapon_lifesteal).
## Alan adı (lifesteal_percent) player.gd/weapon_select/tooltip'lerle uyum için
## korundu, sadece anlamı olasılıktan hasar-yüzdesine döndü.
var lifesteal_percent: float = 0.0

## Tüfeğin delici mermisi: birincil hedeften SONRA bu kadar EK düşmana daha
## çarpar (0 = delmez, diğer tüm silahler), her ek isabette hasar
## pierce_damage_percent'e düşer (birincil hedef her zaman TAM hasar alır) -
## bkz. projectile.gd.
@export var pierce_count: int = 0
@export var pierce_damage_percent: float = 0.3
## Efekt sprite'ı saldırı yönüyle tam örtüşmeyebilir (ör. Tabanca'nın
## efekti "sağa 90°" düzeltme istiyor) - saldırı yönüne eklenen sabit bir
## düzeltme açısı (radyan).
@export var muzzle_flash_rotation_offset: float = 0.0

## Yakın dövüş modu: mermi yerine anında pençe vuruşu - hedefe
## tam hasar, hedefin çevresindeki düşmanlara (melee_aoe_radius içinde) hafif
## alan hasarı uygulanır ve savuruş efekti (fx_slash.gd) çizilir.
@export var melee: bool = false
@export var melee_aoe_radius: float = 60.0
@export var melee_aoe_damage_percent: float = 0.5
## Ana hedefe uygulanan hasar kaç parçaya bölünüp art arda verilecek (ör.
## Assasin Çocuk: 1 yerine 3 - "-30" yerine sırayla "-10","-10","-10").
## 1 = eski davranış, tek seferde tam hasar.
@export var melee_hit_segments: int = 1
@export var melee_hit_segment_delay: float = 0.1 ## parçalar arası saniye

## Yaratığa isabet edince çıkan isabet görseli - ör. Uzunkılıç için
## "İsabet 2", Topuz/Pençe için kan efekti (bkz. "isabet halinde efektler"
## klasörü, Ne neye uygulanacak.txt). "" /null olan tüm diğer silahlerde
## no-op, mevcut savuruş efektine (_spawn_slash_fx) hiç dokunmaz.
## GÜNCELLEME (kullanıcı düzeltmesi): ilk denemede bu efekt yanlışlıkla
## _spawn_slash_fx ile AYNI "silahın SAVURULDUĞU nokta" formülünü
## kullanıyordu - kullanıcı bunu düzeltti: "isabet halinde efektleri silah
## efektlerinden bağımsız ve ayrıdır, onlar yaratıkların üzerinde çıkarlar...
## yaratığın üstünde görünmeleri gerekiyor kılıcı takip etmeleri değil."
## Artık _spawn_melee_hit_fx, savuruş efektinden TAMAMEN BAĞIMSIZ olarak
## doğrudan hedefin (yaratığın) o anki gerçek konumunu (target_pos_at_attack)
## kullanır - bkz. _spawn_melee_hit_fx, çağrı yeri (_fire_at).
@export var hit_impact_scene: PackedScene
## Kullanıcı bildirimi: "çok ufak olmuş kılıçla topuzun isabet halinde
## efekti" - bu efektlerin sahneleri (fx_hit_slash_streak.tscn/
## fx_hit_blood_1.tscn) menzilli silahlerle (Tüfek/Bumerang) PAYLAŞILIYOR,
## o yüzden paylaşılan sahnenin taban ölçeğini büyütmek onları da büyütürdü.
## Bunun yerine SADECE bu silahin isabet efektine uygulanan ayrı bir çarpan -
## 1.0 (varsayılan, diğer tüm silahlerde) hiçbir şeyi değiştirmez.
@export var hit_impact_scale_mult: float = 1.0
## BULUNAN GERÇEK BUG (kullanıcı: "kılıcın saldırı animasyonu ve efekti ayrı
## yerlerde... hedefin üzerine gidip vurması gerekiyor"): isabet efekti
## sprite'ları (İsabet 2/mini kan efektleri) kendi 128x64 / 32x32 tuvalleri
## İÇİNDE ORTALANMIŞ DEĞİL - piksel analizi gösterdi ki içerik kareden kareye
## sabit bir açıda (aşağı-soldan yukarı-sağa) kayıyor, yani efekt HER ZAMAN
## aynı sabit yönde "savruluyormuş" gibi görünüyordu, gerçek saldırı yönünden
## TAMAMEN BAĞIMSIZ (rotasyon hiç ayarlanmıyordu). Bu yüzden kılıç örneğin
## aşağıya doğru vursa bile efekt hep yukarı-sağa doğru "kayıyordu" - ikon
## doğru yerde ama efekt yanlış YÖNDE göründüğü için "ayrı yerdeymiş" gibi
## algılanıyordu. Radyan cinsinden, silahın gerçek saldırı yönüne (direction.
## angle()) eklenen bir düzeltme açısı - piksel-tabanlı bir TAHMİN (görsel
## olarak doğrulanamadı, gerekirse ince ayar istenebilir). 0.0 (varsayılan,
## diğer tüm silahlerde) hiçbir şeyi değiştirmez.
@export var hit_impact_rotation_offset: float = 0.0

## Yakın dövüş ikonunun "dinlenme" (saldırı dışı) rotasyonu, derece cinsinden.
## Bıçak/Pençe'nin sanatı zaten dikey/yukarı bakan çizildiği için varsayılan
## 0° onlarda hiçbir şeyi değiştirmiyor. Uzunkılıç/Topuz'un sanatı YATAY
## çizili (uç sağa bakıyor) - kullanıcı bildirimi: "kılıç ve topuz yan
## duruyor, dik durmasını istiyorum kafanın üstündeyken" - bu iki silahte
## -90 verilerek uç yukarı baksın diye düzeltiliyor. SADECE dinlenme
## pozundaki rotasyonu etkiler; sprite_forward_angle_deg (saldırı yönü
## hesaplaması, _do_melee_swing) hâlâ ORİJİNAL (döndürülmemiş) sanata göre
## kalibreli, ona hiç dokunulmuyor.
@export var melee_icon_rest_rotation_deg: float = 0.0

## Sınıf ayrımı: yakıncı (melee) silahlar menzil kartlarından bu katsayı
## kadar etkilenir (+60 menzil kartı pençeye yalnızca +21 verir). Menzil
## büyüdükçe savuruş efekti de aynı oranda büyür (_spawn_slash_fx).
const MELEE_RANGE_BONUS_FACTOR := 0.35

## _do_melee_swing (ikon) ve _spawn_slash_fx (efekt) ikisi de bu değeri
## kullanır ki "Z" çizen savuruşun ikonun SON sıçradığı noktasıyla efektin
## belirdiği nokta HER ZAMAN birebir örtüşsün. Kullanıcı bildirimi: "hasar
## verme efekti silahın SAVURULDUĞU yerde olması gerekiyor, direkt yaratığın
## üzerinde değil" - efekt eskiden bu zigzag kaymasını (bkz. _melee_final_
## swing_offset) hiç hesaba katmıyordu, ikon 24px yana sıçrarken efekt tam
## ortada (kaymasız) kalıyordu, bu yüzden ikisi görsel olarak kopuk dururdu.
const MELEE_ZIGZAG_SPREAD := 24.0

## Menzilli (projectile) mermi görselinin ince ayarı - karaktere özel sprite
## kullanan mermilerde (ör. Büyücü Kız'ın kuyruklu yıldızı) sprite'ın çizili
## "ucu" saldırı yönüyle tam örtüşmeyebilir; rotation_offset bunu düzeltir.
## scale_mult mermi görselini büyütüp küçültür. İkisi de Characters.DEFS'ten
## (ve varsa CombatTuning'den) player.gd tarafından ayarlanır.
@export var ranged_projectile_rotation_offset: float = 0.0
@export var ranged_projectile_scale_mult: float = 1.0
## Yakın dövüş savuruş efektinin genel büyüklük çarpanı (menzil büyümesinden
## bağımsız, sabit bir ince ayar - bkz. CombatTuning debug paneli).
var melee_slash_fx_scale_mult: float = 1.0

## The following only apply to weapons that have a visible "Icon" sprite
## child (staves bought from the shop) - the base weapon has no sprite and
## just ignores all of it.
## All weapon icons fan out above the character like rays from a pivot point
## sitting just above the overhead health/shield bar (which sits at y = -92,
## see overhead_bar.gd). Player re-lays out the whole fan (see
## _reposition_weapon_icons) every time a weapon is added, so with 1 weapon
## it sits dead center, with 2+ they spread out evenly and symmetrically.
@export var hover_offset: Vector2 = Vector2(0, -100) ## the fan's pivot point
@export var fan_radius: float = 46.0 ## distance from the pivot to every icon
## Icons are drawn pointing at this angle at rotation 0 (degrees, measured
## the same way Vector2.angle() does), so we know the correction needed to
## make them visually aim at the target. Measured from the actual staff
## icon art (tip vs. handle pixels): both staves point at ~-48.5°.
@export var sprite_forward_angle_deg: float = -48.5
@export var recoil_distance: float = 10.0

## Asalar (fire/lightning) her açıda döndürülse de tuhaf durmuyor - ama
## Tabanca gibi belirgin bir "üst/alt"ı olan ikonlarda sola dönünce silah
## baş aşağı gibi görünüyor. true ise (Tabanca'da açık) sola bakarken ikon
## döndürülmez, bunun yerine yatay aynalanır (flip_h) - sağda hep normal
## halinde, solda hep aynalı görünür, hiçbir zaman "ters" durmaz.
@export var mirror_icon_when_aiming_left: bool = false

## Yay (Bow): atış artık FireTimer'ın kendi zamanlamasından DEĞİL, "çekiliş"
## animasyonunun BİTMESİNDEN tetiklenir - yay tam çekilmeden ok fırlatılamaz.
## _process() her karede _draw_ready true VE bir hedef varsa hemen ateş eder;
## _fire_at() hasar/delme/kritik mantığına hiç dokunulmadan aynen çalışır,
## sadece SONUNDA yeni bir çekiliş döngüsü başlatır (bkz. _start_draw_cycle,
## _on_draw_finished). fire_timer bu modda kullanılmaz (bkz. _on_fire_timer_
## timeout'taki erken çıkış).
@export var draw_before_fire: bool = false
## "draw" animasyonunun DOĞAL (1x hız) süresi - ateş hızı tier/yükseltmeyle
## kısaldıkça (bkz. player.gd _apply_yay_tier) animasyon da orantılı
## hızlandırılır ki TÜM atış döngüsü (çekiliş+atış) her zaman güncel ateş
## hızına denk gelsin (üst sınır draw_anim_speed_scale_max ile aşırı
## hızlanmayı engeller). 0 = hızlandırma yapılmaz.
@export var draw_anim_base_duration: float = 0.0
@export var draw_anim_speed_scale_max: float = 8.0
## DrawSound'un pitch_scale = 1.0 olduğu referans ateş aralığı (saniye) -
## saldırı hızı arttıkça (ateş aralığı kısaldıkça) perde de orantılı yükselir
## ("hızlı atarsa çekiş sesi de hızlı oynar"), üst sınır draw_sound_pitch_
## scale_max ile aşırı tizleşmeyi engeller (ses bu noktada süresinden erken
## kesilip yeniden başlayabilir - normal, döngü ne kadar hızlıysa o kadar sık
## kesilir). 0 = hızlandırma yapılmaz.
@export var draw_sound_base_duration: float = 0.0
@export var draw_sound_pitch_scale_max: float = 3.0
## NOT (kullanıcı bildirimi: "arkada sürekli çalan, benim eklemediğim bir kalkan sesi ... savaşta
## yay kullanırken oluyordu"): weapon_yay.tscn'in DrawSound'u kullanıcının bilerek sildiği
## yay_draw.mp3'ün yerine konmuş 8,95 sn'lik bir "Channel Power Up LOOP" dosyasıydı - her atışta
## baştan başlatılıp savaş boyunca sürekli bir vızıltı gibi çalıyordu. Yayın çekme sesi artık YOK
## (düğüm sahneden kaldırıldı, bu değişken null kalır ve aşağıdaki `if draw_sound` korumaları
## sessizce atlar). Yeni bir çekme sesi eklenecekse KISA (~1 sn altı, döngü olmayan) bir dosya olmalı
## (bkz. tests/test_weapon_sounds_not_long.gd).
@onready var draw_sound: AudioStreamPlayer2D = get_node_or_null("DrawSound")
## Ok görseli çekiliş sırasında yayın üzerinde durur - atış anında gizlenir,
## bir sonraki çekilişte tekrar görünür olur (bkz. weapon_yay.tscn Icon/
## HeldArrow).
@onready var held_arrow: Node2D = get_node_or_null("Icon/HeldArrow")
## Ok'un "draw" animasyonunun HER karesinde (frame_changed) alacağı yerel X
## konumu - ipin gerçekten geriye çekildiği görünsün diye kare kare ölçülmüş
## (draw1..draw5.png piksel analizi: ip ucu x=101,89,77,63,43 -> frame0'a göre
## 0,-12,-24,-38,-58). Boşsa (diğer tüm silahlerde) hiç uygulanmaz, ok sabit
## kalır.
@export var held_arrow_offsets: Array[float] = []
var _draw_ready: bool = false
var _frame_changed_connected: bool = false

## Yay pasifi (kullanıcı isteği): her 3. saldırıdan sonra fazladan 1 kez ok
## atar - yayın dönüm noktası (3/5/7/10) her seviyeye ulaştıkça bu fazladan
## ok sayısı +1 artar (bkz. player.gd _apply_yay_tier -> set_yay_multishot_
## bonus). 0 = pasif kapalı (diğer tüm silahlerde no-op).
var yay_multishot_bonus: int = 0
var _yay_attack_counter: int = 0
const YAY_MULTISHOT_TRIGGER_EVERY := 3
const YAY_MULTISHOT_VISUAL_DELAY := 0.09

func set_yay_multishot_bonus(bonus: int) -> void:
	yay_multishot_bonus = max(0, bonus)


## Her gerçek ok atışından sonra çağrılır (hem draw_before_fire modundaki
## _process() dalından hem de - ileride gerekirse - _on_fire_timer_timeout'tan)
## - 3 atışta bir, dönüm noktasına göre büyüyen sayıda fazladan ok fırlatır.
func _process_yay_multishot_passive(target: Node2D) -> void:
	if yay_multishot_bonus <= 0 or not target or not is_instance_valid(target):
		return
	_yay_attack_counter += 1
	if _yay_attack_counter < YAY_MULTISHOT_TRIGGER_EVERY:
		return
	_yay_attack_counter = 0
	for i in range(yay_multishot_bonus):
		_fire_at_delayed(target, YAY_MULTISHOT_VISUAL_DELAY * float(i + 1))

var rage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
## #56 DÜZELTME (Talon ULTİ "Devleşme"): "saldırılarının vuruş alanı (menzil
## değil) 2 katına çıkar" - melee_range'e (silahın hedef ARAMA menzili)
## DOKUNULMUYOR, sadece isabet alanının (melee_aoe_radius) etrafındaki
## sıçrama yarıçapı bu çarpanla büyütülüyor. rage_multiplier/fire_rate_
## multiplier ile AYNI desen: varsayılan 1.0, beceri bitince player.gd
## _end_skill_effects() tarafından geri 1.0'a çekilir.
var aoe_radius_multiplier: float = 1.0
var _fan_angle_deg: float = 0.0
var _icon_flipped: bool = false

## Base stats as configured on the scene, captured before any level-up bonus
## is layered on top - lets every weapon (base + bought staves) benefit from
## the same upgrade cards instead of only the base weapon.
var _base_attack_range: float = 0.0
var _base_damage: float = 0.0
var _base_fire_rate: float = 0.0
var _base_crit_chance: float = 0.0
var _base_crit_damage: float = 0.0

## Shop-bought staves (fire_staff/lightning_staff) also have their own shop
## level (1-30, separate from the shared level-up cards) - these two combine
## with the card bonus above so both systems stack instead of overriding
## each other. See set_shop_damage_bonus / set_shop_fire_rate_mult.
var _card_damage_bonus: float = 0.0
var _shop_damage_bonus: float = 0.0
var _card_fire_rate_mult: float = 1.0
var _shop_fire_rate_mult: float = 1.0

## "Saldırı gücü" (oyuncunun topladığı Hasar kartlarının toplamı,
## player.damage_bonus) bu silahın hasarına ne oranda yansır - varsayılan 1.0
## (=%100, herkesin aldığı normal pay, davranış hiçbir mevcut silahte
## değişmez). Tüftüf gibi bazı silahlerde bu oran özel olarak düşürülür (bkz.
## tüftüf özellikleri.txt "%50 saldırı gücü", player.gd _apply_tuftuf_tier).
## Kullanıcı isteği: "her silahın saldırı gücü oranını %10 azalt VE silahların
## başlangıç hasarlarını kaldır" - her silah sahnesinde bu oran ×0.9 edildi
## VE kendi sabit "damage" (başlangıç/taban) değeri 0'a çekildi (bkz. aşağıdaki
## _base_damage). Oyuncunun KENDİ taban "Hasar" statı (player.gd damage_bonus,
## varsayılan 10.0) buna dahil DEĞİL, o hâlâ bu oran üzerinden tam olarak
## yansıyor - yani silahsız/kartsız bir karakter hâlâ hasar verir, sadece
## silahın KENDİNE ÖZGÜ ekstra sabit hasarı kalktı.
@export var card_damage_bonus_ratio: float = 1.0

## Tier/dükkan seviyesinden gelen ÇARPIMSAL hasar bonusu (ör. Arcane
## Asası'nın dönüm noktası bonusları: tier 3/5/7/10'da +%8, kümülatif) -
## toplamsal _shop_damage_bonus YETMEZ çünkü bu çarpan card_damage_bonus'u
## (saldırı gücü payını) da kapsamalı. Varsayılan 1.0 = hiçbir etkisi yok,
## diğer tüm silahlerde davranış değişmez - bkz. set_tier_damage_mult().
var _tier_damage_mult: float = 1.0

@onready var fire_timer: Timer = $FireTimer
## Sprite2D (çoğu silah) VEYA AnimatedSprite2D (Yay - çekiliş animasyonu için)
## olabildiğinden artık türü sabitlenmemiş - kullanılan tüm üyeler (.texture
## hariç, o zaten tier_icon_textures boşken hiç çağrılmıyor) ikisinde de ortak.
@onready var icon_sprite = get_node_or_null("Icon")
var shadow_sprite: Sprite2D
var _icon_base_scale: Vector2 = Vector2.ONE
var _punch_tween: Tween = null
## Ikonun dokudan okunan GERÇEK (width, height) piksel boyutu - gölgenin
## silahın GERÇEK ŞEKLİNE göre (ince silah -> ince gölge, yuvarlak/kalın
## silah -> daha yuvarlak gölge) uzayıp genişlemesi için ikisi de saklanıyor,
## sadece genişlik yetmiyor (bkz. kullanıcı isteği: "bazı silahlar çok ince
## bazıları kalın veya yuvarlak").
var _icon_pixel_size: Vector2 = Vector2(64.0, 64.0)


## icon_sprite Sprite2D VEYA AnimatedSprite2D olabilir - ikisinde de dokunun
## gerçek (width, height) piksel boyutunu okur (yoksa 64x64 varsayılana düşer).
## ÖNEMLİ: tüm silah ikonları KARE (250x250 / 200x200) tuvaller üzerine
## çizilmiş - tuvalin tam boyutunu kullanmak "ince kılıç" ile "yuvarlak
## topuz"u AYNI (kare) oranda gösterirdi (kullanıcı isteği: "bazı silahlar
## çok ince bazıları kalın veya yuvarlak" - bunu yansıtmak için tuvalin
## KENDİSİ değil, içindeki GERÇEK GÖRÜNÜR (şeffaf olmayan) piksel alanının
## sıkı sınır kutusu (get_used_rect) ölçülüyor).
func _measure_icon_pixel_size() -> Vector2:
	var tex: Texture2D = null
	if icon_sprite is Sprite2D and icon_sprite.texture:
		tex = icon_sprite.texture
	elif icon_sprite is AnimatedSprite2D and icon_sprite.sprite_frames:
		var anim_name: StringName = icon_sprite.animation
		if anim_name != &"" and icon_sprite.sprite_frames.has_animation(anim_name):
			tex = icon_sprite.sprite_frames.get_frame_texture(anim_name, icon_sprite.frame)
	if not tex:
		return Vector2(64.0, 64.0)
	var img: Image = tex.get_image()
	if img:
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			return Vector2(used.size)
	return tex.get_size()


## Optional marker placed at the icon's visual tip (e.g. the wand's end) so
## hitscan effects originate from there instead of the icon's center.
@onready var muzzle: Node2D = get_node_or_null("Icon/Muzzle")


## Arcane Asası pasifleri (bkz. kullanıcı isteği):
## 1) "Canı %30'un altındaki düşmanlara %30 daha fazla hasar" - _fire_at()
##    içinde final_damage'a uygulanıyor.
## 2) menzil içindeki rastgele düşmanlara aniden 10 kere saldırır - bkz.
##    add_arcane_stack/_process_arcane_burst_cooldown üstündeki DÜZELTME
##    notu (kullanıcı isteği: "kendi öldürdüğü değil etrafta ölen
##    düşmanlara göre stacklensin, 6sn bekleme süresi olsun").
const ARCANE_EXECUTE_HP_THRESHOLD := 0.30
const ARCANE_EXECUTE_DAMAGE_MULT := 1.3
const ARCANE_BURST_ATTACK_COUNT := 10
## DÜZELTME (kullanıcı bildirimi: "Arcane asası kendi öldürdüğü değil
## etrafta ölen düşmanlara göre stacklensin (belli bi stackten sonra
## ateşleme yapıyordu çünkü) ve bunun bekleme süresi 6 saniye olsun ve bu
## bekleme süresi bekleme süresinde azalmaya göre azalabilsin. Her arcane
## asasının kendi bekleme süresi ve kendi etrafta yaratık ölünce stack
## birikmesi olsun") - eski sistem SADECE bu silahın KENDİ mermisiyle
## öldürdüğü düşmanları sayıyordu (bkz. eski notify_kill), bu yüzden nadir/
## tahmin edilemezdi. Artık player.gd _distribute_arcane_stack() (bkz. o
## dosyadaki on_enemy_killed/_remote çağrıları) menzil (attack_range)
## içindeki SAHİP OLUNAN Arcane kopyalarından rastgele BİRİNE (kim
## öldürürse öldürsün, "1 ölüm 5 asaya da stack vermemeli") add_arcane_
## stack() ile 1 stack ekliyor; her kopya KENDİ stack sayacını ve KENDİ
## 6sn'lik (cooldown_reduction_percent'e tabi) bekleme süresini bağımsız
## işletip hazır olduğunda birikmiş TÜM stack'i tek seferde patlatıyor.
const ARCANE_BURST_COOLDOWN := 8.0
var _is_arcane: bool = false
var _arcane_stacks: int = 0
var _arcane_burst_cooldown_timer: float = 0.0
var _is_uzunkilic: bool = false
var _orbit_angle: float = 0.0
var _hit_cooldowns: Dictionary = {}
var _trail_timer: float = 0.0
const HitClawFxScene := preload("res://scenes/fx_pence_slash.tscn")
## Trail sahne yolu artık weapon_orbit_math.gd'de TEK yerde (TRAIL_SCENE_PATH)
## - burada elle ikinci bir referans tutulmuyor (bkz. o dosyanın başındaki
## kök neden notu).


## player.gd _distribute_arcane_stack() çağırır (bkz. dosya başındaki
## ARCANE_BURST_COOLDOWN üstündeki DÜZELTME notu) - SADECE Arcane Asası bu
## metodu anlamlı kullanır, diğer tüm silahlerde no-op (has_method
## kontrolüyle her silahta çağrılabilir olsa da _is_arcane false olduğu
## için hiçbir şey yapmaz).
func add_arcane_stack() -> void:
	if not _is_arcane:
		return
	_arcane_stacks += 1


## _process()'ten her karede çağrılır - bkz. ARCANE_BURST_COOLDOWN üstündeki
## DÜZELTME notu. Bekleme süresi dolduğunda VE en az 1 stack birikmişse
## patlamayı tetikleyip stack'i sıfırlıyor, sonra bekleme süresini (oyuncunun
## cooldown_reduction_percent'iyle ölçeklenmiş) yeniden başlatıyor - stack
## yoksa bekleme süresi dolsa bile hiçbir şey olmaz (yakınında kimse
## ölmediyse "boşa" ateş etmez).
func _process_arcane_burst_cooldown(delta: float) -> void:
	if not _is_arcane:
		return
	if _arcane_burst_cooldown_timer > 0.0:
		_arcane_burst_cooldown_timer -= delta
		return
	if _arcane_stacks <= 0:
		return
	_arcane_stacks = 0
	var reduction: float = 0.0
	var owner_char: Node = get_parent()
	if owner_char and "cooldown_reduction_percent" in owner_char:
		reduction = owner_char.cooldown_reduction_percent
	_arcane_burst_cooldown_timer = ARCANE_BURST_COOLDOWN * (1.0 - reduction)
	_trigger_arcane_burst()


## Menzil içindeki düşmanlardan rastgele ARCANE_BURST_ATTACK_COUNT tanesine
## (yeterince yoksa hepsine) art arda normal bir atış gönderir - _fire_at()
## zaten dışarıdan (bkz. _fire_at_delayed) tekrar tekrar çağrılabilecek
## şekilde tasarlı, burada da aynı şekilde kullanılıyor.
func _trigger_arcane_burst() -> void:
	var origin: Vector2 = _attack_origin()
	var in_range: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		if attack_range <= 0.0 or origin.distance_to(e.global_position) <= attack_range:
			in_range.append(e)
	if in_range.is_empty():
		return
	in_range.shuffle()
	var count: int = min(ARCANE_BURST_ATTACK_COUNT, in_range.size())
	for i in range(count):
		_fire_at(in_range[i])


## Silah TÜRÜ tespiti için kaynak metin. BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-24: "saldırı hızı yükseltmeme rağmen
## azaldı / atış hızı ve saldırı hızı farklı algılanıyor" araştırmasında ölçüldü): tür eskiden düğüm ADINDAN ("WeaponYay"
## vb.) çıkarılıyordu, ama aynı silahın dükkandan alınan İKİNCİ kopyası aynı üst düğüme eklenince Godot çakışan adı
## "@Node2D@23" gibi bir şeyle değiştiriyor - ikinci yay %15 yavaşlatmayı almıyordu (ilk yay 0.728 sn, alınan yay 0.619 sn)
## ve ikinci bir Uzunkılıç/asa kopyası kendi özel davranışını tamamen kaybederdi. Sahne dosya yolu çakışmadan etkilenmez.
var _type_src: String = ""


func _ready() -> void:
	_type_src = scene_file_path if scene_file_path != "" else String(name)
	_is_uzunkilic = _type_src.containsn("uzunkilic") or _type_src.containsn("kılıç") or _type_src.containsn("kilic")
	if _is_uzunkilic:
		## Kullanıcı isteği: "her silahın saldırı gücü oranını %10 azalt" -
		## eskiden 1.8, %10 azaltılmış hali 1.62.
		card_damage_bonus_ratio = 1.62
		melee = false
		attack_range = 115.0
	_is_arcane = _type_src.containsn("arcane")
	if _type_src.containsn("yay") or _type_src.containsn("bow"):
		# Firing rate (saldırı hızı) %15 azaltılıyor (yani atış aralığı saniyesi %15 artıyor)
		fire_rate = fire_rate / 0.85
	
	# Menzilli silahların menzilini %10 azalt
	if not melee and not _is_uzunkilic:
		attack_range *= 0.9
		
	_base_attack_range = attack_range
	_base_damage = damage
	_base_fire_rate = fire_rate
	_base_crit_chance = crit_chance
	_base_crit_damage = crit_damage
	fire_timer.wait_time = fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	if icon_sprite:
		# Asalar için yeni piksel-art görsellerini dinamik yükleme (tscn kilitlerini aşmak için)
		# Yeni 32x32 piksel görsellerin aşırı küçülmesini önlemek için ikon ölçeğini (0.99, 0.99) yapıyoruz.
		if _type_src.containsn("arcane"):
			icon_sprite.texture = load("res://assets/weapons/arcane/icon_v3.png")
			icon_sprite.scale = Vector2(0.99, 0.99)
		elif _type_src.containsn("fire"):
			icon_sprite.texture = load("res://assets/weapons/fire/firestaff_icon_v3.png")
			icon_sprite.scale = Vector2(0.99, 0.99)
		elif _type_src.containsn("lightning"):
			icon_sprite.texture = load("res://assets/weapons/lightning/icon_v3.png")
			icon_sprite.scale = Vector2(0.99, 0.99)
		elif _type_src.containsn("buz"):
			icon_sprite.texture = load("res://assets/weapons/buz_asasi/icon_v3.png")
			icon_sprite.scale = Vector2(0.99, 0.99)
		else:
			# Diğer silahların boyutunu %10 küçült (çarpımsal)
			icon_sprite.scale *= 0.9
		## Kullanıcı isteği (2026-09-25): tüm silahlar %15 küçük - uzak kuklada AYNI çarpan (bkz. WeaponOrbitMath).
		icon_sprite.scale *= WeaponOrbitMath.ICON_SIZE_MULT
		_icon_base_scale = icon_sprite.scale ## ateş "punch"ının döndüğü SABİT taban (bkz. WeaponJuice)

		top_level = true
		_target_local_offset = hover_offset + _fan_offset()
		var parent = get_parent()
		if parent and parent is Node2D:
			global_position = parent.global_position + _target_local_offset
		else:
			position = _target_local_offset
		_hover_bob_phase = randf_range(0.0, TAU)
		
		shadow_sprite = Sprite2D.new()
		shadow_sprite.set_script(preload("res://scripts/shadow_blob.gd"))
		shadow_sprite.top_level = true
		## shadow_blob.gd PAYLAŞILAN bir script (karakterin kendi Shadow
		## node'u da aynısını kullanıyor) - o yüzden alpha'yı script'in
		## kendisinde DEĞİL, sadece BU node'un modulate'ında değiştiriyoruz
		## (karakterin kendi gölgesine dokunmadan). SHADOW_TRANSPARENCY:
		## kullanıcı isteği "%60 saydam olsun" - saydamlık YÜZDESİ, opaklık
		## DEĞİL, o yüzden modulate.a = 1.0 - saydamlık (yüksek saydamlık ->
		## düşük opaklık/alpha). Önceki deneme (modulate.a'yı doğrudan
		## yüzdeye eşitlemek) TERSİ etkiyi vermişti ("çok opak olmuş").
		const SHADOW_TRANSPARENCY := 0.6
		shadow_sprite.modulate = Color(1, 1, 1, 1.0 - SHADOW_TRANSPARENCY)
		## 2026-09-25: gölge KARAKTERİN ALTINDA çizilir (ayak gölgesiyle aynı katman, sahibin "Shadow" düğümünün hemen
		## arkası) - yukarıdaki slotların gölgesi artık karakterin arkasındaki zemine iniyor (bkz. WeaponOrbitMath.
		## hover_shadow_gap), silahın çocuğu kalsaydı karakterin bacaklarının ÜSTÜNE çizilirdi. top_level olduğu için
		## konumu yine bu script belirler; silah silinince _exit_tree gölgeyi de siler.
		## (Ertelenir: sahip o an çocuk kuruyor olabilir - "Parent node is busy".)
		_attach_shadow_under_owner.call_deferred()
		## KRİTİK: negatif z_index KULLANMA - top_level=true node'lar bile
		## z_index'i EBEVEYNDEN (Player, main.tscn'de z_index=1) miras alır,
		## yani z_index=-1 => efektif z = 1-1 = 0 = HARİTANIN/zeminin efektif
		## z'siyle (Harita/TileMapLayer, varsayılan 0) AYNI seviye - Harita
		## Player'dan SONRA sahneye eklendiği için eşit z'de zemin ÜSTTE
		## çiziliyor ve gölge tamamen zemin altında kalıp GÖRÜNMEZ oluyordu
		## (kullanıcı bildirimi: "hiçbir şey görünmüyor" - bu asıl sebepti).
		## Doğru çözüm: z_index'e hiç dokunma (aynı efektif seviyede kal,
		## Player/İkon ile birlikte zeminin ÜSTÜNDE kalır), sadece kardeş
		## node sıralamasında İkon'dan ÖNCE (index 0) konumlandır - böylece
		## aynı z katmanında ama İkonun ARKASINDA çizilir. (Yukarıda: artık sahibin ayak gölgesinin yanına taşınıyor.)
		## Ikonun gercek piksel genisligi (dokudan okunur) - sadece icon.scale'e
		## bakmak yetmez, cunku her silahin kaynak dokusu farkli boyutta.
		## Bu, golgenin ikona gore orantili olmasini sagliyor.
		_icon_pixel_size = _measure_icon_pixel_size()
		
		## melee_icon_rest_rotation_deg .tscn'den @export ile geliyor, yani
		## _ready() çalışana kadar zaten atanmış olur - configure_melee()'nin
		## "melee = true" ataması ise BUNDAN SONRA (buy_weapon_copy içinde
		## add_child()'dan sonra) geldiği için burada "melee" bayrağına değil,
		## doğrudan bu değere bakılıyor (Uzunkılıç/Topuz dışında hep 0.0, no-op).
		if melee_icon_rest_rotation_deg != 0.0:
			icon_sprite.rotation = deg_to_rad(melee_icon_rest_rotation_deg)
	if max_ammo > 0:
		current_ammo = max_ammo
	if reload_anim:
		reload_anim.visible = false
	if draw_before_fire:
		_start_draw_cycle()
	## Fizik interpolasyonu (bkz. physics_interp.gd): hover takibi ve gölge _physics_process'te
	## -> kök + shadow_sprite AÇIK; icon_sprite KAPALI (nişan dönüşü _process'te, _update_aim).
	PhysicsInterp.opt_in(self, func(c: Node) -> bool: return c == shadow_sprite)


## Kalıcı "menzil" kartı bonusundan SONRA üstüne binen geçici bir çarpan -
## şu an sadece Şovalye (Paladin) ultisi kullanıyor (bkz. player.gd
## _skill_paladin_ulti, +%30). Kalıcı bonus muhasebesini (set_range_bonus)
## hiç bozmadan üstüne binmesi için son kullanılan bonus değeri ayrıca
## saklanıyor (_last_range_bonus) - set_temp_range_mult tek başına
## çağrıldığında da (bonus tekrar verilmeden) doğru sonucu hesaplayabilsin.
var _temp_range_mult: float = 1.0
var _last_range_bonus: float = 0.0


## Called by Player whenever the "menzil" upgrade changes, and once when a
## newly-bought weapon is attached, so every weapon shares the same range
## bonus. attack_range = 0 keeps meaning "unlimited" regardless of bonus.
## bonus = KESİR (0.12 = taban menzilin +%12'si); yakıncı silahlarda MELEE_RANGE_BONUS_FACTOR kadar payı uygulanır.
func set_range_bonus(bonus: float) -> void:
	_last_range_bonus = bonus
	_recompute_attack_range()


func set_temp_range_mult(mult: float) -> void:
	_temp_range_mult = mult
	_recompute_attack_range()


func _recompute_attack_range() -> void:
	if _base_attack_range <= 0.0:
		return
	## Yakıncı silahlar menzil bonusundan kısılmış pay alır.
	var effective_bonus: float = _last_range_bonus * (MELEE_RANGE_BONUS_FACTOR if melee else 1.0)
	## weapon_range_bonus artık KESİR (0.12 = +%12, bkz. player.gd) - taban menzil üstüne çarpan olarak biner.
	attack_range = _base_attack_range * (1.0 + effective_bonus) * _temp_range_mult


## The following four are the same idea as set_range_bonus, but for the
## "hasar"/"ateş hızı"/"kritik oran"/"kritik hasar" level-up cards, so every
## weapon the player owns (base + bought staves) benefits from every pick,
## not just the base weapon.
func set_damage_bonus(bonus: float) -> void:
	_card_damage_bonus = bonus * card_damage_bonus_ratio
	_recompute_damage()


func set_fire_rate_mult(mult: float) -> void:
	_card_fire_rate_mult = mult
	fire_rate = max(0.15, _base_fire_rate * _card_fire_rate_mult * _shop_fire_rate_mult)


## Called by Player.set_weapon_shop_level() for weapons bought/leveled from
## the shop (fire_staff/lightning_staff) - stacks on top of whatever the
## level-up cards have already granted.
func set_shop_damage_bonus(bonus: float) -> void:
	_shop_damage_bonus = bonus
	_recompute_damage()


## Tier/dükkan seviyesi değiştiğinde (ör. Arcane Asası dönüm noktaları)
## çağrılır - saklanan çarpan, sonraki HER set_damage_bonus/set_shop_damage_
## bonus çağrısında (ör. yeni bir Hasar kartı alındığında) otomatik yeniden
## uygulanır, ayrı bir tetikleyiciye gerek kalmaz.
func set_tier_damage_mult(mult: float) -> void:
	_tier_damage_mult = mult
	_recompute_damage()


func _recompute_damage() -> void:
	damage = (_base_damage + _card_damage_bonus + _shop_damage_bonus) * _tier_damage_mult


func set_shop_fire_rate_mult(mult: float) -> void:
	_shop_fire_rate_mult = mult
	fire_rate = max(0.15, _base_fire_rate * _card_fire_rate_mult * _shop_fire_rate_mult)


## weapon_crit_chance_bonus/weapon_crit_damage_bonus: Crossbow gibi silaha özel
## EK kritik bonusları (diğer tüm silahlerde 0 - no-op) - oyuncunun kart
## bonusuna (bonus parametresi) toplamsal olarak eklenir, üzerine yazmaz.
var weapon_crit_chance_bonus: float = 0.0
var weapon_crit_damage_bonus: float = 0.0

func set_crit_chance_bonus(bonus: float) -> void:
	crit_chance = clamp(_base_crit_chance + bonus + weapon_crit_chance_bonus, 0.0, 1.0)


func set_crit_damage_bonus(bonus: float) -> void:
	crit_damage = _base_crit_damage + bonus + weapon_crit_damage_bonus


## Boomerang: aynı anda sadece TEK bir mermi havada olabilir - geri dönüp
## kendini serbest bırakana kadar (bkz. boomerang_projectile.gd _on_returned)
## yeni bir atış tetiklenmez. Diğer tüm silahlerde false (no-op, davranış
## değişmez) - bkz. _on_fire_timer_timeout.
@export var single_active_projectile: bool = false
## DÜZELTME (kullanıcı bildirimi: "boomerang elarada bozuluyor. çifte tetik
## yeteneğinde 2 tane atması normal ama yetenek bitince bile 2 tane atmaya
## devam ediyor") - kök neden: bu eskiden tek bir bool'du. Elara ULTİ'si
## (çifte tetik) aktifken _fire_at_delayed() single_active_projectile
## kısıtlamasını (bkz. _on_fire_timer_timeout'taki kontrol) HİÇ görmeden
## _fire_at()'i doğrudan çağırıp İKİNCİ bir bumerangı havaya atıyordu - bu
## "yetenek açıkken 2 atması normal" kısmı için kasıtlı/doğru. Ama bool tek
## bir mermiyi temsil ettiği için, havada GERÇEKTEN 2 bumerang varken
## bunlardan HANGİSİ önce dönerse dönsün _on_boomerang_returned() bool'u
## direkt false'a çekiyordu - yani ikincisi hâlâ havadayken yeni bir atışa
## izin veriliyordu. Bu da yetenek bittikten SONRA bile üst üste binen iki
## bumerangın havada kalmaya devam etmesine (yani "hâlâ 2 atıyormuş" gibi
## görünmesine) yol açıyordu. Artık gerçek havadaki mermi SAYISI tutuluyor -
## kısıtlama sadece sayı 0'a inince (yani TÜM bumeranglar gerçekten dönünce)
## kalkıyor, bool'un "ilk dönen sıfırlar" hatasına artık kapalı.
var _projectiles_in_flight: int = 0

## Fişek: menzilli silahlerin varsayılan "her an en yakın düşmana dön"
## davranışını kapatır - kullanıcı bildirimi: "yaratıklara dönük pozisyonda
## durmalarına gerek yok fişeklerin, onlar yukardan ateşleniyor çünkü" - yani
## ikon hep aynı (dikey/yukarı) pozda kalır, sadece hover salınımı devam
## eder. true (varsayılan, diğer tüm silahlerde) eski davranış, hiçbir şey
## değişmez.
@export var icon_faces_target: bool = true

## Talon Silah Salvosu (bkz. player.gd _skill_talon_weapon_salvo/
## _end_talon_weapon_salvo) - true iken _on_fire_timer_timeout/_process
## (çekiliş-hazır dalı) _get_target_enemy() ile hedef ARAMAZ, bunun yerine
## _make_facing_direction_target() ile icon_sprite'ın O ANKİ (dairesel
## dizilimde sürekli dönen) rotasyonunun işaret ettiği yönde "hayalet" bir
## hedef üretir - kullanıcı isteği: "saldırı salvosu hedeflere doğru oluyor,
## ben baktıkları yöne doğru olsun istemiştim, hedef yoksa bile atmalı."
## false (varsayılan, diğer tüm silahlerde/durumlarda) no-op, eski davranış.
var fire_in_facing_direction: bool = false

## Fişek: fırlatılan mermi(ler) havadayken kafanın üstündeki ikonu gizler -
## bkz. _fire_at() sonundaki ilgili blok ve _on_ranged_projectile_landed().
## false (varsayılan, diğer tüm silahlerde) no-op.
@export var hide_icon_while_projectile_flying: bool = false
var _flying_projectile_count: int = 0


## hide_icon_while_projectile_flying açık olan silahlerin merminin (bkz.
## firework_projectile.gd _explode) çağırdığı geri bildirim - havadaki
## mermi sayısı sıfıra inince (üst üste atılan hepsi patlayınca) ikon
## tekrar görünür olur.
func _on_ranged_projectile_landed() -> void:
	_flying_projectile_count = max(0, _flying_projectile_count - 1)
	if _flying_projectile_count == 0 and icon_sprite:
		icon_sprite.visible = true
		_broadcast_weapon_icon_visibility(true)


## Boomerang: dönüm noktalarında (3/5/7/10) kümülatif "daha hızlı fırlatılır
## VE daha hızlı geri döner" bonusu - mermiyi HEM giderken HEM dönerken
## hızlandırır (fire_rate'i DEĞİL, doğrudan merminin kendi speed'ini çarpar -
## bkz. _fire_at, player.gd _apply_boomerang_tier). Diğer tüm silahlerde 1.0
## (no-op, merminin kendi speed'i hiç değişmez).
var projectile_speed_mult: float = 1.0
## bkz. _fire_at'teki single_active_projectile dalı (2026-09-24 denge turu).
const BOOMERANG_BASE_SPEED_MULT := 0.8


## Boomerang geri döndüğünde (bkz. boomerang_projectile.gd) çağrılır - bir
## sonraki atışın önü açılır, kafanın üstünde süzülen ikon tekrar görünür olur
## (bkz. _fire_at - atış anında gizlenmişti, "iki bumerang" görünmesin diye).
func _on_boomerang_returned() -> void:
	## bkz. _projectiles_in_flight üstündeki yorum - eskiden burada bool
	## direkt false'a çekiliyordu, çifte tetik ile havada 2 bumerang varken
	## ilk döneni "hepsi bitti" sanıp yeni atışın önünü erken açıyordu.
	_projectiles_in_flight = max(0, _projectiles_in_flight - 1)
	## Kafadaki ikon sadece havada GERÇEKTEN hiç bumerang kalmayınca geri
	## görünür olur - yoksa (çifte tetikte) ikinci bumerang hâlâ havadayken
	## ikon erken görünüp "kafada bir tane + havada bir tane" gibi görünürdü.
	if _projectiles_in_flight <= 0 and icon_sprite:
		icon_sprite.visible = true
		_broadcast_weapon_icon_visibility(true)


## Fişek: dönüm noktalarında (3/5/7/10) kümülatif büyüyen patlama genişliği
## çarpanı - firework_projectile.gd'nin (veya splash_radius kullanan başka
## herhangi bir merminin) splash_radius'unu büyütür. Diğer tüm silahlerde 1.0
## (no-op, bkz. _fire_at).
var splash_radius_mult: float = 1.0


## Tüftüf: hem kafanın üstündeki ikonu HEM DE bundan sonra atılacak dart'ların
## görselini verilen tier'e (1-10) günceller - player.gd'nin _apply_tuftuf_tier()
## fonksiyonu her seviye atlandığında çağırır. tier_icon_textures/
## tier_dart_textures boşsa (Tüftüf dışındaki tüm silahler) no-op.
func set_weapon_tier(tier: int) -> void:
	_current_tier = max(1, tier)
	if not tier_icon_textures.is_empty() and icon_sprite:
		var idx: int = clamp(_current_tier - 1, 0, tier_icon_textures.size() - 1)
		icon_sprite.texture = tier_icon_textures[idx]


## Reads a stat off the owning Player (weapons are always direct children of
## Player), defaulting to 0 if it's missing (e.g. in an editor preview).
func _player_stat(stat_name: String) -> float:
	var parent := get_parent()
	if parent and stat_name in parent:
		return parent.get(stat_name)
	return 0.0


## Same as _player_stat, but for multiplier-style stats (e.g.
## shield_mode_damage_mult) where "missing" should mean "no change" (1.0),
## not "zero out everything" (0.0).
func _player_stat_default(stat_name: String, default_value: float) -> float:
	var parent := get_parent()
	if parent and stat_name in parent:
		return parent.get(stat_name)
	return default_value


## Called by Player._reposition_weapon_icons() every time the set of owned
## weapons changes, so the whole fan re-centers itself: 1 weapon sits dead
## center (angle 0), 2+ spread out evenly and symmetrically around it.
func set_fan_angle(angle_deg: float) -> void:
	_fan_angle_deg = angle_deg
	if icon_sprite:
		_target_local_offset = hover_offset + _fan_offset()
		var parent = get_parent()
		if parent:
			global_position = parent.global_position + _target_local_offset
		else:
			position = _target_local_offset


func _fan_offset() -> Vector2:
	var angle_rad: float = deg_to_rad(_fan_angle_deg)
	return Vector2(sin(angle_rad), -cos(angle_rad)) * fan_radius


## Player._reposition_weapon_icons() artık silahları eskisi gibi tek bir
## pivot etrafında sürekli açıyla (set_fan_angle) değil, kullanıcının
## çizdiği diyagrama göre sabit noktalara (WEAPON_ICON_SLOTS) yerleştiriyor -
## bu da doğrudan o noktayı verir, hover_offset/fan_radius hesabına girmez.
func set_icon_offset(offset: Vector2) -> void:
	if icon_sprite:
		_target_local_offset = offset
		var parent = get_parent()
		if parent and parent is Node2D:
			global_position = parent.global_position + _target_local_offset
		else:
			position = _target_local_offset


## Kafanın üstünde süzülen silah ikonu hafifçe yukarı-aşağı süzülüyormuş gibi
## görünsün diye küçük, zamana bağlı bir sinüs sallanması ekleniyor (bkz.
## kullanıcı bildirimi: "hafiften kafanın üstünde uçuyormuş gibi gözükmesini
## istiyorum o kadar"). ÖNCEKİ deneme (harekete göre GECİKMELİ takip - global_
## position'ı karakterin ANLIK konumuna doğru lerp'lemek) konumu hareket
## sırasında FARK EDİLİR şekilde kafadan kopartıyordu (hız ne kadar yüksekse
## sapma o kadar büyüyordu) - kullanıcı "silahların konumunu eski haline
## getir" diye bildirdi, o yüzden TAMAMEN kaldırıldı. self.position artık
## HER ZAMAN _target_local_offset'e göre TAM/rijit (eskisi gibi, karakterle
## birebir aynı hizada) - üstüne eklenen tek şey, hıza/harekete HİÇ bağlı
## olmayan, sabit küçük genlikli (HOVER_BOB_AMPLITUDE) bir salınım, o yüzden
## asla "geride kalmış" gibi görünmez, sadece nazikçe süzülür.
## Talon'un Ayna Formu'nda (R) silahlar %10 büyür (TalonFormationMath.FORM_SCALE_MULT) - player.gd her karede yazar,
## form bitince 1.0'a döner. scale atanan her yerde (hover takibi, dönen kılıç) çarpılır ki gölge/menzil hesabı tutarlı kalsın.
var form_scale_mult: float = 1.0
const HOVER_BOB_AMPLITUDE := 3.5 ## px
const HOVER_BOB_SPEED := 2.2 ## rad/sn
var _target_local_offset: Vector2 = Vector2.ZERO
var _hover_bob_time: float = 0.0
## Her silah kendine özel rastgele bir faz ile başlar ki 5 slotun hepsi
## birbiriyle aynı anda, robotik biçimde yukarı/aşağı gitmesin.
var _hover_bob_phase: float = 0.0
var _floaty_global_pos: Vector2 = Vector2.ZERO
## Gölgenin (shadow_sprite) yükseklige gore azicik buyuyup kucalmesi icin
## en son hesaplanan bob degeri saklaniyor - bkz. _physics_process.
var _last_bob: float = 0.0

## Kullanıcı isteği: "Ölünce silahlar yere düşsün (düşme hareketine uygun
## yere düşüp hafif zıplayıp dağılma animasyonları da ekle) dirilince de ease
## ease şeklinde normal yerlerine geri dönsün silahlar. Gölgenin konumunu
## buna göre ayarla, düşünce gölgesi tam altında olmalı yere düştüğü için."
##
## DÜZELTME (kullanıcı bildirimi: "düşme animasyonu doğal değil, Minecraft'ta
## ölünce itemlerin yere düşmesi gibi düşmeleri gerekiyor, gölgeler
## görünmüyor ve çok ruhsuz") - bkz. weapon_death_drop_math.gd dosya başı kök
## neden notu: ilk deneme (tek bir TRANS_BOUNCE tween'iyle global_position'ı
## düz bir çizgide interpolasyon) gerçek bir dikey sekme DEĞİL, çizgi
## üzerinde ileri-geri kayma gibi görünüyordu. Artık YATAY (XY, karaktere
## göre hedef noktaya ease-out ile) ve DİKEY (yerçekimi + sekme, WeaponDeath
## DropMath.step_bounce) TAMAMEN AYRI simüle ediliyor - gölgenin boşluğu da
## (bkz. _update_icon_shadow) DOĞRUDAN bu dikey yüksekliği (_drop_height)
## okuyor, ayrı/kopuk bir "progress" değişkeni YOK, o yüzden ikisi ASLA
## birbirinden kopamaz.
##
## Oyuncu is_dead/is_downed olunca silah düşmeye başlar - bu süre boyunca
## (ve yerdeyken/dönerken) normal hover takibi (_update_hover_follow)
## TAMAMEN durur (bkz. _physics_process), yoksa hover her karede konumu
## canlı hedefe geri çekip animasyonu anında iptal ederdi.
var _weapon_grounded: bool = false
var _falling: bool = false
var _rising: bool = false
var _was_owner_incapacitated: bool = false
## Düşüş: dikey (sekme) durumu.
var _drop_height: float = 0.0
var _drop_v_speed: float = 0.0
var _drop_spin_speed: float = 0.0
var _drop_elapsed: float = 0.0
var _drop_start_pos: Vector2 = Vector2.ZERO
var _drop_ground_local_offset: Vector2 = Vector2.ZERO
## Dönüş: normal hover hedefine ease-out ile giden AYRI bir geçiş.
var _rise_start_pos: Vector2 = Vector2.ZERO
var _rise_elapsed: float = 0.0
## Sadece yakın dövüş ikonları için (bkz. _process_weapon_rise) - ölmeden
## HEMEN önceki ikon rotasyonu, dirilince buna geri dönülür.
var _pre_drop_icon_rotation: float = 0.0


## Her fizik karesinde (orbit kılıç HARİÇ) çağrılır - is_dead/is_downed
## GEÇİŞLERİNİ yakalayıp düşme/dönüş animasyonlarını tetikler.
func _process_death_drop() -> void:
	var owner_node: Node = get_parent()
	var incapacitated: bool = owner_node != null \
			and (owner_node.get("is_dead") == true or owner_node.get("is_downed") == true)
	if incapacitated and not _was_owner_incapacitated:
		_start_weapon_drop()
	elif not incapacitated and _was_owner_incapacitated:
		_start_weapon_rise()
	_was_owner_incapacitated = incapacitated


func _start_weapon_drop() -> void:
	_falling = true
	_rising = false
	_weapon_grounded = false
	_drop_elapsed = 0.0
	_drop_start_pos = global_position
	_drop_height = 0.0
	## Rastgele bir ilk fırlama hızı - 3 silah da AYNI tepe noktasına
	## zıplamasın diye (kullanıcı isteği: "dağılma animasyonları").
	_drop_v_speed = randf_range(WeaponDeathDropMath.INITIAL_UP_SPEED_MIN, WeaponDeathDropMath.INITIAL_UP_SPEED_MAX)
	_drop_spin_speed = randf_range(WeaponDeathDropMath.SPIN_SPEED_MIN, WeaponDeathDropMath.SPIN_SPEED_MAX) * (1.0 if randf() < 0.5 else -1.0)
	_pre_drop_icon_rotation = icon_sprite.rotation if icon_sprite else 0.0
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(WeaponDeathDropMath.SCATTER_RADIUS_MIN, WeaponDeathDropMath.SCATTER_RADIUS_MAX)
	_drop_ground_local_offset = _target_local_offset + Vector2(cos(angle), sin(angle)) * radius


func _start_weapon_rise() -> void:
	_falling = false
	_rising = true
	_weapon_grounded = false
	_rise_elapsed = 0.0
	_rise_start_pos = global_position


## Yatayda (XY) karakterin ANLIK konumuna göre hedef "yere saçılmış" noktaya
## ease-out ile süzülür, dikeyde (WeaponDeathDropMath.step_bounce) gerçek bir
## yerçekimi/sekme simülasyonu yaşar - Minecraft'taki item drop hissi tam
## olarak bu ikisinin AYRIŞTIRILMASINDAN geliyor.
func _process_weapon_fall_physics(delta: float) -> void:
	_drop_elapsed += delta
	var bounce: Dictionary = WeaponDeathDropMath.step_bounce(_drop_height, _drop_v_speed, delta, false)
	_drop_height = bounce["height"]
	_drop_v_speed = bounce["v_speed"]
	var xy_t: float = WeaponDeathDropMath.ease_out_cubic(_drop_elapsed / WeaponDeathDropMath.XY_DURATION)
	var parent_node: Node = get_parent()
	var ground_target: Vector2 = _drop_start_pos
	if parent_node is Node2D:
		var p2d := parent_node as Node2D
		ground_target = p2d.global_position + _drop_ground_local_offset * p2d.scale
	var xy_pos: Vector2 = _drop_start_pos.lerp(ground_target, xy_t)
	global_position = xy_pos + Vector2(0.0, -_drop_height) ## height yukarı = ekranda Y azalır
	_set_death_alpha(WeaponDeathDropMath.fall_alpha(_drop_elapsed))
	if icon_sprite:
		icon_sprite.rotation += _drop_spin_speed * delta
	if bounce["settled"] and xy_t >= 1.0:
		_falling = false
		_weapon_grounded = true
		if icon_sprite:
			## Minecraft'taki gibi rastgele bir açıda yatarak dursun - sürekli
			## dönmeyi burada kesip son karedeki açıyı (normalize edilmiş) sabitliyoruz.
			icon_sprite.rotation = wrapf(icon_sprite.rotation, -PI, PI)


## Dirilince "ease ease" normal hover hedefine dönüş - hover_follow'un KENDİ
## lerp'ine bırakmak YETERSİZ: o fonksiyondaki max_drift (20px*scale) sınırı
## SADECE küçük/sürekli sapmalar için var, silah yerden (100+ px uzakta
## olabilir) hedefe dönerken ilk karede hemen bu sınıra SIÇRAYIP "ease ease"
## hissini yok ederdi - bu yüzden dönüş de kendi ayrı geçişiyle yapılıyor.
func _process_weapon_rise_physics(delta: float) -> void:
	_rise_elapsed += delta
	## 2026-09-25: "dirilince ease ease halinde geri dönsün" - ease-in-out, biraz daha uzun (bkz. WeaponDeathDropMath).
	var t: float = WeaponDeathDropMath.ease_in_out_cubic(_rise_elapsed / WeaponDeathDropMath.RISE_DURATION)
	_set_death_alpha(lerpf(WeaponDeathDropMath.GROUND_ALPHA, 1.0, t))
	var parent_node: Node = get_parent()
	var target_global: Vector2 = _rise_start_pos
	if parent_node is Node2D:
		var p2d := parent_node as Node2D
		target_global = p2d.global_position + _target_local_offset * p2d.scale
	global_position = _rise_start_pos.lerp(target_global, t)
	## Rotasyon: menzilli silahlarda _update_aim (is_dead kalkınca otomatik
	## devreye girer) zaten kendi AIM_EASE_RATE'iyle aynı işi yapıyor; ama
	## yakın dövüş ikonları (melee=true) hiç _update_aim çağırmıyor, o yüzden
	## SADECE onlar için burada eski (ölmeden önceki) rotasyona dönülüyor.
	if melee and icon_sprite:
		icon_sprite.rotation = lerp_angle(icon_sprite.rotation, _pre_drop_icon_rotation, clampf(delta * 10.0, 0.0, 1.0))
	## Gölge boşluğu da (bkz. _update_icon_shadow) aynı hızla sıfıra iniyor -
	## "yerden kalkıp normal süzülüşe dönme" hissi.
	_drop_height = lerpf(_drop_height, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	if t >= 1.0:
		_rising = false
		_floaty_global_pos = global_position
		_drop_height = 0.0
		_set_death_alpha(1.0)


## Ölüm düşüşü opaklığı (bkz. WeaponDeathDropMath.GROUND_ALPHA) - ikon + gölge, self_modulate ile (başka sistemlerin
## modulate'ına dokunmadan).
func _set_death_alpha(a: float) -> void:
	if icon_sprite:
		icon_sprite.self_modulate.a = a
	if shadow_sprite:
		shadow_sprite.self_modulate.a = a

func _update_hover_follow(delta: float) -> void:
	if not icon_sprite:
		return
	_hover_bob_time += delta
	var bob: float = sin(_hover_bob_time * HOVER_BOB_SPEED + _hover_bob_phase) * HOVER_BOB_AMPLITUDE
	_last_bob = bob
	var parent_node: Node = get_parent()
	if parent_node and parent_node is Node2D:
		# Karakterin ölçeğini silaha uyguluyoruz (büyük görünmesini engeller)
		var is_wand: bool = _type_src.containsn("arcane") or _type_src.containsn("fire") or _type_src.containsn("lightning") or _type_src.containsn("buz")
		if is_wand:
			## Kullanıcı isteği: "Arcane Asası'nın boyutunu %15 düşür" - diğer
			## asalar (fire/lightning/buz) hâlâ 0.3, sadece Arcane için ek
			## %15 küçültme (0.3 * 0.85 = 0.255).
			var wand_scale: float = 0.255 if _is_arcane else 0.3
			scale = parent_node.scale * wand_scale * form_scale_mult
		else:
			scale = parent_node.scale * form_scale_mult
		
		# Karakterin ölçeğini mesafeye (offset) de uygulayarak yakın kalmalarını sağlıyoruz
		var target_global_pos = parent_node.global_position + (_target_local_offset + Vector2(0, bob)) * parent_node.scale
		
		# İlk başlatmada veya ışınlanmada doğrudan konumu eşitle
		if _floaty_global_pos == Vector2.ZERO or _floaty_global_pos.distance_to(target_global_pos) > 200.0:
			_floaty_global_pos = target_global_pos
			global_position = _floaty_global_pos.round()
			return
			
		# Silahların kafadan kopup uzaklaşmaması için maksimum mesafe limiti (karakter ölçeğine göre)
		var max_drift: float = 20.0 * parent_node.scale.x
		
		# Karakter hareket ederken silahların "ease ease" (9.0 * delta) yumuşaklığıyla geriden gelmesi
		# Hassasiyeti korumak için lerp işlemini küsüratlı (fractional) _floaty_global_pos üzerinde yapıyoruz
		var next_pos = _floaty_global_pos.lerp(target_global_pos, 9.0 * delta)
		
		# Eğer mesafe limiti aşıldıysa, silahı sınırda tut (kopmasını engeller)
		var offset = next_pos - target_global_pos
		if offset.length() > max_drift:
			next_pos = target_global_pos + offset.normalized() * max_drift
			
		_floaty_global_pos = next_pos
		# Çizimde piksel bulanıklığını (sub-pixel blur) önlemek için pozisyonu tam sayılara (pixel grid) yuvarlıyoruz
		global_position = _floaty_global_pos.round()
	else:
		position = _target_local_offset + Vector2(0, bob)


## How quickly the icon eases into the new aim angle - higher = snappier,
## lower = more of a lazy swing. Not a flat rotation speed, so it naturally
## slows down as it gets close (eased, not a sudden snap/teleport).
const AIM_EASE_RATE := 12.0

func _physics_process(delta: float) -> void:
	if _is_uzunkilic:
		_process_uzunkilic_orbit(delta)
	else:
		_process_death_drop()
		## Düşerken/yerdeyken/dönerken hover takibi TAMAMEN durur (bkz.
		## _process_death_drop üstündeki kök neden notu) - kendi fizik/geçiş
		## simülasyonları global_position'ı zaten dolduruyor.
		if _falling:
			_process_weapon_fall_physics(delta)
		elif _rising:
			_process_weapon_rise_physics(delta)
		elif not _weapon_grounded:
			_update_hover_follow(delta)
		_update_icon_shadow()


var _orbit_arc: AnimatedSprite2D = null

func _process_uzunkilic_orbit(delta: float) -> void:
	# Update cooldowns
	for id in _hit_cooldowns.keys():
		_hit_cooldowns[id] -= delta
		if _hit_cooldowns[id] <= 0.0:
			_hit_cooldowns.erase(id)

	var parent_node: Node = get_parent()
	if not parent_node or not parent_node is Node2D:
		return

	# Compute range multiplier based on attack range
	var range_mult: float = attack_range / max(0.001, _base_attack_range)
	scale = parent_node.scale * range_mult * form_scale_mult

	## Dönüş/pozisyon formülü artık weapon_orbit_math.gd'de TEK yerde -
	## remote_player.gd _update_local_uzunkilic_orbit AYNI fonksiyonu
	## çağırıyor, bkz. o dosyanın başındaki kök neden notu.
	var orbit: Dictionary = WeaponOrbitMath.compute(delta, _orbit_angle, fire_rate, range_mult, parent_node.scale.x)
	_orbit_angle = orbit["angle"]
	global_position = parent_node.global_position + orbit["offset"]
	rotation = orbit["rotation"]

	# Ensure the icon is visible
	if icon_sprite:
		icon_sprite.visible = true

	## Yörünge izi: kılıcın arkasında TEK bir pişirilmiş hilal (bkz. WeaponOrbitMath.update_arc) - eskiden saniyede ~22
	## ayrı iz sahnesi doğuyordu.
	if is_inside_tree():
		_orbit_arc = WeaponOrbitMath.update_arc(_orbit_arc, self, (parent_node as Node2D).global_position, global_position)

	# Collision detection with enemies
	var sword_pos: Vector2 = global_position
	var collision_radius: float = 45.0 * range_mult * parent_node.scale.x
	
	# Compute effective damage stats
	var final_damage: float = damage * rage_multiplier
	final_damage *= 1.0 + _player_stat("aggressive_damage_bonus") + _player_stat("talon_damage_bonus")
	final_damage *= _player_stat_default("shield_mode_damage_mult", 1.0)
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		final_damage *= crit_damage
	final_damage += _player_stat("item_flat_hit_damage")
	final_damage *= 1.0 + _player_stat("item_damage_mult_bonus")
	
	var shield_pen: float = _player_stat("shield_mode_shield_pen_bonus") + weapon_shield_pen_bonus

	## DÜZELTME (kullanıcı bildirimi: "yaratıklara tam saldırırken anlık fps
	## düşürüyor") - bu HER FİZİK KARESİNDE (uzunkılıç dönerken sürekli)
	## çalışıyordu ve eskiden TÜM "enemies" grubunu tarıyordu; artık Enemy.
	## get_enemies_near ile (bkz. enemy.gd) sadece kılıcın o anki yakınındaki
	## yaratıklar geliyor.
	## BUG DÜZELTMESİ (2026-09-24 denge turu): dönen kılıç Elara ULTİ'sinden (Çift Tetik) hiç etkilenmiyordu. Diğer
	## silahlarla AYNI kural: ulti açıkken her isabet 2 kez, her biri %60 hasarla (x1.2).
	var orbit_hits: int = 1
	if _player_flag("elara_double_fire_active"):
		orbit_hits = 2
		final_damage *= ELARA_DOUBLE_FIRE_DAMAGE_MULT
	if is_inside_tree():
		## Şaman pasifi: bu vuruş penceresi (bir fizik karesi) kapsamında
		## yakma EN FAZLA 1 düşmanda tetiklenebilir - bkz. enemy.gd
		## try_shaman_weapon_burn() üstündeki kök neden notu.
		var _shaman_burn_applied: bool = false
		for e in Enemy.get_enemies_near(get_tree(), sword_pos, collision_radius):
			var id: int = e.get_instance_id()
			if not _hit_cooldowns.has(id):
				_hit_cooldowns[id] = 1.0
				if e.has_method("take_damage"):
					for _h in range(orbit_hits):
						if is_instance_valid(e) and e.get("is_dead") != true:
							e.take_damage(final_damage, is_crit, shield_pen, true) ## donen kilic: cevresindeki herkese = alan
					_spawn_orbit_hit_fx(e.global_position)
					if not _shaman_burn_applied and e.has_method("try_shaman_weapon_burn"):
						_shaman_burn_applied = e.try_shaman_weapon_burn()


func _spawn_orbit_hit_fx(pos: Vector2) -> void:
	if not HitClawFxScene:
		return
	var fx: Node2D = HitClawFxScene.instantiate() as Node2D
	if is_inside_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(fx)
	else:
		get_parent().add_child(fx)
	fx.global_position = pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	fx.rotation = randf_range(0.0, TAU)
	fx.scale = Vector2(0.5, 0.5)


## Silahın kafanın üstünde süzülen ikonu için, İKONA BAĞLI (karakterin
## sabit ayak hizasına DEĞİL) makul bir mesafede asılı duran, ikonun kendi
## GÖRÜNÜR piksel şekline (_icon_pixel_size, sıkı bounding-box - bkz.
## _measure_icon_pixel_size) orantılı GENİŞLEYİP UZAYAN bir gölge oval'i
## çizer - ince bir kılıç ince, yuvarlak bir topuz/asa daha yuvarlak bir
## gölge bırakır (kullanıcı isteği).
##
## GEÇMİŞ: önce gölge ikonun hemen dibine (bkz. eski ~19px offset)
## sabitlenmişti - kullanıcı "yükseklik hissi yok" dedi. Sonra gölge
## karakterin GERÇEK ayak hizasına (parent.y+55, ~200px aşağı) taşındı -
## bu sefer TÜM silahlar aynı sabit yükseklikte süzüldüğü için (hover_offset
## sabit) gölgeler dümdüz, birbirinden kopuk, "ekranın altına serpiştirilmiş
## ayrı noktalar" gibi göründü (kullanıcı: "pek doğal durmuyor").
## Doğru denge: gölge yine İKONA GÖRE (karakterin ayak hizasına değil)
## konumlanır ama makul (~46px) bir boşlukla - hem "silah havada süzülüyor"
## hissini korur hem de ikondan kopmaz. Bu boşluk hover sallanmasına (bob)
## göre hafifçe açılıp kapanır - "silah yükseldikçe gölgesinden biraz daha
## uzaklaşır" hissi verir, ayrıca her silahın kendi rastgele bob fazı
## olduğu için (bkz. _hover_bob_phase) birden fazla silahın gölgesi ASLA
## robotik bir düz çizgide TAM senkron durmaz, organik biçimde titreşir.
func _update_icon_shadow() -> void:
	if not (shadow_sprite and is_instance_valid(shadow_sprite)):
		return
	if not icon_sprite:
		shadow_sprite.visible = false
		return
	shadow_sprite.visible = icon_sprite.visible
	if not shadow_sprite.visible:
		return

	## (Eski sabit HOVER_SHADOW_GAP 62 artık WeaponOrbitMath.HOVER_SHADOW_BASE_GAP - en alttaki slotun boşluğu.)
	## Kullanıcı bildirimi: "çok abartılı olmuş uçma animasyonları, aşırı
	## yukarı aşağı gidip geliyorlar" - eskiden gölge bob'a göre ±10px
	## kayıp ±%15 küçülüp büyüyordu, bu da (silahın kendi ~3.5px'lik ufak
	## sallanmasına kıyasla ORANSIZ büyük olduğu için) gölgenin abartılı
	## "pompalanıyor" gibi görünmesine yol açıyordu. Artık çok daha hafif -
	## sadece ince bir organik titreşim veriyor, "uçuyor" hissini ezmiyor.
	## bob > 0 -> silah şu an biraz YUKARIDA -> gölgeden biraz daha uzaklaşır (gap büyür, gölge küçülür)
	## bob < 0 -> silah biraz AŞAĞIDA -> gölgeye biraz daha yaklaşır (gap küçülür, gölge büyür)
	## Kullanıcı isteği: "gölgenin konumunu buna göre ayarla, düşünce gölgesi
	## tam altında olmalı yere düştüğü için" + bildirim: "gölgeler görünmüyor" -
	## bkz. weapon_death_drop_math.gd kök neden notu: eski ayrı "progress"
	## değişkeni gerçek konumdan kopuyordu. Artık düşerken/yerdeyken/dönerken
	## boşluk DOĞRUDAN simüle edilen sekme yüksekliğini (_drop_height, bkz.
	## _process_weapon_fall_physics) okuyor - ikisi ASLA birbirinden kopamaz.
	var gap: float
	var bob_factor: float
	if _falling or _weapon_grounded or _rising:
		gap = _drop_height * scale.y
		bob_factor = 1.0
	else:
		var bob_norm: float = _last_bob / max(0.001, HOVER_BOB_AMPLITUDE) ## -1..1
		## Yer noktası slot yüksekliğine göre (bkz. WeaponOrbitMath.hover_shadow_gap) ve KARAKTERİN ölçeğiyle - eskiden
		## silahın KENDİ ölçeğiyle (asalar 0.3) çarpılıyordu, asaların gölgesi ikonun hemen dibinde kalıyordu.
		var owner_scale: float = (get_parent() as Node2D).scale.y if get_parent() is Node2D else 1.0
		gap = (WeaponOrbitMath.hover_shadow_gap(_target_local_offset.y) + bob_norm * 3.0) * owner_scale
		bob_factor = 1.0 - bob_norm * 0.05

	## Kullanıcı isteği: "gölgelerin silahın boyutlarına göre genişleyip
	## uzamasını istiyorum çünkü bazı silahlar çok ince bazıları kalın veya
	## yuvarlak" - gölgenin GENİŞLİĞİ ikonun gerçek dokusunun eninden,
	## YÜKSEKLİĞİ ise dokunun boyundan ayrı ayrı hesaplanıyor. SHADOW_FLATTEN
	## "yere düşmüş gölge" hissi için yükseklik eksenini biraz bastırıyor.
	## SHADOW_SHRINK: kullanıcı isteği "%20 küçülsün" - genel bir çarpan.
	const SHADOW_FLATTEN := 0.55
	const SHADOW_SHRINK := 0.8
	var effective_width: float = _icon_pixel_size.x * icon_sprite.scale.x * scale.x
	var effective_height: float = _icon_pixel_size.y * icon_sprite.scale.y * scale.y
	var half_w: float = max(3.5, effective_width * 0.30 * bob_factor * SHADOW_SHRINK)
	var half_h: float = max(2.5, effective_height * 0.30 * SHADOW_FLATTEN * bob_factor * SHADOW_SHRINK)

	shadow_sprite.scale = Vector2(half_w, half_h)
	shadow_sprite.global_position = icon_sprite.global_position + Vector2(0, gap)

func _process(delta: float) -> void:
	if _is_uzunkilic:
		return
	## Oyuncu öldüğünde/yere düştüğünde silah node'u (kendi Timer/_process
	## döngüsüyle Player'dan bağımsız çalışıyor) ateş etmeyi durdurmalı -
	## Player._physics_process'teki "if is_dead: return" koruması BU node'u
	## etkilemiyor (bkz. CLAUDE.md benzeri hata sınıfı: iki ayrı yer, biri
	## unutulmuş). Kullanıcı bildirimi: "ölen kişiler öldüğünde bile silahları
	## saldırmaya devam ediyor".
	var owner_node := get_parent()
	if owner_node and (owner_node.get("is_dead") == true or owner_node.get("is_downed") == true):
		if continuous_beam:
			## Şimşek Asası: hedefe kilitliyken oyuncu ölür/yere düşerse ışın
			## FX'i (get_tree().current_scene altına parent'lanmış, bu node'un
			## kendi görünürlüğünden bağımsız) sahipsiz kalıp sonsuza dek
			## çalışmaya devam ediyordu - bkz. _end_beam() aşağıdaki aynı
			## düzeltme (market bölgesi) ile aynı hata sınıfı.
			_end_beam()
		return
	## DÜZELTME (kullanıcı bildirimi: "Dükkanda yeni bir silah aldığımızda...
	## kalkanın içinden düşmanlara o silahla ateş edebiliyoruz bunun olmaması
	## gerekiyor") - seyyar satıcının güvenli bölgesi (bkz. player.gd
	## is_in_merchant_zone) enemy.gd tarafında ZATEN karşılıklı sayılıyordu
	## (yaratıklar bölgedeki oyuncuyu hiç hedeflemiyor/hasar veremiyor) ama
	## oyuncunun KENDİ silahları bölgenin DIŞINDAKİ yaratıklara ateş etmeye
	## devam edebiliyordu - artık gerçek bir ateşkes, silah da susuyor.
	if owner_node and owner_node.get("is_in_merchant_zone") == true:
		if continuous_beam:
			## Kullanıcı bildirimi: "Yıldırım asasına sahipken market alanının
			## içine girince effekt çıkmaya devam ediyor ama hasar vermiyor" -
			## process_mode zaten player.gd:set_combat_active() ile DISABLED
			## yapılıyor (bu satırın altına asla inemeyecek kadar erken), ama
			## o geçiş anıyla bu _process() çağrısı arasında bir kare farkı
			## olabilecek durumlar için burada da aynı temizliği yapıyoruz.
			_end_beam()
		return
	_process_arcane_burst_cooldown(delta)
	## Şimşek Asası: FireTimer/fire_rate'i tamamen görmezden gelir, kendi
	## sürekli ışın döngüsünü işler (bkz. _process_continuous_beam).
	if continuous_beam:
		_process_continuous_beam(delta)
		if icon_sprite:
			_update_aim(delta)
		return

	var target_wait: float = max(0.05, _effective_fire_wait())
	if abs(fire_timer.wait_time - target_wait) > 0.01:
		fire_timer.wait_time = target_wait

	## Yay: saldırı hızı bir kart/tier ile değişirse (draw cycle ortasındayken
	## bile) çekiliş animasyonunun hızı her karede tazelenir - tüm atış döngüsü
	## güncel ateş hızına denk gelsin diye.
	if draw_before_fire and icon_sprite and draw_anim_base_duration > 0.0 \
			and icon_sprite is AnimatedSprite2D and icon_sprite.sprite_frames \
			and icon_sprite.sprite_frames.has_animation("draw"):
		icon_sprite.speed_scale = clamp(draw_anim_base_duration / target_wait, 1.0, draw_anim_speed_scale_max)

	## Yay: yay TAM ÇEKİLMEDEN (draw animasyonu bitmeden) ok fırlatılamaz -
	## _draw_ready sadece _on_draw_finished() ile true olur (bkz. aşağıda).
	## Çekiliş bitince, ilk fırsatta (bir hedef belirir belirmez, aynı karede
	## bile olsa) hemen ateş edilir - fire_timer bu modda hiç kullanılmaz.
	if draw_before_fire and _draw_ready:
		var draw_target: Node2D = _make_facing_direction_target() if (fire_in_facing_direction and icon_sprite) else _get_target_enemy()
		if draw_target:
			_fire_at(draw_target)
			## Elara ULTİ (R): Yay da "2 kez tetiklenir" kuralına uyar - ikinci
			## ok kısa bir gecikmeyle arkasından çıkar (bkz. _on_fire_timer_
			## timeout'taki birebir aynı mantık / DOUBLE_FIRE_VISUAL_DELAY).
			if _player_flag("elara_double_fire_active"):
				_fire_at_delayed(draw_target, DOUBLE_FIRE_VISUAL_DELAY)
			## Kaos Kitabı: bkz. _on_fire_timer_timeout'taki birebir aynı mantık.
			if randf() < _player_stat("item_double_fire_chance"):
				_fire_at_delayed(draw_target, ITEM_DOUBLE_FIRE_VISUAL_DELAY)
			## Yay pasifi: her 3. saldırıda dönüm noktasına göre fazladan ok/oklar.
			_process_yay_multishot_passive(draw_target)

	## Tabanca (Revolver): reload sırasında geri sayım - bkz. _start_reload/_finish_reload.
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	## Yakın dövüş ikonu (bıçak) sürekli hedefe dönmez - sabit dururken 0
	## derece (dik, yukarı bakan) pozisyonda kalır, sadece saldırırken
	## _do_melee_swing() ile hedefe döner/gider. Menzilli silahlar (asalar/
	## tabanca) eskisi gibi her an en yakın düşmana dönmeye devam eder.
	## Reload sırasında da (Tabanca/Revolver) hedefe dönmeyi durdurur - silah
	## "elinde meşgul" görünsün diye.
	if icon_sprite and not melee and not is_reloading and icon_faces_target:
		_update_aim(delta)


## Keeps the weapon icon turned towards the nearest enemy at all times, even
## while the fire timer is still on cooldown - eased so it swings smoothly
## into place instead of snapping instantly to the new angle.
func _update_aim(delta: float) -> void:
	var target := _get_target_enemy()
	if not target:
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var forward: float = deg_to_rad(sprite_forward_angle_deg)
	var target_rotation: float = 0.0
	var t: float = 0.0

	if not mirror_icon_when_aiming_left:
		target_rotation = dir.angle() - forward
		t = clamp(delta * AIM_EASE_RATE, 0.0, 1.0)
		icon_sprite.rotation = lerp_angle(icon_sprite.rotation, target_rotation, t)
		return

	## Tabanca gibi ikonlar: sola bakarken rotasyonla değil aynalamayla döner,
	## yoksa 90°'yi geçince ters (baş aşağı) görünür. Sağda hep normal
	## (flip_h=false), solda hep aynalı (flip_h=true) - flip_h negatif x ile
	## aynaladığı için düz açı formülü yerine "F' = PI - F" ile hesaplanan
	## aynalı açı kullanılır (bkz. yorum: iki formül de tam +/-90°'de aynı
	## görüntüyü verir, yani geçiş anında görsel sıçrama olmaz).
	var flip: bool = dir.x < 0.0
	target_rotation = (dir.angle() - PI + forward) if flip else (dir.angle() - forward)
	if flip != _icon_flipped:
		## Aynalama durumu bu karede değiştiyse ara kareyi (lerp) atla - eski
		## ham rotasyon değeri yeni aynalama uzayında anlamsız olur, doğrudan
		## hedef açıya geç (geçiş noktasında görsel olarak zaten aynı).
		icon_sprite.rotation = target_rotation
		icon_sprite.flip_h = flip
		_icon_flipped = flip
		return
	t = clamp(delta * AIM_EASE_RATE, 0.0, 1.0)
	icon_sprite.rotation = lerp_angle(icon_sprite.rotation, target_rotation, t)


## Yay: bir sonraki atıştan önce oynayacak "ok çekiliş" animasyonu + sesini
## başlatır - hem ilk atıştan önce (_ready) hem de HER gerçek atıştan hemen
## sonra (_fire_at) çağrılır. Animasyon bitince _on_draw_finished() ile
## _draw_ready true olur - gerçek atış SADECE o zaman, _process()'te bir hedef
## belirir belirmez tetiklenir (bkz. _process, "çekmeden ok fırlatmamalı").
func _start_draw_cycle() -> void:
	if not draw_before_fire or not icon_sprite:
		return
	_draw_ready = false
	var target_wait: float = max(0.05, _effective_fire_wait())
	if held_arrow:
		held_arrow.visible = true
		held_arrow.position.x = 0.0
	if icon_sprite is AnimatedSprite2D and icon_sprite.sprite_frames and icon_sprite.sprite_frames.has_animation("draw"):
		if draw_anim_base_duration > 0.0:
			icon_sprite.speed_scale = clamp(draw_anim_base_duration / target_wait, 1.0, draw_anim_speed_scale_max)
		## Ok'un ipi takip eden kare kare geri çekilişi (bkz. held_arrow_offsets)
		## - sadece bir kez bağlanır, "draw" her yeniden oynatıldığında zaten
		## frame 0'dan başladığı için ilk kare offseti (_on_draw_frame_changed
		## henüz çağrılmadan) yukarıdaki satırla elle sıfırlanıyor.
		if not _frame_changed_connected:
			icon_sprite.frame_changed.connect(_on_draw_frame_changed)
			_frame_changed_connected = true
		## Önceki döngüden kalma animation_finished bağlantılarını temizle,
		## yoksa aynı sinyal birden çok kez tetiklenip _draw_ready çakışması
		## yapabilir (bkz. kullanıcı bildirimi: "yay animasyonları çalışmıyor").
		if icon_sprite.animation_finished.is_connected(_on_draw_finished):
			icon_sprite.animation_finished.disconnect(_on_draw_finished)
		icon_sprite.animation_finished.connect(_on_draw_finished, CONNECT_ONE_SHOT)
		icon_sprite.stop()
		icon_sprite.play("draw")
	else:
		## SpriteFrames yoksa/animasyon bulunamazsa yine de kilitlenip
		## kalmasın diye hemen hazır sayılır.
		_draw_ready = true
	if draw_sound:
		if draw_sound_base_duration > 0.0:
			draw_sound.pitch_scale = clamp(draw_sound_base_duration / target_wait, 1.0, draw_sound_pitch_scale_max)
		draw_sound.play()


## "draw" animasyonu tam bitince çağrılır (CONNECT_ONE_SHOT) - yay artık tam
## gerilmiş durumda, _process() bir hedef bulur bulmaz ateş edecek.
func _on_draw_finished() -> void:
	_draw_ready = true


## "draw" animasyonunun HER karesinde çağrılır - ok görselini (HeldArrow) o
## karedeki ip konumuna göre kaydırır (bkz. held_arrow_offsets), böylece ok
## gerçekten ipte geriye doğru çekiliyormuş gibi görünür.
func _on_draw_frame_changed() -> void:
	if not held_arrow or held_arrow_offsets.is_empty():
		return
	var idx: int = icon_sprite.frame
	if idx >= 0 and idx < held_arrow_offsets.size():
		held_arrow.position.x = held_arrow_offsets[idx]


func _on_fire_timer_timeout() -> void:
	if _is_uzunkilic:
		return
	## bkz. _process() en başındaki aynı ölüm/yere düşme koruması - FireTimer
	## bu node'a ait ve Player öldükten sonra da tetiklenmeye devam edebiliyordu.
	var owner_node := get_parent()
	if owner_node and (owner_node.get("is_dead") == true or owner_node.get("is_downed") == true):
		return
	## DÜZELTME (kullanıcı bildirimi: "Fişek tüfek ve bıçak market alanın
	## içinde saldırı yapmaya devam ediyor") - _process()'teki AYNI kontrol
	## sadece _process()'in KENDİ mantığını (namlu takibi vb.) atlıyordu,
	## FireTimer'ın kendisi (bu node'un çocuğu, ayrı bir engine zamanlayıcısı)
	## hâlâ tikleyip _fire_at()'i tetikleyebiliyordu - asıl hasarın verildiği
	## yer burasıydı ve hiç koruması yoktu (bkz. player.gd buy_weapon_copy'deki
	## eşleşen düzeltme - kök neden, bölgedeyken satın alınan silahın hiç
	## devre dışı bırakılmaması). Doğrudan koruma - totem_base.gd/
	## player_pet.gd'deki AYNI desen.
	if owner_node and owner_node.get("is_in_merchant_zone") == true:
		return
	if continuous_beam:
		## Şimşek Asası: FireTimer bu modda hiç kullanılmaz (bkz. _process,
		## _process_continuous_beam).
		return
	if is_reloading or draw_before_fire:
		## Yay: atış artık FireTimer'dan değil, çekiliş animasyonunun
		## bitmesinden tetiklenir (bkz. _process, _on_draw_finished).
		return
	## Boomerang: önceki mermi henüz geri dönmediyse yeni atış tetiklenmez.
	if single_active_projectile and _projectiles_in_flight > 0:
		return
	var target: Node2D = _make_facing_direction_target() if (fire_in_facing_direction and icon_sprite) else _get_target_enemy()
	if target:
		_fire_at(target)
		## Elara ULTİ (R): "tüm silahlar 2 kez tetiklenir" - aynı hedefe kısa
		## bir gecikmeyle (bkz. DOUBLE_FIRE_VISUAL_DELAY) ikinci bir atış daha
		## (her ikisi de _fire_at() içindeki ELARA_DOUBLE_FIRE_DAMAGE_MULT
		## sayesinde zaten %60 hasarla işliyor).
		if _player_flag("elara_double_fire_active"):
			_fire_at_delayed(target, DOUBLE_FIRE_VISUAL_DELAY)
		## Kaos Kitabı: her silah bağımsız olarak %şans ile 2. kez ateşlenir
		## (kullanıcı isteği: "her silahın olasılığı birbirinden bağımsız").
		if randf() < _player_stat("item_double_fire_chance"):
			_fire_at_delayed(target, ITEM_DOUBLE_FIRE_VISUAL_DELAY)


## Tabanca (Revolver): mermi biterse çağrılır - ikonu gizleyip yerine
## ReloadAnim'i (varsa) oynatır, reload_duration sonunda _finish_reload() ile
## geri döner.
func _start_reload() -> void:
	if is_reloading or max_ammo <= 0:
		return
	is_reloading = true
	_reload_timer = reload_duration
	if icon_sprite:
		icon_sprite.visible = false
		_broadcast_weapon_icon_visibility(false)
	if reload_anim and reload_anim.sprite_frames and reload_anim.sprite_frames.has_animation("reload"):
		reload_anim.visible = true
		## Reload süresi tier'le kısaldıkça (bkz. player.gd _apply_tabanca_tier)
		## animasyon da orantılı hızlanır - sabit kare sayısı her zaman tam
		## reload_duration'a sığar.
		if reload_anim_base_duration > 0.0 and reload_duration > 0.0:
			reload_anim.speed_scale = reload_anim_base_duration / reload_duration
		reload_anim.play("reload")


func _finish_reload() -> void:
	is_reloading = false
	current_ammo = max_ammo
	if icon_sprite:
		icon_sprite.visible = true
		_broadcast_weapon_icon_visibility(true)
	if reload_anim:
		reload_anim.visible = false
		reload_anim.stop()


func get_nearest_enemy() -> Node2D:
	return _get_nearest_enemy()


## Silahın kendi global_position'ı, ikonun süzüldüğü/karaktere göre
## konumlandığı yerde duruyor (hover_offset + fan/slot ofseti) - birden
## fazla silah sahibi olunduğunda (bkz. buy_weapon_copy) her biri karakterin
## etrafında FARKLI bir noktada durur. Menzil/en-yakın-düşman hesabı bu
## YÜZDEN silahın KENDİ konumunu kullanır - aksi halde (parent/karakter
## konumu kullanılsaydı) TÜM silahlar birebir aynı "en yakın düşmanı"
## seçerdi, yani her silah kendi bulunduğu tarafa değil, hep karaktere en
## yakın tek bir düşmana saldırırdı (bkz. kullanıcı bildirimi: "her silah
## kendi konumuna yakın yaratığa saldırması gerekirken karaktere en yakın
## yaratığa saldırıyorlar").
func _attack_origin() -> Vector2:
	## Menzil merkezi: dikeyde karakterin ortası, yatayda ikonun x'i (bkz. WeaponTargetPriority.range_center).
	var owner_node := get_parent() as Node2D
	if owner_node == null or _falling or _weapon_grounded or _rising:
		return global_position
	return WeaponTargetPriorityScript.range_center(owner_node.global_position, global_position)


func _get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var origin: Vector2 = _attack_origin()
	var nearest: Node2D = null
	var nearest_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		# Corpses stay in the "enemies" group for their death animation before
		# being freed - skip them, otherwise weapons keep "locking on" to a
		# dying enemy (wasting shots that visibly fly toward it/past it)
		# instead of the actual nearest live threat.
		if e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		var d := origin.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest == null:
		return null
	if attack_range > 0.0 and nearest_dist > attack_range:
		return null
	return nearest


## bkz. fire_in_facing_direction üstündeki not - sahne ağacına hiç
## EKLENMEYEN (gerek yok: ebeveyni olmayan bir Node2D'nin global_position'ı
## zaten kendi position'ına eşittir), tek örneği tekrar tekrar yeniden
## konumlandırılan "hayalet" bir hedef döndürür. _fire_at() SADECE
## target.global_position (yön/VFX konumu) okur ve target.has_method(
## "take_damage") ile GERÇEK hasar uygulayıp uygulamayacağına karar verir -
## bu node'da o method YOK, yani "hedefsiz" bir yöne ateş etmiş gibi
## davranır; mermi/hitscan kendi çarpışmasıyla GERÇEK bir düşmana rastlarsa
## normal şekilde hasar verir.
var _facing_direction_target: Node2D = null

## Yakın dövüş silahları "hayalet" hedefe savurunca hiçbir yaratığa vurmaz (hayalet take_damage'sizdir) - sadece
## hayaletin etrafındaki melee alan payı uygulanırdı. Talon Silah Salvosu'nda bu, "silah ne kadar vuruyorsa o kadar
## vursun" kuralını bozuyordu; bu yüzden ışının üstünde (menzil içinde) gerçek bir yaratık varsa o hedef seçilir.
## Yaratığın gövde yarıçapına eklenen ışın payı (px):
const FACING_MELEE_RAY_MARGIN := 24.0

func _find_enemy_on_facing_ray(origin: Vector2, dir: Vector2, reach: float) -> Node2D:
	var ray_end: Vector2 = origin + dir * reach
	var best: Node2D = null
	var best_along: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true or not (e is Node2D):
			continue
		if not VisionFogScript.can_target(e):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(epos, origin, ray_end)
		var body_radius: float = float(e._body_radius) if "_body_radius" in e else 20.0
		if epos.distance_to(closest) > body_radius + FACING_MELEE_RAY_MARGIN:
			continue
		var along: float = origin.distance_to(closest)
		if along < best_along:
			best_along = along
			best = e
	return best


func _make_facing_direction_target() -> Node2D:
	if not _facing_direction_target:
		_facing_direction_target = Node2D.new()
	var forward: float = deg_to_rad(sprite_forward_angle_deg)
	## Aynalanan ikonlarda (tabanca/tüfek, mirror_icon_when_aiming_left) sola bakarken rotasyon değil flip_h kullanılır:
	## _update_aim'deki "rotation = açı - PI + forward" formülünün tersi burada (namlu ters yöne ateş etmesin).
	var facing_angle: float = icon_sprite.rotation + forward
	if mirror_icon_when_aiming_left and icon_sprite.get("flip_h") == true:
		facing_angle = icon_sprite.rotation + PI - forward
	var facing_dir: Vector2 = Vector2(cos(facing_angle), sin(facing_angle))
	var reach: float = attack_range if attack_range > 0.0 else 400.0
	if melee:
		var on_ray: Node2D = _find_enemy_on_facing_ray(global_position, facing_dir, reach)
		if on_ray:
			return on_ray
	_facing_direction_target.position = global_position + facing_dir * reach
	return _facing_direction_target


## Hangi hedefleme moduna göre saldırılacağını seçer - Tüftüf hariç herkes
## en yakın düşmanı hedeflemeye devam eder (eski davranış).
func _get_target_enemy() -> Node2D:
	## Menzilde boss / görev kopyası varsa silah DAİMA onlara odaklanır (kullanıcı isteği 2026-09-25) - kural TEK yerde:
	## weapon_target_priority.gd (uzak kuklanın nişanı da aynısını çağırır).
	var priority: Node2D = WeaponTargetPriorityScript.nearest_priority_target(get_tree(), _attack_origin(), attack_range,
			func(e: Node) -> bool: return VisionFogScript.can_target(e))
	if priority != null:
		if target_prefer_unfrozen:
			_claimed_frost_target = priority
		return priority
	if target_highest_health:
		return _get_highest_health_enemy()
	if target_prefer_unfrozen:
		return _get_nearest_unfrozen_enemy()
	return _get_nearest_enemy()


## Buz Asası: menzildeki en yakın DONMAMIŞ düşmanı hedefler (donmayı daha
## fazla düşmana yaymak için) - hiç donmamış düşman yoksa (hepsi is_frozen)
## normal en yakın düşman mantığına düşer (bkz. _get_nearest_enemy) ki asa
## "hedefsiz" kalıp ateş etmeyi bırakmasın.
##
## DÜZELTME (kullanıcı bildirimi: "buz asası veya büyücü kız ile donmuş
## düşmanlar hedef alınamıyor") - eskiden bu fonksiyon donmuş düşmanları
## MESAFEDEN BAĞIMSIZ tamamen göz ardı ediyordu: sürekli yeni (donmamış)
## düşman gelen bir dalgada, menzilde HER ZAMAN en az bir donmamış düşman
## bulunduğu için zaten donmuş (ve genelde çoktan yakın dövüş mesafesindeki)
## düşmanlar SONSUZA KADAR hedeflenemiyor, yani hiç bitirilemiyordu. Artık
## en yakın donmamış düşman İLE en yakın düşman (donmuş dahil) birlikte
## hesaplanıyor - en yakın düşman zaten donmamışsa hiçbir şey değişmiyor,
## ama en yakın düşman DONMUŞSA ve ondan belirgin şekilde (bkz.
## PREFER_UNFROZEN_MAX_EXTRA_DIST) daha yakın bir donmamış alternatif YOKSA
## artık o yakın donmuş düşman hedeflenmeye devam ediyor.
const PREFER_UNFROZEN_MAX_EXTRA_DIST := 80.0

## Kullanıcı isteği: aynı oyuncudaki DİĞER Buz Asası kopyalarının o anki
## hedeflerini (_claimed_frost_target) toplar - _get_nearest_unfrozen_enemy()
## bunları (bosslar hariç) hariç tutarak donmayı farklı yaratıklara yayar.
## get_parent() burada da (bkz. dosyanın başka yerlerindeki "owner_char"
## deseni) doğrudan oyuncu düğümünü verir - kardeş silahler onun diğer
## çocuklarıdır.
func _get_sibling_frost_targets() -> Array:
	var claimed: Array = []
	var owner_char: Node = get_parent()
	if not owner_char:
		return claimed
	for w in owner_char.get_children():
		if w == self or not (w is Node) or not w.has_method("get_claimed_frost_target"):
			continue
		var t = w.get_claimed_frost_target()
		if t:
			claimed.append(t)
	return claimed


## bkz. _get_sibling_frost_targets - Buz Asası olmayan silahlerde
## target_prefer_unfrozen=false olduğu için her zaman null döner (no-op).
func get_claimed_frost_target() -> Node2D:
	return _claimed_frost_target if target_prefer_unfrozen else null


func _get_nearest_unfrozen_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		_claimed_frost_target = null
		return null
	var origin: Vector2 = _attack_origin()
	var claimed_by_siblings: Array = _get_sibling_frost_targets()
	var nearest: Node2D = null
	var nearest_dist := INF
	var nearest_unfrozen: Node2D = null
	var nearest_unfrozen_dist := INF
	## Kullanıcı isteği: "birden fazla buz asasına sahip olunca hepsi aynı
	## yaratığa ateş ediyor" - en yakın donmamış adayın YANINDA, başka bir Buz
	## Asası kopyasının HENÜZ hedeflemediği (ya da hedef bir boss olduğu için
	## paylaşımın serbest olduğu) en yakın donmamış adayı da ayrıca izliyoruz.
	var nearest_unfrozen_unclaimed: Node2D = null
	var nearest_unfrozen_unclaimed_dist := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		var d := origin.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
		if e.get("is_frozen") != true:
			if d < nearest_unfrozen_dist:
				nearest_unfrozen_dist = d
				nearest_unfrozen = e
			var is_claimed_by_sibling: bool = e.get("is_boss") != true and claimed_by_siblings.has(e)
			if not is_claimed_by_sibling and d < nearest_unfrozen_unclaimed_dist:
				nearest_unfrozen_unclaimed_dist = d
				nearest_unfrozen_unclaimed = e
	if nearest == null:
		_claimed_frost_target = null
		return null
	if attack_range > 0.0 and nearest_dist > attack_range:
		_claimed_frost_target = null
		return null
	var result: Node2D
	# Sahiplenilmemiş (ya da boss olduğu için paylaşımı serbest) bir donmamış
	# aday varsa VE en yakın düşmandan aşırı uzak değilse (bkz.
	# PREFER_UNFROZEN_MAX_EXTRA_DIST), dağıtma davranışı için onu tercih et.
	if nearest_unfrozen_unclaimed and (nearest.get("is_frozen") != true or nearest_unfrozen_unclaimed_dist <= nearest_dist + PREFER_UNFROZEN_MAX_EXTRA_DIST) \
			and (attack_range <= 0.0 or nearest_unfrozen_unclaimed_dist <= attack_range):
		result = nearest_unfrozen_unclaimed
	# En yakın düşman zaten donmamışsa (en sık durum, sahiplenilmiş olsa
	# bile - hiç uygun alternatif yoksa boş kalmak yerine paylaşır) onu
	# hedefle.
	elif nearest.get("is_frozen") != true:
		result = nearest
	# En yakın düşman donmuş: yakınında (belirgin şekilde daha uzak
	# olmayan) donmamış bir alternatif varsa donmayı yaymak için onu
	# tercih et, yoksa donmuş düşmanı hedeflemeye devam et (bkz. yukarıdaki
	# düzeltme notu).
	elif nearest_unfrozen and nearest_unfrozen_dist <= nearest_dist + PREFER_UNFROZEN_MAX_EXTRA_DIST \
			and (attack_range <= 0.0 or nearest_unfrozen_dist <= attack_range):
		result = nearest_unfrozen
	else:
		result = nearest
	## DÜZELTME (kullanıcı bildirimi: "Buz asası aynı hedefe ateş etmemesi
	## gerekiyor (boss hariç) sürekli rasgele yakın başka DONMAMIŞ hedefleri
	## dondurmaya çalışan bir item bu") - üstteki mantık result'ı HEP
	## deterministik ("en yakın") seçiyordu, bu yüzden bir düşman tam donana
	## kadar (donma birkaç isabet gerektirebiliyor) hep AYNI hedefe
	## kilitleniyordu. Yukarıdaki hysteresis/sahiplenme/boss mantığı
	## DEĞİŞMEDİ (hâlâ hangi BÖLGENİN hedefleneceğine karar veriyor) - sadece
	## o bölgedeki KESİN seçim artık _pick_random_nearby_unfrozen ile
	## rastgele, isabetler farklı yaratıklara yayılıyor.
	var final_target: Node2D = _pick_random_nearby_unfrozen(result, claimed_by_siblings)
	_claimed_frost_target = final_target
	return final_target


## bkz. _get_nearest_unfrozen_enemy üstündeki DÜZELTME notu - preferred
## ZATEN donmuşsa (son çare fallback'i, uygun donmamış alternatif hiç
## yoktu) rastgeleliğe gerek yok, doğrudan onu döndürür. Değilse preferred'e
## PREFER_UNFROZEN_MAX_EXTRA_DIST içindeki AYNI şekilde uygun (donmamış,
## boss değilse sahiplenilmemiş) diğer adaylarla birlikte bir havuz kurup
## rastgele birini seçer.
func _pick_random_nearby_unfrozen(preferred: Node2D, claimed_by_siblings: Array) -> Node2D:
	if not is_instance_valid(preferred) or preferred.get("is_frozen") == true:
		return preferred
	var pool: Array = [preferred]
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == preferred or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		if e.get("is_frozen") == true:
			continue
		if e.get("is_boss") != true and claimed_by_siblings.has(e):
			continue
		if preferred.global_position.distance_to(e.global_position) <= PREFER_UNFROZEN_MAX_EXTRA_DIST:
			pool.append(e)
	return pool[randi() % pool.size()]


## Tüftüf: hedef önceliği "canı yüksek > hiç zehirlenmemiş > tüm yaratıklar"
## (kullanıcı isteği) - kural TEK yerde, bkz. tuftuf_targeting.gd (remote_player.gd
## kozmetik kopyası da aynısını çağırıyor). Her ateşte (ve her _update_aim karesinde)
## yeniden hesaplandığı için hedefin canı düştükçe ya da yeni bir yaratık zehirlenip/
## belirdikçe hedef kendiliğinden değişir, ayrı bir takip mantığı gerekmez. Fonksiyon
## adı eski "en yüksek can" isteğinden kaldı (test_vision_targeting.gd kullanıyor).
func _get_highest_health_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	return TuftufTargetingScript.pick(enemies, _attack_origin(), attack_range, func(e: Node) -> bool: return VisionFogScript.can_target(e))


## Şimşek Asası: her karede menzildeki hedefi tazeler - hedef değişirse
## (yenisi belirirse, öncekinin öldüğü/menzil dışına çıktığı için) eski ışın
## efekti kapatılıp yenisi başlar; hedef aynı kalırsa ışın sadece pozisyonunu
## güncellemeye devam eder (bkz. fx_lightning_beam.gd _process).
## ÖNEMLİ (bug fix - 2. tur): fx_lightning_beam.gd'nin ışını hiç "büyümüyor",
## setup() çağrılır çağrılmaz aynı karede TAM boyunda beliriyor (bkz. o script,
## _update_shape) - yani "ışın hedefe ulaşana kadar bekle" diye görsel bir
## ipucu yok, bekleme SÜRESİ tamamen hasarın kendisiyle sağlanmalı. Bu yüzden
## artık her hedef (DEĞİŞİMİ) - ister ışın hiç yokken ilk kez başlasın, ister
## bir düşman ölüp yerine hemen başka biri hedeflensin, FARK ETMEKSİZİN -
## sayaç TAM BİR tik aralığına sıfırlanır; hiçbir zaman anında (0 bekleme ile)
## hasar verilmez. Eskiden "ilk hedefe hemen bir tik" diye özel bir durum
## vardı - kullanıcı bunun "animasyon başlamadan/anında öldürüyor, hedef
## değişince aniden herşeye birden vuruyormuş gibi görünüyor" diye
## bildirmesi üzerine tamamen kaldırıldı.
## Tik aralığı sabit beam_tick_interval DEĞİL, diğer tüm silahlerin
## FireTimer.wait_time'ıyla BİREBİR AYNI formülle (fire_rate * fire_rate_
## multiplier) hesaplanıyor - böylece saldırı hızı kartları/tier bonusları
## tik sıklığını da hızlandırır ("saldırı hızına bağlı artıcak şekilde"
## isteği). beam_tick_interval (taban 1.0sn) hâlâ referans - fire_rate'in
## kendi taban değerine (_base_fire_rate) göre değişim ORANIYLA ölçeklenir,
## böylece tier 1 (hiç bonus yokken) tam olarak beam_tick_interval saniyede
## bir tık atar.
func _process_continuous_beam(delta: float) -> void:
	var target := _get_target_enemy()
	if not target or not is_instance_valid(target):
		_end_beam()
		return
	var rate_ratio: float = _effective_fire_wait() / _base_fire_rate if _base_fire_rate > 0.0 else 1.0
	## BUG DÜZELTMESİ (2026-09-24 denge turu): Elara ULTİ'si (Çift Tetik) ışın silahında "2 kez tetiklenme"yi hiç
	## uygulamıyordu (FireTimer yolu ışında erken dönüyor) ama _deal_beam_tick her tiki yine x0.6 ile çarpıyordu -
	## ulti açıkken Yıldırım Asası %40 ZAYIFLIYORDU. Artık ışın 2 kat sık tikler (x0.6 ile birlikte diğer silahlar gibi x1.2).
	if _player_flag("elara_double_fire_active"):
		rate_ratio *= 0.5
	var effective_tick_interval: float = max(0.05, beam_tick_interval * rate_ratio)
	if target != _beam_target:
		_end_beam()
		_beam_target = target
		## Hedef (yeniden) kilitlendiği HER an tik sayacı TAM aralığa
		## sıfırlanır - anında/aynı karede hasar asla verilmez (yukarıdaki
		## yoruma bkz.).
		_beam_tick_timer = effective_tick_interval
		if beam_scene:
			_beam_fx = beam_scene.instantiate()
			get_tree().current_scene.add_child(_beam_fx)
			var origin_node: Node2D = muzzle if muzzle else (icon_sprite if icon_sprite else self)
			if _beam_fx.has_method("setup"):
				_beam_fx.setup(origin_node, target)
			# Broadcast the exact muzzle position so remote beams start at the same point.
			if NetworkManager.is_multiplayer_active:
				NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "beam_start", target.global_position, {
					"beam_type": "lightning",
					"from_pos": origin_node.global_position
				})
	# Keep both endpoints synchronized while the player or target moves.
	if NetworkManager.is_multiplayer_active and not NetworkManager.should_throttle("lightning_beam_%d" % multiplayer.get_unique_id(), 0.05):
		var origin_node_update: Node2D = muzzle if muzzle else (icon_sprite if icon_sprite else self)
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "beam_update", target.global_position, {
			"from_pos": origin_node_update.global_position
		})
	_beam_tick_timer -= delta
	if _beam_tick_timer <= 0.0:
		_beam_tick_timer += effective_tick_interval
		_deal_beam_tick(target)


## Işını (varsa) kapatır - hedef kaybolduğunda/değiştiğinde çağrılır.
func _end_beam() -> void:
	if _beam_fx and is_instance_valid(_beam_fx):
		_beam_fx.queue_free()
	_beam_fx = null
	_beam_target = null
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "beam_stop", Vector2.ZERO, {})


func _attach_shadow_under_owner() -> void:
	if not (shadow_sprite and is_instance_valid(shadow_sprite)) or shadow_sprite.get_parent() != null:
		return
	var shadow_host: Node = get_parent()
	var foot_shadow: Node = shadow_host.get_node_or_null("Shadow") if shadow_host != null else null
	if foot_shadow != null:
		shadow_host.add_child(shadow_sprite)
		shadow_host.move_child(shadow_sprite, foot_shadow.get_index() + 1)
		shadow_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	else:
		add_child(shadow_sprite)
		move_child(shadow_sprite, 0)
	shadow_sprite.queue_redraw()


## Silah satılır/yok edilirse (bkz. player.gd remove_owned_weapon) açık kalmış
## bir ışın varsa (Şimşek Asası) sahipsiz kalmasın diye o da serbest bırakılır.
func _exit_tree() -> void:
	if continuous_beam:
		_end_beam()
	## Gölge artık sahibin çocuğu (bkz. shadow_sprite kurulumu) - silahla birlikte gitsin.
	if shadow_sprite and is_instance_valid(shadow_sprite) and shadow_sprite.get_parent() != self:
		if shadow_sprite.get_parent() == null:
			shadow_sprite.free() ## henüz ağaca girmemiş (ertelenmiş ekleme) - sızıntı olmasın
		else:
			shadow_sprite.queue_free()


## Şimşek Asası artık saniyede 3 kez tik atıyor (beam_tick_interval taban
## 1/3sn), her tik TAM hasarın sadece %33'ünü veriyor (bkz. kullanıcı
## bildirimi: "saniyede 3 defa hasar vermesini ve her hasarın %33 vurmasını
## istiyorum, bu sayede hedef değiştirince tek atmıcak ve vurunca hiç
## vurmuyormuş gibi gözükmücek") - toplam saniyelik hasar ~aynı kalır
## (3 x %33 = %99 ≈ damage), sadece çok daha sık/küçük parçalara bölünmüş
## olur; hem "hedef değişince anında tek vuruşla öldürüyor" hissini hem de
## "vurunca hiç vurmuyormuş gibi" boşluk hissini ortadan kaldırır.
const BEAM_TICK_DAMAGE_RATIO := 0.33

## Şimşek Asası'nın tik hasarı: normal _fire_at()'teki hasar hesaplama
## zinciriyle AYNI (rage/aggressive/shield modu/kritik), sadece FireTimer
## yerine beam_tick_interval'a bağlı. Birincil hedefe BEAM_TICK_DAMAGE_RATIO
## kadarı, chain_jump_count kadar EK (en yakın farklı) düşmana bunun da
## chain_damage_percent'i kadarı uygulanır (bkz. _apply_chain_jumps).
func _deal_beam_tick(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return
	var final_damage: float = damage * BEAM_TICK_DAMAGE_RATIO * rage_multiplier
	final_damage *= 1.0 + _player_stat("aggressive_damage_bonus") + _player_stat("talon_damage_bonus")
	final_damage *= _player_stat_default("shield_mode_damage_mult", 1.0)
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		final_damage *= crit_damage
	var shield_pen: float = _player_stat("shield_mode_shield_pen_bonus") + weapon_shield_pen_bonus
	## Elara TEMEL/ULTİ - bkz. _fire_at()'teki birebir aynı blok. Sürekli ışın
	## (Şimşek Asası) nadiren de olsa Elara'ya verilirse tikleri de aynı
	## kurala uysun diye burada da tekrarlanıyor.
	if _elara_true_damage_active():
		shield_pen = 1.0
	if _player_flag("elara_double_fire_active"):
		final_damage *= ELARA_DOUBLE_FIRE_DAMAGE_MULT
	## Eldiven/Sigara: item_flat_hit_damage (düz +hasar) ve
	## item_damage_mult_bonus (%hasar artışı) - bkz. items.gd.
	final_damage += _player_stat("item_flat_hit_damage")
	final_damage *= 1.0 + _player_stat("item_damage_mult_bonus")
	shield_pen += _player_stat("shield_pen_percent") + _player_stat("spirit_shield_pen") ## + Ruhani Yetenek "Adc" (%15)
	target.take_damage(final_damage, is_crit, shield_pen)
	## Şaman pasifi: bu tik = 1 "saldırı" (bkz. enemy.gd try_shaman_weapon_burn
	## üstündeki not) - yakma bu tikte EN FAZLA 1 düşmanda (birincil hedef ya
	## da bir sekme hedefi) tetiklenebilir, aşağı _apply_chain_jumps'a taşınır.
	var _shaman_burn_applied: bool = false
	if target.has_method("try_shaman_weapon_burn"):
		_shaman_burn_applied = target.try_shaman_weapon_burn()
	if chain_jump_count > 0:
		_apply_chain_jumps(target, final_damage * chain_damage_percent, is_crit, shield_pen, _shaman_burn_applied)
	fired.emit((target.global_position - global_position).normalized())
	_apply_item_slow_on_hit(target)


## Birincil hedefe EN YAKIN chain_jump_count kadar farklı düşmana (birincil
## hedefin kendisi hariç) chain_damage kadar hasar uygular. Her sıçrama
## bir önceki hedeften yeni hedefe görsel bir elektrik arkı (fx_lightning_
## chain) bırakır - önceden bu efekt hiç oluşturulmuyordu (bkz.
## FxLightningChainScene yorumu), sıçrama tamamen görünmezdi.
func _apply_chain_jumps(primary: Node2D, chain_damage: float, is_crit: bool, shield_pen: float, shaman_burn_applied: bool = false) -> void:
	var candidates: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == primary or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not e.has_method("take_damage"):
			continue
		if not VisionFogScript.can_target(e):
			continue
		## DÜZELTME: sekme artık sadece birincil hedefin CHAIN_JUMP_RANGE
		## yarıçapı içindeki yaratıkları aday sayıyor (bkz. sabit üstündeki not).
		if primary.global_position.distance_to(e.global_position) > CHAIN_JUMP_RANGE:
			continue
		candidates.append(e)
	candidates.sort_custom(func(a, b):
		return primary.global_position.distance_to(a.global_position) < primary.global_position.distance_to(b.global_position))
	var n: int = min(chain_jump_count, candidates.size())
	## Zincir görsel olarak sırayla sıçrasın diye (birincil -> 1. -> 2. -> ...)
	## bir önceki hedefi takip ediyoruz - sadece hepsi birincilden ayrı ayrı
	## sıçramış gibi değil, gerçek bir "zincir" hissi versin diye.
	var chain_from: Node2D = primary
	for i in range(n):
		var chain_to: Node2D = candidates[i]
		chain_to.take_damage(chain_damage, is_crit, shield_pen, true) ## zincir sıçraması = alan
		if not shaman_burn_applied and chain_to.has_method("try_shaman_weapon_burn"):
			shaman_burn_applied = chain_to.try_shaman_weapon_burn()
		_spawn_chain_lightning_fx(chain_from, chain_to)
		chain_from = chain_to


## Bkz. _apply_chain_jumps üstündeki yorum - iki düşman arasında (veya
## birincil hedeften ilk sıçramaya) kısa ömürlü bir zikzak elektrik arkı
## oluşturur ve multiplayer'da uzak oyunculara da yayınlar.
func _spawn_chain_lightning_fx(from_node: Node2D, to_node: Node2D) -> void:
	if not FxLightningChainScene or not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return
	var fx: Node2D = FxLightningChainScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	if fx.has_method("setup"):
		fx.setup(from_node, to_node)
	## DÜZELTME: bu RPC, dosyadaki DİĞER tüm kozmetik broadcast'lerin
	## (muzzle_flash, recoil, wfire, hitscan_impact - hepsi NetworkManager.
	## should_throttle ile sınırlanıyor) aksine hiç throttle edilmiyordu.
	## _apply_chain_jumps() bunu HER sıçrama için ayrı ayrı çağırıyor (bkz.
	## o fonksiyondaki for döngüsü) ve bu da (özellikle Şimşek Asası'nın
	## saniyede 3 tik atan sürekli ışınıyla, bkz. _deal_beam_tick) chain_
	## jump_count arttıkça saniyede onlarca unreliable RPC'ye çıkıyordu.
	## Ziva relay'i bunu "flood" sayıp bağlantıyı sessizce kapatıyor (bkz.
	## dosya başındaki network_manager.gd notu) - katılımcıların Şimşek
	## Asası ateş eder etmez/oyuna girer girmez oyundan düşmesinin/donmasının
	## asıl nedeni muhtemelen buydu. Diğerleriyle aynı desene uyup burada da
	## throttle uyguluyoruz.
	if NetworkManager.is_multiplayer_active and not NetworkManager.should_throttle("chain_%d" % multiplayer.get_unique_id(), 0.05):
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "chain_lightning", to_node.global_position, {
			"from_pos": from_node.global_position,
		})


## Kitelama Seti: item_enemy_slow_percent > 0 ise hasar verilen düşmana 5sn'lik
## hareket yavaşlatma uygular (bkz. enemy.gd apply_slow/_process_slow) - hasar
## vermek etkiyi baştan başlatır (kullanıcı isteği), stack YAPMAZ. Item
## sahip değilse (item_enemy_slow_percent=0) hiçbir şey yapmaz.
func _apply_item_slow_on_hit(target: Node2D) -> void:
	var slow_percent: float = _player_stat("item_enemy_slow_percent")
	if slow_percent > 0.0 and is_instance_valid(target) and target.has_method("apply_slow"):
		target.apply_slow(slow_percent, 5.0)


func _fire_at(target: Node2D) -> void:
	## Şaman pasifi (Totem Auraları): bu TEK saldırı (bu _fire_at() çağrısı -
	## alan hasarlı bir yakın dövüş vuruşu birden fazla düşmana değebilir)
	## kapsamında yakma EN FAZLA 1 düşmanda tetiklenebilir - bkz. enemy.gd
	## try_shaman_weapon_burn() üstündeki kök neden notu.
	var _shaman_burn_applied: bool = false
	## Tabanca (Revolver): mermi tükenmişse ateş etmeden reload'a gir (normalde
	## _on_fire_timer_timeout zaten reload sırasında buraya hiç girmez, bu
	## sadece güvenlik amaçlı). Mermi varsa bu atışı düşür; sıfıra inerse
	## atış GERÇEKLEŞTİKTEN sonra reload başlasın diye kontrol en altta.
	if max_ammo > 0:
		if current_ammo <= 0:
			_start_reload()
			return
		current_ammo -= 1
		if current_ammo <= 0:
			## Son mermi bu atışla gitti - reload hemen başlar (bu atışın
			## kendisi normal şekilde gerçekleşmeye devam eder, aşağıdaki
			## kod hiç etkilenmez; icon_sprite görünmez olur ama geri tepme
			## tween'i zararsızca boşa döner).
			_start_reload()

	## Yay: gerçek atış anında elde tutulan ok görseli kaybolur - _fire_at
	## sonunda başlayacak bir sonraki çekiliş döngüsü onu tekrar görünür yapar.
	if draw_before_fire and held_arrow:
		held_arrow.visible = false

	var final_damage: float = damage * rage_multiplier
	final_damage *= 1.0 + _player_stat("aggressive_damage_bonus") + _player_stat("talon_damage_bonus")
	final_damage *= _player_stat_default("shield_mode_damage_mult", 1.0) ## Tank Modu: -25% while active
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		final_damage *= crit_damage
	## Arcane Asası pasifi: canı %30'un altındaki düşmanlara %30 fazla hasar.
	if _is_arcane and "health" in target and "max_health" in target:
		var target_max_health: float = float(target.get("max_health"))
		if target_max_health > 0.0 and float(target.get("health")) <= target_max_health * ARCANE_EXECUTE_HP_THRESHOLD:
			final_damage *= ARCANE_EXECUTE_DAMAGE_MULT
	var direction: Vector2 = (target.global_position - global_position).normalized()
	var parent_node: Node = get_parent()
	if parent_node and parent_node.has_method("get_skill_character_id") and parent_node.get_skill_character_id() == 5:
		var line_scene: PackedScene = preload("res://scenes/fx_speed_line.tscn")
		if line_scene:
			var line: Node2D = line_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(line)
			line.global_position = global_position
			line.setup(direction, Color(0.3, 0.05, 0.5, 0.95))
	## Hedefin konumu BİR KEZ burada yakalanır - aşağıda _apply_knockback
	## hedefi itip global_position'ını değiştirebiliyor, eğer ikon (yukarıda)
	## ve efekt (aşağıda) konumu iki farklı zamanda okusaydı ikisi birbirinden
	## kopardı. Artık ikisi de aynı, tutarlı noktayı kullanıyor.
	var target_pos_at_attack: Vector2 = target.global_position
	## melee_lunge_range_ratio > 0 olan silahlerde ikon VE efekt hedefin O ANKİ
	## gerçek konumuna değil, saldırı yönünde attack_range'in bu oranı kadar
	## SABİT bir noktaya giderdi - bkz. melee_lunge_range_ratio yorumu. Kullanıcı
	## bunun "yaratıkların üstüne saldırmıyor" görünmesine yol açtığını bildirdi,
	## bu yüzden artık HİÇBİR silah (Pençe/Topuz/Uzunkılıç dahil) bu parametreyi
	## configure_melee()'ye vermiyor - hepsi varsayılan 0.0'da, yani melee_at_
	## position HER ZAMAN gerçek hedef konumu (target_pos_at_attack) ile aynı.
	## Mekanizma ileride tekrar gerekirse diye kodda duruyor, şu an no-op.
	var melee_at_position: Vector2 = target_pos_at_attack
	if melee and melee_lunge_range_ratio > 0.0:
		melee_at_position = global_position + direction * (attack_range * melee_lunge_range_ratio)
	## Efektler (savuruş + isabet) artık DAMAGE/knockback'ten ÖNCE, burada
	## spawn ediliyor - konumları (melee_at_position/target_pos_at_attack)
	## zaten hasardan/knockback'ten önce sabitlendiği için bu sıralama
	## değişikliği hiçbir hasar/knockback değerini etkilemez, sadece
	## _do_melee_swing'e "ne kadar bekleyip döneceğini" (hold_duration)
	## önceden söyleyebilmemizi sağlar - bkz. kullanıcı bildirimi: "kesme
	## efekti bitmeden kılıcın geri dönmesi [sorunu]".
	var melee_effect_hold: float = 0.0
	if melee:
		var fx_speed: float = _melee_effect_speed_scale()
		var slash_fx_node: Node2D = _spawn_slash_fx(direction, melee_at_position, fx_speed)
		var hit_fx_node: Node2D = _spawn_melee_hit_fx(direction, target_pos_at_attack, fx_speed)
		if NetworkManager.is_multiplayer_active:
			var s_key: String = String(get_meta("shop_key", "dagger"))
			NetworkManager.broadcast_weapon_attack.rpc(global_position, target_pos_at_attack, s_key, "melee")
		melee_effect_hold = max(
			_fx_playback_duration(slash_fx_node, fx_speed),
			_fx_playback_duration(hit_fx_node, fx_speed))
		## Menzilli silahların ateş yönünün TERSİNE kaçtığı "geri tepme"
		## yerine, yakın dövüşte ikon hedefe doğru hızlı ileri-geri
		## (kesiyormuş gibi) hareket eder - bkz. _do_melee_swing(). Artık
		## efekt(ler) tamamen bitmeden dönmeye başlamıyor (melee_effect_hold).
		_do_melee_swing(direction, melee_at_position, melee_effect_hold)
		if NetworkManager.is_multiplayer_active:
			_broadcast_weapon_fire_anim(direction, melee_at_position, melee_effect_hold)
	else:
		_do_recoil(direction)
		_spawn_muzzle_flash(direction)
		if NetworkManager.is_multiplayer_active:
			_broadcast_weapon_fire_anim(direction)

	## Delicilik Modu (oyuncu geneli) + Uzunkılıç/Tüfek/Topuz gibi silaha özel
	## kalkan delme (weapon_shield_pen_bonus, diğer tüm silahlerde 0 - no-op).
	var shield_pen: float = _player_stat("shield_mode_shield_pen_bonus") + weapon_shield_pen_bonus

	## Tüftüf: her zaman gerçek hasar (bkz. always_true_damage üstündeki
	## yorum) - Elara'nın geçici hakkının aksine bonus çarpan YOK, sadece
	## kalkan yok sayılıyor.
	if always_true_damage:
		shield_pen = 1.0

	## Elara TEMEL (E) açıkken bu atış kalkanı tamamen yok sayar (gerçek hasar; bonus hasar 2026-09-25'te kaldırıldı,
	## bkz. TRUE_DAMAGE_ATTACK_SPEED_BONUS notu) - diğer tüm karakterlerde bayrak yok (no-op). Elara ULTİ (R) aktifken
	## (bkz. player.gd elara_double_fire_active) her atış sadece %60 hasar verir - "2 kez tetiklenir" kısmı bu
	## fonksiyonun İKİ KEZ çağrılmasıyla dışarıda sağlanıyor (bkz. _on_fire_timer_timeout, _process draw-ready dalı),
	## burada sadece oran düşüyor.
	if _elara_true_damage_active():
		shield_pen = 1.0
	if _player_flag("elara_double_fire_active"):
		final_damage *= ELARA_DOUBLE_FIRE_DAMAGE_MULT

	## Eldiven/Sigara: item_flat_hit_damage (düz +hasar) ve
	## item_damage_mult_bonus (%hasar artışı) - bkz. items.gd. Keskin Uçlar:
	## shield_pen_percent genel kalkan delme.
	final_damage += _player_stat("item_flat_hit_damage")
	final_damage *= 1.0 + _player_stat("item_damage_mult_bonus")
	shield_pen += _player_stat("shield_pen_percent") + _player_stat("spirit_shield_pen") ## + Ruhani Yetenek "Adc" (%15)

	if melee:
		if target.has_method("take_damage"):
			## Bölünmüş vuruş (Assasin Çocuk): tek seferde tam hasar yerine,
			## eşit parçalara bölünüp art arda uygulanır - "-30" yerine
			## sırayla "-10","-10","-10" gibi. Geri tepme tek seferde,
			## saldırının başında uygulanır (vuruş anındaki fiziksel itiş).
			_apply_knockback(target)
			_deal_melee_damage(target, final_damage, is_crit, shield_pen)
			_apply_item_slow_on_hit(target)
			## Hançer: birincil hedefte kanama yükü bırakır (bkz. enemy.gd
			## apply_bleed) - diğer tüm silahlerde bleed_max_stacks=0, no-op.
			if bleed_max_stacks > 0 and target.has_method("apply_bleed"):
				target.apply_bleed(bleed_tick_damage_per_stack, bleed_stacks_per_hit, bleed_max_stacks)
			## Pençe: SADECE bu silahın kendi vuruşundan can çalar - diğer tüm
			## silahlerde lifesteal_percent=0, no-op (bkz. _apply_weapon_lifesteal).
			if lifesteal_percent > 0.0:
				_apply_weapon_lifesteal(final_damage)
			if target.has_method("try_shaman_weapon_burn"):
				_shaman_burn_applied = target.try_shaman_weapon_burn()
		## Hafif alan hasarı: hedefin çevresindeki diğer düşmanlar da
		## savuruştan pay alır (tam hasarın melee_aoe_damage_percent'i).
		## DÜZELTME (kullanıcı bildirimi: "yaratıklara tam saldırırken anlık
		## fps düşürüyor") - HER yakın dövüş vuruşunda TÜM "enemies" grubunu
		## (158'e kadar) tarayıp mesafe hesaplıyordu; artık Enemy.
		## get_enemies_near ile (bkz. enemy.gd - ayrışma ızgarasının genel
		## amaçlı sürümü) SADECE gerçekten menzildeki yaratıklar geliyor.
		## Hayalet hedefe (Talon Salvosu, ışında yaratık yok) savurulmuşsa gerçek bir vuruş yok: etrafına
		## alan payı da dağıtılmaz (aksi halde boşa atan silah alan hasarı veriyordu).
		var aoe_victims: Array = Enemy.get_enemies_near(get_tree(), target.global_position, melee_aoe_radius * aoe_radius_multiplier) if target.has_method("take_damage") else []
		for e in aoe_victims:
			if e == target:
				continue
			if e.has_method("take_damage"):
				## DÜZELTME (kullanıcı isteği 2026-09-24: "alan hasarı veren silahların efektifliğinin %33 olmasını
				## istemiyorum") - eskiden burada ayrıca ×0.33 (GameManager.AOE_DAMAGE_EFFECTIVENESS) vardı; asıl istek
				## sadece alan hasarında CAN EMMENİN %33 olmasıydı (LIFESTEAL_EFFECTIVENESS, dokunulmadı). Sıçrama artık
				## silahın kendi melee_aoe_damage_percent payını (varsayılan %50) aynen verir.
				e.take_damage(final_damage * melee_aoe_damage_percent, false, shield_pen, true)
				_apply_knockback(e)
				_apply_item_slow_on_hit(e)
				## Hançer: kullanıcı isteği - kanama sadece isabet ettiği İLK
				## yaratığa değil, savuruşun değdiği TÜM yaratıklara
				## uygulanmalı (bkz. yukarıdaki birincil hedef bleed'i, diğer
				## tüm silahlerde bleed_max_stacks=0, no-op).
				if bleed_max_stacks > 0 and e.has_method("apply_bleed"):
					e.apply_bleed(bleed_tick_damage_per_stack, bleed_stacks_per_hit, bleed_max_stacks)
				## Şaman pasifi: kullanıcı isteği - alan hasarlı bir savuruş
				## değdiği TÜM düşmanları değil, bu saldırı başına SADECE 1
				## düşmanı yakabilir (bkz. _shaman_burn_applied üstündeki not).
				if not _shaman_burn_applied and e.has_method("try_shaman_weapon_burn"):
					_shaman_burn_applied = e.try_shaman_weapon_burn()
		## Efektler artık YUKARIDA (hasar/knockback'ten ÖNCE) spawn edildi -
		## bkz. melee_effect_hold ve _do_melee_swing çağrısı.
		fired.emit(direction)
		_play_attack_sound()
		return

	if hitscan:
		if target.has_method("take_damage"):
			target.take_damage(final_damage, is_crit, shield_pen)
			_apply_knockback(target)
			_apply_item_slow_on_hit(target)
			if target.has_method("try_shaman_weapon_burn"):
				_shaman_burn_applied = target.try_shaman_weapon_burn()
		if impact_scene:
			var fx = impact_scene.instantiate()
			get_tree().current_scene.add_child(fx)
			if fx.has_method("setup"):
				var origin_node: Node2D = muzzle if muzzle else (icon_sprite if icon_sprite else self)
				fx.setup(origin_node, target)
			else:
				fx.global_position = target.global_position
			# Broadcast hitscan impact to remote players
			## Relay flood korumasına takılmamak için sınırlanıyor (bkz.
			## NetworkManager.should_throttle) - çok hızlı ateş eden silahlar
			## saniyede onlarca isabet efekti göndermeye çalışabilir.
			if NetworkManager.is_multiplayer_active and not NetworkManager.should_throttle("hitscan_%d" % multiplayer.get_unique_id(), 0.08):
				NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "hitscan_impact", target.global_position, {
					"scene_path": impact_scene.resource_path
				})
		fired.emit(direction)
		_play_attack_sound()
		return

	if not projectile_scene:
		return
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	proj.direction = direction
	if "face_direction" in proj and proj.face_direction:
		proj.rotation = direction.angle() + ranged_projectile_rotation_offset
	if ranged_projectile_scale_mult != 1.0:
		proj.scale *= ranged_projectile_scale_mult
	## Merminin ölçeğini karakterin ölçeğiyle senkronize et (büyük görünmesini
	## engeller). ÖNEMLİ: burada silahın kendi `scale`'ini (self.scale)
	## KULLANMIYORUZ - doğrudan karakterin (parent) scale'ini okuyoruz.
	## Sebep: Asa tipi silahlerde (_update_hover_follow'daki is_wand dalı)
	## self.scale, SADECE kafanın üstünde süzülen İKONUN küçük görünmesi için
	## karakter scale'inin 0.3 katına düşürülüyor. Eskiden burada self.scale
	## okunduğundan bu kozmetik ikon küçültmesi mermiye de sızıyor, TÜM asa
	## türlerinin (Arkan/Ateş/Buz Asası vb.) mermilerini gereksiz yere %70
	## küçültüyordu - kullanıcı bildirimi: "asaların attığı projectileların
	## boyutu çok küçük ... bazıları normal bazıları küçük" (tabanca/yay gibi
	## asa OLMAYAN menzilli silahler bu küçülmeye tabi olmadığından "normal",
	## asalar ise hep küçük görünüyordu).
	var char_scale: Vector2 = Vector2.ONE
	var owner_char: Node = get_parent()
	if owner_char and owner_char is Node2D:
		char_scale = (owner_char as Node2D).scale
	proj.scale *= char_scale
	proj.damage = final_damage
	proj.is_crit = is_crit
	proj.shield_pen_percent = shield_pen
	if "knockback_force" in proj:
		proj.knockback_force = _player_stat("knockback_force")
	## Arcane Asası pasifi: mermi, öldürdüğü hedefi bu silaha bildirsin diye
	## kendisini kaydediyor (bkz. notify_kill/_trigger_arcane_burst, ve
	## projectile.gd _on_body_entered'ın sonundaki kill bildirimi). Diğer
	## silahlerde source_weapon hiç okunmadığı için no-op.
	if "source_weapon" in proj:
		proj.source_weapon = self
	## Kitelama Seti (bkz. items.gd/enemy.gd apply_slow): eskiden sadece
	## melee/hitscan isabetlerinde uygulanıyordu, mermi fırlatan (projectile_
	## scene kullanan) TÜM menzilli silahlerde (Tabanca/Tüfek/Yay/Arbalet/
	## Tüftüf/Fişek/Arkan/Ateş/Buz Asası vb.) hiç tetiklenmiyordu - bkz.
	## kullanıcı bildirimi: "yaratıkları yavaşlatmıyor". Artık knockback_force
	## ile birebir aynı şekilde mermiye taşınıyor (bkz. projectile.gd
	## _on_body_entered).
	if "slow_percent" in proj:
		proj.slow_percent = _player_stat("item_enemy_slow_percent")
	## Tüftüf: mevcut tier'in dart görseli mermiye uygulanır (Bullet adlı
	## Sprite2D varsa) ve zehir bilgisi mermiye taşınır - proje.gd çarpınca
	## hedefe apply_poison() çağırır (bkz. projectile.gd).
	if not tier_dart_textures.is_empty() and proj.has_node("Bullet"):
		var idx: int = clamp(_current_tier - 1, 0, tier_dart_textures.size() - 1)
		proj.get_node("Bullet").texture = tier_dart_textures[idx]
	if poison_tick_damage > 0.0 and "poison_tick_damage" in proj:
		proj.poison_tick_damage = poison_tick_damage
		proj.poison_max_stacks = poison_max_stacks
		proj.poison_duration = poison_duration
	## Tüfek: delici mermi - birincil hedeften sonra pierce_count kadar ek
	## düşmana daha (azalan yüzde hasarla) çarpar (bkz. projectile.gd).
	if pierce_count > 0 and "pierce_count" in proj:
		proj.pierce_count = pierce_count
		proj.pierce_damage_percent = pierce_damage_percent
	## Tabanca: hedefte biriken "yük" (mark) sayısının azami tavanı - bkz.
	## projectile.gd _on_body_entered.
	if mark_max_stacks > 0 and "mark_max_stacks" in proj:
		proj.mark_max_stacks = mark_max_stacks
	## Buz Asası: her isabette hedefe soğuma yükü uygular (bkz. projectile.gd
	## _on_body_entered, enemy.gd apply_chill).
	if chill_stacks_per_hit > 0 and "chill_stacks" in proj:
		proj.chill_stacks = chill_stacks_per_hit
	## Ateş Asası pasifi: her isabette hedefi yakar (bkz. projectile.gd
	## _on_body_entered/_apply_splash_damage, enemy.gd apply_burn).
	if burn_on_hit_tick_damage > 0.0 and "burn_on_hit_tick_damage" in proj:
		proj.burn_on_hit_tick_damage = burn_on_hit_tick_damage
	## Fişek: hedefin ateş anındaki SABİT konumu (aşağıda knockback ile
	## değişebilecek target.global_position değil, en üstte bir kez yakalanan
	## target_pos_at_attack) - mermi her zaman bu noktaya iner (bkz.
	## firework_projectile.gd). Diğer tüm mermilerde bu alan yok, no-op.
	if "target_position" in proj:
		proj.target_position = target_pos_at_attack
	if splash_radius_mult != 1.0 and "splash_radius" in proj:
		proj.splash_radius *= splash_radius_mult
	## Boomerang: tier'e göre büyüyen gidiş/dönüş hız çarpanı + havada tek
	## mermi kısıtlaması (bkz. player.gd _apply_boomerang_tier,
	## boomerang_projectile.gd).
	if projectile_speed_mult != 1.0 and "speed" in proj:
		proj.speed *= projectile_speed_mult
	if single_active_projectile:
		## Kullanıcı isteği (2026-09-24 denge turu: "boomerangın hızını azaltıp saldırı hızına bağlı olarak hızlı
		## gidip dönmesini sağla") - bumerang havada tek mermiyle sınırlı olduğu için saldırı hızı kartları ona HİÇ
		## yaramıyordu (uçuş süresi ~1.4sn'ye kilitliydi). Artık taban hız x0.8, üstüne saldırı hızı oranı (taban atış
		## aralığı / şu anki etkin aralık - kartlar, eşyalar, Elara Gerçek Hasar vb. dahil) kadar hızlanır. Uzak
		## oyunculara giden hız aşağıdaki proj_speed okumasıyla bu son değerden alınır.
		if "speed" in proj:
			var attack_speed_ratio: float = _base_fire_rate / maxf(0.01, _effective_fire_wait()) if _base_fire_rate > 0.0 else 1.0
			proj.speed *= BOOMERANG_BASE_SPEED_MULT * maxf(1.0, attack_speed_ratio)
		_projectiles_in_flight += 1
		if "return_callback_target" in proj:
			proj.return_callback_target = self
		if "player_node" in proj:
			proj.player_node = get_parent()
		## Boomerang: kafanın üstünde süzülen ikon, mermi havadayken (dönene
		## kadar) gizlenir - "fırlatılan bumerang" ile "kafadaki bumerang"
		## AYNI ANDA görünüp iki ayrı bumerang varmış gibi durmasın diye (bkz.
		## kullanıcı bildirimi: "fırlatılan, kafadaki bumeranglardan olmalı,
		## ayrı bir projectile değil"). Yay'ın held_arrow'u gizleme deseniyle
		## birebir aynı mantık.
		if icon_sprite:
			icon_sprite.visible = false
			_broadcast_weapon_icon_visibility(false)
	## Fişek: kafanın üstündeki ikon, ateşlenen fişek(ler) havadayken (henüz
	## inip patlamadan) gizlenir - kullanıcı isteği: "fırlatıldığı esnada
	## karakterin üstünden de yok olmalı tekrar spawnlanana kadar". Fişek
	## single_active_projectile OLMADIĞI (üst üste birden fazla fişek havada
	## olabilir) için boomerang'daki gibi tek bir bool yerine bir SAYAÇ
	## kullanılıyor - havadaki fişek sayısı sıfıra inince (hepsi patlayınca)
	## ikon tekrar görünür olur (bkz. _on_ranged_projectile_landed).
	if hide_icon_while_projectile_flying:
		_flying_projectile_count += 1
		if icon_sprite:
			icon_sprite.visible = false
			_broadcast_weapon_icon_visibility(false)
		if "return_callback_target" in proj:
			proj.return_callback_target = self
	## Multiplayer: broadcast projectile so other players see it.
	if NetworkManager.is_multiplayer_active:
		var scene_path: String = projectile_scene.resource_path
		var proj_speed: float = proj.get("speed") if "speed" in proj else 0.0
		var proj_scale: Vector2 = proj.scale
		var target_pt: Vector2 = proj.get("target_position") if "target_position" in proj else Vector2.ZERO
		NetworkManager.broadcast_projectile.rpc(scene_path, global_position, direction, proj_speed, proj_scale, target_pt, multiplayer.get_unique_id())
	fired.emit(direction)
	_play_attack_sound()
	if draw_before_fire:
		_start_draw_cycle()


## Silahın bu karaktere özel savuruş efekti sahnesi ("" = prosedürel pençe).
var melee_slash_fx_scene: String = ""
## Efektin karakter merkezinden ne kadar dışa kaydırılacağı (karaktere özel;
## bkz. Characters.DEFS "slash_fx_offset"). 0 = tam merkezde, sadece
## saldırı yönüne döner (ör. hilal efekti).
var melee_slash_fx_offset: float = 95.0
## Efekt VE savuruş ikonu (bıçak) ikisi de hedefin bu kadar üzerine
## (ekrana göre sabit, yukarı) kaydırılır - ikisi de AYNI sabitten okuduğu
## için birbirinden kopup uzaklaşmazlar (bkz. _spawn_slash_fx ve
## _do_melee_swing). "Efektle bıçak aynı yerde olmalı" + "üstlerine doğru
## gitsin" isteklerinin ikisini birden karşılamak için eklendi.
## ÖNEMLİ: bu değer melee_range'den (110) BÜYÜK olmamalı - yoksa hedefe doğru
## olan yer değiştirme (max ~menzil kadar) bu sabit tarafından ezilir ve nokta
## hedeften kopup oyuncunun tepesine doğru kayar (120 denendi, tam da bu
## hataya yol açtı - "yaratıkların üstünde değil karakterin üstünde rastgele
## bir konumda" diye bildirildi). Artık menzilin çok altında, ılımlı bir
## değer: yaratığın üst gövdesine/başına doğru iner ama ondan kopmaz.
# Kullanıcı isteği: Saldırı efekti ve silah hamlesi yaratığın üstünde (yukarı kaymış) değil,
# tam olarak yaratığın bulunduğu konumda tetiklenir (above_offset = 0.0).
var melee_slash_fx_above_offset: float = 0.0
## Efektin sprite'ı saldırı yönüyle tam simetrik çizilmemiş olabilir (ör.
## hilal biraz bir yana açık duruyor) - bu, saldırı yönüne eklenen sabit bir
## düzeltme açısı (radyan), merkezi/konumu etkilemez, sadece görsel yönü ince
## ayarlar (bkz. Characters.DEFS "slash_fx_rotation_offset").
var melee_slash_fx_rotation_offset: float = 0.0
## true ise efekt saldırı yönüne göre hiç dönmez - rotasyonu her zaman
## melee_slash_fx_rotation_offset'te sabit kalır, sadece KONUMU (hangi
## tarafta belireceği) saldırı yönüne göre değişir. Yere vuran bir darbe/
## patlama gibi, her zaman aynı açıda "yere çakılmış" görünmesi gereken
## efektler için (ör. Şovalye Adam'ın gürz darbesi - bkz. Characters.DEFS
## "slash_fx_fixed_rotation").
var melee_slash_fx_fixed_rotation: bool = false
## true ise (sabit rotasyonla birlikte kullanılır) efekt döndürülmez, bunun
## yerine saldırı yönüne göre yatay/dikey AYNALANIR (flip_h/flip_v) - ör.
## Şovalye Adam'ın yere vuran darbesi hep aynı açıda kalır ama sola/sağa,
## yukarı/aşağı saldırınca aynalanarak yön hissi verir (bkz. Characters.DEFS
## "slash_fx_mirror").
var melee_slash_fx_mirror: bool = false

## Dagger (Characters.MAIN_WEAPON) HİÇ dokunulmadı: 0.0 = eski davranış,
## ikon/efekt hedefin O ANKİ gerçek mesafesine göre lunge yapar (bkz.
## _fire_at, _do_melee_swing) - bu da hedef zaten çok yakınken (sık rastlanan
## durum) neredeyse hiç lunge olmamasına yol açıyordu ("hedefe fazla
## yaklaşmıyorlar" - bkz. kullanıcı bildirimi). >0.0 (Pençe/Topuz/Uzunkılıç'ta
## ~0.85) ise lunge mesafesi artık gerçek hedef mesafesinden BAĞIMSIZ, doğrudan
## attack_range'in bu oranı kadar sabit bir mesafeye gider - "menziline bağlı
## olarak karakterden uzaklaşıp" isteğini karşılar, her saldırıda tutarlı,
## belirgin bir atılım hissi verir. Hasar/AOE hesaplaması bu görsel konumdan
## TAMAMEN bağımsız (gerçek target node'una göre çalışır), o yüzden bu sadece
## kozmetik bir değişiklik, oynanışı etkilemez.
var melee_lunge_range_ratio: float = 0.0


## Ana hedefe hasarı melee_hit_segments'e göre böler: 1 ise eskisi gibi tek
## seferde, >1 ise eşit parçalara bölüp melee_hit_segment_delay arayla art
## arda uygular (her parça enemy.take_damage'ı ayrı çağırdığı için ekranda
## ayrı ayrı hasar sayıları belirir). Hedef ilk parçalardan ölürse
## enemy.take_damage zaten is_dead kontrolüyle sonraki parçaları no-op yapar.
func _deal_melee_damage(target: Node, total_damage: float, is_crit: bool, shield_pen: float) -> void:
	if melee_hit_segments <= 1:
		target.take_damage(total_damage, is_crit, shield_pen)
		return
	var per_hit: float = total_damage / float(melee_hit_segments)
	for i in range(melee_hit_segments):
		if i == 0:
			target.take_damage(per_hit, is_crit, shield_pen)
		else:
			get_tree().create_timer(i * melee_hit_segment_delay).timeout.connect(
				_apply_delayed_segment.bind(target, per_hit, is_crit, shield_pen))


func _apply_delayed_segment(target: Node, amount: float, is_crit: bool, shield_pen: float) -> void:
	## DÜZELTME (kullanıcı bildirimi: "Fişek tüfek ve bıçak market alanın
	## içinde saldırı yapmaya devam ediyor") - bu get_tree().create_timer()
	## ile gecikmeli tetiklendiği için (bkz. _deal_melee_damage), silahın
	## KENDİ process_mode'undan bağımsız çalışır - bir vuruş tam bölgeye
	## girerken başlamışsa sonraki parçaları hâlâ hasar verebiliyordu
	## (bıçağın 3 parçası en savunmasız - bkz. Characters.MAIN_WEAPON
	## melee_hit_segments).
	var owner_node := get_parent()
	if owner_node and owner_node.get("is_in_merchant_zone") == true:
		return
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(amount, is_crit, shield_pen)


## Pençe: vuruşun kendi hasarının lifesteal_percent'i kadarını doğrudan
## oyuncuya can olarak geri verir - player.gd'nin genel can çalma pasifinden
## (lifesteal_percent/on_damage_dealt) tamamen ayrı bir yol izler.
func _apply_weapon_lifesteal(amount: float) -> void:
	var parent := get_parent()
	if not parent or not ("health" in parent) or not ("max_health" in parent):
		return
	if parent.get("is_dead") == true:
		return
	var cur_health: float = parent.get("health")
	var max_hp: float = parent.get("max_health")
	if cur_health >= max_hp or amount <= 0.0:
		return
	## Kullanıcı isteği: "Pençenin can çalması can emme olarak gösterilecek ve
	## hesaplanacak yani bu can emme verilen hasarın %'liği olarak can
	## yenileyecek". ESKİ DÜZELTME (bkz. player.gd::
	## on_damage_dealt - genel Can Çalma kartı/eşyası için "%X ihtimalle 1 can")
	## Pençe'nin KENDİ can emmesini de olasılığa çevirmişti; bu geri alındı:
	## Pençe artık DETERMİNİSTİK, vurduğu hasarın lifesteal_percent'i kadar
	## can yeniler (hasar tabanlı; genel %33 GameManager.LIFESTEAL_EFFECTIVENESS
	## çarpanı BİLEREK uygulanmıyor - silah kartında/tooltip'inde yazan yüzde ile
	## gerçekte yenilenen aynı olsun).
	var new_health: float = min(max_hp, cur_health + amount * lifesteal_percent)
	parent.set("health", new_health)
	if parent.has_signal("health_changed"):
		parent.emit_signal("health_changed", new_health, max_hp)


## Yakın dövüşçüler için: silahı kısa menzilli, alan hasarlı moda alır,
## savuruş seslerini (kombo çalıcı) ve varsa özel savuruş efektini bağlar.
## Player, karakter tanımından (Characters.DEFS) çağırır.
func configure_melee(range_px: float, aoe_radius: float, aoe_percent: float,
		sound_paths: Array = [], slash_fx: String = "", slash_fx_offset: float = 95.0,
		slash_fx_rotation_offset: float = 0.0, hit_segments: int = 1,
		slash_fx_scale_mult: float = 1.0, sound_volume_db: float = -12.0,
		slash_fx_fixed_rotation: bool = false, slash_fx_mirror: bool = false,
		lunge_range_ratio: float = 0.0) -> void:
	if _is_uzunkilic:
		return
	melee = true
	attack_range = range_px
	_base_attack_range = range_px
	melee_aoe_radius = aoe_radius
	melee_aoe_damage_percent = aoe_percent
	melee_slash_fx_scene = slash_fx
	melee_slash_fx_offset = slash_fx_offset
	melee_slash_fx_rotation_offset = slash_fx_rotation_offset
	melee_hit_segments = max(1, hit_segments)
	melee_slash_fx_scale_mult = slash_fx_scale_mult
	melee_slash_fx_fixed_rotation = slash_fx_fixed_rotation
	melee_slash_fx_mirror = slash_fx_mirror
	melee_lunge_range_ratio = lunge_range_ratio
	if not sound_paths.is_empty() and get_node_or_null("AttackSound") == null:
		var s := Node2D.new()
		s.name = "AttackSound"
		s.set_script(load("res://scripts/melee_swing_sound.gd"))
		add_child(s)
		s.setup(sound_paths, sound_volume_db)


## _do_melee_swing (ikonu Z çizerek zigzag'a sokan aynı fonksiyon) ile bu
## fonksiyonun SON zigzag noktasını hesaplarken kullandığı formül BİREBİR
## aynı olmalı - aksi halde ikon savuruşun sonunda bir yana sıçrarken efekt
## tam ortada (kaymasız) kalır ve "silah bir yerde, efekt başka yerde"
## kopukluğu oluşur (bkz. kullanıcı bildirimi: "hasar verme efekti ile
## silahın SAVURULDUĞU yerde olması gerekiyor, direkt yaratığın üzerinde
## değil"). reps/side mantığı _do_melee_swing'in points[] döngüsüyle aynı.
func _melee_final_swing_offset(direction: Vector2) -> Vector2:
	var reps: int = max(1, melee_hit_segments)
	var last_side: float = 1.0 if (reps - 1) % 2 == 0 else -1.0
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	return perp * MELEE_ZIGZAG_SPREAD * last_side


## Savuruş efekti artık karakterden sabit bir mesafede DEĞİL, doğrudan
## hedefin (yaratığın) gerçek konumuna yakın bir noktada beliriyor - hedef
## menzil içinde nerede olursa olsun (yakın/uzak) efekt hep yaratığın
## üzerinde/hemen yanında çıkar. Tam üstüne binip görüşü kapatmasın diye
## saldırı yönünün TERSİNE (oyuncuya doğru) melee_slash_fx_offset kadar
## geri çekilir, ve melee_slash_fx_above_offset kadar yukarı kayar - bu
## İKİNCİ ofset, ikonun (_do_melee_swing) gittiği noktayla TAM AYNI sabitten
## okunur. ÜÇÜNCÜ olarak _melee_final_swing_offset() ile ikonun savuruşun
## SONUNDA sıçradığı zigzag kayması da eklenir (bkz. yukarıdaki not) - bu
## üçü sayesinde ikon efektle TAM AYNI dünya noktasına gelir, ikisi asla
## birbirinden kopup uzaklaşmaz. Saldırı yönüne göre döner (düşman hangi
## yöndeyse o yöne bakar). Karaktere özel efekt sahnesi (melee_slash_fx_scene)
## varsa o kullanılır, yoksa prosedürel pençe yayı (fx_slash.gd) çizilir (o,
## eskisi gibi karakterin tam merkezinde kalır).
## speed_scale: bkz. _melee_effect_speed_scale - efektin gerçek oynama hızı,
## saldırı hızıyla orantılı büyür ki kılıç/topuz efekt bitmeden dönmeyi
## BEKLERKEN bile hızlı saldırılarda tıkanmasın. Node2D'yi (fx'i) döner ki
## çağıran taraf (_fire_at) gerçek oynama süresini hesaplayabilsin (bkz.
## _fx_playback_duration).
func _spawn_slash_fx(direction: Vector2, at_position: Vector2, speed_scale: float = 1.0) -> Node2D:
	var fx: Node2D
	var is_image_fx := melee_slash_fx_scene != "" and ResourceLoader.exists(melee_slash_fx_scene)
	if is_image_fx:
		fx = (load(melee_slash_fx_scene) as PackedScene).instantiate()
	else:
		fx = Node2D.new()
		fx.set_script(load("res://scripts/fx_slash.gd"))
	
	# Efektin hareket halindeyken karakteri takip etmeyip dünyada sabit kalması için
	# doğrudan ana sahneye (current_scene) çocuk olarak ekliyoruz.
	get_tree().current_scene.add_child(fx)
	
	var parent_node = get_parent()
	var parent_global_pos = parent_node.global_position if parent_node is Node2D else global_position
	
	## Menzil kartlarıyla menzil büyüdükçe savuruş efekti de orantılı büyür
	## (sahnenin kendi taban ölçeği korunarak çarpılır).
	var grow_ratio: float = attack_range / _base_attack_range if _base_attack_range > 0.0 else 1.0
	if is_image_fx:
		fx.global_position = at_position - direction * melee_slash_fx_offset \
			+ Vector2(0, -melee_slash_fx_above_offset) + _melee_final_swing_offset(direction)
	else:
		# Görsel olmayan (prosedürel pençe vb.) efektleri cast edildiği andaki konuma sabitliyoruz
		fx.global_position = parent_global_pos
	## Sabit rotasyon modunda (ör. yere vuran bir darbe) efekt hep aynı açıda
	## durur - sadece konumu (hangi tarafta belireceği) yöne göre değişir.
	fx.rotation = melee_slash_fx_rotation_offset if melee_slash_fx_fixed_rotation \
		else direction.angle() + melee_slash_fx_rotation_offset
	var p_scale = parent_node.scale if parent_node is Node2D else Vector2.ONE
	## DÜZELTME (kullanıcı bildirimi: "talon ultisini açınca saldırıların
	## alanı büyümüyor, veya efektler büyümediği için büyümemiş gibi
	## görünüyor"): Talon'un Devleşme ultisi weapon.gd'nin aoe_radius_
	## multiplier'ını (bkz. dosya başındaki var tanımı, gerçek vuruş alanı
	## hesabında kullanılıyor - _fire_at içindeki melee_aoe_radius *
	## aoe_radius_multiplier satırı) 2 katına çıkarıyordu ama bu savuruş
	## efekti SADECE menzil kartlarının grow_ratio'suna göre büyüyordu -
	## aoe_radius_multiplier hiç hesaba katılmıyordu. Mekanik olarak alan
	## gerçekten 2 katına çıkıyordu ama görsel efekt aynı kalınca "büyümemiş
	## gibi" görünüyordu. Normal (aoe_radius_multiplier == 1.0) durumda bu
	## çarpım no-op, davranış değişmiyor.
	fx.scale *= grow_ratio * melee_slash_fx_scale_mult * aoe_radius_multiplier * p_scale
	## Ayna modu: rotasyon sabit kalırken efekt saldırı yönüne göre yatay/
	## dikey aynalanır - hep aynı taraftan saldırıyormuş hissi vermez.
	## fx.set() kullanılır çünkü flip_h/flip_v sadece Sprite2D/
	## AnimatedSprite2D'de var, fx'in statik tipi Node2D.
	if melee_slash_fx_mirror:
		fx.set("flip_h", direction.x < 0.0)
		fx.set("flip_v", direction.y < 0.0)
	if "speed_scale" in fx:
		fx.speed_scale = speed_scale
	## Pençe efekti (fx_claw_slash.gd) savuruşun MERKEZİNE hizalanır - konumu savuruşun son noktası (yukarısı), izler
	## ikonun süpürdüğü yol boyunca yırtılsın diye (kullanıcı isteği 2026-09-24: "saldırı animasyonuyla uyumlu").
	if is_image_fx and fx.has_method("align_to_swing"):
		fx.align_to_swing(-_melee_final_swing_offset(direction))
	return fx


## Savuruş efektinden (melee_slash_fx_scene, _spawn_slash_fx) TAMAMEN
## BAĞIMSIZ - kullanıcı düzeltmesi: "isabet halinde efektleri silah
## efektlerinden bağımsız ve ayrıdır onlar yaratıkların üzerinde çıkarlar."
## Bu yüzden silahın SAVURULDUĞU konum yerine doğrudan hedefin (yaratığın)
## ateş anındaki gerçek konumu (target_pos, çağrı yerinde target_pos_at_
## attack) kullanılır - ranged silahlerin _spawn_impact()'indeki mantıkla
## aynı fikir. Rotasyon (bkz. hit_impact_rotation_offset yorumu) saldırı
## yönüne göre ayarlanır - yoksa efekt sprite'ının kendi sabit "savrulma"
## açısı gerçek saldırı yönüyle çakışmayınca yanlış yöne doğru çıkmış gibi
## görünür. hit_impact_scene boşsa (dagger dahil, ayarlanmayan tüm
## silahlerde) hiçbir şey yapmaz.
func _spawn_melee_hit_fx(direction: Vector2, target_pos: Vector2, speed_scale: float = 1.0) -> Node2D:
	if not hit_impact_scene:
		return null
	var fx = hit_impact_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = target_pos
	fx.rotation = direction.angle() + hit_impact_rotation_offset
	if hit_impact_scale_mult != 1.0:
		fx.scale *= hit_impact_scale_mult
	## _spawn_slash_fx'teki AYNI düzeltme (bkz. oradaki not) - isabet efekti
	## de savuruş efektiyle aynı şekilde Talon Devleşme'nin aoe_radius_
	## multiplier'ı ile büyüsün diye. Normalde (1.0) no-op.
	if aoe_radius_multiplier != 1.0:
		fx.scale *= aoe_radius_multiplier
	if "speed_scale" in fx:
		fx.speed_scale = speed_scale
	# Broadcast melee hit impact to remote players
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "melee_hit", target_pos, {
			"scene_path": hit_impact_scene.resource_path,
			"rotation": fx.rotation,
			"scale_mult": aoe_radius_multiplier
		})
	return fx


## fx'in (AnimatedSprite2D tabanlı bir isabet/savuruş efekti) "play"
## animasyonunun GERÇEK (speed_scale uygulanmış) oynama süresi - _do_melee_
## swing'in dönmeden önce ne kadar bekleyeceğini hesaplamak için kullanılır
## (bkz. kullanıcı isteği: "efekt bitmeden kılıç geri dönmesin"). fx null'sa
## ya da AnimatedSprite2D/SpriteFrames tabanlı değilse (ör. prosedürel pençe
## yayı fx_slash.gd) 0 döner - bekleme yok, eski davranış.
func _fx_playback_duration(fx: Node2D, speed_scale: float) -> float:
	if fx == null or not is_instance_valid(fx) or not ("sprite_frames" in fx):
		return 0.0
	var frames: SpriteFrames = fx.get("sprite_frames")
	if not frames:
		return 0.0
	## Varyantlı efektler (ör. fx_claw_slash.gd "v0/v1/v2") kendi _ready'sinde başka bir animasyon oynatır - o an oynayan
	## animasyon varsa onun süresi, yoksa klasik "play".
	var anim_name: StringName = &"play"
	var current: Variant = fx.get("animation")
	if current != null and frames.has_animation(StringName(str(current))) and fx.has_method("is_playing") and fx.call("is_playing"):
		anim_name = StringName(str(current))
	if not frames.has_animation(anim_name):
		return 0.0
	var fps: float = frames.get_animation_speed(anim_name)
	if fps <= 0.0:
		return 0.0
	var count: int = frames.get_frame_count(anim_name)
	return (count / fps) / max(0.01, speed_scale)


## Saldırı hızı arttıkça (fire_rate küçüldükçe) isabet/savuruş efektleri de
## orantılı hızlanır - kullanıcı isteği: "saldırı hızı artınca efekt daha
## hızlı olsun ki daha hızlı dönüp saldırabilsin." MAX ile aşırı yüksek
## saldırı hızında efektin saçma derecede titrek/hızlı oynamasının önüne
## geçilir. _base_fire_rate/fire_rate <= 1.0 olan (yani hızlanmamış) tüm
## silahlerde sonuç hep 1.0 - no-op.
const MELEE_EFFECT_SPEED_SCALE_MAX := 3.0

func _melee_effect_speed_scale() -> float:
	if _base_fire_rate <= 0.0 or fire_rate <= 0.0:
		return 1.0
	return clamp(_base_fire_rate / fire_rate, 1.0, MELEE_EFFECT_SPEED_SCALE_MAX)


## Silaha özel ateşleme sesi: sahnesinde "AttackSound" adında bir
## AudioStreamPlayer2D varsa onu çalar (ör. ateş asası) - yoksa sessizce
## geçer, oyuncunun genel ateş sesi player.gd'de zaten çalıyor.
func _play_attack_sound() -> void:
	var s: Node = get_node_or_null("AttackSound")
	if s == null:
		return
	if s.has_method("play_swing"):
		## Kombo çalıcı (melee_swing_sound.gd): rastgele sıra + perde,
		## %60 kuralıyla üst üste binmeden.
		s.play_swing()
	elif s is AudioStreamPlayer2D:
		## Geniş rastgele perde aralığı: art arda vuruşlar tekdüze/spam gibi
		## hissettirmesin.
		s.pitch_scale = randf_range(0.88, 1.12)
		s.play()
		# Broadcast weapon fire sound to remote players
		if NetworkManager.is_multiplayer_active and s.stream and s.stream.resource_path != "":
			var player_id: int = multiplayer.get_unique_id()
			NetworkManager.broadcast_player_vfx.rpc(player_id, "weapon_sound", global_position, {
				"sound_path": s.stream.resource_path,
				"pitch": s.pitch_scale,
				## DÜZELTME: gerçek volume_db taşınmıyordu, katılımcılar bu
				## silahın sesini her zaman 0dB (tam ses) duyuyordu (bkz.
				## network_manager.gd "weapon_sound" case'indeki yorum).
				"volume_db": s.volume_db,
			})


## Talon's rage: shoves whatever was just hit away from the shooter. 0 force
## (every character but Talon, and Talon outside his rage window) is a no-op.
func _apply_knockback(target: Node2D) -> void:
	## Tek isabette absürt bir mesafeye ışınlanmasın diye tavan (çok sayıda
	## Kitelama Seti kopyasıyla knockback_force teorik olarak çok büyüyebilir).
	var force: float = min(_player_stat("knockback_force"), 400.0)
	if force <= 0.0 or not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	## force = İTİŞ MESAFESİ (px) - bkz. enemy.gd apply_knockback_distance (yumuşak, sönümlenen, istemciden host'a iletilir).
	if target.has_method("apply_knockback_distance"):
		target.apply_knockback_distance(dir, force)
	elif target.has_method("apply_knockback_force"):
		target.apply_knockback_force(dir, force)
	else:
		target.global_position += dir * force


## muzzle_flash_scene ayarlıysa (ör. Tabanca) merminin başladığı tam noktadan
## saldırı yönüne dönük bir kerelik efekt oynatır; ayarlı değilse (Ateş/
## Yıldırım Asası gibi) hiçbir şey yapmaz.
func _spawn_muzzle_flash(direction: Vector2) -> void:
	if not muzzle_flash_scene:
		return
	var fx = muzzle_flash_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + direction * muzzle_flash_offset
	fx.rotation = direction.angle() + muzzle_flash_rotation_offset
	# Broadcast to remote players
	## Relay flood korumasına takılmamayı garantilemek için sınırlanıyor
	## (bkz. NetworkManager.should_throttle) - hızlı ateşli silahlar saniyede
	## onlarca namlu alevi göndermeye çalışabilir.
	if NetworkManager.is_multiplayer_active:
		var player_id: int = multiplayer.get_unique_id()
		if not NetworkManager.should_throttle("muzzle_%d" % player_id, 0.05):
			NetworkManager.broadcast_player_vfx.rpc(player_id, "muzzle_flash", fx.global_position, {
				"scene_path": muzzle_flash_scene.resource_path,
				"rotation": fx.rotation
			})


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "boomerang ve fişek
## kullanan biri saldırı yaptığında ... diğer oyunculara yeni bir boomerang
## ve yeni bir fişek projectile olarak fırlatılıyormuş gibi görünüyor") -
## kök neden: icon_sprite.visible = false/true (bkz. _fire_at içindeki
## boomerang/fişek dalları, _on_boomerang_returned, _on_ranged_projectile_
## landed, ve tabanca'nın _start_reload/_finish_reload'ı) SADECE yerel,
## hiç ağa yayınlanmıyordu. Uzak izleyicide kafadaki ikon UÇUŞ BOYUNCA
## görünür kalmaya devam edip GERÇEKTEN uçan mermiyle ÜST ÜSTE bindiği için
## "iki ayrı boomerang/fişek" varmış gibi görünüyordu. recoil/fire_anim ile
## AYNI desen - slot_index + görünürlük yayınlanır, remote_player.gd
## kendi kopyasındaki aynı slottaki ikonu gizler/gösterir.
func _broadcast_weapon_icon_visibility(is_visible: bool) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var owner_player: Node = get_parent()
	if not owner_player or not owner_player.has_method("_get_weapon_index"):
		return
	var slot_idx: int = owner_player._get_weapon_index(self)
	if slot_idx < 0:
		return
	NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "weapon_icon_visibility", global_position, {
		"slot_index": slot_idx,
		"visible": is_visible,
	})


## Small kick opposite the fire direction, purely cosmetic on the icon
## sprite (doesn't affect hover_offset / firing origin).
func _do_recoil(direction: Vector2) -> void:
	if not icon_sprite:
		return
	var kick: Vector2 = -direction * recoil_distance
	var tw := create_tween()
	tw.tween_property(icon_sprite, "position", kick, 0.04)
	tw.tween_property(icon_sprite, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	## Ezilip esneyen "punch" (bkz. weapon_juice.gd - uzak kopya remote_player.gd de aynısını oynatır).
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = WeaponJuice.fire_punch(self, icon_sprite, _icon_base_scale)
	# Broadcast weapon recoil to remote players
	if NetworkManager.is_multiplayer_active:
		# Determine slot index from parent's weapon list
		var owner_player: Node = get_parent()
		if owner_player and owner_player.has_method("_get_weapon_index"):
			var slot_idx: int = owner_player._get_weapon_index(self)
			## Relay flood korumasına takılmamak için sınırlanıyor (bkz.
			## NetworkManager.should_throttle).
			if slot_idx >= 0 and not NetworkManager.should_throttle("recoil_%d_%d" % [multiplayer.get_unique_id(), slot_idx], 0.05):
				## DÜZELTME (mimari sadeleştirme): recoil_distance bu silahın
				## KENDİ sabit @export değeri - "hangi silah tepiyor" bilgisi
				## (slot_index) zaten yeterli, alıcı taraf (remote_player.gd)
				## o slottaki GERÇEK silahın recoil_distance'ını zaten kendi
				## update_weapon_visuals()'ında yakalayıp saklıyor (bkz.
				## _weapon_recoil_distance). Görsel/sabit bir değeri ayrıca
				## ağdan göndermek hem gereksiz trafik hem de iki tarafın
				## sayısı bir gün birbirinden sapabilir diye gereksiz risk.
				NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "weapon_recoil", global_position, {
					"slot_index": slot_idx,
				})


## Multiplayer: uzak oyuncunun silah ikonuna ateş animasyonu oynatması için
## broadcast. slot_index + fire_direction + tam melee/menzilli parametrelerini
## gönderir, remote_player.gd'de _animate_weapon_fire karşılar.
func _broadcast_weapon_fire_anim(fire_direction: Vector2, melee_target_pos: Vector2 = Vector2.ZERO, hold_dur: float = 0.0) -> void:
	var owner_player: Node = get_parent()
	if not owner_player or not owner_player.has_method("_get_weapon_index"):
		return
	var slot_idx: int = owner_player._get_weapon_index(self)
	if slot_idx < 0:
		return
	## Relay flood korumasına takılmamak için sınırlanıyor (bkz.
	## NetworkManager.should_throttle) - yüksek ateş hızlı silahlarda animasyon
	## zaten görsel olarak ~20/sn üzerinde fark edilmiyor.
	if NetworkManager.should_throttle("wfire_%d_%d" % [multiplayer.get_unique_id(), slot_idx], 0.05):
		return
	## DÜZELTME (mimari sadeleştirme - kullanıcı isteği: "singleplayerda zaten
	## kayıtlı animasyon/efekt bilgilerinin multiplayerdan gereksiz yere
	## alınması yerine kendi bilgisiyle gerçekleşmesi"): is_melee, reps,
	## forward_deg, rest_rotation_deg, slash_fx_offset, slash_fx_above_offset
	## ve recoil_distance HEPSİ bu silahın KENDİ sabit @export/tanım
	## değerleri - hangi oyuncunun ateş ettiği zaten runtime'da değişmiyor.
	## remote_player.gd zaten update_weapon_visuals() içinde GERÇEK weapon.gd
	## sahnesinden bunların birebir aynısını (silinmeden hemen önce) yakalayıp
	## _weapon_melee/_weapon_forward_angle_deg/_weapon_rest_rotation_deg/vb.
	## dizilerinde saklıyor (nişan açısı zaten aynı desenle ağdan çıkarılmıştı,
	## bkz. _update_local_weapon_aim notu). Burada SADECE gerçekten o ana
	## özel olan gerçek olaylar kalıyor: hangi slot ateş etti, hangi yöne,
	## (yakın dövüşse) nereye vurdu, ne kadar tuttu.
	NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "weapon_fire", global_position, {
		"slot_index": slot_idx,
		"direction_x": fire_direction.x,
		"direction_y": fire_direction.y,
		"target_pos_x": melee_target_pos.x,
		"target_pos_y": melee_target_pos.y,
		"hold_duration": hold_dur,
	})


## Aynı anda tek bir savuruş animasyonu koşmalı - hızlı ateş hızında yeni bir
## saldırı öncekini yarıda keserse eski tween'in "hayalet" bir hedefe doğru
## devam etmesini engeller.
var _melee_swing_tween: Tween = null

## Yakın dövüş ikonu (kafanın üstünde süzülen bıçak) saldırmadığı sürece SABİT
## durur: konumu Vector2.ZERO (hover noktasında), rotasyonu 0° (dik, yukarı
## bakan - bkz. _process()'te artık melee ikonlar için _update_aim hiç
## çağrılmıyor). Saldırınca ikon, hedefin biraz YUKARISINA (yaratığın üzerine)
## gidip orada saldırı yönüne dik eksende sağa/sola sıçrayarak zigzag (Z)
## çizer - melee_hit_segments kadar (ana silah: 3) sıçrama - her segment
## kendi yönüne döner, gerçek bir kesme vuruşu gibi görünsün diye. En sonda
## yumuşakça geri hover konumuna ve 0° rotasyona döner.
## hold_duration: kullanıcı bildirimi "kesme efekti bitmeden kılıcın geri
## dönmesi" sorunu - ikon artık son zigzag noktasına ULAŞTIKTAN sonra, geri
## dönüş tween'ine başlamadan ÖNCE bu kadar (isabet/savuruş efektinin gerçek
## oynama süresi, bkz. _fx_playback_duration) BEKLİYOR. 0.0 (efekt yoksa/
## efekt AnimatedSprite2D değilse) = eski davranış, hiç bekleme yok.
func _do_melee_swing(direction: Vector2, at_position: Vector2, hold_duration: float = 0.0) -> void:
	if not icon_sprite:
		return
	var reps: int = max(1, melee_hit_segments)
	## _spawn_slash_fx() efekti "at_position - direction * melee_slash_fx_offset
	## + Vector2(0, -melee_slash_fx_above_offset)" noktasına koyuyor. direction
	## zaten (target.global_position - global_position).normalized() olduğu
	## için (target.global_position - global_position) = direction *
	## hedefe_olan_mesafe eşitliğinden yararlanılıp bu nokta doğrudan bu
	## silahın kendi (Weapon) uzayındaki bir yerel konuma çevrilebiliyor.
	## AYNI iki sabit (melee_slash_fx_offset, melee_slash_fx_above_offset)
	## kullanıldığı için ikon efektle TAM AYNI dünya noktasına gelir - biri
	## değişse bile ikisi birbirinden asla kopmaz.
	var distance_to_target: float = global_position.distance_to(at_position)
	var strike_center: Vector2 = direction * max(0.0, distance_to_target - melee_slash_fx_offset) + Vector2(0, -melee_slash_fx_above_offset)
	var forward: float = deg_to_rad(sprite_forward_angle_deg)

	## Zigzag noktaları: saldırı yönüne dik eksende (perp) sırayla sağa/sola
	## kayan noktalar - yaratığın üzerinde bir "Z" çizerek kesiyormuş hissi
	## verir (düz tek ileri-geri yerine). Yukarı ofsetle orantılı küçültüldü.
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	var points: Array[Vector2] = []
	for i in range(reps):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		points.append(strike_center + perp * MELEE_ZIGZAG_SPREAD * side)

	if _melee_swing_tween and _melee_swing_tween.is_valid():
		_melee_swing_tween.kill()

	var tw := create_tween()
	_melee_swing_tween = tw
	var prev_pos: Vector2 = Vector2.ZERO
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var seg_dir: Vector2 = p - prev_pos
		var seg_rotation: float = (seg_dir.angle() - forward) if seg_dir.length() > 1.0 else (direction.angle() - forward)
		var dur: float = 0.12 if i == 0 else 0.09
		tw.tween_property(icon_sprite, "position", p, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(icon_sprite, "rotation", seg_rotation, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		prev_pos = p

	## Efekt(ler) tamamen bitene kadar burada bekle - bkz. yukarıdaki
	## hold_duration yorumu. 0.0 ise (efekt yok/AnimatedSprite2D değil)
	## tween_interval hiç eklenmiyor, davranış eskisiyle birebir aynı.
	if hold_duration > 0.0:
		tw.tween_interval(hold_duration)

	## Kafanın üstündeki dinlenme konumuna dönüş: mesafe büyüdüğü için süre de
	## uzatıldı (0.18 -> 0.26sn), TRANS_SINE + EASE_IN_OUT ile yavaş başlayıp
	## yavaş biten yumuşak bir "ease-ease" kavis çizer, ani durmaz. Rotasyon
	## sabit 0.0'a DEĞİL, bu silahın kendi dinlenme açısına (bkz.
	## melee_icon_rest_rotation_deg - Uzunkılıç/Topuz'da -90°) döner, yoksa
	## her saldırıdan sonra ikon "dik" pozundan çıkıp tekrar yan yatardı.
	tw.tween_property(icon_sprite, "position", Vector2.ZERO, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(icon_sprite, "rotation", deg_to_rad(melee_icon_rest_rotation_deg), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
