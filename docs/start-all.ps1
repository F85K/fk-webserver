# FK Webstack - Complete Startup Script
# Dit script start alles: minikube, cert-manager, je app, Prometheus, en ArgoCD
# Run als Administrator

Write-Host "=== FK Webstack - Complete Startup ===" -ForegroundColor Cyan

# 1. Start minikube met 2 nodes
Write-Host "`n[1/10] Starting minikube met 2 worker nodes..." -ForegroundColor Yellow
minikube start --nodes 2 --cpus 4 --memory 8192
if ($LASTEXITCODE -ne 0) { Write-Host "Minikube start failed" -ForegroundColor Red; exit 1 }

# 2. Enable addons
Write-Host "`n[2/10] Enabling ingress en metrics-server..." -ForegroundColor Yellow
minikube addons enable ingress
minikube addons enable metrics-server

# 3. Point Docker to minikube
Write-Host "`n[3/10] Connecting Docker to minikube..." -ForegroundColor Yellow
& minikube -p minikube docker-env | Invoke-Expression

# 4. Build images
Write-Host "`n[4/10] Building Docker images..." -ForegroundColor Yellow
docker build -t fk-api:latest ./api
docker build -t fk-frontend:latest ./frontend

# 5. Install cert-manager
Write-Host "`n[5/10] Installing cert-manager..." -ForegroundColor Yellow
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
Write-Host "Waiting for cert-manager pods..." -ForegroundColor Gray
Start-Sleep -Seconds 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# 6. Deploy je applicatie
Write-Host "`n[6/10] Deploying FK webstack..." -ForegroundColor Yellow
kubectl apply -f k8s/

# 7. Wait for pods
Write-Host "`n[7/10] Waiting voor pods om klaar te zijn..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
kubectl wait --for=condition=ready pod -l app=fk-mongodb -n fk-webstack --timeout=120s
kubectl wait --for=condition=ready pod -l app=fk-api -n fk-webstack --timeout=120s
kubectl wait --for=condition=ready pod -l app=fk-frontend -n fk-webstack --timeout=120s

# 8. Add local DNS (vereist Administrator)
Write-Host "`n[8/10] Adding fk.local to hosts file..." -ForegroundColor Yellow
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$entry = "127.0.0.1 fk.local"
$hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
if ($hostsContent -notcontains $entry) {
    try {
        Add-Content -Path $hostsPath -Value $entry -ErrorAction Stop
        Write-Host "Added fk.local to hosts file" -ForegroundColor Green
    } catch {
        Write-Host "Failed to add to hosts. Run as Administrator!" -ForegroundColor Red
        Write-Host "Manually add: 127.0.0.1 fk.local to $hostsPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "fk.local already in hosts file" -ForegroundColor Green
}

# 9. Install Prometheus + Grafana (optioneel)
Write-Host "`n[9/10] Installing Prometheus + Grafana..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo update
helm install fk-monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Prometheus installed. Access Grafana:" -ForegroundColor Green
    Write-Host "  kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80" -ForegroundColor Cyan
    Write-Host "  http://localhost:3000 (admin/prom-operator)" -ForegroundColor Cyan
} else {
    Write-Host "Prometheus already installed or failed" -ForegroundColor Yellow
}

# 10. Install ArgoCD (optioneel)
Write-Host "`n[10/10] Installing ArgoCD..." -ForegroundColor Yellow
kubectl create namespace argocd 2>$null
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Waiting for ArgoCD..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s
    
    # Deploy FK app via ArgoCD
    kubectl apply -f k8s/60-argocd-application.yaml
    
    # Get ArgoCD password
    $argoPass = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
    
    Write-Host "ArgoCD installed. Access UI:" -ForegroundColor Green
    Write-Host "  kubectl port-forward -n argocd svc/argocd-server 8080:443" -ForegroundColor Cyan
    Write-Host "  https://localhost:8080 (admin / $argoPass)" -ForegroundColor Cyan
} else {
    Write-Host "ArgoCD already installed or failed" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Startup Complete ===" -ForegroundColor Green
Write-Host "`nYour app is ready at:" -ForegroundColor White
Write-Host "  https://fk.local (after running 'minikube tunnel')" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "  1. Open NEW terminal and run: minikube tunnel" -ForegroundColor Yellow
Write-Host "  2. Open browser: https://fk.local" -ForegroundColor Yellow
Write-Host "  3. Check status: kubectl get all -n fk-webstack" -ForegroundColor Yellow
Write-Host "`nOptional services:" -ForegroundColor White
Write-Host "  - Grafana: kubectl port-forward -n monitoring svc/fk-monitoring-grafana 3000:80" -ForegroundColor Gray
Write-Host "  - ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:443" -ForegroundColor Gray
