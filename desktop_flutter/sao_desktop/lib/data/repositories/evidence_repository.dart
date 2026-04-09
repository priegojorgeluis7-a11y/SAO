import 'backend_api_client.dart';

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
}
