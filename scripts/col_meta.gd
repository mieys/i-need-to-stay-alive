extends RefCounted

## ALTIN KUMLAR (çöl) haritasının çalışma anı verisi - tools/col/gen_col.py --write ÜRETİR (elle düzenleme; üreteç ezer).
## Koordinatlar dünya pikseli (Harita (0,0)'da). Oyun alanı hücre Rect2i(32, 20, 243, 243).

const PLAY_CELLS := Rect2i(32, 20, 243, 243)
const SPAWN := Vector2(2456, 3752)
## Gece ışıkları: [tür, dünya konumu] (küre tapınağının mavi küresi)
const LIGHTS := [
	["kure", Vector2(1255.5, 994.0)],
]
