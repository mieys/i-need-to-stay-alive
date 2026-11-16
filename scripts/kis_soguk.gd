extends Node

## AYAZ DAĞI ÜŞÜME / ISINMA (2026-11-15, kullanıcı: "karlı biyomda ateş kaynaklarından uzakta olunca karakterler üşümeye ve yavaşlamaya
## başlasın, ateşe yaklaşmak ısıtıp toparlasın kısa sürede. uzun süre soğukta kalınca karakter hafiften donmaya başlasın hareket hızı düşsün
## (2 dakikada 1 ısınması gerekecek şekilde ayarla)"). main.gd kurar (MapProfiles "soguk" bayrağı, yalnız Ayaz Dağı).
##
## Değer: oyuncunun `kis_cold`u = ateşten uzakta geçen SANİYE (0 = sıcak). Isı noktası yarıçapında (kis_meta.gd HEAT_SOURCES -> kis_fx.gd
## "isi_kaynagi" grubu: meşale 64, mangal 90, kamp ateşi 120, büyük mangal 150, sıcak kaynak 170 px) WARM_RATE ile hızla düşer.
##  - ÜŞÜME 0..FREEZE_AT (120 sn): hız kaybı 0 -> CHILL_SLOW (%10), karakter yavaşça buz mavisine döner; HUD rozetinin altında donmaya kalan sn.
##  - DONMA FREEZE_AT..MAX_COLD (+30 sn): hız kaybı CHILL_SLOW -> FREEZE_SLOW (%30), renk en soğuk tona iner, ısı çubuğu buz tutar.
##  - Ateş başında donma eşiğinden sıfıra WARM_TIME (4 sn) - en ağır donmadan ~5 sn.
## Sığınak (ev içi / zindan / güvenli alan) sıcak sayılır; ölü / yerde yatan oyuncu sıfırlanır (kalkınca sıcak başlar).
##
## Kim: yalnız YEREL oyuncu ("player" grubu) - her ekran kendi oyuncusunu sayar. Ağ: hız main.gd extra["move_speed"] ile zaten gider (çarpan
## %1 adımlı -> paket her karede değişmez); renk + ısı çubuğu için extra["kc"] (tam saniye, 0'da anahtar yok) -> remote_player.gd set_kis_cold.
## Saf hesaplar (step / move_mult / tint...) static: player.gd, remote_player.gd, overhead_bar.gd ve testler aynı formülü okur.

const HEAT_GROUP := "isi_kaynagi"

const FREEZE_AT := 120.0  ## sn: ateşten bu kadar uzak kalınca donma başlar ("2 dakikada 1 ısınması gerekecek")
const FREEZE_FULL := 30.0 ## donma başladıktan sonra en ağır yavaşlamaya ulaşma süresi
const MAX_COLD := FREEZE_AT + FREEZE_FULL
const WARM_TIME := 4.0    ## ateş başında donma eşiğinden tam sıcağa inme süresi ("kısa sürede")
const WARM_RATE := FREEZE_AT / WARM_TIME
const CHILL_SLOW := 0.10  ## üşüme sonunda (120 sn) hız kaybı
const FREEZE_SLOW := 0.30 ## en ağır donmada hız kaybı
const SLOW_STEP := 0.01   ## çarpan bu adımla yuvarlanır (move_speed paketi her karede değişmesin)
const TINT_FROM := 30.0   ## renk bu saniyeden sonra belirmeye başlar (ateşten ayrılır ayrılmaz mavileşmesin)
const TINT_CHILL := Color(0.80, 0.90, 1.0)  ## donma eşiğindeki ton (sprite rengiyle çarpılır)
const TINT_FREEZE := Color(0.62, 0.80, 1.0) ## en ağır donma
const BADGE_FROM := 1.0   ## HUD rozeti ateşten çıkınca (titreşim olmasın diye 1 sn sonra) görünür

var _sources: Array = [] ## [[Vector2 konum, float yarıçap²], ...] - ısı noktaları haritada sabit, bir kez toplanır


func _ready() -> void:
	name = "KisSoguk"
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if _sources.is_empty():
		_sources = collect_sources(get_tree())
		if _sources.is_empty():
			return
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D) or not p.has_method("set_kis_cold"):
			continue
		var c: float = float(p.get("kis_cold"))
		if bool(p.get("is_dead")) or bool(p.get("is_downed")):
			c = 0.0
		else:
			c = step(c, delta, is_sheltered(p) or is_warm_at((p as Node2D).global_position, _sources))
		p.call("set_kis_cold", c)


