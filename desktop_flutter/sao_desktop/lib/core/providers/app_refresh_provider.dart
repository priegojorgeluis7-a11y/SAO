import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRefreshTokenProvider = StateProvider<int>((ref) => 0);
final appShellIndexProvider = StateProvider<int>((ref) => 2);
final operationsHubTabIndexProvider = StateProvider<int>((ref) => 0);
final operationsHubActivityIdProvider = StateProvider<String?>((ref) => null);
