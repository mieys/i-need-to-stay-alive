## Süzülen silah ikonlarının yerel silah (weapon.gd) VE uzak oyuncu kuklası (remote_player.gd) arasında PAYLAŞILAN
## sabitleri/formülleri - ikon boyu ve gölge. Biri güncellenip diğeri unutulursa diğer oyuncularda silahlar farklı
## görünür (CLAUDE.md "iki ayrı yer" hata sınıfı); iki taraf da SADECE buradan okur.
##
## (Dosyanın adı eski "dönen kılıç"tan (orbit sword) kaldı: 2026-09-26'da Uzunkılıç hedefe savrulan bir silaha
## dönüştü - yörünge formülü ve iz fonksiyonları (compute/update_arc/spawn_trail) silindi; savuruşun ortak matematiği
## artık scripts/sword_swing_math.gd'de. assets/fx/sword_arc artık kullanılmıyor.)
class_name WeaponOrbitMath
extends RefCounted

## Kullanıcı isteği (2026-09-25): "silahların boyutunu %15 küçült". Silah ikonunun ölçeği hem yerel silahta (weapon.gd
## _ready) hem uzak oyuncu kuklasında (remote_player.gd update_weapon_visuals) AYRI ayrı kuruluyor - ikisi de bu TEK
## çarpanı kullanır ki diğer oyunculara silahlar farklı boyda görünmesin (CLAUDE.md "iki yer" hata sınıfı).
const ICON_SIZE_MULT: float = 0.85

## ---------- Süzülen silahların gölgesi (weapon.gd _update_icon_shadow + remote_player.gd _refresh_remote_weapon_shadow) ----------
## Kullanıcı bildirimi (2026-09-25): "silahların gölgesi doğru konumda gösterilmiyor, yukardaki silahların gölgesi çok
## yukarda". Kök neden: gölge her silahta ikonun SABİT 62 birim altına çiziliyordu; ama slotlar farklı yükseklikte (tepe
## -125, üst yanlar -70, yanlar -28, ayak +33) - tepedeki silahın gölgesi kafanın üstünde havada kalıyordu. Artık yer
## noktası slotun yüksekliğiyle orantılı: en alttaki (yan) slotlar eskisi gibi 62 (ayak hizası), yukarıdaki slotlar
## karakterin arkasındaki zemine (ayak çizgisinin biraz üstü) iner. Gölgeler karakterin ALTINDA çizilir (bkz. weapon.gd).
const HOVER_SHADOW_BASE_GAP: float = 62.0
const HOVER_SHADOW_LOWEST_SLOT_Y: float = -28.0
const HOVER_SHADOW_HEIGHT_TO_GROUND: float = 0.9


## slot_y: ikonun karaktere göre YEREL y'si (bob/tepme hariç ya da dahil - ikisi de olur). Dönen: ikondan gölgeye dikey boşluk.
static func hover_shadow_gap(slot_y: float) -> float:
	return HOVER_SHADOW_BASE_GAP + maxf(0.0, HOVER_SHADOW_LOWEST_SLOT_Y - slot_y) * HOVER_SHADOW_HEIGHT_TO_GROUND
