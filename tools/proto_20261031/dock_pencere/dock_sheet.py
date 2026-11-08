# Yetenek paneli pencere prototipleri karşılaştırma sayfası (madde 391): her satır = gerçek oyun yakalamasından panel (1:1) +
# aynı karedeki grup paneli / görev / bildirim levhaları (uyum kontrolü). Girdi out/simdi.png + out/proto_<X>.png.
#   python tools/proto_20261031/dock_pencere/dock_sheet.py [v2]  -> out[/v2]/ozet.png (1:1) + yakin.png (x2 panel)
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", *sys.argv[1:2])  # argüman: alt klasör (ör. v2)
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "PixeloidSans-Bold.ttf")
DOCK = (430, 868, 1310, 1068)  # v2 taşmaları (kemer, topuz, kütük) dahil
CTX = (1480, 196, 1890, 566)
BG = (24, 18, 13)
INK = (243, 230, 204)


def rows():
	pal = json.load(open(os.path.join(OUT, "palettes.json"), encoding="utf-8"))
	out = [("ŞU AN", "simdi.png")]
	for k in "ABCD":
		out.append(("%s - %s" % (k, pal[k]["name"]), "proto_%s.png" % k))
	return out


def main():
	font = ImageFont.truetype(FONT, 22)
	rs = rows()
	ctx_s = 0.5
	cw = int((CTX[2] - CTX[0]) * ctx_s)
	ch = int((CTX[3] - CTX[1]) * ctx_s)
	dw = DOCK[2] - DOCK[0]
	dh = DOCK[3] - DOCK[1]
	lab = 34
	rh = lab + max(dh, ch) + 14
	sheet = Image.new("RGB", (dw + cw + 30, rh * len(rs)), BG)
	near = Image.new("RGB", (dw * 2, (lab + dh * 2 + 10) * len(rs)), BG)
	d = ImageDraw.Draw(sheet)
	dn = ImageDraw.Draw(near)
	for i, (name, f) in enumerate(rs):
		im = Image.open(os.path.join(OUT, f)).convert("RGB")
		y = i * rh
		d.text((10, y + 6), name, font=font, fill=INK)
		sheet.paste(im.crop(DOCK), (0, y + lab))
		sheet.paste(im.crop(CTX).resize((cw, ch), Image.NEAREST), (dw + 20, y + lab))
		yn = i * (lab + dh * 2 + 10)
		dn.text((10, yn + 6), name, font=font, fill=INK)
		near.paste(im.crop(DOCK).resize((dw * 2, dh * 2), Image.NEAREST), (0, yn + lab))
	sheet.save(os.path.join(OUT, "ozet.png"))
	near.save(os.path.join(OUT, "yakin.png"))
	print("ozet", sheet.size, "yakin", near.size)


if __name__ == "__main__":
	main()
