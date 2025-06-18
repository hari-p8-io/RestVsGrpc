# REST vs gRPC Performance Testing with RabbitMQ Integration (100 TPS)

## Overview
This enhanced benchmark tests REST vs gRPC performance at 100 TPS with full RabbitMQ integration, measuring end-to-end latency from API request to message queue delivery with transactional consistency.

## Key Features
- **100 TPS Load Testing**: Constant arrival rate of 100 requests per second
- **RabbitMQ Integration**: Transactional DB + Queue writes
- **End-to-End Latency**: Measures time from request to queue message
- **Separate Queues**: REST and gRPC use different queues for isolation
- **Correlation Tracking**: Each request tracked with unique correlation ID
- **Transactional Consistency**: DB and RabbitMQ operations are atomic

## Architecture Changes

### Application Enhancements
1. **TransactionalPayloadService**: Handles atomic DB + RabbitMQ operations
2. **RabbitMQ Configuration**: Topic exchange with protocol-specific routing
3. **Enhanced DTOs**: Added timing and protocol information
4. **Correlation Tracking**: UUID-based request correlation

### Infrastructure Components
- **Spring Boot Application**: REST + gRPC endpoints
- **RabbitMQ**: Message broker with management UI
- **H2 Database**: Transactional data persistence
- **GKE Autopilot**: Kubernetes orchestration

### Queue Architecture
```
payload-exchange (Topic Exchange)
├── rest-payload-queue (routing: rest.payload.new)
└── grpc-payload-queue (routing: grpc.payload.new)
```

## Deployment Instructions

### 1. Setup GKE Cluster
```bash
./gke-setup.sh
```

### 2. Build and Deploy with RabbitMQ
```bash
./build-and-deploy.sh
```
This will:
- Deploy RabbitMQ with management UI
- Build and deploy the enhanced application
- Wait for all services to be ready

### 3. Verify Deployment
```bash
kubectl get pods
kubectl get services
```

Expected services:
- `rest-grpc-service` (LoadBalancer)
- `rabbitmq-service` (ClusterIP)
- `rabbitmq-management` (LoadBalancer)

### 4. Access RabbitMQ Management UI
```bash
kubectl get service rabbitmq-management
# Access via external IP on port 15672
# Credentials: guest/guest
```

## Running Performance Tests

### Run All 100 TPS Tests
```bash
./run-100tps-tests.sh
```

### Run Individual Tests
```bash
# REST only
./run-100tps-tests.sh k6-rest-100tps-rabbitmq.js

# gRPC only  
./run-100tps-tests.sh k6-grpc-100tps-rabbitmq.js
```

## Test Specifications

### Load Profile
- **Rate**: 100 requests/second (constant arrival rate)
- **Duration**: 120 seconds (2 minutes)
- **Virtual Users**: 20-100 (auto-scaling)
- **Total Requests**: ~12,000 per test

### Metrics Collected
1. **HTTP/gRPC Metrics**:
   - Request duration (avg, p95, p99)
   - Success rate
   - Throughput (req/s)

2. **End-to-End Metrics**:
   - API-to-Queue latency
   - Message delivery rate
   - Correlation success rate

3. **RabbitMQ Metrics**:
   - Queue depth
   - Message throughput
   - Processing latency

### Performance Thresholds
- **Request Duration**: p95 < 2000ms
- **Error Rate**: < 5%
- **End-to-End Latency**: p95 < 5000ms
- **Message Delivery**: > 95% success rate

## Transactional Behavior

### REST Flow
1. Receive JSON payload
2. Start transaction
3. Save to H2 database
4. Publish to `rest-payload-queue`
5. Commit transaction
6. Return correlation ID

### gRPC Flow
1. Receive protobuf payload
2. Start transaction
3. Save to H2 database
4. Publish to `grpc-payload-queue`
5. Commit transaction
6. Return correlation ID

### Failure Handling
- Database failure → Transaction rollback, no queue message
- RabbitMQ failure → Transaction rollback, no database save
- Ensures data consistency across systems

## Expected Results

### Performance Comparison
Based on previous testing, expected results:

| Metric | REST | gRPC | Winner |
|--------|------|------|--------|
| Avg Response Time | ~60-80ms | ~30-50ms | gRPC |
| p95 Response Time | ~200-300ms | ~100-150ms | gRPC |
| End-to-End Latency | ~100-150ms | ~60-100ms | gRPC |
| Success Rate | 95-98% | 98-100% | gRPC |
| Message Delivery | 95-98% | 98-100% | gRPC |

### Key Differences
- **gRPC Advantages**: Binary serialization, HTTP/2, connection reuse
- **REST Advantages**: Simpler debugging, wider tooling support
- **RabbitMQ Impact**: Adds ~20-50ms to end-to-end latency

## Monitoring and Analysis

### RabbitMQ Management UI
- Queue statistics and message rates
- Connection and channel monitoring
- Message browsing and debugging

### Application Logs
```bash
kubectl logs deployment/rest-grpc-service -f
```

### Queue Inspection
```bash
# Check queue status
curl -u guest:guest http://<rabbitmq-ip>:15672/api/queues

# Get messages from queue
curl -u guest:guest -X POST \
  http://<rabbitmq-ip>:15672/api/queues/%2F/rest-payload-queue/get \
  -d '{"count":10,"ackmode":"ack_requeue_false"}'
```

## Troubleshooting

### Common Issues
1. **RabbitMQ Connection Failures**:
   - Check service DNS resolution
   - Verify credentials in application.properties

2. **Transaction Rollbacks**:
   - Monitor application logs for exceptions
   - Check database connection health

3. **High Latency**:
   - Monitor RabbitMQ queue depth
   - Check GKE node resource utilization

### Cleanup
```bash
./cleanup-gke.sh
```

## Technical Implementation Details

### Dependencies Added
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
<dependency>
    <groupId>org.apache.camel.springboot</groupId>
    <artifactId>camel-rabbitmq-starter</artifactId>
</dependency>
```

### Configuration Properties
```properties
spring.rabbitmq.host=rabbitmq-service
spring.rabbitmq.port=5672
spring.rabbitmq.username=guest
spring.rabbitmq.password=guest
spring.rabbitmq.publisher-confirm-type=correlated
spring.rabbitmq.publisher-returns=true
```

### Message Structure
```json
{
  "userId": "rest-100tps-1-1",
  "userName": "Load Test User",
  "notificationType": "NEW_PAYLOAD",
  "correlationId": "uuid-string",
  "protocol": "REST",
  "processingStartTime": 1640995200000,
  "timestamp": "2021-12-31T12:00:00Z"
}
```

This comprehensive setup provides a realistic benchmark of REST vs gRPC performance in a production-like environment with full transactional messaging integration. 