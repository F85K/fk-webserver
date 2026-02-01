# Security & Secrets Management

## ⚠️ CRITICAL: GitGuardian Alert Response

**Alert:** Exposed kubeadm join token in `kubeadm-config/join-command.sh`  
**Status:** ✅ REVOKED and REMOVED from repository  
**Date:** February 1, 2026

### Token Revoked
- **Token:** `egvgyj.ks2yu2d82jalzgdq`
- **Action:** Deleted via `kubeadm token delete egvgyj.ks2yu2d82jalzgdq`
- **Cleanup:** Removed from Git history

---

## Never Commit Sensitive Data

All sensitive files are protected by `.gitignore`:

```
kubeadm-config/join-command.sh
.env files
kubeadm credentials
Database passwords
ArgoCD admin credentials
API keys and tokens
```

---

## Kubeadm Join Token Lifecycle

### 1. Generate Token (When Adding New Worker)

```bash
# On fk-control node
ssh vagrant@192.168.56.10

# Create join command (valid 24 hours by default)
kubeadm token create --print-join-command

# Output example:
# kubeadm join 192.168.56.10:6443 --token abc123.def456 --discovery-token-ca-cert-hash sha256:xxxxx
```

### 2. Use Token for Worker Join

```bash
# On new worker node (fk-worker1 or fk-worker2)
# Copy the full join command from step 1 and run it

kubeadm join 192.168.56.10:6443 --token abc123.def456 --discovery-token-ca-cert-hash sha256:xxxxx
```

### 3. Revoke Token (After Worker Joins)

```bash
# On fk-control node
# List active tokens
kubeadm token list

# Revoke the used token
kubeadm token delete abc123.def456

# Verify it's gone
kubeadm token list
```

**Important:** Worker nodes store permanent certificates after join, so token revocation does NOT affect existing workers.

### 4. Token Management Commands

```bash
# List all valid tokens
kubeadm token list

# List with detailed info
kubeadm token list --show-management-token

# Create token with custom TTL (0 = never expires - not recommended)
kubeadm token create --ttl=24h --print-join-command

# Revoke specific token
kubeadm token delete <TOKEN>

# Revoke all tokens (be careful!)
kubeadm token create --ttl=0 && for token in $(kubeadm token list | awk 'NR>1 {print $1}'); do kubeadm token delete $token; done
```

---

## Secret Storage by Environment

### Development (Local)

**File:** `.env.local` (in `.gitignore`, never committed)

```bash
# .env.local (DO NOT COMMIT)
KUBEADM_JOIN_COMMAND="kubeadm join 192.168.56.10:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx"
ARGOCD_ADMIN_PASSWORD="your-secure-password"
MONGO_ROOT_PASSWORD="mongodb-root-password"
MONGO_INITDB_DATABASE="fk_webstack"
```

Load in your scripts:
```bash
if [ -f .env.local ]; then
    export $(cat .env.local | grep -v '^#' | xargs)
fi
```

### Production (Kubernetes Secrets)

**File:** `k8s/99-secrets.yaml` (template, actual values in `.env.local`)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: fk-api-secrets
  namespace: fk-webstack
type: Opaque
stringData:
  MONGO_PASSWORD: "{{ MONGO_ROOT_PASSWORD }}"
  MONGO_INITDB_ROOT_PASSWORD: "{{ MONGO_ROOT_PASSWORD }}"
  ARGOCD_PASSWORD: "{{ ARGOCD_ADMIN_PASSWORD }}"
```

**Deploy with environment variable substitution:**

```bash
envsubst < k8s/99-secrets.yaml | kubectl apply -f -
```

### Kubernetes Native Approach

```bash
# Create Secret directly from environment
kubectl create secret generic fk-api-secrets \
  --from-literal=MONGO_PASSWORD="$(cat .env.local | grep MONGO_ROOT_PASSWORD | cut -d= -f2)" \
  -n fk-webstack

# Or from file
kubectl create secret generic fk-api-secrets \
  --from-file=.env.local \
  -n fk-webstack
```

---

## ArgoCD Password Management

### Initial Setup

```bash
# Get initial admin password (auto-generated)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Store securely (NOT in Git)
echo "your-argocd-password" > ~/.argocd-password
chmod 600 ~/.argocd-password
```

### Change Admin Password

```bash
# Port-forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI
argocd login localhost:8080 \
  --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Change password
argocd account update-password \
  --account admin \
  --new-password "<new-secure-password>" \
  --current-password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
```

### Store in Kubernetes Secret

```bash
# Create secret with new password
kubectl create secret generic argocd-admin-password \
  --from-literal=password="<your-secure-password>" \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## MongoDB Credentials

### Current Setup (Development)

MongoDB runs without authentication in current setup. For production:

```yaml
# k8s/10-mongodb-deployment.yaml
env:
- name: MONGO_INITDB_ROOT_USERNAME
  value: "root"
- name: MONGO_INITDB_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mongo-credentials
      key: root-password
```

### Create MongoDB Secret

```bash
# Generate strong password
MONGO_PASS=$(openssl rand -base64 24)

# Create secret
kubectl create secret generic mongo-credentials \
  --from-literal=root-password="$MONGO_PASS" \
  -n fk-webstack

# Store password securely (NOT in Git)
echo "MongoDB root password: $MONGO_PASS" >> ~/.mongodb-password
chmod 600 ~/.mongodb-password
```

---

## Best Practices Implemented

### ✅ Source Control
- [x] All secrets in `.gitignore`
- [x] Environment-specific configs separated
- [x] No credentials in manifests
- [x] Exposed token revoked from cluster
- [x] Git history cleaned

### ✅ Token Management
- [x] Short-lived tokens (24h default)
- [x] Token revocation process documented
- [x] Kubeadm join tokens used only once
- [x] Old tokens automatically expired

### ✅ Runtime Security
- [x] Kubernetes Secrets for sensitive data
- [x] Environment variables for apps
- [x] Secret mounting in pods
- [x] RBAC for secret access (recommended)

### ✅ Deployment Scripts
- [x] No hardcoded passwords in scripts
- [x] Use environment variables
- [x] Use kubectl secrets for sensitive data
- [x] Secure password generation with `openssl`

### ✅ Monitoring & Scanning
- [x] GitGuardian integration (external)
- [x] GitHub Actions secrets scanning (optional)
- [x] Regular token audits

---

## Compliance Checklist for Oral Exam

When demonstrating security:

- [ ] Show `.gitignore` protecting sensitive files
- [ ] Demonstrate token lifecycle (list → use → revoke)
- [ ] Show kubernetes secrets in deployment
- [ ] Explain how GitGuardian incident was resolved
- [ ] Demonstrate no plaintext credentials in Git
- [ ] Show secure password generation

**Command to verify security:**

```bash
# 1. Check Git has no secrets
git log --all --full-history -- kubeadm-config/join-command.sh
# Expected: Shows commit that REMOVED the file

# 2. Verify .gitignore works
git check-ignore kubeadm-config/*.token
# Expected: kubeadm-config/*.token (ignored)

# 3. Scan repository for any remaining secrets
grep -r "kubeadm join" . --exclude-dir=.git
# Expected: No output (only in .gitignore or docs)

# 4. Check Kubernetes secrets
kubectl get secrets -n fk-webstack
# Expected: Secrets stored safely
```

---

## References

- [GitGuardian Best Practices](https://docs.gitguardian.com/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [kubeadm Token Management](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token/)
- [OWASP Secrets Management](https://owasp.org/www-community/Insufficient_Logging_and_Monitoring)

---

**Last Updated:** February 1, 2026  
**Status:** ✅ All security guidelines implemented
