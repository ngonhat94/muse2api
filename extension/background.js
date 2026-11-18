importScripts('import_policy.js');
const pending = new Map();
const used = new Set();
const TTL = 90_000;
const P = ImportPolicy;
function identity(s) { return `${s.tab.id}:${s.documentId}:${s.origin}`; }
function finish(id, code) {
  const r = pending.get(id);
  if (!r) return;
  pending.delete(id);
  clearTimeout(r.timer);
  r.controller?.abort();
  r.reply?.({ id, code });
  if (r.windowId) chrome.windows.remove(r.windowId).catch(() => {});
}
chrome.windows.onRemoved.addListener((windowId) => {
  for (const [id, r] of pending) if (r.windowId === windowId) finish(id, 'cancelled');
});
chrome.tabs.onUpdated.addListener((tabId, change) => {
  if (change.status === 'loading') for (const [id, r] of pending) if (r.tabId === tabId) finish(id, 'cancelled');
});
chrome.tabs.onRemoved.addListener((tabId) => {
  for (const [id, r] of pending) if (r.tabId === tabId) finish(id, 'cancelled');
});
chrome.runtime.onMessageExternal.addListener((m, s, reply) => {
  if (!P.trusted(s)) return false;
  if (m?.type === 'muse.ping') { reply({ version: 1 }); return false; }
  if (!P.validId(m?.id)) return false;
  const id = m.id;
  if (m.type === 'muse.cancel') {
    if (pending.get(id)?.identity === identity(s)) finish(id, 'cancelled');
    reply({ id, code: 'cancelled' }); return false;
  }
  if (m.type === 'muse.prepare') {
    let target;
    try { target = P.destination(m.base); } catch (_) { reply({ id, code: 'invalid_destination' }); return false; }
    if (used.has(id) || pending.size >= 4 || used.size >= 4096 ||
        [...pending.values()].some(r => r.identity === identity(s))) {
      reply({ id, code: 'busy' }); return false;
    }
    used.add(id);
    const r = { identity: identity(s), tabId: s.tab.id, origin: s.origin, target,
      approved: false, expires: Date.now() + TTL, reply };
    pending.set(id, r);
    r.timer = setTimeout(() => finish(id, 'expired'), TTL);
    chrome.windows.create({ url: chrome.runtime.getURL('approval.html') + '?id=' + id,
      type: 'popup', width: 520, height: 540 }).then(w => {
        if (pending.get(id) === r) r.windowId = w.id;
        else chrome.windows.remove(w.id).catch(() => {});
      }).catch(() => finish(id, 'unavailable'));
    return true;
  }
  if (m.type === 'muse.commit') {
    const r = pending.get(id);
    if (!r || !r.approved || r.identity !== identity(s) || Date.now() >= r.expires ||
        typeof m.key !== 'string' || !m.key || m.key.length > 4096 || /[\r\n]/.test(m.key)) {
      reply({ id, code: 'invalid_request' }); return false;
    }
    // Consume before any asynchronous cookie read or POST: never retry a mutation.
    r.approved = false; r.committing = true; r.reply = reply;
    r.controller = new AbortController();
    clearTimeout(r.timer); r.timer = setTimeout(() => finish(id, 'uncertain'), 20000);
    const key = m.key; m.key = '';
    (async () => {
      try {
        const tab = await chrome.tabs.get(r.tabId);
        if (new URL(tab.url).origin !== r.origin) throw Error();
        const all = await chrome.cookies.getAll({ domain: 'muse.ai' });
        const cookies = {}, expires = {};
        for (const c of all) {
          const d = c.domain.replace(/^\./, '');
          if (d !== 'muse.ai' && !d.endsWith('.muse.ai')) continue;
          cookies[c.name] = c.value;
          if (c.expirationDate) expires[c.name] = Math.floor(c.expirationDate);
        }
        if (pending.get(id) !== r) return;
        if (!cookies.hatch_sess) { finish(id, 'no_session'); return; }
        const response = await fetch(r.target, { method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + key },
          body: JSON.stringify({ label: '', cookies, expires }),
          redirect: 'error', credentials: 'omit', cache: 'no-store',
          referrerPolicy: 'no-referrer', signal: r.controller.signal });
        // Never return response bodies, cookie values, account records or server errors.
        finish(id, response.ok ? 'imported' : response.status === 401 || response.status === 403 ? 'unauthorized' : 'uncertain');
      } catch (_) { finish(id, 'uncertain'); }
    })();
    return true;
  }
  return false;
});
chrome.runtime.onMessage.addListener((m, s, reply) => {
  if (!s.url?.startsWith(chrome.runtime.getURL('approval.html') + '?id=')) return false;
  const id = new URL(s.url).searchParams.get('id');
  const r = pending.get(id);
  if (!r || r.committing || Date.now() >= r.expires) { reply({ code: 'expired' }); return false; }
  if (m.type === 'view') { reply({ origin: r.origin, target: r.target }); return false; }
  if (m.type === 'deny') { finish(id, 'cancelled'); reply({ code: 'cancelled' }); return false; }
  if (m.type === 'approve' && !r.approved) {
    r.approved = true;
    r.reply({ id, code: 'approved' }); r.reply = null;
    const windowId = r.windowId; r.windowId = null;
    if (windowId) chrome.windows.remove(windowId).catch(() => {});
    reply({ code: 'approved' });
  }
  return false;
});
