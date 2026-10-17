extends RefCounted

## Cadı (roster id 15) - player.gd (yetkili/gerçek oyuncu), remote_player.gd (diğer istemcilerdeki kozmetik kopya) ve
## network_manager.gd ("cadi_fx" dalı) tarafından PAYLAŞILAN sabitler, formüller ve görsel yardımcılar (hadime_math.gd ile
## aynı düzen - CLAUDE.md madde 3: iki tarafa ayrı ayrı yazılan formül bir gün sapar, hepsi BURADAKİ static fonksiyonları çağırır).
##
## Tasarım (kullanıcı isteği 2026-10-13, masaüstü "cadı özellikleri.txt" + soru-cevap; efektler tools/gen_cadi_fx.py):
##  Pasif Şans Tılsımı        : her eksik %5 can başına +1 şans.
##  Q Zehirli Duman (id 51)   : AÇ/KAPA. Arkasında uçan zehir şişesi dumanı ağzından yere döker; bulut 6 sn kalır, dumana değen
##                              yaratık saniyede saldırı gücünün %120'si hasar alır (kaç bulut üst üste olursa olsun saniyede BİR).
##                              Her saniye azami kalkanın %0,5'i + 5 kalkan. Kapatınca 8 sn bekleme (metinde yoktu - Hadime
##                              Q'suyla aynı seçildi).
##  E Uçan Süpürge (id 52)    : 8 sn süpürgeye biner (+%20 hız, saniyede saldırı gücünün %10'u can VE kalkan). Değdiği takım
##                              arkadaşları da biner: cadıya yapışık giderler, AYNI bonusları alırlar (evrimler dahil), silah ve
##                              yetenek kullanabilirler; ilk 1 sn inemezler, sonra hareket ederek inerler (kullanıcı cevabı).
##                              20 sn bekleme (metinde yoktu).
##  R İksir Çantası (id 53)   : 5 yük (yük başına 8 sn), atışlar arası 0,5 sn. Her atış RASTGELE bir iksir - sıradaki iksir
##                              ikonda görünür (kullanıcı cevabı). Hedef otomatik: saldırı iksirleri menzildeki en kalabalık
##                              yaratık kümesine, şifa canı en az müttefike. Alanlar 4 sn:
##                                1 Delilik: değen yaratık 4 sn delirir, en yakın yaratığa saldırır (boss + elit hariç)
##                                2 Don: 2 sn dondurur + %100 hasar          3 Patlama: alan açmaz, %200 hasar
##                                4 Şifa: üstündeki müttefikler saniyede %20  5 Korku: 2 sn korkutur + %100 hasar
##                              Kalkan bedeli: ulti tarifesinin 1/5'i ATIŞ BAŞINA (5 atış = bir ulti; metinde yoktu).
## Evrim kartları scripts/skill_evolutions.gd DEFS[15]; etkileri player.gd'de has_evo("cadi_*") - sayılar aşağıdaki EVO_* sabitleri.

const CHAR_ID := 15
const Q_SKILL_ID := 51
const E_SKILL_ID := 52
const R_SKILL_ID := 53

## 1 sanat pikseli = KARAKTERİN pikseli (Cadı'nın tüm efektleri bu yoğunlukta çizildi - tools/gen_cadi_fx.py başı).
## Karakterin ÇOCUĞU olan düğümlerde CHAR_TEXEL (yerel birim; kök 0,5 ölçekli), sahneye eklenenlerde WORLD_TEXEL (dünya birimi).
const CHAR_TEXEL := 2.2368375 * EntityScale.SIZE
const WORLD_TEXEL := CHAR_TEXEL * 0.5
## Karakter kökünden ayak altı (yerel birim) - hadime_math.gd HOLE_FEET_LOCAL ile aynı üretici kanvası.
const FEET_LOCAL := Vector2(0, 30)

## ---------- Pasif: Şans Tılsımı ----------
const PASSIVE_HP_STEP := 0.05
const PASSIVE_LUCK_PER_STEP := 1.0

