Test: 905
#!/usr/bin/env bash
set -euo pipefail

# delete-unattached-aks-disks.sh
# Deletes Azure managed disks by name IF they are unattached (managedBy == null).
# Safe-by-default: DRY_RUN=1 unless explicitly disabled.

usage() {
  cat <<'EOF'
Usage:
  delete-unattached-aks-disks.sh -f <list-file> [-g <resource-group>] [--search-all-rgs] [--execute]

Options:
  -f, --file            File with disk names (one per line). Lines starting with # are ignored. (required)
  -g, --resource-group  Resource group to try first. If omitted, only subscription-wide search is used.
      --search-all-rgs  If disk is not found in the provided RG, search across the whole subscription. (default: on if -g set)
      --execute         Actually delete disks. If not set -> DRY RUN (prints what would be deleted).
  -h, --help            Show this help.

Examples:
  # Dry run (default) — look in RG first, then search entire subscription
  ./delete-unattached-aks-disks.sh -f pvc-list.txt -g MC_example_rg_example_aks --search-all-rgs

  # Execute deletion
  ./delete-unattached-aks-disks.sh -f pvc-list.txt -g MC_example_rg_example_aks --search-all-rgs --execute

  # No RG known — search across subscription only
  ./delete-unattached-aks-disks.sh -f pvc-list.txt --search-all-rgs --execute

Notes:
  - Disks are deleted ONLY if managedBy is empty (unattached).
  - You must be logged into Azure CLI and have permissions to read/delete disks.
EOF
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }

LIST_FILE=""
RG=""
SEARCH_ALL_RGS="0"
EXECUTE="0"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file) LIST_FILE="${2:-}"; shift 2 ;;
    -g|--resource-group) RG="${2:-}"; shift 2 ;;
    --search-all-rgs) SEARCH_ALL_RGS="1"; shift ;;
    --execute) EXECUTE="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# Defaults: if RG provided but search flag not specified, enable search-all for convenience
if [[ -n "$RG" && "$SEARCH_ALL_RGS" == "0" ]]; then
  SEARCH_ALL_RGS="1"
fi

# --- Validate ---
if [[ -z "$LIST_FILE" ]]; then
  echo "Error: --file is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$LIST_FILE" ]]; then
  echo "Error: list file not found: $LIST_FILE" >&2
  exit 1
fi

need az

# Ensure user is logged in
if ! az account show >/dev/null 2>&1; then
  echo "Error: Azure CLI not logged in. Run: az login" >&2
  exit 1
fi

# --- Info ---
DRY_RUN="1"
if [[ "$EXECUTE" == "1" ]]; then DRY_RUN="0"; fi

echo "List file      : $LIST_FILE"
echo "Resource group : ${RG:-<none>}"
echo "Search all RGs : $SEARCH_ALL_RGS"
echo "Mode           : $([[ "$DRY_RUN" == "1" ]] && echo "DRY RUN" || echo "EXECUTE")"
echo

# --- Helpers ---
find_disk_rg() {
  local name="$1"
  # returns resource group or empty
  az disk list --query "[?name=='$name'].resourceGroup" -o tsv 2>/dev/null | head -n1 || true
}

disk_exists_in_rg() {
  local rg="$1" name="$2"
  az disk show -g "$rg" -n "$name" --query "name" -o tsv >/dev/null 2>&1
}

disk_managed_by() {
  local rg="$1" name="$2"
  az disk show -g "$rg" -n "$name" --query "managedBy" -o tsv 2>/dev/null || true
}

delete_disk() {
  local rg="$1" name="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[DRY] az disk delete -g \"$rg\" -n \"$name\" --yes"
  else
    echo "[DEL] $name (rg:$rg)"
    az disk delete -g "$rg" -n "$name" --yes --only-show-errors
  fi
}

# --- Main loop ---
while IFS= read -r NAME; do
  # skip empty lines and comments
  [[ -z "${NAME// }" || "${NAME#\#}" != "$NAME" ]] && continue

  CURRENT_RG=""
  FOUND="0"

  # 1) Try provided RG first (if any)
  if [[ -n "$RG" ]]; then
    if disk_exists_in_rg "$RG" "$NAME"; then
      CURRENT_RG="$RG"
      FOUND="1"
    fi
  fi

  # 2) Search subscription for disk's RG (optional)
  if [[ "$FOUND" != "1" && "$SEARCH_ALL_RGS" == "1" ]]; then
    POSS_RG="$(find_disk_rg "$NAME")"
    if [[ -n "$POSS_RG" ]]; then
      CURRENT_RG="$POSS_RG"
      FOUND="1"
    fi
  fi

  if [[ "$FOUND" != "1" || -z "$CURRENT_RG" ]]; then
    echo "[SKIP] $NAME — not found"
    continue
  fi

  # Ensure unattached
  MANAGED_BY="$(disk_managed_by "$CURRENT_RG" "$NAME")"
  if [[ -n "$MANAGED_BY" && "$MANAGED_BY" != "null" ]]; then
    echo "[SKIP] $NAME (rg:$CURRENT_RG) — ATTACHED to: $MANAGED_BY"
    continue
  fi

  delete_disk "$CURRENT_RG" "$NAME"
done < "$LIST_FILE"

echo
echo "Done."
