# Vagrant, Kubernetes & Linux Commands Reference

## Vagrant Commands (PowerShell)

### VM Lifecycle Management
```powershell
# Start all VMs defined in Vagrantfile
vagrant up

# Start a specific VM
vagrant up fk-control-plane
vagrant up fk-worker

# Stop VMs (graceful shutdown)
vagrant halt

# Stop a specific VM
vagrant halt fk-worker

# Restart VMs
vagrant reload

# Restart with provisioning
vagrant reload --provision

# Suspend VMs (save state)
vagrant suspend

# Resume suspended VMs
vagrant resume

# Destroy VMs (delete completely)
vagrant destroy

# Destroy without confirmation
vagrant destroy -f

# Destroy specific VM
vagrant destroy fk-worker -f
```

### VM Status & Information
```powershell
# Check status of all VMs
vagrant status

# Check global status of all Vagrant VMs
vagrant global-status

# Refresh global status cache
vagrant global-status --prune

# Show SSH configuration
vagrant ssh-config

# Show SSH config for specific VM
vagrant ssh-config fk-worker
```

### SSH Access
```powershell
# SSH into control plane
vagrant ssh fk-control-plane

# SSH into worker node
vagrant ssh fk-worker

# Execute command without entering VM
vagrant ssh fk-worker -c "kubectl get nodes"

# SSH with specific key
vagrant ssh fk-worker -- -i path/to/key
```

### Provisioning & Updates
```powershell
# Run provisioners
vagrant provision

# Run provisioners on specific VM
vagrant provision fk-control-plane

# Reload VM and re-run provisioners
vagrant reload --provision
```

### Snapshots
```powershell
# Create snapshot
vagrant snapshot save snapshot-name

# List snapshots
vagrant snapshot list

# Restore snapshot
vagrant snapshot restore snapshot-name

# Delete snapshot
vagrant snapshot delete snapshot-name
```

### Troubleshooting
```powershell
# Validate Vagrantfile
vagrant validate

# Show detailed logs
vagrant up --debug

# Force halt (hard shutdown)
vagrant halt -f

# Clear box cache
vagrant box remove ubuntu/jammy64
```

---

## Accessing VMs

### Enter VM via Vagrant SSH
```bash
# From PowerShell on Windows host:
vagrant ssh fk-worker

# You'll see prompt like:
# vagrant@fk-worker:~$
```

### Direct SSH (if configured)
```bash
# Get SSH config first
vagrant ssh-config fk-worker

# Then SSH directly
ssh vagrant@192.168.56.12 -i .vagrant/machines/fk-worker/virtualbox/private_key
```

### Switch User in VM
```bash
# Switch to root
sudo su -

# Run single command as root
sudo kubectl get nodes

# Switch to specific user
sudo su - username
```

---

## Essential Linux Commands

### Navigation & File Management
```bash
# Current directory
pwd

# List files
ls -la

# Change directory
cd /path/to/directory
cd ~          # Go to home directory
cd ..         # Go up one level
cd -          # Go to previous directory

# Create directory
mkdir dirname
mkdir -p parent/child/grandchild  # Create nested directories

# Copy files
cp source.txt destination.txt
cp -r sourcedir/ destdir/  # Copy directory recursively

# Move/rename
mv oldname.txt newname.txt
mv file.txt /new/location/

# Delete files
rm file.txt
rm -rf directory/  # Remove directory recursively (DANGEROUS!)

# View file contents
cat file.txt
less file.txt    # Scrollable view
head file.txt    # First 10 lines
tail file.txt    # Last 10 lines
tail -f file.txt # Follow file updates (logs)
```

### File Searching & Editing
```bash
# Find files
find /path -name "filename"
find . -name "*.yaml"

# Search in files
grep "search-term" file.txt
grep -r "search-term" /path/  # Recursive search
grep -i "search-term" file.txt # Case-insensitive

# Edit files
nano file.txt    # Simple editor
vi file.txt      # Vim editor
vim file.txt
```

