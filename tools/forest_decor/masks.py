import sys; sys.path.insert(0,sys.argv[1]); sys.path.insert(0,__import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from tmxlib import *
import json
root,ts=load()
L={ '/'.join(p):grid(l) for p,l in layers(root)}
def nz(name): return L[name]!=0
def dil(m,r):
    out=m.copy()
    for dy in range(-r,r+1):
        for dx in range(-r,r+1):
            if dx*dx+dy*dy<=r*r+r:
                out|=np.roll(np.roll(m,dy,0),dx,1)
    return out
def label4(m):
    H_,W_=m.shape; lab=np.zeros((H_,W_),int); n=0; sizes=[]
    for y in range(H_):
        for x in range(W_):
            if m[y,x] and lab[y,x]==0:
                n+=1; st=[(y,x)]; lab[y,x]=n; c=0
                while st:
                    cy,cx=st.pop(); c+=1
                    for dy,dx in((1,0),(-1,0),(0,1),(0,-1)):
                        yy,xx=cy+dy,cx+dx
                        if 0<=yy<H_ and 0<=xx<W_ and m[yy,xx] and lab[yy,xx]==0:
                            lab[yy,xx]=n; st.append((yy,xx))
                sizes.append(c)
    return lab,n,sizes
wall=nz('Orman parçaları/Orman parçaları')
water=nz('Su/Su')|nz('Su/Su collisionsuz')|nz('Su/Su altı')
water_core=nz('Su/Su')
bridge=nz('Köprü/Köprü alt')|nz('Köprü/Köprü üst')
house=np.zeros((H,W),bool)
for n_ in ['ev/Blacksmith','ev/blacksmith kapı','ev/Ev ayrıntı','ev/Ev','ev/ev kapı','ev/Ev Çatı 1','ev/baca duman']: house|=nz(n_)
mine=nz('Etkileşimler/Maden')|nz('Etkileşimler/Maden 1')
base=nz('Düşman Üssü/Düşman üssü')|nz('Düşman Üssü/Özel maden')
grass=nz('Yer/Zemin Çimen')
dirt=~grass&~water_core
# existing deco
existing=np.zeros((H,W),bool)
for n_ in ['Shader Eklenecek/Çiçekler 1','Shader Eklenecek/Çalılar','Shader Eklenecek/Çalılar1','Shader Eklenecek/Animasyonsuz çalılar','Shader Eklenecek/Ağaç 0','Shader Eklenecek/Ağaç 1','Shader Eklenecek/Ağaç 2']: existing|=nz(n_)
# other forest layers (decorations)
forest_other=nz('Orman parçaları/Orman parçaları 2')|nz('Orman parçaları/Orman parçaları 3')|nz('Orman parçaları/Orman parçaları 4')|nz('Orman parçaları/orman parçaları -1')
lab,n,sizes=label4(dirt)
big=[(i+1,s) for i,s in enumerate(sizes) if s>=400]
print('dirt comps big',big)
np.savez(sys.argv[1]+'/masks.npz',wall=wall,water=water,water_core=water_core,bridge=bridge,house=house,mine=mine,base=base,grass=grass,dirt=dirt,existing=existing,forest_other=forest_other,dirtlab=lab)
print('wall',wall.sum(),'water',water.sum(),'house',house.sum(),'mine',mine.sum(),'base',base.sum(),'dirt',dirt.sum(),'existing',existing.sum())
# overlay image: 4px per cell
sc=4
img=np.zeros((H*sc,W*sc,3),np.uint8)+np.array([70,150,60],np.uint8)
def paint(m,col):
    mm=np.kron(m,np.ones((sc,sc),bool))
    img[mm]=col
paint(dirt,(150,120,90)); paint(water,(70,110,170)); paint(wall,(60,45,50)); paint(house,(200,60,60)); paint(mine|base,(200,160,40)); paint(bridge,(240,220,120)); paint(existing,(20,100,20)); paint(forest_other&~wall,(90,70,90))
Image.fromarray(img).save(sys.argv[1]+'/masks_overlay.png')
