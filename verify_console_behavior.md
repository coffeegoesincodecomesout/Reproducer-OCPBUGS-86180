# How to Verify Console Troubleshooting Panel Behavior

This guide explains how to check if the OpenShift Console Troubleshooting Panel actually shows traces.

## Step 1: Access OpenShift Console

1. Get the console URL:
   ```bash
   oc whoami --show-console
   ```

2. Open in browser and log in

## Step 2: Navigate to a Pod with Traces

1. Go to **Workloads** → **Pods**
2. Filter by namespace: `ns1-uwl` or `ns2-uwl`
3. Click on any pod (e.g., `threepilar-app-*`)

## Step 3: Look for Troubleshooting Panel

In the pod details page, look for:
- **"Observe"** tab or section
- **"Troubleshooting Panel"** button/section
- **"Related Traces"** or **"Traces"** section

## Step 4: Check Browser DevTools

### Open DevTools
- Chrome/Edge: F12 or Ctrl+Shift+I
- Firefox: F12 or Ctrl+Shift+K
- Safari: Cmd+Option+I

### Switch to Network Tab

1. Click **Network** tab
2. Filter by: `korrel8r` or `objects`
3. Look for requests like:
   ```
   GET /api/proxy/plugin/troubleshooting-panel/korrel8r/api/v1alpha1/objects?query=trace:span:{...}
   ```

### Check Request Details

Click on the request and verify:

**Request Headers:**
```
Method: GET                                    ← Should be GET, not POST
URL: /api/proxy/.../korrel8r/api/v1alpha1/objects?query=...
Authorization: Bearer <token>
```

**Query Parameters:**
```
query: trace:span:{resource.k8s.pod.name="threepilar-app-xxx"}
```

**Response:**

- **200 OK** + JSON array = ✅ Working
  ```json
  [
    {
      "name": "handleRequest",
      "context": {"traceID": "...", "spanID": "..."},
      "attributes": {"k8s.namespace.name": "ns1-uwl"}
    }
  ]
  ```

- **200 OK** + empty array `[]` = ⚠️ No traces found (but API works)

- **401 Unauthorized** = ❌ Authentication problem

- **403 Forbidden** = ❌ RBAC permissions problem

- **404 Not Found** = ❌ Routing/service problem

- **500 Server Error** = ❌ Backend error (check korrel8r logs)

## Step 5: Expected Behaviors

### If Troubleshooting Panel Shows Traces ✅

**What you'll see:**
- "Related Traces" section appears
- List of trace IDs and spans
- Links to trace details

**Conclusion:**
- Everything works correctly
- Bug report is INVALID
- Reproducer script was using wrong method
- No action needed

### If Troubleshooting Panel Shows No Traces ❌

**Check DevTools Network tab:**

#### Scenario A: No API call to korrel8r
- **Symptom:** No requests to `/objects` endpoint
- **Cause:** Panel not configured or not loading
- **Action:** Check if plugin is enabled, check browser console for JS errors

#### Scenario B: API call returns 401/403
- **Symptom:** Request made but auth fails
- **Cause:** Token not forwarded, RBAC issue
- **Action:** Check ServiceAccount permissions, proxy configuration

#### Scenario C: API call returns empty array []
- **Symptom:** 200 OK but no traces in response
- **Cause:** Korrel8r can't reach Tempo, or no traces match query
- **Action:** Check korrel8r logs, verify Tempo backend

#### Scenario D: API call returns 500
- **Symptom:** Server error
- **Cause:** Korrel8r backend failure
- **Action:** Check korrel8r pod logs

## Step 6: Collect Diagnostic Info

If traces don't appear, collect this information:

### Browser Info
```bash
# Take screenshot of:
# - Pod details page (showing no traces)
# - DevTools Network tab (showing API call)
# - DevTools Console tab (showing any errors)
```

### API Call Details
```bash
# From DevTools Network tab, right-click request → Copy → Copy as cURL
# This gives exact request being made by browser
```

### Korrel8r Logs
```bash
oc logs -n openshift-operators deploy/korrel8r --tail=200 > korrel8r.log
```

### Troubleshooting Panel Logs
```bash
oc logs -n openshift-operators deploy/troubleshooting-panel --tail=200 > panel.log
```

### Verify Tempo Accessibility
```bash
# From korrel8r pod, can it reach Tempo?
oc exec -n openshift-operators deploy/korrel8r -- \
  curl -sk https://tempo-platform-gateway.openshift-tracing.svc.cluster.local:8080/api/traces/v1/platform/tempo/api/search?q={} --head
```

## Example: Working Console Behavior

When everything works, you should see in DevTools:

**Request:**
```
GET /api/proxy/plugin/troubleshooting-panel/korrel8r/api/v1alpha1/objects?query=trace%3Aspan%3A%7Bresource.k8s.pod.name%3D%22threepilar-app-abc123%22%7D
Status: 200 OK
```

**Response:**
```json
[
  {
    "name": "handleRequest",
    "context": {
      "traceID": "a28b90849456c90abceb641079919877",
      "spanID": "8de9f3ea7a9ea8a5"
    },
    "startTime": "2026-06-10T12:17:24.806091124Z",
    "endtime": "2026-06-10T12:17:25.806285554Z",
    "attributes": {
      "k8s.namespace.name": "ns1-uwl",
      "k8s.pod.name": "threepilar-app-abc123",
      "service.name": "threepilar-app"
    },
    "status": {
      "statusCode": "Unset"
    }
  }
]
```

**UI Display:**
```
Related Traces
  ├─ Trace ID: a28b90849456c90abceb641079919877
  │  └─ Span: handleRequest (1s duration)
  └─ View in Trace UI →
```

## Summary Checklist

- [ ] Accessed OpenShift Console
- [ ] Navigated to a pod in ns1-uwl or ns2-uwl
- [ ] Looked for Troubleshooting Panel / Related Traces section
- [ ] Opened browser DevTools Network tab
- [ ] Verified API call method is GET (not POST)
- [ ] Checked response status and body
- [ ] Collected logs if issue found
- [ ] Documented actual behavior vs. expected

## Report Format

When reporting results, include:

1. **Console Version:**
   ```bash
   oc get console.operator cluster -o jsonpath='{.status.version}'
   ```

2. **Behavior:**
   - [ ] Traces appear in UI
   - [ ] No traces shown, but API call works
   - [ ] No traces shown, API call fails
   - [ ] No API call made at all

3. **API Call Details:**
   - Method: GET / POST / None
   - Status: 200 / 401 / 403 / 404 / 500
   - Response: (paste JSON or error message)

4. **Logs:**
   - Attach korrel8r.log
   - Attach panel.log
   - Include browser console errors

This information will help determine if there's a real issue or if the reproducer was simply using the wrong test method.
