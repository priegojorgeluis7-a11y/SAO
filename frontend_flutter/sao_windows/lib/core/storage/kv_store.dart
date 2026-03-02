import 'package:shared_preferences/shared_preferences.dart';

abstract class KvStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

class SharedPrefsKvStore implements KvStore {
  final SharedPreferences _prefs;

  SharedPrefsKvStore(this._prefs);

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }
}
