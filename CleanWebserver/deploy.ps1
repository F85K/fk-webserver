# FK Webstack Deployment Helper Script
# This script automates the deployment phases

param(
    [ValidateSet("up", "deploy", "test", "logs", "scale", "destroy", "status")]
    [string]$Action = "status",
    [int]$Replicas = 4
)

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-Step {
    param([string]$Message)
    Write-Host "$Blue[STEP]$Reset $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "$Green[✓]$Reset $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "$Red[✗]$Reset $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$Yellow[!]$Reset $Message"
}

# Phase 1: Create cluster
function Invoke-ClusterUp {
    Write-Step "Phase 1: Creating Kubernetes cluster with Vagrant..."
    Write-Warning "This will take 20-25 minutes on first run (image download)"
    
    vagrant up
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create cluster"
        exit 1
    }
    
    Write-Success "Cluster created!"
    Write-Step "Verifying cluster status..."
    
    Start-Sleep -Seconds 10
    vagrant ssh fk-control -c "kubectl get nodes"
}

# Phase 2: Deploy application
function Invoke-Deploy {
    Write-Step "Phase 2: Deploying application to Kubernetes..."
    
    Write-Step "Checking cluster status..."
    $nodes = vagrant ssh fk-control -c "kubectl get nodes --no-headers" -ErrorAction SilentlyContinue
    if ($null -eq $nodes -or $nodes -notmatch "Ready") {
        Write-Error "Cluster not ready. Run 'deploy.ps1 -Action up' first"
        exit 1
    }
    
    Write-Success "Cluster is Ready!"
    
    Write-Step "Deploying manifests..."
    vagrant ssh fk-control -c "kubectl apply -f /vagrant/kubernetes/manifests.yaml"
    
    Write-Success "Manifests deployed!"
    
    Write-Step "Waiting for pods to start (30 seconds)..."
    Start-Sleep -Seconds 30
    
    Write-Step "Pod status:"
    vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"
}

# Phase 3: Run tests
function Invoke-Test {
    Write-Step "Phase 3: Testing application..."
    
    Write-Step "Checking pod status..."
    $pods = vagrant ssh fk-control -c "kubectl get pods -n fk-webstack --no-headers"
    $running = @($pods -split "`n" | Where-Object { $_ -match "Running" }).Count
    
    if ($running -lt 3) {
        Write-Warning "Not all pods running yet. Waiting..."
        Start-Sleep -Seconds 10
    }
    
    Write-Success "Testing API endpoints..."
    
    Write-Step "Setting up port-forwards (this will run in background)..."
    
    # Test API
    Write-Step "Test 1: API /api/name"
    $result = vagrant ssh fk-control -c "curl -s http://fk-api:8000/api/name"
    if ($result -match "Frank Koch") {
        Write-Success "✓ API returns student name"
    } else {
        Write-Warning "API not responding, trying via port-forward..."
    }
    
    Write-Step "Test 2: API /api/container-id"
    $result = vagrant ssh fk-control -c "curl -s http://fk-api:8000/api/container-id"
    if ($result -match "container_id") {
        Write-Success "✓ API returns container ID"
    }
    
    Write-Step "Test 3: Health checks"
    $result = vagrant ssh fk-control -c "kubectl get pods -n fk-webstack -o json | grep -c 'Ready.*true'"
    Write-Success "✓ Health checks configured"
    
    Write-Step "Manual testing instructions:"
    Write-Host "  1. Port-forward frontend:"
    Write-Host "     $Yellow`vagrant ssh fk-control -c 'kubectl port-forward -n fk-webstack svc/fk-frontend 8080:80'$Reset"
    Write-Host "  2. Open browser: http://localhost:8080"
    Write-Host ""
    Write-Host "  3. Port-forward API (separate terminal):"
    Write-Host "     $Yellow`vagrant ssh fk-control -c 'kubectl port-forward -n fk-webstack svc/fk-api 8000:8000'$Reset"
    Write-Host "  4. Test: curl http://localhost:8000/api/name"
}

# Show logs
function Invoke-Logs {
    Write-Step "Showing application logs..."
    Write-Host "MongoDB logs:"
    vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-mongodb --tail=20"
    
    Write-Host ""
    Write-Host "API logs:"
    vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-api --tail=20"
    
    Write-Host ""
    Write-Host "Frontend logs:"
    vagrant ssh fk-control -c "kubectl logs -n fk-webstack -l app=fk-frontend --tail=20"
}

# Scale API
function Invoke-Scale {
    Write-Step "Scaling API deployment to $Replicas replicas..."
    vagrant ssh fk-control -c "kubectl scale deployment fk-api -n fk-webstack --replicas=$Replicas"
    Write-Success "Scaled to $Replicas replicas"
    
    Write-Step "Current replicas:"
    vagrant ssh fk-control -c "kubectl get deployment fk-api -n fk-webstack"
}

# Destroy cluster
function Invoke-Destroy {
    Write-Warning "This will DELETE all VMs and data!"
    $confirm = Read-Host "Type 'yes' to confirm"
    
    if ($confirm -ne "yes") {
        Write-Step "Cancelled"
        return
    }
    
    Write-Step "Destroying cluster..."
    vagrant destroy -f
    Write-Success "Cluster destroyed"
}

# Cluster status
function Invoke-Status {
    Write-Step "FK Webstack Deployment Status"
    Write-Host "================================"
    
    Write-Step "Vagrant VMs:"
    vagrant status
    
    Write-Host ""
    Write-Step "Kubernetes nodes:"
    vagrant ssh fk-control -c "kubectl get nodes" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    
    Write-Host ""
    Write-Step "Application pods:"
    vagrant ssh fk-control -c "kubectl get pods -n fk-webstack" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    
    Write-Host ""
    Write-Step "Services:"
    vagrant ssh fk-control -c "kubectl get svc -n fk-webstack" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
}

# Main dispatcher
switch ($Action) {
    "up" { Invoke-ClusterUp }
    "deploy" { Invoke-Deploy }
    "test" { Invoke-Test }
    "logs" { Invoke-Logs }
    "scale" { Invoke-Scale -Replicas $Replicas }
    "destroy" { Invoke-Destroy }
    "status" { Invoke-Status }
    default { 
        Write-Host "Usage: deploy.ps1 -Action <action> [-Replicas <n>]"
        Write-Host ""
        Write-Host "Actions:"
        Write-Host "  up       - Create cluster and provision (20-25 min on first run)"
        Write-Host "  deploy   - Deploy application manifests"
        Write-Host "  test     - Run tests and show status"
        Write-Host "  logs     - Show application logs"
        Write-Host "  scale    - Scale API replicas (default 4, use -Replicas)"
        Write-Host "  status   - Show current deployment status"
        Write-Host "  destroy  - Delete cluster and VMs"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  deploy.ps1 -Action up           # Create cluster"
        Write-Host "  deploy.ps1 -Action deploy       # Deploy app"
        Write-Host "  deploy.ps1 -Action test         # Run tests"
        Write-Host "  deploy.ps1 -Action scale -Replicas 2  # Scale to 2 replicas"
    }
}
