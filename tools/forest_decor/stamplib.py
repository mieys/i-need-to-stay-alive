import sys
from tmxlib import *
import numpy as np
from PIL import Image

def label8(m):
    H_,W_=m.shape; lab=np.zeros((H_,W_),int); n=0
    for y in range(H_):
        for x in range(W_):
            if m[y,x] and lab[y,x]==0:
                n+=1; st=[(y,x)]; lab[y,x]=n
                while st:
                    cy,cx=st.pop()
                    for dy in(-1,0,1):
                        for dx in(-1,0,1):
                            yy,xx=cy+dy,cx+dx
                            if 0<=yy<H_ and 0<=xx<W_ and m[yy,xx] and lab[yy,xx]==0:
                                lab[yy,xx]=n; st.append((yy,xx))
    return lab,n

class Lib:
    def __init__(self, ts):
        self.ts=ts
        self.sets={}
        for fg,src,img,cols,cnt in ts.list:
            self.sets[src]=self._analyze(fg,src,img,cols,cnt)
    def _analyze(self,fg,src,img,cols,cnt):
        a=np.array(img.getchannel('A'))
        m=a>30
        lab,n=label8(m)
        boxes=[]
        for i in range(1,n+1):
            ys,xs=np.nonzero(lab==i)
            boxes.append({'ids':[i],'x0':xs.min(),'y0':ys.min(),'x1':xs.max(),'y1':ys.max(),'n':len(ys)})
        big=[b for b in boxes if b['n']>=60]
        for s in [b for b in boxes if b['n']<60]:
            best=None;bd=99
            for b in big:
                dx=max(b['x0']-s['x1'],s['x0']-b['x1'],0); dy=max(b['y0']-s['y1'],s['y0']-b['y1'],0)
                dd=max(dx,dy)
                if dd<bd: bd=dd;best=b
            if best is not None and bd<=4:
                best['ids']+=s['ids']; best['x0']=min(best['x0'],s['x0']);best['y0']=min(best['y0'],s['y0'])
                best['x1']=max(best['x1'],s['x1']);best['y1']=max(best['y1'],s['y1']);best['n']+=s['n']
        big.sort(key=lambda b:(b['y0']//(T*2),b['x0']))
        return {'fg':fg,'img':img,'cols':cols,'lab':lab,'comps':big,'alpha':a}
    def stamp(self,src,cid):
        S=self.sets[src]; c=S['comps'][cid]
        lab=S['lab']; a=S['alpha']; cols=S['cols']; fg=S['fg']
        tx0,ty0,tx1,ty1=c['x0']//T,c['y0']//T,c['x1']//T,c['y1']//T
        w,h=tx1-tx0+1,ty1-ty0+1
        idset=set(c['ids'])
        tiles=[]; contam=0
        pix=np.zeros((h*T,w*T),np.uint8)  # alpha of this sprite only
        rgba=np.zeros((h*T,w*T,4),np.uint8)
        arr=np.array(S['img'])
        for j in range(h):
            for i in range(w):
                ty,tx=ty0+j,tx0+i
                blk=lab[ty*T:(ty+1)*T,tx*T:(tx+1)*T]
                mine=np.isin(blk,list(idset))
                other=(blk>0)&~mine
                if mine.any():
                    tiles.append((i,j,fg+ty*cols+tx))
                    contam+=int(other.sum())
                    sub=arr[ty*T:(ty+1)*T,tx*T:(tx+1)*T].copy()
                    sub[~mine&(sub[...,3]>0)&(blk>0)]=0   # drop neighbour sprite pixels
                    rgba[j*T:(j+1)*T,i*T:(i+1)*T]=sub
                    pix[j*T:(j+1)*T,i*T:(i+1)*T]=sub[...,3]
        return {'src':src,'id':cid,'w':w,'h':h,'tiles':tiles,'contam':contam,'alpha':pix,'rgba':rgba}

BAND=9.0; FEET=15.0; MINPX=20; OPAQ=0.4
def footprint(st):
    """cells (dx,dy) rel. to stamp top-left cell that become collision cells (terrain_collision.gd rules)"""
    a=st['alpha']/255.0
    op=a>=OPAQ
    rows=np.nonzero(op.any(axis=1))[0]
    if len(rows)==0: return set(), 0
    base=rows.max()+1   # root y in stamp px
    counts={}
    y0=max(0,int(np.ceil(base-BAND))); y1=int(base)-1
    for y in range(y0,y1+1):
        for x in np.nonzero(op[y])[0]:
            wy=y+0.5-FEET
            cell=(int(x//T), int(np.floor(wy/T)))
            counts[cell]=counts.get(cell,0)+1
    fp={c for c,n in counts.items() if n>=MINPX}
    return fp, base
