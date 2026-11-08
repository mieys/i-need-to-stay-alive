extends RefCounted
## MÜTTEFİK EFEKT YOĞUNLUĞU (2026-11-06, madde 425; kullanıcı: "savaşta multiplayerda aşırı göz yorucu ve karmaşık").
## Analiz + sınıf tablosu: docs/oneri/savas_gorsel_karmasa_2026-11-06.md (5b). ALICI TARAFTA çalışır, ağ/senkron DEĞİŞMEZ; kendi (yerel)
## efektlerine hiç dokunmaz - yalnız BAŞKA oyuncunun kopyası olan efektler (network_manager.gd uzak dalları + remote_player.gd).
##
## DÖRT SINIF (kullanıcı kuralları):
##   TAKIM    (Melek bağı/R, Şovalye Yankı/Bariyer/Baloncuk, Oakley ağaç/çiçek, Cadı iksiri, diriltme ...) -> HEP tam opak
##   ÇAĞRILAN (Necro iskelet/golem, Shaman totemleri, evcil hayvan, arı sürüsü)                         -> HEP tam opak
##   FORM     (Shaman golem, Matthew topu, Vampir yarasa, Talon formu, Cadı süpürgesi ...)              -> HEP tam opak + sayaca girmez
##   KİŞİSEL  (kendi gösterişi: namlu, vuruş izi, kast süsü, asa ucu partikülü, uzak mermi)             -> bu modülün azalttığı TEK sınıf
## Güvenli varsayılan: tabloda OLMAYAN efekt tam görünür sayılır (yanlışlıkla saydam yapmak, fazla göstermekten kötüdür). Bu yüzden burada
## yalnız KİŞİSEL listesi var; yeni bir efekt eklerken buraya EKLEMEZSEN tam görünür kalır.
## Kasteri o anda FORM'da olan kuklanın efektleri (RemotePlayer.is_in_form) tabloda olsa bile azaltılmaz.
##
## Modlar (Ayarlar > Genel > Müttefik Efektleri, UISound.ally_fx_mode): 0 Tam, 1 Azaltılmış (varsayılan), 2 Minimal.
## Otomatik yoğunluk: ekrandaki KİŞİSEL birim sayısı (grup GROUP) eşiği aşınca Azaltılmış/Minimal kendiliğinden biraz daha soluklaşır;
## Tam modunda hiçbir şey değişmez. A/B ölçümü için ortam değişkeni ALLY_FX_MODE=0|1|2 ayarı ezer (araçlar: tools/buyuk_test/mp_clutter.ps1).

const MODE_FULL := 0
const MODE_REDUCED := 1
const MODE_MINIMAL := 2

const GROUP := &"ally_personal_fx"

## KİŞİSEL efekt (yetenek sahnesi, vuruş izi, namlu) alfa çarpanı / uzak mermi / asa ucu partikülü - mod sırasıyla.
const FX_ALPHA: Array = [1.0, 0.6, 0.35]
const PROJ_ALPHA: Array = [1.0, 0.8, 0.6]
const TIP_ALPHA: Array = [1.0, 0.5, 0.0] ## 0 = asa ucu partikülü hiç kurulmaz
const CASING_ON: Array = [true, false, false] ## boş kovan (kuklada) - kozmetik kalabalık

## Otomatik yoğunluk: eşik altı etkisiz, AUTO_FULL üstünde en yoğun. Ek alfa çarpanları (Tam modunda uygulanmaz).
const AUTO_START := 18
const AUTO_FULL := 48
const AUTO_EXTRA_FX := 0.7
const AUTO_EXTRA_PROJ := 0.85

## KİŞİSEL sahneler (taban adı). Hem "skill_scene" hem "hitscan_impact" dalı bunu okur. Bilerek DIŞARIDA kalanlar:
## FORM (fx_talon_form, fx_matthew_ball, fx_matthew_form_burst, fx_evo_vanish, fx_assasin_stealth), tehlike/alan çekirdeği (fx_buyucu_tornado,
## fx_korsan_zone, meteor/hortum), TAKIM/ÇAĞRILAN sahneleri ve root `modulate.a`'yı kendi süren sahneler (fx_evo_loop = Assasin güçlenme,
## fx_enemy_burn_status): onların kendi alfa tween'i çarpanı ezerdi, o yüzden tam kalır.
const PERSONAL_SCENES: Dictionary = {
	"fx_matthew_fox_strike": true, "fx_matthew_claw_slash": true, "fx_matthew_spark": true, "fx_matthew_shield_cast": true,
	"fx_talon_chains": true, "fx_talon_dash": true, "fx_evo_talon_ward": true, "fx_evo_talon_block": true,
	"fx_evo_assasin_evade": true, "fx_evo_blood_shield": true, "fx_evo_buyucu_enchant": true, "fx_evo_cooldown_reset": true,
	"fx_evo_gain": true, "fx_evo_shield_refill": true, "fx_evo_spin_spark": true, "fx_evo_kunai_hit": true,
	"fx_evo_blood_burst": true, "fx_evo_bat_swoop": true,
	"fx_assasin_dash": true, "fx_assasin_shadow_hit": true, "fx_assasin_slash": true,
	"fx_buyucu_fastfire": true, "fx_buyucu_surge_spark": true, "fx_buyucu_surge_wave": true, "fx_buyucu_tornado_cast": true,
	"fx_buyucu_tornado_hit": true, "fx_buyucu_meteor_channel": true, "fx_mage_swap": true, "fx_mage_passive_burst": true,
	"fx_blood_splatter": true,
}

