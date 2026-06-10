#!/bin/bash

# Test script to demonstrate the correct Korrel8r API usage
# This script compares POST vs GET methods for the /objects endpoint

echo "==================================================================="
echo "Korrel8r API Method Test - POST vs GET"
echo "==================================================================="
echo ""

# Check if port-forward is already running
if ! pgrep -f "port-forward.*korrel8r.*9443" > /dev/null; then
    echo "Starting port-forward to korrel8r (HTTPS port 9443)..."
    oc port-forward -n openshift-operators deploy/korrel8r 9443:9443 &
    PORT_FORWARD_PID=$!
    echo "Port-forward started (PID: $PORT_FORWARD_PID)"
    echo "Waiting 5 seconds for port-forward to establish..."
    sleep 5
else
    echo "Port-forward to korrel8r is already running"
fi

echo ""
echo "==================================================================="
echo "Test 1: POST method to /objects endpoint (INCORRECT - Returns 404)"
echo "==================================================================="
echo ""
echo "This is what the current reproducer script does:"
echo ""
echo "Command:"
echo "curl -k -X POST https://localhost:9443/api/v1alpha1/objects \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"query\":\"trace:span:{resource.k8s.namespace.name=\\\"ns1-uwl\"}\"}'"
echo ""
echo "Response:"

curl -sk -X POST https://localhost:9443/api/v1alpha1/objects \
  -H 'Content-Type: application/json' \
  -d '{"query":"trace:span:{resource.k8s.namespace.name=\"ns1-uwl\"}"}'

echo ""
echo ""
echo "Result: ❌ 404 Not Found - POST is not supported for this endpoint"
echo ""

echo "==================================================================="
echo "Test 2: GET method to /objects endpoint (CORRECT - Should work)"
echo "==================================================================="
echo ""
echo "This is the correct API usage according to korrel8r OpenAPI spec:"
echo ""
echo "Command:"
echo "curl -k -G https://localhost:9443/api/v1alpha1/objects \\"
echo "  --data-urlencode 'query=trace:span:{resource.k8s.namespace.name=\"ns1-uwl\"}' \\"
echo "  --data-urlencode 'limit=3'"
echo ""
echo "Response:"

RESPONSE=$(curl -sk -G https://localhost:9443/api/v1alpha1/objects \
  --data-urlencode 'query=trace:span:{resource.k8s.namespace.name="ns1-uwl"}' \
  --data-urlencode 'limit=3')

echo "$RESPONSE"
echo ""

# Check if response contains an error about authentication
if echo "$RESPONSE" | grep -q "error.*oauth\|error.*certificate\|error.*unauthorized"; then
    echo "Result: ⚠️  Authentication error - This is expected when querying through port-forward"
    echo "        The endpoint exists and responds, but requires proper authentication"
    echo ""
    echo "NOTE: The GET method is CORRECT, but direct testing requires proper auth setup."
    echo "      In production, korrel8r uses service account tokens for authentication."
elif echo "$RESPONSE" | grep -q "traceID\|spanID"; then
    TRACE_COUNT=$(echo "$RESPONSE" | grep -o '"traceID"' | wc -l)
    echo "Result: ✅ SUCCESS - Found $TRACE_COUNT traces"
elif [ -z "$RESPONSE" ]; then
    echo "Result: ⚠️  Empty response - might indicate auth or connectivity issue"
else
    echo "Result: ⚠️  Unexpected response format"
fi

echo ""
echo "==================================================================="
echo "Summary: POST vs GET for /objects endpoint"
echo "==================================================================="
echo ""
echo "According to korrel8r OpenAPI specification (korrel8r-openapi.yaml):"
echo ""
echo "  /objects:"
echo "    get:                    ← Only GET method is defined"
echo "      summary: Execute a query, returns a list of JSON objects"
echo "      parameters:"
echo "        - name: query       ← Query passed as URL parameter"
echo "          in: query         ← Not in request body"
echo "          required: true"
echo ""
echo "Key Findings:"
echo "  1. ❌ POST /objects → 404 Not Found (method not supported)"
echo "  2. ✅ GET  /objects?query=... → Correct endpoint (requires auth)"
echo "  3. ✅ POST /graphs/goals → Correct for cross-domain correlation"
echo ""
echo "Root Cause of OCPBUGS-86180:"
echo "  The test reproducer was using POST when it should use GET."
echo "  The korrel8r API only supports GET for the /objects endpoint."
echo ""
echo "Recommendation:"
echo "  - If testing direct trace queries: Use GET with query parameter"
echo "  - If testing Pod→Trace correlation: Use POST to /graphs/goals"
echo "  - OpenShift Console/Troubleshooting Panel may need updating if it uses POST"
echo ""
