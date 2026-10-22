"""Generate temporary whitebox tests against the pinned Rust upstream."""
import json, random, subprocess, os, shutil, sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
cargo=shutil.which('cargo') or str(Path.home()/'.cargo/bin/cargo.exe')
subprocess.run([cargo,'build','--release','--locked','--manifest-path',str(root/'tests/reference/Cargo.toml')],check=True)
exe=root/'tests/reference/target/release'/('moondatamatrix-reference.exe' if os.name=='nt' else 'moondatamatrix-reference')
rng=random.Random(20261022)
cases=[]
for text in ['', 'A','ABC','abcdef','ABC>ABC123>ABCDE','AIMAIMAIMAIMAI','DEABCFG','CP0*','[]ABC01','中文🙂','Hello, World!']:
 for eci in [0,1]:cases.append((0,0,eci,text.encode()))
for size in [10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144]:cases.append((size,size,0,b'A'))
for w,h in [(18,8),(32,8),(26,12),(36,12),(36,16),(48,16)]:cases.append((w,h,0,b'ABC'))
for n in [1,2,3,4,5,6,7,8,9,10,11,12,14,16,20,31,40,62,100,249,250,251,512,1555]:
 for alphabet in [b'ABCDEFGHIJKLMNOPQRSTUVWXYZ', b'abcdefghijklmnopqrstuvwxyz',b'0123456789',b'@^?;><* ABC123',bytes(range(256))]:
  cases.append((0,0,n%2,bytes(rng.choice(alphabet) for _ in range(n))))
if '--quick' in sys.argv:cases=cases[:22]
lines=''.join(f'{w},{h},{eci},{data.hex()}\n' for w,h,eci,data in cases)
ref=subprocess.run([str(exe)],input=lines,capture_output=True,text=True,check=True)
results=[json.loads(line) for line in ref.stdout.splitlines()]
assert len(results)==len(cases)
source=['// Temporary fixtures generated from pinned datamatrix-rs (MIT).']
for i,((w,h,eci,data),r) in enumerate(zip(cases,results)):
 literal='b"'+''.join('\\x%02x'%b for b in data)+'"'
 options='{shape:Square}' if not w else '{shape:Fixed(%d,%d)}'%(w,h)
 source += ['///|',f'test "upstream differential {i}" {{',f'let options : EncodeOptions = {options}', f'let data = {literal}']
 if 'error' in r:
  source += [f'let failed = try {{ let out=planned_codewords(data,{str(bool(eci)).lower()},options);ignore(pad_data(out,options));false }} catch {{_=>true}}','assert_true(failed)','}'];continue
 source += [f'let out = planned_codewords(data,{str(bool(eci)).lower()},options)','let size = pad_data(out,options)',f'assert_eq(out,{r["data"]})',f'assert_eq((size.width,size.height),({r["width"]},{r["height"]}))','for b in error_code(out,size) {out.push(b)}',f'assert_eq(out,{r["codewords"]})','let symbol=place(out,size)','let bits=symbol.matrix().map(fn(row){row.map(fn(v){if v {"1"} else {"0"}}).join("")}).join("")',f'assert_eq(bits,"'+''.join('1' if b else '0' for b in r['bits'])+'")','}']
path=root/'differential_generated_wbtest.mbt'
try:
 path.write_text('\n'.join(source),encoding='utf8')
 proc=subprocess.run(['moon','test','--target','native','--deny-warn','--filter','upstream differential*'],cwd=root,text=True,capture_output=True)
 (root/'test-results').mkdir(exist_ok=True)
 (root/'test-results/differential.log').write_text(proc.stdout+proc.stderr,encoding='utf8')
 print(proc.stdout[-6000:]);print(proc.stderr[-2000:])
 if proc.returncode:raise SystemExit(proc.returncode)
 print(f'Exact upstream differential cases passed: {len(cases)}')
finally:path.unlink(missing_ok=True)
