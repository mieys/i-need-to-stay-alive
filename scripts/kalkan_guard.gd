extends RefCounted

## KALKAN silahı "Siper Duruşu" (madde 685, kullanıcı: "kalkan menzilli atışları bloklayabilsin, baktığı/durduğu taraftan gelen atışlar
## bloklansın; menzilinde kimse yoksa ve saldıramıyorsa oyuncuyu atışlardan korumaya odaklansın"; sonra "komple bloklasın").
## TEK kaynak: weapon.gd (yerel kalkan) ve remote_player.gd (uzak kukla - host'ta yetkili mermi onu sorar) aynı fonksiyonları kullanır.
##
## Kural: oyuncuda ekranda görünen (çıkış/gösterim durumunda) bir Kalkan varsa, onun YÜZ yönü (8 dilim, KalkanBashMath) etrafında
## +-HALF_ARC_DEG (65) yaya ve oyuncu merkezinden RADIUS içine giren her yaratık atışı kalkana çarpar (kıvılcım + ses + geri tepme) ve hasarı
## DAMAGE_REDUCTION (%30; Siper "Sağlam Siper" %50) azalır, atış yoluna devam edip gövdeye vurur (madde 705, kullanıcı: "hasarı sadece %30 azaltsın,
## komple bloklamasın, çok bozuk oldu" - madde 685'teki TAM blok kalktı). Her atış EN ÇOK BİR kez azalır (META_GUARDED). Arkadan / yandan gelen
## atış azalmaz. Yön her karede silah tarafından yayınlanır (publish) ve kısa sürede bayatlar (TTL_MSEC): Kalkan satılır/gizlenir/ölürse
## koruma kendiliğinden biter. Mermi türleri `try_block`'u Talon çemberinin hemen yanında çağırır (enemy_projectile.gd _guard_owners).
## Yönlendirme (weapon.gd _wf_update_facing / remote_player.gd _wf_melee_facing): menzilde düşman varsa yüz ona (saldırı önce); yoksa
## `threat_dir` = üstüne gelen en yakın atışın yönü -> Kalkan gizliyse de çıkar (görünürlük "want"ına eklenir).

const META := &"kalkan_guard"
const META_GUARDED := &"kalkan_guarded" ## atışa: bu atışın hasarı zaten azaltıldı
const DAMAGE_REDUCTION := 0.3 ## temel (weapon_traits.gd "siper" metni + siper.gd guard_reduction ile aynı sayı)
const MAX_REDUCTION := 0.9
const GROUP := &"ranged_shots" ## tüm yaratık/boss atışları _ready'de katılır (enemy_projectiles grubu sis gizlemesi taşıdığı için ayrı grup)
const RADIUS := 40.0 ## dünya px (oyuncu merkezinden; gövde yarıçapı 12) - atış gövdeye varmadan kalkana çarpar
const HALF_ARC_DEG := 65.0 ## yüz yönünün iki yanı (toplam 130 derece; yön 45 derecelik dilime oturur: en çok ~30 derece dilim hatası + yan geçen atışın payı)
const TTL_MSEC := 250
const THREAT_RANGE := 260.0 ## bu mesafedeki, bize doğru gelen atış "tehdit" sayılır (kalkanın çıkış süresi 0,42 sn + dönüş payı)
const THREAT_AIM_DOT := 0.7 ## atışın yönü bize en çok ~45 derece sapmış olabilir
const THREAT_MISS := 22.0 ## atış çizgisi merkezimizden en çok bu kadar yan geçiyorsa tehdit (gövde 12 + atış 8 = zaten vuracak olanlar)
const BLOCK_SCENE_PATH := "res://scenes/fx_evo_talon_block.tscn" ## Talon çemberiyle aynı küçük kıvılcım

