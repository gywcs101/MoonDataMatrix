import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const {generate}=await import(pathToFileURL(process.argv[2]));
const cases=JSON.parse(readFileSync(process.argv[3],'utf8'));
const results=cases.map(c=> {
 const result=JSON.parse(generate(c.input,c.hex,c.shape??'square',c.width??0,c.height??0));
 return {...c,result};
});
writeFileSync(process.argv[4],JSON.stringify(results));
