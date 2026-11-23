"""Offline package/sandbox contract. Never contacts YouTube or downloads media.

Run in a fresh image with --network none, not in a production container.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from web_download_worker import configure_limits, install_guards, youtube_support


def main():
    support = youtube_support()
    assert support['available'], support
    with tempfile.TemporaryDirectory(prefix='muse-ejs-offline-') as folder:
        os.chdir(folder)
        configure_limits()
        install_guards()

        def deny(*args, **kwargs):
            raise AssertionError('Network access forbidden in offline runtime check')

        socket.getaddrinfo = deny
        socket.socket.connect = deny
        socket.socket.connect_ex = deny
        # Import after installing the process guard, like the real worker.
        import yt_dlp
        from yt_dlp.globals import plugin_dirs
        plugin_dirs.value = []
        from yt_dlp.extractor.youtube import YoutubeIE
        from yt_dlp.extractor.youtube.jsc._builtin.deno import DenoJCP
        from yt_dlp.extractor.youtube.jsc._builtin.ejs import ScriptSource
        from yt_dlp.extractor.youtube.jsc.provider import (
            JsChallengeRequest, JsChallengeType, NChallengeInput, SigChallengeInput,
        )

        class Quiet:
            def debug(self, *args, **kwargs): pass
            info = warning = error = debug

        with yt_dlp.YoutubeDL(dict(js_runtimes={'deno': {'path': shutil.which('deno')}},
                                  remote_components=set(), cachedir=False, proxy='',
                                  cookiefile=None, cookiesfrombrowser=None, logger=Quiet())) as ydl:
            provider = DenoJCP(ie=YoutubeIE(ydl), logger=Quiet(), settings={})
            assert provider.is_available()
            assert provider._lib_script.source is ScriptSource.PYPACKAGE
            assert provider._core_script.source is ScriptSource.PYPACKAGE
            requests = [
                JsChallengeRequest(JsChallengeType.N, NChallengeInput('https://fixture.invalid/player.js', ['abc'])),
                JsChallengeRequest(JsChallengeType.SIG, SigChallengeInput('https://fixture.invalid/player.js', ['abc'])),
            ]
            # Real bundled EJS core and yt-dlp stdin/protocol; synthetic prepared player.
            player = '_result.n = x => x.split("").reverse().join(""); _result.sig = x => x + "!";'
            result = json.loads(provider._run_js_runtime(provider._construct_stdin(player, True, requests)))
            assert result == dict(type='result', responses=[
                dict(type='result', data={'abc': 'cba'}), dict(type='result', data={'abc': 'abc!'}),
            ]), 'Synthetic EJS solution failed'
            script = '''
const checks = [
  () => Deno.readTextFile('/etc/passwd'),
  () => Deno.writeTextFile('must-not-exist', 'synthetic'),
  () => Deno.connect({hostname:'127.0.0.1', port:18080}),
  () => Deno.env.get('PATH'),
  () => new Deno.Command('/bin/sh', {args:['-c','true']}).output(),
  () => Deno.hostname(),
  () => Deno.dlopen('/nonexistent', {}),
];
const results = [];
for (const check of checks) {
  try { await check(); results.push('unexpected_success'); }
  catch (error) { results.push(error.name); }
}
console.log(JSON.stringify(results));
'''
            denied = json.loads(provider._run_js_runtime(script))
            assert denied == ['NotCapable'] * 7, denied
            assert not Path('must-not-exist').exists()
    print('PASS: packaged EJS/Deno, synthetic n/signature solutions, denied file/network/env/process/system/FFI access')


if __name__ == '__main__':
    main()
