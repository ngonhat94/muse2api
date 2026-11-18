import 'package:http/http.dart' as http;

/// Reports credential rejection without coupling transport to presentation.
class SessionClient extends http.BaseClient {
  SessionClient(this.inner, this.onRejected);
  final http.Client inner;
  final void Function(Uri, String) onRejected;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    final authorization = request.headers['Authorization'];
    if (response.statusCode == 401 && authorization != null) {
      onRejected(request.url, authorization);
    }
    return response;
  }

  @override
  void close() => inner.close();
}
