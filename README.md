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

3. **See detailed reproduction steps and configuration:**
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

See `REPRODUCER_SETUP.md` for complete details on all changes made.
