# SAO Mobile

Cliente Flutter movil de SAO.

## Comandos base

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `dart run build_runner build --delete-conflicting-outputs`

## iOS

El proyecto incluye target nativo para iPhone/iPad en `ios/`.

Prerequisitos para compilar en macOS:

- Xcode con el runtime de iOS y/o iOS Simulator instalado desde `Xcode > Settings > Components`
- CocoaPods disponible
- Cuenta/equipo de signing configurado en Xcode para pruebas en dispositivo fisico

Build de simulador:

- `flutter build ios --simulator --no-codesign`
- Si el workspace vive dentro de `Documents` y Xcode falla por metadatos Finder/codesign, usa `tools/diagnostics/scripts/build_mobile_ios_simulator_clean.sh`

Build para dispositivo fisico sin firmar:

- `flutter build ios --release --no-codesign`

Notas:

- El bundle id iOS del proyecto es `com.tmq.sao`.
- Para push notifications en iPhone sigue siendo necesario configurar certificados o key de APNs en Apple Developer/Firebase fuera del repositorio.
- Si Xcode reporta que no encuentra destino para simulator, normalmente falta instalar el runtime de iOS correspondiente.
- El Podfile iOS usa `use_modular_headers!` para que Firebase y `sqlite3_flutter_libs` resuelvan modulos Swift sin `use_frameworks!`.
