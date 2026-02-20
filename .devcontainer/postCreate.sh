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

echo "Install Kyverno..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace --wait --version 3.7.0

echo "Install Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --wait

echo "Install ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --version 9.4.0 --namespace argocd --create-namespace --wait

echo "Create Backstage RBAC..."
kubectl apply -f backstage-rbac/namespace.yaml
kubectl apply -f backstage-rbac/serviceAccount.yaml
kubectl apply -f backstage-rbac/secret.yaml
kubectl apply -f backstage-rbac/clusterRoleBinding.yaml

echo "Install Metrics Server..."
kubectl apply -k metrics-server/

echo "Detect environment..."
if [ "$CODESPACES" = "true" ]; then
  echo "Environment: GitHub Codespaces"
  GATEWAY_HOST="${CODESPACE_NAME}-443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
  echo "Environment: Local Dev Container"
  GATEWAY_HOST="localhost"
fi

echo "Install Envoy Gateway..."
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.3.0 \
  -n envoy-gateway-system --create-namespace --wait

echo "Create Gateway TLS Certificate..."
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gateway-tls
  namespace: envoy-gateway-system
spec:
  secretName: gateway-tls
  issuerRef:
    name: my-ca-issuer
    kind: ClusterIssuer
  dnsNames:
  - localhost
  - "*.localhost"
  - "${GATEWAY_HOST}"
EOF

kubectl apply -f envoy-gateway/gateway.yaml

kubectl -n envoy-gateway-system wait --for=condition=Accepted gateway/backstage-gateway --timeout=5m

echo "Patch Envoy Gateway NodePorts for KinD..."
until kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=backstage-gateway -o jsonpath='{.items[0].spec.ports}' 2>/dev/null | grep -q "443"; do
  sleep 2
done
EG_SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=backstage-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl -n envoy-gateway-system patch svc "$EG_SVC" --type='json' -p='[
  {"op":"replace","path":"/spec/ports/0/nodePort","value":80},
  {"op":"replace","path":"/spec/ports/1/nodePort","value":443}
]'

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
