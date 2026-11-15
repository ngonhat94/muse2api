import 'dart:convert';

import '../domain/reference_image.dart';

List<String> referencePayload(List<ReferenceImage> images) => images
    .map((image) => 'data:${image.mime};base64,${base64Encode(image.bytes)}')
    .toList(growable: false);
