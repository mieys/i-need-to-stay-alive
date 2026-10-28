extends RefCounted

## MATTHEW REWORK (2026-10-12, madde 98; kullanıcı: "Q bundan sonra köpeğiyle değil kendi şimşek gücüyle alakalı ... yeni pasif ... yeni E ...
## yeni ulti") - sayılar, formüller ve sprite sayfaları TEK yerde. player.gd (kaster) ile remote_player.gd (diğer ekranlardaki kukla)
## AYNI sabitleri/fonksiyonları buradan okur (CLAUDE.md "MP iki-yer hatası": görsel iki tarafta ayrı kurulur, biri unutulmasın).
##   Pasif  Yıldırım Hızı   - hareket ederken saniyede +%1 hareket hızı (en çok %15; 2026-10-14'te %30'dan düştü); dururken 5 sn'de söner.
##                            Saldırı hızı: TOPLAM hareket hızı bonusunun (her kaynaktan: bu pasif + kart + eşya + ruhani...) her %1'i = %0,5 saldırı hızı
##                            (genel %600 saldırı hızı sınırına kadar; pasif payı taşma->saldırı gücü dönüşümüne girmez).
##                            Arkasında 1 sn'de incelip sönen yıldırım izi; tam hızda iz GÜÇLENİR: değdiği yaratık 1 sn sersemler + %80 AP
##                            (aynı yaratığa 3 sn'de bir).
##   Q      Şimşek Hücumu   - eski Köpek Hücumu'nun AYNISI (en yakın 6 hedef, %110 AP), köpek yerine Matthew'dan çakan şimşek.
##   E      Elektrik Topu   - 3 sn top formu: dokunulmaz, silahlar içe çekilir (Vampir yarasa mekanizması), %20 toplam hareket hızı;
##                            değdiği yaratık %200 AP alıp fırlar, fırlayan yaratık bir başkasına çarparsa o da %200 AP alır
##                            (aynı yaratığa 0,5 sn'de bir). 20 sn bekleme.
##   R      Yıldırım Kalkanı - eski Feda Kalkanı'nın AYNISI (%1000 AP kapasite, kırılınca patlama) ama köpek gerekmez; Q ve pasif çalışır.
##                            Kalkan kırılmaya yaklaştıkça Matthew sarı parıldar (glow_level).
## Sprite sayfaları: tools/gen_matthew_lightning_fx.py (çizim tools/proto_20261012/gen_matthew_simsek.py) -> assets/fx/matthew_lightning/.

const CHAR_ID := 3
const Q_SKILL_ID := 43
const E_SKILL_ID := 50
const R_SKILL_ID := 9

## ÖLÇEK (TUZAK): Player / RemotePlayer kökü sahnede 0,5 ölçekli (main.tscn, remote_player.tscn). Bu yüzden iki ayrı piksel boyu var:
##  - KARAKTERE BAĞLI efektler (top, kalkan, dönüşüm patlaması, çağırma şimşeği - oyuncunun çocuğu): sprite ölçeği TEXEL (yerel) ->
##    dünyada 0,606 birim/piksel. Bu sayfalar gövdeye göre x1,311 büyük çizildi (tools/gen_matthew_lightning_fx.py ORAN DÜZELTMESİ).
##  - DÜNYADA duran efektler (iz, şimşek, isabet kıvılcımı - sahnenin çocuğu): WORLD_TEXEL = Matthew'in kendi pikselinin dünyadaki
##    boyu (sprite ölçeği 1,5895 x kök 0,5). Prototipte efekt pikseli = Matthew pikseli çizildiği için oran birebir tutar.
##    (TEXEL ile çizilseydi iz/şimşek onaylanan prototipten ~1,5 kat kalın ve iri pikselli olurdu.)
##  - Kalkan patlaması (nova) dünya efekti ama TEXEL ile: yarıçapı hasar yarıçapına (220 dünya birimi) bağlı.
## Testler oyuncuyu ölçeksiz (1,0) kurar - dünya ofsetleri bu yüzden sahibin ölçeğiyle çarpılır (BODY_CENTER * scale).
const TEXEL := 1.212
const WORLD_TEXEL := 0.795
## Gövde ortası / baş üstü (karakter düğümünün YEREL koordinatı): Matthew'in 48x48 karesinde gövde y 8..40, ölçek 1,5895, offset -1,8 px.
const BODY_CENTER := Vector2(0.0, -3.0)
const HEAD_TOP := Vector2(0.0, -28.0)

