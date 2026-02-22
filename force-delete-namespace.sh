#!/bin/bash
set -e

NS=cert-manager

kubectl get namespace "${NS}" -o json > /tmp/ns.json
python3 /vagrant/clear-namespace-finalizers.py
kubectl replace --raw /api/v1/namespaces/${NS}/finalize -f /tmp/ns-fixed.json
sleep 5
kubectl get ns | grep "${NS}" || echo "cert-manager namespace removed"
