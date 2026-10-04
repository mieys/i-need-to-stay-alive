extends TotemBase
class_name TotemShield

## Kalkan Totemi (Shaman ULTİ, skill id 26): "Etrafındaki müttefiklere her
## saniye kendi kalkanlarının %0.5'ini yeniler ve shaman'ın saldırı gücünün
## %20'si kadar kalkan yeniler."
##
## Ally'ye kalkan verme _apply_shield_heal_to_ally() üzerinden YAPILMALI
## (bkz. player.gd, CLAUDE.md'nin bahsettiği TAM hata sınıfı) - doğrudan
## .heal_shield() çağırmak sadece caster'ın o ally'nin KOZMETİK kuklasını
## etkiler, gerçek client'ına ulaşmaz.
##
## DÜZELTME (kullanıcı isteği: "saldırı gücü oranını %10'dan %20'ye
## yükselt") - eskiden 0.10 idi.
const SELF_PERCENT := 0.005
## Kullanıcı isteği (2026-09-24 denge turu): "Shaman'ın kalkanı %12 AP olsun" - 0.20 -> 0.12 (30sn boyunca tüm takıma
## saniyede AP'nin %20'si kalkan, AP ile sınırsız büyüyen en güçlü takım savunmalarından biriydi).
const ATTACK_POWER_RATIO := 0.12
## Yetenek evrimleri (kart metinleri skill_evolutions.gd DEFS[12]): "Güçlü Kalkan" (shaman_e4) verilen kalkan x1.5;
## "Savaş Ritmi" (shaman_e2) alandaki oyunculara +%15 saldırı hızı (player.gd enchant_haste_value "atk_speed" buff'ı okur).
const EVO_SHIELD_MULT := 1.5
const EVO_ATTACK_SPEED := 0.15
const EVO_SLOW_PERCENT := 0.7 ## Yapışkan Zemin (shaman_e3): alandaki yaratıklar %70 yavaşlar (temel yavaşlatma YOK - evrim getirir)
const EVO_SLOW_TIME := 1.5 ## alan tiki 1 sn'de bir - yavaşlatma bir sonraki tikte yenilenir, alandan çıkınca ~0.5 sn sonra biter
const EVO_PUSH_DISTANCE := 34.0 ## İtici Dalga (shaman_ef): her hasar tikinde merkezden dışarı itme (dünya birimi)
const EVO_BUFF_TIME := 1.6 ## player.gd EVO_BUFF_REFRESH_TIME ile aynı (tik 1 sn; buff tikler arasında düşmesin)

## Kullanıcı isteği: "totemden diğer oyunculara doğru ses ince sihirli bir
## ses dalgasına benzer bir efektle kalkan göndersin menzilin içindeyken.
## sadece efektini böyle yap skilin mantığına falan dokunma" - aşağıdaki
## dalga efekt bölümü TAMAMEN kozmetiktir: _tick'teki kalkan miktarı
## hesaplarına HİÇBİR etkisi yoktur, silinse bile skil aynı çalışır.
const TotemShieldWave := preload("res://scripts/totem_shield_wave.gd")
## Bu kadar yakın (totemin dibindeki = dikeni Shaman'ın kendisi) hedeflere
## dalga çizilmez - dalga zaten "totemden DİĞER oyunculara" doğru akmalı.
const WAVE_MIN_DISTANCE := 40.0

var _wave_timer: float = 0.0


func _init() -> void:
	totem_kind = "shield"
	totem_color = Color(0.35, 0.65, 1.0)
	totem_radius = 220.0
	## Kullanıcı isteği (2026-09-30): Saldırı Totemi'nin alan hasarı bu totemde de (bkz. totem_base.gd "ALAN HASARI").
	area_damage_enabled = true


## Kalkan Totemi evrimleri (alan hasar tiki, bkz. totem_base.gd _on_area_enemy_tick): "Yapışkan Zemin" ve final "İtici Dalga".
## slow/push enemy.gd'nin host-yönlendirmeli çağrılarıdır (istemci kasterden de çalışır).
func _on_area_enemy_tick(enemy: Node2D) -> void:
	if _caster_has_evo("shaman_e3") and enemy.has_method("apply_slow"):
		enemy.call("apply_slow", EVO_SLOW_PERCENT, EVO_SLOW_TIME)
	if _caster_has_evo("shaman_ef") and enemy.has_method("apply_skill_push"):
		var away: Vector2 = enemy.global_position - global_position
		if away.length() < 1.0:
			away = Vector2.from_angle(randf() * TAU)
		enemy.call("apply_skill_push", away.normalized(), EVO_PUSH_DISTANCE)


