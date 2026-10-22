import json, subprocess, tempfile, re
from pathlib import Path
from PIL import Image
import zxingcpp
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','native'],cwd=root,check=True)
candidates=[p for p in (root/'_build').rglob('*') if p.is_file() and p.name in ('main.exe','main') and p.parent.name=='main']
assert candidates,'native CLI not found'
exe=max(candidates,key=lambda p:p.stat().st_mtime)
def run(args,code=0):
 p=subprocess.run([str(exe),*map(str,args)],capture_output=True,encoding='utf8')
 assert p.returncode==code,(args,p.returncode,p.stderr)
 if code:assert not p.stdout and p.stderr
 return p

def decode_svg(svg):
 box=re.search(r'viewBox="0 0 (\d+) (\d+)"',svg);w,h=map(int,box.groups())
 im=Image.new('L',(w*6,h*6),255)
 for x,y in re.findall(r'M(\d+) (\d+)h1v1h-1z',svg):
  x=int(x);y=int(y);im.paste(0,(x*6,y*6,(x+1)*6,(y+1)*6))
 r=zxingcpp.read_barcode(im,formats=zxingcpp.BarcodeFormat.DataMatrix)
 assert r is not None
 return r
with tempfile.TemporaryDirectory() as td:
 d=Path(td);output=d/'single.svg'
 p=run(['encode','--text','中文🙂','--output',output]);assert not p.stdout
 assert decode_svg(output.read_text()).text=='中文🙂', repr(decode_svg(output.read_text()).text)
 before=output.read_bytes();run(['encode','--text','new','--output',output],4);assert output.read_bytes()==before
 run(['encode','--hex','0Z','--output',output],3);assert output.read_bytes()==before
 run(['encode','--text','a','--hex','00'],2)
 run(['encode','--text','a','--size','11x11'],2)
 run(['encode','--text-file',d/'missing'],4)
 bad=d/'bad.txt';bad.write_bytes(b'\xff');run(['encode','--text-file',bad],3)
 binary=d/'binary.bin';binary.write_bytes(bytes(range(256)))
 assert decode_svg(run(['encode','--binary-file',binary]).stdout).bytes==bytes(range(256))
 inp=d/'batch.jsonl';dest=d/'labels'
 inp.write_text('\n'.join(json.dumps(x) for x in [{'id':'asset-1','text':'ASSET-001'},{'id':'asset-2','hex':'00ff01'}]),encoding='utf8')
 run(['batch','--input',inp,'--output',dest]);assert len(list(dest.glob('*.svg')))==2
 run(['batch','--input',inp,'--output',dest],4)
 for rows in [[{'id':'ok','text':'abc'},{'id':'bad/../','text':'abc'}],[{'id':'a','text':'x'},{'id':'A','hex':'00'}],[{'id':'a','text':'x','extra':1}],[{'id':'CON','text':'x'}]]:
  inp.write_text('\n'.join(json.dumps(x) for x in rows),encoding='utf8');target=d/'failed'
  run(['batch','--input',inp,'--output',target],3);assert not target.exists()
 assert not list(d.glob('*.tmp-*'))
print('CLI success, error codes, no-clobber, batch rollback and SVG round trips passed')

