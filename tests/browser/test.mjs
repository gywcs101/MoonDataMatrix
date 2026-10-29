import {chromium} from '@playwright/test';
import {createServer} from 'node:http';
import {readFile,writeFile} from 'node:fs/promises';
import {mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const server=createServer(async(req,res)=>{try{const path=req.url==='/'?'index.html':req.url.slice(1);if(!['index.html','app.js','core.js'].includes(path)){res.writeHead(404);return res.end();}res.setHeader('Content-Type',path.endsWith('.js')?'application/javascript':'text/html; charset=utf-8');res.end(await readFile(resolve(root,'web',path)));}catch{res.writeHead(404);res.end();}});
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
  assert.equal(await page.locator('#decoded-text').textContent(),binaryDisplay);
 }
 await page.locator('[data-example="1"]').click();
 assert.equal(await page.locator('#decoded-text').textContent(),'样本编号：LAB-2026-001 🧪');
 await page.locator('[data-example="2"]').click();await page.locator('#shape').selectOption('fixed');await page.locator('#size').selectOption('10x10');await page.locator('#generate').click();
 assert.ok((await page.locator('#error').textContent()).includes('CapacityExceeded'));
 for(const example of ['3','4','5','6']) {
  await page.locator(`[data-example="${example}"]`).click();
  assert.equal(await page.locator('#error').textContent(),'');
  assert.ok(await page.locator('#decoded').textContent());
 }
 assert.ok(await page.locator('#symbol option').count()>1);
 const pendingJson=page.waitForEvent('download');await page.locator('#json').click();
 const jsonDownload=await pendingJson;await jsonDownload.saveAs(resolve(output,'symbols.json'));
 const symbolSet=await readFile(resolve(output,'symbols.json'),'utf8');
 await page.locator('#kind').selectOption('assemble');await page.locator('#input').fill(symbolSet);await page.locator('#generate').click();
 assert.equal(await page.locator('#error').textContent(),'');
 assert.equal(JSON.parse(await page.locator('#decoded').textContent()).text,'设备配置：中文🙂'.repeat(12));
 await page.locator('#kind').selectOption('matrix');await page.locator('#input').fill(JSON.stringify(JSON.parse(symbolSet).symbols[0]));await page.locator('#generate').click();
 assert.equal(await page.locator('#error').textContent(),'');
 await page.screenshot({path:resolve(output,'extended-demo.png'),fullPage:true});
 assert.deepEqual(errors,[]);console.log('Browser preview, stale-output clearing, errors and SVG/PNG downloads passed');
}finally{await browser.close();server.close();}
