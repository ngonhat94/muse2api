// One process per job. Never starts upstream's HTTP server or shares its caches.
import fs from 'node:fs';
const output = process.stdout.write.bind(process.stdout);
for (const method of ['log','debug','info','warn','error','trace']) console[method] = () => {};
// Upstream diagnostics can contain tokens. Only the final bounded result is emitted.
process.stdout.write = () => true;
process.stderr.write = () => true;
try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const { SessionManager } = await import('/opt/bgutil/server/build/session_manager.js');
  const manager = new SessionManager();
  // Reviewed 2.0.2 method: force one upstream HTTP attempt, never its retry loop.
  const originalFetch = manager.getFetch.bind(manager);
  manager.getFetch = (proxy, _attempts, _delay) => originalFetch(proxy, 1, 0);
  const result = await manager.generatePoToken(input.binding, '', true);
  const expiry = new Date(result.expiresAt).getTime()/1000;
  const response = { ...input, token:result.poToken, expires_at:expiry };
  const text = JSON.stringify(response);
  if (Buffer.byteLength(text) > 32768) throw new Error('size');
  output(text);
  // All guest session/minter/token state dies with this process.
  process.exit(0);
} catch (_) {
  process.exit(1);
}
