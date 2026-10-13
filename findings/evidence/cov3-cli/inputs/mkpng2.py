# mkpng2.py <path> <w> <h> <n-changed-pixels>: grey image with the first n pixels of row 0 set to pure red
import sys,zlib,struct
p,w,h,n=sys.argv[1],*map(int,sys.argv[2:5])
rows=[]
for y in range(h):
    r=b''
    for x in range(w): r+= bytes((255,0,0)) if (y==0 and x<n) else bytes((128,128,128))
    rows.append(b'\x00'+r)
def ch(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(b''.join(rows)))+ch(b'IEND',b''))
