# VM Lifecycle Management Guide

## 💾 Saving and Resuming Your Vagrant Cluster

This guide explains how to properly save and resume your Kubernetes cluster VMs when shutting down your laptop.

---

## 🎯 Quick Reference

| Scenario | Command | Boot Time | Preserves State |
|----------|---------|-----------|-----------------|
| **Short break** (lunch, overnight) | `vagrant suspend` | 5-10 sec | ✅ Yes - Everything preserved |
| **Long break** (weekend, shutdown) | `vagrant halt` | 2-3 min | ⚠️ Pods restart, cluster recovers |
| **Full cleanup** (start fresh) | `vagrant destroy -f` | 15-20 min | ❌ No - Complete rebuild |

---

## Option 1: Suspend (Hibernation) - RECOMMENDED FOR DAILY USE

### What It Does
Saves the entire VM memory state to disk, like hibernating your laptop. All running processes, network connections, and Kubernetes pods remain exactly as they were.

### Commands

```powershell
# Save current state
vagrant suspend

# Resume later
vagrant resume

# Check status
vagrant status
```

### When to Use
- ✅ End of workday
- ✅ Quick laptop restart
- ✅ Moving between locations
- ✅ Short breaks (hours to 1-2 days)

### Advantages
- ⚡ **Instant resume**: 5-10 seconds
- 🎯 **Exact state preserved**: All pods, services, connections intact
- 🔄 **No cluster recovery needed**: Kubernetes doesn't know anything happened
- 📊 **No data loss**: Everything in memory is saved

