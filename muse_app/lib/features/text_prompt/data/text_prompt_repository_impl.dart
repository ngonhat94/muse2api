import 'dart:async';
import 'dart:convert';

import '../../../core/errors/app_failure.dart';

import 'package:http/http.dart' as http;

import '../domain/text_prompt_repository.dart';

/// Isolated third-party transport; no Muse connection or credentials.
class TextPromptRepositoryImpl implements TextPromptRepository {
  TextPromptRepositoryImpl(
    this.clientFactory, {
    this.timeout = const Duration(seconds: 90),
  });
  final http.Client Function() clientFactory;
  final Duration timeout;
  @override
  Future<String> enhance(String text) async {
    final client = clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('https://imageprompt.org/api/ai/prompts/magic-enhance'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userPrompt': text,
              'page': 'image-prompt-generator',
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        final help = switch (response.statusCode) {
          401 => 'Dịch vụ yêu cầu đăng nhập trên imageprompt.org.',
          402 => 'Dịch vụ yêu cầu tín dụng trên imageprompt.org.',
          403 => 'Dịch vụ chặn yêu cầu. Thử trang gốc imageprompt.org.',
          429 => 'Quá nhiều yêu cầu. Chờ rồi gửi lại thủ công.',
          451 => 'Dịch vụ từ chối nội dung. Sửa mô tả rồi gửi lại.',
          _ => 'Dịch vụ không xử lý được. Thử lại sau.',
        };
        throw AppFailure(
          'imageprompt.org (HTTP ${response.statusCode}): $help',
        );
      }
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const AppFailure('Dịch vụ trả phản hồi không hợp lệ.');
      }
      if (data is! Map ||
          data['prompt'] is! String ||
          (data['prompt'] as String).trim().isEmpty) {
        throw const AppFailure('Dịch vụ trả phản hồi thiếu prompt hợp lệ.');
      }
      return (data['prompt'] as String).trim();
    } on TimeoutException {
      throw const AppFailure(
        'Yêu cầu hết thời gian. Kiểm tra mạng rồi gửi lại thủ công.',
      );
    } on http.ClientException {
      throw const AppFailure(
        'Không thể kết nối imageprompt.org. Kiểm tra mạng; bản web có thể bị CORS chặn. Dùng desktop hoặc trang gốc.',
      );
    } finally {
      client.close();
    }
  }
}
