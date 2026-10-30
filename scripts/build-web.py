import subprocess, shutil, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','js','--target-dir',str(root/'_build')],cwd=root,check=True)
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
# Content-addressed assets keep cached modules consistent across Pages releases.
site=root/'_build/site'
site.mkdir(parents=True,exist_ok=True)
core=(root/'web/core.js').read_bytes()
core_name='core.'+hashlib.sha256(core).hexdigest()[:16]+'.js'
(site/core_name).write_bytes(core)
app=(root/'web/app.js').read_text(encoding='utf8').replace("'./core.js'",repr('./'+core_name))
app_name='app.'+hashlib.sha256(app.encode('utf8')).hexdigest()[:16]+'.js'
(site/app_name).write_text(app,encoding='utf8')
html=(root/'web/index.html').read_text(encoding='utf8').replace('src="app.js"','src="'+app_name+'"')
(site/'index.html').write_text(html,encoding='utf8')
shutil.copytree(licenses,site/'licenses',dirs_exist_ok=True)
print('Static demo built in _build/site with versioned assets. Serve with python -m http.server --directory _build/site 8080')