## ---------- Q: Zehirli Duman ----------
## Saniyelik bedel (2026-10-13, kullanıcı): azami kalkanın %0,5'i + 5 (eskiden temel yetenek bedelinin yarısı = %2 + 10).
const Q_COST_PERCENT_OF_MAX := 0.005
const Q_COST_FLAT := 5.0
const Q_COOLDOWN := 8.0
const Q_DAMAGE_RATIO := 1.2
## Aynı yaratık dumandan en fazla bu aralıkla hasar alır ("her saniye"); yaratıklar bu sıklıkla taranır.
const Q_HIT_INTERVAL := 1.0
const Q_SCAN_INTERVAL := 0.25
const SMOKE_LIFE := 6.0 ## 2026-10-13 kullanıcı: 3 -> 6 sn
## Yürürken bu aralıkla yeni bulut; yerinde dururken (son buluttan SMOKE_MIN_STEP'ten az uzaklaşmışken) SMOKE_IDLE_INTERVAL.
const SMOKE_DROP_INTERVAL := 0.4
const SMOKE_IDLE_INTERVAL := 1.2
const SMOKE_MIN_STEP := 14.0
## Bulutun zemindeki izi (dünya birimi; sayfadaki kütlenin tabanı) - hasar/yavaşlatma bu elipsin içinde.
const SMOKE_RX := 32.0
const SMOKE_RY := 17.0
## Cadı yukarı/aşağı yürürken bırakılan DİKEY bulut (kullanıcı 2026-10-13: "yukarı ve aşağı pozisyonda kötü oluyor, ona
## göre bir uyumu yok"): yatay bulut 64 geniş x 34 derin - yan yana kesintisiz şerit olur ama alt alta (33 birim arayla)
## dizilince geniş kaburgalar gibi durur, izler de ancak birbirine değer. Dikey bulut dar + derin: sütun kesintisiz.
## Alan neredeyse aynı (pi x 24 x 22 = 1659, yatay 1709). Ayrı klipler (intro_v/loop_v/outro_v) ve orijin (52, 46).
const SMOKE_V_RX := 24.0
const SMOKE_V_RY := 22.0
const SMOKE_V_CENTER_ART := Vector2(0, 8)
## Dikey yürüyüşte bulutlar daha sık bırakılır (25 birimde bir; yatayda 33): gerçek çizicide 0,4 sn'de cadıyla sütun
## arasında boşluk kalıyor, bulutlar tek tek seçiliyordu. Hasar bulut sayısından bağımsız (saniyede BİR), bedel aynı.
const SMOKE_V_DROP_INTERVAL := 0.3
## Dikey bulutların her biri bu kadar sağa/sola kayık çizilir (sadece görsel; sütun ip gibi dizilmesin).
const SMOKE_V_JITTER_ART := 4.0
## 2026-10-13 kullanıcı: duman yaratıkların (ve oyuncuların) ÜSTÜNDE, her bulut ayrı %50 saydam (eskiden zeminde, %80).
## Oyuncular dumanın ÜSTÜNDE kalır (kendi karakterin ve can barın silikleşmesin - gerçek çizicide denendi, kötü durdu).
## Katman: yaratık z 0, oyuncu z 1 (CLAUDE.md madde 25/45) -> bulut z 1 + sahnenin en başına taşınır (cadi_smoke.gd).
const SMOKE_ALPHA := 0.5
const SMOKE_Z := 1
## Sayfa karesinde bulut ORİJİNİ (zemindeki izin merkezi) karenin ortasına göre (sanat pikseli): 104x76, orijin (52, 53).
const SMOKE_CENTER_ART := Vector2(0, 15)
const SMOKE_OUTRO_TIME := 0.7
## Şişe HER yönde cadının TAM ARKASINDA süzülür (kullanıcı 2026-10-13: "sağa sola dönükken duman arkasından çıkmıyor,
## arkaya dönükken şişe arkasında değil yanlarında duruyor"). Gövde merkezi cadının AYAĞINA göre (sanat pikseli):
##   sağa bakarken solunda (sola bakarken aynası), 45 derece eğik; duman topuğunun hemen arkasına iner
##   yukarı bakarken (sırtı kameraya) ekranda ALTINDA, karakterin ÖNÜNDE çizilir; ağzı dümdüz aşağı
##   aşağı bakarken (yüzü kameraya) başının üstünden görünür, karakterin ARKASINDA çizilir; ağzı dümdüz aşağı
## Gövde her duruşta inişin 26 px üstünde; ağız/iniş ölçüleri tools/gen_cadi_fx.py ÖLÇÜ çıktısı (POT_POSES, ST_POSES).
const POTION_BODY_SIDE_ART := Vector2(-15, -27)
const POTION_BODY_UP_ART := Vector2(0, -13)
const POTION_BODY_DOWN_ART := Vector2(0, -36)
const POTION_DROP_SIDE_ART := Vector2(-12, 26)
const POTION_DROP_VERT_ART := Vector2(0, 26)
## Aşağı bakarken akış cadının gövdesinin ardında (görünmez): bulut biraz daha geride doğar, yoksa başının çevresinde açılıyor.
const POTION_DROP_DOWN_ART := Vector2(0, 14)
const POTION_MOUTH_SIDE_ART := Vector2(-8.06, 8.06)
const POTION_MOUTH_VERT_ART := Vector2(0, 11.4)
## Yön değişince şişe yeni yerine bu hızla süzülür (1/sn, üstel).
const POTION_FOLLOW_RATE := 12.0
const POTION_BOB_ART := 1.5
const POTION_BOB_SPEED := 2.6
## Süpürgedeyken şişe gövdesi, cadı merkezinden samanın ucunun bu kadar ardında (sanat pikseli; sap 31 + yarım şişe).
const POTION_BROOM_TAIL_ART := 37.0
const POTION_NODE := "CadiPotion"
## Evrimler
const EVO_SMOKE_SLOW := 0.3
const EVO_SMOKE_SLOW_TIME := 0.6
const EVO_SMOKE_LIFE_BONUS := 3.0 ## 2026-10-13 kullanıcı: 1,5 -> 3 sn
const EVO_Q_COST_MULT := 0.5
const EVO_SMOKE_SIZE_MULT := 1.3
const EVO_SMOKE_LIFESTEAL := 0.03

