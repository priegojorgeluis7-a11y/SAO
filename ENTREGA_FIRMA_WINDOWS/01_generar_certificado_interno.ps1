param(
    [string]$CertName = "SAO Internal Code Signing",
    [string]$PfxOutput = ".\certificados\sao-internal-code-signing.pfx",
    [string]$CerOutput = ".\certificados\sao-internal-code-signing.cer",
    [string]$Password = "Cambiar_Esta_Password_2026!"
)

$ErrorActionPreference = 'Stop'

$securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
$subject = "CN=$CertName"

$cert = New-SelfSignedCertificate \
    -Type CodeSigningCert \
    -Subject $subject \
    -FriendlyName $CertName \
    -KeyAlgorithm RSA \
    -KeyLength 3072 \
    -HashAlgorithm SHA256 \
    -CertStoreLocation "Cert:\CurrentUser\My" \
    -NotAfter (Get-Date).AddYears(3)

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $PfxOutput -Password $securePassword | Out-Null
Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $CerOutput | Out-Null

Write-Host "Certificado creado correctamente" -ForegroundColor Green
Write-Host "PFX: $PfxOutput"
Write-Host "CER: $CerOutput"
Write-Host "Thumbprint: $($cert.Thumbprint)"
