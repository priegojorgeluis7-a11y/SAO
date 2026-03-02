#!/usr/bin/env pwsh
# Cloud SQL Setup Automation Script
# Usage: .\setup_cloud_sql.ps1 -ProjectId "your-project" -DbSecret "strong-password"

param(
    [Parameter(Mandatory=$true)][string]$ProjectId,
    [Parameter(Mandatory=$true)][SecureString]$DbSecret,
    [Parameter(Mandatory=$true)][SecureString]$JwtSecret,
    [Parameter(Mandatory=$false)][string]$GcsBucket = "sao-evidences",
    [Parameter(Mandatory=$false)][string]$Region = "us-central1",
    [Parameter(Mandatory=$false)][string]$InstanceName = "sao-db",
    [Parameter(Mandatory=$false)][string]$DBName = "sao",
    [Parameter(Mandatory=$false)][string]$DBUser = "sao_user"
)

$DBPasswordPlain = [System.Net.NetworkCredential]::new("", $DbSecret).Password
$JwtSecretPlain = [System.Net.NetworkCredential]::new("", $JwtSecret).Password

Write-Host "🚀 Cloud SQL Setup for SAO Backend" -ForegroundColor Cyan
Write-Host "=" * 60

# Step 1: Authenticate
Write-Host "`n[1/7] Authenticating with Google Cloud..." -ForegroundColor Yellow
try {
    gcloud auth application-default login
    gcloud config set project $ProjectId
    Write-Host "✅ Authenticated successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Authentication failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create Cloud SQL Instance
Write-Host "`n[2/7] Creating Cloud SQL Instance..." -ForegroundColor Yellow
try {
    gcloud sql instances create $InstanceName `
        --database-version=POSTGRES_15 `
        --tier=db-g1-small `
        --region=$Region `
        --storage-type=SSD `
        --storage-size=20GB `
        --availability-type=REGIONAL `
        --backup-start-time=03:00
    Write-Host "✅ Cloud SQL Instance created" -ForegroundColor Green
} catch {
    Write-Host "❌ Instance creation failed: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Get Instance IP
Write-Host "`n[3/7] Getting Instance Connection Details..." -ForegroundColor Yellow
try {
    $InstanceIP = gcloud sql instances describe $InstanceName `
        --format="value(ipAddresses[0].ipAddress)" `
        --region=$Region
    $InstanceConnectionName = "$ProjectId`:$Region`:$InstanceName"
    Write-Host "✅ Instance IP: $InstanceIP" -ForegroundColor Green
    Write-Host "✅ Connection Name: $InstanceConnectionName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to get instance details: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Create Database User and Database
Write-Host "`n[4/7] Creating Database and User..." -ForegroundColor Yellow
try {
    # Set postgres password
    gcloud sql users set-password postgres `
        --instance=$InstanceName `
        --password=$DBPasswordPlain
    
    # Create database user
    gcloud sql users create $DBUser `
        --instance=$InstanceName `
        --password=$DBPasswordPlain
    
    Write-Host "✅ Database user created" -ForegroundColor Green
} catch {
    Write-Host "❌ User creation failed: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Create Secrets
Write-Host "`n[5/7] Creating Secrets in Secret Manager..." -ForegroundColor Yellow
try {
    $DBConnectionString = "postgresql://${DBUser}:${DBPasswordPlain}@/${DBName}?host=/cloudsql/${InstanceConnectionName}"

    # DATABASE_URL — connection string used by Cloud Run at runtime
    Write-Output $DBConnectionString | gcloud secrets create DATABASE_URL `
        --replication-policy="automatic" 2>$null
    Write-Output $DBConnectionString | gcloud secrets versions add DATABASE_URL `
        --data-file=- 2>$null

    # JWT_SECRET — signing key for access/refresh tokens
    Write-Output $JwtSecretPlain | gcloud secrets create JWT_SECRET `
        --replication-policy="automatic" 2>$null
    Write-Output $JwtSecretPlain | gcloud secrets versions add JWT_SECRET `
        --data-file=- 2>$null

    # GCS_BUCKET — bucket name for evidence uploads
    Write-Output $GcsBucket | gcloud secrets create GCS_BUCKET `
        --replication-policy="automatic" 2>$null
    Write-Output $GcsBucket | gcloud secrets versions add GCS_BUCKET `
        --data-file=- 2>$null

    Write-Host "✅ Secrets created: DATABASE_URL, JWT_SECRET, GCS_BUCKET" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Some secrets may already exist, continuing: $_" -ForegroundColor Yellow
}

# Step 6: Configure IAM Permissions
Write-Host "`n[6/7] Configuring IAM Permissions..." -ForegroundColor Yellow
try {
    # Must match $ServiceAccountEmail in deploy_to_cloud_run.ps1
    $SA_EMAIL = "sao-runner@${ProjectId}.iam.gserviceaccount.com"

    # Secret Manager access for all three secrets
    foreach ($secret in @("DATABASE_URL", "JWT_SECRET", "GCS_BUCKET")) {
        gcloud secrets add-iam-policy-binding $secret `
            --member=serviceAccount:$SA_EMAIL `
            --role=roles/secretmanager.secretAccessor
    }

    # Cloud SQL client access
    gcloud projects add-iam-policy-binding $ProjectId `
        --member=serviceAccount:$SA_EMAIL `
        --role=roles/cloudsql.client

    # GCS access for evidence uploads/downloads
    gcloud projects add-iam-policy-binding $ProjectId `
        --member=serviceAccount:$SA_EMAIL `
        --role=roles/storage.objectCreator
    gcloud projects add-iam-policy-binding $ProjectId `
        --member=serviceAccount:$SA_EMAIL `
        --role=roles/storage.objectViewer

    Write-Host "✅ IAM permissions configured for $SA_EMAIL" -ForegroundColor Green
} catch {
    Write-Host "❌ IAM configuration failed: $_" -ForegroundColor Red
    exit 1
}

# Step 7: Generate Configuration Files
Write-Host "`n[7/7] Generating Configuration Files..." -ForegroundColor Yellow

# Create .env.production (reference only — Cloud Run reads from Secret Manager)
$EnvProduction = @"
# Cloud SQL Connection (stored in Secret Manager as DATABASE_URL)
DATABASE_URL=postgresql://${DBUser}:${DBPasswordPlain}@/${DBName}?host=/cloudsql/${InstanceConnectionName}

# JWT Secret (stored in Secret Manager as JWT_SECRET)
JWT_SECRET=${JwtSecretPlain}

# CORS Origins
CORS_ORIGINS=https://your-frontend-domain.com

# Google Cloud Storage (stored in Secret Manager as GCS_BUCKET)
GCS_BUCKET=${GcsBucket}
"@

$EnvProduction | Out-File -FilePath ".\backend\.env.production" -Encoding UTF8

# Create deployment config
$ConfigJSON = @"
{
  "project_id": "$ProjectId",
  "region": "$Region",
  "instance_name": "$InstanceName",
  "instance_ip": "$InstanceIP",
  "connection_name": "$InstanceConnectionName",
  "database": "$DBName",
  "db_user": "$DBUser",
  "created_at": "$(Get-Date -Format 'o')"
}
"@

$ConfigJSON | Out-File -FilePath ".\backend\cloud_sql_config.json" -Encoding UTF8
Write-Host "✅ Configuration files created" -ForegroundColor Green

Write-Host "`n" * 2
Write-Host "=" * 60
Write-Host "✅ Cloud SQL Setup Complete!" -ForegroundColor Green
Write-Host "=" * 60

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Update .env.production with your JWT_SECRET" -ForegroundColor White
Write-Host "2. Update CORS_ORIGINS with your frontend domain" -ForegroundColor White
Write-Host "3. Update GCS_BUCKET with your actual bucket name" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Deploy to Cloud Run:" -ForegroundColor Cyan
Write-Host "   cd .\backend" -ForegroundColor White
Write-Host "   gcloud builds submit --tag gcr.io/$ProjectId/sao-backend ." -ForegroundColor White
Write-Host ""
Write-Host "   gcloud run deploy sao-backend \" -ForegroundColor White
Write-Host "     --image gcr.io/$ProjectId/sao-backend \" -ForegroundColor White
Write-Host "     --region $Region \" -ForegroundColor White
Write-Host "     --add-cloudsql-instances $InstanceConnectionName \" -ForegroundColor White
Write-Host "     --set-env-vars DATABASE_URL=\$DATABASE_URL" -ForegroundColor White
Write-Host ""
Write-Host "📊 Configuration saved to: .\backend\cloud_sql_config.json" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 Instance Connection Name: $InstanceConnectionName" -ForegroundColor Yellow
Write-Host "📍 Public IP: $InstanceIP" -ForegroundColor Yellow

