extends RefCounted

## Sandık sanatı TEK KAYNAK (2026-10-17, madde 242: "B Işık Sütunu" - Lost Ark / Diablo esinli, kasvetli gerçekçi). Sayfalar
## tools/gen_chest_sprites.py ile üretilir (kare düzeni o dosyanın başında). Kullananlar: chest_drop.gd (dünya), chest_open_anim.gd
## (ödül ekranı + efsun ekranı girişi), chest_pass_fx.gd (sıradakine uçan sandık), gold_reward_fx.gd (altın fışkıran sandık).
##
## 1 sanat pikseli = TEXEL dünya px (silahlarla aynı yoğunluk). Sandık karesi FRAME_PX doku px = FRAME_WU dünya px: eski 48 px
## kareyle aynı yeri kaplar, 20 karelik düzen aynı (0-3 bekleme, 4-7 sallanma, 8 patlama, 9-15 ışın, 16-19 açık döngü).
## Işık sütunu + yer halkası AYRI sayfa (sandığın arkasında ayrı sprite; sandık sayfası sütunsuz kalır -> küçük ikonlar etkilenmez).

const TEXEL := 0.5
const FRAME_PX := 96
const FRAME_WU := 48.0
const FRAME_COUNT := 20

const BEAM_W := 128
const BEAM_H := 192
const BEAM_FRAMES := 37
const BEAM_IDLE := 24 ## 0..23 bekleme döngüsü
const BEAM_IDLE_STEP := 0.1
const BEAM_SHAKE := 24 ## 24..27 sallanma (sandık kareleri 4..7 ile eş)
const BEAM_COLLAPSE := 28 ## 28..36 çökme
const BEAM_COLLAPSE_FRAMES := 9
const BEAM_COLLAPSE_STEP := 0.05

## Sandığın alt-orta noktası (doku px): sandık karesinde ve ışık sütunu karesinde. Sprite'lar ortalı -> sütun sprite'ı sandık
## sprite'ına göre BEAM_OFFSET_PX (doku px, ölçekten önce) kadar kaydırılır.
const CHEST_ANCHOR_PX := Vector2(48, 84)
const BEAM_ANCHOR_PX := Vector2(64, 176)
const BEAM_OFFSET_PX := (CHEST_ANCHOR_PX - Vector2(FRAME_PX, FRAME_PX) * 0.5) - (BEAM_ANCHOR_PX - Vector2(BEAM_W, BEAM_H) * 0.5)

## Dünya: sıcak altın ışık (çıkacak eşya henüz belli değil). Ödül ekranı: ışık = eşyanın nadirliği (1 gri-beyaz, 2 mavi, 3 mor, 4 altın).
const NORMAL_SHEET := preload("res://assets/sprites/chests/chest_normal.png")
const NORMAL_TIER_SHEETS := [
	preload("res://assets/sprites/chests/chest_normal_t1.png"),
	preload("res://assets/sprites/chests/chest_normal_t2.png"),
	preload("res://assets/sprites/chests/chest_normal_t3.png"),
	preload("res://assets/sprites/chests/chest_normal_t4.png"),
]
const ELITE_SHEET := preload("res://assets/sprites/chests/chest_elite.png")
const BEAM_SHEET := preload("res://assets/sprites/chests/chest_beam.png")
const BEAM_TIER_SHEETS := [
	preload("res://assets/sprites/chests/chest_beam_t1.png"),
	preload("res://assets/sprites/chests/chest_beam_t2.png"),
	preload("res://assets/sprites/chests/chest_beam_t3.png"),
	preload("res://assets/sprites/chests/chest_beam_t4.png"),
]
const ELITE_BEAM_SHEET := preload("res://assets/sprites/chests/chest_beam_elite.png")


## Açılışta sandık karesine (4..12+) eş düşen ışık sütunu karesi: sallanmada 24..27, patlamadan sonra çökme (dünyada 0,05 sn'lik
## sandık adımları çökmeyi 2 kat hızlı oynatır). -1 = sütun bitti (gizle).
static func beam_frame_for_open(chest_frame: int, collapse_step: int = 2) -> int:
	if chest_frame < 4:
		return 0
	if chest_frame < 8:
		return BEAM_SHAKE + chest_frame - 4
	var j: int = (chest_frame - 8) * collapse_step
	return BEAM_COLLAPSE + j if j < BEAM_COLLAPSE_FRAMES else -1
