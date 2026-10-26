# Regenerates DuoAirHockey/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024px, no alpha).
# Usage: python3 docs/duo-air-hockey/make_icon.py DuoAirHockey/Assets.xcassets/AppIcon.appiconset/AppIcon.png  (needs Pillow)
import sys
from PIL import Image, ImageDraw, ImageFilter
S=4096; k=S/1024
def r(v): return int(v*k)
img=Image.new("RGB",(S,S),(8,18,34))
d=ImageDraw.Draw(img)
# vertical gradient background
for y in range(S):
    t=y/S
    c=(int(10+8*t),int(22+10*t),int(44+18*t))
    d.line([(0,y),(S,y)],fill=c)
# rink
d.rounded_rectangle([r(120),r(70),r(904),r(954)],radius=r(150),fill=(14,32,58),outline=(200,220,255),width=r(14))
# fold / center line: a hinge seam with dashes
d.rectangle([r(120),r(504),r(904),r(520)],fill=(4,10,20))
for x in range(140,890,56):
    d.rounded_rectangle([r(x),r(506),r(x+32),r(518)],radius=r(5),fill=(235,240,255))
d.ellipse([r(392),r(392),r(632),r(632)],outline=(200,220,255),width=r(10))
# goals
d.rounded_rectangle([r(392),r(64),r(632),r(96)],radius=r(14),fill=(52,152,255))
d.rounded_rectangle([r(392),r(928),r(632),r(960)],radius=r(14),fill=(255,70,78))
glow=Image.new("RGB",(S,S),(0,0,0)); g=ImageDraw.Draw(glow)
def mallet(cx,cy,col,dd):
    R=105
    dd.ellipse([r(cx-R),r(cy-R),r(cx+R),r(cy+R)],fill=col,outline=(255,255,255),width=r(10))
    dd.ellipse([r(cx-48),r(cy-48),r(cx+48),r(cy+48)],fill=tuple(int(c*0.7) for c in col))
g.ellipse([r(330-150),r(260-150),r(330+150),r(260+150)],fill=(30,90,170))
g.ellipse([r(700-150),r(770-150),r(700+150),r(770+150)],fill=(170,40,50))
g.ellipse([r(560-90),r(440-90),r(560+90),r(440+90)],fill=(120,120,120))
glow=glow.filter(ImageFilter.GaussianBlur(r(40)))
from PIL import ImageChops
img=ImageChops.add(img,glow)
d=ImageDraw.Draw(img)
mallet(330,260,(52,152,255),d)
mallet(700,770,(255,70,78),d)
# motion lines behind the puck, pointing back at the red mallet
import math
ux,uy=140/358.5,330/358.5; px,py=-uy,ux
for off,start,ln in ((-28,62,80),(0,58,130),(28,62,80)):
    sx=560+ux*start+px*off; sy=440+uy*start+py*off
    d.line([(r(sx),r(sy)),(r(sx+ux*ln),r(sy+uy*ln))],fill=(170,190,220),width=r(11))
d.ellipse([r(516),r(396),r(604),r(484)],fill=(240,244,250))
d.ellipse([r(536),r(416),r(584),r(464)],outline=(150,160,175),width=r(6))
img=img.resize((1024,1024),Image.LANCZOS)
img.save(sys.argv[1])
