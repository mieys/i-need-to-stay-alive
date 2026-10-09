import sys; sys.path.insert(0,sys.argv[1]); sys.path.insert(0,__import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from tmxlib import *
tmx=sys.argv[2]; tag=sys.argv[3]
root,ts=load(tmx)
im=render(root,ts).convert('RGB')
im.resize((1024,1024),Image.LANCZOS).save(f"{sys.argv[1]}/{tag}_1024.png")
im.save(f"{sys.argv[1]}/{tag}_full.png")
regs={'a':(50,30,130,80),'b':(0,170,80,230),'c':(150,150,230,210),'d':(150,0,230,50)}
for k,(x0,y0,x1,y1) in regs.items():
    im.crop((x0*16,y0*16,x1*16,y1*16)).save(f"{sys.argv[1]}/{tag}_crop_{k}.png")
print('ok')
