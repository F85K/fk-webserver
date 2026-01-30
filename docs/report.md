# FK Webstack – Documentatie

## 1. Overzicht (schema)

```
[Browser]
   |
   | HTTPS (Ingress + cert-manager)
   v
[Ingress Controller]
   |-- /       --> [fk-frontend Service] --> [fk-frontend Pod (lighttpd)]
   |-- /api    --> [fk-api Service]      --> [fk-api Pods (FastAPI)]
                                           |
                                           v
                                     [fk-mongodb Service] --> [MongoDB Pod]
```

## 2. Doel van de opdracht
- **Frontend**: lighttpd toont een HTML/JS pagina.
- **API**: FastAPI geeft naam uit MongoDB + container/pod ID.
- **Database**: MongoDB bewaart de naam.
- **Extra punten**: HTTPS (cert-manager), extra worker node, HPA, healthchecks, Prometheus, ArgoCD GitOps.

## 3. Frontend (lighttpd)
**Bestand:** frontend/index.html
- Toont de naam uit de DB en de container ID.
- Detecteert layout wissel (mobiel/desktop) en toont dit live.
- Refresh knop + automatische update om naamswijziging te zien.

**Bestand:** frontend/Dockerfile
- Gebruikt lighttpd image.
- Kopieert index.html naar webroot.

## 4. API (FastAPI)
**Bestand:** api/app/main.py
- `/api/name` haalt de naam uit MongoDB.
- `/api/container-id` toont hostname (pod/container id).
- `/health` voor liveness/readiness probes.
- CORS aan zodat de frontend kan praten met de API.

**Bestand:** api/requirements.txt
- fastapi, uvicorn, pymongo.

**Bestand:** api/Dockerfile
- Installeert dependencies.
- Start uvicorn op poort 8000.

## 5. Database (MongoDB)
**Bestand:** db/init/init.js
- Seed script om `Frank Koch` in de DB te zetten.

## 6. Docker Compose (basispunten)
**Bestand:** docker-compose.yaml
- 3 containers: fk-mongo, fk-api, fk-frontend.
- Je kan lokaal testen via:
  - Frontend: http://localhost:8080
  - API: http://localhost:8000/api/name

## 7. Kubernetes (minikube)
**Namespace:** k8s/00-namespace.yaml
- Isolatie voor het project.

**MongoDB:** k8s/10, 11, 12, 13
- Deployment + Service.
- ConfigMap + Job init om de naam te zetten.

**API:** k8s/20, 21, 22
- Deployment met 2 replicas.
- Liveness/Readiness probes.
- HPA voor autoscaling.

**Frontend:** k8s/30, 31
- Lighttpd deployment + service.

**Ingress + HTTPS:** k8s/40, 50
- Ingress met path routing `/` en `/api`.
- Cert-manager ClusterIssuer voor Let’s Encrypt.
- **Belangrijk:** je hebt een publieke domeinnaam nodig om een geldig certificaat te krijgen.

**ArgoCD GitOps:** k8s/60
- Application file met placeholders voor repo URL.

## 8. Installatie & Deploy stappen (minikube)

Kort samengevat: start minikube, bouw de images, deploy alle k8s YAML’s en test. Voor HTTPS en GitOps moet je nog een domein en repo invullen.

### 8.1 Start minikube + extra worker
1. Start cluster
2. Voeg node toe
3. Controleer nodes

> Gebruik: `minikube node add` om extra worker te krijgen.

### 8.2 Bouw images in minikube
- Build fk-frontend en fk-api images zodat Kubernetes ze kan gebruiken.

### 8.3 Deploy manifests
- Apply namespace
- Apply mongo + init job
- Apply api + frontend
- Apply ingress

### 8.4 Ingress controller
- Installeer NGINX Ingress addon voor minikube.

### 8.5 HTTPS met cert-manager
- Installeer cert-manager in cluster.
- Pas domain + email aan in k8s/40 en k8s/50.

### 8.6 Prometheus monitoring
- Installeer kube-prometheus-stack via Helm.
- Toon resource usage via Grafana.

### 8.7 ArgoCD GitOps
- Installeer ArgoCD via Helm.
- Pas repoURL in k8s/60-argocd-application.yaml aan.
- ArgoCD synct automatisch je app.

## 9. Bewijs voor extra punten
- **Extra worker node**: `kubectl get nodes`.
- **HPA**: `kubectl get hpa -n fk-webstack`.
- **Spread pods**: `kubectl get pods -o wide -n fk-webstack`.
- **HTTPS**: browser toont slotje (bij geldig domein).
- **Prometheus**: Grafana dashboard screenshot.
- **ArgoCD**: Application sync status screenshot.

## 10. Wat moet jij nog invullen?
- Publieke domeinnaam (voor HTTPS).
- Git repo URL (voor ArgoCD/GitOps).

---

> Deze documentatie kan je omzetten naar PDF via Markdown → PDF export (bijv. in VS Code).
