import subprocess,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','package'],cwd=root,check=True)
archives=list((root/'_build/publish').glob('gywcs101-MoonDataMatrix-0.1.0.zip'))
assert len(archives)==1
with zipfile.ZipFile(archives[0]) as archive:
 names=set(archive.namelist())
 required={'README.md','LICENSE','LICENSES/datamatrix-rs-MIT.txt','LICENSES/Apache-2.0.txt','LICENSES/moonbit-core-NOTICE.txt','THIRD_PARTY_NOTICES.md','MIGRATION.md','moon.mod','moon.pkg','planner.mbt','encoder_context.mbt','cmd/main/atomic.c','examples/assets.jsonl','examples/basic/main.mbt','web/index.html','webbridge/bridge.mbt'}
 assert required <= names,required-names
 forbidden={'node_modules','target','_build','.git','.mooncakes','test-results','research','__pycache__'}
 for name in names:
  path=Path(name);assert not path.is_absolute() and '..' not in path.parts,name
  assert not forbidden.intersection(path.parts),name
  assert not any(s in name.lower() for s in ['credentials','rustup-init','.env']),name
 manifest=archive.read('moon.mod').decode()
 assert 'gywcs101/MoonDataMatrix' in manifest and '0.1.0' in manifest
print('Package contents, licenses, source mapping and artifact exclusions passed')
