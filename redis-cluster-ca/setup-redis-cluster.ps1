# Set strict mode and fail early
$ErrorActionPreference = "Stop"

Write-Host "🔐 Redis Cluster TLS Setup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Yellow

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan

# Docker check
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker is installed" -ForegroundColor Green

# Docker Compose check
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker Compose is not installed or not in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Docker Compose is installed" -ForegroundColor Green

# OpenSSL check
if (-not (Get-Command "openssl" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ OpenSSL is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install OpenSSL and add it to your PATH" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ OpenSSL is installed" -ForegroundColor Green

Write-Host "✅ All prerequisites are available" -ForegroundColor Green

# Paths
$certsPath = ".\certs"

# 🚫 Clean up old certificates
Write-Host "`n🧹 Removing old certificates..." -ForegroundColor Cyan
if (Test-Path $certsPath) {
    Remove-Item "$certsPath\*" -Recurse -Force
    Write-Host "🗑️  Old certs deleted" -ForegroundColor Green
} else {
    New-Item -ItemType Directory -Path $certsPath | Out-Null
    Write-Host "📁 Created certs directory" -ForegroundColor Green
}

Push-Location $certsPath

# 🔐 Generate new certificates
Write-Host "`n🔐 Generating new TLS certificates..." -ForegroundColor Cyan

Write-Host "📄 Creating CA private key..." -ForegroundColor Cyan
openssl genrsa -out ca.key 4096
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to generate CA key"; exit 1 }

Write-Host "📄 Creating CA certificate..." -ForegroundColor Cyan
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=RedisTestCA"
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to generate CA cert"; exit 1 }

Write-Host "📄 Creating Redis server key..." -ForegroundColor Cyan
openssl genrsa -out redis.key 2048
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to generate Redis key"; exit 1 }

Write-Host "📄 Creating CSR..." -ForegroundColor Cyan
openssl req -new -key redis.key -out redis.csr -subj "/CN=localhost"
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to generate CSR"; exit 1 }

Write-Host "📄 Signing Redis certificate..." -ForegroundColor Cyan
openssl x509 -req -in redis.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out redis.crt -days 3650 -sha256
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to sign cert"; exit 1 }

Write-Host "🧹 Cleaning up temporary files..." -ForegroundColor Cyan
Remove-Item redis.csr, ca.srl -ErrorAction SilentlyContinue

Pop-Location

Write-Host "✅ TLS certificates generated in ./certs" -ForegroundColor Green

# 🌍 Set NODE_EXTRA_CA_CERTS to point to the Redis CA certificate
$caCertPath = Resolve-Path "$certsPath\ca.crt"
Write-Host "`n🌍 Setting NODE_EXTRA_CA_CERTS environment variable to $caCertPath" -ForegroundColor Cyan
$env:NODE_EXTRA_CA_CERTS = $caCertPath
Write-Host "`n✅ Environment variable set: NODE_EXTRA_CA_CERTS = $env:NODE_EXTRA_CA_CERTS" -ForegroundColor Green


# 🔍 Verify generated files
Write-Host "`n🔍 Verifying certificates..." -ForegroundColor Cyan
foreach ($file in @("ca.crt", "redis.crt", "redis.key")) {
    $fullPath = Join-Path $certsPath $file
    if (Test-Path $fullPath) {
        Write-Host "✅ $file exists" -ForegroundColor Green
    } else {
        Write-Host "❌ $file missing" -ForegroundColor Red
        exit 1
    }
}

# 🛑 Clean up old containers, volumes, orphans
Write-Host "`n🛑 Stopping and cleaning existing Redis containers..." -ForegroundColor Cyan
docker-compose down --volumes --remove-orphans
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Existing containers, volumes, orphans cleaned" -ForegroundColor Green
} else {
    Write-Host "ℹ️  No containers or volumes to remove" -ForegroundColor Yellow
}

# 🧹 Clean up Redis data directory
$redisDataPath = ".\data\node1"
Write-Host "`n🧹 Removing existing Redis data in $redisDataPath..." -ForegroundColor Cyan
if (Test-Path $redisDataPath) {
    try {
        Remove-Item "$redisDataPath\*" -Recurse -Force
        Write-Host "✅ Data directory cleaned" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to clean data directory: $_" -ForegroundColor Red
        exit 1
    }
} else {
    New-Item -ItemType Directory -Path $redisDataPath | Out-Null
    Write-Host "📁 Created data directory" -ForegroundColor Green
}


# 🐳 Start fresh containers
Write-Host "`n🐳 Starting Redis cluster with Docker Compose..." -ForegroundColor Cyan
docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start Docker containers" -ForegroundColor Red
    exit 1
}

# ⏱️ Give it a moment
Start-Sleep -Seconds 3

# ✅ Check status
Write-Host "`n🔍 Checking container status..." -ForegroundColor Cyan
$running = docker-compose ps --services --filter "status=running"
if ($running) {
    Write-Host "✅ Redis cluster is running" -ForegroundColor Green
} else {
    Write-Host "❌ Redis cluster failed to start" -ForegroundColor Red
    docker-compose logs
    exit 1
}

# � Initialize cluster slots
Write-Host "`n🎰 Initializing cluster slots..." -ForegroundColor Cyan
Write-Host "📍 Assigning hash slots 0-16383 to the node..." -ForegroundColor White

try {
    $slotCommand = 'for i in $(seq 0 500 16383); do end=$((i+499)); [ $end -gt 16383 ] && end=16383; redis-cli --tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt -p 6379 cluster addslots $(seq $i $end); done'
    docker exec redis-single-cluster sh -c $slotCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ All hash slots assigned successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some slots may already be assigned" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Error assigning slots: $_" -ForegroundColor Yellow
}

# 🔍 Verify cluster state
Write-Host "`n🔍 Verifying cluster state..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

$clusterInfo = docker exec redis-single-cluster redis-cli --tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt -p 6379 cluster info
Write-Host "📊 Cluster Status:" -ForegroundColor Cyan
Write-Host $clusterInfo -ForegroundColor Gray

if ($clusterInfo -match "cluster_state:ok") {
    Write-Host "✅ Cluster state is OK!" -ForegroundColor Green
} elseif ($clusterInfo -match "cluster_state:fail") {
    Write-Host "❌ Cluster state is still failing" -ForegroundColor Red
} else {
    Write-Host "⚠️  Unknown cluster state" -ForegroundColor Yellow
}

# 🧪 Test cluster connection
Write-Host "`n🧪 Testing cluster connection..." -ForegroundColor Cyan
$pingResult = docker exec redis-single-cluster redis-cli --tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt -p 6379 ping
if ($pingResult -eq "PONG") {
    Write-Host "✅ Cluster connection test: $pingResult" -ForegroundColor Green
} else {
    Write-Host "❌ Cluster connection failed: $pingResult" -ForegroundColor Red
}

# �🎉 Done!
Write-Host "`n🎉 Redis cluster with TLS setup completed successfully!" -ForegroundColor Green
Write-Host "📋 Certificate files available in: $certsPath" -ForegroundColor Cyan
Write-Host "🔗 Redis cluster accessible on: localhost:6379 (TLS)" -ForegroundColor Cyan
Write-Host "`n🧪 Test commands:" -ForegroundColor Cyan
Write-Host "   docker exec redis-single-cluster redis-cli --tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt -p 6379 ping" -ForegroundColor Gray
Write-Host "   docker exec redis-single-cluster redis-cli --tls --cert /certs/redis.crt --key /certs/redis.key --cacert /certs/ca.crt -p 6379 cluster info" -ForegroundColor Gray
