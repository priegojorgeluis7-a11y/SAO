import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/auth/token_storage.dart';
import 'package:sao_windows/core/network/api_client.dart';
import 'package:sao_windows/core/storage/kv_store.dart';
import 'package:sao_windows/features/auth/application/auth_providers.dart';
import 'package:sao_windows/features/auth/data/auth_repository.dart';
import 'package:sao_windows/features/auth/data/models/signup_request.dart';
import 'package:sao_windows/features/auth/data/models/signup_response.dart';
import 'package:sao_windows/features/auth/ui/signup_page.dart';

class _MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _InMemoryKvStore implements KvStore {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<String?> getString(String key) async => _storage[key];

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }
}

class _NoopApiClient extends ApiClient {
  _NoopApiClient({required super.tokenStorage});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required this.rolesLoader,
  }) : super(
          apiClient: _NoopApiClient(tokenStorage: TokenStorage(_MockSecureStorage())),
          tokenStorage: TokenStorage(_MockSecureStorage()),
          kvStore: _InMemoryKvStore(),
        );

  final Future<List<String>> Function() rolesLoader;

  @override
  Future<List<String>> fetchSignupRoles() => rolesLoader();

  @override
  Future<SignupResponse> signup(SignupRequest request) async {
    return SignupResponse(
      userId: 'u1',
      email: request.email,
      role: request.role,
    );
  }
}

void main() {
  group('SignupPage roles', () {
    testWidgets('loads roles dynamically and shows first role', (tester) async {
      final repository = _FakeAuthRepository(
        rolesLoader: () async => <String>['ADMIN', 'OPERATIVO'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: SignupPage()),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows error when roles cannot be loaded', (tester) async {
      final repository = _FakeAuthRepository(
        rolesLoader: () async => throw Exception('network down'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: SignupPage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar los roles'), findsOneWidget);
    });
  });
}
