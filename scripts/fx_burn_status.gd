extends Node2D

## Yaratıklar yanarken (Shaman pasifi/Totem Auraları, ateşli silahlar v.s -
## bkz. enemy.gd apply_burn/_spawn_burn_status_fx) gövdelerinde beliren efekt.
##
## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Ateş özel klasörü): eskiden
## TEK bir sabit alev animasyonu vardı (fx_burn_flames.png, 6 kare, tek
## katman). Artık 4 ateş + 3 duman varyantından rastgele biri seçilip İKİ
## KATMAN olarak gösteriliyor. Kullanıcı isteği: "layer sıralamaları düşman
## bedeni-duman-ateş olacak" - duman ARKADA (düşük z_index), ateş ÖNDE
## (yüksek z_index); "duman efekti yukarıya doğru gidecek uzunluğu fazla
## olduğu için" - duman kendi kare boyu (96-128px) ateşinkinden fazla
## olduğu için alt kenarları hizalanınca doğal olarak ateşin üstüne taşıyor
## (bkz. _ready() sonundaki hizalama - doku boyutunu HER ZAMAN runtime'da
## okur, aşağıdaki değişiklikten etkilenmedi).
##
## DÜZELTME (kullanıcı isteği: "yeni ateş efektinin sprite-sheeti oyundaki
## ateş efektleri yerine eklenecek, duman aynı mantıkla arkasında duracak ve
## aynı çalışacak") - eski 4 rastgele varyant (a/b/c/d, 14'er kare, ayrı
## PNG dosyaları) TEK bir yeni 9 kareli sprite sheet (fx_burn_fire_v2.png,
## 3x3 atlas) ile değiştirildi. Duman tarafı (SMOKE_VARIANTS, konumlama,
## z_index, opaklık) HİÇ dokunulmadı - istek zaten "aynı çalışacak" diyordu.
## Eski a/b/c/d dosyaları silinmedi (kullanılmıyor ama zararsız duruyorlar,
## proje genelinde silme konusunda temkinli davranılıyor).
## GÜNCELLEME (kullanıcı isteği 2026-09-24: "yakma efektini daha minimal pixel tarzda 48x48 ve göz yormayacak şekilde
## değiştir ancak dumana dokunma" + "spritesheete dönüştür") - ateş artık tools/gen_burn_fire_fx.py'nin pişirdiği 48x48
## pixel-art alev (4 yumuşak ton, beyaz-sıcak parlama yok, kareler arası parlaklık sabit, 8 kare / 8 fps sakin döngü).
## Eski fx_burn_fire_v2 (119x124 yumuşak/parlak) dosyaları kullanılmıyor. DUMAN (SMOKE_VARIANTS ve tüm ayarları) aynen.
## GERİ ALINDI (kullanıcı isteği 2026-09-24, aynı gün: "yanma efektini değiştirmeni istemiştim beğenmedim yenisini eski
## haline döndür") - ateş yine fx_burn_fire_v2 (FIRE_ONLY_SCALE 0.5 ile). Minimal sürüm (assets/fx/burn/fire_min_*,
## tools/gen_burn_fire_fx.py) dosyaları duruyor ama kullanılmıyor.
## GÜNCELLEME (madde 551, 2026-11-10; kullanıcı Ateş Asası prototiplerinden C'nin yer alevini ekran görüntüsüyle gösterdi: "D yi oyuna al, C deki
## yerdeki ateşler de yaratıkların yanarkenki çıkardığı ateş efekti ile değiştir (sadece 1 tane yer ateşi yeterli)" + "yanmadan kastım ... prototipin
## C yer ateşi parçalarından biriydi bunlar değil"): ATEŞ katmanı artık o YER ALEVİ - tek küçük alev, yaratığın AYAK DİBİNDE (görünen bedenin
## alt-ortası, `_place_flame`), karakter pikselinde (yaratık/efekt ölçeği ne olursa olsun 1 sanat px = FLAME_WORLD_PX dünya birimi), parlatma yok
## (renkler Ateş Asası damlalarıyla aynı palet). Önce 2 karelik tutuşma ("ignite"), sonra 5 karelik döngü ("burn"). Sayfa: tools/gen_yer_alevi_fx.py.
## DUMAN aynen: konumu / ölçeği / opaklığı bugünkü gibi (hizası eski ateş karesinin boyundan, OLD_FIRE_FRAME_H). fx_burn_fire_v2 dosyaları duruyor, kullanılmıyor.
## GÜNCELLEME (2026-11-13, kullanıcı yeni yanma GIF'i gönderdi, "rotasyonu bozuk, yanma efekti dikey olmalı"): ateş katmanı artık
## tools/fx_kaynak/yanma_alevi_yan.gif'in saat yönünde 90 derece döndürülmüş hali (tools/gen_gif_fire_fx.py -> yanma_gif_*; 13x28 kare,
## 10 kare / 60 ms). Yer alevi (yer_alevi_*) dosyaları duruyor, kullanılmıyor. Konum / piksel ölçeği / duman aynen.
const FIRE_FRAMES := preload("res://assets/fx/burn/yanma_gif_frames.tres")
const IceFreeze := preload("res://scripts/fx_ice_freeze_status.gd") ## body_rect: yaratığın görünen bedeni (sprite satırının opak sınırı)
const FLAME_WORLD_PX := 0.903
const FLAME_ANCHOR_OFFSET := Vector2(0.0, -14.0) ## kare 13x28, tutunma noktası taban ortası -> ortalı sprite ofseti
const FLAME_FOOT_LIFT := 2.0 ## dünya birimi: alevin tabanı bedenin en alt pikselinin (sprite'a gömülü gölge) bu kadar üstünde
const FLAME_FALLBACK_FOOT := Vector2(0.0, 10.0) ## beden okunamazsa (headless / dokusuz) yaratık yerelinde ayak noktası
const OLD_FIRE_FRAME_H := 124.0 ## eski fx_burn_fire_v2 karesinin boyu - duman tabanı buna göre hizalı kalır
const SMOKE_VARIANTS := [
	preload("res://assets/generated/fx_burn_smoke_a_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_b_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_c_frames.tres"),
]

