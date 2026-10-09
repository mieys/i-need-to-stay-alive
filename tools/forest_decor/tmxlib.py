import os, sys, xml.etree.ElementTree as ET
import numpy as np
from PIL import Image
sys.stdout.reconfigure(encoding='utf-8')
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'harita'))
W=H=256; T=16
class Tilesets:
    def __init__(self, root):
        self.list=[]  # (firstgid, name, img, cols, count)
        for e in root.findall('tileset'):
            fg=int(e.get('firstgid')); src=e.get('source')
            p=os.path.join(ROOT,src)
            if not os.path.exists(p): continue
            try: tr=ET.parse(p).getroot()
            except Exception as ex:
                print('TSX PARSE FAIL',src,ex); continue
            im=tr.find('image')
            if im is None: continue
            ip=os.path.normpath(os.path.join(os.path.dirname(p), im.get('source')))
            if not os.path.exists(ip): continue
            img=Image.open(ip).convert('RGBA')
            self.list.append((fg,src,img,int(tr.get('columns')),int(tr.get('tilecount'))))
        self.list.sort(key=lambda x:x[0])
        self.cache={}
    def find(self,gid):
        best=None
        for t in self.list:
            if t[0]<=gid: best=t
        return best
    def tile(self,gid):
        raw=gid
        g=gid&0x0FFFFFFF
        fh=bool(gid&0x80000000); fv=bool(gid&0x40000000); fd=bool(gid&0x20000000)
        key=(g,fh,fv,fd)
        if key in self.cache: return self.cache[key]
        t=self.find(g)
        res=None
        if t:
            fg,src,img,cols,cnt=t
            i=g-fg
            if 0<=i<cnt:
                x=(i%cols)*T; y=(i//cols)*T
                res=img.crop((x,y,x+T,y+T))
                if fd: res=res.transpose(Image.TRANSPOSE)
                if fh: res=res.transpose(Image.FLIP_LEFT_RIGHT)
                if fv: res=res.transpose(Image.FLIP_TOP_BOTTOM)
        self.cache[key]=res
        return res

def load(path=None):
    path=path or os.environ.get('HARITA_TMX') or os.path.join(ROOT,'Harita.tmx')
    tree=ET.parse(path); root=tree.getroot()
    return root, Tilesets(root)

def layers(root):
    """yield (path, layer element) in document order"""
    def walk(el,pre):
        for c in el:
            if c.tag=='group':
                yield from walk(c,pre+[c.get('name')])
            elif c.tag=='layer':
                yield pre+[c.get('name')], c
    yield from walk(root,[])

def grid(layer):
    d=layer.find('data')
    return np.array([int(x) for x in d.text.replace('\n','').split(',') if x.strip()],dtype=np.int64).reshape(H,W)

def render(root,ts,skip=lambda p:False,region=None,visible_only=True):
    x0,y0,x1,y1=region or (0,0,W,H)
    out=Image.new('RGBA',((x1-x0)*T,(y1-y0)*T),(0,0,0,255))
    for path,l in layers(root):
        if visible_only and l.get('visible')=='0': continue
        if skip(path): continue
        g=grid(l)
        op=float(l.get('opacity','1'))
        lay=Image.new('RGBA',out.size,(0,0,0,0))
        ys,xs=np.nonzero(g[y0:y1,x0:x1])
        for y,x in zip(ys,xs):
            t=ts.tile(int(g[y0+y,x0+x]))
            if t: lay.alpha_composite(t,(int(x*T),int(y*T)))
        if op<1:
            a=lay.getchannel('A').point(lambda v:int(v*op)); lay.putalpha(a)
        out.alpha_composite(lay)
    return out
