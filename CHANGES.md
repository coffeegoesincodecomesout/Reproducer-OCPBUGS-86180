# Summary of Changes for Korrel8r-Tempo Issue Reproduction

## Modified Files

### Tempo Configuration (05_Tempo/)
1. **00_namespace.yaml**
   - Changed namespace: `openshift-tempo` → `openshift-tracing`

2. **01_objectclaim.yaml**
   - Changed namespace: `openshift-tempo` → `openshift-tracing`

3. **02_bucketsecret.sh**
   - Changed namespace: `openshift-tempo` → `openshift-tracing`
   - Changed secret name: `tempostack-dev-odf` → `tempostack-platform-odf`

4. **03_tempo.yaml**
   - Changed namespace: `openshift-tempo` → `openshift-tracing`
   - Changed TempoStack name: `simplest` → `platform`
   - Changed tenant: `dev` → `platform` (removed `prod` tenant)
   - Updated retention perTenant: `dev` → `platform`
   - Updated limits perTenant: `dev` → `platform`
   - Changed storage secret name: `tempostack-dev-odf` → `tempostack-platform-odf`

### OpenTelemetry Configuration (04_Opentelemetry/)
5. **01_collector.yaml**
   - **Added k8sattributes processor** with metadata extraction:
     - k8s.namespace.name
     - k8s.pod.name
     - k8s.deployment.name
   - Updated processor pipelines to include: `k8sattributes, batch, memory_limiter, resourcedetection`
   - Changed OTLP exporter endpoint: `tempo-simplest-gateway.openshift-tempo` → `tempo-platform-gateway.openshift-tracing`
   - Changed OTLP HTTP exporter endpoint: `tempo-simplest-gateway.openshift-tempo` → `tempo-platform-gateway.openshift-tracing`
   - Changed X-Scope-OrgID header: `dev` → `platform`
   - **Updated RBAC:**
     - ClusterRole `tempostack-traces-reader`: resource `dev/prod` → `platform`
     - ClusterRole `tempostack-traces-write`: resource `dev` → `platform`
     - **Added ClusterRoleBinding** for `system:cluster-admins` to have read access

### Perses Configuration (07_Perses/)
6. **02_datasource.yaml**
   - Changed namespace: `openshift-tempo` → `openshift-tracing`
   - Changed datasource URL: `tempo-simplest-gateway.openshift-tempo` → `tempo-platform-gateway.openshift-tracing`

### New Files Created
7. **test_korrel8r.sh** (NEW)
   - Test script to reproduce the Korrel8r integration failures
   - Tests direct trace queries (expects HTTP 404)
   - Tests cross-domain graph queries (expects empty results)

8. **REPRODUCER_SETUP.md** (NEW)
   - Comprehensive documentation of all changes
   - Explanation of the issue being reproduced
   - Deployment and testing instructions

9. **CHANGES.md** (NEW)
   - This file - summary of all modifications

### Updated Files
10. **README.md**
    - Updated to reflect the reproducer purpose
    - Added quick start instructions
    - Added references to reproduction documentation

## Key Configuration Changes Summary

### Before (Original)
```yaml
Namespace: openshift-tempo
TempoStack: simplest
Tenant: dev, prod
Processors: batch, memory_limiter, resourcedetection
RBAC: dev/prod resources
```

### After (Reproducer)
```yaml
Namespace: openshift-tracing
TempoStack: platform
Tenant: platform
Processors: k8sattributes, batch, memory_limiter, resourcedetection
RBAC: platform resource with system:cluster-admins access
```

## Testing

To verify all changes were applied correctly:

```bash
# Check namespace
grep -r "openshift-tempo" --include="*.yaml" --include="*.sh" . | grep -v ".git"
# Should return no results

# Check old TempoStack name
grep -r "simplest" --include="*.yaml" --include="*.sh" . | grep -v ".git"
# Should return no results

# Check new configuration
grep -r "openshift-tracing\|platform" --include="*.yaml" . | grep -v ".git"
# Should show multiple results in the modified files
```

## Reproducing the Issue

After deploying with `./00_Deploy.sh`, run:
```bash
./test_korrel8r.sh
```

Expected failures indicate successful reproduction of the issue.
