extends RefCounted

## Shaman R - Elemental Golem (kullanıcı isteği 2026-09-30): "20 saniyeliğine dev bir elemental goleme dönüşür ... yakınında
## yaratık varsa o yaratıklara saldırı hızına bağlı olarak düzenli olarak alan hasarı darbe indirir her darbe saldırı gücünün
## %120'si kadar hasar verir. Bu saldırılar kritik vuruş yapabilir. (Yakın mesafe bir saldırıdır) Bu esnada Q ve E yeteneği
## değişir" - Q: "Yere sert bir darbe indirerek etraftaki yaratıkları 1 saniye sersemletir ve saldırı gücünün %250'si kadar
## hasar verir. (3sn bekleme süresi)", E: "Zıplayıp ileri doğru atlayarak düştüğü yerdeki herkesi birbirine çeker ve saldırı
## gücünün %150si kadar hasar verir. (8 sn bekleme süresi)".
##
## TEK KAYNAK (CLAUDE.md hata sınıfı): sayılar, klip adları ve form görünüm kuralları burada - player.gd (gerçek golem),
## remote_player.gd (diğer ekranlardaki kukla), ground_shadow.gd (ayak gölgesi) ve hud.gd aynı değerleri buradan okur.
## Formun ağ senkronu için YENİ bir ağ alanı yok: golem klip ADI ("golem_*", transform kanalı - bkz. char_anim.gd dosya başı)
## uzak kuklaya formu, silahların gövdeye çekilmesini, büyük gölgeyi, sıçrayışta yaratıkların içinden geçmeyi söyler.
## Klip kareleri tools/gen_shaman_golem.py'den (zamanlama sabitleri orayla AYNI olmalı).
## Metinler (Q/E'nin form hâli adı/açıklaması/ikonu) characters.gd DEFS[12]'de: "golem_skill_*" / "golem_skill2_*".

const CHAR_ID := 12
const R_SKILL_ID := 49
const DURATION := 20.0
## Kullanıcı bekleme süresi vermedi - diğer 20 sn'lik güçlü formlara göre seçildi (Hadime Karabasan 100, Assasin 90).
const COOLDOWN := 90.0

## ---------- Klip adları (tools/gen_shaman_golem.py CLIPS/ALIASES ile aynı) ----------
const ANIM_PREFIX := "golem_"
const IDLE := "golem_idle_"
const WALK := "golem_walk_"
const SLAM := "golem_slam_"
## Aynı karelerin ikinci adı: arka arkaya darbelerde ad değişsin ki uzak kukla klibi baştan oynatsın (remote_player.gd
## update_position_and_anim_from_net sadece ad değişince play() çağırır).
const SLAM_ALT := "golem_slam2_"
const JUMP := "golem_jump_"
const SLAM_FPS := 14.0
const SLAM_FRAMES := 6
const SLAM_IMPACT_FRAME := 3 ## yumrukların yere değdiği kare
const JUMP_FPS := 20.0
const JUMP_FRAME_DURATIONS: Array[float] = [1.4, 1.0, 1.6, 1.6, 1.6, 1.0, 1.6, 1.4]
const JUMP_TAKEOFF_FRAME := 1 ## ayaklar yerden kesilir (hareket başlar)
const JUMP_LAND_FRAME := 6 ## yere iniş (çekme + hasar)

## ---------- Form savunması (kullanıcı isteği 2026-09-30: "ulti formundayken %40 hasar azaltma kazansın ve yetenekleri
## kalkan tüketmesin") ----------
## Gelen her hasar (kalkan/sıvışma katmanlarından ÖNCE, ham miktar - player.gd take_damage) bu çarpanla azalır.
const DAMAGE_TAKEN_MULT := 0.6
## Yetenek evrimleri (kullanıcı isteği 2026-10-04, bkz. skill_evolutions.gd DEFS[12]; kart metniyle birebir):
const EVO_DAMAGE_TAKEN_MULT := 0.4 ## Taş Deri (shaman_r1): hasar azaltma %40 -> %60
const EVO_HEAL_MISSING_PER_KILL := 0.01 ## Taşın Dirilişi (shaman_r2): formda öldürülen her yaratık başına eksik canın %1'i
const EVO_BIG_SCALE_MULT := 1.3 ## Dev Golem (shaman_rf): boyut +%30
const EVO_BIG_AP_BONUS := 0.15 ## Dev Golem: +%15 saldırı gücü (form boyunca)
const EVO_BIG_AREA_MULT := 1.3 ## Dev Golem: darbe/sarsıntı/iniş alanları +%30


## Formdayken gelen hasar çarpanı (r1 = "Taş Deri" evrimi alındı mı).
static func damage_taken_mult(r1: bool) -> float:
	return EVO_DAMAGE_TAKEN_MULT if r1 else DAMAGE_TAKEN_MULT
## Formdaki Q/E (Sarsıcı Darbe / Golem Sıçrayışı) standart yetenek makinelerini bypass eder ve kalkan bedeli ÖDEMEZ
## (player.gd _shaman_golem_try_q/_shaman_golem_try_e - bilerek _activate_skill*'a hiç gitmezler).

