# Instalador de SAO para Windows

Esta carpeta prepara un instalador estándar de Windows para SAO Desktop (app de administración).

## Resultado
Genera `SAO_Desktop_Setup.exe` que:
- instala SAO en Program Files
- crea acceso directo en escritorio
- agrega acceso en menú Inicio
- permite desinstalación normal desde Windows

## Requisitos en la PC Windows
1. **Git** — para clonar/actualizar el repositorio
2. **Flutter SDK** (canal stable, versión ≥ 3.2) — `flutter doctor` debe pasar sin errores en Windows
3. **Visual Studio 2022** con el workload "Desarrollo para escritorio con C++" (requerido por Flutter Windows)
4. **Inno Setup 6** — descargar desde https://jrsoftware.org/isdl.php

## Pasos

```powershell
# 1. Clonar o actualizar el repositorio
git clone <repo-url>   # o: git pull origin v1.0.12

# 2. Ir a la carpeta del instalador
cd ENTREGA_INSTALADOR_WINDOWS

# 3. Ejecutar el script (PowerShell como Administrador)
.\crear_instalador_sao.ps1
```

## Salida esperada
```
desktop_flutter\sao_desktop\build\windows\installer\SAO_Desktop_Setup.exe
```

## Notas
- El script compila automáticamente `flutter build windows --release` con el backend en producción (`SAO_BACKEND_URL` ya está incluido en el script).
- Si `dist\windows_release\SAO Desktop Windows Release\` existe en el repo, el script usa esa compilación pre-construida y salta el paso de Flutter.
- Backend apuntado: `https://sao-api-97150883570.us-central1.run.app`
- Versión del instalador: **1.0.2**
