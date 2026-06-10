# Verifying Troubleshooting Panel Trace Correlation

## Purpose

This guide helps you verify whether traces appear in the Troubleshooting Panel's spider diagram when viewing a custom alert that should have related traces.

## Prerequisites

1. Environment deployed with `./00_Deploy.sh`
2. Applications generating traces in `ns1-uwl` and `ns2-uwl` namespaces
3. Custom alerts firing (based on application activity)

## Available Custom Alerts

Your reproducer has the following custom alerts that **should** correlate with traces:

### ns1-uwl Alerts

1. **TestappConnectionCount** (PrometheusRule)
   - Namespace: `ns1-uwl`
   - Condition: `ping_request_count{job="threepilar-example-service"} > 0`
   - Fires when: Application receives ping requests
   - Should correlate to: Pod → Metric → **Traces** from `threepilar-app`

2. **TestappLogRallyCount** (Loki AlertingRule)
   - Namespace: `ns1-uwl`
   - Condition: Log rate for pods matching `threepilar-uwl-example-app.*`
   - Fires when: Application logs at high rate
   - Should correlate to: Alert → Log → Pod → **Traces**

### ns2-uwl Alerts

3. **TestappFrontendConnectionCount** (PrometheusRule)
   - Namespace: `ns2-uwl`
   - Condition: `ping_request_count{job="threepilar-frontend-service"} > 0`
   - Should correlate to: Alert → Metric → Pod → **Traces** from `threepilar-frontend`

4. **TestappBackendResponseCount** (PrometheusRule)
   - Namespace: `ns2-uwl`
   - Condition: `ping_response_request_count{job="threepilar-backend-service"} > 0`
   - Should correlate to: Alert → Metric → Pod → **Traces** from `threepilar-backend`

5. **TestappFrontendLogRallyCount** (Loki AlertingRule)
   - Namespace: `ns2-uwl`
   - Should correlate to: Alert → Log → Pod → **Traces** from frontend

6. **TestappBackendLogResponseCount** (Loki AlertingRule)
   - Namespace: `ns2-uwl`
   - Should correlate to: Alert → Log → Pod → **Traces** from backend

## Step 1: Generate Traffic to Trigger Alerts

Run the test script to generate traces and trigger alerts:

```bash
./test_korrel8r.sh
```

Or manually generate traffic:

```bash
# Get route URLs
NS1_ROUTE=$(oc get route threepilar-example-route -n ns1-uwl -o jsonpath='{.spec.host}')
NS2_ROUTE=$(oc get route threepilar-frontend-route -n ns2-uwl -o jsonpath='{.spec.host}')

# Generate traffic
for i in {1..50}; do
  curl -sk "https://${NS1_ROUTE}/ping" &
  curl -sk "https://${NS2_ROUTE}/ping" &
done

wait
```

## Step 2: Wait for Alerts to Fire

Alerts have a `for: 1m` condition, so wait ~2-3 minutes for them to become active.

Check alert status:

```bash
# Check Prometheus alerts
oc get prometheusrules -n ns1-uwl
oc get prometheusrules -n ns2-uwl

# Check Loki alerts
oc get alertingrules -n ns1-uwl
oc get alertingrules -n ns2-uwl

# Check firing alerts in Prometheus
oc exec -n openshift-monitoring prometheus-k8s-0 -- \
  curl -s localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname | contains("Testapp"))'
```

## Step 3: Open Troubleshooting Panel from Alert

### Option A: Via Observe → Alerting

1. Open OpenShift Console: `oc whoami --show-console`
2. Navigate to: **Observe** → **Alerting**
3. Filter by namespace: `ns1-uwl` or `ns2-uwl`
4. Find one of the custom alerts (e.g., `TestappConnectionCount`)
5. Click on the alert to open details
6. Open the **Troubleshooting Panel** (right sidebar or menu)

### Option B: Via Application Grid

1. Navigate to any view showing the alert or related pod
2. Click the **application grid** (9-dot icon) in the masthead
3. Under **Troubleshooting**, click **Signal Correlation**
4. Panel opens focused on current context