## ---------- E: Uçan Süpürge ----------
const E_DURATION := 8.0
const E_COOLDOWN := 20.0
const E_SPEED_MULT := 1.2
const E_REGEN_RATIO := 0.1
const E_REGEN_TICK := 1.0
const EVO_E_DODGE := 0.25
const EVO_E_SPEED_MULT := 1.5
## Silah isabetlerinin ek itişi (px - weapon.gd knockback_force ile aynı birim).
const EVO_E_KNOCKBACK := 28.0
const EVO_E_CONTACT_DAMAGE := 1.0
const EVO_E_CONTACT_ROOT := 2.0
const EVO_E_CONTACT_REACH := 14.0
const EVO_E_CONTACT_INTERVAL := 3.0
## Görünüm: süpürge yerden bu kadar yüksekte (karakter sanat pikseli), binenler süpürgeye göre SIT_DROP kadar aşağıda oturur
## (kullanıcı: "azıcık havada duruyorlar"). Hafif iniş-çıkış.
const RIDE_LIFT_ART := 8.0
const RIDE_SIT_DROP_ART := 2.0
const RIDE_BOB_ART := 1.5
const RIDE_BOB_SPEED := 3.9
## Süpürge sayfalarında karakter hücresinin merkezi (tools/gen_cadi_fx.py ÖLÇÜ): broom_side 176x24 karede (40, -2),
## broom_vert 48x24 karede (24, -2) -> sprite merkezine göre ofset (sanat pikseli).
const BROOM_SIDE_OFFSET_ART := Vector2(48, 14)
const BROOM_VERT_OFFSET_ART := Vector2(0, 14)
const BROOM_NODE := "CadiBroom"
const MAX_PASSENGERS := 7
## Yolcular: yan görünümde sap boyunca SEAT kadar arkada, aşağı/yukarı bakarken derinlikte SEAT_VERT kadar (sanat pikseli).
const SEAT_ART := 14.0
const SEAT_VERT_ART := 9.0
## Binme: yolcunun KENDİ istemcisi süpürgedeki cadıya bu kadar (dünya birimi) yaklaşınca biner.
const MOUNT_RADIUS := 27.5
const DISMOUNT_LOCK := 1.0
## İnmek için hareket girdisi bu kadar saniye KESİNTİSİZ basılı tutulmalı (istemeden dokunma düşürmesin, kullanıcı isteği 2026-10-14).
const DISMOUNT_HOLD := 0.5
## İnişte girdi yoksa (süre doldu / cadı indi) cadının gittiği yöne bu kadar saniye otomatik koşulur; yeni hareket girdisi devralır.
const DISMOUNT_AUTORUN := 0.8
const REMOUNT_LOCK := 1.5
const RIDE_ANIM_PREFIX := "ride_"

