#!/bin/bash
# Script para desplegar índices de Firestore actualizados
# Uso: ./scripts/deploy_firestore_indexes.sh [project_id]

set -e

PROJECT_ID="${1:-sao-prod-488416}"

echo "=== Desplegando índices de Firestore ==="
echo "Proyecto: $PROJECT_ID"
echo ""

# Verificar que gcloud está configurado
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI no está instalado"
    exit 1
fi

# Verificar el proyecto activo
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || true)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo "Configurando proyecto: $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
fi

echo "Índices actuales:"
gcloud firestore indexes list --collection-group=activities 2>/dev/null | head -20 || echo "No se encontraron índices para activities"

echo ""
echo "Desplegando nuevos índices desde firestore.indexes.json..."
gcloud firestore indexes import firestore.indexes.json --collection-group=activities --project="$PROJECT_ID" 2>&1 || \
gcloud firestore indexes create firestore.indexes.json --project="$PROJECT_ID" 2>&1

echo ""
echo "=== Índices desplegados exitosamente ==="
echo "Recuerda que los índices pueden tardar unos minutos en estar listos."
echo ""
echo "Puedes verificar el estado en:"
echo "  https://console.cloud.google.com/firestore/indexes?project=$PROJECT_ID"
