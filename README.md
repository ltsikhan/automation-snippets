# Automation Snippets (AKS / Kubernetes)

Small, safe-by-default scripts for day-to-day Azure/AKS/Kubernetes operations.

## Scripts

### 1) Delete unattached Azure managed disks (AKS PVC leftovers)
Path: `scripts/delete-unattached-aks-disks/`

- Deletes disks **only if unattached** (`managedBy` is empty)
- Dry run by default

➡️ See: `scripts/delete-unattached-aks-disks/README.md`

### 2) Delete empty Kubernetes namespaces
Path: `scripts/delete-empty-namespaces/`

- Scans namespaces and deletes those that have no active resources
- Dry run by default

➡️ See: `scripts/delete-empty-namespaces/README.md`