static var _env_mode: int = -2 ## -2 = henüz okunmadı, -1 = yok


## Etkin mod (ortam değişkeni > ayar).
static func mode() -> int:
	if _env_mode == -2:
		var env: String = OS.get_environment("ALLY_FX_MODE")
		_env_mode = clampi(int(env), 0, 2) if not env.is_empty() else -1
	if _env_mode >= 0:
		return _env_mode
	return clampi(UISound.ally_fx_mode, 0, 2)


static func is_personal_scene(scene_path: String) -> bool:
	return PERSONAL_SCENES.has(scene_path.get_file().get_basename())


## Ekrandaki KİŞİSEL birim yoğunluğu 0..1 (eşik AUTO_START..AUTO_FULL).
static func load_factor(tree: SceneTree) -> float:
	if tree == null:
		return 0.0
	var n: int = tree.get_node_count_in_group(GROUP)
	return clampf(float(n - AUTO_START) / float(AUTO_FULL - AUTO_START), 0.0, 1.0)


## Kasteri formda mı (golem/top/yarasa/Talon formu/süpürge ...)? Kukla yoksa (yerel oyuncu / bilinmiyor) false.
static func caster_in_form(caster: Node) -> bool:
	return caster != null and is_instance_valid(caster) and caster.has_method("is_in_form") and bool(caster.call("is_in_form"))


## Verilen mod için KİŞİSEL efekt/mermi alfa çarpanı (otomatik yoğunluk dahil). 1.0 = dokunma.
static func alpha_for(kind: String, tree: SceneTree) -> float:
	var m: int = mode()
	if m == MODE_FULL:
		return 1.0
	var base: float = float((PROJ_ALPHA if kind == "proj" else FX_ALPHA)[m])
	var extra: float = AUTO_EXTRA_PROJ if kind == "proj" else AUTO_EXTRA_FX
	return base * lerpf(1.0, extra, load_factor(tree))


## Uzak bir KİŞİSEL efektin alfa çarpanı (1.0 = dokunma) ve sayaca ekleme. Kendi `modulate.a`sını her karede yazan efektler (sürekli alev) için:
## çarpanı kendi alanlarına koyup kendileri uygular. Tam modda, formdaki kasterde ya da geçersiz düğümde 1.0 döner ve sayaca girmez.
static func mult_for(node: Node, caster: Node, kind: String = "fx") -> float:
	if node == null or not is_instance_valid(node):
		return 1.0
	if mode() == MODE_FULL or caster_in_form(caster):
		return 1.0
	node.add_to_group(GROUP)
	return alpha_for(kind, node.get_tree())


## Uzak bir KİŞİSEL efekti/mermiyi soluklaştırır ve sayaca ekler. kind: "fx" | "proj". Tam modda, formdaki kasterde ya da geçersiz düğümde hiçbir şey yapmaz.
static func soften(node: Node, caster: Node, kind: String = "fx") -> void:
	if node == null or not is_instance_valid(node) or not (node is CanvasItem):
		return
	var a: float = mult_for(node, caster, kind)
	if a < 1.0:
		(node as CanvasItem).modulate.a *= a


## Yaratık yanma alevi (fx_burn_status.gd) için ekranda AYNI ANDA gösterilecek en çok alev sayısı: 0 = sınırsız (Tam). Sınırı aşan yanan yaratıkta
## yalnız duman kalır (en yakın N alev, oyuncunun kamerasına göre). Yanma hasar/durum olarak aynen sürer - yalnız çizim.
const BURN_FLAME_CAP: Array = [0, 12, 6]


static func burn_flame_cap() -> int:
	return int(BURN_FLAME_CAP[mode()])


## Asa ucu partikülü: 0 = kurma, aksi hâlde alfa çarpanı. Formdaki kasterde 1.
static func tip_alpha(caster: Node) -> float:
	var m: int = mode()
	if m == MODE_FULL or caster_in_form(caster):
		return 1.0
	return float(TIP_ALPHA[m])


## Kuklada boş kovan çıksın mı?
static func casing_allowed(caster: Node) -> bool:
	var m: int = mode()
	return m == MODE_FULL or caster_in_form(caster) or bool(CASING_ON[m])
