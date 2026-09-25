extends RefCounted

## Suriyeli Hadime (roster id 14) - player.gd (yetkili/gerçek oyuncu), remote_player.gd (diğer istemcilerdeki kozmetik
## kopya) ve network_manager.gd ("hadime_fx" dalı) tarafından PAYLAŞILAN sabitler, formüller ve görsel yardımcılar.
##
## KÖK NEDEN NOTU (CLAUDE.md "yeni yetenek eklerken eskisi kalıyor" hata sınıfı, madde 3): lanetin uçuş eğrisi, kanal
## sırasında havaya süzülme miktarı, Karabasan/hayalet görünümü (shader) ve ceset HER istemcide AYNI formülle yerel
## hesaplanır - ağdan kare kare konum gelmez. İki dosyaya ayrı ayrı yazılsa biri değişince diğer oyuncular farklı
## görürdü; bu yüzden hepsi BURADAKİ static fonksiyonları çağırır.
##
## Tasarım (kullanıcı isteği 2026-09-25, "hadime yetenekleri.txt" + soru-cevap):
##  Q Lanet Kitabı (id 46) : AÇ/KAPA kanal (ilk tasarımda basılı tutuluyordu; kullanıcı: "basınca açılıp tekrar basınca
##                           kapansın") - read klibi, hafifçe havaya süzülür (birimlerin içinden geçer, ayak altında
##                           karanlık uçma parçacıkları - fx_hadime_levitate.tscn), %30 yavaş yürür; saniyede 1 lanet
##                           kitaptan yukarı fırlayıp etraftaki yaratıklara (sırayla, en uzun süredir lanetlenmemişe) düşer,
##                           %110 saldırı gücü. Her saniye temel yetenek kalkan bedelinin YARISI (kullanıcı düzeltmesi).
##                           Tekrar basınca (açıldıktan 1 sn sonra - spam koruması) / kalkan yetmeyince 8 sn bekleme.
##  E Kara Delik (id 47)   : (2026-09-25 ikinci istek - ilk tasarım "Kara Büyü" tamamen kaldırıldı) bulunduğu yere 5 sn süren
##                           bir kara delik bırakır: yakındaki yaratıkları hafifçe içine çeker, her saniye %80 saldırı gücü
##                           hasar verir, verdiği hasarın %20'si kadar Hadime'nin kalkanını yeniler (kalkan çekme efekti YOK -
##                           kullanıcı). 18 sn bekleme (5 sn aktif süreden sonra başlar). Q basılıyken de kullanılabilir.
##  R Karabasan (id 48)    : 15 sn karanlık form - yakına gelen her yaratık 1 sn korkar, yakındakiler saniyede %80 saldırı
##                           gücü hasar alır. 100 sn bekleme.
##  Pasif Ruh Göçü         : yere düşünce (downed) 2 sn sonra ölüm klibinin TERSİYLE yarı saydam hayalet olarak kalkar,
##                           ceset yerde kalır; sadece yetenekleriyle savaşır (%80 az hasar), hiçbir şey toplayamaz,
##                           diriltemez, silah kullanamaz, dükkan/görevle etkileşemez, yaratıklar onu görmezden gelir.
##                           Arkadaşları CESEDİ diriltince bedenine döner; tek oyunculuda 20 sn sonra kendiliğinden döner.

const CHAR_ID := 14
const Q_SKILL_ID := 46
const E_SKILL_ID := 47
const R_SKILL_ID := 48

## 1 sanat pikseli = bu kadar birim (projedeki FX dili, bkz. PixelDraw.TEXEL). DİKKAT: Player/RemotePlayer kökü 0.5 ölçekli
## (main.tscn / remote_player.tscn) - karakterin ÇOCUĞU olan efektlerde bu yerel birimdir, sahneye (dünyaya) eklenenlerde
## dünya birimidir. Karakterin yerel birimindeki ofsetler dünyaya to_global() ile çevrilir.
const TEXEL := 1.212
## Karakter dokusunun 1 sanat pikseli, karakterin YEREL biriminde (DEFS scale 2.2368375 x EntityScale 0.95).
const CHAR_TEXEL := 2.125

