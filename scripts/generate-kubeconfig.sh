#!/bin/bash

set -e

# Generate kubeconfig for a given namespace and github repository
# Usage: ./generate-kubeconfig.sh <namespace> [github-repo] [--output-dir <dir>] [--keep-temp] [--minimal]
#
# By default, creates 3 namespaces: <namespace>, <namespace>-dev, <namespace>-pr
# With --minimal, only creates the single specified namespace

NAMESPACE=""
GITHUB_REPO=""
OUTPUT_DIR=""
KEEP_TEMP=false
MINIMAL=false
SERVICE_ACCOUNT_NAME="github-deployer"
CLUSTER_NAME=$(kubectl config current-context)
SECRET_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --keep-temp)
      KEEP_TEMP=true
      shift
      ;;
    --minimal)
      MINIMAL=true
      shift
      ;;
    *)
      if [ -z "$NAMESPACE" ]; then
        NAMESPACE="$1"
      elif [ -z "$GITHUB_REPO" ]; then
        GITHUB_REPO="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$NAMESPACE" ]; then
  echo "Error: Namespace is required." >&2
  echo "Usage: $0 <namespace> [github-repo] [--output-dir <dir>] [--keep-temp] [--minimal]" >&2
  exit 1
fi

# Define namespaces based on mode
if [ "$MINIMAL" = true ]; then
  NAMESPACES=("$NAMESPACE")
  echo "Running in minimal mode: single namespace only"
else
  NAMESPACES=("$NAMESPACE" "${NAMESPACE}-dev" "${NAMESPACE}-pr")
  echo "Running in full mode: namespace + -dev + -pr variants"
fi

FLUX_REGISTRY_NS="flux-registry"

# Create all namespaces if they don't exist
echo "Creating namespaces..."
for NS in "${NAMESPACES[@]}"; do
  kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"
  echo "  ✓ Namespace $NS ready"
done

# Ensure flux-registry namespace exists (shared across apps)
kubectl get namespace "$FLUX_REGISTRY_NS" >/dev/null 2>&1 || kubectl create namespace "$FLUX_REGISTRY_NS"
echo "  ✓ Namespace $FLUX_REGISTRY_NS ready"

# Create service account in the main namespace only
echo "Creating service account in namespace $NAMESPACE..."
kubectl create serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create a single ClusterRole that grants admin access to resources in the specific namespaces
echo "Creating ClusterRole with namespace-scoped admin permissions..."

# Build the resourceNames array properly
RESOURCE_NAMES=""
for NS in "${NAMESPACES[@]}"; do
  if [ -z "$RESOURCE_NAMES" ]; then
    RESOURCE_NAMES="[\"$NS\""
  else
    RESOURCE_NAMES="$RESOURCE_NAMES, \"$NS\""
  fi
done
RESOURCE_NAMES="$RESOURCE_NAMES]"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-admin-$NAMESPACE
rules:
# Full admin permissions for all resources in the specified namespaces
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
# Namespace management permissions (for --create-namespace flag in Helm)
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
  resourceNames: $RESOURCE_NAMES
# CRD read permissions
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list"]
# Permissions for flux-registry namespace (read HelmRepository sources and trigger reconciliation)
- apiGroups: ["source.toolkit.fluxcd.io"]
  resources: ["helmrepositories", "helmrepositories/status"]
  verbs: ["get", "list", "watch", "patch"]
EOF

# Create RoleBindings in each namespace pointing to the single ClusterRole
echo "Creating role bindings in all namespaces..."
for NS in "${NAMESPACES[@]}"; do
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-deployer-admin-binding
  namespace: $NS
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: app-admin-$NAMESPACE
  apiGroup: rbac.authorization.k8s.io
EOF
  echo "  ✓ RoleBinding created in $NS"
done

# Create RoleBinding in flux-registry namespace for HelmRepository access
# Use a unique name per namespace since roleRef references namespace-specific ClusterRole
echo "Creating role binding in flux-registry namespace..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-deployer-${NAMESPACE}
  namespace: $FLUX_REGISTRY_NS
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: app-admin-$NAMESPACE
  apiGroup: rbac.authorization.k8s.io
EOF
echo "  ✓ RoleBinding created in $FLUX_REGISTRY_NS"

# Get the service account token secret name
SECRET_NAME=$(kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE -o jsonpath='{.secrets[0].name}')

if [ -z "$SECRET_NAME" ]; then
  # For Kubernetes 1.24+, create a token manually
  echo "Creating token for service account..."
  SECRET_NAME="${SERVICE_ACCOUNT_NAME}-token"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT_NAME}
type: kubernetes.io/service-account-token
EOF
fi

# Wait for the secret to be properly initialized
echo "Waiting for secret to be initialized..."
sleep 3

# Get service account details
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
CA_CERT=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 --decode)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Create or use specified output directory
if [ -n "$OUTPUT_DIR" ]; then
  TEMP_DIR="$OUTPUT_DIR"
  mkdir -p "$TEMP_DIR"
else
  TEMP_DIR=$(mktemp -d)
fi

CA_CERT_FILE="${TEMP_DIR}/ca.crt"
KUBE_CONFIG_FILE="${TEMP_DIR}/kubeconfig.yaml"

# Write the CA certificate to a file
echo "$CA_CERT" > "$CA_CERT_FILE"

# Generate the kubeconfig
cat > "$KUBE_CONFIG_FILE" <<EOF
apiVersion: v1
kind: Config
preferences: {}

clusters:
- cluster:
    certificate-authority-data: $(cat "$CA_CERT_FILE" | base64 | tr -d '\n')
    server: $SERVER
  name: $CLUSTER_NAME

contexts:
- context:
    cluster: $CLUSTER_NAME
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT_NAME
  name: $SERVICE_ACCOUNT_NAME@$CLUSTER_NAME

current-context: $SERVICE_ACCOUNT_NAME@$CLUSTER_NAME

users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: $TOKEN
EOF

echo "======================================================"
echo "Kubeconfig file created at: $KUBE_CONFIG_FILE"
echo "Content of the kubeconfig (to copy to GitHub Secret):"
echo "======================================================"
cat "$KUBE_CONFIG_FILE"
echo "======================================================"

if [ -n "$GITHUB_REPO" ]; then
  echo "Instructions:"
  echo "1. Copy the above kubeconfig content"
  echo "2. Go to your GitHub repository: https://github.com/$GITHUB_REPO"
  echo "3. Navigate to Settings > Secrets > Actions"
  echo "4. Create a new repository secret named 'KUBE_CONFIG'"
  echo "5. Paste the content and save"
fi

echo ""
echo "Service account has been granted full admin access to the following namespaces:"
for NS in "${NAMESPACES[@]}"; do
  echo "  - $NS"
done
echo "  - $FLUX_REGISTRY_NS (read/reconcile HelmRepository sources)"

echo ""
echo "To trigger immediate Flux reconciliation from GitHub Actions in any of the namespaces:"
echo "kubectl annotate helmrelease/<release-name> reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\" -n <namespace> --overwrite"

if [ -z "$OUTPUT_DIR" ] && [ "$KEEP_TEMP" = false ]; then
  echo ""
  echo "Removing temporary directory..."
  rm -rf "$TEMP_DIR"
else
  echo ""
  echo "Kubeconfig file preserved at: $KUBE_CONFIG_FILE"
fi

echo "Setup complete!"
