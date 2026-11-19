const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const P = require('../extension/import_policy.js');
const origin = P.origins[0];
assert.deepEqual(P.origins, ['https://muapp-3d6.pages.dev', 'https://muse.dntrip.xyz']);
const manifest = JSON.parse(fs.readFileSync(require.resolve('../extension/manifest.json')));
assert.deepEqual(manifest.externally_connectable.matches, P.origins.map(o => o + '/*'));
for (const o of P.origins) assert(manifest.host_permissions.includes(o + '/*'));
for (const o of P.origins) assert(P.trusted({origin:o,url:o+'/accounts',frameId:0,documentId:'fixture',tab:{id:7}}));
for (const o of ['http://muse.dntrip.xyz','https://sub.muse.dntrip.xyz','https://muse.dntrip.xyz.evil.example','https://muse.dntrip.xyz:8443']) assert(!P.trusted({origin:o,url:o+'/',frameId:0,documentId:'fixture',tab:{id:7}}));
const sender = {origin, url: origin + '/accounts', frameId: 0, documentId: 'doc', tab:{id:7}};
const id = 'a'.repeat(64);
for (const base of ['http://muse.dntrip.xyz','https://127.0.0.1','https://localhost','https://evil.example','https://muse.dntrip.xyz?x=1','https://x@muse.dntrip.xyz','https://muse.dntrip.xyz/#x','https://muse.dntrip.xyz:8443','https://muse.dntrip.xyz/%2e%2e/x']) assert.throws(() => P.destination(base));
assert.equal(P.destination('https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech'), 'https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech/admin/accounts');
assert.equal(P.destination('https://muse.dntrip.xyz/prefix'), 'https://muse.dntrip.xyz/prefix/admin/accounts');
assert(P.trusted(sender));
for (const s of [{...sender,origin:'https://evil.example'}, {...sender,frameId:1}, {...sender,documentId:undefined}, {...sender,url:'https://preview.muapp-3d6.pages.dev'}]) assert(!P.trusted(s));
function harness() {
 let external, internal, removed, updated, closed;
 const uploads=[], responses=[], reads=[];
 const ctx={ ImportPolicy:P, URL, console:{log(){throw Error('no logs');}}, AbortSignal,
  setTimeout:()=>1, clearTimeout:()=>{}, Date, AbortController,
  importScripts(){}, fetch:async(url,options)=>{uploads.push({url,options});return {ok:true};},
  chrome:{ runtime:{getURL:p=>'chrome-extension://fixture/'+p,
   onMessageExternal:{addListener:f=>external=f},onMessage:{addListener:f=>internal=f}},
   windows:{onRemoved:{addListener:f=>removed=f},create:async()=>({id:10}),remove:async()=>{}},
   tabs:{onUpdated:{addListener:f=>updated=f},onRemoved:{addListener:f=>closed=f},get:async()=>({url:origin})},
   cookies:{getAll:async o=>{reads.push(o);return [{domain:'.muse.ai',name:'hatch_sess',value:'SYNTHETIC',expirationDate:123},{domain:'evilmuse.ai',name:'bad',value:'NO'}];}}}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../extension/background.js'),'utf8'),ctx);
 const send=(m,s=sender)=>external(m,s,r=>responses.push(r));
 const approval=type=>internal({type},{url:'chrome-extension://fixture/approval.html?id='+id},()=>{});
 return {ctx,send,approval,responses,uploads,reads,updated:(...args)=>updated(...args)};
}
(async()=>{
 let h=harness();h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'}, {...sender,origin:'https://evil.example'});assert.equal(h.responses.length,0);assert.equal(h.reads.length,0);
 h.send({type:'muse.commit',id,key:'fixture'});assert.equal(h.reads.length,0);
 h=harness();h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});assert.equal(h.reads.length,0);
 h.approval('deny');h.send({type:'muse.commit',id,key:'fixture'});assert.equal(h.uploads.length,0);
 h=harness();h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});h.approval('approve');
 h.send({type:'muse.commit',id,key:'fixture'}, {...sender,documentId:'other'});assert.equal(h.reads.length,0);
 h.send({type:'muse.commit',id,key:'fixture'}); await new Promise(setImmediate);
 assert.equal(h.uploads.length,1);
 const {url,options}=h.uploads[0];
 assert.equal(url,'https://muse.dntrip.xyz/admin/accounts');assert.equal(options.method,'POST');
 assert.equal(options.headers.Authorization,'Bearer fixture');assert.equal(options.redirect,'error');assert.equal(options.credentials,'omit');
 assert.deepEqual(JSON.parse(options.body),{label:'',cookies:{hatch_sess:'SYNTHETIC'},expires:{hatch_sess:123}});
 assert(!JSON.stringify(h.responses).includes('SYNTHETIC'));assert(!JSON.stringify(h.responses).includes('fixture'));
 assert(h.responses.some(r=>r.id===id&&r.code==='imported'));
 h.send({type:'muse.commit',id,key:'fixture'});await new Promise(setImmediate);assert.equal(h.uploads.length,1);
 h=harness();h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});h.updated(7,{status:'loading'});h.approval('approve');h.send({type:'muse.commit',id,key:'fixture'});assert.equal(h.reads.length,0);
 h=harness();h.ctx.fetch=async()=>{throw Error('redirect or network');};h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});h.approval('approve');h.send({type:'muse.commit',id,key:'fixture'});await new Promise(setImmediate);assert(h.responses.some(r=>r.code==='uncertain'));
 h=harness();h.ctx.fetch=async()=>({ok:false,status:401});h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});h.approval('approve');h.send({type:'muse.commit',id,key:'fixture'});await new Promise(setImmediate);assert(h.responses.some(r=>r.code==='unauthorized'));
 h=harness();h.ctx.Date={now:()=>100};h.send({type:'muse.prepare',id,base:'https://muse.dntrip.xyz'});h.approval('approve');h.ctx.Date.now=()=>1000000;h.send({type:'muse.commit',id,key:'fixture'});assert.equal(h.reads.length,0);
 console.log('PASS: policy, approval, cancellation, document binding, nonce replay, exact payload/auth/POST, redirect-error and no cookie leak');
})().catch(e=>{console.error(e);process.exitCode=1;});
