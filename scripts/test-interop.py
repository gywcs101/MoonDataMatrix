"""Original deterministic fixtures; ZXing-C++ is independent of the port source."""
import json, random, subprocess, tempfile
from pathlib import Path
from PIL import Image
import zxingcpp
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','js'],cwd=root,check=True)
bridge=next((root/'_build').rglob('webbridge.js'))
rng=random.Random(20261022)
cases=[dict(input=t,hex=False) for t in ['Hello, World!', '中文样本🙂', ' A\nB\r\n', '\ufeffABC','A'*200,'a'*200,'*>ABC123\r'*40,'@^?;:'+ '@^?;'*80]]
cases += [dict(input=bytes(range(256)).hex(),hex=True),dict(input=bytes(rng.randrange(256) for _ in range(1555)).hex(),hex=True)]
sizes=[(n,n) for n in [10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144]]+[(18,8),(32,8),(26,12),(36,12),(36,16),(48,16)]
cases += [dict(input=(b'1'*3116).hex(),hex=True)]
cases += [dict(input='41',hex=True,shape='fixed',width=w,height=h) for w,h in sizes]
for n in [1,2,3,4,5,10,31,249,250,251,512]:
 cases.append(dict(input=bytes(rng.randrange(256) for _ in range(n)).hex(),hex=True))
with tempfile.TemporaryDirectory() as td:
 inp=Path(td)/'in.json';out=Path(td)/'out.json';inp.write_text(json.dumps(cases),encoding='utf8')
 subprocess.run(['node',str(root/'scripts/interop.mjs'),str(bridge),str(inp),str(out)],check=True)
 for i,c in enumerate(json.loads(out.read_text(encoding='utf8'))):
  r=c['result'];assert 'error' not in r,(i,r)
  rows=r['matrix'];w=r['width'];h=r['height'];scale=6;q=3
  im=Image.new('L',((w+2*q)*scale,(h+2*q)*scale),255)
  for y,row in enumerate(rows):
   for x,v in enumerate(row):
    if v:im.paste(0,((x+q)*scale,(y+q)*scale,(x+q+1)*scale,(y+q+1)*scale))
  decoded=zxingcpp.read_barcode(im,formats=zxingcpp.BarcodeFormat.DataMatrix)
  expected=bytes.fromhex(c['input']) if c['hex'] else c['input'].encode('utf8')
  assert decoded is not None,(i,'undecodable',w,h)
  assert decoded.bytes==expected,(i,decoded.bytes,expected)
  if not c['hex']:assert decoded.text==c['input'],(i,decoded.text,c['input'])
print(f'Independent ZXing-C++ round trips passed: {len(cases)}')

