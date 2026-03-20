import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kKey = 'sao_theme_mode';
const _storage = FlutterSecureStorage();

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final v = await _storage.read(key: _kKey);
    if (v == 'dark') state = ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(
      key: _kKey,
      value: mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void toggle() => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