## Blok tepkisi (madde 687, kullanıcı: "skill atışlarını bloklarken hafif geri tepmeli, ses çıkmalı, kendini atışlara göre hizalamalı"):
## blokta kalkan ikonu atıştan uzağa kısa "tok" geri tepme + hafif ezilme yapar, kıvılcımla birlikte kısa bir isabet sesi çıkar. Ses: Kalkan'ın kendi
## isabet sesi (kalkan_isabet_1/2; darbeden ayırt edilsin diye daha tiz + kısık + 0,5 sn'de söner). Hizalama: weapon.gd/remote_player.gd gelen atışı
## (threat_dir) saldırı hedefinin ÖNÜNE koyar ve darbenin beklemesini böler.
const BLOCK_SOUNDS: Array = [preload("res://assets/audio/kalkan_isabet_1.wav"), preload("res://assets/audio/kalkan_isabet_2.wav")]
## Madde 701 (kullanıcı: "siper alıp korumuş hissiyatı vermiyor, geri tepmiyor, ses çıkarmıyor, mermilere doğru pozisyon almıyor"):
## ses -9 -> -3 dB ve daha pes (tok), geri tepme 4,5 -> 8 px + daha derin ezilme + beyaz parlama, yerel oyuncuda küçük kamera sarsıntısı.
const BLOCK_SOUND_DB := -15.0 ## kullanıcı: "çok kafa ağrıtıyor" -> -3'ten -15 dB'ye düşürüldü
const BLOCK_SOUND_PITCH := Vector2(0.88, 1.02)
const BLOCK_SOUND_GAP_MSEC := 110 ## art arda gelen atışlar tek bir gürültüye dönüşmesin
const BLOCK_SOUND_LIFE := 0.6 ## sn: dosya 0,8-0,9 sn sürer; bu süreden sonra kısılıp biter
const RECOIL_WORLD_PX := 8.0 ## dünya px (ikon yerel birimine silahın/pivotun dönüşümüyle çevrilir)
const RECOIL_IN := 0.035
const RECOIL_OUT := 0.2
const RECOIL_SQUASH := 0.82
const FLASH := 2.3 ## blokta ikonun self_modulate parlaması (1 = yok), FLASH_TIME'da söner
const FLASH_TIME := 0.14
const SPARK_WORLD_PX := 24.0 ## kıvılcım kalkanın yüzünde (gövde merkezinden atış yönünde) - mermi RADIUS'ta söner, kıvılcım kalkanın üstünde
const SHAKE_TRAUMA := 0.3 ## yalnız yerel oyuncunun kendi bloğu (camera_shake.gd: genlik travma^2)
const NET_VFX := "kalkan_block" ## NetworkManager.broadcast_player_vfx türü (diğer istemcilerde de geri tepme + ses)

## SİPER ALMA (madde 701): gelen atış varken kalkan silah yuvasından (başın ~60 px üstü) çıkıp gövdenin ATIŞ TARAFINA, COVER_WORLD_PX
## mesafeye kayar (atışla oyuncunun arasına girer), atış bitince COVER_HOLD sonra yuvasına döner. Yerel silah (weapon.gd) ve kukla
## (remote_player.gd) aynı durum makinesini (cover_step) ve hedefi (cover_world) kullanır. Darbe sürerken durum donar (darbe yolu kaymasın).
const COVER_WORLD_PX := 20.0
const COVER_IN_RATE := 9.0 ## k/sn (~0,11 sn'de siperde; smoothstep)
const COVER_OUT_RATE := 3.5
const COVER_HOLD := 0.4 ## sn: son tehditten / bloktan sonra siperde kalma
const COVER_TURN_RATE := 14.0 ## siper yönünün yeni atışa dönüş hızı
## Atış bu kadar yakınken (bize gelirken) yerel Kalkan yeni darbeye ÇIKMAZ, siperde bekler (weapon.gd _on_fire_timer_timeout); bir darbe en çok
## POSTPONE_MAX_MSEC ertelenir (sürekli yağmurda saldırı hiç kesilmesin).
const IMMINENT_DIST := 140.0
const POSTPONE_MAX_MSEC := 700

static var _block_scene: PackedScene = null
static var _last_sound_msec: int = -100000


## Dilim (KalkanBashMath.sector_of: 0 aşağı, 90 derece sağ, 180 yukarı) -> birim yön.
static func sector_dir(sector: int) -> Vector2:
	var a: float = deg_to_rad(float(posmod(sector, 8)) * 45.0)
	return Vector2(sin(a), cos(a))


