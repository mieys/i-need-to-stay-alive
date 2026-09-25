## Silahların öldüğünde yere düşme/dirilince geri dönme animasyonunun
## PAYLAŞILAN fiziği - weapon.gd (yerel/gerçek silah) VE remote_player.gd
## (diğer oyunculardaki kozmetik kopya) BU dosyayı çağırıyor, formülü ayrı
## ayrı KOPYALAMIYOR (bkz. weapon_orbit_math.gd'deki AYNI kök neden notu -
## iki yerde tutulan bir formül, biri güncellenince diğeri unutuluyor).
##
## KÖK NEDEN NOTU (kullanıcı bildirimi: "düşme animasyonu doğal değil,
## Minecraft'ta ölünce itemlerin yere düşmesi gibi düşmeleri gerekiyor,
## gölgeler görünmüyor ve çok ruhsuz"): eski deneme TEK bir Tween ile
## global_position'ı (yatay+dikey birlikte) TRANS_BOUNCE ile düz bir ÇİZGİ
## üzerinde interpolasyon yapıyordu - "bounce" eğrisi bu durumda düz çizgi
## üzerinde ileri-geri KAYMA gibi görünüyordu (gerçek bir dikey sekme değil),
## ve gölgenin boşluğu bu YANILTICI konumdan tamamen KOPUK, sadece geçen
## zamana bağlı ayrı bir "progress" değişkeniyle hesaplanıyordu - ikisi asla
## tutarlı değildi. Minecraft'taki item drop hissi: YATAYDA (XY) düz bir
## hedefe doğru sabit/yumuşak hareket eder, DİKEYDE ise AYRI bir "yükseklik"
## (height) yukarı fırlayıp yerçekimiyle düşer, yere çarpınca sönümlenerek
## birkaç kez sekip sonunda durur. Height DOĞRUDAN gölgenin boşluğunu besler
## (bkz. weapon.gd/remote_player.gd _update_*_shadow) - ikisi ASLA kopmaz.
class_name WeaponDeathDropMath
extends RefCounted

const GRAVITY := 1000.0 ## px/sn^2
const INITIAL_UP_SPEED_MIN := 220.0 ## ilk fırlamanın dikey hızı (rastgele aralık - hepsi aynı yükseklikte zıplamasın diye)
const INITIAL_UP_SPEED_MAX := 320.0
const BOUNCE_DAMPING := 0.4 ## her yere çarpışta dikey hız bu oranla küçülür
const MIN_BOUNCE_SPEED := 60.0 ## bu hızın altına inince sekmeyi bırakıp yerde SABİT kal
const XY_DURATION := 0.4 ## yatay konumun (parent'a göre hedef) ne kadar sürede tamamlanacağı
const SPIN_SPEED_MIN := 6.0 ## rad/sn, düşerken dönme hızı
const SPIN_SPEED_MAX := 12.0
## Silahın normal (hover) konumundan ne kadar uzağa saçılacağı - weapon.gd VE
## remote_player.gd İKİSİ de buradan okur (bkz. dosya başı kök neden notu).
const SCATTER_RADIUS_MIN := 18.0
const SCATTER_RADIUS_MAX := 50.0
## Gölge boşluğu (px cinsinden, height ile BİREBİR aynı ölçek) bu değerin
## üstüne çıkmaz - ilk fırlamanın tepe noktası (v^2/2g) bu sınırın altında
## kalacak şekilde INITIAL_UP_SPEED ile uyumlu seçildi.
const MAX_SHADOW_GAP := 70.0
## Kullanıcı isteği (2026-09-25): "ölünce silahlar etrafa saçılıp hafifçe opaklaşsın dirilince ease ease halinde geri
## dönsün karaktere" - yerdeyken silah (ikon + gölge) bu opaklığa iner (düşerken kademeli), dirilince geri dönüş
## RISE_DURATION sürer ve ease-in-out'tur (yavaş kalkar, hızlanır, yavaşça yerine oturur); opaklık da aynı eğriyle 1'e çıkar.
## weapon.gd ve remote_player.gd ikisi de buradan okur (self_modulate - Vampir yarasa formunun modulate'ıyla çakışmaz).
const GROUND_ALPHA := 0.55
const RISE_DURATION := 0.75


## Düşerken opaklık: 1 -> GROUND_ALPHA (yatay kaymayla aynı eğri).
static func fall_alpha(elapsed: float) -> float:
	return lerpf(1.0, GROUND_ALPHA, ease_out_cubic(elapsed / XY_DURATION))


## Dönüşün konum/opaklık eğrisi (0..1 zaman -> 0..1 ilerleme).
static func ease_in_out_cubic(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0


## Bir fizik karesi kadar dikey "sekme" simülasyonu ilerletir - height (>=0,
## px) ve v_speed (+yukarı) parent'tan/ölçekten TAMAMEN bağımsız, saf bir
## yerçekimi/reflect simülasyonu.
## Döner: {"height": yeni yükseklik, "v_speed": yeni dikey hız, "settled": tam oturdu mu (bundan sonra hep 0/0 döner)}
static func step_bounce(height: float, v_speed: float, delta: float, settled: bool) -> Dictionary:
	if settled:
		return {"height": 0.0, "v_speed": 0.0, "settled": true}
	v_speed -= GRAVITY * delta
	height += v_speed * delta
	if height <= 0.0:
		height = 0.0
		if absf(v_speed) < MIN_BOUNCE_SPEED:
			return {"height": 0.0, "v_speed": 0.0, "settled": true}
		v_speed = -v_speed * BOUNCE_DAMPING
	return {"height": height, "v_speed": v_speed, "settled": false}


## t: 0..1 (elapsed / XY_DURATION, çağıran taraf clamp'liyor). Ease-out cubic -
## hızlı çıkar, yavaşça yerleşir (bkz. Minecraft item toss hissi).
static func ease_out_cubic(t: float) -> float:
	var inv: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - inv * inv * inv
