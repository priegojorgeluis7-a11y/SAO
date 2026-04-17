param(
    [string]$CertName = "SAO Internal Code Signing",
    [string]$PfxOutput = ".\signing\sao-internal-code-signing.pfx",
    [string]$CerOutput = ".\signing\sao-internal-code-signing.cer",
    [string]$Password = "Cambiar_Esta_Password_2026!"
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating internal code signing certificate..." -ForegroundColor Cyan

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

if (-not $cert) {
    throw "Certificate creation failed."
}

$signingDir = Split-Path -Parent $PfxOutput
if ($signingDir -and -not (Test-Path $signingDir)) {
    New-Item -ItemType Directory -Path $signingDir -Force | Out-Null
}

Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $PfxOutput -Password $securePassword | Out-Null
Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $CerOutput | Out-Null

Write-Host "Certificate created successfully." -ForegroundColor Green
Write-Host "PFX: $PfxOutput"
Write-Host "CER: $CerOutput"
Write-Host "Thumbprint: $($cert.Thumbprint)"
Write-Host ""
Write-Host "Next step for internal deployment:" -ForegroundColor Yellow
Write-Host "1. Install the CER file into Trusted Root Certification Authorities on company PCs."
Write-Host "2. Use the build_and_sign_windows.ps1 script to sign the release executable."
