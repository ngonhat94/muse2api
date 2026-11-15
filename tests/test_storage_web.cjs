const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const html = fs.readFileSync('admin.html', 'utf8');
const source = html.slice(html.indexOf('async function api('), html.indexOf('\n}', html.indexOf('async function api(')) + 2);
(async () => {
 for (const [status, expected] of [[429, '17'], [507, '存储']]) {
  const context = {KEY: 'synthetic', setAuth() {}, fetch: async () => ({status, ok:false, headers:{get:()=> '17'}, text:async()=>JSON.stringify({detail:'secret-cookie'})})};
  vm.createContext(context); vm.runInContext(source, context);
  await assert.rejects(context.api('/v1/images/tasks'), error => error.message.includes(expected) && !error.message.includes('secret-cookie'));
 }
 assert(html.includes('id="storageUsage"'));
 console.log('PASS: safe rate/storage errors and usage surface');
})();
