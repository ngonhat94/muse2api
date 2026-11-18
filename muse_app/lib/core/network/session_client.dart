import 'package:http/http.dart' as http;

/// Reports credential rejection without coupling transport to presentation.
class SessionClient extends http.BaseClient {
  SessionClient(this.inner, this.onRejected, {this.isCurrent});
  final bool Function()? isCurrent;
  bool _closed = false;
  bool get isClosed => _closed;
  final http.Client inner;
  final void Function(Uri, String) onRejected;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed || isCurrent?.call() == false) {
      throw http.ClientException('Session ended');
    }
    final response = await inner.send(request);
    if (_closed || isCurrent?.call() == false) {
      throw http.ClientException('Session ended');
    }
    final authorization = request.headers['Authorization'];
    if (response.statusCode == 401 && authorization != null) {
      onRejected(request.url, authorization);
    }
    return response;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    inner.close();
  }
}