### System Information
```bash
# Disk usage
df -h           # Disk space
du -sh /path    # Directory size

# Memory usage
free -h

# CPU and processes
top             # Interactive process viewer
htop            # Better top (if installed)
ps aux          # List all processes
ps aux | grep nginx

# System info
uname -a        # Kernel version
cat /etc/os-release  # OS version
hostname        # Show hostname
whoami          # Current user
```

### Process Management
```bash
# Kill process
kill PID
kill -9 PID     # Force kill
killall processname

# Background jobs
command &       # Run in background
jobs            # List background jobs
fg              # Bring to foreground
bg              # Send to background
```

### Networking
```bash
# IP information
ip addr
ip a            # Short version
ifconfig        # Older command

# Test connectivity
ping 8.8.8.8
ping fk-webserver.duckdns.org

# Check ports
netstat -tulpn
ss -tulpn       # Modern alternative
lsof -i :80     # What's using port 80

# DNS lookup
nslookup domain.com
dig domain.com

# Download files
curl https://example.com
wget https://example.com/file.tar.gz
```

### Permissions & Ownership
```bash
# Change permissions
chmod 755 script.sh
chmod +x script.sh   # Make executable

# Change ownership
chown user:group file.txt
chown -R user:group directory/

# View permissions
ls -l file.txt
```

### Archives & Compression
```bash
# Create tar archive
tar -czf archive.tar.gz directory/

# Extract tar archive
tar -xzf archive.tar.gz

# Zip files
zip archive.zip file1 file2
zip -r archive.zip directory/

# Unzip
unzip archive.zip
```

### System Management
```bash
# Systemd services
sudo systemctl status servicename
sudo systemctl start servicename
sudo systemctl stop servicename
sudo systemctl restart servicename
sudo systemctl enable servicename   # Start on boot
sudo systemctl disable servicename

# View logs
journalctl -u servicename
journalctl -f   # Follow journal
journalctl -xe  # Recent errors

# Reboot/shutdown
sudo reboot
sudo shutdown -h now
sudo shutdown -r now  # Reboot
```

---

## Kubernetes Commands (kubectl)

### Cluster Information
```bash
# Check cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes
kubectl get nodes -o wide

# Node details
kubectl describe node node-name

# Check component status
kubectl get componentstatuses
kubectl get cs
```

### Namespace Management
```bash
# List namespaces
kubectl get namespaces
kubectl get ns

# Create namespace
kubectl create namespace myapp

# Delete namespace
kubectl delete namespace myapp

# Set default namespace
kubectl config set-context --current --namespace=myapp
```

### Working with Pods
```bash
# List pods
kubectl get pods
kubectl get pods -n namespace-name
kubectl get pods --all-namespaces
kubectl get pods -A    # Short for all namespaces
kubectl get pods -o wide

# Pod details
kubectl describe pod pod-name
kubectl describe pod pod-name -n namespace

# Pod logs
kubectl logs pod-name
kubectl logs pod-name -n namespace
kubectl logs -f pod-name          # Follow logs
kubectl logs pod-name -c container-name  # Specific container
kubectl logs --tail=100 pod-name  # Last 100 lines
kubectl logs --since=1h pod-name  # Last hour

# Execute command in pod
kubectl exec -it pod-name -- /bin/bash
kubectl exec -it pod-name -- sh
kubectl exec pod-name -- ls /app
kubectl exec -it pod-name -c container-name -- /bin/bash

# Copy files to/from pod
kubectl cp file.txt pod-name:/path/in/pod
kubectl cp pod-name:/path/in/pod/file.txt ./local-file.txt

# Port forwarding
kubectl port-forward pod-name 8080:80
kubectl port-forward svc/service-name 8080:80
```

### Deployments
```bash
# List deployments
kubectl get deployments
kubectl get deploy

# Deployment details
kubectl describe deployment deployment-name

# Scale deployment
kubectl scale deployment deployment-name --replicas=3

# Update image
kubectl set image deployment/deployment-name container-name=new-image:tag

# Rollout status
kubectl rollout status deployment/deployment-name

# Rollout history
kubectl rollout history deployment/deployment-name

# Rollback deployment
kubectl rollout undo deployment/deployment-name
kubectl rollout undo deployment/deployment-name --to-revision=2

# Restart deployment
kubectl rollout restart deployment/deployment-name
```

