"""Unpacked Chromium, synthetic httpOnly cookie and worker-only fake upload."""
import asyncio
import json
import os
import tempfile
from pathlib import Path
from urllib.parse import urlsplit
from playwright.async_api import async_playwright, expect

ROOT = str(Path(__file__).resolve().parents[1])
ID = 'lloaecnfmnmampknhgnpagabengejlaj'
ORIGINS = ['https://muapp-3d6.pages.dev', 'https://muse.dntrip.xyz']
REJECTED = ['http://muse.dntrip.xyz', 'https://sub.muse.dntrip.xyz',
            'https://muse.dntrip.xyz.evil.example', 'https://muse.dntrip.xyz:8443']

async def main():
    scratch = Path(os.environ.get('TMPDIR', str(Path.home() / '.cache')))
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='muse-import-', dir=scratch) as profile:
        async with async_playwright() as p:
            ctx = await p.chromium.launch_persistent_context(
                profile, executable_path='/usr/bin/chromium', headless=True,
                args=['--no-sandbox', f'--disable-extensions-except={ROOT}/extension',
                      f'--load-extension={ROOT}/extension'])
            async def route_fixture(route):
                u = urlsplit(route.request.url)
                if f'{u.scheme}://{u.netloc}' in ORIGINS + REJECTED:
                    await route.fulfill(status=200, content_type='text/html',
                                        body='<h1>Synthetic Muse import fixture</h1>')
                elif u.scheme == 'chrome-extension':
                    await route.continue_()
                else:
                    await route.abort()
            await ctx.route('**/*', route_fixture)
            worker = ctx.service_workers[0] if ctx.service_workers else await ctx.wait_for_event('serviceworker')
            assert ID in worker.url, worker.url
            await worker.evaluate('''() => { globalThis.uploads=[]; globalThis.fetch=async(url, options)=>{uploads.push({url,options});return {ok:true,status:200};}; }''')
            await ctx.add_cookies([{'name':'hatch_sess','value':'SYNTHETIC_BROWSER_FIXTURE',
                                   'domain':'.muse.ai','path':'/','httpOnly':True,'secure':True}])
            for index, origin in enumerate(ORIGINS):
                nonce = str(index + 1) * 64
                page = await ctx.new_page()
                await page.goto(origin)
                ping = await page.evaluate('(id)=>new Promise(resolve=>chrome.runtime.sendMessage(id,{type:"muse.ping"},resolve))', ID)
                assert ping == {'version':1}, ping
                async with ctx.expect_page() as popup:
                    await page.evaluate('''({extension,id}) => { window.result=null; chrome.runtime.sendMessage(extension,{type:'muse.prepare',id,base:'https://muse.dntrip.xyz'},r=>window.result=r); }''', {'extension':ID,'id':nonce})
                approval = await popup.value
                await expect(approval.locator('#origin')).to_have_text(origin)
                await expect(approval.locator('#target')).to_have_text('https://muse.dntrip.xyz/admin/accounts')
                await approval.locator('#approve').click()
                await page.wait_for_function('window.result?.code === "approved"')
                result = await page.evaluate('''({extension,id})=>new Promise(resolve=>chrome.runtime.sendMessage(extension,{type:'muse.commit',id,key:'synthetic-user-key'},resolve))''', {'extension':ID,'id':nonce})
                assert result == {'id':nonce,'code':'imported'}, result
                assert 'SYNTHETIC' not in json.dumps(result)
                await page.close()
                print(f'PASS approved exact frontend {origin}')
            for origin in REJECTED:
                page = await ctx.new_page()
                await page.goto(origin)
                result = await page.evaluate('''async id => { if (!globalThis.chrome?.runtime?.sendMessage) return 'blocked'; return await new Promise(resolve => chrome.runtime.sendMessage(id,{type:'muse.ping'},response=>{ const error=chrome.runtime.lastError; resolve(error || !response ? 'blocked' : 'allowed'); })); }''', ID)
                assert result == 'blocked', (origin, result)
                await page.close()
                print(f'PASS rejected frontend {origin}')
            uploads = await worker.evaluate('uploads')
            assert len(uploads) == len(ORIGINS)
            for upload in uploads:
                assert upload['url'] == 'https://muse.dntrip.xyz/admin/accounts'
                options = upload['options']
                assert options['method'] == 'POST'
                assert options['headers']['Authorization'] == 'Bearer synthetic-user-key'
                assert json.loads(options['body'])['cookies'] == {'hatch_sess':'SYNTHETIC_BROWSER_FIXTURE'}
                assert options['redirect'] == 'error' and options['credentials'] == 'omit'
            await ctx.close()
            print('PASS real Chromium: fixed ID; both approved origins; 4 rejected origins; synthetic httpOnly direct fixture POST; no cookie response')

if __name__ == '__main__':
    asyncio.run(main())
