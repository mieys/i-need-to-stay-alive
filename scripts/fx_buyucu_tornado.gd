extends Node2D
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

## Silah/yetenek hedef seçiminde görünürlük şartı (bkz. VisionFogScript.can_target).
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")
## 2026-10-16 (madde 188, onaylanan prototip): dolu, sarmal şeritli hortum hunisi (şerit aralarından arka duvar / çimen görünür, içinde
## menekşe kıvılcım + yaprak + çakıl, tabanda toz girdabı) - assets/fx/buyucu/hortum_{in,loop,out}.png (tools/gen_buyucu_fx.py).
## Eski ince çizgili beyaz huni (assets/fx/buyucu_tornado/loop_*) artık kullanılmıyor. Doğuşta küçük girdaptan büyür (hortum_in),
## ömrü bitince alttan çözülüp yükselir (hortum_out, begin_out - uzak kopya despawn yayınıyla aynı fonksiyonu çağırır), değdiği
## yaratıkta rüzgâr kesikleri (fx_buyucu_tornado_hit.tscn, "hitscan_impact" ile diğer oyunculara).
const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const HitFxScene := preload("res://scenes/fx_buyucu_tornado_hit.tscn")
const SHEET_FPS := 15.0
## Sayfa 48x72, zemin satırı 64 -> ortalanmış sprite ofseti (düğüm orijini = hortumun yere değdiği nokta).
const SHEET_OFFSET := Vector2(0.0, -28.0)
## Kozmetik kopyanın despawn'ı / kasterin ömrü bitince çözülme başlar - player.gd bu sinyalle despawn yayınlar (çözülme iki tarafta aynı anda).
signal ending

## Büyücü Kız'ın TEMEL yeteneğinin 3. varyasyonu ("Hortum") için bağımsız
## bir hortum varlığı - bkz. player.gd _skill_buyucu_tornado(). Oyuncunun
## etrafında BUYUCU_TORNADO_RADIUS yarıçapında rastgele yaratıklara doğru
## dolaşır, değdiği yaratığa saniyede en fazla 1 kez hasar verir.
##
## DÜZELTME (kullanıcı bildirimi: "bazı karakterler ve yetenekleri
## multiplayerda çalışmıyor ve görünmüyor"): eskiden bu varlık SADECE döken
## oyuncunun kendi ekranında simüle ediliyordu (aşağıdaki eski not hâlâ
## doğru: hasar zaten host-yetkili take_damage() ile herkeste senkronize
## oluyordu, sadece GÖRSEL tarafı eksikti). Artık Necromancer'ın iskelet/
## golem'leriyle BİREBİR AYNI "gerçek pet" deseni kullanılıyor (bkz. player.gd
## _skill_buyucu_tornado - broadcast_pet_spawn/despawn/state) - SADECE döken
## istemcide gerçek yapay zeka/hasar çalışır, diğer istemcilerde SADECE
## kozmetik bir kopya (mark_as_network_visual) son bildirilen konuma
## yumuşakça kayar.
##
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "büyücü kızın hortumu... fps düşürüyor" - bkz.
## performans denetimi): GÖRÜNÜM artık PROSEDUREL DEĞİL. Eskiden _draw() içinde huni gövdesi +
## katmanlı halkalar + döküntü/kıvılcımlar karede ~1100 draw_rect() çağrısıyla YENİDEN
## ÇİZİLİYORDU - bu varyasyon AYNI ANDA 3 hortum çağırdığı (BUYUCU_TORNADO_COUNT) ve her biri
## 15 saniye yaşadığı için karede ~3300+ çağrı, Matthew'in kalkanıyla (kullanıcının zaten
## bulduğu -100fps) AYNI CİDDİYETTE bir düşüşe yol açıyordu. Artık görünüm tools/gen_heavy_fx_
## perf_sprite.py ile PNG'ye "pişirildi" (assets/fx/buyucu_tornado/loop_sheet.png, huninin
## kendi dönüş hızıyla - TORNADO_SPIN_RATE=6.0 - TAM BİR periyot, 36 kare, ~1.05sn - SESSİZ
## DÖNGÜ) ve tek bir AnimatedSprite2D çizimiyle oynatılıyor: draw_rect sayısı ~1100 -> 1'e indi.
## ÖLÇEK NOTU: PNG "1 raster piksel = 1 world birimi" pişirildi (bkz. o script'in ÖLÇEK NOTU) -
## PixelDraw.TEXEL ile AYRICA ölçeklenmez, sadece _ready()'deki mevcut 1.05 kullanıcı-boyut
## çarpanı korunur.

