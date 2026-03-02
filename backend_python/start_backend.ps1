# Script para iniciar el backend SAO con configuración para red local
# Ejecutar como: .\start_backend.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  SAO Backend - Inicio Local     " -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Obtener IP local
Write-Host "Obteniendo IP local..." -ForegroundColor Yellow
$ipInfo = ipconfig | Select-String -Pattern "IPv4.*192" | Select-Object -First 1
if ($ipInfo) {
    $ip = ($ipInfo -split ':')[1].Trim()
    Write-Host "IP Local: $ip" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "No se pudo determinar la IP local" -ForegroundColor Red
    $ip = "localhost"
}

# Verificar si ya hay un proceso en el puerto 8000
Write-Host "Verificando puerto 8000..." -ForegroundColor Yellow
$port8000 = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
if ($port8000) {
    Write-Host "⚠️  El puerto 8000 ya está en uso" -ForegroundColor Yellow
    Write-Host "Proceso existente encontrado. ¿Deseas detenerlo? (S/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq 'S' -or $response -eq 's') {
        $pid = $port8000.OwningProcess
        Stop-Process -Id $pid -Force
        Write-Host "Proceso detenido" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Saliendo..." -ForegroundColor Red
        exit
    }
}

# Cambiar al directorio del backend
$backendPath = "D:\SAO\backend"
if (!(Test-Path $backendPath)) {
    Write-Host "❌ Error: No se encuentra el directorio $backendPath" -ForegroundColor Red
    exit
}

Set-Location $backendPath
Write-Host "Directorio: $backendPath" -ForegroundColor Cyan
Write-Host ""

# Activar virtual environment
Write-Host "Activando entorno virtual..." -ForegroundColor Yellow
if (Test-Path ".\venv\Scripts\Activate.ps1") {
    & .\venv\Scripts\Activate.ps1
    Write-Host "✅ Entorno virtual activado" -ForegroundColor Green
} else {
    Write-Host "⚠️  No se encuentra el entorno virtual. Creándolo..." -ForegroundColor Yellow
    python -m venv venv
    & .\venv\Scripts\Activate.ps1
    Write-Host "Instalando dependencias..." -ForegroundColor Yellow
    pip install -r requirements.txt
    Write-Host "✅ Dependencias instaladas" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Green
Write-Host "  Iniciando servidor FastAPI      " -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""
Write-Host "Backend será accesible en:" -ForegroundColor Cyan
Write-Host "  - Local:    http://127.0.0.1:8000" -ForegroundColor White
Write-Host "  - Red:      http://$($ip):8000" -ForegroundColor White
Write-Host "  - Docs:     http://$($ip):8000/docs" -ForegroundColor White
Write-Host ""
Write-Host "Configura esta URL en Flutter:" -ForegroundColor Yellow
Write-Host "  lib/core/config/app_config.dart" -ForegroundColor White
Write-Host "  baseApiUrl = 'http://$($ip):8000/api/v1'" -ForegroundColor White
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el servidor" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

# Iniciar uvicorn con host 0.0.0.0 para permitir conexiones externas
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
