# Firma interna para SAO Desktop en Windows

## Objetivo
Este flujo permite firmar la aplicación de escritorio de Windows para distribución interna dentro de la organización.

## Ruta recomendada
Usar un certificado interno de firma de código y confiar ese certificado en los equipos corporativos.

## Archivos preparados
- [desktop_flutter/sao_desktop/scripts/windows/create_internal_code_signing_cert.ps1](desktop_flutter/sao_desktop/scripts/windows/create_internal_code_signing_cert.ps1)
- [desktop_flutter/sao_desktop/scripts/windows/build_and_sign_windows.ps1](desktop_flutter/sao_desktop/scripts/windows/build_and_sign_windows.ps1)
- [desktop_flutter/sao_desktop/scripts/windows/sao_desktop_internal_installer.iss](desktop_flutter/sao_desktop/scripts/windows/sao_desktop_internal_installer.iss)
- [desktop_flutter/sao_desktop/scripts/windows/build_sign_and_package_windows.ps1](desktop_flutter/sao_desktop/scripts/windows/build_sign_and_package_windows.ps1)

## Opción 1: certificado interno propio
En una máquina Windows con PowerShell:

1. Ejecutar el script de creación de certificado.
2. Se generarán un archivo PFX y un archivo CER.
3. Instalar el archivo CER en Trusted Root Certification Authorities de los equipos internos.
4. Firmar el ejecutable de release con el script de firma.

## Opción 2: certificado empresarial
Si TI ya entrega un certificado de firma de código, usar directamente el archivo PFX corporativo con el script de firma.

## Flujo operativo
1. Compilar release de Windows desde la app desktop.
2. Firmar el archivo sao_desktop.exe.
3. Generar el instalador interno con Inno Setup.
4. Firmar también el instalador final.
5. Distribuir el instalador firmado dentro de la organización.

## Instalador interno listo
Se dejó preparado un instalador tipo Setup para instalación estándar en equipos Windows internos.

Resultado esperado al empaquetar:
- ejecutable firmado
- instalador interno firmado
- acceso directo en escritorio y menú de inicio

La salida del instalador queda en la carpeta de build de Windows del proyecto.

## Requisitos en Windows
- Flutter instalado
- Windows SDK con SignTool
- Certificado PFX de firma
- Password del PFX

## Notas
- Este flujo es para distribución interna, no para Microsoft Store.
- Si el certificado es autofirmado, los equipos destino deben confiar en el certificado raíz.
- El ejecutable del proyecto es sao_desktop.exe y su metadata Windows ya usa nombre SAO Desktop.