## ---------- R: İksir Çantası ----------
const R_MAX_CHARGES := 5
const R_RECHARGE := 8.0
const R_THROW_LOCK := 0.5
const R_COST_SHARE := 0.2
const R_RANGE := 260.0
const R_FALLBACK_DISTANCE := 110.0
const R_FLIGHT_TIME := 0.45
const R_ARC_HEIGHT := 40.0
const POTION_MAD := 0
const POTION_ICE := 1
const POTION_BOOM := 2
const POTION_HEAL := 3
const POTION_FEAR := 4
const POTION_COUNT := 5
const POTION_NAMES := ["Delilik İksiri", "Don İksiri", "Patlama İksiri", "Şifa İksiri", "Korku İksiri"]
const POTION_DESCS := [
	"Değen yaratıklar 4 saniye delirir ve en yakınındaki yaratığa saldırır (boss ve elitler etkilenmez).",
	"Değen yaratıkları 2 saniye dondurur ve saldırı gücünün %100'ü kadar hasar verir.",
	"Patlayarak yok olur ve çevresine saldırı gücünün %200'ü kadar hasar verir.",
	"Üstünde duran müttefikler her saniye saldırı gücünün %20'si kadar can yeniler.",
	"Değen yaratıkları 2 saniye korkutur ve saldırı gücünün %100'ü kadar hasar verir.",
]
const ZONE_DURATION := 6.0 ## 4 -> 6 sn (kullanıcı isteği 2026-10-14: "iksirler 2 saniye daha uzun sürsün")
## Alanın zemindeki izi (dünya birimi): sayfadaki 58x30 px elips.
const ZONE_RX := 58.0 * WORLD_TEXEL
const ZONE_RY := 30.0 * WORLD_TEXEL
const ZONE_SCAN_INTERVAL := 0.2
## Sayfa karesinde alan merkezi karenin ortasına göre (sanat pikseli): 160x108, merkez (80, 70).
const ZONE_CENTER_ART := Vector2(0, 16)
const ZONE_SHEETS := {POTION_MAD: "zone_mad", POTION_ICE: "zone_ice", POTION_HEAL: "zone_heal", POTION_FEAR: "zone_fear"}
const ZONE_ALPHA := [0.9, 0.9, 1.0, 1.0, 0.88]
const ZONE_INTRO_TIME := 0.5
const ZONE_OUTRO_TIME := 0.6
const MAD_DURATION := 4.0
## Aynı yaratığa delilik en fazla bu aralıkla yenilenir (alanda kaldıkça süre tazelenir).
const MAD_REAPPLY := 1.0
const ICE_FREEZE_TIME := 2.0
const ICE_DAMAGE_RATIO := 1.0
const BOOM_DAMAGE_RATIO := 2.0
const BOOM_RADIUS := 60.0
## Sayfa karesinde patlama merkezi karenin ortasına göre (sanat pikseli): 176x164, merkez (88, 88).
const BOOM_CENTER_ART := Vector2(0, 6)
const HEAL_RATIO := 0.2
const HEAL_TICK := 1.0
const FEAR_TIME := 2.0
const FEAR_DAMAGE_RATIO := 1.0
const EVO_ZONE_DURATION_BONUS := 1.5
## "İksirler %25 daha hızlı dolar": dolum HIZI x1,25 -> süre /1,25 (8 sn -> 6,4 sn).
const EVO_R_RECHARGE_DIV := 1.25
const EVO_ZONE_SIZE_MULT := 1.4

