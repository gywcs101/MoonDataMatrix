import subprocess, shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['moon','build','--target','js'],cwd=root,check=True)
files=list((root/'_build').rglob('webbridge.js'))
assert files,'compiled JS bridge missing'
source=max(files,key=lambda p:p.stat().st_mtime)
shutil.copyfile(source,root/'web/core.js')
print('Static demo built in web/. Serve with python -m http.server --directory web 8080')
