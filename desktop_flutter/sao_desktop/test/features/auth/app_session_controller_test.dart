import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/core/auth/token_store.dart';
import 'package:sao_desktop/features/auth/app_session_controller.dart';

class _FakeAuthHttp implements AuthHttp {
  _FakeAuthHttp({
    required this.onPost,
    required this.onGet,
    Future<dynamic> Function(String path, String token)? onGetAny,
  }) : onGetAny = onGetAny ?? ((path, token) => onGet(path, token));

  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> body,
    String? token,
  ) onPost;

  final Future<Map<String, dynamic>> Function(String path, String token) onGet;
  final Future<dynamic> Function(String path, String token) onGetAny;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return onPost(path, body, token);
  }

  @override
  Future<Map<String, dynamic>> get(String path, String token) {
    return onGet(path, token);
  }

  @override
  Future<dynamic> getAny(String path, String token) {
    return onGetAny(path, token);
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final start = DateTime.now();
  while (!condition()) {
    if (DateTime.now().difference(start) > timeout) {
      throw TimeoutException('Condition not met before timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sao_desktop_session_test_');
    TokenStore.setFileResolverForTest(
      () async => File('${tempDir.path}/sao_session.json'),
    );
    await TokenStore.clear();
  });

  tearDown(() async {
    await TokenStore.clear();
    TokenStore.setFileResolverForTest(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('startup refreshes token when access token is near expiry', () async {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await TokenStore.save(
      'old-access',
      refreshToken: 'old-refresh',
      accessExpiresAtEpoch: nowEpoch - 5,
    );

    final fakeHttp = _FakeAuthHttp(
      onPost: (path, body, token) async {
        expect(path, '/api/v1/auth/refresh');
        expect(body['refresh_token'], 'old-refresh');
        return {
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'expires_in': 600,
        };
      },
      onGet: (path, token) async {
        expect(path, '/api/v1/auth/me');
        expect(token, 'new-access');
        return {
          'id': 'u-1',
          'email': 'user@sao.dev',
          'full_name': 'User SAO',
          'role': 'SUPERVISOR',
        };
      },
    );

    final controller = AppSessionController(fakeHttp);
    addTearDown(controller.dispose);

    await _waitUntil(() => !controller.state.initializing);

    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.accessToken, 'new-access');
    expect(TokenStore.current, 'new-access');
    expect(TokenStore.currentRefreshToken, 'new-refresh');
  });

  test('startup clears session when access token is invalid and refresh fails', () async {
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await TokenStore.save(
      'stale-access',
      refreshToken: 'stale-refresh',
      accessExpiresAtEpoch: nowEpoch - 20,
    );

    final fakeHttp = _FakeAuthHttp(
      onPost: (path, body, token) async {
        throw HttpException('refresh failed');
      },
      onGet: (path, token) async {
        throw HttpException('access token invalid');
      },
    );

    final controller = AppSessionController(fakeHttp);
    addTearDown(controller.dispose);

    await _waitUntil(() => !controller.state.initializing);

    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.accessToken, isNull);
    expect(TokenStore.hasToken, isFalse);
    expect(TokenStore.hasRefreshToken, isFalse);
  });
}
