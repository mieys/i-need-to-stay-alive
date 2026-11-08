# KAYITLI YESIL prototipi ozet gorselleri (2026-11-06, oyuna bagli DEGIL).
#   python -I tools/proto_20261106/kayitli_yesil/ozet.py
# out/kayitli_<V>.png (kayitli_capture.gd) -> out/ozet.png (A-D, pazarin tamami, %55) + out/yakin.png (SU AN + A-D, 1:1 kayitli yuvalar)
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
NAMES = {
	"SU_AN": "ŞU AN (altın)",
	"A": "A - Yosun Kenar",
	"B": "B - Yosun Kuyu",
	"C": "C - Kilitli Etiket",
	"D": "D - Köşe Kilidi",
}
BG = (20, 14, 9)
INK = (243, 230, 204)


def font(sz):
	return ImageFont.truetype(FONT, sz)


def main():
	shots = {k: Image.open(os.path.join(OUT, "kayitli_%s.png" % k)).convert("RGB") for k in NAMES}
	# 1) ozet: A-D, pazar penceresi + baslik
	box = (222, 100, 1698, 896)
	sc = 0.55
	cw, ch = int((box[2] - box[0]) * sc), int((box[3] - box[1]) * sc)
	lab = 40
	o = Image.new("RGB", (cw * 2 + 30, (ch + lab) * 2 + 30), BG)
	d = ImageDraw.Draw(o)
	for n, k in enumerate(["A", "B", "C", "D"]):
		x, y = 10 + (n % 2) * (cw + 10), 10 + (n // 2) * (ch + lab + 10)
		d.text((x + 4, y + 2), NAMES[k], font=font(32), fill=INK)
		o.paste(shots[k].crop(box).resize((cw, ch), Image.LANCZOS), (x, y + lab))
	o.save(os.path.join(OUT, "ozet.png"))
	# 2) yakin: 1:1 kayitli yuvalar (Bicak kayitli, Deri Cizmeler kayitli + imlec ustunde) + kayitli gelistirme satiri
	box = (445, 232, 1226, 500)
	cw, ch = box[2] - box[0], box[3] - box[1]
	lw = 230
	o = Image.new("RGB", (lw + cw + 10, (ch + 8) * len(NAMES) + 8), BG)
	d = ImageDraw.Draw(o)
	for n, k in enumerate(NAMES):
		y = 8 + n * (ch + 8)
		d.text((10, y + ch // 2 - 14), NAMES[k], font=font(32), fill=INK)
		o.paste(shots[k].crop(box), (lw, y))
	o.save(os.path.join(OUT, "yakin.png"))
	print("ozet.png + yakin.png")


main()
