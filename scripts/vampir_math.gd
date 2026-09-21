extends RefCounted

## Vampir Çocuk (roster id 13) - player.gd (yetkili/gerçek oyuncu) VE remote_player.gd
## (diğer istemcilerdeki kozmetik kopya) tarafından PAYLAŞILAN formüller.
##
## KÖK NEDEN NOTU (bkz. CLAUDE.md "yeni yetenek eklerken eskisi kalıyor" hata sınıfı, madde 3):
## Yarasa Formu'nda (E) silahların karakterin İÇİNE çekilip kaybolması ve bitince geri çıkması
## kare-kare hesaplanan bir görsel - ağdan pozisyon alınmaz, her istemci KENDİ kopyasını hesaplar.
## Formül iki dosyaya ayrı ayrı yazılırsa biri değiştirilince diğer oyuncularda silahlar farklı
## hızda/yerde görünür. Bu yüzden ikisi de BURADAKİ static fonksiyonları çağırır. Aynısı R'nin
## küçük yarasalarının ev-yörünge konumu için de geçerli (bat_home_offset).

const CHAR_ID := 13
## Silahların gövdeye çekilme / geri çıkma süresi (sn).
const PULL_TIME := 0.35
## Silahların "çekildiği" nokta - karakter düğümünün yerel uzayında (gövdenin ortası).
const BODY_CENTER := Vector2(0, -6)
## R yeteneği: aynı anda dolaşan küçük yarasa sayısı.
const BAT_COUNT := 6
const BAT_HOME_RADIUS := 30.0
## Karakter dokusunun 1 sanat pikselinin dünyadaki boyutu (DEFAULT_ANIM_SCALE 1.27575 x EntityScale.SIZE 0.95).
## Tüm Vampir FX'leri bu ızgaraya oturtulur - bkz. feedback "pixel-style FX".
const TEXEL := 1.212

const BAT_ANIM_PREFIX := "bat_"


static func is_bat_anim(anim_name: String) -> bool:
	return anim_name.begins_with(BAT_ANIM_PREFIX)


## pull: 0 = silahlar normal yerinde, 1 = tamamen gövdenin içinde. absorbed=true iken 1'e,
## değilken 0'a PULL_TIME sürede doğrusal ilerler.
static func step_pull(pull: float, absorbed: bool, delta: float) -> float:
	return move_toward(pull, 1.0 if absorbed else 0.0, delta / PULL_TIME)


static func eased(pull: float) -> float:
	var t: float = clampf(pull, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Bir silah ikonunun (karakter düğümüne göre) o anki yeri: slot -> BODY_CENTER arası yumuşak geçiş.
static func icon_offset(slot: Vector2, pull: float) -> Vector2:
	return slot.lerp(BODY_CENTER, eased(pull))


## İkon saydamlığı: gövdeye yaklaştıkça (pull 0.5 -> 1) tamamen kaybolur.
static func icon_alpha(pull: float) -> float:
	return 1.0 - smoothstep(0.5, 1.0, clampf(pull, 0.0, 1.0))


## R yarasalarının karakterin çevresindeki dinlenme (ev) yörüngesi, karakter konumuna göre.
static func bat_home_offset(index: int, count: int, time: float) -> Vector2:
	var a: float = TAU * float(index) / float(maxi(count, 1)) + time * 1.6
	return Vector2(cos(a) * BAT_HOME_RADIUS, sin(a) * BAT_HOME_RADIUS * 0.55 - 26.0)


## Dünya konumunu piksel ızgarasına (TEXEL) oturtur.
static func snap(v: Vector2) -> Vector2:
	return (v / TEXEL).round() * TEXEL


## Vampir FX'i doğar: kind = "hit" | "puff" | "drain". opts: drain için "points" (PackedVector2Array,
## kaynak dünya konumları) ve "sink" (Node2D - damlaların aktığı karakter/kukla).
static func spawn_fx(host: Node, kind: String, world_pos: Vector2, opts: Dictionary = {}) -> Node2D:
	if host == null or not is_instance_valid(host):
		return null
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/vampir_fx.gd"))
	fx.set("kind", kind)
	if opts.has("points"):
		fx.set("points", opts["points"])
	if opts.has("sink"):
		fx.set("sink", opts["sink"])
	host.add_child(fx)
	fx.global_position = world_pos
	return fx