## ---------- Q: Lanet Kitabı ----------
const Q_TARGET_RADIUS := 320.0
const Q_CURSE_INTERVAL := 1.0
## Kanal başladıktan sonra ilk lanet bu kadar sonra (kitap açılır açılmaz bir lanet görünsün).
const Q_FIRST_CURSE_DELAY := 0.3
const Q_DAMAGE_RATIO := 1.1
## Kullanıcı düzeltmesi (2026-09-25): "Q su temel skillerin kalkan bedelinin yarısı kadar harcasın" - saniyelik bedel.
const Q_COST_RATIO := 0.5
const Q_COOLDOWN := 8.0
const Q_MOVE_MULT := 0.7
## Havaya süzülme: karakter sanat pikseli cinsinden (tam sayı -> piksel ızgarası bozulmaz), yavaş bir iniş-çıkış.
const Q_LIFT_ART_PX := 3.0
const Q_LIFT_BOB_ART_PX := 1.0
const Q_LIFT_BOB_SPEED := 2.4
## Lanetin uçuşu: kitaptan yukarı yükselir (RISE), tepede asılır gibi yavaşlar, hedefe düşer (FALL).
const CURSE_RISE_TIME := 0.38
const CURSE_FALL_TIME := 0.3
## Dünya birimi (karakter ~40 birim boyunda) - lanet başının biraz üstüne kadar yükselir.
const CURSE_APEX_HEIGHT := 48.0
## Kanal sırasında klip: read_<yön>. Kitabın (lanetin çıktığı yer) karakter kökünden YEREL ofseti, yöne göre (read.png) -
## dünyaya çağıran taraf to_global() ile çevirir (kök ölçeği 0.5).
const BOOK_OFFSETS := {
	"down": Vector2(0, -2), "up": Vector2(0, -6), "left": Vector2(-11, 0), "right": Vector2(11, 0),
}

## ---------- E: Kara Delik (dünya birimleri) ----------
const HOLE_DURATION := 5.0
const HOLE_COOLDOWN := 18.0
## Çekim/hasar yarıçapı - sayfadaki içe akan zerrelerin başladığı halkayla aynı büyüklük (gen_hadime_fx.py black_hole).
const HOLE_RADIUS := 110.0
const HOLE_DAMAGE_RATIO := 0.8
const HOLE_SHIELD_RATIO := 0.2
const HOLE_TICK := 1.0
## İlk hasar tiki (sonra her HOLE_TICK sn) - 5 sn içinde 5 tik: 0.5, 1.5, 2.5, 3.5, 4.5.
const HOLE_FIRST_TICK := 0.5
## "Hafifçe içine doğru çeker": sabit, yavaş kayma (dünya birimi/sn) - yürüyen yaratık uzaklaşabilir ama zorlanır.
## Merkeze bu kadar yaklaşan yaratık artık çekilmez (üst üste yığılıp titremesin). Bosslar çekilmez (diğer kontrol
## etkilerindeki gibi bağışık).
const HOLE_PULL_SPEED := 38.0
const HOLE_PULL_DEADZONE := 10.0
## Karakter kökünden (yerel) ayak altı - kara delik buraya bırakılır.
const HOLE_FEET_LOCAL := Vector2(0, 30)

## ---------- R: Karabasan ----------
const R_DURATION := 15.0
const R_COOLDOWN := 100.0
const R_RADIUS := 130.0
const R_FEAR_TIME := 1.0
const R_DAMAGE_RATIO := 0.8
const R_TICK := 1.0
## Korku kontrolü aralığı (sn) - yaklaşan yaratık en geç bu kadar gecikmeyle korkar.
const R_FEAR_SCAN := 0.15
const R_SCALE_MULT := 1.15

