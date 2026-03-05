import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/exceptions.dart';
import '../data/auth_repository.dart';
import '../data/models/signup_request.dart';

class SignupState {
  final bool isLoading;
  final bool success;
  final String? error;

  const SignupState({
    this.isLoading = false,
    this.success = false,
    this.error,
  });

  const SignupState.initial()
      : isLoading = false,
        success = false,
        error = null;

  SignupState copyWith({
    bool? isLoading,
    bool? success,
    String? error,
  }) {
    return SignupState(
      isLoading: isLoading ?? this.isLoading,
      success: success ?? this.success,
      error: error,
    );
  }
}

class SignupController extends StateNotifier<SignupState> {
  SignupController(this._repository) : super(const SignupState.initial());

  final AuthRepository _repository;

  Future<bool> signup(SignupRequest request) async {
    state = const SignupState(isLoading: true);

    try {
      await _repository.signup(request);
      state = const SignupState(success: true);
      return true;
    } on NetworkException {
      state = const SignupState(error: 'No internet connection');
      return false;
    } on ApiTimeoutException {
      state = const SignupState(error: 'Connection timeout');
      return false;
    } on AuthException catch (e) {
      state = SignupState(error: e.message);
      return false;
    } catch (e) {
      state = SignupState(error: 'Unexpected error: $e');
      return false;
    }
  }

  void clearState() {
    state = const SignupState.initial();
  }
}