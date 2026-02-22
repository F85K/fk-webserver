# Deployment Issues Log

This file tracks issues encountered during deployment and their resolution.

---

## Observed Issues (from vagrant_deployment.log)

### 1) Guest Additions Version Mismatch

**Symptom:**
- Messages about Guest Additions version 6.0.0 with VirtualBox 7.2.

**Impact:**
- Usually safe, but can break shared folders in some cases.

**Resolution:**
- If `/vagrant` mount fails inside any VM, install matching Guest Additions or update the box.

---

### 2) SSH Connection Resets During First Boot

**Symptom:**
- `Warning: Connection reset. Retrying...`
- `Warning: Connection aborted. Retrying...`

**Impact:**
- Harmless during first boot. Vagrant retries and succeeds.

**Resolution:**
- No action needed unless it repeats for more than 10 minutes.

---

## Items To Monitor During Provisioning

### A) API Server Stability

**Symptoms:**
- `kubectl get nodes` returns connection refused.

**Likely Causes:**
- Control plane not fully initialized.
- Resource pressure (etcd/API server restarts).

**Resolution:**
- Wait 3-5 minutes after `kubeadm init`.
- Check `sudo journalctl -u kubelet -n 100 --no-pager`.

---

### B) Flannel Not Ready

**Symptoms:**
- Workers stuck in NotReady.
- Flannel pods CrashLoopBackOff.

**Resolution:**
- Reapply Flannel manifest.
- Restart kubelet on workers.

---

### C) Helm Install Timeouts

**Symptoms:**
- cert-manager / ArgoCD install hangs or times out.

**Resolution:**
- Re-run the specific Helm install with longer timeouts.

---

## Notes

Add new issues here as they appear. Include:
- Exact error text
- Which step it happened
- How it was resolved
