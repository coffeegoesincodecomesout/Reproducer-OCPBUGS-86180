# OpenShift Console Troubleshooting Panel Analysis

## Investigation Date: 2026-06-10

## Question
Does the OpenShift Console Troubleshooting Panel use POST (incorrect) or GET (correct) when querying the korrel8r `/objects` endpoint?

## Answer: ✅ The Console Uses GET (CORRECT)

## Evidence

### Source Analysis

**Plugin:** `troubleshooting-panel-console-plugin`
**Namespace:** `openshift-operators`
**Image:** `registry.redhat.io/cluster-observability-operator/troubleshooting-panel-console-plugin-rhel9@sha256:019272ef6ebce38473cdb8e15c385ee48e9cbe55c79f093f52a328865c5b183f`

### JavaScript Code Analysis

Downloaded and analyzed the korrel8r client code from the running plugin:
```
/korrel8r-client_ts-redux-actions_ts-webpack_sharing_consume_default_openshift-console_dynamic-e192fa-chunk.js
```

**Key Finding - Lines 751-760:**
```javascript
/**
 * Execute a query, returns a list of JSON objects.
 * @param query query string
 * @returns any OK
 * @throws ApiError
 */
getObjects(query) {
    return this.httpRequest.request({
        method: 'GET',              // ← CORRECT METHOD
        url: '/objects',
        query: {
            'query': query,        // ← Query in URL params, not body
        },
    });
}
```

### Complete API Client Implementation

The console plugin correctly implements all korrel8r endpoints:

| Endpoint | Method | Implementation | Status |
|----------|--------|----------------|--------|
| `/domains` | GET | `getDomains()` | ✅ Correct |
| `/objects` | GET | `getObjects(query)` | ✅ Correct |
| `/graphs/goals` | POST | `postGraphsGoals(request, rules)` | ✅ Correct |
| `/graphs/neighbours` | POST | `postGraphsNeighbours(request, rules)` | ✅ Correct |
| `/lists/goals` | POST | `postListsGoals(request)` | ✅ Correct |

## Console Plugin Configuration

```yaml
spec:
  proxy:
  - alias: korrel8r
    authorization: UserToken
    endpoint:
      service:
        name: korrel8r
        namespace: openshift-operators
        port: 9443
      type: Service
```

The console plugin correctly:
1. Proxies requests through the console backend
2. Uses UserToken for authorization
3. Points to the correct korrel8r service on port 9443

## Conclusion

**The OpenShift Console Troubleshooting Panel is NOT the source of the issue.**

The console plugin:
- ✅ Uses the correct HTTP method (GET) for `/objects` endpoint
- ✅ Passes query as URL parameter (not in request body)
- ✅ Uses POST correctly for cross-domain correlation (`/graphs/goals`)
- ✅ Properly configures authentication (UserToken)

## Issue Isolation

Since the console uses the correct API:

1. **The reproducer script is wrong** - It uses POST when testing, which doesn't reflect actual console behavior
2. **The real issue (if any) must be elsewhere:**
   - Authentication/Authorization problems
   - RBAC permissions missing
   - Tempo backend configuration
   - Network/routing issues
   - ServiceAccount token issues

## Next Steps

1. ✅ Update reproducer script to use GET (matching console behavior)
2. ⏳ Test with proper authentication tokens
3. ⏳ Check RBAC permissions for ServiceAccount
4. ⏳ Verify Tempo backend is accessible from korrel8r pod
5. ⏳ Check korrel8r logs for actual errors when console queries fail

## Recommendation

**Update the bug report** to clarify:
- Console implementation is correct
- Reproducer script was using wrong method
- Real issue needs investigation with proper auth context
- Focus on why console sees no traces, not on HTTP method

## Testing the Console Behavior

To verify console actually works, check:

1. Open OpenShift Console
2. Navigate to a Pod in ns1-uwl or ns2-uwl namespace
3. Look for "Troubleshooting Panel" or "Observe" → "Troubleshooting Panel"
4. Check if "Related Traces" section appears
5. If traces don't appear, check browser DevTools Network tab for actual API calls

The Network tab will show:
```
GET /api/proxy/plugin/troubleshooting-panel/korrel8r/api/v1alpha1/objects?query=trace:span:{...}
```

This confirms the console uses GET through the proxy.
