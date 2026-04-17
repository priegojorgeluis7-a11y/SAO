import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';

class UploadInitResult {
  final String evidenceId;
  final String objectPath;
  final String signedUrl;
  final DateTime? expiresAt;

  const UploadInitResult({
    required this.evidenceId,
    required this.objectPath,
    required this.signedUrl,
    required this.expiresAt,
  });

  factory UploadInitResult.fromJson(Map<String, dynamic> json) {
    return UploadInitResult(
      evidenceId: (json['evidenceId'] ?? '').toString(),
      objectPath: (json['objectPath'] ?? '').toString(),
      signedUrl: (json['signedUrl'] ?? '').toString(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
    );
  }
}

class EvidenceUploadRepository {
  final ApiClient _apiClient;
  final AppDb _db;
  final Dio _uploadDio;
  final Uuid _uuid;

  EvidenceUploadRepository({
    ApiClient? apiClient,
    AppDb? db,
    Dio? uploadDio,
    Uuid? uuid,
  })  : _apiClient = apiClient ?? GetIt.instance<ApiClient>(),
        _db = db ?? GetIt.instance<AppDb>(),
        _uploadDio = uploadDio ?? Dio(),
        _uuid = uuid ?? const Uuid();

  Future<UploadInitResult> uploadInit({
    required String activityId,
    required String mimeType,
    required int sizeBytes,
    required String fileName,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/evidences/upload-init',
      data: {
        'activityId': activityId,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'fileName': fileName,
      },
    );

    final data = (response.data as Map).cast<String, dynamic>();
    return UploadInitResult.fromJson(data);
  }

  Future<void> uploadBytesToSignedUrl({
    required String signedUrl,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await _uploadDio.put<void>(
      signedUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': mimeType,
        },
      ),
    );
  }

  Future<void> uploadComplete({
    required String evidenceId,
    String? description,
  }) async {
    final data = {'evidenceId': evidenceId};
    if (description != null && description.trim().isNotEmpty) {
      data['description'] = description.trim();
    }
    await _apiClient.post<dynamic>(
      '/evidences/upload-complete',
      data: data,
    );
  }

  Future<String> enqueuePendingUpload({
    required String activityId,
    required String localPath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    String? description,
  }) async {
    final queueId = _uuid.v4();
    final now = DateTime.now();
    final normalizedDescription = description?.trim();

    await _db.into(_db.pendingUploads).insert(
          PendingUploadsCompanion.insert(
            id: queueId,
            activityId: activityId,
            localPath: localPath,
            fileName: fileName,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            description: Value(
              normalizedDescription != null && normalizedDescription.isNotEmpty
                  ? normalizedDescription
                  : null,
            ),
            status: const Value('PENDING_INIT'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    appLogger.i('📥 Pending upload queued: $queueId ($fileName)');
    return queueId;
  }
}
