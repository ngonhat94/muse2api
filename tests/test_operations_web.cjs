const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync('admin.html','utf8');
const start=html.indexOf('/* Operational dashboard */');
assert(start>=0,'manual operational dashboard absent');
const source=html.slice(start,html.indexOf('/* End operational dashboard */',start));
const nodes=new Map();const $=id=>{if(!nodes.has(id))nodes.set(id,{textContent:'',disabled:false});return nodes.get(id);};
const calls=[];const snapshot={tasks:{queued:2,running:1,failed:3,completed:0,cancelled:0,unknown:0},storage:{bytes:17,files:1,limits:{bytes:100,files:3}},oldest_queued_seconds:10,wait_estimate_seconds:null};
const c={$,KEY:'synthetic',CURRENT:{id:'A',role:'user'},api:async path=>{calls.push(path);return snapshot;}};
vm.createContext(c);vm.runInContext(source,c);
(async()=>{
await c.refreshOperations();assert.deepEqual(calls,['/v1/operations']);assert($('operationsSummary').textContent.includes('2'));assert($('operationsSummary').textContent.includes('17'));assert($('operationsSummary').textContent.includes('未知'));assert.equal($('operationsRefresh').disabled,false);
c.CURRENT={id:'admin',role:'admin'};c.api=async p=>{calls.push(p);return p==='/admin/operations'?{users:[{owner_id:'A',...snapshot}],disk:{available_bytes:99,temporary_bytes:null}}:snapshot;};
await c.refreshOperations();assert(calls.includes('/admin/operations'));assert($('operationsAggregate').textContent.includes('A'));assert($('operationsAggregate').textContent.includes('99'));
c.api=async()=>{throw new Error('PRIVATE cap=secret');};await c.refreshOperations();assert(!$('operationsSummary').textContent.includes('PRIVATE'));assert.equal($('operationsAggregate').textContent,'');
let release;c.CURRENT={id:'A',role:'user'};c.api=()=>new Promise(r=>{release=r;});const pending=c.refreshOperations();c.KEY='replacement';c.clearOperations();release(snapshot);await pending;assert(!$('operationsSummary').textContent.includes('17'));assert.equal($('operationsRefresh').disabled,false);
// Exercise the real key-rotation handler, not a test-side clearOperations call.
const rotate=html.slice(html.indexOf('async function rotateKey(){'),html.indexOf('/* Operational dashboard */'));
Object.assign(c,{confirm:()=>true,localStorage:{setItem(){}},KEY_STORE:'fixture',renderKey(){},buildCmd:()=>'',toast(){},closeTenantLimits(){},realKey:'old'});
vm.runInContext(rotate,c);
c.CURRENT={id:'admin',role:'admin'};c.KEY='old';
c.api=async p=>p==='/admin/apikey/rotate'?{api_key:'rotated'}:snapshot;
await c.refreshOperations();assert($('operationsSummary').textContent.includes('17'));
await c.rotateKey();assert(!$('operationsSummary').textContent.includes('17'),'rotation clears rendered snapshot');assert.equal($('operationsAggregate').textContent,'');assert.equal($('operationsRefresh').disabled,false);
c.KEY='old';c.CURRENT={id:'admin',role:'admin'};
let releaseRotation;c.api=p=>p==='/admin/apikey/rotate'?Promise.resolve({api_key:'rotated'}):new Promise(r=>{releaseRotation=r;});
const inflight=c.refreshOperations();await c.rotateKey();assert.equal($('operationsRefresh').disabled,false,'rotation unlocks refresh before old request returns');releaseRotation(snapshot);await inflight;assert(!$('operationsSummary').textContent.includes('17'));assert.equal($('operationsRefresh').disabled,false);
console.log('PASS: manual dashboard own/admin, safe failures, real rotation clears rendered/inflight snapshots and unlocks refresh');
})().catch(e=>{console.error(e);process.exitCode=1;});