## DÜZELTME (kullanıcı isteği: "yangının opaklığı %100 de kalsın duman
## aynı kalsın ama opaklık olarak") - ateş tekrar tam opak, duman %30'da
## kalıyor (önceki "ikisi de indir" isteğinin ateş kısmı geri alındı).
## NOT (kullanıcı isteği: "ateş efektini %15 opaklaştır") - FIRE_OPACITY
## zaten 1.0 (tam opak, alfa'nın ulaşabileceği MATEMATİKSEL tavan) - %15 daha
## opaklaştırmak sayısal olarak mümkün değil, bu yüzden buraya dokunulmadı
## (bkz. sohbet - kullanıcıya bu sınır ayrıca açıklandı).
const FIRE_OPACITY := 1.0
const FIRE_BRIGHTNESS := 1.2
## DÜZELTME (kullanıcı isteği: "dumanı ... %10 daha opaklaştır") - 0.3 * 1.1.
const SMOKE_OPACITY := 0.33

## DÜZELTME (kullanıcı isteği: "yanma efektini dumanla beraber %10 küçült",
## sonra "yangını efekti %10 daha küçült dumanı da") - ateş VE duman
## birlikte, aynı oranda küçülsün diye kök Node2D'ye uygulanıyor (alt kenar
## hizalaması _ready() sonunda doku piksel boyutlarından hesaplandığı için
## bu ölçeklemeden etkilenmiyor, orantı korunuyor). İki ardışık %10 küçültme
## kümülatif: 0.9 * 0.9 = 0.81.
## 2026-09-25: "yanma efektinin boyutunu %10 küçült" - 0.81 -> 0.729.
const EFFECT_SCALE := 0.729

