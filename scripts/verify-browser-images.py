from pathlib import Path
from PIL import Image
import zxingcpp
root=Path(__file__).resolve().parents[1]
expected='样本编号：LAB-2026-001 🧪'
for name in ['browser.png','browser-svg-rendered.png']:
 result=zxingcpp.read_barcode(Image.open(root/'test-results'/name),formats=zxingcpp.BarcodeFormat.DataMatrix)
 assert result is not None,name
 assert result.bytes==expected.encode('utf8'),name
 assert result.text==expected,name
print('Downloaded PNG and browser-rasterized SVG independently decoded correctly')
