"""Original protocol fixtures and independent ZXing-C++ bidirectional checks."""
import json, subprocess, tempfile
from pathlib import Path
from PIL import Image
import zxingcpp
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','native','--target-dir',str(root/'_build')],cwd=root,check=True)
exe=max((p for p in (root/'_build').rglob('*') if p.is_file() and p.name in ('main.exe','main') and p.parent.name=='main'),key=lambda p:p.stat().st_mtime)
def call(args,code=0):
 p=subprocess.run([str(exe),*map(str,args)],capture_output=True,encoding='utf8')
 assert p.returncode==code,(args,p.returncode,p.stderr)
 return p.stdout

def raster(rows):
 h=len(rows);w=len(rows[0]);im=Image.new('L',((w+4)*6,(h+4)*6),255)
 for y,row in enumerate(rows):
  for x,v in enumerate(row):
   if v:im.paste(0,((x+2)*6,(y+2)*6,(x+3)*6,(y+3)*6))
 return im
with tempfile.TemporaryDirectory() as td:
 d=Path(td);f=d/'request.json'
 def request(value):
  f.write_text(json.dumps(value,ensure_ascii=False),encoding='utf8')
  return json.loads(call(['message','--input',f]))
 samples=[(3,'café'),(20,'日本語'),(25,'中文🙂'),(26,'中文🙂'),(28,'中文'),(29,'中文'),(30,'한국어'),(31,'中文'),(32,'中文🙂'),(33,'中文🙂'),(34,'中文🙂'),(35,'中文🙂')]
 for eci,text in samples:
  result=request({'segments':[{'text':text,'eci':eci}]})['symbols'][0]
  assert result['decoded']['text']==text
  decoded=zxingcpp.read_barcode(raster(result['matrix']),formats=zxingcpp.BarcodeFormat.DataMatrix)
  assert decoded is not None,(eci,'missing decode')
  codec={3:'latin1',20:'shift_jis',25:'utf-16-be',26:'utf8',28:'big5',29:'gb2312',30:'euc_kr',31:'gbk',32:'gb18030',33:'utf-16-le',34:'utf-32-be',35:'utf-32-le'}[eci]
  assert decoded.bytes==text.encode(codec),(eci,decoded.bytes)
  assert decoded.bytes.decode(codec)==text
  if eci not in [31,32,33,34,35]:assert decoded.text==text,(eci,decoded.text,text)
 multi=request({'segments':[{'text':'中文','eci':29},{'text':'日本語','eci':20},{'text':'🙂','eci':32}]})['symbols'][0]
 assert multi['decoded']['text']=='中文日本語🙂'
 gs=request({'gs1':True,'segments':[{'hex':b'010123456789012810BATCH'.hex()},{'fnc1':True},{'hex':b'21SERIAL'.hex()}]})['symbols'][0]
 assert gs['decoded']['gs1']
 read=zxingcpp.read_barcode(raster(gs['matrix']),formats=zxingcpp.BarcodeFormat.DataMatrix)
 assert read and read.bytes==b'010123456789012810BATCH\x1d21SERIAL'
 for macro in [5,6]:
  result=request({'macro':macro,'segments':[{'hex':'414243'}]})['symbols'][0]
  read=zxingcpp.read_barcode(raster(result['matrix']),formats=zxingcpp.BarcodeFormat.DataMatrix)
  assert read and read.bytes==b'[)>\x1e0'+str(macro).encode()+b'\x1dABC\x1e\x04'
 long='中文🙂'*30
 result=request({'split':True,'text':long,'shape':'fixed','width':26,'height':26})
 assert 1<len(result['symbols'])<=16
 for symbol in result['symbols']:
  read=zxingcpp.read_barcode(raster(symbol['matrix']),formats=zxingcpp.BarcodeFormat.DataMatrix)
  assert read and read.bytes==bytes.fromhex(symbol['decoded']['hex'])
 result['symbols'].reverse();f.write_text(json.dumps(result),encoding='utf8')
 assert json.loads(call(['assemble','--input',f]))['text']==long
 # Reject incomplete, duplicate, and mixed-file sets without producing output.
 for symbols in [result['symbols'][:-1], [result['symbols'][0]]*len(result['symbols'])]:
  f.write_text(json.dumps({'symbols':symbols}),encoding='utf8')
  call(['assemble','--input',f],3)
 other=request({'split':True,'text':long,'shape':'fixed','width':26,'height':26,'file_id1':2})
 mixed=result['symbols'].copy();mixed[0]=other['symbols'][-1]
 f.write_text(json.dumps({'symbols':mixed}),encoding='utf8')
 call(['assemble','--input',f],3)
 # Independent encoder -> MoonBit decoder, including damaged payload modules.
 for text in ['ABC123','中文🙂','a'*120,bytes(range(256))]:
  image=zxingcpp.write_barcode(zxingcpp.BarcodeFormat.DataMatrix,text,quiet_zone=0)
  rows=[[pixel==0 for pixel in row] for row in memoryview(image).tolist()]
  expected=text.encode() if isinstance(text,str) else text
  for damaged in [False,True]:
   if damaged:rows[1][1]=not rows[1][1]
   f.write_text(json.dumps({'matrix':rows}),encoding='utf8')
   read=json.loads(call(['decode','--input',f]))
   assert bytes.fromhex(read['hex'])==expected,(text,read)
   if damaged:assert read['corrected_codewords']==1
 for bad in [{'segments':[{'eci':1000000}]},{'segments':[],'reader_programming':True,'gs1':True},{'segments':[{'text':'🙂','eci':29}]},{'segments':[],'append':{'index':1,'count':1,'file_id1':1,'file_id2':1}},{'segments':[{'text':'a','extra':1}]}]:
  f.write_text(json.dumps(bad),encoding='utf8');call(['message','--input',f],3)
 # Mixed ECI automatic splitting: independent per-symbol byte recovery.
 segments=[{'text':'中文'*12,'eci':29},{'text':'日本語'*8,'eci':20},{'text':'🙂'*6,'eci':26}]
 mixed_request={'split':True,'segments':segments,'shape':'fixed','width':26,'height':26}
 mixed=request(mixed_request)
 assert 1<len(mixed['symbols'])<=16
 recovered=b''
 for symbol in mixed['symbols']:
  read=zxingcpp.read_barcode(raster(symbol['matrix']),formats=zxingcpp.BarcodeFormat.DataMatrix)
  assert read and read.bytes==bytes.fromhex(symbol['decoded']['hex'])
  recovered+=read.bytes
 assert recovered==('中文'*12).encode('gb2312')+('日本語'*8).encode('shift_jis')+('🙂'*6).encode()
 f.write_text(json.dumps({'symbols':list(reversed(mixed['symbols']))}),encoding='utf8')
 assert json.loads(call(['assemble','--input',f]))['text']=='中文'*12+'日本語'*8+'🙂'*6
 batch=d/'batch.jsonl';out=d/'labels'
 gs_message={'gs1':True,'segments':[{'text':'010123456789012810BATCH','eci':3},{'fnc1':True},{'text':'21SERIAL','eci':3}]}
 batch.write_text('\n'.join(json.dumps(x) for x in [{'id':'gs1','message':gs_message},{'id':'mixed','message':mixed_request}]),encoding='utf8')
 call(['batch','--input',batch,'--output',out])
 assert (out/'gs1.svg').exists() and (out/'mixed/part-01.svg').exists()
 f.write_text(json.dumps(json.loads((out/'gs1.json').read_text())['symbols'][0]),encoding='utf8')
 gs_read=json.loads(call(['decode','--input',f]));assert gs_read['gs1'] and len(gs_read['fnc1_positions'])==1
 call(['batch','--input',batch,'--output',out],4)
 batch.write_text(batch.read_text()+'\n'+json.dumps({'id':'bad','message':{'segments':[{'eci':1000000}]}}),encoding='utf8')
 call(['batch','--input',batch,'--output',d/'badlabels'],3);assert not (d/'badlabels').exists()
 # Literal GS is preserved as data, not mistaken for FNC1 metadata.
 literal=request({'segments':[{'hex':'411d42'}]})['symbols'][0]['decoded']
 assert literal['hex']=='411d42' and literal['fnc1_positions']==[]
print('Extended ECI, GS1, Macro, append, strict inputs and external-encoder decoding passed')
