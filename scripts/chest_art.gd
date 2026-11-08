extends RefCounted

## Sandık sanatı TEK KAYNAK. Kullananlar: chest_drop.gd (dünya), chest_open_anim.gd (ödül ekranı + efsun ekranı girişi),
## chest_pass_fx.gd (sıradakine uçan sandık), gold_reward_fx.gd (altın fışkıran sandık).
##
## 2026-11-06 (madde 409, kullanıcı: "sandığı eski haline döndür, senin yaptığını değil eski ai olmayan versiyonu"): oyunun İLK
## sürümündeki PAKET sandıkları geri geldi (assets/sprites/chest_tier_*.png + chests.png, elle çizilmiş paket sanatı). Kademe bandı
## (0-5 = KADEME I-II ... XI+, chest_drop.gd chest_tier) sandığın görünüşünü seçer - ilk sürümdeki gibi. Elit = aynı paketin koyu
## gümüş-kristal sandığı. Sayfalar tools/gen_chest_from_pack.py ile 20 karelik düzene DİZİLİR (çizim değişmez): 0-3 kapalı,
## 4-7 sallanma (+-1 px), 8 kapak aralık, 9-10 altın görünür, 11-19 tam açık. 32 px kare, ilk sürümdeki ölçek (0,8 dünya px).
## Işık sütunu (madde 242 "B Işık Sütunu", üretilmiş sanat) KAPALI: BEAM_ENABLED. Eski sayfalar (chest_normal*.png, chest_beam*.png,
## tools/gen_chest_sprites.py) duruyor - geri açmak: BEAM_ENABLED true + sabitleri eski değerlere (TEXEL 0,5, FRAME_PX 96).

const TEXEL := 0.8
const FRAME_PX := 32
const FRAME_WU := FRAME_PX * TEXEL
const FRAME_COUNT := 20
const BEAM_ENABLED := false
## Paket sanatının kendi gölgesi var: üretilmiş chest_shadow.png + drop_shadow.gd ikinci gölgesi eklenmez.
const EXTRA_SHADOW := false

## Kademe bandına göre normal sandık (chest_drop.gd chest_tier / chest_menu.gd _chest_tier, 0-5).
const KADEME_SHEETS := [
	preload("res://assets/sprites/chests/paket_k0.png"),
	preload("res://assets/sprites/chests/paket_k1.png"),
	preload("res://assets/sprites/chests/paket_k2.png"),
	preload("res://assets/sprites/chests/paket_k3.png"),
	preload("res://assets/sprites/chests/paket_k4.png"),
	preload("res://assets/sprites/chests/paket_k5.png"),
]


static func normal_sheet(kademe_band: int) -> Texture2D:
	return KADEME_SHEETS[clampi(kademe_band, 0, KADEME_SHEETS.size() - 1)]

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
const CHEST_ANCHOR_PX := Vector2(16, 31) ## paket karesinde sandığın alt-ortası (gen_chest_from_pack.py yazdırır)
const BEAM_ANCHOR_PX := Vector2(64, 176)
const BEAM_OFFSET_PX := (CHEST_ANCHOR_PX - Vector2(FRAME_PX, FRAME_PX) * 0.5) - (BEAM_ANCHOR_PX - Vector2(BEAM_W, BEAM_H) * 0.5)

## Kademe bilinmeyen yerler (uçan sandık, altın fışkıran sandık) ilk bandın sandığını kullanır. Ödül ekranı nadirliğe göre sandık
## DEĞİŞTİRMEZ (eskiden ışık rengi nadirlikti); NORMAL_TIER_SHEETS eski çağıranlar için aynı sandık.
const NORMAL_SHEET := preload("res://assets/sprites/chests/paket_k0.png")
const NORMAL_TIER_SHEETS := [NORMAL_SHEET, NORMAL_SHEET, NORMAL_SHEET, NORMAL_SHEET]
const ELITE_SHEET := preload("res://assets/sprites/chests/paket_elite.png")
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
