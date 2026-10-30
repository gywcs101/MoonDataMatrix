import {chromium} from '@playwright/test';
import {createServer} from 'node:http';
import {readFile,writeFile} from 'node:fs/promises';
import {mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const site=resolve(root,'_build/site');
const html=await readFile(resolve(site,'index.html'),'utf8');
assert.match(html,/src="app\.[0-9a-f]{16}\.js"/);
const server=createServer(async(req,res)=>{try{const path=req.url==='/'?'index.html':req.url.slice(1);if(!/^(index\.html|(?:app|core)\.[0-9a-f]{16}\.js)$/.test(path)){res.writeHead(404);return res.end();}res.setHeader('Content-Type',path.endsWith('.js')?'application/javascript':'text/html; charset=utf-8');res.end(await readFile(resolve(site,path)));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch();
try{
 const page=await browser.newPage({acceptDownloads:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`http://127.0.0.1:${server.address().port}`);
 await page.locator('#preview svg').waitFor();
 await page.locator('[data-example="1"]').click();
 const output=resolve(root,'test-results');mkdirSync(output,{recursive:true});
 for(const type of ['svg','png']){
  const pending=page.waitForEvent('download');await page.locator('#'+type).click();const download=await pending;
  assert.equal(download.suggestedFilename(),'datamatrix.'+type);await download.saveAs(resolve(output,'browser.'+type));
 }
 const svg=await readFile(resolve(output,'browser.svg'),'utf8');
 const raster=await page.evaluate(async svg=>{
  const image=new Image();const url=URL.createObjectURL(new Blob([svg],{type:'image/svg+xml'}));
  try{image.src=url;await image.decode();const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;canvas.getContext('2d').drawImage(image,0,0);return canvas.toDataURL('image/png').split(',')[1];}finally{URL.revokeObjectURL(url);}
 },svg);
 await writeFile(resolve(output,'browser-svg-rendered.png'),Buffer.from(raster,'base64'));
 await page.screenshot({path:resolve(output,'demo.png'),fullPage:true});
 await page.locator('#kind').selectOption('hex');await page.locator('#input').fill('XX');await page.locator('#generate').click();
 assert.ok(await page.locator('#error').textContent());assert.ok(await page.locator('#png').isDisabled());assert.equal(await page.locator('#preview svg').count(),0);
 await page.locator('[data-example="2"]').click();
 const binaryDisplay='十六进制（8 字节）：\n00 01 02 03 FF FE 80 7F';
 assert.equal(await page.locator('#decoded-text').textContent(),binaryDisplay);
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).hex,'00010203fffe807f');
 const binaryDownload=page.waitForEvent('download');await page.locator('#json').click();
 await (await binaryDownload).saveAs(resolve(output,'binary-symbols.json'));
 const binarySet=JSON.parse(await readFile(resolve(output,'binary-symbols.json'),'utf8'));
 for(const kind of ['matrix','assemble']) {
  await page.locator('#kind').selectOption(kind);
  await page.locator('#input').fill(JSON.stringify(kind==='matrix'?binarySet.symbols[0]:binarySet));
  await page.locator('#generate').click();
  assert.ok((await page.locator('#decoded-hex').textContent()).includes('00 01 02 03 FF FE 80 7F'));
 }
 await page.locator('[data-example="1"]').click();
 assert.equal(await page.locator('#decoded-text').textContent(),'样本编号：LAB-2026-001');
 await page.locator('[data-example="2"]').click();await page.locator('#shape').selectOption('fixed');await page.locator('#size').selectOption('10x10');await page.locator('#generate').click();
 assert.ok((await page.locator('#error').textContent()).includes('容量'));
 for(const example of ['3','4','5','6']) {
  await page.locator(`[data-example="${example}"]`).click();
  assert.equal(await page.locator('#error').textContent(),'');
  assert.ok(await page.locator('#decoded').textContent());
  if(example==='3') {
   assert.ok(await page.locator('#eci').isDisabled());
   assert.ok((await page.locator('#input').inputValue()).includes('␝'));
   assert.ok((await page.locator('#decoded-text').textContent()).includes('BATCH␝21SERIAL'));
   const gs=JSON.parse(await page.locator('#decoded').textContent());
   assert.equal(gs.gs1,true);assert.equal(gs.fnc1_positions.length,1);
   assert.equal(gs.hex.slice(gs.fnc1_positions[0]*2,gs.fnc1_positions[0]*2+2),'1d');
   await page.locator('#input').fill((await page.locator('#input').inputValue()).replace('␝','\x1d'));
   await page.locator('#generate').click();
   assert.equal(JSON.parse(await page.locator('#decoded').textContent()).hex,gs.hex);
  }
 }
 assert.ok(await page.locator('#symbol option').count()>1);
 assert.equal(await page.locator('#assembled-text').textContent(),'设备配置：中文🙂'.repeat(12));
 await page.locator('#symbol').selectOption('1');
 assert.equal(await page.locator('#assembled-text').textContent(),'设备配置：中文🙂'.repeat(12));
 const pendingJson=page.waitForEvent('download');await page.locator('#json').click();
 const jsonDownload=await pendingJson;await jsonDownload.saveAs(resolve(output,'symbols.json'));
 const symbolSet=await readFile(resolve(output,'symbols.json'),'utf8');
 await page.locator('#kind').selectOption('assemble');await page.locator('#input').fill(symbolSet);await page.locator('#generate').click();
 assert.equal(await page.locator('#error').textContent(),'');
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).text,'设备配置：中文🙂'.repeat(12));
 await page.locator('#kind').selectOption('matrix');await page.locator('#input').fill(JSON.stringify(JSON.parse(symbolSet).symbols[0]));await page.locator('#generate').click();
 assert.equal(await page.locator('#error').textContent(),'');
 await page.screenshot({path:resolve(output,'extended-demo.png'),fullPage:true});
 await page.locator('[data-example="7"]').click();
 assert.equal(await page.locator('#error').textContent(),'');
 assert.equal(await page.locator('#assembled-text').textContent(),'中文设备配置与校准记录。'.repeat(3)+'日本語の検査記録。'.repeat(3)+'🙂🧪');
 assert.ok(await page.locator('#shape').isEnabled());
 await page.locator('#kind').selectOption('message');
 await page.locator('#input').fill('invalid json');await page.locator('#generate').click();
 assert.ok(await page.locator('#json').isDisabled());
 await page.locator('[data-example="0"]').click();
 await page.locator('#generate').focus();await page.keyboard.press('Enter');
 assert.equal(await page.locator('#decoded-text').textContent(),'ASSET-2026-0001');
 await page.locator('#kind').selectOption('eci');assert.ok(await page.locator('#eci').isEnabled());
 await page.locator('#shape').selectOption('square');
 await page.locator('#eci').selectOption('29');await page.locator('#input').fill('中文');await page.locator('#generate').click();
 assert.equal(await page.locator('#decoded-text').textContent(),'中文');
 await page.locator('#input').fill('🙂');await page.locator('#generate').click();
 assert.ok(await page.locator('#json').isDisabled());assert.ok(await page.locator('#error').textContent());
 await page.locator('[data-example="0"]').click();await page.locator('#input').fill('');await page.locator('#generate').click();
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).hex,'');
 await page.locator('#input').fill('A\x1dB');await page.locator('#generate').click();
 assert.equal(await page.locator('#decoded-text').textContent(),'A\\u001dB');
 assert.deepEqual(JSON.parse(await page.locator('#decoded').textContent()).fnc1_positions,[]);
 for(const [kind,input,expected] of [
  ['message','样本编号：LAB-001','文本输入模式'],
  ['matrix','样本编号：LAB-001','JSON'],
  ['assemble','{','补全'],
  ['hex','0xGG','十六进制'],
  ['message','{"segments":[{"text":"🙂","eci":29}]}','字符集'],
  ['matrix','{"matrix":[[1]]}','true 或 false'],
  ['assemble',JSON.stringify({symbols:JSON.parse(symbolSet).symbols.slice(1)}),'完整符号集合'],
  ['assemble',JSON.stringify({symbols:JSON.parse(symbolSet).symbols.map(()=>JSON.parse(symbolSet).symbols[0])}),'重复分片'],
 ]) {
  await page.locator('#kind').selectOption(kind);await page.locator('#input').fill(input);await page.locator('#generate').click();
  const message=await page.locator('#error').textContent();
  assert.ok(message.includes(expected),message);
  assert.ok(!/InvalidChar|InvalidRequest|InvalidOption|CapacityExceeded|TypeError|Error\(/.test(message),message);
  assert.ok(await page.locator('#json').isDisabled());assert.equal(await page.locator('#preview svg').count(),0);
 }
 await page.locator('[data-example="1"]').click();assert.equal(await page.locator('#error').textContent(),'');
 // The default text workflow exposes all encodings without a second mode switch.
 assert.ok(await page.locator('#eci').isEnabled());await page.locator('#eci').selectOption('29');
 await page.locator('#input').fill('中文');await page.locator('#generate').click();
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).eci[0].eci,29);
 // New examples and top-level operations are real actions, not decorative links.
 for(const index of [8,9,10,11,12]) {
  await page.locator(`[data-example="${index}"]`).click();
  assert.equal(await page.locator('#error').textContent(),'');
  const decoded=JSON.parse(await page.locator('#decoded').textContent());
  if(index===8){assert.equal(decoded.macro,5);await page.locator('#control').selectOption('macro6');await page.locator('#generate').click();assert.equal(JSON.parse(await page.locator('#decoded').textContent()).macro,6);}
  if(index===9)assert.equal(decoded.reader_programming,true);
  if(index===10){assert.equal(decoded.gs1,true);assert.equal(await page.locator('#symbol option').count(),2);assert.ok(await page.locator('#assembled').isHidden());}
  if(index===11)assert.equal(decoded.corrected_codewords,1);
  if(index===12)assert.ok(decoded.text.includes('日本語'));
 }
 await page.locator('[data-view="batch"]').click();
 const batchInput=await page.locator('#input').inputValue();
 await page.locator('#input').fill(batchInput+'\n'+batchInput.split('\n')[0]);await page.locator('#generate').click();
 assert.ok((await page.locator('#error').textContent()).includes('重复'));assert.ok(await page.locator('#json').isDisabled());
 await page.locator('[data-view="matrix"]').click();assert.equal(await page.locator('#kind').inputValue(),'matrix');
 await page.locator('[data-view="assemble"]').click();assert.equal(await page.locator('#kind').inputValue(),'assemble');
 await page.locator('[data-view="encode"]').click();
 await page.locator('[data-example="7"]').click();
 assert.equal(await page.locator('#segment-list .segment').count(),3);
 await page.locator('#segment-list textarea').first().fill('新配置');await page.locator('#generate').click();
 assert.ok((await page.locator('#assembled-text').textContent()).startsWith('新配置'));
 await page.locator('#add-segment').click();assert.equal(await page.locator('#segment-list .segment').count(),4);
 await page.locator('#segment-list .segment').last().getByRole('button',{name:'删除数据段'}).click();
 assert.equal(await page.locator('#segment-list .segment').count(),3);
 await page.locator('[data-view="matrix"]').click();
 await page.locator('#file').setInputFiles({name:'matrix.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(binarySet.symbols[0]))});
 await page.waitForFunction(()=>document.getElementById('decoded').textContent.includes('00010203fffe807f'));
 assert.equal(await page.locator('#kind').inputValue(),'matrix');
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).hex,'00010203fffe807f');
 await page.locator('[data-example="1"]').click();await page.locator('#input').fill('保留工作草稿');
 await page.locator('[data-view="matrix"]').click();await page.locator('[data-view="encode"]').click();
 assert.equal(await page.locator('#input').inputValue(),'保留工作草稿');
 await page.evaluate(()=>{window.originalFileText=File.prototype.text;File.prototype.text=function(){return new Promise(resolve=>{window.finishImport=()=>resolve('{"segments":[{"text":"过期输入"}]}');});};});
 await page.locator('#file').setInputFiles({name:'slow.json',mimeType:'application/json',buffer:Buffer.from('{}')});
 await page.waitForFunction(()=>typeof window.finishImport==='function');
 await page.locator('[data-example="0"]').click();
 await page.evaluate(()=>{window.finishImport();File.prototype.text=window.originalFileText;});
 assert.equal(await page.locator('#input').inputValue(),'ASSET-2026-0001');
 await page.locator('[data-example="7"]').click();
 await page.screenshot({path:resolve(output,'workspace-desktop.png'),fullPage:true});
 const category=await page.locator('.examples h3').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize));
 const item=await page.locator('[data-example="1"]').evaluate(e=>parseFloat(getComputedStyle(e).fontSize));assert.ok(category>=item);
 await page.setViewportSize({width:375,height:800});
 await page.screenshot({path:resolve(output,'workspace-mobile.png'),fullPage:true});
 await page.setViewportSize({width:375,height:800});
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 assert.deepEqual(errors,[]);console.log('Browser preview, stale-output clearing, errors and SVG/PNG downloads passed');
}finally{await browser.close();server.close();}
