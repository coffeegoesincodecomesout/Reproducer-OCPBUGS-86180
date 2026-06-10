# Korrel8r-Tempo Integration Issue Reproducer

This repository has been configured to reproduce a specific Korrel8r-Tempo integration issue where trace queries fail and the Troubleshooting Panel does not show related traces.

## Purpose

This setup demonstrates collecting metrics, logs and traces on OpenShift using OpenShift Data Foundation (ODF) managed NooBaa as the storage backend, **specifically configured to reproduce the Korrel8r integration issue**.

## Components

- **User Workload Monitoring**: Stores user metrics
- **Cluster Logging & Loki Operators**: Collect and store logs
- **OpenTelemetry Collector**: Collects traces with k8sattributes processor
- **Tempo**: Stores traces at the exact path Korrel8r expects (`openshift-tracing/platform`)
- **Cluster Observability Operator**: Manages UIPlugins (Troubleshooting Panel)

## Test Applications

Test apps are deployed in namespaces `ns1-uwl` and `ns2-uwl`:

- `ns1-uwl`: https://github.com/coffeegoesincodecomesout/testapp-ThreePilars 
- `ns2-uwl`: 
  - https://github.com/coffeegoesincodecomesout/testapp-ThreePilars-Frontend 
  - https://github.com/coffeegoesincodecomesout/testapp-ThreePilars-backend 

## Quick Start

1. **Deploy the environment:**
   ```bash
   ./00_Deploy.sh
   ```

2. **Test Korrel8r integration (after deployment completes):**
   ```bash
   ./test_korrel8r.sh
   ```
   
   This script:
   - Generates traces by sending traffic to test applications
   - Verifies traces exist in Tempo (direct API queries)
   - Tests Korrel8r's ability to query the same traces via its HTTPS API (port 9443)
   - Demonstrates the contrast: Tempo queries work ✓, Korrel8r queries fail ✗

3. **Verify Troubleshooting Panel shows traces (RECOMMENDED):**
   ```bash
   cat VERIFY_TROUBLESHOOTING_PANEL.md
   ```
   
   This provides step-by-step instructions to:
   - Trigger custom alerts that correlate with traces
   - Open the Troubleshooting Panel from an alert
   - Visually verify if trace nodes appear in the spider diagram
   - Confirm the end-to-end user experience

4. **See detailed reproduction steps and configuration:**
   ```bash
   cat REPRODUCER_SETUP.md
   cat reproductionSteps.txt
   ```

## Key Configuration Details

This reproducer uses specific configuration to match Korrel8r's expectations:

- TempoStack named `platform` in namespace `openshift-tracing`
- Tenant named `platform` with mode `openshift`
- OTel collector with `k8sattributes` processor extracting k8s.namespace.name, k8s.pod.name, k8s.deployment.name
- RBAC configured to grant `create` on `tempo.grafana.com/platform/traces` to OTel collector SA
- RBAC configured to grant `get` on `tempo.grafana.com/platform/traces` to `system:cluster-admins`

## Observed Behavior

The test script demonstrates:

✓ **Working:** Direct Tempo API queries successfully return traces with k8s.namespace.name attributes
✗ **Broken:** Korrel8r API queries fail:
  - `POST https://localhost:9443/api/v1alpha1/objects` with `trace:span:{...}` returns **404 page not found**
  - Cross-domain queries `k8s:Pod → trace:span` return empty graph `{}`
  - Troubleshooting Panel shows no 'Related Traces' section

This confirms the issue is with Korrel8r's trace-store domain configuration, not trace generation or storage.

See `REPRODUCER_SETUP.md` for complete details on all changes made.
