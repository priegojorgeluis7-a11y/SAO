import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/auth/token_storage.dart';
import 'package:sao_windows/core/network/api_client.dart';
import 'package:sao_windows/core/services/biometric_service.dart';
import 'package:sao_windows/core/storage/kv_store.dart';
import 'package:sao_windows/features/auth/application/auth_controller.dart';
import 'package:sao_windows/features/auth/data/auth_repository.dart';
import 'package:sao_windows/features/auth/data/models/login_request.dart';
import 'package:sao_windows/features/auth/data/models/token_response.dart';
import 'package:sao_windows/features/auth/data/models/user.dart';

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
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}

class _OfflineTolerantApiClient extends ApiClient {
  _OfflineTolerantApiClient({required super.tokenStorage});

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
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      error: 'offline',
    );
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required super.apiClient,
    required super.tokenStorage,
    required super.kvStore,
  });

  @override
  Future<TokenResponse> login(LoginRequest request) async {
    return const TokenResponse(
      accessToken: 'acc',
      refreshToken: 'ref',
    );
  }

  @override
  Future<User> getCurrentUser() async {
    return User(
      id: 'u1',
      email: 'test@sao.dev',
      fullName: 'Test User',
      status: 'active',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<BootstrapResult> bootstrap() async => BootstrapResult.unauthenticated;
}

class _StubBiometricService extends BiometricService {
  @override
  Future<bool> hasBiometricCredentials() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = true,
  }) async => true;
}

void main() {
  group('Logout flow', () {
    test('logout clears local session even when revoke call fails', () async {
      final secureStorage = _MockSecureStorage();
      final tokenStorage = TokenStorage(secureStorage);
      final kvStore = _InMemoryKvStore();
      final apiClient = _OfflineTolerantApiClient(tokenStorage: tokenStorage);

      await tokenStorage.saveTokens(
        accessToken: 'token-a',
        refreshToken: 'token-r',
      );
      await kvStore.setString('selected_project', 'TMQ');
      await kvStore.setString('current_user', '{"id":"u1"}');

      final repository = AuthRepository(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        kvStore: kvStore,
      );

      await repository.logout();

      expect(await tokenStorage.hasTokens(), isFalse);
      expect(await kvStore.getString('selected_project'), isNull);
      expect(await kvStore.getString('current_user'), isNull);
    });

    test('auth controller becomes unauthenticated after logout', () async {
      final secureStorage = _MockSecureStorage();
      final tokenStorage = TokenStorage(secureStorage);
      final kvStore = _InMemoryKvStore();
      final apiClient = _OfflineTolerantApiClient(tokenStorage: tokenStorage);

      final repository = _FakeAuthRepository(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        kvStore: kvStore,
      );
      final controller = AuthController(
        repository,
        biometricService: _StubBiometricService(),
      );

      await controller.login('test@sao.dev', '123456');
      expect(controller.state.isAuthenticated, isTrue);

      await controller.logout();

      expect(controller.state.isAuthenticated, isFalse);
    });
  });
}
