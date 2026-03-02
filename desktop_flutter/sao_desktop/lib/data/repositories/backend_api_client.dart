import 'dart:convert';
import 'dart:io';

import '../../core/config/data_mode.dart';

class BackendApiClient {
  const BackendApiClient();

  Future<dynamic> getJson(String path) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw StateError('backendBaseUrl is empty');
    }

    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();

    final request = await client.getUrl(uri);
    request.headers.contentType = ContentType.json;

    final token = AppDataMode.backendBearerToken.trim();
    if (token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backend GET failed (${response.statusCode}) for $path: $body',
        uri: uri,
      );
    }

    if (body.isEmpty) {
      return null;
    }

    return jsonDecode(body);
  }
}
