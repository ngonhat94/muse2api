import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const path = fs.existsSync('deploy/pot-provider/mint.mjs') ? 'deploy/pot-provider/mint.mjs' : '/opt/muse/mint.mjs';
const source = fs.readFileSync(path,'utf8').replace("import fs from 'node:fs';",'').replace("await import('/opt/bgutil/server/build/session_manager.js')", 'await loadProvider()');
const input = {client:'mweb',context:'gvs',video_id:'fixture1234',binding:'synthetic-visitor',binding_type:'visitor_data'};
for (const mode of ['success','failure','oversize']) {
 const emitted=[]; const exits=[]; const fetches=[];
 const process = {stdout:{write:text=>emitted.push(text)},stderr:{write:()=>{}},exit:code=>exits.push(code)};
 class SessionManager {
  getFetch(proxy,attempts,delay) { fetches.push({proxy,attempts,delay}); }
  async generatePoToken(binding,proxy,bypass) {
   assert.equal(binding,input.binding);assert.equal(proxy,'');assert.equal(bypass,true);
   this.getFetch({},3,5000);
   if(mode==='failure') throw new Error('SYNTHETIC_RAW_ERROR');
   process.stdout.write('SYNTHETIC_RAW_LOG');
   return {poToken:mode==='oversize'?'x'.repeat(40000):'SYNTHETIC_TOKEN_ONLY_123456',expiresAt:new Date(Date.now()+60000)};
  }
 }
 const context=vm.createContext({process,Buffer,console:{},fs:{readFileSync:()=>JSON.stringify(input)},loadProvider:async()=>({SessionManager})});
 await new vm.Script('(async()=>{'+source+'})()').runInContext(context);
 assert.deepEqual(fetches.map(x=>x.attempts),[1]);
 if(mode==='success') {
  assert.deepEqual(exits,[0]);assert.equal(emitted.length,1);
  assert.equal(JSON.parse(emitted[0]).token,'SYNTHETIC_TOKEN_ONLY_123456');
 } else { assert.deepEqual(exits,[1]);assert.deepEqual(emitted,[]); }
}
console.log('PASS: one-shot provider wrapper, suppressed raw logs, bounded output, no upstream runtime executed');
