import subprocess,zipfile,hashlib,json
from pathlib import Path
from release_metadata import release_info, module_identity
root=Path(__file__).resolve().parents[1]
name,version,archive_path=release_info()
subprocess.run(['moon','package'],cwd=root,check=True)
if not archive_path.is_file():
 raise FileNotFoundError(f'Expected current release archive: {archive_path}')
with zipfile.ZipFile(archive_path) as archive:
 names=set(archive.namelist())
 required={'decode.mbt','decode_ecc.mbt','message.mbt','append.mbt','charset/charset.mbt','charset/table_32.mbt','charset/SOURCES.json','protocol/protocol.mbt','LICENSES/Python.txt','README.md','LICENSE','LICENSES/datamatrix-rs-MIT.txt','LICENSES/Apache-2.0.txt','LICENSES/moonbit-core-NOTICE.txt','THIRD_PARTY_NOTICES.md','MIGRATION.md','moon.mod','moon.pkg','planner.mbt','encoder_context.mbt','cmd/main/atomic.c','examples/assets.jsonl','examples/basic/main.mbt','web/index.html','webbridge/bridge.mbt'}
 assert required <= names,required-names
 forbidden={'node_modules','target','_build','.git','.mooncakes','test-results','research','__pycache__'}
 assert not {'SUBMISSION.md','AGENTS.md'}.intersection(names)
 for entry in names:
  path=Path(entry);assert not path.is_absolute() and '..' not in path.parts,entry
  assert not forbidden.intersection(path.parts),entry
  assert not any(s in entry.lower() for s in ['credentials','rustup-init','.env']),entry
 manifest=archive.read('moon.mod').decode()
 assert module_identity(manifest) == (name,version), 'Archive module identity does not match moon.mod'
 assert archive.testzip() is None, 'Archive contains a corrupt file'
 assert 'scripts/release_metadata.py' in names
 assert {'append_message.mbt','examples/mixed-append.json','examples/gs1-batch.jsonl'} <= names
print('Package contents, licenses, source mapping and artifact exclusions passed')
inventory={'module':name,'version':version,'archive':archive_path.name,'sha256':hashlib.sha256(archive_path.read_bytes()).hexdigest(),'files':sorted(names)}
(archive_path.parent/'release-inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2),encoding='utf8')