const FX_DIR := "res://assets/fx/cadi/"
const R_ICONS := [
	"res://assets/skills/cadi_iksir_1_icon.png", "res://assets/skills/cadi_iksir_2_icon.png", "res://assets/skills/cadi_iksir_3_icon.png",
	"res://assets/skills/cadi_iksir_4_icon.png", "res://assets/skills/cadi_iksir_5_icon.png",
]
const SmokeScript := "res://scripts/cadi_smoke.gd"
const ZoneScript := "res://scripts/cadi_zone.gd"
const BottleScript := "res://scripts/cadi_bottle.gd"
const PotionVisualScript := "res://scripts/cadi_potion_visual.gd"
const BroomVisualScript := "res://scripts/cadi_broom_visual.gd"

## Kaynaklar preload DEĞİL, ilk kullanımda yüklenip önbellekte tutulur (dünya düğümlerinin betikleri de bu dosyayı preload
## ediyor - döngüsel preload olmasın; hadime_math.gd scene() ile aynı çözüm).
static var _cache: Dictionary = {}


static func res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func frames(sheet: String) -> SpriteFrames:
	return res(FX_DIR + sheet + "_frames.tres") as SpriteFrames


static func is_cadi(char_id: int) -> bool:
	return char_id == CHAR_ID


## ---------- ortak küçük yardımcılar ----------
static func facing_from_anim(anim_name: String, fallback: String = "down") -> String:
	var i: int = anim_name.rfind("_")
	if i < 0:
		return fallback
	var f: String = anim_name.substr(i + 1)
	return f if f in ["down", "left", "right", "up"] else fallback


## host: Player ya da RemotePlayer. İkisinde de "facing" yoksa oynayan klibin son ekinden.
static func facing_of(host: Node) -> String:
	if "facing" in host:
		return str(host.get("facing"))
	var a: Variant = host.get("anim")
	if a != null and is_instance_valid(a):
		return facing_from_anim(str((a as AnimatedSprite2D).animation))
	return "down"