## DÜZELTME (kullanıcı isteği: "yangın ve dumanı biraz yukarı taşı") - kök
## Node2D'nin Y konumu (enemy.gd tarafında hep Vector2.ZERO'ya sabitlenen
## position'ın ÜZERİNE, kendi negatif Y'siyle) - ikisini BİRLİKTE (aralarındaki
## alt-kenar hizalamasını bozmadan) yukarı kaydırır.
const VERTICAL_OFFSET := -12.0

## DÜZELTME (kullanıcı isteği: "Ateş efektini %50 azalt") - SADECE ateş
## sprite'ı için, kök Node2D'nin EFFECT_SCALE'i (duman DAHİL ikisini birlikte
## küçülten) yerine _fire'ın KENDİ yerel ölçeği - kullanıcı bu sefer SADECE
## "ateş"i belirtti, duman önceki isteklerde olduğu gibi ayrı tutuldu.
## (Minimal 48x48 ateş denemesinde 1.212 idi - geri alındı, bkz. FIRE_VARIANTS notu.)
const FIRE_ONLY_SCALE := 0.5
## DÜZELTME (kullanıcı isteği: "dumanı %10 küçült") - FIRE_ONLY_SCALE ile
## AYNI desen, SADECE duman için kendi yerel ölçeği.
const SMOKE_ONLY_SCALE := 0.9

@onready var _smoke: AnimatedSprite2D = $Smoke
@onready var _fire: AnimatedSprite2D = $Fire

## KALABALIK SINIRI (madde 426, kullanıcı: "savaşta aşırı göz yorucu ve karmaşık"; Ateş Asası kalabalıkta ~30 yanan yaratık = ~30 alev): ekranda AYNI ANDA
## en çok AllyFxDensity.burn_flame_cap() alev gösterilir (Tam = sınırsız, Azaltılmış 12, Minimal 6); en yakın yanan yaratıklar kamera merkezine göre,
## sınırı aşanda yalnız DUMAN kalır. Yalnız çizim: yanma hasarı/durumu aynen sürer; alev ve duman sanatı/opaklığı DEĞİŞMEDİ (kullanıcı onaylı).
const AllyFxDensity := preload("res://scripts/ally_fx_density.gd")
const BURN_GROUP := &"burn_status_fx"
const BUDGET_EVERY := 0.25 ## her yaratık kendi kararını bu aralıkla verir (rastgele fazlı)
const RANK_STALE_MSEC := 200 ## sıralama bu süreden eskiyse ilk soran yeniler (tüm yaratıklar tek sıralamayı paylaşır)
const KEEP_BONUS := 0.85 ## alevi zaten açık olanın uzaklığı bununla çarpılır: sınırdaki iki yaratık arasında yanıp sönme olmasın
static var _rank_msec: int = -1000000
static var _flames_ok: Dictionary = {} ## instance_id -> true (alev gösterilecekler)
var _timer: Timer = null
var _flame_on: bool = true


## Testler: paylaşılan sıralamayı sıfırla.
static func reset_rank() -> void:
	_rank_msec = -1000000
	_flames_ok.clear()


