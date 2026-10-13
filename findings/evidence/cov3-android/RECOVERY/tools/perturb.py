import sys,zlib,struct
# perturb.py <png> <mode>: mode >=2 shifts the red channel by <mode> over rows 300-2100 (pixel-only change); mode 0 = paint a 300x300 black square (large diff), 1 = flip ~0.5% of pixels (pixel-only diff)
# minimal PNG RGBA/RGB 8-bit non-interlaced re-encoder using zlib
p=sys.argv[1]; mode=int(sys.argv[2]); data=open(p,'rb').read(); assert data[:8]==b'\x89PNG\r\n\x1a\n'
pos=8; chunks=[]
while pos<len(data):
    l=struct.unpack('>I',data[pos:pos+4])[0]; t=data[pos+4:pos+8]; c=data[pos+8:pos+8+l]; chunks.append((t,c)); pos+=12+l
ih=[c for t,c in chunks if t==b'IHDR'][0]; w,h,bd,ct,_,_,il=struct.unpack('>IIBBBBB',ih); assert bd==8 and il==0 and ct in (2,6)
bpp=4 if ct==6 else 3; raw=zlib.decompress(b''.join(c for t,c in chunks if t==b'IDAT')); stride=w*bpp
rows=[]; prev=bytearray(stride); i=0
for y in range(h):
    f=raw[i]; line=bytearray(raw[i+1:i+1+stride]); i+=1+stride
    for x in range(stride):
        a=line[x-bpp] if x>=bpp else 0; b=prev[x]; c=prev[x-bpp] if x>=bpp else 0
        if f==1: line[x]=(line[x]+a)&255
        elif f==2: line[x]=(line[x]+b)&255
        elif f==3: line[x]=(line[x]+((a+b)>>1))&255
        elif f==4:
            pa=abs(b-c); pb=abs(a-c); pc=abs(a+b-2*c); pr=a if pa<=pb and pa<=pc else (b if pb<=pc else c); line[x]=(line[x]+pr)&255
    rows.append(line); prev=line
if mode==0:
    for y in range(900,1200):
        for x in range(300,600): rows[y][x*bpp:x*bpp+3]=b'\x00\x00\x00'
elif mode>=2:
    d=mode
    for y in range(300,2100):
        r=rows[y]
        for x in range(0,w):
            i=x*bpp
            r[i]=min(255,r[i]+d) if r[i]<128 else r[i]-d
else:
    n=0
    for y in range(400,2000,7):
        for x in range(0,w,9):
            rows[y][x*bpp:x*bpp+3]=bytes(255-v for v in rows[y][x*bpp:x*bpp+3]); n+=1
out=zlib.compress(b''.join(b'\x00'+bytes(r) for r in rows),6)
def ch(t,c): return struct.pack('>I',len(c))+t+c+struct.pack('>I',zlib.crc32(t+c)&0xffffffff)
open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',ih)+ch(b'IDAT',out)+ch(b'IEND',b''))
print('perturbed',p,'mode',mode)