## ---------- Pasif: Ruh Göçü (hayalet) ----------
const GHOST_RISE_DELAY := 2.0
## ghostrise_<yön> klibi (ölüm klibinin tersi, 3 kare / 5 fps) sürerken yürünmez.
const GHOST_RISE_LOCK := 0.62
const GHOST_DAMAGE_MULT := 0.2
## Kullanıcı seçimi: tek oyunculuda hayalet 20 sn savaşır, sonra kendiliğinden bedenine döner (can hakkı harcanır).
const GHOST_SP_TIME := 20.0
## "Hayalet formu Hadime'nin kendisi, sadece yarı saydam hali" (kullanıcı) - renk tonu/ek efekt YOK.
const GHOST_ALPHA := 0.5

const GHOST_RISE_PREFIX := "ghostrise_"

## Sahneler preload DEĞİL, ilk kullanımda yüklenip önbellekte tutulur: FX script'leri de bu dosyayı preload ediyor
## (döngüsel preload olmasın). Önbellek referansı tuttuğu için load() her seferinde diskten okumaz.
const FX_CURSE := "res://scenes/fx_hadime_curse.tscn"
const FX_BLACK_HOLE := "res://scenes/fx_hadime_black_hole.tscn"
const FX_NIGHTMARE_AURA := "res://scenes/fx_hadime_nightmare.tscn"
const FX_LEVITATE := "res://scenes/fx_hadime_levitate.tscn"
static var _scene_cache: Dictionary = {}


static func scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

const AURA_NODE := "HadimeNightmareAura"
const LEVITATE_NODE := "HadimeLevitate"
const CORPSE_NODE := "HadimeCorpse"


static func is_hadime(char_id: int) -> bool:
	return char_id == CHAR_ID


## Karakterin YEREL biriminde (dünyaya: host.to_global(book_offset(...))).
static func book_offset(facing: String, lift_px: float) -> Vector2:
	return Vector2(BOOK_OFFSETS.get(facing, Vector2(0, -2))) + Vector2(0, -lift_px * CHAR_TEXEL)


## Kanal sırasında süzülme (karakter sanat pikseli, tam sayı). t = kanal başlangıcından beri geçen süre.
static func channel_lift(t: float) -> float:
	return Q_LIFT_ART_PX + roundf(sin(t * Q_LIFT_BOB_SPEED) * Q_LIFT_BOB_ART_PX)


## Lanetin t anındaki dünya konumu (from = kitap, to = hedefin O ANKİ konumu). Toplam süre = RISE + FALL.
## Yükselirken hedef yönüne biraz kayar (tek tek farklı yaratıklara gittiği okunsun), sonra hızlanarak düşer.
static func curse_position(from: Vector2, to: Vector2, t: float) -> Vector2:
	var apex: Vector2 = from + (to - from) * 0.22 + Vector2(0, -CURSE_APEX_HEIGHT)
	if t <= CURSE_RISE_TIME:
		var u: float = t / CURSE_RISE_TIME
		var e: float = 1.0 - (1.0 - u) * (1.0 - u)
		return from.lerp(apex, e)
	var v: float = clampf((t - CURSE_RISE_TIME) / CURSE_FALL_TIME, 0.0, 1.0)
	## Yatayda doğrusal, dikeyde karesel (yerçekimi gibi hızlanan düşüş).
	return Vector2(lerpf(apex.x, to.x, v), lerpf(apex.y, to.y, v * v))


static func curse_total_time() -> float:
	return CURSE_RISE_TIME + CURSE_FALL_TIME


## Yaratığın gövde ortası (lanet buraya düşer, mühür burada belirir) - kök ayak hizasına yakın.
static func enemy_hit_point(e: Node2D) -> Vector2:
	return e.global_position + Vector2(0, -8)