## react: blokta çağrılacak (atışa doğru yön) -> geri tepme; silah / kukla kendi ikonunu oynatır (boşsa yalnız kıvılcım + ses).
## reduction: bu kalkanın hasar azaltması (yerel: siper.gd guard_reduction; kukla: sahibinin eşitlediği "kguard").
static func publish(player: Node, dir: Vector2, react: Callable = Callable(), reduction: float = DAMAGE_REDUCTION) -> void:
	if player == null or not is_instance_valid(player) or dir.length() < 0.0001:
		return
	player.set_meta(META, [dir.normalized(), Time.get_ticks_msec() + TTL_MSEC, react, reduction])


## Etkin kalkanın hasar azaltması (eski 2-3 elemanlı meta: temel).
static func reduction_of(player: Node) -> float:
	if player == null or not is_instance_valid(player) or not player.has_meta(META):
		return DAMAGE_REDUCTION
	var g: Array = player.get_meta(META)
	return clampf(float(g[3]), 0.0, MAX_REDUCTION) if g.size() >= 4 else DAMAGE_REDUCTION


## Mermilerin çağırdığı (madde 705): atış kalkanın önündeyse ilk kez değdiği karede blok tepkisi (try_block) + atışın `damage`'ı
## x(1 - azaltma). Atış DURMAZ - yoluna devam edip normal kuralıyla vurur (alan hasarı / durum etkisi de azalmış hasarla). true = bu karede azaltıldı.
## Her makine kendi kopyasında azaltır; hasarı yalnız yetkili kopya verir (host'ta kukla, kendi makinede yerel oyuncu) - sonuç aynı.
static func guard_shot(player: Node, shot: Node) -> bool:
	if shot == null or not is_instance_valid(shot) or not (shot is Node2D) or shot.has_meta(META_GUARDED):
		return false
	if not try_block(player, (shot as Node2D).global_position):
		return false
	shot.set_meta(META_GUARDED, true)
	var d: Variant = shot.get("damage")
	if d is float or d is int:
		shot.set("damage", float(d) * (1.0 - reduction_of(player)))
	return true


static func clear(player: Node) -> void:
	if player != null and is_instance_valid(player) and player.has_meta(META):
		player.remove_meta(META)


## Etkin koruma yönü (bayatsa / yoksa ZERO).
static func guard_dir(player: Node) -> Vector2:
	if player == null or not is_instance_valid(player) or not player.has_meta(META):
		return Vector2.ZERO
	var g: Array = player.get_meta(META)
	if Time.get_ticks_msec() > int(g[1]):
		return Vector2.ZERO
	return g[0] as Vector2


## `pos` noktasındaki yaratık atışını bu oyuncunun kalkanı bloklar mı? (saf geometri; efekt yok)
static func blocks(player: Node, pos: Vector2) -> bool:
	var dir: Vector2 = guard_dir(player)
	if dir == Vector2.ZERO or not (player is Node2D):
		return false
	var to: Vector2 = pos - (player as Node2D).global_position
	var d: float = to.length()
	if d > RADIUS or d < 1.0:
		return false
	return dir.dot(to / d) >= cos(deg_to_rad(HALF_ARC_DEG))


## Blok tepkisi (geometri + kıvılcım + ses + kalkanın geri tepmesi); hasarı guard_shot azaltır. true = kalkanın önünde.
## Her makine kendi mermi kopyasıyla bloklar; YEREL oyuncunun bloğu ayrıca diğer istemcilere yayınlanır (onların kopyası yerel olmayan oyuncuyu
## hiç sınamaz): alıcı remote_player.gd kalkan_block_remote.
static func try_block(player: Node, pos: Vector2) -> bool:
	if not blocks(player, pos):
		return false
	var center: Vector2 = (player as Node2D).global_position
	var to_shot: Vector2 = pos - center
	var fx_pos: Vector2 = spark_pos(center, to_shot)
	play_block_fx(player.get_tree(), fx_pos)
	react(player, to_shot)
	_broadcast_block(player, fx_pos, to_shot)
	if player.is_in_group("player"):
		_shake(fx_pos)
	return true


## Kıvılcımın yeri: kalkanın siper yüzü (atış RADIUS'ta söner ama kıvılcım kalkanın üstünde patlasın).
static func spark_pos(center: Vector2, to_shot: Vector2) -> Vector2:
	if to_shot.length() < 0.0001:
		return center
	return center + to_shot.normalized() * minf(SPARK_WORLD_PX, to_shot.length())


