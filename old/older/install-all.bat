@echo off
cd /d C:\Users\Admin\Desktop\WebserverLinux

echo Installing cert-manager...
vagrant ssh fk-control -c "bash /vagrant/install-cert-manager.sh"
timeout /t 10

echo Installing Prometheus...
vagrant ssh fk-control -c "bash /vagrant/install-prometheus.sh"
timeout /t 10

echo Installing ArgoCD...
vagrant ssh fk-control -c "bash /vagrant/install-argocd.sh"
timeout /t 10

echo.
echo ===== VERIFICATION =====
vagrant ssh fk-control -c "kubectl get ns"
echo.
vagrant ssh fk-control -c "kubectl get pods -n fk-webstack"
echo.
vagrant ssh fk-control -c "kubectl get pods -n cert-manager"
echo.

echo All installations complete!
echo.
echo Next steps:
echo 1. In a new terminal, run: vagrant ssh fk-control -c "kubectl port-forward svc/fk-api -n fk-webstack 8000:8000"
echo 2. In another terminal, test: Invoke-RestMethod http://localhost:8000/api/name
echo.
pause