var owner_player: Node2D = null
var origin: Vector2 = Vector2.ZERO
var wander_radius: float = 380.0
var damage_amount: float = 0.0
var hit_interval: float = 1.0
var touch_radius: float = 46.0
var lifetime: float = 15.0

var _elapsed: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
## Kullanıcı isteği: "büyücü kızın hortumlarını %40 yavaşlat" - eski taban
## 170.0'ın %60'ı (170 * 0.6 = 102).
var _speed: float = 102.0
var _hit_timers: Dictionary = {} ## enemy instance_id -> kalan bekleme (sn)
## Büyücü "Efsunlu Büyü" (Q finali, 2026-10-04): efsunlu dökümde hortum %25 büyük (görsel; temas yarıçapını player.gd zaten
## büyütüp setup'a verir). Kozmetik kopyaya pet durum yayınının sprite_row alanında x100 gider (hortumun sprite satırı yok).
var size_mult: float = 1.0
## Düğüm ölçeği = size_mult (Efsunlu Büyü); sayfa pikseli BuyucuFx.PX dünya birimi (eski sayfa 1,05 ölçekliydi).
const BASE_VISUAL_SCALE := 1.0

## bkz. skeleton_pet.gd dosya başındaki "kozmetik kopya" notu - AYNI desen.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false
var _sheet: Node = null
var _ending: bool = false


func mark_as_network_visual() -> void:
	_is_network_visual = true


## Kullanıcı isteği: "hortumlarını ... %20 küçült" - eski _draw() kendi yerel
## orijinine göre çiziyordu, bu yüzden scale'i %80'e indirmek görseli
## orantılı küçültüyordu; artık AnimatedSprite2D için AYNI scale kullanılıyor.
## touch_radius (isabet/hasar menzili) BİLEREK değiştirilmedi - istek sadece
## görsel küçültme, yeteneğin etki alanını değiştirmek değildi.
## DÜZELTME: bu artık _ready()'de (setup() DEĞİL) uygulanıyor - kozmetik
## kopyada hiç setup() çağrılmıyor (bkz. skeleton_pet.gd'deki AYNI desen),
## ama görsel ölçeği yine de doğru olmalı.
func _ready() -> void:
	scale = Vector2.ONE * BASE_VISUAL_SCALE * size_mult
	## Üç hortum aynı anda doğuyor: hepsi TIPATIP aynı karede dönerse "tek hortumun 3 kopyası" hissi verir -> doğuşları 0-5 kare
	## (0-0,33 sn) rastgele gecikir (doğuş sayfası döngünün sonuna dikişsiz bağlandığı için başlangıç karesi kaydırılmaz).
	_sheet = BuyucuFxScript.Sheet.new()
	_sheet.centered = true
	_sheet.offset = SHEET_OFFSET
	_sheet.scale = Vector2.ONE * BuyucuFxScript.PX
	add_child(_sheet)
	_sheet.setup([["hortum_in", false], ["hortum_loop", true]], SHEET_FPS, 0, float(randi() % 6) / SHEET_FPS)


func setup(p_owner: Node2D, p_origin: Vector2, p_radius: float, p_damage: float,
		p_hit_interval: float, p_lifetime: float, p_touch_radius: float) -> void:
	owner_player = p_owner
	origin = p_origin
	wander_radius = p_radius
	damage_amount = p_damage
	hit_interval = p_hit_interval
	lifetime = p_lifetime
	touch_radius = p_touch_radius
	global_position = origin + Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
	_pick_new_target()
	set_process(true)


func set_size_mult(mult: float) -> void:
	size_mult = maxf(0.1, mult)
	scale = Vector2.ONE * BASE_VISUAL_SCALE * size_mult