## ---------- Otomatik darbe ----------
## Aralık = taban x oyuncunun saldırı aralığı çarpanı (player.gd get_attack_interval_mult - kart/eşya saldırı hızı dahil).
const AUTO_BASE_INTERVAL := 1.0
const AUTO_MIN_INTERVAL := 0.25
const AUTO_DAMAGE_RATIO := 1.2
## Dünya birimi. "Yakın mesafe": golem gövdesinin (~28 birim yarı genişlik) ~3 katı.
const AUTO_RADIUS := 90.0

## ---------- Q (form hâli): Sarsıcı Darbe ----------
const Q_DAMAGE_RATIO := 2.5
const Q_STUN_TIME := 1.0
const Q_COOLDOWN := 3.0
const Q_RADIUS := 140.0

## ---------- E (form hâli): Golem Sıçrayışı ----------
const E_DAMAGE_RATIO := 1.5
const E_COOLDOWN := 8.0
const E_DISTANCE := 170.0 ## ileri sıçrama mesafesi (dünya birimi; duvar/harita sınırında kısalır)
const E_RADIUS := 150.0 ## iniş noktasında çekme + hasar yarıçapı
const E_PULL_KEEP := 16.0 ## yaratıklar iniş noktasının bu kadar yakınına kadar çekilir (üst üste yığılmasınlar)

## ---------- Görünüm ----------
## Ayak hizası: karakter kökünün YEREL biriminde (kök 0.5 ölçekli - dünyada ~16 birim). Zemin efektleri buraya konur.
const FEET_LOCAL_Y := 32.0
## Golem kareleri insan formundan ~2.4 kat geniş: ayak gölgesi büyür (ground_shadow.gd), sıçrayışta havadayken küçülür.
const SHADOW_SCALE := Vector2(2.3, 1.6)
const JUMP_SHADOW_BY_FRAME: Array[float] = [1.05, 0.9, 0.7, 0.6, 0.66, 0.85, 1.15, 1.05]
## Can/kalkan çubuğu ve isim etiketi golemin boynuzlarının üstüne çıkar (karakter kökünün yerel birimi, 0.5 ölçekli kök).
const OVERHEAD_LIFT := -50.0


static func is_golem_anim(anim_name: String) -> bool:
	return anim_name.begins_with(ANIM_PREFIX)


static func is_jump_anim(anim_name: String) -> bool:
	return anim_name.begins_with(JUMP)


static func is_slam_anim(anim_name: String) -> bool:
	return anim_name.begins_with(SLAM) or anim_name.begins_with(SLAM_ALT)


## Tek seferlik golem aksiyon klipleri (bitene kadar yürüme/bekleme klibi ezmez).
static func is_golem_action_anim(anim_name: String) -> bool:
	return is_slam_anim(anim_name) or is_jump_anim(anim_name)


## Sıçrayış klibinin başından itibaren belirli bir kareye kadar geçen süre (sn, speed_scale 1).
static func jump_time_to_frame(frame: int) -> float:
	var t: float = 0.0
	for i in range(mini(frame, JUMP_FRAME_DURATIONS.size())):
		t += JUMP_FRAME_DURATIONS[i]
	return t / JUMP_FPS


static func jump_total_time() -> float:
	return jump_time_to_frame(JUMP_FRAME_DURATIONS.size())


static func slam_impact_time() -> float:
	return float(SLAM_IMPACT_FRAME) / SLAM_FPS


static func slam_total_time() -> float:
	return float(SLAM_FRAMES) / SLAM_FPS


## Ayak gölgesi ölçeği: golem formunda büyük, sıçrayışta havadayken küçülür. İnsan formunda 1.
static func shadow_scale_for(anim_name: String, frame: int) -> Vector2:
	if not is_golem_anim(anim_name):
		return Vector2.ONE
	var s: Vector2 = SHADOW_SCALE
	if is_jump_anim(anim_name) and frame >= 0 and frame < JUMP_SHADOW_BY_FRAME.size():
		s *= JUMP_SHADOW_BY_FRAME[frame]
	return s


## Can/kalkan çubuğu + isim etiketi (player.gd ve remote_player.gd aynı çağrıyı yapar): host'un "OverheadBar"/"NameLabel"
## düğümleri golem boyunca OVERHEAD_LIFT kadar yukarı. Durum değişmediyse hiçbir şey yapmaz (her karede çağrılabilir).
## (Yere düşme sayacı - DownedTimerLabel - kaydırılmaz: golem formu yere düşmeden ÖNCE biter.)
const OverheadBarScript := preload("res://scripts/overhead_bar.gd")


static func apply_overhead_lift(host: Node, golem: bool, size_mult: float = 1.0) -> void:
	## size_mult: "Dev Golem" evrimi (EVO_BIG_SCALE_MULT) formu büyütür - çubuk/isim de orantılı yukarı çıkar.
	var lift: float = OVERHEAD_LIFT * size_mult if golem else 0.0
	if host == null or is_equal_approx(float(host.get_meta("golem_overhead_lift", 0.0)), lift):
		return
	host.set_meta("golem_overhead_lift", lift)
	var bar: Node = host.get_node_or_null("OverheadBar")
	if bar != null and bar.has_method("set_offset"):
		bar.set_offset(OverheadBarScript.CHARACTER_Y_OFFSET + lift)
	var label: Control = host.get_node_or_null("NameLabel") as Control
	if label != null:
		if not label.has_meta("golem_base_y"):
			label.set_meta("golem_base_y", label.position.y)
		label.position.y = float(label.get_meta("golem_base_y")) + lift
