#!/usr/bin/env pwsh
# Complete deployment script - runs everything needed

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

cd C:\Users\Admin\Desktop\WebserverLinux

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FK Webstack Complete Deployment" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Memory: 12GB total (6GB control + 3GB each worker)" -ForegroundColor Green
Write-Host ""

Write-Host "Step 1: Stop all VMs..." -ForegroundColor Yellow
vagrant halt
Start-Sleep -Seconds 10

Write-Host "Step 2: Start VMs with new memory config..." -ForegroundColor Yellow
vagrant up
Write-Host "⏳ Waiting for cluster to boot (5-10 minutes)..." -ForegroundColor Yellow

# Wait for VMs to be ready
Start-Sleep -Seconds 60

# Check if cluster is ready
$ready = $false
$attempts = 0
while (-not $ready -and $attempts -lt 30) {
    $result = vagrant ssh fk-control -c "kubectl get nodes 2>/dev/null | grep -c Ready" 2>&1
    if ($result -match "3") {
        $ready = $true
    }
    $attempts++
    if (-not $ready) {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 10
    }
}

Write-Host ""
if ($ready) {
    Write-Host "✅ Cluster is ready!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Cluster may still be starting, continuing anyway..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 3: Deploying complete stack..." -ForegroundColor Yellow
vagrant ssh fk-control -c "bash /vagrant/install-complete-stack.sh"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available services:" -ForegroundColor Yellow
Write-Host "  🔧 API:        http://localhost:8000/api/name"
Write-Host "  📊 Grafana:    http://localhost:3000 (admin/prom-operator)"
Write-Host "  📈 Prometheus: http://localhost:9090"
Write-Host "  🔄 ArgoCD:     https://localhost:8080"
Write-Host ""
Write-Host "To access services, run (in separate terminals):" -ForegroundColor Yellow
Write-Host ""
Write-Host "# API Tests:" -ForegroundColor Cyan
Write-Host "vagrant ssh fk-control -c 'kubectl port-forward svc/fk-api -n fk-webstack 8000:8000'" -ForegroundColor White
Write-Host "# Then in another terminal:"
Write-Host "Invoke-RestMethod http://localhost:8000/api/name" -ForegroundColor White
Write-Host ""
Write-Host "# Grafana (Monitoring Dashboard):" -ForegroundColor Cyan
Write-Host "vagrant ssh fk-control -c 'kubectl port-forward svc/fk-monitoring-grafana -n monitoring 3000:80'" -ForegroundColor White
Write-Host "# Access: http://localhost:3000 (admin/prom-operator)" -ForegroundColor White
Write-Host ""
Write-Host "# Prometheus:" -ForegroundColor Cyan
Write-Host "vagrant ssh fk-control -c 'kubectl port-forward svc/fk-monitoring-prometheus -n monitoring 9090:9090'" -ForegroundColor White
Write-Host ""
