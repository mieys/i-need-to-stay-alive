## OTOMATİK ÜRETİLİR: python tools/gen_yukleme_bg.py - elle düzenleme (çekim/sahne değişince yeniden üret).
## Yükleme ekranı "Mühürlü Kapı" (assets/ui/yukleme/yukleme_bg.png, 640x360 tuval, oyunda x3) canlı parçaları: yatay kare şeritleri.
## [dosya, tuvalde sol üst, kare boyutu, kare sayısı, fps, ayak y (çizim sırası)]

const CANVAS := Vector2(640, 360)
const PARTS: Array = [
	["kapi_alev.png", Vector2(505, 121), Vector2(69, 87), 6, 6.25, 200],
]
## kapının yeşil ışığı (toplamalı katman, %100'de güç 1.15) + zindan kapısı ağzı (hale ve ruh ışıkları buradan)
const LIGHT := "yukleme_isik.png"
const GATE_MOUTH := Vector2(546, 184)
