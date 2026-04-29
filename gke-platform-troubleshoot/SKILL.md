---
name: gke-platform-troubleshoot
description: Diagnose and fix common failures in this GKE platform stack. Use when Argo CD apps are Degraded/Unknown, pods are CrashLoopBackOff, PVCs are Pending, TiKV or SurrealDB won't start, or SSD quota is exceeded.
---

# GKE Platform Troubleshooting

Decision-tree playbooks for the most common failure modes encountered in this cluster.

## When to Use

- An Argo CD application shows `Unknown`, `Degraded`, or `OutOfSync` and is not self-healing.
- Pods in the `platform` namespace are in `CrashLoopBackOff`, `Pending`, or `Error` state.
- PVCs are stuck in `Pending`.
- TiKV, PD, or SurrealDB won't start.
- GCP quota errors appear in events.

## Playbook 1: Argo CD application stuck at `Unknown`

**Diagnose:**

```bash
kubectl describe application <APP_NAME> -n argocd | grep -A 5 "Conditions"
```

**Decision tree:**

| Error message | Cause | Fix |
|---------------|-------|-----|
| `authentication required` | Repo credentials missing | Register the repo secret (see `argocd-gitops-sync` skill, step 2) |
| `Write access to repository not granted` | Fine-grained PAT lacks permissions | Use a classic PAT with `repo` scope |
| `chart "X" version "Y" not found` | Helm chart does not exist at that version | Check the chart repo for available versions; update `targetRevision` |
| `CRD not installed` | Missing CRDs for custom resources | Apply CRDs manually (e.g. TiDB Operator CRDs) |

**Force refresh after fixing:**

```bash
kubectl patch application <APP_NAME> -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## Playbook 2: Sync operation stuck / retries exhausted

**Symptoms:** Application stays at `OutOfSync` or sync message shows "Retrying attempt #5".

**Diagnose:**

```bash
kubectl get application <APP_NAME> -n argocd \
  -o jsonpath='{.status.operationState.phase}' && echo ""
kubectl get application <APP_NAME> -n argocd \
  -o jsonpath='{.status.operationState.message}' && echo ""
```

**Fix — reset the sync:**

```bash
kubectl delete application <APP_NAME> -n argocd --cascade=orphan
kubectl patch application infra-root -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

The root app recreates the child application with a fresh sync operation.

---

## Playbook 3: PVC stuck in `Pending` (SSD quota exceeded)

**Diagnose:**

```bash
kubectl get events -n platform --sort-by=.lastTimestamp | grep -i "quota\|provision"
```

Look for: `QUOTA_EXCEEDED: Quota 'SSD_TOTAL_GB' exceeded. Limit: 500.0`

**Check current disk usage:**

```bash
gcloud compute disks list --project=walker-di-br \
  --filter="zone~southamerica-east1 AND type~pd-balanced" \
  --format="value(sizeGb)" \
  | python3 -c "import sys; print('Total SSD GB:', sum(int(x) for x in sys.stdin))"
```

**Check for orphaned disks (no users):**

```bash
gcloud compute disks list --project=walker-di-br \
  --filter="zone~southamerica-east1 AND -users:*" \
  --format="table(name,sizeGb,type,zone)"
```

**Fix — delete orphaned disks:**

```bash
gcloud compute disks delete <DISK_NAME> --zone=<ZONE> --project=walker-di-br --quiet
```

**Fix — check for Retained PVs still consuming quota:**

```bash
kubectl get pv | grep Released
# Delete any Released PVs (their GCP disks persist with Retain policy):
kubectl delete pv <PV_NAME>
# Then delete the underlying GCP disk if it still exists
```

**Prevention:** The TidbCluster CR uses `pvReclaimPolicy: Delete` to avoid this. Verify:

```bash
kubectl get tidbcluster tikv-platform -n platform \
  -o jsonpath='{.spec.pvReclaimPolicy}' && echo ""
```

---

## Playbook 4: TiKV pod crash — "duplicated store address"

**Symptom:** TiKV logs show `FATAL: duplicated store address ... already registered by id:XXXX`

**Cause:** PD still has the old TiKV store registration from a previous instance. This happens when TiKV PVCs are deleted but PD data is preserved.

**Fix — wipe and recreate the entire TiDB cluster:**

```bash
kubectl delete tidbcluster tikv-platform -n platform
kubectl delete pvc -l app.kubernetes.io/managed-by=tidb-operator -n platform
# Wait for pods to terminate, then re-apply:
kubectl apply -f platform/tikv/tidbcluster.yaml
```

---

## Playbook 5: SurrealDB CrashLoopBackOff

**Diagnose:**

```bash
kubectl describe pod surrealdb-0 -n platform | grep -A 10 "Last State:"
kubectl logs surrealdb-0 -n platform --tail=20
```

**Decision tree:**

| Error | Cause | Fix |
|-------|-------|-----|
| `exec: "/bin/sh": no such file or directory` | Image is distroless, no shell | Use `/surreal` as the command, not `/bin/sh` |
| `exec: "surreal": executable file not found` | Binary not in PATH | Use absolute path `/surreal` |
| `unexpected argument '--auth'` | Flag removed in SurrealDB v2.x | Remove `--auth` from args; auth is always enabled in v2 |
| `gRPC error: transport error` | TiKV is not running yet | Wait for TiKV-0 to reach `Running`, then `kubectl delete pod surrealdb-0 -n platform` |
| `data stored on disk is out-of-date` | Stale data from previous failed starts | Wipe TiKV data (Playbook 4) and restart SurrealDB |

**Correct SurrealDB v2.2.1 startup:**

```yaml
command: ["/surreal"]
args:
  - start
  - --bind
  - 0.0.0.0:8000
  - --user
  - $(SURREAL_ROOT_USER)
  - --pass
  - $(SURREAL_ROOT_PASSWORD)
  - tikv://pd.platform.svc.cluster.local:2379
```

**Verify SurrealDB is healthy:**

```bash
kubectl logs surrealdb-0 -n platform --tail=5
# Should show: "Started web server on 0.0.0.0:8000"
```

---

## Playbook 6: TiDB Operator Helm chart errors

**Symptom:** `tidb-operator` application shows `ComparisonError`.

**Diagnose:**

```bash
kubectl describe application tidb-operator -n argocd | grep -A 5 "Conditions"
```

**Common errors:**

| Error | Fix |
|-------|-----|
| `YAML parse error on scheduler-deployment.yaml` | Set `scheduler.create: false` in Helm values |
| `failed to fetch chart` | Verify chart name and version exist in `https://charts.pingcap.org` |

After fixing the Helm values in `infra/tidb-operator/application.yaml`:

```bash
git add -A && git commit -m "fix: tidb-operator helm values" && git push origin main
kubectl patch application infra -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## General diagnostic commands

```bash
# Application sync details
kubectl get application <APP_NAME> -n argocd -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); \
  [print(f\"{r['kind']}/{r['name']}: {r['status']}\") \
  for r in d.get('status',{}).get('resources',[])]"

# All events in a namespace (sorted)
kubectl get events -n <NAMESPACE> --sort-by=.lastTimestamp | tail -20

# Disk quota summary
gcloud compute disks list --project=walker-di-br \
  --filter="zone~southamerica-east1" \
  --format="table(name,sizeGb,type)"
```

## Safety Notes

- Deleting a TidbCluster CR destroys all PD/TiKV/TiDB pods and their data if `pvReclaimPolicy: Delete`.
- Always use `--cascade=orphan` when deleting Argo CD applications to preserve underlying resources.
- Never delete PVCs in production without confirming backups exist.
- GCP disk deletion is irreversible.
