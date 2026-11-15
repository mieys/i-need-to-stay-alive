extends RefCounted

## ÜRETİLDİ: tools/kamp/gen_kamp.py (elle düzenleme; yeniden üret). Takım üssü kampının parçaları (madde 607, team_camp.gd).
## x / y = parçanın sol üst köşesi, kamp merkezine (kamp ateşi) göre dünya birimi (1 sanat px = 1 birim); ayak = üst kenardan
## derinlik ayak hizası; kare = animasyon karesi (yatay şerit); engel_r = çadır çarpışma çemberi (move_blockers).

const DIR := "res://assets/map/kamp/"
const KARE_MS := 150
const KAPSAM := Rect2(-148.5, -98.0, 292.0, 121.0)
const PARCALAR: Array = [
	{"ad": "tent1", "tur": "cadir", "dosya": "tent1.png", "x": -148.5, "y": -97.0, "w": 108, "h": 103, "kare": 1, "ayak": 103, "sira": 0, "engel_r": 32.4},
	{"ad": "tent2", "tur": "cadir", "dosya": "tent2.png", "x": 40.5, "y": -98.0, "w": 103, "h": 88, "kare": 1, "ayak": 88, "sira": 1, "engel_r": 30.9},
	{"ad": "rocks_1", "tur": "esya", "dosya": "rocks_1.png", "x": -61.5, "y": -12.0, "w": 13, "h": 9, "kare": 1, "ayak": 9, "sira": 6},
	{"ad": "rocks2_0", "tur": "esya", "dosya": "rocks2_0.png", "x": -43.5, "y": -40.0, "w": 12, "h": 12, "kare": 1, "ayak": 12, "sira": 7},
	{"ad": "logs_0", "tur": "esya", "dosya": "logs_0.png", "x": -27.5, "y": -38.0, "w": 48, "h": 10, "kare": 1, "ayak": 10, "sira": 8},
	{"ad": "logs_1", "tur": "esya", "dosya": "logs_1.png", "x": 19.5, "y": -30.0, "w": 9, "h": 43, "kare": 1, "ayak": 43, "sira": 8},
	{"ad": "logs_2", "tur": "esya", "dosya": "logs_2.png", "x": -39.5, "y": -28.0, "w": 9, "h": 41, "kare": 1, "ayak": 41, "sira": 8},
	{"ad": "logs_3", "tur": "esya", "dosya": "logs_3.png", "x": -27.5, "y": 7.0, "w": 45, "h": 13, "kare": 1, "ayak": 13, "sira": 8},
	{"ad": "weapons_1", "tur": "esya", "dosya": "weapons_1.png", "x": -3.5, "y": 4.0, "w": 24, "h": 19, "kare": 1, "ayak": 19, "sira": 9},
	{"ad": "ates", "tur": "ates", "dosya": "ates.png", "x": -23.5, "y": -23.0, "w": 36, "h": 29, "kare": 12, "ayak": 29, "sira": 0},
]
