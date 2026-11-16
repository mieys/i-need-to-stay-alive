extends "res://scripts/enchant_behavior.gd"

## Yankılanan Büyü (Arcane Asası, kalıcı özellik) - bkz. EnchantDefs "yankilanan_buyu". Küre isabeti hedefin yerinde bir "yankı" bırakır;
## echo_delay sn sonra aynı noktada patlar (silah hasarı x echo_dmg, echo_radius). Çift Yankı: 0,5 sn sonra bir kez daha (yarı hasar).
## Final: patlamaya yakalananlar echo_stun sn sersemler. Hasar `blast` ile, görsel sprite'larla (yerel + diğer oyunculara aynı efekt).
## MADDE 749 (2026-11-16, kullanıcı: "her 3 saldırıda herhangi bir hedefte kesin açılıyorsa"): şans YOK - sayaç SİLAHA bağlı
## (roll_pity anahtarı "echo" bu davranışın), hangi düşmana vurursa vursun her (echo_pity + 1). isabette kesin; echo_pity <= 0 = her isabet.
## Görsel "C - Kaos Yarığı": hedefin yerinde açılan dikey yarık (void_rift_open, 0,8 sn) + kırık halka şok dalgası (void_rift_pop_45 /
## _60 - Geniş Yankı ikinci sayfa, ölçekleme yok). Eski görsel Korsan'ın TURUNCU patlaması + ateş sesiydi (madde 729 teşhisi).

const REPEAT_GAP := 0.5
const ECHO_COLOR := Color(0.88, 0.55, 1.0)
## Sayfalar 1 sanat px = 1 dünya birimi çizildi (tools/gen_asa_efekt_fx.py); fx_enchant_sprite TEXEL 1,212 ile çarpar.
const SHEET_SCALE := Vector2(1.0 / 1.212, 1.0 / 1.212)
## Yarığın merkezi yaratığın kökünün (ayak hizası) bu kadar üstünde - prototipte gövde ortası.
const RIFT_LIFT := 7.0
const POP_SFX := "res://assets/audio/arcane_attack.mp3"
const POP_SFX_DB := -8.0
const POP_SFX_PITCH := 0.72


## Bu isabette yarık açılır mı: echo_pity <= 0 her isabet, yoksa kötü şans koruması = her (pity + 1). isabet (echo_chance tabanda 0).
func _echo_now() -> bool:
	var pity: int = n("echo_pity", 2)
	if pity <= 0:
		return true
	return roll_pity("echo", f("echo_chance", 0.0), pity)


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not is_enemy(t) or not can_act():
		return
	if not _echo_now():
		return
	var at: Vector2 = (t as Node2D).global_position
	sprite("void_rift_open", at + Vector2(0.0, -RIFT_LIFT), {"scale": SHEET_SCALE})
	get_tree().create_timer(f("echo_delay", 0.8), false).timeout.connect(_pop.bind(at, 1.0, n("echo_repeat")))


func _pop_sheet() -> String:
	return "void_rift_pop_60" if f("echo_radius", 45.0) >= 52.0 else "void_rift_pop_45"


func _pop(at: Vector2, mult: float, repeats_left: int) -> void:
	if not is_instance_valid(self) or not is_instance_valid(weapon) or not can_act():
		return
	sprite(_pop_sheet(), at + Vector2(0.0, -RIFT_LIFT), {"scale": SHEET_SCALE, "sfx": POP_SFX, "sfx_db": POP_SFX_DB,
		"sfx_pitch": POP_SFX_PITCH})
	var victims: Array = enemies_near(at, f("echo_radius", 45.0))
	var amount: float = wdmg() * f("echo_dmg", 1.0) * mult
	for e in victims:
		hit(e, amount)
	if f("echo_stun") > 0.0:
		for e in victims:
			if is_enemy(e):
				el(e, "stun", {"dur": f("echo_stun")})
	if repeats_left > 0:
		get_tree().create_timer(REPEAT_GAP, false).timeout.connect(_pop.bind(at, mult * 0.5, repeats_left - 1))