### Disadvantages
- 💾 **Disk space**: Uses ~6GB (your cluster's RAM: 6GB+5GB+5GB)
- ⏰ **Not for long periods**: VMs can become stale after several days

### Example Workflow

```powershell
# Friday 5 PM - Going home
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant suspend
==> fk-worker2: Saving VM state and suspending execution...
==> fk-worker1: Saving VM state and suspending execution...
==> fk-control: Saving VM state and suspending execution...

# Monday 9 AM - Back to work
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant resume
==> fk-control: Resuming suspended VM...
==> fk-worker1: Resuming suspended VM...
==> fk-worker2: Resuming suspended VM...

# Verify cluster is immediately ready
PS C:\Users\Admin\Desktop\WebserverLinux> kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
fk-control    Ready    control-plane   2d    v1.35.0
fk-worker1    Ready    <none>          2d    v1.35.0
fk-worker2    Ready    <none>          2d    v1.35.0
```

---

## Option 2: Halt (Clean Shutdown) - RECOMMENDED FOR LONGER PERIODS

### What It Does
Performs a graceful shutdown of all VMs, like shutting down your computer. Kubernetes cluster will need to restart all components and pods.

### Commands

```powershell
# Shutdown all VMs
vagrant halt

# Start all VMs later
vagrant up

# Or do it for specific VMs
vagrant halt fk-control
vagrant up fk-control
```

### When to Use
- ✅ Weekend breaks (2+ days)
- ✅ Extended laptop shutdown
- ✅ Saving laptop battery
- ✅ Freeing up RAM for other work

### Advantages
- 💾 **No extra disk space**: No RAM snapshots saved
- 🧹 **Clean state**: VMs boot fresh, no stale processes
- 🔋 **Battery friendly**: No VirtualBox processes running
- 📦 **Smaller footprint**: Only VM disks stored (~10GB vs ~16GB with suspend)

### Disadvantages
- ⏱️ **Slower startup**: 2-3 minutes for full cluster recovery
- 🔄 **Kubernetes restart**: Pods restart, temporary service interruption
- ⚙️ **More complex recovery**: Cluster needs time to stabilize

### Example Workflow

```powershell
# Friday evening - Extended shutdown
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant halt
==> fk-worker2: Attempting graceful shutdown of VM...
==> fk-worker1: Attempting graceful shutdown of VM...
==> fk-control: Attempting graceful shutdown of VM...

# Monday morning - Restart
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant up
Bringing machine 'fk-control' up with 'virtualbox' provider...
Bringing machine 'fk-worker1' up with 'virtualbox' provider...
Bringing machine 'fk-worker2' up with 'virtualbox' provider...
==> fk-control: Checking if box 'ubuntu/jammy64' version '20240821.0.0' is up to date...
==> fk-control: Booting VM...
[... 2-3 minutes ...]

# Wait a bit, then verify cluster recovered
PS C:\Users\Admin\Desktop\WebserverLinux> Start-Sleep -Seconds 120
PS C:\Users\Admin\Desktop\WebserverLinux> kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
fk-control    Ready    control-plane   2d    v1.35.0
fk-worker1    Ready    <none>          2d    v1.35.0
fk-worker2    Ready    <none>          2d    v1.35.0
```

---

## Option 3: Destroy (Full Cleanup) - ONLY WHEN STARTING FRESH

### What It Does
Completely deletes all VMs and their virtual disks. Next `vagrant up` will rebuild everything from scratch.

### Commands

```powershell
# Delete everything
vagrant destroy -f

# Rebuild cluster from scratch
vagrant up
```

### When to Use
- ✅ Cluster is broken beyond repair
- ✅ Testing cluster initialization scripts
- ✅ Freeing up disk space (removes ~10GB)
- ✅ Starting fresh for oral exam practice

### Workflow

```powershell
# Nuclear option - delete and rebuild
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant destroy -f
==> fk-worker2: Forcing shutdown of VM...
==> fk-worker2: Destroying VM and associated drives...
==> fk-worker1: Forcing shutdown of VM...
==> fk-worker1: Destroying VM and associated drives...
==> fk-control: Forcing shutdown of VM...
==> fk-control: Destroying VM and associated drives...

PS C:\Users\Admin\Desktop\WebserverLinux> vagrant up
# ... 15-20 minutes for full cluster build ...
```

---

## ⚠️ What NOT to Do

### ❌ DON'T Use VirtualBox GUI Directly

Vagrant manages VMs - using VirtualBox GUI can cause state mismatches.

```
❌ BAD:
VirtualBox Manager → Right-click VM → "Save State"
VirtualBox Manager → Right-click VM → "Close" → "Power Off"

✅ GOOD:
vagrant suspend
vagrant halt
```

### ❌ DON'T Mix Vagrant and VirtualBox Commands

```powershell
# ❌ BAD - State conflicts
VBoxManage controlvm fk-control poweroff
vagrant status  # Will show incorrect state

# ✅ GOOD - Consistent state
vagrant halt fk-control
vagrant status  # Correct state shown
```

---

## 📊 Status Checking

### Check VM States

```powershell
PS C:\Users\Admin\Desktop\WebserverLinux> vagrant status
Current machine states:

fk-control    running (virtualbox)    # ← Currently running
fk-worker1    saved (virtualbox)      # ← Suspended
fk-worker2    poweroff (virtualbox)   # ← Shut down

This environment represents multiple VMs. The VMs are all listed
above with their current state.
```

### Check Kubernetes Cluster

```powershell
# Quick node check
kubectl get nodes

# Detailed cluster info
kubectl cluster-info

# Check pod status across all namespaces
kubectl get pods -A

# Check if ArgoCD is running
kubectl get pods -n argocd
```

---

## 🎯 Recommended Workflow for Your Use Case

**Your laptop: 32GB RAM, i7-12800H, Windows 11**  
**Your cluster: 16GB allocated (6GB+5GB+5GB across 3 VMs)**

### Daily Work (Best Practice)

```powershell
# Morning - Start work
vagrant resume  # Or 'vagrant up' if halted
kubectl get nodes  # Verify cluster is ready

# During day - Work normally
kubectl apply -f ...
vagrant ssh fk-control

# Evening - Going home
vagrant suspend  # Quick save
```

### Extended Breaks (Weekends)

```powershell
# Friday evening
vagrant halt  # Clean shutdown

# Monday morning
vagrant up  # Takes 2-3 minutes
# Wait for cluster to stabilize...
kubectl get nodes  # Verify all Ready
```

### Troubleshooting Scenario

```powershell
# Something broken?
vagrant destroy -f  # Nuclear option
vagrant up  # Rebuild from scratch (15-20 min)
```

---

## 🔍 Troubleshooting

### Issue: "vagrant resume" Takes Forever

**Solution**: VM was suspended for too long (>1 week). Halt and restart instead:

```powershell
vagrant halt -f  # Force shutdown
vagrant up  # Clean boot
```

### Issue: Kubernetes Nodes Not Ready After Resume

**Solution**: Give cluster time to stabilize:

```powershell
vagrant resume
Start-Sleep -Seconds 60  # Wait 1 minute
kubectl get nodes  # Should show Ready now
```

### Issue: Can't SSH After Suspend

**Solution**: Network issue - reload the VM:

```powershell
vagrant reload fk-control
```

### Issue: Out of Disk Space

**Solution**: Remove suspended state and use halt instead:

```powershell
# Find where Vagrant stores VMs (usually C:\Users\Admin\VirtualBox VMs\)
# Delete .sav files manually, or:
vagrant halt  # Cleans up suspended state
vagrant up  # Restart without suspend files
```

---

## 📝 Summary Table

| Action | Command | Time | RAM Impact | Disk Impact | Best For |
|--------|---------|------|------------|-------------|----------|
| **Suspend** | `vagrant suspend` | 5-10s | Freed | +6GB | Daily work |
| **Resume** | `vagrant resume` | 5-10s | 16GB used | - | Daily work |
| **Halt** | `vagrant halt` | 30s | Freed | 0 | Weekends |
| **Up** | `vagrant up` | 2-3min | 16GB used | 0 | After halt |
| **Destroy** | `vagrant destroy -f` | 30s | Freed | -10GB | Fresh start |
| **Build** | `vagrant up` (after destroy) | 15-20min | 16GB used | +10GB | After destroy |

---

## 🎓 For Your Oral Exam

To demonstrate cluster reliability:

```powershell
# Show cluster is working
kubectl get nodes
kubectl get pods -A

# Demonstrate suspend/resume cycle
vagrant suspend
Write-Host "Cluster saved - simulating laptop shutdown/resume"
vagrant resume
Start-Sleep -Seconds 30
kubectl get nodes  # Still all Ready - impressive!

# Demonstrate halt/up cycle
vagrant halt
Write-Host "Clean shutdown - simulating multi-day break"
vagrant up
Start-Sleep -Seconds 120
kubectl get nodes  # Cluster self-recovered - self-healing!

# Demonstrate destroy/rebuild cycle
vagrant destroy -f
Write-Host "Demonstrating reproducible infrastructure"
vagrant up
# Wait 15-20 minutes for full rebuild
kubectl get nodes  # Cluster rebuilt from scratch - infrastructure as code!
```

---

## 💡 Pro Tips

1. **Always check status first**: `vagrant status` before any command
2. **Use suspend for < 2 days**: Faster and preserves exact state
3. **Use halt for > 2 days**: Cleaner and no extra disk space
4. **Test your workflow**: Practice suspend/resume cycle before your exam
5. **Document your choice**: Explain why you chose suspend vs halt in your presentation

---

## 🔗 Related Commands

```powershell
# See all vagrant commands
vagrant --help

# SSH into any VM (auto-resumes if suspended)
vagrant ssh fk-control

# Reload a VM (like restart without full destroy)
vagrant reload fk-control

# Provision only (run scripts without reboot)
vagrant provision fk-control

# Take a snapshot (VirtualBox native, not Vagrant)
VBoxManage snapshot fk-control take "before-argocd"
VBoxManage snapshot fk-control restore "before-argocd"
```

---

**Last Updated**: February 1, 2026  
**Cluster Configuration**: 3-node kubeadm (1 control + 2 workers)  
**Resources**: 16GB RAM, 8 CPUs (50% of host)  
**Kubernetes Version**: v1.35.0
