"""Explicit yt-dlp extractor adapter. Loaded after worker guards, no plugin discovery."""
import socket
from pot_broker import PotError, send_frame, recv_frame, validate_response


def install(downloader, fd, video_id):
    from yt_dlp.extractor.youtube import YoutubeIE as BaseYoutubeIE
    from yt_dlp.extractor.youtube.pot.provider import PoTokenContext
    from yt_dlp.extractor.youtube.pot.utils import get_webpo_content_binding

    conn = socket.socket(fileno=fd)
    conn.set_inheritable(False)
    conn.settimeout(25)

    class Director:
        def get_po_token(self, request):
            if (request.is_authenticated or request.data_sync_id or request.request_proxy
                    or request.request_source_address or not request.request_verify_tls
                    or request.context != PoTokenContext.GVS or request.internal_client_name != 'mweb'
                    or request.video_id != video_id):
                raise PotError('youtube_po_request_rejected')
            binding, kind = get_webpo_content_binding(request)
            payload = dict(client='mweb',context='gvs',video_id=video_id,
                           binding=binding,binding_type=kind.value if kind else None)
            send_frame(conn, payload)
            result = recv_frame(conn)
            if 'error' in result:
                reason = result['error']
                allowed = {'youtube_po_request_rejected','youtube_po_binding_mismatch','youtube_po_token_expired'}
                raise PotError(reason if reason in allowed else 'youtube_po_provider_failed')
            return validate_response(result, payload)['token']

    class YoutubeIE(BaseYoutubeIE):
        def _real_initialize(self):
            super()._real_initialize()
            self._pot_director = Director()

    # Same key as upstream YoutubeIE: replace it without enabling arbitrary plugins.
    downloader.add_info_extractor(YoutubeIE(downloader))
    return conn
