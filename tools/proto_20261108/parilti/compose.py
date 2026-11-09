import sys
from PIL import Image, ImageDraw
d = sys.argv[1]
S = 2560/1920
def load(n): return Image.open(f"{d}/{n}.png").convert("RGB")
eski, yeni, spr = load("gece_eski"), load("gece_yeni"), load("sprite")
def lum(p): return 0.299*p[0]+0.587*p[1]+0.114*p[2]
XS=[160,480,800,1120]; CNT=[1,2,3,5]
for name, im in (("eski", eski), ("yeni", yeni)):
    vals=[]
    for x in XS:
        best=0
        for yy in range(int(330*S), int(400*S), 2):
            for xx in range(int((x-60)*S), int((x+60)*S), 2):
                best=max(best, lum(im.getpixel((xx,yy))))
        vals.append(round(best))
    print("gece", name, dict(zip(CNT, vals)))
for row,name in ((200,"toplamali"),(500,"yumusak")):
    vals=[]
    for x in XS:
        best=0
        for yy in range(int((row-40)*S),int((row+40)*S),2):
            for xx in range(int((x-120)*S),int((x+110)*S),2):
                best=max(best, lum(spr.getpixel((xx,yy))))
        vals.append(round(best))
    print("sprite", name, dict(zip(CNT, vals)))
W=1280
def crop(im,y0,y1): return im.crop((0,int(y0*S),int(1280*S),int(y1*S))).resize((W,(y1-y0)), Image.NEAREST)
parts=[("GECE ESKI (1 / 2 / 3 / 5 isik)",crop(eski,250,470)),("GECE YENI",crop(yeni,250,470)),
       ("SPRITE: ust = eski toplamali, alt = yeni yumusak",crop(spr,130,570))]
H=sum(p[1].height+22 for p in parts)
out=Image.new("RGB",(W,H),(20,16,12)); y=0; dr=ImageDraw.Draw(out)
for t,p in parts:
    dr.text((8,y+5),t,fill=(240,220,180)); y+=22; out.paste(p,(0,y)); y+=p.height
out.save(f"{d}/ozet.png"); print(out.size)
