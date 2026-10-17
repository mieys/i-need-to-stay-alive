extends RefCounted

## EVCİL HAYVAN kataloğu (kullanıcı isteği 2026-10-12: "petler karakter seçim ekranında silah seçer gibi seçilecek").
## Seçim GameManager.selected_pet'e yazılır (menu_pet_picker.gd); oyun başlayınca player.gd _setup_pet() kurar. Silah/ruhani
## yetenek gibi yerel tercih - ağdan gitmez; köpek zaten broadcast_pet_spawn ile, papağan ilk olayında (remote_player.gd
## korsan_parrot_event) diğer oyunculara görünür.
##  - kopek: eski Matthew köpeği (player_pet.gd) - yakındaki yaratıklara saldırır, hasar/saldırı hızı/kritik sahibin statlarından.
##  - papagan: eski Korsan papağanı (korsan_parrot.gd) - yakındaki ağaçları 3-4 sn gagalayıp yere eşya düşürür (yiyecek / kalkan orbu / mıknatıs / silah parçacığı, değerliler nadir) + LUCK_BONUS şans.
##  - kelebek: Kelebek Ruhu (kelebek_ruhu.gd) - KELEBEK_ATTACK_SPEED saldırı hızı + sahibin İLK silahının vurduğu düşmana pembe lazer
##    atışı (saldırı gücünün KELEBEK_DAMAGE_RATIO kadarı); kuklası ilk olayında kurulur (remote_player.gd kelebek_ruhu_event).
##  - peri: Peri (peri_pet.gd) - sahibin canı eksikken PERI_HEAL_INTERVAL saniyede bir can basar (saldırı gücünün PERI_HEAL_RATIO
##    kadarı); kuklası ilk olayında kurulur (remote_player.gd peri_event).
##  - kirpi: Kirpi (kirpi_pet.gd) - sahibine saldıran yaratıklar sahibinin azami kalkanının KIRPI_REFLECT_RATIO'su kadar hasar alır, kalkan
##    varken alınan hasar KIRPI_SHIELD_REDUCTION azalır (player.gd _kirpi_on_hit); dikenleri sahibin görüşünde yaratık varsa açık, yoksa
##    kapalı (sadece görsel). Kuklası ilk olayında kurulur (remote_player.gd kirpi_event).

const KEYS := ["kopek", "papagan", "kelebek", "peri", "kirpi"]
const DEFAULT_KEY := "kopek"
const NAMES := {"kopek": "Köpek", "papagan": "Papağan", "kelebek": "Kelebek Ruhu", "peri": "Peri", "kirpi": "Kirpi"}
## Papağanın verdiği şans (player.gd luck PUAN sayacı - kart +1,5, Şanslı Zar +2; bkz. stats_panel.gd Şans notu).
const LUCK_BONUS := 10.0
## Kelebek Ruhu: saldırı hızı eşyalarla AYNI toplanan havuza girer (item_fire_rate_percent gibi 0.10 = "+%10 saldırı hızı").
const KELEBEK_ATTACK_SPEED := 0.10
## Lazer atışının hasarı = sahibin saldırı gücü (damage_bonus) x bu oran.
const KELEBEK_DAMAGE_RATIO := 0.20
## Aynı yaratığa en sık bu aralıkla atış (ışın/alev gibi sık vuran silahlarda atış yağmuru olmasın; her atış istemcide host'a bir RPC).
const KELEBEK_SHOT_INTERVAL := 0.2
## Peri: can %100'ün altındayken bu aralıkla can basar; miktar = sahibin saldırı gücü (damage_bonus) x oran.
const PERI_HEAL_INTERVAL := 6.0
const PERI_HEAL_RATIO := 0.10
## Kirpi: sahibine saldıran yaratığa sahibin AZAMİ kalkanı (item_shield_max, Yansıtan Kubbe ile aynı "kalkan gücü" tanımı) x oran hasar;
## sahibin kalkanı (item_shield_hp) varken alınan hasar bu oran kadar azalır.
const KIRPI_REFLECT_RATIO := 0.05
const KIRPI_SHIELD_REDUCTION := 0.05
const DESCRIPTIONS := {
	"kopek": "Yakındaki yaratıklara saldırır. Statları senin statlarınla aynıdır.",
	"papagan": "Ağaçları gagalayıp yere eşya düşürür (yiyecek, kalkan, nadiren mıknatıs/parçacık). +10 şans verir.",
	"kelebek": "+%10 saldırı hızı. İlk silahının vurduğuna lazer atar (%20 saldırı gücü).",
	"peri": "Canın eksikken 6 saniyede bir can basar (saldırı gücünün %10'u).",
	"kirpi": "Saldıran yaratıklar mana kalkanı gücünün %5'i kadar hasar alır. Mana kalkanın varken %5 az hasar alırsın.",
}
## Ikon: oyundaki hayvanın kendi sprite karesi (yeni sanat yok) - bkz. icon().
const FRAMES := {
	"kopek": ["res://assets/pets/dog/dog_frames.tres", &"idle_down"],
	"papagan": ["res://assets/characters/korsan_parrot/parrot_frames.tres", &"perch"],
	"kelebek": ["res://assets/pets/kelebek_ruhu/kelebek_frames.tres", &"fly_down"],
	"peri": ["res://assets/pets/peri/peri_frames.tres", &"fly_down"],
	"kirpi": ["res://assets/pets/kirpi/kirpi_frames.tres", &"acik_down"],
}

static var _icon_cache: Dictionary = {}


static func is_valid(key: String) -> bool:
	return KEYS.has(key)


## Geçerli seçim (GameManager'da yoksa / bozuksa varsayılan).
static func selected() -> String:
	var k: String = str(GameManager.selected_pet)
	return k if is_valid(k) else DEFAULT_KEY


static func display_name(key: String) -> String:
	return str(NAMES.get(key, key.capitalize()))


static func description(key: String) -> String:
	return str(DESCRIPTIONS.get(key, ""))


## Hayvanın duruş karesi, saydam kenarları kırpılmış (48x48 karede hayvan küçük kalıyor; menüde büyük görünsün).
static func icon(key: String) -> Texture2D:
	if _icon_cache.has(key):
		return _icon_cache[key]
	var spec: Array = FRAMES.get(key, [])
	if spec.is_empty() or not ResourceLoader.exists(str(spec[0])):
		return null
	var frames: SpriteFrames = load(str(spec[0])) as SpriteFrames
	if frames == null or not frames.has_animation(spec[1]) or frames.get_frame_count(spec[1]) == 0:
		return null
	var tex: Texture2D = frames.get_frame_texture(spec[1], 0)
	var result: Texture2D = tex
	var img: Image = tex.get_image() if tex else null
	if img != null:
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0 and tex is AtlasTexture:
			var at := AtlasTexture.new()
			at.atlas = (tex as AtlasTexture).atlas
			var base: Rect2 = (tex as AtlasTexture).region
			at.region = Rect2(base.position + Vector2(used.position), Vector2(used.size))
			result = at
	_icon_cache[key] = result
	return result
