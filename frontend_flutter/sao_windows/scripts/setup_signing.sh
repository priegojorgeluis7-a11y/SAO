#!/usr/bin/env bash
# setup_signing.sh — Genera el keystore y crea android/key.properties
# Ejecutar UNA SOLA VEZ desde la raíz del proyecto (frontend_flutter/sao_windows)
#
# Uso:
#   chmod +x scripts/setup_signing.sh
#   ./scripts/setup_signing.sh

set -euo pipefail

ANDROID_DIR="$(cd "$(dirname "$0")/.." && pwd)/android"
KEYSTORE_PATH="$ANDROID_DIR/app/sao-release.jks"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"

echo ""
echo "=== SAO — Configuración de firma para release ==="
echo ""

if [ -f "$KEY_PROPERTIES" ]; then
  echo "⚠️  $KEY_PROPERTIES ya existe. Elimínalo primero si quieres regenerar."
  exit 1
fi

if [ -f "$KEYSTORE_PATH" ]; then
  echo "⚠️  $KEYSTORE_PATH ya existe. Elimínalo primero si quieres regenerar."
  exit 1
fi

read -rsp "Contraseña del keystore (storePassword, mín 6 chars): " STORE_PASS; echo
read -rsp "Confirma contraseña del keystore: " STORE_PASS2; echo
if [ "$STORE_PASS" != "$STORE_PASS2" ]; then
  echo "❌ Las contraseñas no coinciden."; exit 1
fi

read -rsp "Contraseña de la clave (keyPassword, Enter = igual al keystore): " KEY_PASS; echo
if [ -z "$KEY_PASS" ]; then
  KEY_PASS="$STORE_PASS"
fi

read -rp "Nombre completo del firmante (ej: Jorge Priego): " DNAME_CN
read -rp "Organización (ej: TMQ Constructora): " DNAME_O
DNAME_C="MX"

echo ""
echo "Generando keystore en: $KEYSTORE_PATH"

keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias sao-key \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=$DNAME_CN, O=$DNAME_O, C=$DNAME_C"

echo ""
echo "Creando $KEY_PROPERTIES ..."

cat > "$KEY_PROPERTIES" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=sao-key
storeFile=app/sao-release.jks
EOF

echo ""
echo "✅ Listo. Archivos generados:"
echo "   $KEYSTORE_PATH"
echo "   $KEY_PROPERTIES"
echo ""
echo "IMPORTANTE: Guarda una copia de $KEYSTORE_PATH en un lugar seguro fuera del repo."
echo "            Sin ese archivo NO podrás actualizar la app en Play Store."
echo ""
echo "Siguiente paso — build para Play Store:"
echo "   flutter build appbundle --release"
echo ""
