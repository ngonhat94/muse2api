import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html = readFileSync(new URL('../admin.html', import.meta.url), 'utf8');
const elements = new Map();
const $ = id => { if (!elements.has(id)) elements.set(id, {innerHTML:'',textContent:'',hidden:false,setAttribute(){}}); return elements.get(id); };
let rows = [
 {id:'active',label:'Active',enabled:true,key_active:true},
 {id:'disabled',label:'Disabled',enabled:false,key_active:true},
 {id:'legacy',label:'Legacy',enabled:false},
 {id:'revoked',label:'Revoked',enabled:false,key_active:false},
];
const calls=[];
const ctx = vm.createContext({$,CURRENT:{role:'admin'},esc:String,confirm:()=>true,toast(){},api:async (path,opts={})=>{calls.push([path,opts.method]); if(opts.method==='DELETE') rows=rows.map(u=>u.id==='active'?{...u,key_active:false}:u); return {users:rows};}});
vm.runInContext(html.slice(html.indexOf("let userKeyView = 'active';"),html.indexOf('function showOneTimeKey(')),ctx);
await vm.runInContext('loadUsers()',ctx);
assert.ok(!$('usersBody').innerHTML.includes('>Revoked<'),'revoked rows must not appear in default list');
for (const label of ['Active','Disabled','Legacy']) assert.ok($('usersBody').innerHTML.includes('>'+label+'<'));
assert.ok(!$('userKeyMetadataWarning').hidden,'old servers require explicit unknown-state notice');
await vm.runInContext("selectUserKeyView('revoked')",ctx);
assert.ok($('usersBody').innerHTML.includes('>Revoked<'));
assert.ok(!$('usersBody').innerHTML.includes('setTenantEnabled'));
assert.ok(!$('usersBody').innerHTML.includes('revokeTenantKey'));
await vm.runInContext("selectUserKeyView('active')",ctx);
vm.runInContext(html.slice(html.indexOf('async function revokeTenantKey('),html.indexOf('/* ================= 额度显示')),ctx);
await vm.runInContext("revokeTenantKey('active')",ctx);
assert.ok(!$('usersBody').innerHTML.includes('>Active<'),'confirmed revoke must refresh the filtered list');
assert.deepEqual(calls.find(c=>c[1]==='DELETE'),['/admin/users/active/key','DELETE']);
assert.match(html,/id="userKeysActive"[^>]*aria-pressed="true"/);
assert.match(html,/id="userKeysRevoked"/);
console.log('PASS admin active/revoked views, legacy warning, disabled retention and revoke refresh');