## ---------- Görünüm: Karabasan (koyu siluet + parlayan yeşil gözler) / hayalet (yarı saydam) ----------
## Tek shader, iki bağımsız ağırlık. Renk tonu modulate YERİNE shader'da: main.gd "modulate"ı diğer oyunculara KÖK
## düğüme uygulatıyor (isim/silah da soluklaşırdı) - shader ise her istemcide aynı bayraklardan yerel kurulur.
const FORM_SHADER_CODE := """shader_type canvas_item;
uniform float nightmare : hint_range(0.0, 1.0) = 0.0;
uniform float ghost_alpha : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Hadime'nin yeşil gözleri (g > 0.3, r ve b'den belirgin baskın) - çizmeler koyu yeşil, eşik altında kalır.
	float eye = step(0.3, c.g) * step(c.r * 1.4, c.g) * step(c.b, 0.12);
	vec3 dark = mix(vec3(0.05, 0.03, 0.08), vec3(0.22, 0.11, 0.30), lum);
	vec3 nm = mix(dark, vec3(0.55, 1.0, 0.35), eye);
	c.rgb = mix(c.rgb, nm, nightmare);
	c.a *= ghost_alpha;
	COLOR = c;
}
"""
static var _form_shader: Shader = null


static func _shader() -> Shader:
	if _form_shader == null:
		_form_shader = Shader.new()
		_form_shader.code = FORM_SHADER_CODE
	return _form_shader


## Karakter sprite'ına form görünümünü uygular (ikisi de kapalıysa materyali kaldırır - normal çizim, ek maliyet yok).
## Materyal düğüm başına bir kez oluşturulup meta'da tutulur.
static func apply_form(anim: CanvasItem, nightmare: bool, ghost: bool) -> void:
	if anim == null or not is_instance_valid(anim):
		return
	if not nightmare and not ghost:
		if anim.material != null and anim.has_meta("hadime_form_mat"):
			anim.material = null
		return
	var mat: ShaderMaterial = anim.get_meta("hadime_form_mat", null)
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = _shader()
		anim.set_meta("hadime_form_mat", mat)
	if anim.material != mat:
		anim.material = mat
	mat.set_shader_parameter("nightmare", 1.0 if nightmare else 0.0)
	mat.set_shader_parameter("ghost_alpha", GHOST_ALPHA if ghost else 1.0)


## Karakter altı döngü efekti (fx_hadime_ground_loop.gd) - host: Player ya da RemotePlayer. Açık/kapalı idempotent;
## kapatırken solarak kaybolur (bu sırada yeniden açılırsa yeni bir kopya kurulur).
static func set_loop_fx(host: Node, node_name: String, scene_path: String, on: bool) -> void:
	var fx: Node = host.get_node_or_null(node_name)
	if on:
		if fx == null or fx.is_queued_for_deletion():
			if fx != null:
				fx.name = node_name + "_old"
			fx = scene(scene_path).instantiate()
			fx.name = node_name
			host.add_child(fx)
	elif fx != null and not fx.is_queued_for_deletion():
		fx.name = node_name + "_old" ## solarken aynı adla yeni bir kopya kurulabilsin
		if fx.has_method("stop"):
			fx.call("stop")
		else:
			fx.queue_free()


## R Karabasan: ayak altında karanlık aura.
static func set_nightmare_aura(host: Node, on: bool) -> void:
	set_loop_fx(host, AURA_NODE, FX_NIGHTMARE_AURA, on)


## Q Lanet Kitabı: havaya süzülürken ayak altında karanlık uçma parçacıkları (kullanıcı isteği 2026-09-25).
static func set_levitate_fx(host: Node, on: bool) -> void:
	set_loop_fx(host, LEVITATE_NODE, FX_LEVITATE, on)


