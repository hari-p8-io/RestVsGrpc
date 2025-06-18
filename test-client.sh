#!/bin/bash

# Test script for RestGrpcClient service
# Make sure both the main service and client service are running

echo "🚀 Testing RestGrpcClient Service"
echo "================================="

CLIENT_URL="http://localhost:9090"
SERVER_URL="http://localhost:8080"

echo ""
echo "1. Checking if RestGrpcClient is running..."
curl -s "$CLIENT_URL/api/benchmark/health" | jq '.' || echo "❌ RestGrpcClient not running on port 9090"

echo ""
echo "2. Checking if target REST service is running..."
curl -s "$SERVER_URL/api/health" | jq '.' || echo "❌ REST service not running on port 8080"

echo ""
echo "3. Testing individual REST call..."
curl -s -X POST "$CLIENT_URL/api/benchmark/rest" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "rest-test-001",
    "content": "REST test message",
    "timestamp": "2025-06-18T09:00:00Z",
    "protocol": "CLIENT"
  }' | jq '.'

echo ""
echo "4. Testing individual gRPC Unary call..."
curl -s -X POST "$CLIENT_URL/api/benchmark/grpc/unary" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "grpc-unary-test-001",
    "content": "gRPC Unary test message",
    "timestamp": "2025-06-18T09:00:00Z",
    "protocol": "CLIENT"
  }' | jq '.'

echo ""
echo "5. Testing individual gRPC Streaming call..."
curl -s -X POST "$CLIENT_URL/api/benchmark/grpc/streaming" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "grpc-streaming-test-001",
    "content": "gRPC Streaming test message",
    "timestamp": "2025-06-18T09:00:00Z",
    "protocol": "CLIENT"
  }' | jq '.'

echo ""
echo "6. Running single call comparison (all protocols)..."
curl -s -X POST "$CLIENT_URL/api/benchmark/single" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "comparison-test-001",
    "content": "Performance comparison test",
    "timestamp": "2025-06-18T09:00:00Z",
    "protocol": "CLIENT"
  }' | jq '.'

echo ""
echo "7. Running small load test (10 calls)..."
curl -s -X POST "$CLIENT_URL/api/benchmark/load?calls=10" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "load-test-001",
    "content": "Load test message",
    "timestamp": "2025-06-18T09:00:00Z",
    "protocol": "CLIENT"
  }' | jq '.'

echo ""
echo "✅ All tests completed!"
echo ""
echo "💡 Tips:"
echo "   - For better performance comparison, run larger load tests"
echo "   - Monitor logs for detailed timing information"
echo "   - Try different payload sizes to see how protocols compare"
echo "" 