# ---------------------------------------------------------------- Pasif: Yıldırım Hızı
const MOMENTUM_MAX := 0.15 ## en fazla %15 hareket hızı (2026-10-14: %30 -> %15, kullanıcı isteği)
## 2026-10-14 (kullanıcı): "her %1 hareket hızı başına %0,5 saldırı hızı (her kaynaktan, %600 sınırına kadar)". Eskiden birikimin kendisi = aynı oranda saldırı hızıydı.
const MOVE_TO_ATTACK_RATIO := 0.5
const MOMENTUM_GAIN_PER_SEC := 0.01 ## hareket ederken saniyede +%1
const MOMENTUM_DECAY_TIME := 5.0 ## dururken TAM bonus 5 sn'de sıfıra iner
const MOVING_SPEED := 20.0 ## bu hızın üstü "hareket ediyor"
const TRAIL_LIFE := 1.0
const TRAIL_STAGES := 8
const TRAIL_VARIANTS := 3
const TRAIL_TILE := Vector2(16.0, 32.0) ## sayfa karosu (sanat pikseli); çizgi karonun orta satırından girer/çıkar
const TRAIL_STEP := 16.0 * WORLD_TEXEL ## bu kadar yol (dünya birimi) başına bir damga
const TRAIL_OFFSET := Vector2(0.0, 8.0) ## izin geçtiği yükseklik (uyluk hizası) - sahibin YEREL koordinatı
const TRAIL_HIT_RADIUS := 6.0 ## güçlenmiş izin temas yarıçapı, dünya birimi (+ yaratığın gövde yarıçapı)
const TRAIL_HIT_INTERVAL := 3.0 ## aynı yaratık 3 sn'de bir sersemler/hasar alır (kullanıcı seçimi)
const TRAIL_STUN := 1.0
const TRAIL_DAMAGE_RATIO := 0.8 ## %80 saldırı gücü
const TRAIL_SCAN_INTERVAL := 0.1

# ---------------------------------------------------------------- Q: Şimşek Hücumu
const BOLT_INTERVAL := 0.11 ## iki çakış arası (eski köpek sekansı 0,09 + 0,07)
const BOLT_STAGE_TIME := 0.05 ## şimşeğin 6 evresinden her biri
## Şimşek döşeme sayfası (assets/fx/matthew_lightning/bolt_tiles.png, tools/bake_matthew_bolt.gd): düz (sağa bakan) şimşek parçaları, sütun = evre
## (6), satır = tür: 0-1 BAŞ (sivri uç + elde parlama), 2-6 ORTA (2. ve 5. satırda çatal), 7-8 SON (sivri uç). Parçalar x ekseninde BOLT_TILE_LEN
## sanat pikseli uzunlukta, yol karenin orta satırından (BOLT_TILE_CY) girer/çıkar; kenarlarda düz kütük olduğu için yan yana dikişsiz oturur.
## Çalışma anında şimşek = bu parçaların dizilmesi (fx_matthew_bolt.gd) - kare başına/evre başına hesap yok (eskiden 400 px'lik şimşekte evre başı ~5 ms).
const BOLT_TILE_LEN := 40
const BOLT_TILE_PAD := 3 ## karenin solundaki boş pay: baş parçasındaki elde parlaması içeri taşar
const BOLT_TILE_W := BOLT_TILE_LEN + BOLT_TILE_PAD
const BOLT_TILE_H := 49
const BOLT_TILE_CY := 24
const BOLT_STAGES := 6
const BOLT_ROW_START := 0
const BOLT_START_VARIANTS := 2
const BOLT_ROW_MID := 2
const BOLT_MID_VARIANTS := 5
const BOLT_ROW_END := 7
const BOLT_END_VARIANTS := 2
const BOLT_FORK_VARIANTS: Array[int] = [0, 3] ## çatallı orta parçalar (0 yukarı, 3 aşağı)

