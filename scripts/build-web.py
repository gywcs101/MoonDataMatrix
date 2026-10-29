import subprocess, shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','js'],cwd=root,check=True)
files=list((root/'_build').rglob('webbridge.js'))
assert files,'compiled JS bridge missing'
source=max(files,key=lambda p:p.stat().st_mtime)
shutil.copyfile(source,root/'web/core.js')
licenses=root/'web/licenses'
licenses.mkdir(exist_ok=True)
shutil.copyfile(root/'LICENSE',licenses/'PROJECT-MIT.txt')
shutil.copyfile(root/'THIRD_PARTY_NOTICES.md',licenses/'THIRD_PARTY_NOTICES.md')
for name in ['datamatrix-rs-MIT.txt','Apache-2.0.txt','moonbit-core-NOTICE.txt','Python.txt']:
 shutil.copyfile(root/'LICENSES'/name,licenses/name)
(licenses/'README.txt').write_text('MoonDataMatrix: PROJECT-MIT.txt\nPorted algorithms: datamatrix-rs-MIT.txt\nCharacter-set mapping data: Python.txt\nMoonBit standard library: Apache-2.0.txt and moonbit-core-NOTICE.txt\nSource and scope: THIRD_PARTY_NOTICES.md\n',encoding='utf8')
print('Static demo built in web/. Serve with python -m http.server --directory web 8080')
