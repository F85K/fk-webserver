# Cleanup Obsolete Scripts
# Removes old troubleshooting scripts that are now replaced by comprehensive versions

Write-Host "Cleaning up obsolete deployment scripts..." -ForegroundColor Yellow

# Old scripts to remove (replaced by vagrant/deploy-full-stack.sh)
$ObsoleteScripts = @(
    "check-cluster.sh",
    "deploy-all.ps1",
    "deploy-incremental.sh",
    "emergency-recovery.sh",
    "fix-certmanager.sh",
    "fix-worker1.sh",
    "full-worker-fix.sh",
    "install-all.bat",
    "install-all.ps1",
    "install-argocd.sh",
    "install-cert-manager.sh",
    "install-complete-stack.sh",
    "install-gitops-only.sh",
    "install-prometheus.sh",
    "install-tls-only.sh",
    "quick-verify.sh",
    "restart-k8s.sh",
    "verify-all.sh",
    "vagrant\05-deploy-argocd.sh"
)

$Removed = 0
$NotFound = 0

foreach ($Script in $ObsoleteScripts) {
    $Path = Join-Path $PSScriptRoot $Script
    if (Test-Path $Path) {
        Remove-Item $Path -Force
        Write-Host "  ✓ Removed: $Script" -ForegroundColor Green
        $Removed++
    } else {
        $NotFound++
    }
}

Write-Host "`n✓ Cleanup complete!" -ForegroundColor Green
Write-Host "  Removed: $Removed files" -ForegroundColor Cyan
Write-Host "  Not found: $NotFound files (already clean)" -ForegroundColor Gray

Write-Host "`nNow use these comprehensive scripts:" -ForegroundColor Yellow
Write-Host "  vagrant ssh fk-control -c 'bash /vagrant/deploy-full-stack.sh'" -ForegroundColor White
Write-Host "  vagrant ssh fk-control -c 'bash /vagrant/verify-success-criteria.sh'" -ForegroundColor White
Write-Host "  vagrant ssh fk-control -c 'bash /vagrant/cleanup-stuck-resources.sh'" -ForegroundColor White
