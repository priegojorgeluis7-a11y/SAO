import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/pin_storage.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/storage/kv_store.dart';
import '../data/auth_repository.dart';
import '../application/auth_controller.dart';
import 'signup_controller.dart';
import '../data/models/user.dart';

/// Provider for PinStorage
final pinStorageProvider = Provider<PinStorage>((ref) {
  final secureStorage = GetIt.I<FlutterSecureStorage>();
  return PinStorage(secureStorage);
});

/// Provider for AuthRepository
/// Uses ApiClient, TokenStorage and PinStorage from GetIt/providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = GetIt.I<ApiClient>();
  final tokenStorage = GetIt.I<TokenStorage>();
  final kvStore = GetIt.I<KvStore>();
  final prefs = GetIt.I<SharedPreferences>();
  final pinStorage = ref.watch(pinStorageProvider);

  return AuthRepository(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    kvStore: kvStore,
    pinStorage: pinStorage,
    prefs: prefs,
  );
});

/// Provider for AuthController (StateNotifier)
/// Manages authentication state throughout the app
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final pinStorage = ref.watch(pinStorageProvider);
  final biometricService = GetIt.I<BiometricService>();
  return AuthController(
    repository,
    biometricService: biometricService,
    pinStorage: pinStorage,
  );
});

final authStateProvider = Provider<AsyncValue<AuthState>>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading) {
    return const AsyncValue<AuthState>.loading();
  }
  return AsyncValue<AuthState>.data(authState);
});

final sessionProvider = Provider<AuthState>((ref) {
  return ref.watch(authControllerProvider);
});

/// Convenience provider - check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isAuthenticated;
});

/// Convenience provider - get current user (or null if not authenticated)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user;
});

/// Convenience provider - check if auth is loading
final authLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isLoading;
});

/// Convenience provider - get auth error message
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.error;
});

final signupControllerProvider =
    StateNotifierProvider<SignupController, SignupState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignupController(repository);
});
