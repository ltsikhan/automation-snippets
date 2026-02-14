# AKS / Azure Ops Snippets

A small collection of safe-by-default scripts I use for day-to-day Kubernetes/AKS and Azure operations.

## Scripts

### 1) Delete unattached managed disks by name (AKS PVC leftovers)

`scripts/delete-unattached-aks-disks.sh` deletes Azure managed disks **only if they are unattached** (`managedBy` is empty).
It is **dry-run by default** and prints the exact `az` command it would execute.

Typical use case: cleaning up orphaned disks created from Kubernetes PVCs after clusters/namespaces were removed.

#### Requirements
- Azure CLI (`az`)
- Logged in: `az login`
- Permissions to read/delete disks (RBAC): `Microsoft.Compute/disks/read`, `Microsoft.Compute/disks/delete`

#### Usage

Create a list file with disk names (one per line):
```txt
# examples/pvc-list.example.txt
pvc-12345678-aaaa-bbbb-cccc-1234567890ab
pvc-abcdef12-3456-7890-abcd-ef1234567890
