import asyncio, json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=str(Path(__file__).resolve().parents[1])
ID='lloaecnfmnmampknhgnpagabengejlaj'
async def main():
 async with async_playwright() as p:
  ctx=await p.chromium.launch_persistent_context(str(Path(__import__('os').environ.get('TMPDIR', str(Path.home()/'.cache'))) / 'muse-extension-smoke-profile'),channel='chromium',headless=True,args=['--no-sandbox',f'--disable-extensions-except={ROOT}/extension',f'--load-extension={ROOT}/extension'])
  await ctx.route('**/*',lambda route: route.fulfill(status=200,content_type='text/html',body='<h1>Synthetic Muse import fixture</h1>') if route.request.url.startswith('https://muapp-3d6.pages.dev') else route.continue_() if route.request.url.startswith('chrome-extension:') else route.abort())
  worker=ctx.service_workers[0] if ctx.service_workers else await ctx.wait_for_event('serviceworker')
  assert ID in worker.url,worker.url
  await worker.evaluate('''() => { globalThis.uploads=[]; globalThis.fetch=async(url, options)=>{uploads.push({url,options});return {ok:true,status:200};}; }''')
  await ctx.add_cookies([{'name':'hatch_sess','value':'SYNTHETIC_BROWSER_FIXTURE','domain':'.muse.ai','path':'/','httpOnly':True,'secure':True}])
  page=await ctx.new_page();await page.goto('https://muapp-3d6.pages.dev')
  ping=await page.evaluate('(id)=>new Promise(resolve=>chrome.runtime.sendMessage(id,{type:"muse.ping"},resolve))',ID)
  assert ping=={'version':1},ping
  await page.evaluate('''id => { window.result=null; chrome.runtime.sendMessage(id,{type:'muse.prepare',id:'b'.repeat(64),base:'https://muse.dntrip.xyz'},r=>window.result=r); }''',ID)
  approval=await ctx.wait_for_event('page')
  await approval.wait_for_load_state();await approval.locator('#approve').wait_for(state='visible')
  from playwright.async_api import expect
  await expect(approval.locator('#origin')).to_have_text('https://muapp-3d6.pages.dev')
  assert await approval.locator('#origin').inner_text()=='https://muapp-3d6.pages.dev'
  assert await approval.locator('#target').inner_text()=='https://muse.dntrip.xyz/admin/accounts'
  await approval.screenshot(path=str(Path(__import__('os').environ.get('TMPDIR', str(Path.home()/'.cache'))) / 'muse-import-approval-desktop.png'))
  await approval.locator('#approve').click();await page.wait_for_function('window.result?.code === "approved"')
  result=await page.evaluate('(extension)=>new Promise(resolve=>chrome.runtime.sendMessage(extension,{type:"muse.commit",id:"b".repeat(64),key:"synthetic-user-key"},resolve))',ID)
  assert result=={'id':'b'*64,'code':'imported'},result
  uploads=await worker.evaluate('uploads')
  assert len(uploads)==1 and uploads[0]['options']['method']=='POST'
  assert uploads[0]['options']['headers']['Authorization']=='Bearer synthetic-user-key'
  assert json.loads(uploads[0]['options']['body'])['cookies']=={'hatch_sess':'SYNTHETIC_BROWSER_FIXTURE'}
  assert uploads[0]['options']['redirect']=='error'
  assert 'SYNTHETIC' not in json.dumps(result)
  print('PASS real Chromium unpacked extension: fixed ID, external ping, trusted approval window, actual synthetic httpOnly cookie read, direct fixture POST, no cookie response')
  await ctx.close()
asyncio.run(main())
