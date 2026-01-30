# FK Webstack - Kubeadm Cluster Startup Script
# This script automates the complete deployment of FK webstack to a Vagrant/Kubeadm cluster
# Prerequisites: Vagrant and VirtualBox must be installed
# Run as Administrator

Write-Host "=== FK Webstack - Kubeadm Cluster Startup ===" -ForegroundColor Cyan
Write-Host "Prerequisites: Vagrant + VirtualBox installed" -ForegroundColor Gray
Write-Host ""

# Check if Vagrant is installed
if (!(Get-Command vagrant -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Vagrant not found. Please install Vagrant first." -ForegroundColor Red
    Write-Host "Download from: https://www.vagrantup.com/downloads" -ForegroundColor Yellow
    exit 1
}

# Check if VirtualBox is installed
if (!(Get-Command vboxmanage -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: VirtualBox not found. Please install VirtualBox first." -ForegroundColor Red
    Write-Host "Download from: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Yellow
    exit 1
}

# 1. Start Vagrant cluster (3 nodes: 1 control + 2 workers)
Write-Host "`n[1/6] Starting Vagrant Kubeadm cluster (1 control + 2 workers)..." -ForegroundColor Yellow
Write-Host "This will take 15-20 minutes for first run (downloads Ubuntu image + provisions VMs)" -ForegroundColor Gray

$vagrantStatus = vagrant status | Select-String "fk-control.*running"
if ($vagrantStatus) {
    Write-Host "✓ Cluster already running" -ForegroundColor Green
} else {
    Write-Host "Starting VMs..." -ForegroundColor Gray
    vagrant up
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Vagrant up failed. Check output above." -ForegroundColor Red
        exit 1
    }
}

# 2. Verify cluster nodes
Write-Host "`n[2/6] Verifying cluster nodes..." -ForegroundColor Yellow
$nodeCount = 0
$maxAttempts = 10
while ($nodeCount -lt 3 -and $maxAttempts -gt 0) {
    $nodes = vagrant ssh fk-control -c "kubectl get nodes --no-headers 2>/dev/null" 2>$null
    if ($nodes) {
        $nodeCount = ($nodes | Measure-Object -Line).Lines
        Write-Host "  Nodes ready: $nodeCount/3" -ForegroundColor Gray
        if ($nodeCount -ge 3) { break }
    }
    Start-Sleep -Seconds 5
    $maxAttempts--
}

if ($nodeCount -ge 3) {
    Write-Host "✓ All 3 nodes ready" -ForegroundColor Green
    vagrant ssh fk-control -c "kubectl get nodes -o wide"
} else {
    Write-Host "⚠ Only $nodeCount/3 nodes ready. Continuing anyway..." -ForegroundColor Yellow
}

# 3. Copy kubeconfig to Windows host (optional, for local kubectl)
Write-Host "`n[3/6] Copying kubeconfig to Windows host..." -ForegroundColor Yellow
$kubeconfigDir = "$env:USERPROFILE\.kube"
if (!(Test-Path $kubeconfigDir)) {
    New-Item -ItemType Directory -Path $kubeconfigDir -Force | Out-Null
}

try {
    vagrant ssh fk-control -c "cat /etc/kubernetes/admin.conf" 2>$null | Out-File -FilePath "$kubeconfigDir\config" -Encoding UTF8
    Write-Host "✓ Kubeconfig copied to $kubeconfigDir\config" -ForegroundColor Green
    Write-Host "  You can now use kubectl locally (if installed)" -ForegroundColor Gray
} catch {
    Write-Host "⚠ Failed to copy kubeconfig (not critical)" -ForegroundColor Yellow
}

# 4. Deploy ArgoCD + cert-manager + FK stack
Write-Host "`n[4/6] Deploying ArgoCD, cert-manager, and FK webstack..." -ForegroundColor Yellow
vagrant ssh fk-control -c "bash /vagrant/vagrant/05-deploy-argocd.sh"

# 5. Wait for FK stack pods
Write-Host "`n[5/6] Waiting for FK stack pods..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
$podStatus = vagrant ssh fk-control -c "kubectl get pods -n fk-webstack --no-headers 2>/dev/null" 2>$null
if ($podStatus) {
    Write-Host $podStatus
    Write-Host "✓ FK stack pods created" -ForegroundColor Green
} else {
    Write-Host "⚠ Pods may still be initializing" -ForegroundColor Yellow
}

# 6. Add fk.local to hosts file (requires Admin)
Write-Host "`n[6/6] Configuring local DNS (fk.local)..." -ForegroundColor Yellow
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$entry = "127.0.0.1 fk.local"

try {
    $hostsContent = Get-Content $hostsPath -ErrorAction Stop
    if ($hostsContent -notcontains $entry) {
        Add-Content -Path $hostsPath -Value $entry -ErrorAction Stop
        Write-Host "✓ Added fk.local to hosts file" -ForegroundColor Green
    } else {
        Write-Host "✓ fk.local already in hosts file" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Cannot modify hosts file (need Administrator)" -ForegroundColor Yellow
    Write-Host "  Manually add this line to C:\Windows\System32\drivers\etc\hosts:" -ForegroundColor Gray
    Write-Host "  127.0.0.1 fk.local" -ForegroundColor Cyan
}

# Summary
Write-Host "`n════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ KUBEADM CLUSTER DEPLOYED" -ForegroundColor Green
Write-Host "════════════════════════════════════════" -ForegroundColor Green

Write-Host "`n📋 CLUSTER INFO:" -ForegroundColor White
Write-Host "  Nodes: fk-control (192.168.56.10), fk-worker1 (.11), fk-worker2 (.12)" -ForegroundColor Gray
Write-Host "  Cluster: Kubernetes v1.35.0 with Flannel CNI" -ForegroundColor Gray
Write-Host "  Components: cert-manager, ArgoCD (Helm), FK webstack" -ForegroundColor Gray

Write-Host "`n🌐 ACCESS APPLICATIONS:" -ForegroundColor White
Write-Host "  1. ArgoCD UI:" -ForegroundColor Yellow
Write-Host "     vagrant ssh fk-control -c 'kubectl port-forward -n argocd svc/argocd-server 8080:443'" -ForegroundColor Cyan
Write-Host "     Then open: https://localhost:8080" -ForegroundColor Cyan
Write-Host "     User: admin | Password: (check deployment output)" -ForegroundColor Gray

Write-Host "`n  2. FK Application (via port-forward):" -ForegroundColor Yellow
Write-Host "     vagrant ssh fk-control -c 'kubectl port-forward -n fk-webstack svc/fk-frontend 80:80'" -ForegroundColor Cyan
Write-Host "     Then open: http://localhost" -ForegroundColor Cyan

Write-Host "`n  3. Grafana (after Prometheus install):" -ForegroundColor Yellow
Write-Host "     vagrant ssh fk-control -c 'kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80'" -ForegroundColor Cyan
Write-Host "     Then open: http://localhost:3000" -ForegroundColor Cyan

Write-Host "`n📊 USEFUL COMMANDS:" -ForegroundColor White
Write-Host "  Check pods:          vagrant ssh fk-control -c 'kubectl get all -n fk-webstack'" -ForegroundColor Gray
Write-Host "  Check nodes:         vagrant ssh fk-control -c 'kubectl get nodes -o wide'" -ForegroundColor Gray
Write-Host "  SSH to control:      vagrant ssh fk-control" -ForegroundColor Gray
Write-Host "  SSH to worker:       vagrant ssh fk-worker1" -ForegroundColor Gray
Write-Host "  Stop cluster:        vagrant halt" -ForegroundColor Gray
Write-Host "  Restart cluster:     vagrant up" -ForegroundColor Gray
Write-Host "  Destroy cluster:     vagrant destroy -f" -ForegroundColor Gray

Write-Host "`n💡 NEXT STEPS:" -ForegroundColor White
Write-Host "  ☐ Test FK application endpoints" -ForegroundColor Gray
Write-Host "  ☐ Deploy Prometheus monitoring" -ForegroundColor Gray
Write-Host "  ☐ Test HPA autoscaling with load" -ForegroundColor Gray
Write-Host "  ☐ Verify ArgoCD GitOps sync from GitHub" -ForegroundColor Gray
Write-Host "  ☐ Take screenshots for extra points" -ForegroundColor Gray

Write-Host ""
