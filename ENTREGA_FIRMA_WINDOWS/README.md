# Entrega para firma interna en Windows

Esta carpeta está lista para copiarse a una computadora Windows.

## Qué contiene
- generación de certificado interno
- firma del ejecutable
- generación del instalador interno
- firma del instalador final

## Dónde colocarla
Copiar esta carpeta en la raíz del repositorio del proyecto, al mismo nivel que ARCHITECTURE.md y STATUS.md.

## Orden de uso
1. Abrir PowerShell como administrador.
2. Entrar a esta carpeta.
3. Ejecutar 01_generar_certificado_interno.ps1 para crear un certificado interno, o copiar aquí el archivo PFX corporativo.
4. Ejecutar 03_generar_instalador_firmado.ps1 para compilar, firmar y generar el instalador interno.

## Salidas esperadas
- ejecutable firmado dentro del build de Windows
- instalador firmado para distribución interna

## Requisitos en la PC Windows
- Flutter
- Windows SDK con SignTool
- Inno Setup 6
- acceso al repositorio del proyecto
