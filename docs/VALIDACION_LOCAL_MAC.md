# Validacion Local en macOS

Guia corta para validar el workspace SAO en una Mac limpia o parcialmente preparada.

## 1. Prerrequisitos

Este repositorio requiere:

- Python 3.11 para backend
- Flutter para mobile y desktop
- Xcode Command Line Tools

Comandos de instalacion recomendados con Homebrew:

```bash
brew install python@3.11
brew install --cask flutter
```

Si `python3.11` no queda en PATH automaticamente:

```bash
echo 'export PATH="/opt/homebrew/opt/python@3.11/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Validacion base del toolchain:

```bash
python3.11 --version
flutter --version
flutter doctor
```

## 2. Backend

Backend canonico para clientes:

```text
https://sao-api-fjzra25vya-uc.a.run.app
```

Validado desde esta Mac:

```bash
curl https://sao-api-fjzra25vya-uc.a.run.app/version
curl https://sao-api-fjzra25vya-uc.a.run.app/health
```

Usa Cloud Run como backend por defecto para mobile y desktop.
El backend local solo se necesita para desarrollo del backend o pruebas puntuales.

Preparar entorno:

```bash
cd backend
python3.11 -m venv .venv311
source .venv311/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Ejecutar pruebas:

```bash
pytest tests -q
```

Levantar API local (opcional, solo para desarrollo backend):

```bash
cp .env.example .env
```

Ajustes minimos sugeridos para `.env` en desarrollo local:

```env
ENV=development
DATA_BACKEND=firestore
JWT_SECRET=dev-secret
EVIDENCE_STORAGE_BACKEND=local
LOCAL_BASE_URL=http://127.0.0.1:8000
LOCAL_UPLOADS_DIR=./uploads
```

Notas:

- Para ejecutar `/health` con Firestore real necesitas credenciales validas de Google Cloud.
- Si solo quieres comprobar arranque de FastAPI, usa `/` o `/version`.

Arranque:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Smoke checks recomendados:

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/version
```

## 3. Mobile Flutter

Validacion estatica y pruebas:

```bash
cd frontend_flutter/sao_windows
flutter pub get
flutter analyze
flutter test
```

Ejecucion local en macOS:

```bash
flutter run -d macos
```

La app movil soporta override de backend URL desde settings, por lo que puede apuntar a local o staging sin recompilar.

Configuracion recomendada:

- Usar Cloud Run como backend activo.
- No necesitas backend local para ejecutar mobile en esta Mac.

## 4. Desktop Flutter

Preparacion:

```bash
cd desktop_flutter/sao_desktop
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

Importante:

- Desktop requiere `SAO_BACKEND_URL`.
- El cliente desktop rechaza `localhost` y `127.0.0.1`.
- Como politica operativa, usa Cloud Run.

Ejemplo de ejecucion:

```bash
flutter run -d macos --dart-define=SAO_BACKEND_URL=https://sao-api-fjzra25vya-uc.a.run.app
```

Solo si estas desarrollando backend local y necesitas probar contra tu Mac:

```bash
flutter run -d macos --dart-define=SAO_BACKEND_URL=http://192.168.1.20:8000
```

## 5. Orden recomendado de validacion

1. Instalar Python 3.11 y Flutter.
2. Ejecutar `pytest` en backend.
3. Validar Cloud Run con `/version` y `/health`.
4. Ejecutar `flutter analyze` y `flutter test` en mobile.
5. Ejecutar `flutter test` en desktop.
6. Abrir mobile y desktop contra Cloud Run.

## 6. Estado esperado

Si todo esta sano:

- Backend Cloud Run: responde `/version` y `/health`.
- Backend local: importa, corre `pytest` y responde `/version` si decides usarlo.
- Mobile: `flutter analyze` sin errores bloqueantes y `flutter test` en verde.
- Desktop: `flutter test` en verde y arranca con `SAO_BACKEND_URL` valido.

## 7. Limitaciones conocidas

- El workflow CI visible cubre backend y mobile.
- Desktop tiene pruebas en repo, pero no aparece validado por un workflow dedicado en GitHub Actions.
- La documentacion principal del repo aun mezcla rutas antiguas (`mobile/` y `desktop/`) con la estructura real (`frontend_flutter/` y `desktop_flutter/`).