func _process(delta: float) -> void:
	## Gerçek mantık: TotemBase._process - _tick YALNIZCA dikeni oyuncunun
	## kendi client'ında, ağ kopyalarında asla çalışmaz (bkz. totem_base.gd).
	super(delta)
	## Kozmetik dalga döngüsü: ağ GÖRSEL kopyalarında DA çalışır ki her oyuncu
	## totemden müttefiklere akan dalgayı görsün (efekt salt görseldir, her
	## client kendi sahnesindeki oyuncu kopyalarına dalga çizer - "kastın
	## ekranında doğru, diğerinde yok" hatasına bununla düşmez, çünkü burada
	## hiçbir oyun durumu paylaşılmıyor, sadece çizim var).
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_wave_timer += TICK_INTERVAL
	_spawn_shield_waves()


## AYNI menzil/koşul kontrolleri (menzil + item_shield_max) - yani dalga
## SADECECE gerçekten kalkan alan müttefiklere doğru çizilir, ama hiçbir
## kalkan değeri burada hesaplanmaz/uygulanmaz.
##
## GÖRÜNÜRLÜK DÜZELTMESİ (kullanıcı bildirimi: "görünmüyor efekt falan"):
## "player_ally" grubu SADECE uzak oyuncu kopyalarını (ve petleri) içerir -
## YEREL oyuncu (player.tscn groups=["player"]) bu grupta DEĞİL. Tek
## oyunculu modda grup tamamen boş olduğundan efekt HİÇ spawn olmuyordu.
## Şimdi hedef aramasına yerel oyuncu (grup "player") DAHİL - totemin
## dibinde durmuyorsan (WAVE_MIN_DISTANCE) kendi kalkanına giden dalgayı
## da görürsün. Petler item_shield_max'a sahip olmadığından (kalkan
## mantığıyla AYNI koşul) yine filtrelenir.
func _spawn_shield_waves() -> void:
	if caster == null or not is_instance_valid(caster):
		return
	var targets: Array = []
	for ally in caster.get_tree().get_nodes_in_group("player_ally"):
		targets.append(ally)
	for p in caster.get_tree().get_nodes_in_group("player"):
		if not targets.has(p):
			targets.append(p)
	for target in targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var target_n2d := target as Node2D
		var dist: float = global_position.distance_to(target_n2d.global_position)
		if dist > totem_radius or dist < WAVE_MIN_DISTANCE:
			continue
		if not ("item_shield_max" in target):
			continue
		TotemShieldWave.spawn(get_tree().current_scene, global_position, target_n2d, totem_color)
	## Totemin kendisinde kısa bir "yayılma" halkası - her tick'te kalkan
	## verildiğini TÜM modlarda (tek oyunculu dahil) her açıdan görünür kılar.
	TotemShieldWave.spawn_pulse(get_tree().current_scene, global_position, totem_color)
	## Her tik'te çok kısık, ince bir "kalkan cıngırtısı" (30sn boyunca saniyede bir - rahatsız etmesin diye çok yumuşak).
	ShamanSfx.play_at(get_tree().current_scene, ShamanSfx.SHIELD_PULSE, global_position, -19.0, 0.04)


func _tick() -> void:
	if not ("damage_bonus" in caster):
		return
	var flat_bonus: float = float(caster.damage_bonus) * ATTACK_POWER_RATIO
	var evo_shield_mult: float = EVO_SHIELD_MULT if _caster_has_evo("shaman_e4") else 1.0
	var haste_buff: bool = _caster_has_evo("shaman_e2") and caster.has_method("_evo_give_buff")
	## Savaş Ritmi: kendisi (alandaysa) + alandaki müttefikler. Buff her tikte tazelenir, alandan çıkınca/totem kapanınca kısa sürede düşer.
	if haste_buff and global_position.distance_to(caster.global_position) <= totem_radius:
		caster._evo_give_buff(caster, "atk_speed", EVO_ATTACK_SPEED, EVO_BUFF_TIME)

	## Kendi kalkanı.
	if "item_shield_max" in caster and "item_shield_hp" in caster:
		var self_amount: float = (float(caster.item_shield_max) * SELF_PERCENT + flat_bonus) * evo_shield_mult
		if caster.has_method("heal_shield"):
			caster.heal_shield(self_amount)

	## Etraftaki müttefikler - Oakley'nin pasif can yenileme döngüsüyle
	## (player.gd _process_healer_shield_tick benzeri) AYNI "player_ally"
	## grubu taraması.
	for ally in caster.get_tree().get_nodes_in_group("player_ally"):
		if not is_instance_valid(ally):
			continue
		if global_position.distance_to(ally.global_position) > totem_radius:
			continue
		if haste_buff:
			caster._evo_give_buff(ally, "atk_speed", EVO_ATTACK_SPEED, EVO_BUFF_TIME)
		if not ("item_shield_max" in ally):
			continue
		var ally_amount: float = (float(ally.item_shield_max) * SELF_PERCENT + flat_bonus) * evo_shield_mult
		if caster.has_method("_apply_shield_heal_to_ally"):
			caster._apply_shield_heal_to_ally(ally, ally_amount)
