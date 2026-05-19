import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

// ---------------------------------------------------------------------------
// Stub Platform
// ---------------------------------------------------------------------------

class Platform {
  Platform._();

  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isFuchsia => false;
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static String get localHostname => '';
  static Map<String, String> get environment => const {};
  static String get executable => '';
  static String get resolvedExecutable => '';
  static String get localeName => '';
  static int get numberOfProcessors => 1;
  static String get pathSeparator => '/';
  static Uri get script => Uri.parse('');
  static List<String> get executableArguments => const [];
}

// ---------------------------------------------------------------------------
// Stub File
// ---------------------------------------------------------------------------

class File extends FileSystemEntity {
  @override
  final String path;
  const File(this.path);

  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<File> create({bool recursive = false}) async => this;
  Future<void> delete({bool recursive = false}) async {}
  Future<String> readAsString({Object? encoding}) async =>
      throw UnsupportedError('File I/O not supported on web');
  Future<Uint8List> readAsBytes() async =>
      throw UnsupportedError('File I/O not supported on web');
  Future<File> writeAsString(String contents, {Object? encoding, FileMode mode = FileMode.write, bool flush = false}) async =>
      throw UnsupportedError('File I/O not supported on web');
  void writeAsStringSync(String contents, {Object? encoding, FileMode mode = FileMode.write, bool flush = false}) =>
      throw UnsupportedError('File I/O not supported on web');
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) async =>
      throw UnsupportedError('File I/O not supported on web');
  Future<File> copy(String newPath) async =>
      throw UnsupportedError('File I/O not supported on web');
  FileStat statSync() => FileStat._();

  Directory get parent => const Directory('');
  String get absolute => path;
  Uri get uri => Uri.file(path);
}

// ---------------------------------------------------------------------------
// Stub Directory
// ---------------------------------------------------------------------------

class Directory extends FileSystemEntity {
  @override
  final String path;
  const Directory(this.path);

  static Directory get current => const Directory('.');

  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Future<void> delete({bool recursive = false}) async {}
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Stub Process
// ---------------------------------------------------------------------------

class ProcessResult {
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
  final int pid;
  const ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);
}

class Process {
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Object? stdoutEncoding,
    Object? stderrEncoding,
  }) async {
    throw UnsupportedError('Process.run not supported on web');
  }
}

// ---------------------------------------------------------------------------
// Stub FileSystemEntity (base for File/Directory)
// ---------------------------------------------------------------------------

abstract class FileSystemEntity {
  String get path;
  const FileSystemEntity();
}

// ---------------------------------------------------------------------------
// Stub FileStat
// ---------------------------------------------------------------------------

class FileStat {
  FileStat._();
  DateTime get modified => DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get accessed => DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get changed => DateTime.fromMillisecondsSinceEpoch(0);
  int get size => 0;
  int get mode => 0;
}

// ---------------------------------------------------------------------------
// Stub exceptions
// ---------------------------------------------------------------------------

class HttpException implements Exception {
  final String message;
  final Uri? uri;
  const HttpException(this.message, {this.uri});
  @override
  String toString() => 'HttpException: $message';
}

class FileSystemException implements Exception {
  final String message;
  final String? path;
  const FileSystemException([this.message = '', this.path]);
  @override
  String toString() => 'FileSystemException: $message';
}

// ---------------------------------------------------------------------------
// Stub FileMode
// ---------------------------------------------------------------------------

class FileMode {
  static const FileMode write = FileMode._();
  static const FileMode append = FileMode._();
  static const FileMode writeOnlyAppend = FileMode._();
  static const FileMode read = FileMode._();

  const FileMode._();
}

// ---------------------------------------------------------------------------
// Stub SystemEncoding
// ---------------------------------------------------------------------------

class SystemEncoding extends Encoding {
  const SystemEncoding();

  @override
  String get name => 'system';

  @override
  Converter<List<int>, String> get decoder => utf8.decoder;

  @override
  Converter<String, List<int>> get encoder => utf8.encoder;
}

const SystemEncoding systemEncoding = SystemEncoding();

// ---------------------------------------------------------------------------
// Stub ProcessSignal
// ---------------------------------------------------------------------------

class ProcessSignal {
  const ProcessSignal._();

  static const ProcessSignal sighup = ProcessSignal._();
  static const ProcessSignal sigint = ProcessSignal._();
  static const ProcessSignal sigquit = ProcessSignal._();
  static const ProcessSignal sigkill = ProcessSignal._();
  static const ProcessSignal sigterm = ProcessSignal._();
  static const ProcessSignal sigwinch = ProcessSignal._();
}

// ---------------------------------------------------------------------------
// Stub HttpHeaders
// ---------------------------------------------------------------------------

class HttpHeaders {
  static const String acceptHeader = 'accept';
  static const String authorizationHeader = 'authorization';
  static const String cacheControlHeader = 'cache-control';
  static const String connectionHeader = 'connection';
  static const String contentEncodingHeader = 'content-encoding';
  static const String contentLengthHeader = 'content-length';
  static const String contentTypeHeader = 'content-type';
  static const String dateHeader = 'date';
  static const String hostHeader = 'host';
  static const String locationHeader = 'location';
  static const String serverHeader = 'server';
  static const String transferEncodingHeader = 'transfer-encoding';
  static const String userAgentHeader = 'user-agent';
  static const String wwwAuthenticateHeader = 'www-authenticate';

  void set(String name, Object value) {}
  void add(String name, Object value) {}
  String? value(String name) => null;
  void remove(String name, Object value) {}
  void removeAll(String name) {}
}

// ---------------------------------------------------------------------------
// Stub HttpClient / HttpClientRequest / HttpClientResponse
// ---------------------------------------------------------------------------

class _WebHttpClientResponse extends Stream<List<int>> {
  final int statusCode = 0;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      throw UnsupportedError('HttpClient not supported on web');
}

class _WebHttpClientRequest {
  bool followRedirects = true;
  int maxRedirects = 5;
  final HttpHeaders headers = HttpHeaders();

  Future<_WebHttpClientResponse> close() =>
      throw UnsupportedError('HttpClient not supported on web');
}

class HttpClient {
  Duration? connectionTimeout;
  Duration? idleTimeout;

  Future<_WebHttpClientRequest> getUrl(Uri url) =>
      throw UnsupportedError('HttpClient not supported on web');

  Future<_WebHttpClientRequest> openUrl(String method, Uri url) =>
      throw UnsupportedError('HttpClient not supported on web');

  void close({bool force = false}) {}
}
