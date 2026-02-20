#!/bin/bash
set -e
echo "Setting up Backstage environment..."


export VIRTUAL_ENV=$HOME/venv
python3 -m venv $VIRTUAL_ENV
export PATH="$VIRTUAL_ENV/bin:$PATH"
python3 -m pip install mkdocs-techdocs-core


echo "Setting up Backstage Demo environment..."
if kind get clusters | grep -qx backstage-demo; then
  echo "Kind cluster backstage-demo already exists. Skipping create."
else
  kind create cluster --name backstage-demo --config kind/config.yaml
fi

echo "Install Cert Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
kubectl -n cert-manager rollout status deploy/cert-manager --timeout=10m
kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=10m
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=10m

echo "Create Cluster Issuer..."
kubectl apply -f cert-manager/ca-issuer.yaml

echo ""
echo "╔════════════════════════════════════════════════════════╗ "
echo "║  Setup Complete! Ready to launch Backstage!            ║ "
echo "╠════════════════════════════════════════════════════════╣ "
echo "║                                                        ║ "
echo "║  Open a new terminal and run:                          ║ "
echo "║                                                        ║ "
echo "║       yarn start                                       ║ "
echo "║                                                        ║ "
echo "║  Then access Backstage at:                             ║ "
echo "║                                                        ║ "
echo "║       http://localhost:3000                            ║ "
echo "║                                                        ║ "
echo "║  You might need to refresh the page once backend       ║ "
echo "║  is ready.                                             ║ "
echo "║                                                        ║ "
echo "║  Happy coding!                                         ║ "
echo "╚════════════════════════════════════════════════════════╝ "
echo ""