# ---------------------------------------------------------------- E: Elektrik Topu
const BALL_DURATION := 3.0
const BALL_COOLDOWN := 20.0
const BALL_SPEED_MULT := 1.2 ## %20 TOPLAM hareket hızı
const EVO_BALL_SPEED_MULT := 1.3 ## 4. geliştirme
const BALL_DAMAGE_RATIO := 2.0 ## %200 saldırı gücü
const BALL_REHIT_INTERVAL := 0.5 ## aynı yaratığa 0,5 sn'de bir (kullanıcı seçimi)
const BALL_REACH := 10.5 ## topun DÜNYA yarıçapı (17 px x TEXEL x kök ölçeği 0,5) - buna yaratığın gövde yarıçapı eklenir
const BALL_BIG_MULT := 1.5 ## final geliştirme: top %50 büyük (görsel + temas)
const BALL_FLING_DISTANCE := 140.0 ## değdiği yaratığın fırladığı mesafe (enemy.gd apply_skill_push; boss x0,4)
const BALL_CHAIN_PUSH := 70.0 ## çarpılan ikinci yaratığın itilmesi
const BALL_CHAIN_CORRIDOR := 6.0 ## çarpışma koridoru payı (iki gövde yarıçapına eklenir)
const EVO_BALL_EXTRA_DURATION := 1.5 ## 2. geliştirme
const EVO_BALL_HEAL_RATIO := 0.05 ## 3. geliştirme: verilen hasarın %5'i
const EVO_BALL_SPEED_PER_PERCENT := 10.0 ## 1. geliştirme: her 10 hareket hızı (sayı) = +%1 hasar

# ---------------------------------------------------------------- R: Yıldırım Kalkanı
const DOME_GLOW_START := 0.02 ## kalkan bu kadar yıprandıktan sonra parıltı başlar
## PATLAMA (madde 356, kullanıcı: "ultisi patlamıyor gibi ... yaratıklara hasar vermiyor pek ... pikachunun çıldırışı gibi"): eskiden
## sabit 60 hasardı (saldırı gücüyle büyümüyordu) ve yalnız kalkan hasarla KIRILIRSA patlıyordu - %1000 SG kapasiteli kalkan çoğu
## zaman 15 sn'yi doldurup sessizce kapanıyordu. Artık süre dolunca da patlar; hasar = SG x BURST_AP_RATIO + kalkanın EMDİĞİ hasar x
## BURST_ABSORB_RATIO (emilen en çok kalkan kapasitesi kadar sayılır - "yüklenip boşalma").
const BURST_AP_RATIO := 4.0 ## %400 saldırı gücü
const BURST_ABSORB_RATIO := 0.5 ## emilen hasarın %50'si
const BURST_RADIUS := 220.0 ## dünya birimi - nova sayfasının R'si (182 sanat px x TEXEL)
const BURST_KNOCKBACK := 260.0
const BURST_MAX_BOLTS := 6 ## Matthew'dan en yakın yaratıklara çakan Q şimşeği (ağda tek tek gider - sınırlı)
const BURST_GLOW_TIME := 0.8 ## patlamada Matthew tam parlar, bu sürede söner (ağda parıltı basamağıyla gider)
const GLOW_SHADER_PATH := "res://shaders/matthew_glow.gdshader"

const SHEET_DIR := "res://assets/fx/matthew_lightning/"
## kind -> kare boyutu / sayısı / hızı. tools/gen_matthew_lightning_fx.py'nin yazdığı sayfalarla AYNI olmalı.
const SHEETS := {
	"impact": {"fw": 56, "fh": 56, "n": 5, "fps": 16.0},
	"impact_ring": {"fw": 72, "fh": 72, "n": 5, "fps": 16.0},
	"ball": {"fw": 60, "fh": 60, "n": 8, "fps": 12.0, "loop": true},
	"ball_big": {"fw": 80, "fh": 80, "n": 8, "fps": 12.0, "loop": true},
	"form_burst": {"fw": 74, "fh": 74, "n": 4, "fps": 16.0},
	"shield_loop": {"fw": 96, "fh": 96, "n": 24, "cols": 6, "fps": 12.0, "loop": true},
	"shield_pop": {"fw": 196, "fh": 196, "n": 8, "fps": 14.0},
	"nova": {"fw": 440, "fh": 440, "n": 14, "cols": 5, "fps": 18.0}, ## tools/gen_matthew_ult_burst.py (madde 356)
	"cast": {"fw": 64, "fh": 110, "n": 5, "fps": 14.0},
}
const CAST_TARGET_FROM_CENTER := Vector2(0.0, 31.0) ## cast karesinde şimşeğin indiği nokta (32, 86) - kare ortasına göre, sanat pikseli

