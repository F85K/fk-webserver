#!/bin/bash
set -e

echo "==== Installing Prometheus ===="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install fk-monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set alertmanager.enabled=false

echo "==== Waiting for Prometheus to be ready ===="
sleep 15
kubectl get pods -n monitoring

echo "✅ Prometheus installed!"
