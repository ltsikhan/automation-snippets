# Delete Empty Kubernetes Namespaces

Deletes Kubernetes namespaces that appear "empty" (no common workload/networking/storage resources).
Safe-by-default: **dry run by default**.

## What it checks
For each namespace it evaluates:
- Skips protected namespaces (e.g. `kube-system`, `default`, etc.)
- Skips namespaces in `Terminating` phase
- Counts common resources: Deployments, StatefulSets, DaemonSets, ReplicaSets, Jobs, CronJobs, Services, Ingresses, PVCs, Pods
- Extra safety: keeps namespaces with Pods in `Running` or `Pending`

## Requirements
- `kubectl`
- Access to the cluster context you intend to clean up

## Usage

Dry run (default):
```bash
DRY_RUN=1 ./delete-empty-namespaces.sh
