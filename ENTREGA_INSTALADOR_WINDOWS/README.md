# Instalador de SAO para Windows

Esta carpeta prepara un instalador estándar de Windows para SAO Desktop.

## Resultado
Genera un archivo tipo Setup que:
- instala SAO en Program Files
- crea acceso directo en escritorio
- agrega acceso en menú Inicio
- permite desinstalación normal desde Windows

## Requisitos en la PC Windows
- tener el repositorio del proyecto
- Inno Setup 6 instalado
- Flutter solo es necesario si no viene la carpeta compilada en dist/windows_release

## Uso rápido
1. Actualiza el repo con la última rama main.
2. Copia esta carpeta a la raíz del repositorio.
3. Abre PowerShell en Windows.
4. Entra a esta carpeta.
5. Ejecuta el script crear_instalador_sao.ps1

> El script ahora limpia la compilación anterior y reconstruye la app para evitar que el instalador tome binarios viejos.

## Salida esperada
El instalador final se generará en:
- desktop_flutter/sao_desktop/build/windows/installer/SAO_Desktop_Setup.exe

> Si la carpeta dist/windows_release/SAO Desktop Windows Release ya viene en el repo, el script usará esa compilación lista y solo empaquetará el instalador.
