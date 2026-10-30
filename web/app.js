import {generate,process} from './core.js';
const $=id=>document.getElementById(id);
const squares=[10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144];
const sizes=[...squares.map(x=>[x,x]),[18,8],[32,8],[26,12],[36,12],[36,16],[48,16],[48,8],[64,8],[80,8],[96,8],[120,8],[144,8],[64,12],[88,12],[64,16],[36,20],[44,20],[64,20],[48,22],[48,24],[64,24],[40,26],[48,26],[64,26]];
for(const [w,h] of sizes){const o=document.createElement('option');o.value=`${w}x${h}`;o.textContent=`${w} × ${h}`;$('size').append(o);}
const charsets=[[26,'UTF-8'],[2,'CP437'],[3,'ISO-8859-1'],...Array.from({length:10},(_,i)=>[i+4,`ISO-8859-${i+2}`]),...[13,14,15,16].map(n=>[n+2,`ISO-8859-${n}`]),[20,'Shift JIS'],[21,'Windows-1250'],[22,'Windows-1251'],[23,'Windows-1252'],[24,'Windows-1256'],[25,'UTF-16 BE'],[27,'ASCII'],[28,'Big5'],[29,'GB2312'],[30,'EUC-KR'],[31,'GBK'],[32,'GB18030'],[33,'UTF-16 LE'],[34,'UTF-32 BE'],[35,'UTF-32 LE']];
for(const [value,label] of charsets){const o=document.createElement('option');o.value=value;o.textContent=label;$('eci').append(o);}
let current=null,collection=null,revision=0;
class InputError extends Error {}
const hint=document.createElement('p');hint.id='input-hint';$('input').before(hint);
const basis=document.createElement('p');basis.id='text-basis';$('decoded-text').before(basis);
const rawDetails=document.createElement('details');rawDetails.innerHTML='<summary>查看原始字节</summary>';$('decoded-text').after(rawDetails);
const raw=document.createElement('p');raw.id='decoded-hex';rawDetails.append(raw);
const total=document.createElement('section');total.id='assembled';total.hidden=true;total.innerHTML='<h3>完整重组内容</h3><p id="assembled-text" style="white-space:pre-wrap;overflow-wrap:anywhere"></p><p id="assembled-error" role="alert"></p>';$('decoded').closest('details').after(total);
function viewFor(k){return ['matrix','assemble','batch'].includes(k)?k:'encode';}
function updateOptions(){const k=$('kind').value;$('eci').disabled=!['text','eci'].includes(k);const json=['message','matrix','assemble','batch'].includes(k);$('shape').disabled=json;$('size').disabled=json||$('shape').value!=='fixed';$('size-options').hidden=json;$('segment-editor').hidden=k!=='segments';$('input').hidden=k==='segments';$('input-label').hidden=k==='segments';for(const b of document.querySelectorAll('[data-view]')){if(b.dataset.view===viewFor(k))b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');}const titles={encode:['编码生成','输入数据，生成可复用的 Data Matrix 符号。','生成符号 →'],matrix:['矩阵解码','读取模块矩阵，还原数据与控制信息。','解码矩阵 →'],assemble:['符号重组','导入完整符号集合，按序恢复原始消息。','重组消息 →'],batch:['批量处理','每行一条 JSON 消息，全部验证成功后生成结果。','生成批次 →']};const t=titles[viewFor(k)];$('workspace-title').textContent=t[0];$('workspace-description').textContent=t[1];$('generate').textContent=t[2];$('input-label').textContent=k==='batch'?'批次内容（JSONL）':json?'输入 JSON':'编码内容';hint.textContent=k==='gs1'?'GS1 使用 ISO-8859-1；输入 ␝ 表示 FNC1 字段分隔符。':['text','eci'].includes(k)?'文本按所选字符集编码；读取设备需支持对应 ECI。':k==='split'?'文本使用 UTF-8（ECI 26），按完整字符自动分片。':k==='matrix'?'请输入包含定位边的黑白模块矩阵 JSON；照片需先完成定位和采样。':k==='message'?'字符集、尺寸和控制选项以消息 JSON 为准。':k==='segments'?'逐段选择数据类型和字符集；每个符号均保留独立读取所需的信息。':k==='batch'?'每行包含安全 id，以及 text、hex 或 message 中的一项；结果可逐个预览并下载。':'';}
function invalidate(){revision++;current=null;collection=null;$('preview').replaceChildren();$('symbol').replaceChildren();$('symbol').disabled=true;$('decoded').textContent='';$('decoded-text').textContent='';basis.textContent='';raw.textContent='';total.hidden=true;$('assembled-text').textContent='';$('assembled-error').textContent='';$('preview').style.display='grid';$('json').textContent='矩阵 JSON';$('meta').textContent='';$('result-status').textContent='';$('svg').disabled=$('png').disabled=$('json').disabled=true;}
function displayText(decoded){if(decoded.text==null)return '无法转换为文本，请查看原始字节。';let pos=0;return Array.from(decoded.text,c=>{const at=pos;pos+=decoded.gs1?1:new TextEncoder().encode(c).length;if(c==='\x1d'&&decoded.gs1&&decoded.fnc1_positions.includes(at))return '␝';return /[\x00-\x08\x0b-\x1f\x7f-\x9f]/.test(c)?'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'):c;}).join('');}
function showDecoded(decoded){
 $('decoded-heading').textContent=collection?.symbols?.length>1?'当前符号内容':'数据还原';$('result-status').textContent='解码成功';
 $('decoded').textContent=JSON.stringify(decoded,null,2);
 const binary=$('kind').value==='hex'||current?.binary;
 const hex=decoded.hex.match(/.{1,2}/g)?.join(' ').toUpperCase()||'（空）';
 $('decoded-text').textContent=binary||decoded.text==null
  ? `十六进制（${decoded.hex.length/2} 字节）：\n${hex}`
  : displayText(decoded);
 raw.textContent=`原始字节（十六进制）：${hex}`;
 basis.textContent=decoded.eci?.length?'文本按照符号中的 ECI 字符集解读。': '无 ECI：文本按 ISO-8859-1 解读；原始字节见下方。';
}
function showSymbol(index){current=collection.symbols[index];$('preview').innerHTML=current.svg;$('meta').textContent=`${current.width} × ${current.height} 模块 · 第 ${index+1} / ${collection.symbols.length} 个符号`;showDecoded(current.decoded);$('svg').disabled=$('png').disabled=false;}
function render(){
 invalidate();$('error').textContent='';
 try{
  const [width,height]=$('size').value.split('x').map(Number),shape=$('shape').value,kind=$('kind').value,input=$('input').value;
  let result;
  if(kind==='hex'||(kind==='text'&&$('eci').value==='26')) {const symbol=JSON.parse(generate(input,kind==='hex',shape,width,height));if(symbol.error)throw new InputError(symbol.error);result={symbols:[symbol]};}
  else if(kind==='segments') result=JSON.parse(process('encode',JSON.stringify(editorRequest(shape,width,height))));
  else if(kind==='batch') result=batchRequest(input);
  else if(kind==='message'||kind==='matrix'||kind==='assemble') result=JSON.parse(process(kind==='message'?'encode':kind==='matrix'?'decode':'assemble',input));
  else {
   let request={shape,width,height};
   if(kind==='split')Object.assign(request,{split:true,text:input,file_id1:1,file_id2:1});
   else if(kind==='gs1')Object.assign(request,{gs1:true,segments:input.split(/[␝\x1d]/).flatMap((text,i)=>i?[{fnc1:true},{text,eci:3}]:[{text,eci:3}])});
   else request.segments=[{text:input,eci:Number($('eci').value)}];
   result=JSON.parse(process('encode',JSON.stringify(request)));
  }
  if(result.error)throw new InputError(result.error);
  collection=result;$('json').disabled=false;
  if(result.symbols){result.symbols.forEach((s,i)=>{const o=document.createElement('option');o.value=i;o.textContent=s.id?`${s.id} · 符号 ${s.part}`:`符号 ${i+1}`;$('symbol').append(o);});$('symbol').disabled=result.symbols.length<2;showSymbol(0);if(result.symbols.length>1&&!result.batch){total.hidden=false;const assembled=JSON.parse(process('assemble',JSON.stringify({symbols:result.symbols.map(({matrix})=>({matrix}))})));if(assembled.error)$('assembled-error').textContent='重组失败：'+assembled.error;else $('assembled-text').textContent=displayText(assembled);}}
  else {$('preview').style.display='none';showDecoded(result);$('meta').textContent='解码完成';$('json').textContent='下载解码结果';}
 }catch(e){invalidate();$('error').textContent=e instanceof InputError?e.message:'处理失败，请检查输入并重试；若仍失败，请记录输入类型和所选选项后反馈。';}
}
$('symbol').onchange=()=>showSymbol(Number($('symbol').value));
$('json').onclick=()=>{if(collection)download(new Blob([JSON.stringify(collection.symbols?{symbols:collection.symbols.map(({width,height,matrix,id,part})=>({width,height,matrix,...(collection.batch?{id,part}:{})}))}:collection)],{type:'application/json'}),'moondatamatrix.json');};
function download(blob,name){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('generate').onclick=render;
for(const id of ['input','kind','shape','size','eci'])$(id).addEventListener('input',()=>{invalidate();$('error').textContent='';updateOptions();});
$('svg').onclick=()=>{if(current)download(new Blob([current.svg],{type:'image/svg+xml'}),'datamatrix.svg');};
$('png').onclick=()=>{
 if(!current)return;
 const {width,height,matrix}=current;const canvas=document.createElement('canvas');const scale=8,q=2;
 canvas.width=(width+q*2)*scale;canvas.height=(height+q*2)*scale;
 const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.fillStyle='black';
 matrix.forEach((row,y)=>row.forEach((v,x)=>{if(v)ctx.fillRect((x+q)*scale,(y+q)*scale,scale,scale);}));
 canvas.toBlob(blob=>{if(blob)download(blob,'datamatrix.png');},'image/png');
};
function checked(operation,value){const r=JSON.parse(process(operation,JSON.stringify(value)));if(r.error)throw new InputError(r.error);return r;}
function batchRequest(input){
 const lines=input.split('\n');if(lines.at(-1)==='')lines.pop();if(!lines.length)throw new InputError('批次为空，请填写至少一条 JSON 消息。');
 const ids=new Set(),symbols=[];
 for(let i=0;i<lines.length;i++){
  let row;try{row=JSON.parse(lines[i]);}catch{throw new InputError(`第 ${i+1} 行 JSON 格式错误，请检查引号、逗号和括号。`);}
  if(!row||Array.isArray(row)||typeof row!=='object'||typeof row.id!=='string'||!/^[A-Za-z0-9_-]{1,100}$/.test(row.id)||/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i.test(row.id))throw new InputError(`第 ${i+1} 行 id 无效，请使用 1–100 位字母、数字、下划线或连字符，避开系统保留名称。`);
  if(ids.has(row.id.toLowerCase()))throw new InputError(`第 ${i+1} 行 id 重复：${row.id}。请为每条消息使用不同标识。`);ids.add(row.id.toLowerCase());
  const keys=Object.keys(row),inputs=['text','hex','message'].filter(k=>Object.hasOwn(row,k));
  if(keys.length!==2||inputs.length!==1)throw new InputError(`第 ${i+1} 行（${row.id}）应仅包含 id 和 text、hex、message 中的一项。`);
  const key=inputs[0];if(key!=='message'&&typeof row[key]!=='string')throw new InputError(`第 ${i+1} 行（${row.id}）的 ${key} 必须是字符串。`);
  try{const request=key==='message'?row.message:{segments:[key==='text'?{text:row.text,eci:26}:{hex:row.hex}]};const result=checked('encode',request);result.symbols.forEach((s,j)=>symbols.push({...s,id:row.id,part:j+1,binary:key==='hex'}));}catch(e){throw new InputError(`第 ${i+1} 行（${row.id}）：${e instanceof InputError?e.message:'消息格式无效，请参考批量示例。'}`);}
  if(symbols.length>256)throw new InputError('浏览器批次最多预览 256 个符号。请减少条目，或使用 CLI 处理较大批次。');
 }
 return {symbols,batch:true};
}
function addSegment(segment={text:'',eci:26}){
 const row=document.createElement('div');row.className='segment';row.innerHTML='<div class="row"><select aria-label="数据段类型"><option value="text">文本</option><option value="hex">原始字节</option><option value="fnc1">FNC1 分隔符</option><option value="eci">ECI 切换</option></select><select aria-label="数据段字符集"></select><button type="button" aria-label="删除数据段">删除</button></div><textarea aria-label="数据段内容" spellcheck="false"></textarea>';
 const [type,eci]=row.querySelectorAll('select');const text=row.querySelector('textarea');for(const [n,label] of charsets){const o=document.createElement('option');o.value=n;o.textContent=label;eci.append(o);}
 type.value=Object.hasOwn(segment,'text')?'text':Object.hasOwn(segment,'hex')?'hex':segment.fnc1?'fnc1':'eci';eci.value=segment.eci??26;text.value=segment.text??segment.hex??String(segment.eci??26);
 const sync=()=>{eci.hidden=type.value!=='text';text.hidden=type.value==='fnc1';text.placeholder=type.value==='eci'?'ECI 编号（0–999999）':type.value==='hex'?'00 FF 需写为 00ff':'输入文本';};sync();
 row.addEventListener('input',()=>{sync();invalidate();$('error').textContent='';});row.querySelector('button').onclick=()=>{row.remove();invalidate();};$('segment-list').append(row);
}
function editorRequest(shape,width,height){const segments=[...$('segment-list').children].map(row=>{const [type,eci]=row.querySelectorAll('select'),value=row.querySelector('textarea').value;switch(type.value){case 'text':return {text:value,eci:Number(eci.value)};case 'hex':return {hex:value};case 'fnc1':return {fnc1:true};default:if(!/^\d{1,6}$/.test(value))throw new InputError('ECI 切换需填写 0–999999 的整数。');return {eci:Number(value)};}});if(!segments.length)throw new InputError('请添加至少一个数据段。');const r={segments,shape,width,height};if($('auto-split').checked){r.split=true;r.file_id1=Number($('file-id1').value);r.file_id2=Number($('file-id2').value);}const c=$('control').value;if(c==='gs1')r.gs1=true;else if(c.startsWith('macro'))r.macro=Number(c.slice(5));else if(c==='reader')r.reader_programming=true;return r;}
$('add-segment').onclick=()=>{addSegment();invalidate();};
for(const id of ['auto-split','file-id1','file-id2','control'])$(id).addEventListener('input',()=>{invalidate();$('error').textContent='';});
$('import').onclick=()=>$('file').click();$('file').onchange=async()=>{const file=$('file').files[0];if(!file)return;invalidate();const ticket=revision;try{const content=await file.text();if(ticket!==revision)return;const kind=$('kind').value;$('kind').value=file.name.toLowerCase().endsWith('.jsonl')?'batch':['matrix','assemble'].includes(kind)?kind:'message';$('input').value=content;updateOptions();render();}catch{if(ticket===revision)$('error').textContent='文件读取失败，请选择有效的 JSON 或 JSONL 文件。';}finally{if($('file').files[0]===file)$('file').value='';}};
$('reset').onclick=()=>{$('input').value='';$('eci').value='26';$('shape').value='square';$('auto-split').checked=false;$('control').value='none';$('segment-list').replaceChildren();addSegment();invalidate();$('error').textContent='';updateOptions();};
const examples=[
 ['text','ASSET-2026-0001','square'],['text','样本编号：LAB-2026-001','square'],['hex','00010203fffe807f','square'],
 ['gs1','010123456789012810BATCH␝21SERIAL','square'],
 ['text','DEVICE-2026-001','dmre'],
 ['message',JSON.stringify({segments:[{text:'中文',eci:29},{text:'日本語',eci:20},{text:'🙂',eci:32}]},null,2),'square'],
 ['split','设备配置：中文🙂'.repeat(12),'fixed'],
 ['segments',JSON.stringify({split:true,shape:'fixed',width:26,height:26,segments:[{text:'中文设备配置与校准记录。'.repeat(3),eci:29},{text:'日本語の検査記録。'.repeat(3),eci:20},{text:'🙂🧪',eci:26}]},null,2),'fixed'],
 ['segments',JSON.stringify({macro:5,segments:[{text:'ORDER-2026-001',eci:26}]},null,2),'square'],
 ['segments',JSON.stringify({reader_programming:true,segments:[{text:'READER-CONFIG-001',eci:26}]},null,2),'square'],
 ['batch',[{id:'batch-a',message:{gs1:true,segments:[{text:'010123456789012810BATCH-A',eci:3},{fnc1:true},{text:'21SERIAL-001',eci:3}]}},{id:'batch-b',message:{gs1:true,segments:[{text:'010123456789012810BATCH-B',eci:3},{fnc1:true},{text:'21SERIAL-002',eci:3}]}}].map(x=>JSON.stringify(x)).join('\n'),'square']
];
function loadExample(index){let entry=examples[index];if(index===11){const symbol=checked('encode',{segments:[{text:'设备编号：DEV-001',eci:26}]}).symbols[0];symbol.matrix[1][1]=!symbol.matrix[1][1];entry=['matrix',JSON.stringify({matrix:symbol.matrix}),'square'];}if(index===12){const symbols=checked('encode',JSON.parse(examples[7][1])).symbols.map(({matrix})=>({matrix})).reverse();entry=['assemble',JSON.stringify({symbols}),'square'];}const [kind,input,shape]=entry;$('kind').value=kind;$('input').value=input;$('shape').value=shape;$('eci').value='26';if(kind==='split'||kind==='segments')$('size').value='26x26';if(kind==='segments'){const r=JSON.parse(input);$('segment-list').replaceChildren();r.segments.forEach(addSegment);$('auto-split').checked=!!r.split;$('file-id1').value=r.file_id1??1;$('file-id2').value=r.file_id2??1;$('control').value=r.macro?'macro'+r.macro:r.reader_programming?'reader':r.gs1?'gs1':'none';}for(const b of document.querySelectorAll('[data-example]')){if(Number(b.dataset.example)===index)b.setAttribute('aria-current','true');else b.removeAttribute('aria-current');}updateOptions();render();}
for(const b of document.querySelectorAll('[data-example]'))b.onclick=()=>loadExample(Number(b.dataset.example));
const drafts=new Map();
function captureDraft(){return {fields:Object.fromEntries(['kind','input','shape','size','eci','file-id1','file-id2','control'].map(id=>[id,$(id).value])),split:$('auto-split').checked,rows:[...$('segment-list').children].map(row=>{const s=row.querySelectorAll('select');return [s[0].value,s[1].value,row.querySelector('textarea').value];})};}
function restoreDraft(draft){for(const [id,value] of Object.entries(draft.fields))$(id).value=value;$('auto-split').checked=draft.split;$('segment-list').replaceChildren();for(const [type,eci,value] of draft.rows){addSegment();const row=$('segment-list').lastElementChild,s=row.querySelectorAll('select');s[0].value=type;s[1].value=eci;row.querySelector('textarea').value=value;s[1].hidden=type!=='text';row.querySelector('textarea').hidden=type==='fnc1';}updateOptions();render();}
for(const b of document.querySelectorAll('[data-view]'))b.onclick=()=>{const view=b.dataset.view;drafts.set(viewFor($('kind').value),captureDraft());if(drafts.has(view))restoreDraft(drafts.get(view));else loadExample({encode:1,matrix:11,batch:10,assemble:12}[view]);};
$('kind').querySelector('[value="eci"]').hidden=true;
addSegment();
updateOptions();
render();
