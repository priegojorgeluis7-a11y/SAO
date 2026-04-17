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
- Flutter instalado
- Inno Setup 6 instalado

## Uso rápido
1. Copia esta carpeta a la raíz del repositorio.
2. Abre PowerShell en Windows.
3. Entra a esta carpeta.
4. Ejecuta el script crear_instalador_sao.ps1

## Salida esperada
El instalador final se generará en:
- desktop_flutter/sao_desktop/build/windows/installer/SAO_Desktop_Setup.exe