## ---------- Siper alma durum makinesi (madde 701) ----------
## st: {"k": 0..1 siperde olma, "dir": siper yönü (sahibten atışa), "hold": sn}. threat: threat_dir sonucu (yoksa ZERO).
static func cover_step(st: Dictionary, threat: Vector2, delta: float) -> void:
	var hold: float = float(st.get("hold", 0.0))
	var dir: Vector2 = st.get("dir", Vector2.ZERO)
	if threat != Vector2.ZERO:
		hold = COVER_HOLD
		if dir == Vector2.ZERO or float(st.get("k", 0.0)) <= 0.0:
			dir = threat
		else:
			dir = Vector2.from_angle(lerp_angle(dir.angle(), threat.angle(), clampf(delta * COVER_TURN_RATE, 0.0, 1.0)))
	else:
		hold = maxf(0.0, hold - delta)
	var k: float = float(st.get("k", 0.0))
	if hold > 0.0:
		k = minf(1.0, k + delta * COVER_IN_RATE)
	else:
		k = maxf(0.0, k - delta * COVER_OUT_RATE)
	st["k"] = k
	st["dir"] = dir
	st["hold"] = hold


## Blok anı siperi tazeler (atış tehdit taramasına girmeden vurduysa da kalkan o tarafta kalsın).
static func cover_hit(st: Dictionary, to_shot: Vector2) -> void:
	if to_shot.length() < 0.0001:
		return
	st["hold"] = COVER_HOLD
	if float(st.get("k", 0.0)) <= 0.0:
		st["dir"] = to_shot.normalized()


