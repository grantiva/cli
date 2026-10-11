# writes a solid-colour RGB PNG: mkpng.py <path> <w> <h> <r> <g> <b>
import sys,zlib,struct
p,w,h,r,g,b=sys.argv[1],*map(int,sys.argv[2:7])
raw=b''.join(b'\x00'+bytes((r,g,b))*w for _ in range(h))
def ch(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw))+ch(b'IEND',b''))
