extends RefCounted

## EVCİL HAYVAN kataloğu (kullanıcı isteği 2026-10-12: "petler karakter seçim ekranında silah seçer gibi seçilecek").
## Seçim GameManager.selected_pet'e yazılır (menu_pet_picker.gd); oyun başlayınca player.gd _setup_pet() kurar. Silah/ruhani
## yetenek gibi yerel tercih - ağdan gitmez; köpek zaten broadcast_pet_spawn ile, papağan ilk olayında (remote_player.gd
## korsan_parrot_event) diğer oyunculara görünür.
##  - kopek: eski Matthew köpeği (player_pet.gd) - yakındaki yaratıklara saldırır, hasar/saldırı hızı/kritik sahibin statlarından.
##  - papagan: eski Korsan papağanı (korsan_parrot.gd) - yakındaki ağaçları 3-4 sn gagalayıp yere eşya düşürür (yiyecek / kalkan orbu / mıknatıs / silah parçacığı, değerliler nadir) + LUCK_BONUS şans.
##  - kelebek: Kelebek Ruhu (kelebek_ruhu.gd) - KELEBEK_ATTACK_SPEED saldırı hızı + sahibin İLK silahının vurduğu düşmana pembe lazer
##    atışı (hedefin mevcut canının KELEBEK_CURRENT_HP_PERCENT'i, boss/elitte KELEBEK_BOSS_CURRENT_HP_PERCENT); kuklası ilk olayında kurulur (remote_player.gd kelebek_ruhu_event).
##  - peri: Peri (peri_pet.gd) - sahibin canı eksikken PERI_HEAL_INTERVAL saniyede bir can basar (saldırı gücünün PERI_HEAL_RATIO
##    kadarı ya da azami canının PERI_HEAL_MAX_HP_RATIO'su, hangisi büyükse); kuklası ilk olayında kurulur (remote_player.gd peri_event).
##  - kirpi: Kirpi (kirpi_pet.gd) - sahibine saldıran yaratıklar sahibinin azami kalkanının KIRPI_REFLECT_RATIO'su kadar hasar alır, kalkan
##    varken alınan hasar KIRPI_SHIELD_REDUCTION azalır (player.gd _kirpi_on_hit); dikenleri sahibin görüşünde yaratık varsa açık, yoksa
##    kapalı (sadece görsel). Kuklası ilk olayında kurulur (remote_player.gd kirpi_event).

##  - slime: Minik Cadı (iyi slime, slime_pet.gd; madde 509) - ulti bekleme süresi -SLIME_ULT_CDR (player.gd get_pet_ult_cd_mult; 2026-11-15 saldırı gücü payının yerine);
##    sahibi ULTİSİNİ (R) kullanınca, bekleme dolduysa kulakları parlayıp büyü yapar: SLIME_BUFF_TIME sn can/hasar/boyut/menzil +SLIME_BUFF_PERCENT
##    (player.gd apply_slime_buff; menzil ince çizgiyle görünür, slime_range_ring.gd). Bekleme SLIME_COOLDOWN.
##  - hayalet: Hayalet (hayalet_pet.gd, yarı opak; madde 509) - +HAYALET_DODGE sıvışma; sahibin canı HAYALET_HP_THRESHOLD altına düşünce,
##    bekleme dolduysa bedeniyle sahibini kaplar: HAYALET_COVER_TIME sn görünmez + dokunulmaz (player.gd ghost_cover_active). Bekleme HAYALET_COOLDOWN.

const KEYS := ["kopek", "papagan", "kelebek", "peri", "kirpi", "slime", "hayalet"]
const DEFAULT_KEY := "kopek"
const NAMES := {"kopek": "Köpek", "papagan": "Papağan", "kelebek": "Kelebek Ruhu", "peri": "Peri", "kirpi": "Kirpi", "slime": "Minik Cadı",
	"hayalet": "Hayalet"}