### Services
```bash
# List services
kubectl get services
kubectl get svc

# Service details
kubectl describe service service-name

# Get endpoints
kubectl get endpoints
```

### ConfigMaps & Secrets
```bash
# List configmaps
kubectl get configmaps
kubectl get cm

# View configmap
kubectl describe configmap configmap-name
kubectl get configmap configmap-name -o yaml

# Create configmap
kubectl create configmap my-config --from-file=config.txt
kubectl create configmap my-config --from-literal=key=value

# List secrets
kubectl get secrets

# View secret (base64 encoded)
kubectl get secret secret-name -o yaml

# Decode secret
kubectl get secret secret-name -o jsonpath='{.data.password}' | base64 -d
```

### Ingress
```bash
# List ingress
kubectl get ingress
kubectl get ing

# Ingress details
kubectl describe ingress ingress-name
```

### Apply & Delete Resources
```bash
# Apply YAML file
kubectl apply -f file.yaml
kubectl apply -f directory/
kubectl apply -f https://url/file.yaml

# Delete resources
kubectl delete -f file.yaml
kubectl delete pod pod-name
kubectl delete deployment deployment-name
kubectl delete svc service-name

# Force delete pod
kubectl delete pod pod-name --force --grace-period=0

# Delete all pods in namespace
kubectl delete pods --all -n namespace
```

### Resource Management
```bash
# Get all resources
kubectl get all
kubectl get all -n namespace

# Get resource YAML
kubectl get pod pod-name -o yaml
kubectl get deployment deployment-name -o json

# Edit resource
kubectl edit deployment deployment-name

# Explain resource
kubectl explain pod
kubectl explain pod.spec
kubectl explain deployment.spec.template
```

### Troubleshooting
```bash
# Get events
kubectl get events
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n namespace

# Resource usage
kubectl top nodes
kubectl top pods
kubectl top pods -n namespace

# Check API resources
kubectl api-resources

# Dry run (test without applying)
kubectl apply -f file.yaml --dry-run=client
kubectl create deployment test --image=nginx --dry-run=client -o yaml

# Debug pod
kubectl run debug-pod --rm -it --image=busybox -- sh
kubectl run debug-pod --rm -it --image=nicolaka/netshoot -- bash
```

### Context & Configuration
```bash
# View current context
kubectl config current-context

# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context context-name

# View kubeconfig
kubectl config view

# Set credentials
kubectl config set-credentials user-name --token=bearer-token
```

---

## Project-Specific Commands

### Check Deployment Status
```bash
# Check all resources in app namespace
kubectl get all -n app

# Check pods
kubectl get pods -n app -o wide

# Check services
kubectl get svc -n app

# Check ingress
kubectl get ingress -n app
```

### MongoDB Commands
```bash
# Connect to MongoDB pod
kubectl exec -it $(kubectl get pod -n app -l app=mongodb -o jsonpath='{.items[0].metadata.name}') -n app -- mongosh

# Inside MongoDB shell:
show dbs
use testdb
show collections
db.items.find()
db.items.insertOne({name: "Test Item", description: "Test"})
```

### API Testing
```bash
# Port forward API service
kubectl port-forward -n app svc/api 5000:5000

# Test API (from another terminal or VM)
curl http://localhost:5000/items
curl http://localhost:5000/health

# Test from outside
curl http://192.168.56.12/api/items
curl http://fk-webserver.duckdns.org/api/items
```

### View Logs
```bash
# API logs
kubectl logs -f -n app -l app=api

# Frontend logs
kubectl logs -f -n app -l app=frontend

# MongoDB logs
kubectl logs -f -n app -l app=mongodb

# Ingress controller logs
kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Certificate Debugging
```bash
# Check certificates
kubectl get certificates -n app
kubectl describe certificate app-tls -n app