static func _rank(tree: SceneTree, cap: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _rank_msec < RANK_STALE_MSEC:
		return
	_rank_msec = now
	_flames_ok.clear()
	var cam: Camera2D = tree.root.get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	var arr: Array = []
	for n: Node in tree.get_nodes_in_group(BURN_GROUP):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d: float = (n as Node2D).global_position.distance_to(center)
		if bool(n.get("_flame_on")):
			d *= KEEP_BONUS
		arr.append([d, n.get_instance_id()])
	arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in mini(cap, arr.size()):
		_flames_ok[int(arr[i][1])] = true


## Kare başı _process yerine Timer (FPS: yüzlerce yanan yaratıkta saniyede 60 yerine 4 çağrı).
func _budget_tick() -> void:
	if _timer != null:
		_timer.wait_time = BUDGET_EVERY ## ilk (rastgele fazlı) turdan sonra düzenli aralık
	var cap: int = AllyFxDensity.burn_flame_cap()
	var on: bool = true
	if cap > 0 and is_inside_tree():
		_rank(get_tree(), cap)
		on = _flames_ok.has(get_instance_id())
	if on != _flame_on:
		_flame_on = on
		_fire.visible = on
		if on:
			_fire.play("burn")
		else:
			_fire.pause()


func _ready() -> void:
	add_to_group(BURN_GROUP)
	_timer = Timer.new()
	_timer.wait_time = BUDGET_EVERY
	_timer.timeout.connect(_budget_tick)
	add_child(_timer)
	_timer.start(randf_range(0.02, BUDGET_EVERY)) ## yaratıklar aynı karede karar vermesin
	position = Vector2(0.0, VERTICAL_OFFSET)
	scale = Vector2(EFFECT_SCALE, EFFECT_SCALE)

	_smoke.sprite_frames = SMOKE_VARIANTS[randi() % SMOKE_VARIANTS.size()]
	_smoke.modulate.a = SMOKE_OPACITY
	_smoke.play("burn")
	## Yer alevi (madde 551): parlatma / ölçek çarpanı yok - sayfa oyundaki boyda çizildi (FIRE_BRIGHTNESS / FIRE_ONLY_SCALE artık yalnız eski ateşin kaydı).
	_fire.sprite_frames = FIRE_FRAMES
	_fire.modulate = Color.WHITE
	_fire.offset = FLAME_ANCHOR_OFFSET
	_fire.animation_finished.connect(_on_fire_anim_finished)
	_fire.play("ignite")
	_place_flame()
	_smoke.scale = Vector2(SMOKE_ONLY_SCALE, SMOKE_ONLY_SCALE)

	## Alt kenarları hizala (ikisi de centered=true varsayılanıyla merkezden
	## çizilir) - duman böylece ateşin TABANINDAN yükselip onu geride/üstte
	## kalacak şekilde sarar, konumu yanlışsa yaratığın dışında/içinde kalırdı.
	## fire_h/smoke_h artık kendi yerel ölçekleriyle (FIRE_ONLY_SCALE/
	## SMOKE_ONLY_SCALE) çarpılıyor - ikisinin KÜÇÜLMÜŞ gerçek render
	## yüksekliğine göre hizalanmazsa taban hizası bozulurdu.
	## Madde 551: ateş artık ayak dibindeki küçük alev, duman ise ESKİ yerinde kalsın diye hiza eski ateş karesinin boyundan hesaplanır.
	var smoke_tex: Texture2D = _smoke.sprite_frames.get_frame_texture("burn", 0)
	if smoke_tex:
		var smoke_h: float = smoke_tex.get_size().y * SMOKE_ONLY_SCALE
		var fire_h: float = OLD_FIRE_FRAME_H * FIRE_ONLY_SCALE
		_smoke.position.y = (fire_h - smoke_h) * 0.5


func _on_fire_anim_finished() -> void:
	if _fire.animation == &"ignite" and _flame_on:
		_fire.play("burn")


## Alevi yaratığın ayak dibine koyar ve dünya pikselini sabitler. Kök (konum VERTICAL_OFFSET, ölçek EFFECT_SCALE) dumanla ortak olduğu için
## alevin yerel konumu/ölçeği kökün dönüşümünü geri alır: hedef yaratık yerelinde, boy dünya biriminde.
func _place_flame() -> void:
	var gs: Vector2 = global_scale
	_fire.scale = Vector2(FLAME_WORLD_PX / maxf(absf(gs.x), 0.001), FLAME_WORLD_PX / maxf(absf(gs.y), 0.001))
	var host: Node2D = get_parent() as Node2D
	var foot: Vector2 = FLAME_FALLBACK_FOOT
	if host != null:
		var body: Rect2 = IceFreeze.body_rect(host)
		if body.size.x > 1.0 and body.size.y > 1.0:
			foot = Vector2(body.get_center().x, body.end.y - FLAME_FOOT_LIFT / maxf(absf(host.global_scale.y), 0.001))
	_fire.position = (foot - position) / scale