## Siper karışımı (smoothstep). 0 = yuvada, 1 = tam siperde.
static func cover_blend(st: Dictionary) -> float:
	var k: float = clampf(float(st.get("k", 0.0)), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Siper noktası: gövde merkezinden atış yönünde COVER_WORLD_PX (dünya ofseti; çağıran kendi yerel birimine çevirir).
static func cover_world(st: Dictionary) -> Vector2:
	var d: Variant = st.get("dir", Vector2.ZERO)
	return ((d as Vector2) * COVER_WORLD_PX) if d is Vector2 else Vector2.ZERO


## Blok görseli + sesi (yerel blok ve ağdan gelen blok ortak).
static func play_block_fx(tree: SceneTree, pos: Vector2) -> void:
	_spawn_spark(tree, pos)
	_play_block_sound(tree, pos)


## Yayınlanan kalkanın geri tepme tepkisini çağırır (to_shot: sahibten atışa yön).
static func react(player: Node, to_shot: Vector2) -> void:
	if player == null or not is_instance_valid(player) or not player.has_meta(META):
		return
	var g: Array = player.get_meta(META)
	if g.size() >= 3 and g[2] is Callable and (g[2] as Callable).is_valid():
		(g[2] as Callable).call(to_shot)


## İkonu atıştan UZAĞA kısa bir "tok" geri tepme + hafif ezilmeyle oynatır, yaylanarak dinlenme yerine döner. icon: kalkan ikonu, rest_pos /
## base_scale: ikonun YEREL dinlenme konumu / sabit ölçeği, to_shot: sahibten atışa dünya yönü. Tween'i döner (çağıran sonraki blokta öldürür).
static func recoil(host: Node, icon: Node2D, to_shot: Vector2, rest_pos: Vector2, base_scale: Vector2) -> Tween:
	if host == null or icon == null or not is_instance_valid(icon) or not icon.is_inside_tree():
		return null
	var kick: Vector2 = Vector2.ZERO
	if to_shot.length() > 0.0001:
		kick = -to_shot.normalized() * RECOIL_WORLD_PX
		var parent := icon.get_parent() as Node2D
		if parent != null:
			kick = parent.global_transform.affine_inverse().basis_xform(kick) ## dünya px -> ikonun yerel birimi
	var tw: Tween = host.create_tween()
	tw.tween_property(icon, "position", rest_pos + kick, RECOIL_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale * RECOIL_SQUASH, RECOIL_IN)
	tw.tween_property(icon, "position", rest_pos, RECOIL_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "scale", base_scale, RECOIL_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if "self_modulate" in icon: ## beyaz "tok" parlaması (ayrı tween: geri tepmeyi öldüren kod parlamayı yarıda bırakmasın)
		icon.set("self_modulate", Color(FLASH, FLASH, FLASH, 1.0))
		var fl: Tween = host.create_tween()
		fl.tween_property(icon, "self_modulate", Color.WHITE, FLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## Yerel oyuncunun bloğunda küçük kamera sarsıntısı. camera_shake.gd dinamik yüklenir (UISound autoload'u yokken de derlensin).
static func _shake(pos: Vector2) -> void:
	var cs: Script = load("res://scripts/camera_shake.gd") as Script
	if cs != null:
		cs.call("add_limited", "kalkan_block", SHAKE_TRAUMA, 0.15, pos)


static func _play_block_sound(tree: SceneTree, pos: Vector2) -> void:
	var now: int = Time.get_ticks_msec()
	if tree == null or tree.current_scene == null or now - _last_sound_msec < BLOCK_SOUND_GAP_MSEC:
		return
	_last_sound_msec = now
	var p := AudioStreamPlayer2D.new()
	p.stream = BLOCK_SOUNDS[randi() % BLOCK_SOUNDS.size()]
	p.volume_db = BLOCK_SOUND_DB
	p.pitch_scale = randf_range(BLOCK_SOUND_PITCH.x, BLOCK_SOUND_PITCH.y)
	p.max_distance = 1500.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	var tw: Tween = p.create_tween()
	tw.tween_interval(BLOCK_SOUND_LIFE * 0.6)
	tw.tween_property(p, "volume_db", -40.0, BLOCK_SOUND_LIFE * 0.4)
	tw.tween_callback(p.queue_free)


## Yerel oyuncunun bloğunu diğer istemcilere yollar (kozmetik, güvenilmez; en çok ~8/sn). NetworkManager dinamik aranır: bu betik
## autoload'lar yokken de derlenebilsin (yakalama betikleri).
static func _broadcast_block(player: Node, pos: Vector2, to_shot: Vector2) -> void:
	if not player.is_in_group("player"):
		return
	var tree: SceneTree = player.get_tree()
	var nm: Node = tree.root.get_node_or_null("NetworkManager") if tree != null else null
	if nm == null or nm.get("is_multiplayer_active") != true:
		return
	var my_id: int = tree.get_multiplayer().get_unique_id()
	if nm.should_throttle("kalkan_block_%d" % my_id, 0.12):
		return
	nm.send_player_vfx(my_id, NET_VFX, pos, {"dx": to_shot.x, "dy": to_shot.y})


static func _spawn_spark(tree: SceneTree, pos: Vector2) -> void:
	if tree == null or tree.current_scene == null:
		return
	if _block_scene == null and ResourceLoader.exists(BLOCK_SCENE_PATH):
		_block_scene = load(BLOCK_SCENE_PATH) as PackedScene
	if _block_scene == null:
		return
	var fx: Node2D = _block_scene.instantiate() as Node2D
	tree.current_scene.add_child(fx)
	fx.global_position = pos


static func _shot_dir(n: Node) -> Vector2:
	var v: Variant = n.get("_dir")
	if not (v is Vector2):
		v = n.get("direction")
	return (v as Vector2) if v is Vector2 else Vector2.ZERO


## Sahibe doğru gelen en yakın atışın yönü (sahibten atışa, birim). Gelen yoksa ZERO.
static func threat_dir(owner: Node2D) -> Vector2:
	return threat(owner)[0] as Vector2


## [yön (threat_dir), mesafe (yoksa INF)] - yerel Kalkan mesafeyle darbeyi erteler (IMMINENT_DIST).
static func threat(owner: Node2D) -> Array:
	if owner == null or not owner.is_inside_tree():
		return [Vector2.ZERO, INF]
	var o: Vector2 = owner.global_position
	var best_d: float = INF
	var best: Vector2 = Vector2.ZERO
	for n in owner.get_tree().get_nodes_in_group(GROUP):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var v: Vector2 = _shot_dir(n)
		if v == Vector2.ZERO:
			continue
		var to_o: Vector2 = o - (n as Node2D).global_position
		var d: float = to_o.length()
		if d > THREAT_RANGE or d < 1.0 or d >= best_d:
			continue
		if v.dot(to_o / d) < THREAT_AIM_DOT or absf(v.cross(to_o)) > THREAT_MISS:
			continue
		best_d = d
		best = -to_o / d
	return [best, best_d]