static var _frames_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


## Efekt dokuları tembel yüklenir (yeni PNG henüz import edilmemişse betiğin derlenmesi bozulmasın; yoksa null).
static func sheet_texture(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var path: String = SHEET_DIR + kind + ".png"
	var tex: Texture2D = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
	_tex_cache[kind] = tex
	return tex


static func frames(kind: String) -> SpriteFrames:
	if _frames_cache.has(kind):
		return _frames_cache[kind]
	var cfg: Dictionary = SHEETS.get(kind, {})
	var tex: Texture2D = sheet_texture(kind) if not cfg.is_empty() else null
	if tex == null:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	sf.add_animation(&"fx")
	sf.set_animation_loop(&"fx", bool(cfg.get("loop", false)))
	sf.set_animation_speed(&"fx", float(cfg["fps"]))
	var n: int = int(cfg["n"])
	var cols: int = int(cfg.get("cols", n))
	var fw: float = float(cfg["fw"])
	var fh: float = float(cfg["fh"])
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = tex
		@warning_ignore("integer_division")
		at.region = Rect2(float(i % cols) * fw, float(i / cols) * fh, fw, fh)
		sf.add_frame(&"fx", at)
	_frames_cache[kind] = sf
	return sf


## Sayfa tabanlı AnimatedSprite2D (NEAREST). px: bir sanat pikselinin boyu - karaktere bağlı efektte TEXEL (yerel), dünyada duran
## efektte WORLD_TEXEL (bkz. baştaki ÖLÇEK notu). Sayfa yoksa null.
static func make_sprite(kind: String, px: float = TEXEL) -> AnimatedSprite2D:
	var sf: SpriteFrames = frames(kind)
	if sf == null:
		return null
	var spr := AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = sf
	spr.centered = true
	spr.scale = Vector2.ONE * px
	spr.animation = &"fx"
	return spr


# ---------------------------------------------------------------- pasif formülleri
## Hız birikimi (0..MOMENTUM_MAX): hareket ederken saniyede %1 artar, dururken MOMENTUM_DECAY_TIME'da tam bonustan sıfıra iner.
static func step_momentum(momentum: float, moving: bool, delta: float) -> float:
	if moving:
		return minf(MOMENTUM_MAX, momentum + MOMENTUM_GAIN_PER_SEC * delta)
	return maxf(0.0, momentum - (MOMENTUM_MAX / MOMENTUM_DECAY_TIME) * delta)


## Tam hızda mı (iz güçlenir). main.gd extra["mt"] ile diğer oyunculara gider.
static func is_empowered(momentum: float) -> bool:
	return momentum >= MOMENTUM_MAX - 0.0005


## İzin seviyesi: 0 yok (duruyor), 1 normal, 2 güçlenmiş (tam hız).
static func trail_level(momentum: float, moving: bool) -> int:
	if not moving:
		return 0
	return 2 if is_empowered(momentum) else 1


## Saldırı aralığı çarpanı (düşük = hızlı): TOPLAM hareket hızı bonusunun her %1'i = MOVE_TO_ATTACK_RATIO (%0,5) saldırı hızı. Silahlara yalnız TAM yüzde
## değişince yeniden uygulanır (player.gd _matthew_refresh_move_percent) - bu yüzden yüzdeye yuvarlanmış değer.
static func fire_interval_mult(move_speed_percent: int) -> float:
	return 1.0 / (1.0 + float(maxi(move_speed_percent, 0)) * MOVE_TO_ATTACK_RATIO / 100.0)


# ---------------------------------------------------------------- E formülleri
## 1. geliştirme: topun hasarı her 10 hareket hızı (sayı) başına %1 artar.
static func ball_damage_mult(move_speed: float, has_speed_evo: bool) -> float:
	if not has_speed_evo:
		return 1.0
	return 1.0 + floorf(maxf(move_speed, 0.0) / EVO_BALL_SPEED_PER_PERCENT) / 100.0


## Bilardo: from'dan dir yönünde `distance` kadar fırlayan (yarıçapı r_a) yaratığın yolundaki İLK yaratık.
## others: [[Vector2 konum, float yarıçap, Variant kimlik], ...]. Dönüş: [kimlik, yol üstündeki temas mesafesi] ya da [].
static func first_on_path(from: Vector2, dir: Vector2, distance: float, r_a: float, others: Array) -> Array:
	var best: Array = []
	var best_along: float = INF
	for o: Array in others:
		var rel: Vector2 = (o[0] as Vector2) - from
		var along: float = rel.dot(dir)
		var reach: float = r_a + float(o[1]) + BALL_CHAIN_CORRIDOR
		if along <= 0.0 or along > distance + reach:
			continue
		if absf(rel.cross(dir)) > reach:
			continue
		if along < best_along:
			best_along = along
			best = [o[2], maxf(0.0, along - reach)]
	return best


## enemy.gd apply_skill_push ile AYNI kinematik (v0 = sqrt(2 * a * mesafe), sabit yavaşlama a): `travel` kadar yolu ne kadar sürede alır.
static func push_travel_time(push_distance: float, travel: float, decay: float = 1400.0) -> float:
	if push_distance <= 0.0 or travel <= 0.0:
		return 0.0
	var v0: float = sqrt(2.0 * decay * push_distance)
	var disc: float = v0 * v0 - 2.0 * decay * minf(travel, push_distance)
	return (v0 - sqrt(maxf(disc, 0.0))) / decay


# ---------------------------------------------------------------- R formülleri
## Kalkan kırılmaya ne kadar yakın (0 dolu .. 1 kırılmak üzere).
static func glow_level(dome_hp: float, dome_max: float) -> float:
	if dome_max <= 0.0:
		return 0.0
	return clampf(1.0 - dome_hp / dome_max, 0.0, 1.0)


## Kalkan patlamasının hasarı (kritik hariç): SG x %400 + emilen hasarın %50'si.
static func burst_damage(attack_power: float, absorbed: float) -> float:
	return maxf(0.0, attack_power) * BURST_AP_RATIO + maxf(0.0, absorbed) * BURST_ABSORB_RATIO


## Patlama parıltısı (0..1): patlamadan bu yana geçen süreye göre tamdan sıfıra.
static func burst_glow_level(msec_left: int) -> float:
	return clampf(float(msec_left) / (BURST_GLOW_TIME * 1000.0), 0.0, 1.0)


## Ağ için 0..10 basamak (extra durumu her küçük değişimde yeniden gönderilmesin).
static func glow_step(level: float) -> int:
	return clampi(int(round(level * 10.0)), 0, 10)


# ---------------------------------------------------------------- ağ durumu (main.gd extra["mt"])
## [top (0 yok / 1 normal / 2 büyük), iz güçlenmiş mi (0/1), kalkan parıltı basamağı (0..10)] - hepsi SEYREK değişen alanlar
## (durum kanalı yalnız değişince gönderilir). "Hareket ediyor mu" gönderilmez: kukla kendi konum değişiminden çıkarır.
static func pack_state(ball: int, empowered: bool, glow: int) -> Array:
	return [ball, 1 if empowered else 0, glow]


## Kalkan parıltısı: karakter sprite'ına (AnimatedSprite2D) shaders/matthew_glow.gdshader'ı takar / level'ı günceller / söker.
## Sprite'ta BAŞKA bir malzeme varsa dokunmaz. Kaster ve kukla aynı çağrıyı yapar.
static func apply_glow(sprite: CanvasItem, level: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	var ours: bool = mat != null and mat.shader != null and mat.shader.resource_path == GLOW_SHADER_PATH
	if level <= DOME_GLOW_START:
		if ours:
			sprite.material = null
		return
	if not ours:
		if sprite.material != null:
			return
		var shader: Shader = (load(GLOW_SHADER_PATH) as Shader) if ResourceLoader.exists(GLOW_SHADER_PATH) else null
		if shader == null:
			return
		mat = ShaderMaterial.new()
		mat.shader = shader
		sprite.material = mat
	mat.set_shader_parameter("level", level)


# ---------------------------------------------------------------- şimşek biçimi (Q) - piksel ızgarasında
## p0 -> p1 arası sivri zikzak (sanat pikseli koordinatları): ara noktalar sırayla sağa/sola savrulur.
static func zig(rng: RandomNumberGenerator, p0: Vector2, p1: Vector2, step: float, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array([p0])
	var ln: float = p0.distance_to(p1)
	if ln < 1.0:
		pts.append(p1)
		return pts
	var u: Vector2 = (p1 - p0) / ln
	var nrm := Vector2(-u.y, u.x)
	var d: float = 0.0
	var sgn: float = 1.0 if rng.randf() < 0.5 else -1.0
	while true:
		d += step * rng.randf_range(0.6, 1.4)
		if d >= ln - step * 0.5:
			break
		pts.append(p0 + u * d + nrm * (sgn * jag * rng.randf_range(0.45, 1.0)))
		sgn = -sgn
	pts.append(p1)
	return pts


## Kırık çizginin sıralı hücre listesi (Bresenham, 8-bağlı, tekrar yok).
static func cells_of(pts: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(pts.size() - 1):
		var x0: int = int(floor(pts[i].x))
		var y0: int = int(floor(pts[i].y))
		var x1: int = int(floor(pts[i + 1].x))
		var y1: int = int(floor(pts[i + 1].y))
		var dx: int = absi(x1 - x0)
		var dy: int = -absi(y1 - y0)
		var sx: int = 1 if x0 < x1 else -1
		var sy: int = 1 if y0 < y1 else -1
		var err: int = dx + dy
		while true:
			var c := Vector2i(x0, y0)
			if out.is_empty() or out[out.size() - 1] != c:
				out.append(c)
			if x0 == x1 and y0 == y1:
				break
			var e2: int = 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy
	return out


## Parçalanma süzgeci: thr büyüdükçe çizgi boyunca daha çok (bitişik) hücre düşer.
static func dash_keep(i: int, thr: float, salt: float) -> bool:
	return 0.5 + 0.25 * sin(float(i) * 0.61 + salt * 1.7) + 0.25 * sin(float(i) * 0.23 + salt * 2.7 + 1.0) >= thr


const _N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _N12: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Renk indeksleri: 0 kontur (koyu), 1 altın kenar, 2 orta, 3 açık, 4 parlak (krem).
const PALETTE: Array[Color] = [Color8(92, 54, 8), Color8(204, 136, 20), Color8(250, 208, 52), Color8(255, 240, 140), Color8(255, 255, 232)]


## Bir şimşeği hücre sözlüğüne (Vector2i -> palet indeksi) basar. w: 1/3/5 px; uçlarda taper hücre boyunca incelir.
## keep_thr > 0: parçalanma (dash_keep). outl: dış kontur (ince kollarda altın, kalınlarda koyu) - dolu hücrelerin üstüne yazmaz.
static func stamp_bolt(cells: Dictionary, pix: Array[Vector2i], w: int, taper: int, core_idx: int = 4, outl: bool = true, keep_thr: float = 0.0, salt: float = 0.0) -> void:
	var n: int = pix.size()
	var body: Dictionary = {}
	for i in range(n):
		if keep_thr > 0.0 and not dash_keep(i, keep_thr, salt):
			continue
		var c: Vector2i = pix[i]
		body[c] = core_idx
		if w >= 3 and i >= taper and i < n - taper:
			var wide: bool = w >= 5 and i >= 2 * taper and i < n - 2 * taper
			for o: Vector2i in (_N12 if wide else _N4):
				var q: Vector2i = c + o
				## 5 px şimşek: çekirdeğe komşu hücre açık ton, en dış halka orta ton; 3 px şimşek: orta ton.
				var tone: int = 3 if (w >= 5 and absi(o.x) + absi(o.y) == 1) else 2
				if not body.has(q) or int(body[q]) < tone:
					body[q] = tone
	## çekirdek hücreler en son (genişletme onları ezmesin)
	for i in range(n):
		if keep_thr > 0.0 and not dash_keep(i, keep_thr, salt):
			continue
		body[pix[i]] = core_idx
	if outl:
		var edge: int = 0 if w >= 3 else 1
		for c: Vector2i in body:
			for o: Vector2i in _N4:
				var q: Vector2i = c + o
				if not body.has(q) and not cells.has(q):
					cells[q] = edge
	for c: Vector2i in body:
		cells[c] = body[c]