## Yakında bir yaratık varsa ona doğru yönel ("rasgele konumlarda ...
## yaratıklara doğru hareket ederek" isteğiyle uyumlu), yoksa yarıçap
## içinde rastgele bir noktaya doğru dolaş.
func _pick_new_target() -> void:
	var candidates: Array = []
	for e: Node in EnemyQueryScript.candidates(get_tree(), origin, wander_radius + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not VisionFogScript.can_target(e):
			continue
		if origin.distance_to(e.global_position) <= wander_radius:
			candidates.append(e)
	if candidates.size() > 0:
		var pick: Node2D = candidates[randi_range(0, candidates.size() - 1)]
		_target_pos = pick.global_position
	else:
		var angle: float = randf() * TAU
		var dist: float = randf_range(40.0, wander_radius)
		_target_pos = origin + Vector2(cos(angle), sin(angle)) * dist


func _process(delta: float) -> void:
	if _ending:
		return
	if _is_network_visual:
		_process_network_visual(delta)
		return
	_elapsed += delta
	if _elapsed >= lifetime:
		begin_out() ## hasar/hareket burada biter (eskisi gibi) - görsel çözülüp kendini siler
		return

	var to_target: Vector2 = _target_pos - global_position
	if to_target.length() < 24.0:
		_pick_new_target()
	else:
		global_position += to_target.normalized() * _speed * delta
	## Yarıçap dışına taşarsa yeni bir hedefe yönel (elastik sınır).
	if global_position.distance_to(origin) > wander_radius:
		_pick_new_target()

	for key in _hit_timers.keys():
		_hit_timers[key] = max(0.0, (_hit_timers[key] as float) - delta)

	for e: Node in EnemyQueryScript.candidates(get_tree(), global_position, touch_radius + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > touch_radius:
			continue
		var id: int = e.get_instance_id()
		if _hit_timers.get(id, 0.0) > 0.0:
			continue
		_hit_timers[id] = hit_interval
		## Büyücü evrimleri (2026-10-04): temas etkileri (alınan hasar artışı, sersemletme) - hasardan ÖNCE (bkz. player.gd
		## buyucu_tornado_touch).
		if owner_player and is_instance_valid(owner_player) and owner_player.has_method("buyucu_tornado_touch"):
			owner_player.buyucu_tornado_touch(e)
		if e.has_method("take_damage"):
			## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" -
			## her ayrı temas kendi kritik zarını atıyor (player.gd'deki
			## paylaşılan crit_chance_bonus/crit_damage_bonus statlarını
			## kullanarak, bkz. o dosyadaki _roll_ability_crit/_apply_
			## ability_crit).
			var dmg: float = damage_amount
			var is_crit: bool = false
			if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
				is_crit = owner_player._roll_ability_crit()
				dmg = owner_player._apply_ability_crit(dmg, is_crit)
			BalanceLogScript.tag(&"s:buyucu_kasirga")
			e.take_damage(dmg, is_crit, 0.0, true)
			_spawn_hit_fx((e as Node2D).global_position)

	_broadcast_network_state()


## Ömür bitti (kaster) ya da sahibinden despawn geldi (uzak kopya, remote_player.gd _despawn_pet_visual): hareket/hasar durur, huni alttan
## çözülüp yükselir (hortum_out, 0,8 sn), sonra düğüm silinir. İki kez çağrılırsa bir şey yapmaz.
func begin_out() -> void:
	if _ending:
		return
	_ending = true
	ending.emit()
	if is_instance_valid(_sheet):
		_sheet.tree_exited.connect(queue_free)
		_sheet.call("finish", "hortum_out")
	else:
		queue_free()


## Temas anı: yaratığın gövdesinde rüzgâr kesikleri - yerelde + diğer oyunculara "hitscan_impact" (aynı sahne).
func _spawn_hit_fx(pos: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var fx: Node2D = HitFxScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = pos
	if NetworkManager.is_multiplayer_active and not NetworkManager.should_throttle("tornado_hit_%s" % network_instance_id, 0.1):
		NetworkManager.send_player_vfx(multiplayer.get_unique_id(), "hitscan_impact", pos, {"scene_path": HitFxScene.resource_path})


## bkz. skeleton_pet.gd'deki AYNI fonksiyon - GERÇEK hortum kendi konumunu
## periyodik olarak yayınlıyor, kozmetik kopyalar sadece buna yumuşakça
## kayıyor (hiç kendi rastgele dolaşma/hasar mantığı çalıştırmıyor).
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, false,
		-1.0, -1.0, int(round(size_mult * 100.0)))


## broadcast_pet_state RPC'sinin çağırdığı istemci tarafı karşılığı - "is_
## attacking" parametresi bu efekt için anlamsız, kullanılmıyor.
## DÜZELTME: remote_player.gd _update_pet_visual_state() bu fonksiyonu
## sprite_row dahil 3 argümanla çağırıyor (bkz. skeleton_pet.gd/player_pet.gd
## AYNI düzeltme) - eski 2 parametreli imza "too many arguments" hatasıyla
## sessizce başarısız olup tornadoyu diğer oyunculara hareketsiz gösteriyordu.
## sprite_row: boyut çarpanı x100 (Efsunlu Büyü - bkz. size_mult); -1/0 = eski gönderen, ölçek değişmez.
func update_network_pet_state(pos: Vector2, _is_attacking: bool, sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true
	if sprite_row > 0 and absf(float(sprite_row) / 100.0 - size_mult) > 0.001:
		set_size_mult(float(sprite_row) / 100.0)


func _process_network_visual(delta: float) -> void:
	if _network_state_received:
		global_position = global_position.lerp(_network_target_position, min(1.0, delta * 10.0))
