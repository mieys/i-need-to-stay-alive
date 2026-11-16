extends RefCounted

## Necromancer iskelet birlikleri - "2D Pixel Quest Vol.2: The Necromancer's Order" (Barely Apes; künyede anılmasını istiyor).
## ÜRETİLEN DOSYA: tools/necro_iskelet/build_frames.py yazar, elle düzenleme (yeniden üretimde gider).
## Kareler: assets/pets/necro_iskelet/<birim>_frames.tres. Anim adları "<anim>_<yön>", yön DIRS'ten; batı yarısı flip_h.
## Hayalet birimlerde "rise" tek yönlüdür (yön eki yok) - anim_name() ikisini de çözer.
## Sprite: AnimatedSprite2D centered=true, offset=UNITS[k].offset (ayaklar düğüm kökünde), scale=WORLD_SCALE.

## Bir sanat pikseli kaç dünya birimi: Corvina'nın karakter pikseli ~0.9 (2.237 x 0.8075 x 0.5) - aynı doku yoğunluğu.
## 2026-11-16 (kullanıcı: "biraz büyümeleri gerek"): 0.9 -> 1.1, ardından "biraz fazla büyümüşler küçült" -> 1.0.
const WORLD_SCALE := 1.0
const DIRS: Array[String] = ["s", "se", "e", "ne", "n"]

## anahtar -> frames (yol), name (Türkçe), canvas (paket tuvali px), offset (centered sprite için, ayaklar = 0),
## body_h (idle S gövde boyu px), counts (anim -> yön başına kare), strike (saldırı animinde silahın en uzağa
## uzandığı kare - TAHMİN, bağlarken gözle doğrula).
const UNITS := {
	"common": {
		"frames": "res://assets/pets/necro_iskelet/common_frames.tres",
		"name": "İskelet Er", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(60, 57),
		"offset": Vector2(0.0, -12.5),
		"body_h": 28,
		"counts": {"idle": 5, "walk": 4, "attack": 5, "hurt": 5, "death": 12, "rise": 8},
		"strike": {"attack": 3},
	},
	"armored": {
		"frames": "res://assets/pets/necro_iskelet/armored_frames.tres",
		"name": "Zırhlı İskelet", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(60, 57),
		"offset": Vector2(0.0, -12.5),
		"body_h": 31,
		"counts": {"idle": 5, "walk": 4, "attack": 5, "hurt": 5, "death": 12, "block": 8, "rise": 8},
		"strike": {"attack": 3},
	},
	"captain": {
		"frames": "res://assets/pets/necro_iskelet/captain_frames.tres",
		"name": "İskelet Yüzbaşı", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(62, 68),
		"offset": Vector2(0.0, -19.0),
		"body_h": 36,
		"counts": {"idle": 5, "walk": 4, "attack": 8, "hurt": 5, "death": 12, "block": 11, "rise": 10},
		"strike": {"attack": 3},
	},
	"knight": {
		"frames": "res://assets/pets/necro_iskelet/knight_frames.tres",
		"name": "Kemik Şövalyesi", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(101, 95),
		"offset": Vector2(0.0, -24.5),
		"body_h": 47,
		"counts": {"idle": 10, "walk": 8, "attack": 6, "attack2": 7, "attack3": 12, "block": 10, "hurt": 3, "death": 12, "rise": 8},
		"strike": {"attack": 2, "attack2": 2, "attack3": 4},
	},
	"archer": {
		"frames": "res://assets/pets/necro_iskelet/archer_frames.tres",
		"name": "İskelet Okçu", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(54, 44),
		"offset": Vector2(0.0, -18.0),
		"body_h": 28,
		"counts": {"idle": 5, "walk": 4, "attack": 7, "hurt": 5, "death": 12, "rise": 8},
		"strike": {"attack": 1},
	},
	"mage": {
		"frames": "res://assets/pets/necro_iskelet/mage_frames.tres",
		"name": "Kemik Büyücüsü", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(61, 69),
		"offset": Vector2(0.0, -25.5),
		"body_h": 39,
		"counts": {"idle": 7, "walk": 12, "attack": 18, "cast": 15, "summon": 25, "hurt": 3, "death": 21},
		"strike": {"attack": 8},
	},
	"ghost_common": {
		"frames": "res://assets/pets/necro_iskelet/ghost_common_frames.tres",
		"name": "Hayalet Er", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(60, 57),
		"offset": Vector2(0.0, -12.5),
		"body_h": 28,
		"counts": {"idle": 5, "walk": 4, "attack": 5, "hurt": 5, "death": 15, "rise": 11},
		"strike": {"attack": 3},
	},
	"ghost_armored": {
		"frames": "res://assets/pets/necro_iskelet/ghost_armored_frames.tres",
		"name": "Hayalet Zırhlı", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(60, 57),
		"offset": Vector2(0.0, -12.5),
		"body_h": 31,
		"counts": {"idle": 5, "walk": 4, "attack": 5, "hurt": 5, "death": 14, "block": 8, "rise": 11},
		"strike": {"attack": 3},
	},
	"ghost_captain": {
		"frames": "res://assets/pets/necro_iskelet/ghost_captain_frames.tres",
		"name": "Hayalet Yüzbaşı", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(62, 68),
		"offset": Vector2(0.0, -19.0),
		"body_h": 36,
		"counts": {"idle": 5, "walk": 4, "attack": 8, "hurt": 5, "death": 14, "block": 11, "rise": 11},
		"strike": {"attack": 3},
	},
	"ghost_knight": {
		"frames": "res://assets/pets/necro_iskelet/ghost_knight_frames.tres",
		"name": "Hayalet Şövalye", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(101, 95),
		"offset": Vector2(0.0, -24.5),
		"body_h": 47,
		"counts": {"idle": 10, "walk": 8, "attack": 6, "attack2": 7, "attack3": 12, "block": 10, "hurt": 3, "death": 14, "rise": 11},
		"strike": {"attack": 2, "attack2": 2, "attack3": 4},
	},
	"ghost_archer": {
		"frames": "res://assets/pets/necro_iskelet/ghost_archer_frames.tres",
		"name": "Hayalet Okçu", ## dil:yok (iç ad, ekranda görünmez)
		"canvas": Vector2i(54, 44),
		"offset": Vector2(0.0, -18.0),
		"body_h": 28,
		"counts": {"idle": 5, "walk": 4, "attack": 7, "hurt": 5, "death": 14, "rise": 11},
		"strike": {"attack": 1},
	},
}

