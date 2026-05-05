/// Platform-compatibility shim for dart:io types.
/// On native platforms, re-exports from dart:io.
/// On web, provides stub implementations that compile but throw at runtime
/// for unsupported operations.
export 'io_compat_native.dart'
    if (dart.library.js_interop) 'io_compat_web.dart';
