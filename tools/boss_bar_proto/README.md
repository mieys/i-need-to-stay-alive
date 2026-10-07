# Boss çubuğu prototipleri (2026-10-05)

Üst-orta boss barı (T1-T4) ve boss üstü bar (O1-O4) prototipleri. Seçim yapılınca bunlar oyun dokularına/koduna çevrilecek.

- `boss_capture.gd`: gerçek oyundan (SP, pencereli) boss'lu kareler yakalar. `BOSS_CAP_DIR` = çıktı klasörü.
  `Godot --windowed --resolution 1920x1080 --path <proje> -s tools/boss_bar_proto/boss_capture.gd`
- `art.py`, `protos_top.py`, `protos_world.py`: piksel çizim kütüphanesi + 8 tasarım (kit paleti, m5x7 1x yazı).
  Üst bar: 1 art px = 3 ekran px. Dünya çubuğu: 1 art px = 2 ekran px.
- `compose.py`: çizimleri gerçek karelerin üstüne yerleştirir (`BOSS_PROTO_DIR/cap/*.png` -> `BOSS_PROTO_DIR/page/`).
- `build_page.py`: inceleme sayfası (HTML). Seçim sonrası bu klasör silinebilir.

**UYGULANDI (2026-10-05):** seçilen T1 + boss üstünde sadece kafatası; tek bar. Kod: `scripts/boss_bar_art.gd` (bu klasörün Python çizimlerinin GDScript portu), `boss_bar_top.gd`, `boss_skull_marker.gd`. Bu klasör sadece referans, silinebilir.
