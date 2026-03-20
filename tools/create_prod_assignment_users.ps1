$ErrorActionPreference = 'Stop'

Set-Location d:/SAO/backend

$ProjectId = 'sao-prod-488416'
$ProxyPort = 5432
$PythonExe = 'd:/SAO/.venv/Scripts/python.exe'

$jwtSecret = (gcloud secrets versions access latest --secret=JWT_SECRET --project=$ProjectId).Trim()

$databaseUrlSecretValue = (gcloud secrets versions access latest --secret=DATABASE_URL --project=$ProjectId).Trim()
$pattern = '^postgresql(?:\+psycopg)?://(?<user>[^:]+):(?<pass>[^@]+)@/(?<db>[^?]+)\?host=/cloudsql/(?<conn>.+)$'
$m = [regex]::Match($databaseUrlSecretValue, $pattern)
if (-not $m.Success) {
    throw 'DATABASE_URL secret format is not supported'
}

$user = $m.Groups['user'].Value
$pass = $m.Groups['pass'].Value
$db = $m.Groups['db'].Value
$conn = $m.Groups['conn'].Value

$repoRoot = (Resolve-Path ..).Path
$toolsDir = Join-Path $repoRoot 'tools'
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}
$proxyPath = Join-Path $toolsDir 'cloud-sql-proxy.exe'
if (-not (Test-Path $proxyPath)) {
    Invoke-WebRequest -Uri 'https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.x64.exe' -OutFile $proxyPath
}

$proxy = Start-Process -FilePath $proxyPath -ArgumentList @('--port', $ProxyPort, $conn) -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3
if ($proxy.HasExited) {
    throw 'Cloud SQL proxy exited unexpectedly'
}

try {
    $encUser = [Uri]::EscapeDataString($user)
    $encPass = [Uri]::EscapeDataString($pass)
    $encDb = [Uri]::EscapeDataString($db)
    $env:DATABASE_URL = "postgresql://$encUser`:$encPass@127.0.0.1`:$ProxyPort/$encDb"
    $env:JWT_SECRET = $jwtSecret

    & $PythonExe scripts/create_user_with_role.py --email 'operativo.asignaciones@sao.mx' --password 'Operativo123!' --full-name 'Operativo Asignaciones' --role OPERATIVO
    if ($LASTEXITCODE -ne 0) { throw 'Failed creating OPERATIVO user' }

    & $PythonExe scripts/create_user_with_role.py --email 'admin.asignaciones@sao.mx' --password 'Admin123!' --full-name 'Admin Asignaciones' --role ADMIN
    if ($LASTEXITCODE -ne 0) { throw 'Failed creating ADMIN user' }

    $env:SAO_ADMIN_EMAIL = 'admin@sao.mx'
    & $PythonExe scripts/ensure_admin_scope.py
    if ($LASTEXITCODE -ne 0) { throw 'Failed ensuring admin@sao.mx scope' }

    & $PythonExe -c "from app.core.database import SessionLocal; from app.models.user import User; from app.models.user_role_scope import UserRoleScope; from app.models.role import Role; db=SessionLocal(); emails=['operativo.asignaciones@sao.mx','admin.asignaciones@sao.mx'];
for e in emails:
 u=db.query(User).filter(User.email==e).first();
 print('USER',e,'FOUND' if u else 'MISSING');
 if u:
  s=db.query(UserRoleScope).filter(UserRoleScope.user_id==u.id).first();
  r=db.query(Role).filter(Role.id==s.role_id).first() if s else None;
  print('ROLE', r.name if r else 'NONE');
db.close()"

        & $PythonExe -c "from app.core.database import SessionLocal; from app.models.user import User; from app.models.user_role_scope import UserRoleScope; from app.models.role import Role; db=SessionLocal(); e='admin@sao.mx'; u=db.query(User).filter(User.email==e).first(); print('USER',e,'FOUND' if u else 'MISSING');
if u:
 s=db.query(UserRoleScope).filter(UserRoleScope.user_id==u.id).first();
 r=db.query(Role).filter(Role.id==s.role_id).first() if s else None;
 print('ROLE', r.name if r else 'NONE');
db.close()"
}
finally {
    if ($proxy -and -not $proxy.HasExited) {
        Stop-Process -Id $proxy.Id -Force
    }
}
