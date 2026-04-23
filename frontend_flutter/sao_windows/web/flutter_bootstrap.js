{{flutter_js}}
{{flutter_build_config}}
if (_flutter && _flutter.buildConfig && _flutter.buildConfig.builds) {
  _flutter.buildConfig.builds = _flutter.buildConfig.builds.map(function(b) {
    if (b.mainJsPath) { b.mainJsPath = b.mainJsPath + '?v=20260423c'; }
    return b;
  });
}
_flutter.loader.load();
