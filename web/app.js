import {generate} from './core.js';
const $=id=>document.getElementById(id);
const squares=[10,12,14,16,18,20,22,24,26,32,36,40,44,48,52,64,72,80,88,96,104,120,132,144];
const sizes=[...squares.map(x=>[x,x]),[18,8],[32,8],[26,12],[36,12],[36,16],[48,16]];
for(const [w,h] of sizes){const o=document.createElement('option');o.value=`${w}x${h}`;o.textContent=`${w} × ${h}`;$('size').append(o);}
let current=null;
function invalidate(){current=null;$('preview').replaceChildren();$('meta').textContent='';$('svg').disabled=$('png').disabled=true;}
function render(){
 invalidate();$('error').textContent='';
 try{
  const [w,h]=$('size').value.split('x').map(Number);
  const result=JSON.parse(generate($('input').value,$('kind').value==='hex',$('shape').value,w,h));
  if(result.error)throw new Error(result.error);
  current=result;$('preview').innerHTML=result.svg;
  $('meta').textContent=`${result.width} × ${result.height} 模块`;
  $('svg').disabled=$('png').disabled=false;
 }catch(e){$('error').textContent=e.message;}
}
function download(blob,name){const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('generate').onclick=render;
for(const id of ['input','kind','shape','size'])$(id).addEventListener('input',()=>{invalidate();$('error').textContent='';$('size').disabled=$('shape').value!=='fixed';});
$('svg').onclick=()=>{if(current)download(new Blob([current.svg],{type:'image/svg+xml'}),'datamatrix.svg');};
$('png').onclick=()=>{
 if(!current)return;
 const {width,height,matrix}=current;const canvas=document.createElement('canvas');const scale=8,q=2;
 canvas.width=(width+q*2)*scale;canvas.height=(height+q*2)*scale;
 const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.fillStyle='black';
 matrix.forEach((row,y)=>row.forEach((v,x)=>{if(v)ctx.fillRect((x+q)*scale,(y+q)*scale,scale,scale);}));
 canvas.toBlob(blob=>{if(blob)download(blob,'datamatrix.png');},'image/png');
};
const examples=[['text','ASSET-2026-0001'],['text','样本编号：LAB-2026-001 🧪'],['hex','00010203fffe807f']];
for(const b of document.querySelectorAll('[data-example]'))b.onclick=()=>{const [kind,input]=examples[Number(b.dataset.example)];$('kind').value=kind;$('input').value=input;$('shape').value='square';$('size').disabled=true;render();};
render();
