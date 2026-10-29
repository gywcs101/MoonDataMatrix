"""Generate strict ECI maps from CPython codecs; see THIRD_PARTY_NOTICES.md."""
from pathlib import Path
import sys, json
if sys.version_info[:3] != (3, 13, 5):
    raise SystemExit('Mapping generation requires CPython 3.13.5')
root = Path(__file__).resolve().parents[1]
(root/'charset').mkdir(exist_ok=True)
codecs = {2:'cp437',3:'latin1',**{i+2:'iso8859_'+str(i) for i in range(2,12)},**{i+2:'iso8859_'+str(i) for i in range(13,17)},20:'shift_jis',21:'cp1250',22:'cp1251',23:'cp1252',24:'cp1256',27:'ascii',28:'big5',29:'gb2312',30:'euc_kr',31:'gbk',32:'gb18030'}
def literal(blob):
    return 'join_bytes([\n'+',\n'.join('b"'+''.join('\\x%02x'%b for b in blob[i:i+2048])+'"' for i in range(0,len(blob),2048))+'\n])'
def packed(items, kb, vb):
    return b''.join(k.to_bytes(kb,'big')+v.to_bytes(vb,'big') for k,v in items)
for eci, codec in codecs.items():
    dec = {}
    for n in range(65536 if eci in [20,28,29,30,31,32] else 256):
        b = n.to_bytes(1 if n < 256 else 2,'big')
        try:
            t = b.decode(codec,'strict')
            if len(t)==1: dec[n]=ord(t)
        except UnicodeError: pass
    enc = {}
    for cp in set(dec.values()):
        try:
            b = chr(cp).encode(codec,'strict')
            if len(b)<=2 and b.decode(codec,'strict') == chr(cp): enc[cp]=int.from_bytes(b,'big')
        except UnicodeError: pass
    (root/f'charset/table_{eci}.mbt').write_text('// Generated from CPython '+sys.version.split()[0]+' '+codec+' codec; PSF license.\n///|\nlet decode_'+str(eci)+' : Bytes = '+literal(packed(sorted(dec.items()),2,3))+'\n///|\nlet encode_'+str(eci)+' : Bytes = '+literal(packed(sorted(enc.items()),3,2))+'\n')
ranges=[]
start=None
lastcp=lastp=-2
for pointer in range(126*10*126*10):
    n=pointer
    d=n%10+48; n//=10; c=n%126+129; n//=126; b=n%10+48; a=n//10+129
    try:
        t=bytes([a,b,c,d]).decode('gb18030','strict')
        if len(t)!=1: continue
        cp=ord(t)
    except UnicodeError: continue
    if pointer!=lastp+1 or cp!=lastcp+1:
        if start is not None: ranges.append((start,startcp,lastp-start+1))
        start=pointer; startcp=cp
    lastp=pointer; lastcp=cp
if start is not None: ranges.append((start,startcp,lastp-start+1))
(root/'charset/gb_ranges.mbt').write_text('// CPython GB18030 mapping ranges; PSF license.\n///|\nlet gb_ranges : Array[(Int,Int,Int)] = '+str(ranges)+'\n')
(root/'charset/tables.mbt').write_text('///|\nfn tables(eci : Int) -> (Bytes, Bytes) raise CharsetError {\n match eci {\n'+''.join(f' {e} => (decode_{e}, encode_{e})\n' for e in codecs)+' _ => raise UnsupportedEci(eci)\n }\n}\n')
(root/'charset/SOURCES.json').write_text(json.dumps({'generator':'scripts/generate-charsets.py','python':sys.version,'source':'https://github.com/python/cpython/tree/v3.13.5','license':'PSF-2.0 and included historical notices','codecs':codecs},indent=2)+'\n')
print('Generated',len(codecs),'ECI maps and',len(ranges),'GB18030 ranges')
