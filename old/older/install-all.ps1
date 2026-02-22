#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

cd C:\Users\Admin\Desktop\WebserverLinux

Write-Host "======================================"
Write-Host "Installing cert-manager (TLS)"
Write-Host "======================================"
vagrant ssh fk-control -c "bash /vagrant/install-cert-manager.sh"

Start-Sleep -Seconds 10

Write-Host ""
Write-Host "======================================"
Write-Host "Installing Prometheus (Monitoring)"
Write-Host "======================================"
vagrant ssh fk-control -c "bash /vagrant/install-prometheus.sh"

Start-Sleep -Seconds 10

Write-Host ""
Write-Host "======================================"
Write-Host "Installing ArgoCD (GitOps)"
Write-Host "======================================"
vagrant ssh fk-control -c "bash /vagrant/install-argocd.sh"

Start-Sleep -Seconds 10

Write-Host ""
Write-Host "======================================"
Write-Host "VERIFICATION"
Write-Host "======================================"

Write-Host ""
Write-Host "Namespaces:"
vagrant ssh fk-control -c "kubectl get ns"

Write-Host ""
Write-Host "fk-webstack pods:"
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"

Write-Host ""
Write-Host "cert-manager pods:"
vagrant ssh fk-control -c "kubectl get pods -n cert-manager"

Write-Host ""
Write-Host "monitoring pods:"
vagrant ssh fk-control -c "kubectl get pods -n monitoring"

Write-Host ""
Write-Host "argocd pods:"
vagrant ssh fk-control -c "kubectl get pods -n argocd"

Write-Host ""
Write-Host "======================================"
Write-Host "✅ All installations complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Open a NEW terminal and run:"
Write-Host "   vagrant ssh fk-control -c 'kubectl port-forward svc/fk-api -n fk-webstack 8000:8000'"
Write-Host ""
Write-Host "2. In ANOTHER new terminal, test:"
Write-Host "   Invoke-RestMethod http://localhost:8000/api/name"
Write-Host ""
