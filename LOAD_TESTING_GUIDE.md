# Load Testing Guide - REST vs gRPC Client

This guide explains how to perform load testing on the RestGrpcClient service to compare the performance of REST and gRPC protocols.

## Overview

The RestGrpcClient service exposes separate endpoints for testing each protocol:

- **REST**: `/api/benchmark/rest` - Calls the REST endpoint of the main service
- **gRPC Unary**: `/api/benchmark/grpc/unary` - Calls the gRPC unary endpoint 
- **gRPC Streaming**: `/api/benchmark/grpc/streaming` - Calls the gRPC bidirectional streaming endpoint

## Prerequisites

### 1. Install K6
```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Windows
choco install k6
```

### 2. Start Required Services

**Terminal 1 - Main Service:**
```bash
# Start Kafka (if not already running)
docker-compose -f docker-compose-kafka.yml up -d

# Start Spanner Emulator (if needed)
gcloud emulators spanner start --host-port=localhost:9010 &

# Start main service
mvn spring-boot:run
```

**Terminal 2 - Client Service:**
```bash
cd rest-grpc-client
mvn spring-boot:run
```

### 3. Verify Services are Running
```bash
# Test main service
curl http://localhost:8080/camel/api/health

# Test client service
curl http://localhost:9090/api/benchmark/health
```

## Load Testing Scripts

### Available K6 Scripts

1. **`k6-client-rest-load.js`** - Load test REST endpoint
2. **`k6-client-grpc-unary-load.js`** - Load test gRPC unary endpoint
3. **`k6-client-grpc-streaming-load.js`** - Load test gRPC streaming endpoint

### Load Test Configuration

Each script uses the following load pattern:
- **Ramp up**: 30s to reach 20 users
- **Sustain**: 1 minute at 50 users  
- **Ramp up**: 30s to reach 100 users
- **Peak load**: 2 minutes at 100 users
- **Ramp down**: 30s to 0 users

**Total duration**: ~4.5 minutes per test

### Performance Thresholds

- **95th percentile response time**: < 500ms
- **Error rate**: < 10%

## Running Load Tests

### Option 1: Individual Tests

Run each test separately:

```bash
# Test REST endpoint
k6 run k6-client-rest-load.js

# Test gRPC Unary endpoint  
k6 run k6-client-grpc-unary-load.js

# Test gRPC Streaming endpoint
k6 run k6-client-grpc-streaming-load.js
```

### Option 2: Automated Test Suite

Run all tests sequentially with comparison report:

```bash
./run-client-load-tests.sh
```

This script will:
1. Verify both services are running
2. Run all three load tests sequentially
3. Generate a comparison report
4. Save detailed results in JSON format

### Option 3: Quick Endpoint Verification

Before running full load tests, verify endpoints work:

```bash
./test-client-endpoints.sh
```

## Understanding Results

### Key Metrics

- **Total Requests**: Number of requests sent
- **Failed Requests**: Number of failed requests
- **Error Rate**: Percentage of failed requests
- **Average Response Time**: Mean response time in milliseconds
- **95th Percentile**: 95% of requests completed under this time
- **Max Response Time**: Longest response time observed
- **Throughput**: Requests per second

### Result Files

Results are saved in the `load-test-results/` directory:
- `rest-load-test-results.json`
- `grpc-unary-load-test-results.json` 
- `grpc-streaming-load-test-results.json`

### Sample Output

```
========================================
REST CLIENT RESULTS:
========================================
Total Requests:       1250 requests
Failed Requests:         0 requests
Error Rate:           0.00%
Avg Response Time:   45.32 ms
95th Percentile:    125.67 ms
Max Response Time:  234.12 ms
Throughput:          18.52 req/s
========================================
```

## Customizing Load Tests

### Adjusting Load Patterns

Edit the `options.stages` in each K6 script:

```javascript
export let options = {
  stages: [
    { duration: '30s', target: 10 },   // Light load
    { duration: '1m', target: 25 },    // Medium load
    { duration: '30s', target: 50 },   // High load
    { duration: '2m', target: 50 },    // Sustained high load
    { duration: '30s', target: 0 },    // Ramp down
  ],
};
```

### Modifying Thresholds

Adjust performance expectations:

```javascript
thresholds: {
  http_req_duration: ['p(95)<200'],  // Stricter: 95% under 200ms
  error_rate: ['rate<0.05'],         // Stricter: < 5% error rate
},
```

### Changing Test Data

Modify the payload in each script:

```javascript
const payload = {
  id: `custom-test-${__VU}-${__ITER}`,
  content: `Custom message with more data...`,
  timestamp: new Date().toISOString(),
};
```

## GCP Deployment Testing

When deployed to GCP, update the `BASE_URL` in each K6 script:

```javascript
// For GCP deployment
const BASE_URL = 'https://your-client-service-url';

// For local testing
const BASE_URL = 'http://localhost:9090';
```

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Verify services are running on correct ports
   - Check firewall settings

2. **High Error Rates**
   - Reduce load (lower target users)
   - Check service logs for errors
   - Verify database/Kafka connectivity

3. **Slow Response Times**
   - Monitor resource usage (CPU, memory)
   - Check network latency
   - Review service configuration

### Debugging Commands

```bash
# Check service status
curl -v http://localhost:9090/api/benchmark/health
curl -v http://localhost:8080/camel/api/health

# Monitor service logs
tail -f rest-grpc-client/client.log
tail -f app.log

# Check resource usage
top -p $(pgrep -f "spring-boot")
```

## Performance Optimization Tips

1. **JVM Tuning**
   ```bash
   export MAVEN_OPTS="-Xmx2g -Xms1g -XX:+UseG1GC"
   ```

2. **Connection Pooling**
   - Configure HTTP client connection pools
   - Tune gRPC channel settings

3. **Database Optimization**
   - Use connection pooling
   - Optimize queries
   - Consider read replicas

4. **Monitoring**
   - Add application metrics
   - Monitor JVM metrics
   - Track custom business metrics

## Next Steps

1. Run baseline tests locally
2. Deploy to GCP and rerun tests
3. Compare local vs cloud performance
4. Identify bottlenecks and optimize
5. Set up continuous performance testing

For more advanced testing scenarios, consider:
- Gradual load increase tests
- Spike testing
- Endurance testing
- Multi-region testing 