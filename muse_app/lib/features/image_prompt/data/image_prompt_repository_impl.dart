import 'dart:async';
import 'dart:convert';

import '../../../core/errors/app_failure.dart';

import 'package:http/http.dart' as http;

import '../../../core/domain/reference_image.dart';
import '../domain/image_prompt_repository.dart';

/// Dedicated transport: never receives a Muse connection or credential store.
class ImagePromptRepositoryImpl implements ImagePromptRepository {
  ImagePromptRepositoryImpl(
    this.clientFactory, {
    this.timeout = const Duration(seconds: 90),
  });
  final http.Client Function() clientFactory;
  final Duration timeout;
  @override
  Future<String> generate(ReferenceImage image) async {
    final client = clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('https://imageprompt.org/api/ai/prompts/image'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'base64Url':
                  'data:${image.mime};base64,${base64Encode(image.bytes)}',
              'imageModelId': 0,
              'language': 'en',
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        final help = switch (response.statusCode) {
          401 => 'Dịch vụ yêu cầu đăng nhập trên imageprompt.org.',
          402 => 'Dịch vụ yêu cầu tín dụng trên imageprompt.org.',
          403 => 'Dịch vụ chặn yêu cầu. Thử trực tiếp trên imageprompt.org.',
          429 => 'Quá nhiều yêu cầu. Chờ rồi gửi lại thủ công.',
          451 => 'Dịch vụ từ chối nội dung ảnh. Chọn ảnh khác.',
          _ => 'Dịch vụ không xử lý được. Thử lại sau.',
        };
        throw AppFailure(
          'imageprompt.org (HTTP ${response.statusCode}): $help',
        );
      }
      final dynamic data;
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        throw const AppFailure(
          'Dịch vụ trả phản hồi không hợp lệ. Thử lại sau.',
        );
      }
      if (data is! Map ||
          data['prompt'] is! String ||
          (data['prompt'] as String).trim().isEmpty) {
        throw const AppFailure(
          'Dịch vụ trả phản hồi thiếu prompt hợp lệ. Thử lại sau.',
        );
      }
      return (data['prompt'] as String).trim();
    } on TimeoutException {
      throw const AppFailure(
        'Yêu cầu hết thời gian. Kiểm tra mạng rồi gửi lại thủ công.',
      );
    } on http.ClientException {
      throw const AppFailure(
        'Không thể kết nối imageprompt.org. Kiểm tra mạng; bản web có thể bị CORS chặn. Dùng bản desktop hoặc trang gốc.',
      );
    } finally {
      client.close();
    }
  }
}
