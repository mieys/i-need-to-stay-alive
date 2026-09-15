## Talon'un Silah Salvosu (E, skill2 id 36) ve Ayna Formu (R, skill3 id 37)
## yeteneklerinde silahları karakter etrafında dairesel dizen ORTAK
## matematik - bkz. CLAUDE.md "sürekli/karede-karede simüle edilen görsel"
## uyarısı. player.gd (yetkili silahlar, bkz. _talon_set_weapons_circular)
## VE remote_player.gd (kozmetik ikon kopyası, bkz. _update_talon_formation)
## SADECE bu static fonksiyonları çağırır - formül iki dosyada bir daha asla
## birbirinden sapamaz.
class_name TalonFormationMath
extends RefCounted

const SALVO_RADIUS: float = 130.0
const SALVO_DURATION: float = 3.0
const SALVO_ROTATIONS: float = 2.0
const MIRROR_RADIUS: float = 110.0


## count silahı merkez etrafına eşit açılarla dizer; i'inci silahın parent'a
## göre yerel/izafi konumunu ("offset") ve namlunun dışa bakması için ikon
## rotasyonunda kullanılacak açıyı ("angle", çağıran taraf kendi
## sprite_forward_angle_deg'ini düşer) tek pakette döndürür.
static func compute_slot(i: int, count: int, radius: float, angle_offset: float) -> Dictionary:
	if count <= 0:
		return {"angle": angle_offset, "offset": Vector2.ZERO}
	var angle: float = angle_offset + (TAU / count) * i
	return {
		"angle": angle,
		"offset": Vector2(cos(angle), sin(angle)) * radius,
	}


## Silah Salvosu'nun dönüş açısını bir kare ilerletir (SALVO_DURATION'da
## SALVO_ROTATIONS tam tur). remote_player.gd bu açıyı ağdan almak yerine
## KENDİ yerel sayacıyla integre eder - weapon_orbit_math.gd'deki uzunkılıç
## dönüşüyle AYNI mantık: faz caster ile birebir eşleşmeyebilir ama sürekli/
## dekoratif bir dönüş olduğu için fark edilmez.
static func advance_salvo_angle(angle_in: float, delta: float) -> float:
	var rotation_speed: float = (TAU * SALVO_ROTATIONS) / SALVO_DURATION
	return angle_in + delta * rotation_speed
