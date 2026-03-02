# Script de verificación Honor 200
Write-Host "`n=== VERIFICANDO HONOR 200 ===" -ForegroundColor Cyan
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# Matar y reiniciar servidor
& $adb kill-server | Out-Null
Start-Sleep -Seconds 1
& $adb start-server | Out-Null
Start-Sleep -Seconds 2

# Listar dispositivos
$output = & $adb devices
Write-Host $output

# Verificar si hay dispositivos
if ($output -match "\t(device|unauthorized)") {
    Write-Host "`n ¡HONOR 200 DETECTADO!" -ForegroundColor Green
    
    # Obtener info del dispositivo
    $model = & $adb shell getprop ro.product.model 2>$null
    $android = & $adb shell getprop ro.build.version.release 2>$null
    
    if ($model) {
        Write-Host " Modelo: $model" -ForegroundColor Yellow
        Write-Host " Android: $android" -ForegroundColor Yellow
    }
    
    Write-Host "`n EJECUTA LA APP:" -ForegroundColor Cyan
    Write-Host "cd D:\SAO\frontend_flutter\sao_windows" -ForegroundColor White
    Write-Host "flutter run" -ForegroundColor Green
} else {
    Write-Host "`n No se detectó ningún dispositivo" -ForegroundColor Red
    Write-Host "`nREVISA:" -ForegroundColor Yellow
    Write-Host "1. Cable USB conectado correctamente" -ForegroundColor White
    Write-Host "2. Depuración USB activada en el celular" -ForegroundColor White
    Write-Host "3. Aceptaste el popup '¿Permitir depuración USB?'" -ForegroundColor White
    Write-Host "4. Modo USB en 'Transferir archivos'" -ForegroundColor White
}

Write-Host "`nPresiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
