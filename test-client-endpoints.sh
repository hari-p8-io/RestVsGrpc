#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}TESTING REST vs gRPC CLIENT ENDPOINTS${NC}"
echo -e "${BLUE}============================================${NC}"

# Test payload
PAYLOAD='{
  "id": "test-endpoint-001",
  "content": "Testing client endpoints",
  "timestamp": "2025-06-18T10:30:00Z"
}'

BASE_URL="http://localhost:9090"

# Function to test an endpoint
test_endpoint() {
    local endpoint=$1
    local name=$2
    
    echo -e "${YELLOW}Testing $name endpoint: $endpoint${NC}"
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL$endpoint" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1 2>/dev/null || echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ $name: Success (HTTP $http_code)${NC}"
        echo "Response: $body"
    else
        echo -e "${RED}✗ $name: Failed (HTTP $http_code)${NC}"
        echo "Response: $body"
    fi
    echo ""
}

# Check if client is running
echo -e "${YELLOW}Checking if RestGrpcClient is running...${NC}"
health_response=$(curl -s http://localhost:9090/api/benchmark/health)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ RestGrpcClient is running${NC}"
    echo "Health response: $health_response"
    echo ""
else
    echo -e "${RED}✗ RestGrpcClient is not running on port 9090${NC}"
    echo -e "${YELLOW}Please start the client: cd rest-grpc-client && mvn spring-boot:run${NC}"
    exit 1
fi

# Test all endpoints
test_endpoint "/api/benchmark/single" "Single Call Comparison"
test_endpoint "/api/benchmark/rest" "REST Only"
test_endpoint "/api/benchmark/grpc/unary" "gRPC Unary Only"
test_endpoint "/api/benchmark/grpc/streaming" "gRPC Streaming Only"

# Test health check for target service
echo -e "${YELLOW}Testing target service health check...${NC}"
health_check_response=$(curl -s http://localhost:9090/api/benchmark/health/rest)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Target service health check: Success${NC}"
    echo "Response: $health_check_response"
else
    echo -e "${RED}✗ Target service health check: Failed${NC}"
fi

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Endpoint testing completed!${NC}"
echo -e "${BLUE}============================================${NC}" 