# Instalador de SAO Campo para Windows

Esta carpeta prepara un instalador estándar de Windows para la app de campo **SAO Campo** (`sao_windows`), usada por los supervisores y técnicos en campo.

## Resultado
Genera `SAO_Campo_Setup.exe` que:
- instala SAO Campo en Program Files
- crea acceso directo en el escritorio
- agrega acceso en el menú Inicio
- permite desinstalación normal desde Windows

## Requisitos en la PC Windows
1. **Git** — para clonar o actualizar el repositorio
2. **Flutter SDK** (canal stable, versión ≥ 3.19) — `flutter doctor` debe pasar sin errores en Windows
3. **Visual Studio 2022** con el workload "Desarrollo para escritorio con C++" (requerido por Flutter Windows)
4. **Inno Setup 6** — descargar desde https://jrsoftware.org/isdl.php

## Pasos

```powershell
# 1. Clonar o actualizar el repositorio
git clone <repo-url>   # o: git pull origin main

# 2. Ir a la carpeta del instalador
cd ENTREGA_INSTALADOR_WINDOWS_CAMPO

# 3. Ejecutar el script (PowerShell como Administrador)
.\crear_instalador_campo.ps1
```

## Salida esperada
```
frontend_flutter\sao_windows\build\windows\installer\SAO_Campo_Setup.exe
```

## Notas
- El script compila automáticamente `flutter build windows --release` con el backend en producción (`SAO_BACKEND_URL` ya está embebido en el script).
- Si `dist\windows_campo_release\SAO Campo Windows Release\` existe en el repo, el script usa esa compilación pre-construida y salta el paso de Flutter.
- Backend apuntado: `https://sao-api-97150883570.us-central1.run.app`
- Versión del instalador: **2.0.3**
- App id de Windows: `SAOCampo`
