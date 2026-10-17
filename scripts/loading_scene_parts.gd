## OTOMATİK ÜRETİLİR: python tools/gen_yukleme_bg.py - elle düzenleme (sahne değişince yeniden üret).
## Yükleme ekranı sahnesinin (assets/ui/yukleme/yukleme_bg.png, 640x360 tuval, oyunda x3) canlı parçaları: yatay kare şeritleri.
## [dosya, tuvalde sol üst, kare boyutu, kare sayısı, fps, ayak y (çizim sırası)]

const CANVAS := Vector2(640, 360)
const PARTS: Array = [
	["duman.png", Vector2(478, 44), Vector2(48, 30), 6, 8.0, 0],
	["agac_3.png", Vector2(206, -3), Vector2(59, 65), 13, 10.0, 62],
	["agac_0.png", Vector2(368, 5), Vector2(63, 79), 13, 10.0, 84],
	["agac_2.png", Vector2(502, 248), Vector2(59, 64), 13, 10.0, 312],
	["agac_1.png", Vector2(112, 275), Vector2(75, 77), 13, 10.0, 352],
]
