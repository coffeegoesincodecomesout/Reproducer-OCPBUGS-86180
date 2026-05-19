#!/bin/bash

# Test script for Korrel8r Tempo integration issue reproduction
# This script tests the failing scenarios described in the reproduction steps

echo "==================================================================="
echo "Korrel8r Tempo Integration Test"
echo "==================================================================="
echo ""

# Check if port-forward is already running
if pgrep -f "port-forward.*korrel8r.*9443" > /dev/null; then
    echo "Port-forward to korrel8r is already running"
else
    echo "Starting port-forward to korrel8r..."
    oc port-forward -n openshift-operators deploy/korrel8r 9443:9443 &
    PORT_FORWARD_PID=$!
    echo "Port-forward started (PID: $PORT_FORWARD_PID)"
    echo "Waiting 5 seconds for port-forward to establish..."
    sleep 5
fi

echo ""
echo "==================================================================="
echo "Test 1: Direct trace-store query"
echo "Expected: HTTP 404 with body '404 page not found'"
echo "==================================================================="
echo ""
echo "Query: trace:span:{resource.k8s.namespace.name=\"grafana\"}"
echo ""

curl -sk -X POST https://localhost:9443/api/v1alpha1/objects \
  -H 'Content-Type: application/json' \
  -d '{"query":"trace:span:{resource.k8s.namespace.name=\"grafana\"}"}'

echo ""
echo ""

echo "==================================================================="
echo "Test 2: Cross-domain graph query (Pod → trace)"
echo "Expected: Empty graph '{}' returned, even when matching spans exist"
echo "==================================================================="
echo ""
echo "Query: k8s:Pod:{namespace: grafana} → trace:span"
echo ""

curl -sk -X POST https://localhost:9443/api/v1alpha1/graphs/goals \
  -H 'Content-Type: application/json' \
  -d '{
    "start": {"queries":["k8s:Pod:{namespace: grafana}"]},
    "goals": ["trace:span"]
  }'

echo ""
echo ""

# Alternative test with ns1-uwl namespace (the test app namespace in this repo)
echo "==================================================================="
echo "Test 3: Cross-domain graph query with test app namespace"
echo "Expected: Empty graph '{}' returned, even when matching spans exist"
echo "==================================================================="
echo ""
echo "Query: k8s:Pod:{namespace: ns1-uwl} → trace:span"
echo ""

curl -sk -X POST https://localhost:9443/api/v1alpha1/graphs/goals \
  -H 'Content-Type: application/json' \
  -d '{
    "start": {"queries":["k8s:Pod:{namespace: ns1-uwl}"]},
    "goals": ["trace:span"]
  }'

echo ""
echo ""

echo "==================================================================="
echo "Test completed"
echo "==================================================================="
echo ""
echo "Expected behaviors:"
echo "  - Test 1: HTTP 404 error"
echo "  - Test 2 & 3: Empty graph {}, no traces found despite spans existing"
echo ""
echo "This demonstrates the Korrel8r → Tempo integration issue where:"
echo "  1. Direct trace queries fail with 404"
echo "  2. Cross-domain queries return empty results"
echo "  3. Troubleshooting Panel shows no 'Related Traces' section"
echo ""
