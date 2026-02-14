Test: 905
#!/usr/bin/env bash
set -euo pipefail

# Delete Kubernetes namespaces that appear "empty"
# DRY_RUN=1 -> print actions only

DRY_RUN="${DRY_RUN:-1}"
TARGET_NS="${1:-}"   # optional: pass a namespace name, otherwise scan all

# Namespaces to never touch
PROTECTED_REGEX='^(kube-system|kube-public|kube-node-lease|default|gatekeeper-system|cert-manager|ingress-nginx)$'

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need kubectl

# basic cluster access check
kubectl version --client >/dev/null 2>&1 || true
kubectl auth can-i get namespaces >/dev/null 2>&1 || { echo "kubectl access check failed" >&2; exit 1; }

list_namespaces() {
  if [[ -n "$TARGET_NS" ]]; then
    echo "$TARGET_NS"
  else
    kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
  fi
}

has_any_resources() {
  local ns="$1"

  # Count common workload & networking/storage objects.
  # We ignore Events and Secrets/ConfigMaps by default (often exist even in "empty" ns).
  local count
  count="$(
    kubectl -n "$ns" get deploy,sts,ds,rs,job,cronjob,svc,ing,pvc,pod \
      --no-headers 2>/dev/null | wc -l | tr -d ' '
  )"

  [[ "${count:-0}" -gt 0 ]]
}

has_active_pods() {
  local ns="$1"
  # Consider Running or Pending pods as "active"
  local active
  active="$(
    kubectl -n "$ns" get pods --no-headers 2>/dev/null \
      | awk '$3=="Running" || $3=="Pending" {c++} END{print c+0}'
  )"
  [[ "${active:-0}" -gt 0 ]]
}

echo "Dry run: $DRY_RUN (set DRY_RUN=0 to delete)"
echo

while IFS= read -r ns; do
  [[ -z "$ns" ]] && continue

  if [[ "$ns" =~ $PROTECTED_REGEX ]]; then
    echo "[SKIP] $ns — protected"
    continue
  fi

  # Skip terminating namespaces
  phase="$(kubectl get ns "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
  if [[ "$phase" == "Terminating" ]]; then
    echo "[SKIP] $ns — terminating"
    continue
  fi

  if has_any_resources "$ns"; then
    echo "[KEEP] $ns — has resources"
    continue
  fi

  # extra safety: if any active pods, keep
  if has_active_pods "$ns"; then
    echo "[KEEP] $ns — has active pods"
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY] kubectl delete ns \"$ns\""
  else
    echo "[DEL] $ns"
    kubectl delete ns "$ns"
  fi
done < <(list_namespaces)

echo
echo "Done."
