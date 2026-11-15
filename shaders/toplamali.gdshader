shader_type canvas_item;
// Toplamalı karışım (renk zemine eklenir). CanvasItemMaterial BLEND_MODE_ADD yerine: onun shader'ı ilk kullanımda bir kare SONRA
// üretiliyor, Arcane Patlama'nın ilk karesi normal karışımla (koyu mor) çiziliyordu (madde 563). Bu shader preload edilir ve
// fx_warmup.gd EXTRA_SHADERS ile önceden derlenir. Kullanan: BuyucuFx.add_material().
render_mode blend_add;
