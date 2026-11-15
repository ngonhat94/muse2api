const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync('admin.html', 'utf8');
assert.match(html, /function generationAdmission\(/, 'web admission key lifecycle missing');
const start = html.indexOf('const generationAdmissions =');
const end = html.indexOf('async function runImage()', start);
let serial = 0;
const context = {crypto: {randomUUID: () => `synthetic-${++serial}`}, confirm: () => false, KEY: 'owner-a'};
vm.createContext(context);
vm.runInContext(html.slice(start, end), context);
const first = vm.runInContext("generationAdmission('image', {prompt:'one'})", context);
assert.equal(vm.runInContext("generationAdmission('image', {prompt:'one'})", context), first);
assert.equal(vm.runInContext("generationAdmission('image', {prompt:'two'})", context), null, 'changed uncertain request needs consent');
context.confirm = () => true;
assert.notEqual(vm.runInContext("generationAdmission('image', {prompt:'two'})", context), first);
context.KEY = 'owner-b';
assert.notEqual(vm.runInContext("generationAdmission('image', {prompt:'two'})", context), first);
for (const name of ['runImage','runVideo']) {
 const body = html.slice(html.indexOf(`async function ${name}()`), html.indexOf('\n}', html.indexOf(`async function ${name}()`))+2);
 assert.match(body, /Idempotency-Key/);
 assert.match(body, /generationAdmission/);
}
console.log('web admission lifecycle PASS');