## Papağanın verdiği şans (player.gd luck PUAN sayacı - kart +1,5, Şanslı Zar +2; bkz. stats_panel.gd Şans notu).
const LUCK_BONUS := 10.0
## Kelebek Ruhu: saldırı hızı eşyalarla AYNI toplanan havuza girer (item_fire_rate_percent gibi 0.10 = "+%10 saldırı hızı").
const KELEBEK_ATTACK_SPEED := 0.10
## Lazer atışının hasarı = hedefin MEVCUT canı x bu oran (2026-11-15 kullanıcı: saldırı gücünün %20'si yerine; boss/elitte az, normalde çok etkili).
## Saldırı gücüne bakmaz; varışta okunur (silah vuruşundan sonraki can). Canavarlaştırma Özütü (weapon.gd _item_hit_bonus) ile aynı "health" alanı.
const KELEBEK_CURRENT_HP_PERCENT := 0.06
const KELEBEK_BOSS_CURRENT_HP_PERCENT := 0.006 ## boss VE elit
## Aynı yaratığa en sık bu aralıkla atış (ışın/alev gibi sık vuran silahlarda atış yağmuru olmasın; her atış istemcide host'a bir RPC).
## 2026-11-15: önce 0,2 -> 0,5 denendi, aynı gün kullanıcı 0,2'ye geri aldı (normal yaratıkta güçlü olsun; hızlı silahta en çok ~%27/sn
## mevcut can). Boss/elitte saniyede bir ayrı kalır.
const KELEBEK_SHOT_INTERVAL := 0.2
const KELEBEK_BOSS_SHOT_INTERVAL := 1.0
## Peri: can %100'ün altındayken bu aralıkla can basar; miktar = sahibin saldırı gücü (damage_bonus) x oran.
const PERI_HEAL_INTERVAL := 6.0
const PERI_HEAL_RATIO := 0.10
## 2026-11-14 denge turu: düşük saldırı gücünde Peri işe yaramıyordu - can = max(saldırı gücü x PERI_HEAL_RATIO, azami can x PERI_HEAL_MAX_HP_RATIO).
const PERI_HEAL_MAX_HP_RATIO := 0.015
## Kirpi: sahibine saldıran yaratığa sahibin AZAMİ kalkanı (item_shield_max, Yansıtan Kubbe ile aynı "kalkan gücü" tanımı) x oran hasar;
## sahibin kalkanı (item_shield_hp) varken alınan hasar bu oran kadar azalır.
## 2026-11-14 denge turu (kayıtta hasarın %0,4-1,9'u): yansıtma 0,05 -> 0,12, kalkan azaltma 0,05 -> 0,08.
const KIRPI_REFLECT_RATIO := 0.12
const KIRPI_SHIELD_REDUCTION := 0.08
## Minik Cadı (iyi slime): kalıcı saldırı gücü yüzdesi (item_ap_percent ile AYNI havuz: damage_bonus'u okuyan her yer etkin değeri görür).
## Ulti büyüsü: SLIME_BUFF_TIME sn boyunca azami can, saldırı gücü (= hasar), karakter boyu ve silah menzili +SLIME_BUFF_PERCENT.
const SLIME_ULT_CDR := 0.15 ## 2026-11-15 kullanıcı: kalıcı +%8 saldırı gücü kalktı -> ulti bekleme süresi -%15 (cooldown_reduction sınırı dışında, çarpımsal)
const SLIME_BUFF_PERCENT := 0.15
const SLIME_BUFF_TIME := 8.0
const SLIME_COOLDOWN := 60.0 ## 2026-11-15 kullanıcı: 90 -> 60 (önce 2026-11-09 120 -> 90, madde 513)
## Hayalet: sıvışma stat olarak eklenir (kart/eşya sıvışmasıyla aynı sınır). Can bu oranın altına düşünce kaplar.
const HAYALET_DODGE := 0.05
const HAYALET_HP_THRESHOLD := 0.25
const HAYALET_COVER_TIME := 8.0 ## 2026-11-09 kullanıcı: 5 -> 8 (madde 513)
const HAYALET_COOLDOWN := 80.0 ## 2026-11-09 kullanıcı: 90 -> 80 (madde 513)
const DESCRIPTIONS := {
	"kopek": "Yakındaki yaratıklara saldırır. Statları senin statlarınla aynıdır.",
	"papagan": "Ağaçları gagalayıp yere eşya düşürür (yiyecek, kalkan, nadiren mıknatıs/parçacık). +10 şans verir.",
	"kelebek": "+%10 saldırı hızı. İlk silahının vurduğuna lazer atar (mevcut canının %6'sı, boss ve elitlere %0,6).",
	"peri": "Canın eksikken 6 saniyede bir can basar (saldırı gücünün %10'u ya da azami canının %1,5'i, hangisi büyükse).",
	"kirpi": "Saldıran yaratıklar mana kalkanı gücünün %12'si kadar hasar alır. Mana kalkanın varken %8 az hasar alırsın.",
	"slime": "Ulti bekleme süren %15 azalır (bekleme süresi azaltma sınırından ayrı hesaplanır). Ultini kullanınca büyü yapar: 8 sn canın, hasarın, boyun ve menzilin %15 artar. (60 sn bekleme)",
	"hayalet": "+%5 sıvışma. Canın %25'in altına düşünce üstünü kaplar: 8 sn görünmez ve dokunulmaz olursun. (80 sn bekleme)",
}
## Ikon: oyundaki hayvanın kendi sprite karesi (yeni sanat yok) - bkz. icon().
const FRAMES := {
	"kopek": ["res://assets/pets/dog/dog_frames.tres", &"idle_down"],
	"papagan": ["res://assets/characters/korsan_parrot/parrot_frames.tres", &"perch"],
	"kelebek": ["res://assets/pets/kelebek_ruhu/kelebek_frames.tres", &"fly_down"],
	"peri": ["res://assets/pets/peri/peri_frames.tres", &"fly_down"],
	"kirpi": ["res://assets/pets/kirpi/kirpi_frames.tres", &"acik_down"],
	"slime": ["res://assets/pets/slime/slime_frames.tres", &"idle_down"],
	"hayalet": ["res://assets/pets/hayalet/hayalet_frames.tres", &"idle"],
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
