import 'dart:io';

import '../../core/auth/token_store.dart';
import '../../core/config/data_mode.dart';
import 'backend_api_client.dart';

class EvidenceUploadInitResponse {
  final String evidenceId;
  final String signedUrl;

  const EvidenceUploadInitResponse({
    required this.evidenceId,
    required this.signedUrl,
  });
}

class EvidenceRepository {
  final BackendApiClient _apiClient;

  EvidenceRepository({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? const BackendApiClient();

  Future<String> getDownloadSignedUrl(String evidenceId) async {
    final response = await _apiClient
        .getJson('/api/v1/evidences/$evidenceId/download-url')
        .timeout(const Duration(seconds: 8));
    if (response is! Map<String, dynamic>) {
      throw StateError('Invalid response while fetching evidence download URL');
    }

    final signedUrl = (response['signedUrl'] ?? '').toString();
    if (signedUrl.isEmpty) {
      throw StateError('Missing signedUrl in download-url response');
    }

    return signedUrl;
  }

  Future<EvidenceUploadInitResponse> uploadInit({
    required String activityId,
    required String fileName,
    required int sizeBytes,
    String mimeType = 'application/pdf',
  }) async {
    final response = await _apiClient
        .postJson('/api/v1/evidences/upload-init', <String, dynamic>{
      'activityId': activityId,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'fileName': fileName,
    }).timeout(const Duration(seconds: 12));

    if (response is! Map<String, dynamic>) {
      throw StateError('Invalid response while initializing evidence upload');
    }

    final evidenceId = (response['evidenceId'] ?? '').toString().trim();
    final signedUrl = (response['signedUrl'] ?? '').toString().trim();
    if (evidenceId.isEmpty || signedUrl.isEmpty) {
      throw StateError('Missing evidenceId or signedUrl in upload-init response');
    }

    return EvidenceUploadInitResponse(
      evidenceId: evidenceId,
      signedUrl: signedUrl,
    );
  }

  Future<void> uploadToSignedUrl({
    required String signedUrl,
    required List<int> bytes,
    String mimeType = 'application/pdf',
  }) async {
    final uri = Uri.parse(signedUrl);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final request = await client.putUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      request.contentLength = bytes.length;

      final shouldAttachAuth =
          uri.path.contains('/api/v1/evidences/local-upload/');
      if (shouldAttachAuth) {
        final token = _resolveAccessToken();
        if (token.isNotEmpty) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
      }

      request.add(bytes);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Signed upload failed with status ${response.statusCode}',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> uploadComplete(String evidenceId) async {
    await _apiClient
        .postJson('/api/v1/evidences/upload-complete', <String, dynamic>{
      'evidenceId': evidenceId,
    }).timeout(const Duration(seconds: 12));
  }

  String _resolveAccessToken() {
    if (TokenStore.hasToken) {
      return TokenStore.current.trim();
    }
    return AppDataMode.backendBearerToken.trim();
  }
}
