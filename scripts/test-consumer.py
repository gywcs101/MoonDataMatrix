"""Exercise only the public interface from a separate module using the actual package."""
import subprocess,tempfile,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
subprocess.run(['python',str(root/'scripts/verify-package.py')],check=True)
archive=root/'_build/publish/gywcs101-MoonDataMatrix-0.1.0.zip'
with tempfile.TemporaryDirectory(prefix='mdm-consumer-') as tmp:
 work=Path(tmp);lib=work/'library';consumer=work/'consumer';lib.mkdir();consumer.mkdir()
 with zipfile.ZipFile(archive) as z:z.extractall(lib)
 (consumer/'moon.mod').write_text('name = "consumer/check"\nversion = "0.0.0"\nimport { "gywcs101/MoonDataMatrix@0.1.0" }\n')
 (consumer/'moon.pkg').write_text('import { "gywcs101/MoonDataMatrix" @dm } for "test"\n')
 (consumer/'consumer_test.mbt').write_text('///|\ntest "independent package consumer" {\n let symbol=@dm.encode_text("中文🙂")\n assert_true(symbol.width()>0)\n assert_eq(symbol.width(),symbol.height())\n assert_true(@dm.render_svg(symbol).contains("<svg"))\n assert_eq(@dm.encode_bytes(b"123456").width(),10)\n assert_eq(@dm.decode_matrix(symbol.matrix()).text(),"中文🙂")\n let extended=@dm.encode_message([@dm.Text("中文",29)])\n assert_eq(@dm.decode_matrix(extended.matrix()).text(),"中文")\n let copied=symbol.matrix()\n copied[0][0]=false\n assert_eq(symbol.module_at(0,0),Some(true))\n}\n',encoding='utf8')
 subprocess.run(['moon','work','init'],cwd=work,check=True)
 subprocess.run(['moon','work','use','library','consumer'],cwd=work,check=True)
 subprocess.run(['moon','test','--target','all','--deny-warn'],cwd=consumer,check=True)
print('Independent consumer of unpacked release archive passed on all backends')
