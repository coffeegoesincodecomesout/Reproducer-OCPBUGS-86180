# Korrel8r-Tempo Integration Issue Reproducer

This repository has been configured to reproduce the Korrel8r-Tempo integration issue where trace queries fail and the Troubleshooting Panel does not show related traces.

## Changes Made to Reproduce the Issue

The following modifications were made to configure the environment according to the exact specifications in `reproductionSteps.txt`:

### 1. Tempo Namespace and Resource Names

**Changed:**
- Namespace: `openshift-tempo` → `openshift-tracing`
- TempoStack name: `simplest` → `platform`
- Tenant: `dev` → `platform`

**Files Modified:**
- `05_Tempo/00_namespace.yaml` - Updated namespace
- `05_Tempo/01_objectclaim.yaml` - Updated namespace
- `05_Tempo/02_bucketsecret.sh` - Updated namespace and secret name
- `05_Tempo/03_tempo.yaml` - Updated namespace, TempoStack name, and tenant configuration

### 2. TempoStack Configuration

The TempoStack resource (`05_Tempo/03_tempo.yaml`) now matches the exact specification:
```yaml
apiVersion: tempo.grafana.com/v1alpha1
kind: TempoStack
metadata:
  name: platform
  namespace: openshift-tracing
spec:
  storage:
    secret: { name: tempostack-platform-odf, type: s3 }
  template:
    gateway: { enabled: true }
    queryFrontend:
      jaegerQuery: { enabled: true }
  tenants:
    mode: openshift
    authentication:
      - tenantName: platform
        tenantId: "1610b0c3-c509-4592-a256-a1871353dbfa"
```

### 3. OpenTelemetry Collector Configuration

**Added k8sattributes processor** to extract the required Kubernetes resource attributes:
- `k8s.namespace.name`
- `k8s.pod.name`
- `k8s.deployment.name`

**Updated configuration in** `04_Opentelemetry/01_collector.yaml`:
- Added `k8sattributes` processor with metadata extraction
- Updated pipelines to include the processor
- Updated Tempo gateway endpoints to point to `tempo-platform-gateway.openshift-tracing`
- Updated tenant ID to `platform`

### 4. RBAC Configuration

**Updated ClusterRoles and ClusterRoleBindings** in `04_Opentelemetry/01_collector.yaml`:

- **ClusterRole `tempostack-traces-write`**: Grants `create` on resource `platform` (resourceName `traces`)
  - Bound to: `otel-collector-sidecar` ServiceAccount in `opentelemetry` namespace

- **ClusterRole `tempostack-traces-reader`**: Grants `get` on resource `platform` (resourceName `traces`)
  - Bound to: `system:cluster-admins` group

This mirrors the LokiStack RBAC pattern described in the reproduction steps.

### 5. Perses Datasource

**Updated** `07_Perses/02_datasource.yaml`:
- Changed namespace to `openshift-tracing`
- Updated gateway URL to `tempo-platform-gateway.openshift-tracing`

### 6. Troubleshooting Panel UIPlugin

The UIPlugin configuration in `08_Troubleshooting/01_uiplugin.yaml` is already correct:
```yaml
apiVersion: observability.openshift.io/v1alpha1
kind: UIPlugin
metadata:
  name: troubleshooting-panel
spec:
  type: TroubleshootingPanel
  troubleshootingPanel:
    timeout: 30s
```

## Deployment

Run the deployment script as usual:
```bash
./00_Deploy.sh
```

This will:
1. Install all required operators (Tempo, OpenTelemetry, etc.)
2. Create the TempoStack at the exact path Korrel8r expects
3. Configure the OTel collector with k8sattributes processor
4. Set up RBAC permissions
5. Deploy test applications

## Reproducing the Issue

After deployment, use the provided test script to verify the issue:

```bash
./test_korrel8r.sh
```

This script will:
1. Port-forward to the Korrel8r service
2. Execute the failing trace-store query (expect HTTP 404)
3. Execute the cross-domain graph query (expect empty results)

### Expected Failures

#### Test 1: Direct Trace Query
```bash
curl -sk -X POST https://localhost:9443/api/v1alpha1/objects \
  -H 'Content-Type: application/json' \
  -d '{"query":"trace:span:{resource.k8s.namespace.name=\"grafana\"}"}'
```
**Expected:** `HTTP 404` with body `404 page not found`

#### Test 2: Cross-Domain Graph Query
```bash
curl -sk -X POST https://localhost:9443/api/v1alpha1/graphs/goals \
  -H 'Content-Type: application/json' \
  -d '{
    "start": {"queries":["k8s:Pod:{namespace: grafana}"]},
    "goals": ["trace:span"]
  }'
```
**Expected:** Empty graph `{}` returned, even when matching spans exist in Tempo

#### Test 3: Troubleshooting Panel

Navigate to Console → Observe → Alerting and open any active alert. The Troubleshooting Panel should NOT show a "Related Traces" section, even when traces exist.

## Verification Steps

To verify spans are actually reaching TempoStack:

1. Check Console → Observe → Traces
2. Verify spans are visible in TempoStack `openshift-tracing/platform`
3. Confirm spans have the required resource attributes:
   - `k8s.namespace.name`
   - `k8s.pod.name`
   - `k8s.deployment.name`

## Summary

This reproducer demonstrates the Korrel8r → Tempo integration issue where:
- Direct trace queries to Korrel8r fail with HTTP 404
- Cross-domain correlation queries return empty results
- The Troubleshooting Panel does not display related traces
- This occurs despite spans being successfully stored in TempoStack with correct attributes

The issue appears to be in how Korrel8r queries the TempoStack or how the RBAC is configured for trace access.