# Check certificate requests
kubectl get certificaterequests -n app
kubectl describe certificaterequest -n app

# Check cert-manager logs
kubectl logs -f -n cert-manager -l app=cert-manager
```

### ArgoCD
```bash
# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# ArgoCD CLI commands (if installed)
argocd login localhost:8080
argocd app list
argocd app get app-name
argocd app sync app-name
```

### Quick Redeploy
```bash
# Delete and reapply all k8s manifests
kubectl delete -f k8s/ --ignore-not-found
kubectl apply -f k8s/

# Restart specific deployment
kubectl rollout restart deployment/api -n app
kubectl rollout restart deployment/frontend -n app
```

### Cleanup Stuck Resources
```bash
# Remove finalizers from stuck namespace
kubectl get namespace namespace-name -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/namespace-name/finalize" -f -

# Force delete pod
kubectl delete pod pod-name --grace-period=0 --force -n namespace
```

---

## Useful One-Liners

### Vagrant
```powershell
# Recreate everything from scratch
vagrant destroy -f; vagrant up

# SSH and run kubectl command
vagrant ssh fk-control-plane -c "kubectl get pods -A"
```

### Kubernetes
```bash
# Delete all evicted pods
kubectl get pods -A | grep Evicted | awk '{print $2 " -n " $1}' | xargs kubectl delete pod

# Get all container images in use
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Watch pods in real-time
watch kubectl get pods -n app

# Get pod restart count
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'

# Check which pods are not running
kubectl get pods -A --field-selector=status.phase!=Running

# Get resource requests/limits
kubectl get pods -n app -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory
```

### Linux
```bash
# Find largest directories
du -h / | sort -rh | head -20

# Monitor file changes
watch -n 1 cat /var/log/syslog

# Check open files by process
lsof -p PID

# Find files modified in last 24 hours
find /path -mtime -1

# Check listening ports
netstat -tulpn | grep LISTEN
```

---

## Common Workflows

### Deploy Application Changes
```bash
# 1. SSH into control plane
vagrant ssh fk-control-plane

# 2. Apply changes
kubectl apply -f /vagrant/k8s/

# 3. Watch deployment
kubectl rollout status deployment/api -n app
kubectl get pods -n app -w
```

### Debug Failed Pod
```bash
# 1. Check pod status
kubectl get pods -n app

# 2. Describe pod for events
kubectl describe pod pod-name -n app

# 3. Check logs
kubectl logs pod-name -n app

# 4. Check previous logs if crashed
kubectl logs pod-name -n app --previous

# 5. Execute into running pod
kubectl exec -it pod-name -n app -- /bin/sh
```

### Test DNS Resolution
```bash
# Create debug pod
kubectl run dnsutils --image=tutum/dnsutils --rm -it -- /bin/bash

# Inside pod:
nslookup api.app.svc.cluster.local
nslookup mongodb.app.svc.cluster.local
```

### Monitor Cluster Health
```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

---

## Tips & Best Practices

1. **Always specify namespace** with `-n namespace` to avoid confusion
2. **Use labels** to filter resources: `kubectl get pods -l app=api`
3. **Save YAML output** before deleting: `kubectl get pod pod-name -o yaml > backup.yaml`
4. **Use `--dry-run`** to test commands before applying
5. **Follow logs** with `-f` flag for real-time monitoring
6. **Use `watch`** command to monitor changes: `watch kubectl get pods`
7. **Backup important data** before destructive operations
8. **Tab completion** - enable for kubectl: `source <(kubectl completion bash)`

---

## Emergency Commands

```bash
# Restart kubelet on node
sudo systemctl restart kubelet

# Drain node for maintenance
kubectl drain node-name --ignore-daemonsets --delete-emptydir-data

# Make node schedulable again
kubectl uncordon node-name

# Force delete stuck namespace
kubectl delete namespace namespace-name --force --grace-period=0

# Reset kubernetes cluster (DESTRUCTIVE!)
sudo kubeadm reset -f
```

---

*Last updated: 2026-02-22*