## Step 4: Verify Trace Nodes in Spider Diagram

Once the Troubleshooting Panel is open:

### Expected Behavior ✅

The correlation graph should display:

```
    [Alert]
       ↓
    [Metric]
       ↓
    [Pod]
       ↓
    [Trace]  ← Should appear here!
```

**Trace node characteristics:**
- **Icon**: Gantt chart icon (📊)
- **Label**: "Span"
- **Badge**: Count of trace spans found (e.g., `15`)
- **Click behavior**: Navigates to `observe/traces?namespace=openshift-tracing&name=platform&tenant=platform&q=<traceQL>`

### What to Look For

1. **Trace node exists**: Look for a node with the Gantt chart icon
2. **Badge shows count > 0**: Indicates traces were found
3. **Edge to trace node**: Arrow from Pod node to Trace node
4. **Click navigates to Tempo UI**: Clicking trace node opens trace search view

### If Trace Node Is Missing ❌

This confirms the bug. Possible causes:

1. **Korrel8r cannot query Tempo**
   - Check korrel8r logs: `oc logs -n openshift-operators deploy/korrel8r --tail=100`
   - Look for errors querying Tempo gateway

2. **No correlation rules from Pod → Trace**
   - Check korrel8r rules: `oc get configmap korrel8r -n openshift-operators -o yaml`
   - Look for rules involving `trace:span`

3. **Traces lack required attributes**
   - Traces need `k8s.namespace.name` or `k8s.pod.name` for correlation
   - Verify with direct Tempo query (Step 5)

## Step 5: Verify Traces Exist in Tempo

Even if Troubleshooting Panel doesn't show traces, verify they exist:

```bash
TOKEN=$(oc whoami -t)
TEMPO_GATEWAY=$(oc get route tempo-platform-gateway -n openshift-tracing -o jsonpath='{.spec.host}')

# Search for traces in ns1-uwl
curl -sk -G "https://${TEMPO_GATEWAY}/api/traces/v1/platform/tempo/api/search" \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'q={resource.k8s.namespace.name="ns1-uwl"}' \
  --data-urlencode 'limit=5' | jq

# Search for traces in ns2-uwl
curl -sk -G "https://${TEMPO_GATEWAY}/api/traces/v1/platform/tempo/api/search" \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode 'q={resource.k8s.namespace.name="ns2-uwl"}' \
  --data-urlencode 'limit=5' | jq
```

**Expected**: Should return trace results with `traceID` and `k8s.namespace.name` attributes

## Step 6: Use Browser DevTools

To see the actual API calls the Troubleshooting Panel makes:

1. Open Browser DevTools (F12)
2. Go to **Network** tab
3. Filter by: `korrel8r` or `graphs`
4. Open Troubleshooting Panel focused on alert
5. Look for requests:
   ```
   POST /api/proxy/plugin/troubleshooting-panel-console-plugin/korrel8r/api/v1alpha1/graphs/goals
   ```

6. **Check the request body:**
   ```json
   {
     "start": {
       "queries": ["alert:alert:{alertname=\"TestappConnectionCount\"}"],
       "constraint": {"start": "...", "end": "..."}
     },
     "goals": ["trace:span"]
   }
   ```

7. **Check the response:**
   - **Success case**: Response contains `"nodes"` array with a node where `"class": "trace:span"`
   - **Failure case**: Empty `"nodes": []` or error response

## Step 7: Test Goal-Directed Search

You can explicitly search for traces:

1. In Troubleshooting Panel, click **sliders icon** (⚙️)
2. Change **Search type** to **Goals**
3. Enter goal class: `trace:span`
4. Click **Search**

**Expected**: Graph shows path from Alert → ... → Trace

## Step 8: Check Korrel8r Configuration

Verify Korrel8r is configured correctly for trace store:

```bash
oc get configmap korrel8r -n openshift-operators -o yaml
```

Look for:

```yaml
stores:
  - domain: trace
    tempoStack: https://tempo-platform-gateway.openshift-tracing.svc.cluster.local:8080/api/traces/v1/platform/tempo/api/search
```