## fx anahtarı -> [yol, kare_w, kare_h, kare sayısı] (tek satır şerit). arrow/ghost_arrow kare sırası: e, se, s, ne, n.
const FX := {
	"arrow": ["res://assets/pets/necro_iskelet/fx/arrow.png", 20, 20, 5],
	"ghost_arrow": ["res://assets/pets/necro_iskelet/fx/ghost_arrow.png", 20, 20, 5],
	"fire": ["res://assets/pets/necro_iskelet/fx/fire.png", 20, 46, 7],
	"heal": ["res://assets/pets/necro_iskelet/fx/heal.png", 21, 39, 5],
	"reborn": ["res://assets/pets/necro_iskelet/fx/reborn.png", 19, 55, 4],
	"mage_ring": ["res://assets/pets/necro_iskelet/fx/mage_ring.png", 63, 43, 3],
}


## Bakış yönü -> [yön eki, flip_h]. Tam kuzey/güney (n/s) ön/arka görünümdür: aynalama önceki değerde kalır,
## yoksa dikey yürürken küçük x titremesi silahı el değiştirir gibi oynatır.
static func dir_of(v: Vector2, prev_flip: bool = false) -> Array:
	if v.length_squared() < 0.0001:
		return ["s", prev_flip]
	var deg := rad_to_deg(atan2(v.y, absf(v.x))) ## -90 yukarı .. +90 aşağı (Godot y aşağı)
	var d := "e"
	if deg < -67.5:
		d = "n"
	elif deg < -22.5:
		d = "ne"
	elif deg <= 22.5:
		d = "e"
	elif deg <= 67.5:
		d = "se"
	else:
		d = "s"
	if d == "n" or d == "s":
		return [d, prev_flip]
	return [d, v.x < 0.0]


## "<base>_<d>" yoksa yönsüz "<base>" (hayalet rise), o da yoksa idle_<d>.
static func anim_name(frames: SpriteFrames, base: String, d: String) -> String:
	var n := base + "_" + d
	if frames.has_animation(n):
		return n
	if frames.has_animation(base):
		return base
	return "idle_" + d
