extends RefCounted

## ÜRETİLDİ: tools/derin_orman/place_derin_orman.py --apply (madde 361) - elle düzenleme, betiği yeniden koş.
## Derin orman bölgelerinin zindan girişleri ve set parçaları: hücre = parçanın AYAK hücresi (Harita.tmx), bölge = maske kanalı
## (0 Kuzey, 1 Batı, 2 Doğu, 3 Güney).

const GATES: Array[Dictionary] = [
	{"zone": 0, "name": "Kemik Mahzeni", "cell": Vector2i(207, 17)},
	{"zone": 1, "name": "Et Kuyusu", "cell": Vector2i(39, 32)},
	{"zone": 2, "name": "Boynuzlu Kapı", "cell": Vector2i(241, 53)},
]

const SETS: Array[Dictionary] = [
	{"zone": 0, "piece": "kemik_mahzen", "cell": Vector2i(207, 17)},
	{"zone": 1, "piece": "et_kuyusu", "cell": Vector2i(39, 32)},
	{"zone": 2, "piece": "boynuzlu_kapi", "cell": Vector2i(241, 53)},
	{"zone": 3, "piece": "yuzlu_agac", "cell": Vector2i(106, 234)},
	{"zone": 3, "piece": "bataklik_kulube", "cell": Vector2i(135, 232)},
	{"zone": 3, "piece": "dev_bataklik_agaci", "cell": Vector2i(108, 197)},
]