## Ceset: ölüm klibinin SON karesinde donmuş, dünya konumunda sabit bir kopya. Sahibinin ÇOCUĞU ama top_level (sahip -
## hayalet - yürüdükçe ceset yerinde kalır; sahip silinince o da gider) ve show_behind_parent (hayalet önünde çizilir).
static func spawn_corpse(host: Node2D, source_anim: AnimatedSprite2D, clip: String, world_pos: Vector2) -> Node2D:
	remove_corpse(host)
	var corpse := Node2D.new()
	corpse.name = CORPSE_NODE
	corpse.top_level = true
	corpse.show_behind_parent = true
	host.add_child(corpse)
	## BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-25: "hadime ölünce ölü bedeni normalden daha büyük gözüküyor"):
	## top_level düğüm sahibinin ölçeğini MİRAS ALMAZ - Player/RemotePlayer kökü 0.5 ölçekli (main.tscn/remote_player.
	## tscn), ceset sprite'ı ölçeği karakterinkiyle aynı kopyalandığı için 2 kat büyük çıkıyordu (üstüne taşınan ölüm/
	## diriltme efektleri de). Sahibin DÜNYA ölçeği cesedin kendi ölçeği olarak verilir.
	corpse.scale = host.global_scale
	corpse.global_position = world_pos
	var spr := AnimatedSprite2D.new()
	spr.name = "Body"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = source_anim.sprite_frames
	spr.scale = source_anim.scale
	spr.offset = source_anim.offset
	spr.position = source_anim.position
	corpse.add_child(spr)
	if spr.sprite_frames and spr.sprite_frames.has_animation(clip):
		spr.animation = clip
		spr.frame = maxi(0, spr.sprite_frames.get_frame_count(clip) - 1)
		spr.pause()
	return corpse


static func get_corpse(host: Node) -> Node2D:
	var c: Node = host.get_node_or_null(CORPSE_NODE)
	if c != null and not c.is_queued_for_deletion():
		return c as Node2D
	return null


static func remove_corpse(host: Node) -> void:
	var c: Node = host.get_node_or_null(CORPSE_NODE)
	if c != null:
		## Ceset üstüne taşınmış ölüm/diriltme efektleri (bkz. player.gd _death_fx_parent) cesetle birlikte gitmesin -
		## sahibine geri döner (sahibi artık cesedin yerinde).
		for child in c.get_children():
			if child.name != "Body":
				child.reparent(host, false)
		c.name = CORPSE_NODE + "_old"
		c.queue_free()


## ---------- Dünya efektleri (yerel oyuncu VE network_manager.gd "hadime_fx" dalı aynı fonksiyonu çağırır) ----------
## kind:
##  "curse" : opts from (Vector2 kitap), to (Vector2 hedef), target (Node2D, isteğe bağlı - uçarken takip edilir),
##            on_land (Callable, SADECE yetkili kopyada - hasar) -> fx_hadime_curse.tscn
static func spawn_fx(root: Node, kind: String, opts: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return
	match kind:
		"curse":
			var fx: Node2D = scene(FX_CURSE).instantiate() as Node2D
			root.add_child(fx)
			fx.call("setup", Vector2(opts.get("from", Vector2.ZERO)), Vector2(opts.get("to", Vector2.ZERO)),
					opts.get("target", null), opts.get("on_land", Callable()))


## E Kara Delik: dünya konumunda (ayak altı) 5 sn duran kara delik (fx_hadime_black_hole.tscn, hadime_black_hole.gd).
##  authoritative: kasterin kendi kopyası - her HOLE_TICK'te on_tick(merkez) çağırır (hasar + kalkan player.gd'de).
##  pull_authority: yaratıkları çeken kopya - yaratıklar HOST'ta simüle edildiği için sadece host'taki kopya (kaster host
##                  ise kendi kopyası, değilse network_manager.gd broadcast_hadime_black_hole'un host'ta açtığı kopya).
static func spawn_black_hole(root: Node, world_pos: Vector2, authoritative: bool, pull_authority: bool, on_tick: Callable) -> Node2D:
	if root == null or not is_instance_valid(root):
		return null
	var hole: Node2D = scene(FX_BLACK_HOLE).instantiate() as Node2D
	hole.set("authoritative", authoritative)
	hole.set("pull_authority", pull_authority)
	hole.set("on_tick", on_tick)
	root.add_child(hole)
	hole.global_position = world_pos
	return hole