## Recording Your Findings

Create a test results file:

```bash
cat > TEST_RESULTS_$(date +%Y%m%d).md << 'EOF'
# Troubleshooting Panel Trace Verification Results

**Date**: $(date)
**Tester**: $(oc whoami)

## Test Environment

- OpenShift Console Version: 
- Cluster Observability Operator Version:
- Korrel8r Version:

## Alert Tested

- Alert Name: 
- Namespace: 
- Alert Status: Firing / Pending / Not Firing

## Troubleshooting Panel Results

### Correlation Graph Displayed

- [ ] Alert node present
- [ ] Metric node present
- [ ] Pod node present
- [ ] Log node present
- [ ] **Trace node present** ← KEY FINDING
- [ ] Other nodes: _______

### Trace Node Details (if present)

- Badge count: 
- Icon: Gantt chart ✅ / Other: ____
- Clicking navigates to: 
- DevTools shows API call: Success / Error

### Trace Node Missing (if absent)

- [ ] No trace node in graph
- [ ] Graph shows empty/incomplete correlation path
- [ ] DevTools shows error: _______
- [ ] Korrel8r logs show error: _______

## Direct Tempo Query

```bash
# Command used:


# Result:


# Traces found: Yes / No
# Trace count: 
# Attributes present: k8s.namespace.name, k8s.pod.name, etc.
```

## Conclusion

- [ ] ✅ **PASS**: Trace node appears in Troubleshooting Panel spider diagram
- [ ] ❌ **FAIL**: Trace node missing despite traces existing in Tempo
- [ ] ⚠️ **INCONCLUSIVE**: No traces in Tempo to correlate

## Supporting Evidence

Attach:
- Screenshot of Troubleshooting Panel spider diagram
- Screenshot of DevTools Network tab
- Korrel8r logs: `korrel8r.log`
- Tempo query results: `tempo-query.json`

EOF
```

## Expected Outcome

If everything is working correctly:

1. ✅ Alerts fire when applications receive traffic
2. ✅ Traces are stored in Tempo with k8s attributes
3. ✅ Troubleshooting Panel displays trace node in spider diagram
4. ✅ Clicking trace node navigates to Tempo trace search

If traces don't appear in the panel but exist in Tempo:

1. ❌ **Confirms OCPBUGS-86180**: Korrel8r cannot correlate Pod → Trace
2. ❌ Troubleshooting Panel feature is implemented but Korrel8r integration is broken
3. ❌ Root cause is in Korrel8r backend, not Console plugin

## Troubleshooting

### No Alerts Firing

```bash
# Generate more traffic
for i in {1..100}; do curl -sk "https://$NS1_ROUTE/ping"; done

# Check Prometheus scraping
oc exec -n openshift-monitoring prometheus-k8s-0 -- \
  curl -s localhost:9090/api/v1/query?query=ping_request_count | jq
```

### Troubleshooting Panel Not Appearing

```bash
# Check if plugin is enabled
oc get consoles.operator.openshift.io cluster -o yaml | grep troubleshooting

# Check plugin deployment
oc get deploy -n openshift-operators troubleshooting-panel-console-plugin

# Check UIPlugin status
oc get uiplugin troubleshooting-panel -o yaml
```

### Korrel8r Errors

```bash
# Check korrel8r is running
oc get deploy -n openshift-operators korrel8r

# Check korrel8r logs for errors
oc logs -n openshift-operators deploy/korrel8r --tail=200 | grep -i error

# Test korrel8r directly
oc port-forward -n openshift-operators deploy/korrel8r 9443:9443 &
curl -sk https://localhost:9443/api/v1alpha1/domains | jq
```

## Reference: Correlation Path

The expected correlation path for alert → trace:

```
Alert (TestappConnectionCount)
  └─> Metric (ping_request_count)
       └─> Pod (threepilar-uwl-example-app-*)
            └─> Trace (spans with k8s.pod.name matching pod)
```

Korrel8r rules should exist for each arrow in this chain.
