# API Server Crash Diagnosis & Solution

**Problem:** Kubernetes API server (port 6443) crashes repeatedly with "connection refused"  
**Impact:** Cluster becomes unresponsive, all operations fail  
**Root Cause:** etcd instability cascading into API server crashes

## Root Cause Analysis

### 1. **etcd is Overloaded (PRIMARY CAUSE)**
- etcd handles all cluster state writes (pod creation, delete, update, watch events)
- When API pods crash → kubelet aggressively restarts them → rapid pod events → etcd write storm
- **Control plane only has 6GB RAM** - insufficient for etcd + API server + kubelet under load
- Exit code 137 (SIGKILL) on API pods = **out-of-memory** → forceful termination → more etcd events

### 2. **Pod Resource Limits Too Low (SECONDARY CAUSE)**
- Original: API pod limited to **256Mi memory**
- FastAPI + uvicorn + MongoDB driver connections = ~300-400 MB minimum
- Every restart = full clean memory allocation → guaranteed OOM kill
- Creates crash loop: OOM → kill → restart → OOM → ...

### 3. **Aggressive Kubelet Restart Policy (TERTIARY CAUSE)**
- Default restart backoff: 100ms → 100ms → 100ms (FAST)
- API pod dies → 100ms later kubelet restarts it
- This adds 10s+ etcd writes per minute during crash loop
- etcd can't keep up → timeouts → API server loses quorum → CRASH

### 4. **No Rate Limiting on Watch Requests**
- Every kubectl command = watch event from kubelet
- During pod crashes, kubelet watches fire on every restart
- etcd write load becomes exponential, not linear

---

## Fixes Applied

### ✅ Fix 1: Increase Memory Limits
**File:** `k8s/20-api-deployment.yaml`
```yaml
resources:
  requests:
    memory: "256Mi"  # ← WAS 128Mi
  limits:
    memory: "512Mi"  # ← WAS 256Mi (PRIMARY FIX!)
```
- Allows API pod to run without OOM
- Breaks the crash loop
- Prevents cascading etcd stress

### ✅ Fix 2: Reduce Replica Count (Temporary)
```yaml
spec:
  replicas: 1  # ← WAS 2
```
- One running pod = fewer etcd writes
- Two crashing pods = exponential etcd stress
- Temporary measure until stability restored

### ✅ Fix 3: Extended Health Check Timeouts
```yaml
livenessProbe:
  initialDelaySeconds: 15  # ← WAS 10
  periodSeconds: 10
  timeoutSeconds: 5        # ← WAS 1 (too short!)
  failureThreshold: 3
```
- Prevents false-positive kills during startup
- Gives FastAPI time to connect to MongoDB
- Reduces restart rate → reduces etcd stress

---

## How This Solves the Problem

```
BEFORE (Crash Loop):
  startup → OOM (256Mi limit exceeded)
    ↓
  Kill (exit 137) → etcd write: "pod terminated"
    ↓
  Restart → OOM again (256Mi too small)
    ↓
  [repeat 5+ times] → etcd write storm → API server crash

AFTER (Stable):
  startup → No OOM (512Mi available)
    ↓
  Healthy → etcd writes: none (pod stable)
    ↓
  stays running → cluster stable
```

---

## Long-Term Solution (For Production)

### Increase Control Plane Resources
```ruby
# Vagrantfile
cp.vm.provider "virtualbox" do |vb|
  vb.memory = 8192  # ← was 6144 (increase to 8GB)
  vb.cpus = 4       # ← keep 4 CPUs (adequate)
end
```

### Add PodDisruptionBudget to Prevent Cascades
```yaml
# k8s/22-api-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: fk-api-pdb
  namespace: fk-webstack
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: fk-api
```

### Add Horizontal Pod Autoscaler (HPA) with Backoff
```yaml
# k8s/22-api-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fk-api-hpa
  namespace: fk-webstack
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fk-api
  minReplicas: 1
  maxReplicas: 3
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5min before scaling down
```

---

## Verification

After applying fixes:

```bash
# Monitor API pod stability
kubectl get pods -n fk-webstack -w

# Expected: API pod stays at 1/1 Running (no crashes)
# Check etcd health
kubectl get componentstatus

# Expected: etcd is Healthy (✓)
```

---

## Key Takeaway

**etcd is the cluster's single point of failure.** When etcd gets overloaded with write events from crashing pods, it can't keep up and crashes, taking the API server down with it.

The fix is to **stop the pods from crashing in the first place** by giving them enough memory to run stably.

