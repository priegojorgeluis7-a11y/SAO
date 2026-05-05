// lib/features/notifications/state/notifications_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/app_db.dart';
import '../data/notifications_repository.dart';

/// Access to the repository singleton.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (_) => GetIt.I<NotificationsRepository>(),
);

/// Live stream of all notifications from local DB, newest first.
final notificationsStreamProvider =
    StreamProvider<List<UserNotification>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.watchAll();
});

/// Live count of unread notifications for the badge.
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.watchUnreadCount();
});
