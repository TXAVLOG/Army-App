import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'txa_config.dart';

/// Service upload ảnh/voice lên Cloudinary thay Firebase Storage (miễn phí 25GB).
class TXACloudinaryService {
  TXACloudinaryService._();
  static final instance = TXACloudinaryService._();

  /// Tính HMAC-SHA1 signature cho signed upload
  String _sign(Map<String, String> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final toSign = sorted.map((e) => '${e.key}=${e.value}').join('&') + TXAConfig.cloudinaryApiSecret;
    final bytes = utf8.encode(toSign);
    return sha1.convert(bytes).toString();
  }

  /// Upload một file lên Cloudinary, trả về public URL download
  Future<String> uploadFile({
    required File file,
    required String folder,        // e.g. 'posts/photos'
    String resourceType = 'image', // 'image' | 'video' | 'raw'
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final publicId  = '${folder.replaceAll('/', '_')}_$timestamp';

    final params = {
      'folder'    : folder,
      'public_id' : publicId,
      'timestamp' : timestamp,
    };

    final signature = _sign(params);

    final uri = Uri.parse('${TXAConfig.cloudinaryUploadBaseUrl}/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key']   = TXAConfig.cloudinaryApiKey
      ..fields['timestamp'] = timestamp
      ..fields['signature'] = signature
      ..fields['folder']    = folder
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      debugPrint('Cloudinary upload error [${streamed.statusCode}]: $body');
      throw Exception('Upload thất bại (${streamed.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url  = json['secure_url'] as String?;

    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary không trả về URL: $body');
    }

    debugPrint('✅ Cloudinary upload OK: $url');
    return url;
  }

  /// Upload ảnh bài viết
  Future<String> uploadPostPhoto(File file) =>
      uploadFile(file: file, folder: 'posts/photos', resourceType: 'image');

  /// Upload voice note bài viết
  Future<String> uploadPostVoice(File file) =>
      uploadFile(file: file, folder: 'posts/voices', resourceType: 'raw');
}