static func collect_sources(tree: SceneTree) -> Array:
	var out: Array = []
	for n in tree.get_nodes_in_group(HEAT_GROUP):
		if n is Node2D:
			var r: float = float((n as Node).get_meta("yaricap", 0.0))
			if r > 0.0:
				out.append([(n as Node2D).global_position, r * r])
	return out


static func is_warm_at(pos: Vector2, sources: Array) -> bool:
	for s: Array in sources:
		if pos.distance_squared_to(s[0]) <= float(s[1]):
			return true
	return false


## Ev içi / zindan / güvenli alan (satıcı koruması) ateş başı sayılır.
static func is_sheltered(p: Node) -> bool:
	return bool(p.get("is_indoors")) or str(p.get("in_dungeon")) != "" or bool(p.get("is_in_merchant_zone"))


static func step(cold: float, delta: float, warm: bool) -> float:
	if warm:
		return maxf(0.0, minf(cold, MAX_COLD) - WARM_RATE * delta)
	return minf(MAX_COLD, cold + delta)


## Donma ilerlemesi 0..1 (0 = henüz donmuyor, 1 = en ağır).
static func freeze_k(cold: float) -> float:
	return clampf((cold - FREEZE_AT) / FREEZE_FULL, 0.0, 1.0)


static func is_freezing(cold: float) -> bool:
	return cold >= FREEZE_AT


## Isı çubuğunun doluluğu: 1 = sıcak, 0 = donuyor.
static func warmth_ratio(cold: float) -> float:
	return 1.0 - clampf(cold / FREEZE_AT, 0.0, 1.0)


static func move_mult(cold: float) -> float:
	var slow: float
	if cold < FREEZE_AT:
		slow = CHILL_SLOW * clampf(cold / FREEZE_AT, 0.0, 1.0)
	else:
		slow = lerpf(CHILL_SLOW, FREEZE_SLOW, freeze_k(cold))
	return 1.0 - snappedf(slow, SLOW_STEP)


## Karakter sprite'ının (anim.self_modulate rgb) tonu: beyaz -> TINT_CHILL (30..120 sn) -> TINT_FREEZE (donma).
static func tint(cold: float) -> Color:
	if cold < FREEZE_AT:
		return Color.WHITE.lerp(TINT_CHILL, clampf((cold - TINT_FROM) / (FREEZE_AT - TINT_FROM), 0.0, 1.0))
	return TINT_CHILL.lerp(TINT_FREEZE, freeze_k(cold))


## Tonu karakter sprite'ına yazar (player.gd + remote_player.gd). Yalnız rgb: alfa çalı / hayalet örtüsünün (_apply_body_alpha), anim.modulate
## vuruş / zehir / görünmezliğin, kök modulate yeteneklerin - dokunulmaz. Büyücü Yükselişi (buyucu_levitate.gd) havadayken self_modulate'ı her
## karede kendisi yazar: o sürece atlanır, inince ilk çağrı tonu geri koyar.
static func apply_tint(host: Node, anim: CanvasItem, cold: float) -> void:
	if anim == null or not is_instance_valid(anim) or host.get_node_or_null("BuyucuLevitate") != null:
		return
	var t: Color = tint(cold)
	var m: Color = anim.self_modulate
	if m.r != t.r or m.g != t.g or m.b != t.b:
		anim.self_modulate = Color(t.r, t.g, t.b, m.a)


## Can barının altındaki ısı çubuğu (overhead_bar.gd set_warmth): sıcakken gizli.
static func apply_bar(bar: Node, cold: float) -> void:
	if bar != null and is_instance_valid(bar) and bar.has_method("set_warmth"):
		bar.call("set_warmth", warmth_ratio(cold), is_freezing(cold), cold > 0.0)


## Ağ değeri: tam saniye (paket saniyede en çok bir kez değişir).
static func net_value(cold: float) -> int:
	return int(round(cold))


## HUD durum satırı (player.gd get_status_effects): üşürken donmaya kalan süre, donarken süresiz rozet; sıcakken yok.
static func status_entry(cold: float) -> Dictionary:
	if cold < BADGE_FROM:
		return {}
	if cold < FREEZE_AT:
		return {"id": "kis_cold", "kind": "cold", "is_buff": false, "stacks": 0, "remaining": FREEZE_AT - cold, "duration": FREEZE_AT}
	return {"id": "kis_cold", "kind": "freeze", "is_buff": false, "stacks": 0, "remaining": -1.0, "duration": -1.0}
