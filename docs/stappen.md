# FK Webstack – korte stappen (niet complex)

Dit is een eenvoudige lijst met stappen. Elke stap heeft een korte uitleg.

## Wat moet jij nog invullen?
- **Domeinnaam** in [k8s/40-ingress.yaml](k8s/40-ingress.yaml)
- **E‑mail** in [k8s/50-cert-issuer.yaml](k8s/50-cert-issuer.yaml)
- **Git repo URL** in [k8s/60-argocd-application.yaml](k8s/60-argocd-application.yaml)

## 1) Minikube starten (met extra worker node)
- **Waarom?** Dit is je lokale Kubernetes cluster.
- Start het cluster:
  minikube start
- Voeg een extra node toe:
  minikube node add
- Controleer de nodes:
  kubectl get nodes

## 2) Ingress controller aanzetten
- **Waarom?** Ingress zorgt voor toegang tot frontend en API.
- In minikube:
  minikube addons enable ingress

## 3) Images bouwen in minikube
- **Waarom?** Kubernetes moet je eigen images kunnen gebruiken.
- Stel Docker in op minikube:
  minikube -p minikube docker-env
- Build de API:
  docker build -t fk-api:latest ./api
- Build de frontend:
  docker build -t fk-frontend:latest ./frontend

## 4) Kubernetes resources deployen
- **Waarom?** Dit zet alles live in het cluster.
- Namespace:
  kubectl apply -f k8s/00-namespace.yaml
- Mongo + init job:
  kubectl apply -f k8s/10-mongodb-deployment.yaml
  kubectl apply -f k8s/11-mongodb-service.yaml
  kubectl apply -f k8s/12-mongodb-init-configmap.yaml
  kubectl apply -f k8s/13-mongodb-init-job.yaml
- API + HPA:
  kubectl apply -f k8s/20-api-deployment.yaml
  kubectl apply -f k8s/21-api-service.yaml
  kubectl apply -f k8s/22-api-hpa.yaml
- Frontend:
  kubectl apply -f k8s/30-frontend-deployment.yaml
  kubectl apply -f k8s/31-frontend-service.yaml
- Ingress:
  kubectl apply -f k8s/40-ingress.yaml

## 5) Cert-manager (HTTPS)
- **Waarom?** Voor een geldig SSL certificaat van Let's Encrypt.
- Installeer cert-manager:
  ```powershell
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
  ```
- Wacht tot alle cert-manager pods draaien (dit kan 1-2 minuten duren):
  ```powershell
  kubectl get pods --namespace cert-manager
  ```
  Je zou 3 pods in "Running" status moeten zien:
  - cert-manager
  - cert-manager-cainjector
  - cert-manager-webhook

- Pas e-mail aan in [k8s/50-cert-issuer.yaml](k8s/50-cert-issuer.yaml):
  ```yaml
  email: jouw-email@example.com
  ```
  **Belangrijk:** Let's Encrypt gebruikt dit e-mailadres om je te waarschuwen over verlopende certificaten en belangrijke mededelingen.

- Apply ClusterIssuer:
  ```powershell
  kubectl apply -f k8s/50-cert-issuer.yaml
  ```

- Controleer of de issuer correct is geregistreerd:
  ```powershell
  kubectl get clusterissuer
  kubectl describe clusterissuer fk-letsencrypt
  ```
  Status moet "Ready: True" zijn en je zou "ACMEAccountRegistered" moeten zien.

- Pas domein aan in [k8s/40-ingress.yaml](k8s/40-ingress.yaml) en voeg TLS configuratie toe met de annotation:
  ```yaml
  annotations:
    cert-manager.io/cluster-issuer: "fk-letsencrypt"
  ```

## 6) Prometheus (monitoring)
- **Waarom?** Om resources te zien (CPU/RAM).
- Installeer met Helm (kort):
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install fk-monitoring prometheus-community/kube-prometheus-stack

## 7) ArgoCD (GitOps)
- **Waarom?** Auto-deploy uit je Git repo.
- Installeer ArgoCD met Helm:
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm install argocd argo/argo-cd --namespace argocd --create-namespace
- Pas repo URL aan in:
  [k8s/60-argocd-application.yaml](k8s/60-argocd-application.yaml)
- Apply ArgoCD app:
  kubectl apply -f k8s/60-argocd-application.yaml

## 8) Testen
- Check pods:
  kubectl get pods -n fk-webstack
- Check HPA:
  kubectl get hpa -n fk-webstack
- Check nodes (extra worker):
  kubectl get nodes

---

Tip: Als iets mislukt, kijk naar logs met:
- kubectl logs <pod> -n fk-webstack
