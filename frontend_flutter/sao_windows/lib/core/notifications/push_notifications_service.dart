import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';
import '../utils/logger.dart';

/// Channel used for assignment push notifications on Android.
const AndroidNotificationChannel _assignmentChannel = AndroidNotificationChannel(
  'sao_assignments',
  'Actividades asignadas',
  description: 'Notificaciones de nuevas actividades y transferencias.',
  importance: Importance.high,
  sound: RawResourceAndroidNotificationSound('sao_notify'),
);

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

class PushNotificationsService {
  PushNotificationsService({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  bool _initialized = false;
  bool _enabled = false;
  String? _currentProjectId;
  String? _currentToken;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppMessageSub;

  final StreamController<RemoteMessage> _messagesController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get messages => _messagesController.stream;
  bool get isEnabled => _enabled;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    final options = _firebaseOptionsFromEnv();

    try {
      // If dart-define vars are present use them explicitly; otherwise let
      // google-services.json (Android) / GoogleService-Info.plist (iOS) handle
      // auto-configuration.
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }

      // Initialise flutter_local_notifications for foreground messages.
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          await _localNotifications.initialize(
            const InitializationSettings(android: androidInit),
          );
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(_assignmentChannel);
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          // On iOS, initialise flutter_local_notifications so it acts as the
          // UNUserNotificationCenterDelegate.  This lets _showForegroundLocalNotification
          // call show() and have notifications appear in the iOS notification
          // center even when the app is in the foreground.
          const iosInit = DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );
          await _localNotifications.initialize(
            const InitializationSettings(iOS: iosInit),
          );
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          // On macOS, let Firebase Messaging show system banners directly.
          await FirebaseMessaging.instance
              .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      _currentToken = await messaging.getToken();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        final projectId = _currentProjectId;
        if (projectId != null && projectId.isNotEmpty) {
          unawaited(registerCurrentDevice(projectId: projectId));
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        scheduleMicrotask(() => _messagesController.add(initialMessage));
      }

      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
        _messagesController.add(message);
        _showForegroundLocalNotification(message);
      });
      _openedAppMessageSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _messagesController.add,
      );

      _enabled = true;
      appLogger.i('PushNotificationsService initialized.');
    } catch (e, st) {
      appLogger.w(
        'PushNotificationsService initialization failed: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> registerCurrentDevice({required String projectId}) async {
    final normalizedProject = projectId.trim().toUpperCase();
    if (normalizedProject.isEmpty) return;

    await ensureInitialized();
    _currentProjectId = normalizedProject;

    if (!_enabled) return;

    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) return;

    _currentToken = token;

    try {
      await _apiClient.post<dynamic>(
        '/notifications/device-tokens',
        data: {
          'token': token,
          'project_id': normalizedProject,
          'platform': _currentPlatform(),
        },
      );
    } catch (e, st) {
      appLogger.w('registerCurrentDevice failed: $e', error: e, stackTrace: st);
    }
  }

  Future<void> registerCurrentDeviceForProjects({
    required List<String> projectIds,
  }) async {
    if (projectIds.isEmpty) return;
    for (final raw in projectIds) {
      final projectId = raw.trim().toUpperCase();
      if (projectId.isEmpty) continue;
      await registerCurrentDevice(projectId: projectId);
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    await _openedAppMessageSub?.cancel();
    await _messagesController.close();
  }

  /// Shows a local notification banner when a relevant message arrives while
  /// the app is in the foreground. Runs on Android and iOS.
  /// On iOS, flutter_local_notifications acts as UNUserNotificationCenterDelegate
  /// and adds the notification to the system notification center.
  void _showForegroundLocalNotification(RemoteMessage message) {
    if (kIsWeb) {
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final notification = message.notification;
    final data = message.data;
    final type = (data['type'] as String? ?? '').trim().toLowerCase();

    // Show banners for all relevant event types.
    const visibleTypes = {
      'new_assignment',
      'assignment_transferred',
      'assignment_update',
      'review_approved',
      'review_changes_required',
      'review_decision',
      'activity_update',
      'assignment_cancelled',
      'admin_message',
    };
    if (!visibleTypes.contains(type)) return;

    final defaultTitle = switch (type) {
      'assignment_transferred' => 'Actividad transferida',
      'review_approved' => 'Actividad aprobada',
      'review_changes_required' => 'Actividad requiere corrección',
      'review_decision' => 'Decisión de revisión',
      'activity_update' => 'Actividad actualizada',
      'assignment_cancelled' => 'Actividad cancelada',
      'assignment_update' => 'Agenda actualizada',
      'admin_message' => 'Mensaje del administrador',
      _ => 'Nueva actividad asignada',
    };
    final title = (notification?.title?.trim().isNotEmpty ?? false)
        ? notification!.title!
        : defaultTitle;
    final body = notification?.body ?? '';

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _assignmentChannel.id,
          _assignmentChannel.name,
          channelDescription: _assignmentChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('sao_notify'),
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'sao_notify.mp3',
          presentSound: true,
        ),
      ),
    );
  }

  FirebaseOptions? _firebaseOptionsFromEnv() {
    const apiKey = String.fromEnvironment(
      'SAO_FIREBASE_API_KEY',
      defaultValue: '',
    );
    const appId = String.fromEnvironment(
      'SAO_FIREBASE_APP_ID',
      defaultValue: '',
    );
    const senderId = String.fromEnvironment(
      'SAO_FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '',
    );
    const projectId = String.fromEnvironment(
      'SAO_FIREBASE_PROJECT_ID',
      defaultValue: '',
    );

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        senderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: String.fromEnvironment(
        'SAO_FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
    );
  }

  String _currentPlatform() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
