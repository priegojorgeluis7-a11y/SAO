import 'package:http/http.dart' as http;

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
    final headers = <String, String>{
      'Content-Type': mimeType,
      'Content-Length': '${bytes.length}',
    };

    final shouldAttachAuth =
        uri.path.contains('/api/v1/evidences/local-upload/');
    if (shouldAttachAuth) {
      final token = _resolveAccessToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await http.put(uri, headers: headers, body: bytes)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Signed upload failed with status ${response.statusCode}',
      );
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
