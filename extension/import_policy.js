// Pure policy: shared by the worker and synthetic tests. No credentials here.
(function (root) {
  const origins = Object.freeze(['https://muapp-3d6.pages.dev', 'https://muse.dntrip.xyz']);
  function destination(value) {
    if (typeof value !== 'string' || value.length > 2048 || /[\\\s%]/.test(value)) throw Error('invalid_destination');
    const u = new URL(value);
    const h = u.hostname.toLowerCase();
    if (!['https://muse.dntrip.xyz', 'https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech'].includes(u.origin) || u.protocol !== 'https:' || u.username || u.password || u.search || u.hash ||
        u.port && u.port !== '443' || !h.includes('.') || /[\[\]:]/.test(h) ||
        /^[\d.]+$/.test(h) || /\.(localhost|local|internal|lan|home|test|invalid)$/.test(h) ||
        h.endsWith('.') || /%|\/\.|\/\//.test(u.pathname)) throw Error('invalid_destination');
    return u.origin + u.pathname.replace(/\/+$/, '') + '/admin/accounts';
  }
  function trusted(sender) {
    try {
      const u = new URL(sender.url);
      return origins.includes(u.origin) && sender.origin === u.origin &&
        Number.isInteger(sender.tab?.id) && sender.frameId === 0 && !!sender.documentId;
    } catch (_) { return false; }
  }
  function validId(id) { return typeof id === 'string' && /^[a-f0-9]{64}$/.test(id); }
  const policy = { origins, destination, trusted, validId };
  if (typeof module !== 'undefined') module.exports = policy;
  root.ImportPolicy = policy;
})(globalThis);
