@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0crear_instalador_sao.ps1"
if errorlevel 1 (
  echo.
  echo Ocurrio un error al generar el instalador.
  pause
  exit /b 1
)
echo.
echo Instalador generado correctamente.
pause
