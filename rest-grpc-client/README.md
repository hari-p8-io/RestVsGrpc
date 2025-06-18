# RestGrpcClient Service

A Spring Boot client service for testing and benchmarking REST vs gRPC performance, including bidirectional streaming support.

## Overview

This service provides a comprehensive testing framework for comparing the performance of:
- **REST API calls** (HTTP/JSON)
- **gRPC Unary calls** (traditional request-response)
- **gRPC Bidirectional Streaming** (real-time streaming communication)

## Features

- 🚀 **Performance Benchmarking**: Compare REST vs gRPC performance
- 📊 **Load Testing**: Run concurrent requests to test throughput
- 🔄 **Streaming Support**: Test bidirectional gRPC streaming
- 📈 **Metrics Collection**: Detailed performance metrics and statistics
- 🎯 **Easy API**: Simple REST endpoints for triggering tests

## Architecture

```
RestGrpcClient (Port 9090)
    ↓
    ├── REST Client → RestVsGrpc Service (Port 8080)
    └── gRPC Client → RestVsGrpc Service (Port 6565/6566)
```

## Quick Start

### 1. Build the Service

```bash
mvn clean compile
```

### 2. Run the Service

```bash
mvn spring-boot:run
```

The service will start on port **9090**.

### 3. Configure Target Services

Update `application.yml` to point to your target services:

```yaml
rest:
  server:
    host: localhost  # or your service host
    port: 8080

grpc:
  server:
    host: localhost  # or your service host
    port: 6565       # or 6566 for the new streaming server
```

## API Endpoints

### Health Check
```bash
GET /api/benchmark/health
```

### Single Call Comparison
Compare all three protocols with a single request:

```bash
POST /api/benchmark/single
Content-Type: application/json

{
  "id": "test-001",
  "content": "Test message",
  "timestamp": "2025-06-18T09:00:00Z",
  "protocol": "CLIENT"
}
```

**Response:**
```json
{
  "REST": {
    "protocol": "REST",
    "duration": 45,
    "status": "success",
    "message": "correlation-id-123",
    "startTime": 1718676000000,
    "endTime": 1718676000045
  },
  "gRPC_Unary": {
    "protocol": "gRPC_Unary",
    "duration": 38,
    "status": "success",
    "message": "correlation-id-456",
    "startTime": 1718676000100,
    "endTime": 1718676000138
  },
  "gRPC_Streaming": {
    "protocol": "gRPC_Streaming",
    "duration": 42,
    "status": "success",
    "message": "correlation-id-789",
    "startTime": 1718676000200,
    "endTime": 1718676000242
  }
}
```

### Load Testing
Run concurrent requests to test throughput:

```bash
POST /api/benchmark/load?calls=100
Content-Type: application/json

{
  "id": "load-test",
  "content": "Load test message",
  "timestamp": "2025-06-18T09:00:00Z",
  "protocol": "CLIENT"
}
```

**Response:**
```json
{
  "REST": {
    "protocol": "REST",
    "totalCalls": 100,
    "successCount": 98,
    "errorCount": 2,
    "totalDuration": 2500,
    "averageDuration": 25.0,
    "throughput": 40.0
  },
  "gRPC_Unary": {
    "protocol": "gRPC_Unary",
    "totalCalls": 100,
    "successCount": 100,
    "errorCount": 0,
    "totalDuration": 2200,
    "averageDuration": 22.0,
    "throughput": 45.45
  },
  "gRPC_Streaming": {
    "protocol": "gRPC_Streaming",
    "totalCalls": 100,
    "successCount": 99,
    "errorCount": 1,
    "totalDuration": 2100,
    "averageDuration": 21.0,
    "throughput": 47.62
  }
}
```

### Individual Protocol Testing

#### Test REST Only
```bash
POST /api/benchmark/rest
Content-Type: application/json

{
  "id": "rest-test",
  "content": "REST test message",
  "timestamp": "2025-06-18T09:00:00Z",
  "protocol": "CLIENT"
}
```

#### Test gRPC Unary Only
```bash
POST /api/benchmark/grpc/unary
Content-Type: application/json

{
  "id": "grpc-test",
  "content": "gRPC test message",
  "timestamp": "2025-06-18T09:00:00Z",
  "protocol": "CLIENT"
}
```

#### Test gRPC Streaming Only
```bash
POST /api/benchmark/grpc/streaming
Content-Type: application/json

{
  "id": "streaming-test",
  "content": "Streaming test message",
  "timestamp": "2025-06-18T09:00:00Z",
  "protocol": "CLIENT"
}
```

#### Check Target REST Service Health
```bash
GET /api/benchmark/health/rest
```

## Protocol Comparison

| Feature | REST | gRPC Unary | gRPC Streaming |
|---------|------|------------|----------------|
| **Transport** | HTTP/1.1 | HTTP/2 | HTTP/2 |
| **Serialization** | JSON | Protobuf | Protobuf |
| **Connection** | Request/Response | Request/Response | Bidirectional Stream |
| **Overhead** | Higher | Lower | Lowest |
| **Browser Support** | Native | Limited | Limited |
| **Streaming** | No | No | Yes |
| **Type Safety** | Runtime | Compile-time | Compile-time |

## Performance Testing Scenarios

### 1. Latency Testing
```bash
# Single call comparison
curl -X POST http://localhost:9090/api/benchmark/single \
  -H "Content-Type: application/json" \
  -d '{"id":"latency-test","content":"Quick test","timestamp":"2025-06-18T09:00:00Z","protocol":"CLIENT"}'
```

### 2. Throughput Testing
```bash
# 1000 concurrent calls
curl -X POST "http://localhost:9090/api/benchmark/load?calls=1000" \
  -H "Content-Type: application/json" \
  -d '{"id":"throughput-test","content":"Load test","timestamp":"2025-06-18T09:00:00Z","protocol":"CLIENT"}'
```

### 3. Streaming Performance
```bash
# Test streaming specifically
curl -X POST http://localhost:9090/api/benchmark/grpc/streaming \
  -H "Content-Type: application/json" \
  -d '{"id":"stream-test","content":"Streaming test","timestamp":"2025-06-18T09:00:00Z","protocol":"CLIENT"}'
```

## Configuration

### Application Properties
```yaml
server:
  port: 9090

# Target service configuration
rest:
  server:
    host: localhost
    port: 8080

grpc:
  server:
    host: localhost
    port: 6565  # or 6566 for streaming server

# Logging
logging:
  level:
    com.benchmark.client: INFO
    io.grpc: INFO
```

## Development

### Project Structure
```
rest-grpc-client/
├── src/main/java/com/benchmark/client/
│   ├── controller/         # REST controllers
│   ├── service/           # Business logic
│   ├── config/            # Configuration classes
│   └── dto/               # Data transfer objects
├── src/main/proto/        # Protocol buffer definitions
└── src/main/resources/    # Configuration files
```

### Building
```bash
mvn clean compile
mvn spring-boot:run
```

### Testing
```bash
mvn test
```

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Ensure target services are running
   - Check host/port configuration

2. **gRPC Errors**
   - Verify proto file compatibility
   - Check gRPC server is running on correct port

3. **Timeout Issues**
   - Increase timeout values in application.yml
   - Check network connectivity

### Debugging
Enable debug logging:
```yaml
logging:
  level:
    com.benchmark.client: DEBUG
    io.grpc: DEBUG
```

## Performance Tips

1. **For REST**: Use connection pooling
2. **For gRPC**: Reuse channels
3. **For Streaming**: Batch multiple requests
4. **General**: Run on same network for accurate benchmarks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License. 