// lib/features/notifications/data/notifications_repository.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';

/// Model for a notification fetched from the backend.
class UserNotificationDto {
  final String id;
  final String type;
  final String activityId;
  final String activityTitle;
  final String projectId;
  final String? fromUserId;
  final String? fromUserName;
  final String status;
  final bool requiresAcceptance;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? respondedAt;
  final Map<String, dynamic> metadata;

  const UserNotificationDto({
    required this.id,
    required this.type,
    required this.activityId,
    required this.activityTitle,
    required this.projectId,
    this.fromUserId,
    this.fromUserName,
    required this.status,
    required this.requiresAcceptance,
    required this.createdAt,
    this.readAt,
    this.respondedAt,
    this.metadata = const {},
  });

  factory UserNotificationDto.fromJson(Map<String, dynamic> j) {
    return UserNotificationDto(
      id: j['id'] as String? ?? '',
      type: j['type'] as String? ?? '',
      activityId: j['activity_id'] as String? ?? '',
      activityTitle: j['activity_title'] as String? ?? '',
      projectId: j['project_id'] as String? ?? '',
      fromUserId: j['from_user_id'] as String?,
      fromUserName: j['from_user_name'] as String?,
      status: j['status'] as String? ?? 'unread',
      requiresAcceptance: j['requires_acceptance'] as bool? ?? false,
      createdAt: _parseDateTime(j['created_at']) ?? DateTime.now(),
      readAt: _parseDateTime(j['read_at']),
      respondedAt: _parseDateTime(j['responded_at']),
      metadata: (j['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v as String);
    } catch (_) {
      return null;
    }
  }
}

class NotificationsRepository {
  NotificationsRepository({
    required ApiClient apiClient,
    required AppDb database,
  })  : _apiClient = apiClient,
        _database = database;

  final ApiClient _apiClient;
  final AppDb _database;

  /// Pull latest notifications from the backend and upsert into local DB.
  Future<void> sync({int limit = 50}) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/notifications',
        queryParameters: {'limit': limit},
      );
      final body = response.data;
      final rawItems =
          (body is Map ? body['items'] : body) as List<dynamic>? ?? [];
      final dtos = rawItems
          .whereType<Map<String, dynamic>>()
          .map(UserNotificationDto.fromJson)
          .toList();

      // Upsert all into Drift.
      for (final dto in dtos) {
        await _upsert(dto);
      }
      appLogger.i('NotificationsRepository: synced ${dtos.length} notifications');
    } on DioException catch (e) {
      appLogger.w('NotificationsRepository: sync failed: ${e.message}');
    } catch (e) {
      appLogger.w('NotificationsRepository: sync error: $e');
    }
  }

  /// Watch all notifications ordered by createdAt descending.
  Stream<List<UserNotification>> watchAll() {
    return (_database.select(_database.userNotifications)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watch unread count.
  Stream<int> watchUnreadCount() {
    return (_database.select(_database.userNotifications)
          ..where((t) => t.status.equals('unread')))
        .watch()
        .map((rows) => rows.length);
  }

  /// Mark a notification as read locally and on the backend.
  Future<void> markRead(String notificationId) async {
    await (_database.update(_database.userNotifications)
          ..where((t) => t.id.equals(notificationId)))
        .write(UserNotificationsCompanion(
      status: const drift.Value('read'),
      readAt: drift.Value(DateTime.now().toUtc()),
    ));
    try {
      await _apiClient.post<dynamic>('/notifications/$notificationId/read');
    } catch (_) {}
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    await (_database.update(_database.userNotifications)
          ..where((t) => t.status.equals('unread')))
        .write(UserNotificationsCompanion(
      status: const drift.Value('read'),
      readAt: drift.Value(DateTime.now().toUtc()),
    ));
    try {
      await _apiClient.post<dynamic>('/notifications/read-all');
    } catch (_) {}
  }

  /// Accept an assignment/transfer notification.
  Future<bool> accept({
    required String activityId,
    required String notificationId,
  }) async {
    try {
      await _apiClient.post<dynamic>(
        '/assignments/$activityId/accept',
        data: {'notification_id': notificationId},
      );
      await _updateStatus(notificationId, 'accepted');
      return true;
    } catch (e) {
      appLogger.e('NotificationsRepository: accept failed: $e');
      return false;
    }
  }

  /// Decline an assignment/transfer notification.
  Future<bool> decline({
    required String activityId,
    required String notificationId,
  }) async {
    try {
      await _apiClient.post<dynamic>(
        '/assignments/$activityId/decline',
        data: {'notification_id': notificationId},
      );
      await _updateStatus(notificationId, 'declined');
      return true;
    } catch (e) {
      appLogger.e('NotificationsRepository: decline failed: $e');
      return false;
    }
  }

  Future<void> _upsert(UserNotificationDto dto) async {
    final companion = UserNotificationsCompanion.insert(
      id: dto.id,
      type: dto.type,
      activityId: dto.activityId,
      activityTitle: drift.Value(dto.activityTitle),
      projectId: dto.projectId,
      fromUserId: drift.Value(dto.fromUserId),
      fromUserName: drift.Value(dto.fromUserName),
      status: drift.Value(dto.status),
      requiresAcceptance: drift.Value(dto.requiresAcceptance),
      createdAt: dto.createdAt,
      readAt: drift.Value(dto.readAt),
      respondedAt: drift.Value(dto.respondedAt),
      syncedAt: drift.Value(DateTime.now().toUtc()),
      metadataJson: drift.Value(
        dto.metadata.isNotEmpty ? jsonEncode(dto.metadata) : null,
      ),
    );
    await _database.into(_database.userNotifications).insertOnConflictUpdate(companion);
  }

  Future<void> _updateStatus(String notificationId, String newStatus) async {
    await (_database.update(_database.userNotifications)
          ..where((t) => t.id.equals(notificationId)))
        .write(UserNotificationsCompanion(
      status: drift.Value(newStatus),
      respondedAt: drift.Value(DateTime.now().toUtc()),
      readAt: drift.Value(DateTime.now().toUtc()),
    ));
  }
}
