import {generate,process} from './core.js';
const $=id=>document.getElementById(id);
const squares=[10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144];
const sizes=[...squares.map(x=>[x,x]),[18,8],[32,8],[26,12],[36,12],[36,16],[48,16],[48,8],[64,8],[80,8],[96,8],[120,8],[144,8],[64,12],[88,12],[64,16],[36,20],[44,20],[64,20],[48,22],[48,24],[64,24],[40,26],[48,26],[64,26]];
for(const [w,h] of sizes){const o=document.createElement('option');o.value=`${w}x${h}`;o.textContent=`${w} × ${h}`;$('size').append(o);}
const charsets=[[26,'UTF-8'],[2,'CP437'],[3,'ISO-8859-1'],...Array.from({length:10},(_,i)=>[i+4,`ISO-8859-${i+2}`]),...[13,14,15,16].map(n=>[n+2,`ISO-8859-${n}`]),[20,'Shift JIS'],[21,'Windows-1250'],[22,'Windows-1251'],[23,'Windows-1252'],[24,'Windows-1256'],[25,'UTF-16 BE'],[27,'ASCII'],[28,'Big5'],[29,'GB2312'],[30,'EUC-KR'],[31,'GBK'],[32,'GB18030'],[33,'UTF-16 LE'],[34,'UTF-32 BE'],[35,'UTF-32 LE']];
for(const [value,label] of charsets){const o=document.createElement('option');o.value=value;o.textContent=label;$('eci').append(o);}
let current=null,collection=null;
function invalidate(){current=null;collection=null;$('preview').replaceChildren();$('symbol').replaceChildren();$('symbol').disabled=true;$('decoded').textContent='';$('decoded-text').textContent='';$('preview').style.display='grid';$('json').textContent='下载矩阵 JSON';$('meta').textContent='';$('svg').disabled=$('png').disabled=$('json').disabled=true;}
function showSymbol(index){current=collection.symbols[index];$('preview').innerHTML=current.svg;$('meta').textContent=`${current.width} × ${current.height} 模块 · 第 ${index+1} / ${collection.symbols.length} 个符号`;$('decoded').textContent=JSON.stringify(current.decoded,null,2);$('decoded-text').textContent=current.decoded.text??current.decoded.hex;$('svg').disabled=$('png').disabled=false;}
function render(){
 invalidate();$('error').textContent='';
 try{
  const [width,height]=$('size').value.split('x').map(Number),shape=$('shape').value,kind=$('kind').value,input=$('input').value;
  let result;
  if(kind==='text'||kind==='hex') {const symbol=JSON.parse(generate(input,kind==='hex',shape,width,height));if(symbol.error)throw new Error(symbol.error);result={symbols:[symbol]};}
  else if(kind==='message'||kind==='matrix'||kind==='assemble') result=JSON.parse(process(kind==='message'?'encode':kind==='matrix'?'decode':'assemble',input));
  else {
   let request={shape,width,height};
   if(kind==='split')Object.assign(request,{split:true,text:input,file_id1:1,file_id2:1});
   else if(kind==='gs1')Object.assign(request,{gs1:true,segments:input.split(String.fromCharCode(29)).flatMap((text,i)=>i?[{fnc1:true},{text,eci:3}]:[{text,eci:3}])});
   else request.segments=[{text:input,eci:Number($('eci').value)}];
   result=JSON.parse(process('encode',JSON.stringify(request)));
  }
  if(result.error)throw new Error(result.error);
  collection=result;$('json').disabled=false;
  if(result.symbols){result.symbols.forEach((_,i)=>{const o=document.createElement('option');o.value=i;o.textContent=`符号 ${i+1}`;$('symbol').append(o);});$('symbol').disabled=result.symbols.length<2;showSymbol(0);}
  else {$('preview').style.display='none';$('decoded').textContent=JSON.stringify(result,null,2);$('decoded-text').textContent=result.text??result.hex;$('meta').textContent='解码完成';$('json').textContent='下载解码结果';}
 }catch(e){$('error').textContent=e.message;}
}
$('symbol').onchange=()=>showSymbol(Number($('symbol').value));
$('json').onclick=()=>{if(collection)download(new Blob([JSON.stringify(collection.symbols?{symbols:collection.symbols.map(({width,height,matrix})=>({width,height,matrix}))}:collection)],{type:'application/json'}),'moondatamatrix.json');};
function download(blob,name){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('generate').onclick=render;
for(const id of ['input','kind','shape','size','eci'])$(id).addEventListener('input',()=>{invalidate();$('error').textContent='';$('size').disabled=$('shape').value!=='fixed';});
$('svg').onclick=()=>{if(current)download(new Blob([current.svg],{type:'image/svg+xml'}),'datamatrix.svg');};
$('png').onclick=()=>{
 if(!current)return;
 const {width,height,matrix}=current;const canvas=document.createElement('canvas');const scale=8,q=2;
 canvas.width=(width+q*2)*scale;canvas.height=(height+q*2)*scale;
 const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.fillStyle='black';
 matrix.forEach((row,y)=>row.forEach((v,x)=>{if(v)ctx.fillRect((x+q)*scale,(y+q)*scale,scale,scale);}));
 canvas.toBlob(blob=>{if(blob)download(blob,'datamatrix.png');},'image/png');
};
const examples=[
 ['text','ASSET-2026-0001','square'],['text','样本编号：LAB-2026-001 🧪','square'],['hex','00010203fffe807f','square'],
 ['gs1','010123456789012810BATCH'+String.fromCharCode(29)+'21SERIAL','square'],
 ['text','DEVICE-2026-001','dmre'],
 ['message',JSON.stringify({segments:[{text:'中文',eci:29},{text:'日本語',eci:20},{text:'🙂',eci:32}]},null,2),'square'],
 ['split','设备配置：中文🙂'.repeat(12),'fixed']
];
for(const b of document.querySelectorAll('[data-example]'))b.onclick=()=>{const [kind,input,shape]=examples[Number(b.dataset.example)];$('kind').value=kind;$('input').value=input;$('shape').value=shape;if(kind==='split')$('size').value='26x26';$('size').disabled=shape!=='fixed';render();};
render();