static func in_ellipse(p: Vector2, center: Vector2, rx: float, ry: float) -> bool:
	if rx <= 0.0 or ry <= 0.0:
		return false
	var d: Vector2 = p - center
	return (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0


## Tek seferlik sayfa efekti (kırılma, patlama, biniş dumanı): oynar ve silinir. center_art: görselin merkezi sprite
## merkezine göre nerede (sanat pikseli) - düğüm orijini o noktaya oturur.
static func spawn_oneshot(root: Node, sheet: String, anim_name: StringName, world_pos: Vector2, scale_mult: float = 1.0,
		center_art: Vector2 = Vector2.ZERO) -> AnimatedSprite2D:
	if root == null or not is_instance_valid(root):
		return null
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.sprite_frames = frames(sheet)
	s.scale = Vector2.ONE * WORLD_TEXEL * scale_mult
	s.offset = -center_art
	root.add_child(s)
	s.global_position = world_pos
	s.animation_finished.connect(s.queue_free)
	s.play(anim_name)
	return s


## ---------- Q: şişe + duman ----------
## Şişenin yeri bakılan yöne göre (bkz. POTION_BODY_*_ART). Sanat pikseli, cadının ayağına göre.
## riders: süpürgedeki cadıda yolcu sayısı (-1 = süpürgede değil). Süpürgedeyken şişe cadının değil SÜPÜRGENİN arkasında durur:
## sap yolcu başına SEAT kadar uzar, şişe samanın ucunun ardına kayar ve süpürgeyle birlikte RIDE_LIFT kadar yükselir.
static func potion_body_art(facing: String, riders: int = -1) -> Vector2:
	var art: Vector2
	match facing:
		"right":
			art = POTION_BODY_SIDE_ART
		"left":
			art = Vector2(-POTION_BODY_SIDE_ART.x, POTION_BODY_SIDE_ART.y)
		"up":
			art = POTION_BODY_UP_ART
		_:
			art = POTION_BODY_DOWN_ART
	if riders < 0:
		return art
	var n: float = float(mini(riders, MAX_PASSENGERS))
	match facing:
		"right":
			art.x = -(POTION_BROOM_TAIL_ART + SEAT_ART * n)
		"left":
			art.x = POTION_BROOM_TAIL_ART + SEAT_ART * n
		"up":
			art.y += SEAT_VERT_ART * n
		_:
			art.y -= SEAT_VERT_ART * n
	art.y -= RIDE_LIFT_ART
	return art


## Dumanın yere indiği nokta, şişe gövdesine göre (sanat pikseli).
static func potion_drop_art(facing: String) -> Vector2:
	match facing:
		"right":
			return POTION_DROP_SIDE_ART
		"left":
			return Vector2(-POTION_DROP_SIDE_ART.x, POTION_DROP_SIDE_ART.y)
		"up":
			return POTION_DROP_VERT_ART
	return POTION_DROP_DOWN_ART


## Bu bakışta bırakılan bulut dikey mi (dar + derin) - bkz. SMOKE_V_RX.
static func smoke_is_vertical(facing: String) -> bool:
	return facing == "up" or facing == "down"


static func _feet_world() -> Vector2:
	return FEET_LOCAL * 0.5


## Dünya birimi, cadının KÖKÜNE göre (kök 0,5 ölçekli).
static func potion_body_offset(facing: String, riders: int = -1) -> Vector2:
	return _feet_world() + potion_body_art(facing, riders) * WORLD_TEXEL


## Dumanın yere indiği nokta = bulutun doğduğu yer (cadının köküne göre, dünya birimi). Süpürgedeyken şişe havada olsa da
## duman YERE iner (yükselme geri eklenir).
static func smoke_land_offset(facing: String, riders: int = -1) -> Vector2:
	var lift_back := Vector2(0.0, RIDE_LIFT_ART if riders >= 0 else 0.0)
	return _feet_world() + (potion_body_art(facing, riders) + lift_back + potion_drop_art(facing)) * WORLD_TEXEL


## Cadı süpürgedeyse yolcu sayısı, değilse -1 (şişe/duman konumu için). host: Player ya da RemotePlayer.
static func broom_riders(host: Node) -> int:
	if not is_broom_rider(host) or not host.has_method("cadi_peer") or not host.is_inside_tree():
		return -1
	return riders_of(host.get_tree(), int(host.call("cadi_peer"))).size()


static func set_potion_visual(host: Node, on: bool) -> void:
	var fx: Node = host.get_node_or_null(POTION_NODE)
	if on:
		if fx == null or fx.is_queued_for_deletion():
			fx = Node2D.new()
			fx.set_script(res(PotionVisualScript))
			fx.name = POTION_NODE
			host.add_child(fx)
	elif fx != null and not fx.is_queued_for_deletion():
		fx.name = POTION_NODE + "_old"
		fx.queue_free()


## opts: "life" (sn), "size" (çarpan), "owner_peer", "vert" (dikey bulut). authoritative kopya hasar taramasına girer (player.gd _process_cadi_smoke).
## Aynı cadının SMOKE_MIN_STEP'ten yakın bir bulutu varsa yenisi AÇILMAZ, onun ömrü baştan başlar (yerinde dururken 1,2 sn'de
## bir aynı noktaya dökülür): bulutlar %50 saydam ve karakterlerin üstünde - üst üste 5 bulut cadıyı tamamen kapatıyordu.
## Kaster de diğer istemcilerdeki kopyalar da bu işlevden geçtiği için kural her ekranda aynı; alan/süre değişmez.
static func spawn_smoke(root: Node, world_pos: Vector2, authoritative: bool, opts: Dictionary = {}) -> Node2D:
	if root == null or not is_instance_valid(root):
		return null
	var life: float = float(opts.get("life", SMOKE_LIFE))
	var size: float = float(opts.get("size", 1.0))
	var owner_peer: int = int(opts.get("owner_peer", 0))
	var vert: bool = bool(opts.get("vert", false))
	if root.is_inside_tree():
		for c in root.get_tree().get_nodes_in_group("cadi_smokes"):
			if c.get_parent() == root and c.get("owner_peer") == owner_peer and c.get("authoritative") == authoritative \
					and (c as Node2D).global_position.distance_to(world_pos) < SMOKE_MIN_STEP and bool(c.call("refresh", life, size, vert)):
				return c as Node2D
	var s := Node2D.new()
	s.set_script(res(SmokeScript))
	s.set("life", life)
	s.set("size_mult", size)
	s.set("owner_peer", owner_peer)
	s.set("vert", vert)
	s.set("authoritative", authoritative)
	root.add_child(s)
	s.global_position = world_pos
	return s


## ---------- E: süpürge ----------
## t: binişten beri geçen süre. Dönen: süpürgenin yerden yüksekliği (karakter sanat pikseli).
static func ride_lift(t: float) -> float:
	return RIDE_LIFT_ART + roundf(sin(t * RIDE_BOB_SPEED) * RIDE_BOB_ART)


## Binen karakterin sprite'ı bu kadar yükselir (süpürgeden SIT_DROP kadar aşağıda oturur).
static func rider_lift(t: float) -> float:
	return ride_lift(t) - RIDE_SIT_DROP_ART


## index: 0 = cadı, 1.. = yolcular (binme sırası). Cadının köküne göre DÜNYA ofseti.
static func seat_offset(index: int, facing: String) -> Vector2:
	if index <= 0:
		return Vector2.ZERO
	match facing:
		"left":
			return Vector2(SEAT_ART * index, 0.0) * WORLD_TEXEL
		"right":
			return Vector2(-SEAT_ART * index, 0.0) * WORLD_TEXEL
		"up":
			return Vector2(0.0, SEAT_VERT_ART * index) * WORLD_TEXEL
	return Vector2(0.0, -SEAT_VERT_ART * index) * WORLD_TEXEL


## Sahnedeki oyuncu düğümü (yerel Player ya da RemotePlayer) - peer id'den.
static func player_node(tree: SceneTree, peer: int) -> Node2D:
	if tree == null or peer == 0:
		return null
	var local: Node = tree.get_first_node_in_group("player")
	if local != null and local_peer(tree) == peer:
		return local as Node2D
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and int(rp.get("peer_id")) == peer:
			return rp as Node2D
	return null


static func local_peer(tree: SceneTree) -> int:
	var mp: MultiplayerAPI = tree.get_multiplayer()
	return mp.get_unique_id() if mp != null and mp.has_multiplayer_peer() else 1


## Bu düğüm (Player / RemotePlayer) şu an KENDİ süpürgesini süren bir cadı mı.
static func is_broom_rider(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.has_method("is_cadi_broom_active") and bool(node.call("is_cadi_broom_active"))


## Yolcu cadıya yapışık gidebilir mi: süpürge açık VE cadı iç mekanda (Demirci/ev) değil. İç mekan dünyanın başka köşesindedir
## (INTERIOR_OFFSET); cadı içeri girince yolcu da peşinden ışınlanırdı (2026-10-14 kullanıcı bildirimi).
static func can_ride(host: Node) -> bool:
	return is_broom_rider(host) and host.get("is_indoors") != true


## Cadı bir karede bu kadardan fazla uzaklaştıysa (ışınlanma/iç mekana giriş, ağ gecikmesi değil) yolcu peşinden gitmez, iner.
const RIDE_BREAK_DIST := 300.0


## Cadının süpürgesindeki yolcuların peer id'leri, küçükten büyüğe (her istemcide AYNI sıra -> aynı koltuklar).
static func riders_of(tree: SceneTree, witch_peer: int) -> Array:
	var out: Array = []
	if tree == null or witch_peer == 0:
		return out
	var local: Node = tree.get_first_node_in_group("player")
	if local != null and int(local.get("cadi_ride_host_peer")) == witch_peer:
		out.append(local_peer(tree))
	for rp in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and int(rp.get("cadi_ride_host_peer")) == witch_peer and not bool(rp.get("is_dead")):
			out.append(int(rp.get("peer_id")))
	out.sort()
	if out.size() > MAX_PASSENGERS:
		out.resize(MAX_PASSENGERS)
	return out


## Yolcunun koltuk numarası (1..); listede yoksa (henüz durum kanalı gelmedi) sona eklenmiş gibi.
static func seat_index(tree: SceneTree, witch_peer: int, rider_peer: int) -> int:
	var riders: Array = riders_of(tree, witch_peer)
	var i: int = riders.find(rider_peer)
	return i + 1 if i >= 0 else riders.size() + 1


static func set_broom_visual(host: Node, on: bool) -> void:
	var a: Variant = host.get("anim")
	if a == null or not is_instance_valid(a):
		return
	var parent: Node = a as Node
	var fx: Node = parent.get_node_or_null(BROOM_NODE)
	if on:
		if fx == null or fx.is_queued_for_deletion():
			fx = Node2D.new()
			fx.set_script(res(BroomVisualScript))
			fx.name = BROOM_NODE
			fx.set("host", host)
			parent.add_child(fx)
	elif fx != null and not fx.is_queued_for_deletion():
		fx.name = BROOM_NODE + "_old"
		fx.queue_free()


## Biniş / iniş dumanı (mor) - gövde ortasında.
static func spawn_poof(root: Node, world_pos: Vector2) -> void:
	spawn_oneshot(root, "poof", &"default", world_pos, 1.0, Vector2(0, 4))


## ---------- R: iksirler ----------
static func zone_radius(size_mult: float) -> Vector2:
	return Vector2(ZONE_RX, ZONE_RY) * size_mult


## Fırlatılan şişe (from -> to, yay çizerek). Yere değince kırılma efekti + on_land(potion, to) (SADECE yetkili kopyada
## dolu gelir; diğer kopyalar zone_opts ile alanın/patlamanın GÖRSELİNİ kendileri açar - ek ağ mesajı gerekmez).
## zone_opts: "duration", "size".
static func spawn_bottle(root: Node, potion: int, from: Vector2, to: Vector2, on_land: Callable, zone_opts: Dictionary = {}) -> Node2D:
	if root == null or not is_instance_valid(root):
		return null
	var b := Node2D.new()
	b.set_script(res(BottleScript))
	b.set("potion", potion)
	b.set("from", from)
	b.set("to", to)
	b.set("on_land", on_land)
	b.set("zone_opts", zone_opts)
	root.add_child(b)
	b.global_position = from
	return b


## Alan (Delilik / Don / Şifa / Korku). authoritative kopya ZONE_SCAN_INTERVAL'de bir on_scan(zone) çağırır (etkiler player.gd'de).
static func spawn_zone(root: Node, potion: int, world_pos: Vector2, authoritative: bool, on_scan: Callable, opts: Dictionary = {}) -> Node2D:
	if root == null or not is_instance_valid(root) or not ZONE_SHEETS.has(potion):
		return null
	var z := Node2D.new()
	z.set_script(res(ZoneScript))
	z.set("potion", potion)
	z.set("duration", float(opts.get("duration", ZONE_DURATION)))
	z.set("size_mult", float(opts.get("size", 1.0)))
	z.set("authoritative", authoritative)
	z.set("on_scan", on_scan)
	root.add_child(z)
	z.global_position = world_pos
	return z


static func spawn_boom(root: Node, world_pos: Vector2, size_mult: float = 1.0) -> void:
	spawn_oneshot(root, "boom", &"default", world_pos, size_mult, BOOM_CENTER_ART)


## Sıradaki iksir: rastgele, ama az önce atılanın aynısı üst üste gelmez (5'te 1 şansla aynı şişe sıkıcı olurdu).
static func roll_potion(last: int) -> int:
	var p: int = randi() % POTION_COUNT
	if p == last:
		p = (p + 1 + randi() % (POTION_COUNT - 1)) % POTION_COUNT
	return p
