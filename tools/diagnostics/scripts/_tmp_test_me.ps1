$BASE = "https://sao-api-fjzra25vya-uc.a.run.app"

# Login
$body = '{"email":"admin@sao.mx","password":"admin123"}'
$r = Invoke-RestMethod -Uri "$BASE/api/v1/auth/login" -Method Post -ContentType "application/json" -Body $body
Write-Host "Login response:" ($r | ConvertTo-Json)

$token = $r.access_token
$headers = @{ Authorization = "Bearer $token" }

# /auth/me
Write-Host "`n/auth/me response:"
$me = Invoke-RestMethod -Uri "$BASE/api/v1/auth/me" -Method Get -Headers $headers
Write-Host ($me | ConvertTo-Json)
