# GCP Deployment and Load Testing Guide

## Overview

This guide covers deploying the REST vs gRPC service to Google Cloud Platform (GCP) and running comprehensive load tests to compare performance between REST, gRPC Unary, and gRPC Streaming protocols.

## Architecture

- **Main Service**: REST and gRPC endpoints with Spanner and Kafka integration
- **Client Service**: Load testing client with benchmark endpoints
- **Infrastructure**: GKE cluster with Cloud Spanner and managed Kafka
- **Load Testing**: K6 scripts for comprehensive performance analysis

## Prerequisites

### Local Requirements
- Docker installed and running
- kubectl configured
- gcloud CLI installed and authenticated
- K6 installed for load testing
- Maven for building the application

### GCP Resources Required
- GKE cluster: `rest-grpc-cluster`
- Cloud Spanner instance: `restvsgrpc-instance`
- Artifact Registry repository: `rest-grpc-repo`
- Service account with appropriate permissions
- Managed Kafka instance (or Kafka running in cluster)

## Deployment Steps

### 1. Pre-deployment Verification

Ensure all services are working locally:

```bash
# Test local services
./test-client-endpoints.sh

# Run quick K6 test
k6 run k6-quick-test.js
```

### 2. Deploy to GCP

Run the automated deployment script:

```bash
./deploy-to-gcp.sh
```

This script will:
- Build the Maven application
- Create and push Docker image to Artifact Registry
- Deploy to GKE cluster
- Set up service account secrets
- Verify deployment health
- Generate load test configuration

### 3. Manual Deployment (Alternative)

If you prefer manual deployment:

```bash
# Build application
mvn clean package -DskipTests

# Build and push Docker image
docker build -t australia-southeast2-docker.pkg.dev/silent-oxide-210505/rest-grpc-repo/rest-grpc-service:latest .
docker push australia-southeast2-docker.pkg.dev/silent-oxide-210505/rest-grpc-repo/rest-grpc-service:latest

# Deploy to Kubernetes
kubectl apply -f k8s/

# Wait for deployment
kubectl rollout status deployment/rest-grpc-service
```

## Load Testing

### Quick Validation Test

```bash
# Test with local client service
k6 run k6-quick-test.js

# Test with GCP deployment
k6 run --env BASE_URL=http://YOUR_EXTERNAL_IP:9090 k6-quick-test.js
```

### Comprehensive Load Test

```bash
# Run full GCP load test (15+ minutes)
k6 run --env BASE_URL=http://YOUR_EXTERNAL_IP:9090 k6-gcp-load-test.js
```

### Individual Protocol Tests

```bash
# Test REST only
k6 run --env BASE_URL=http://YOUR_EXTERNAL_IP:9090 k6-client-rest-load.js

# Test gRPC Unary only
k6 run --env BASE_URL=http://YOUR_EXTERNAL_IP:9090 k6-client-grpc-unary-load.js

# Test gRPC Streaming only
k6 run --env BASE_URL=http://YOUR_EXTERNAL_IP:9090 k6-client-grpc-streaming-load.js
```

## Load Test Configuration

### Test Stages

The comprehensive GCP load test includes:

1. **Warm-up**: 1 minute, 10 users
2. **Moderate Load**: 2 minutes, 50 users
3. **High Load**: 2 minutes, 100 users
4. **Peak Load**: 5 minutes, 100 users
5. **Stress Test**: 2 minutes, 150 users
6. **Spike Test**: 1 minute, 200 users
7. **Ramp Down**: 2 minutes, 0 users

### Performance Thresholds

- **Response Time**: 95th percentile < 2000ms
- **Error Rate**: < 5%
- **Protocol-specific thresholds**:
  - REST: P95 < 1500ms
  - gRPC Unary: P95 < 1500ms
  - gRPC Streaming: P95 < 1000ms

## Monitoring and Metrics

### Custom Metrics Collected

- **Request Counts**: Per protocol
- **Response Times**: Average and percentiles
- **Error Rates**: Per protocol
- **Throughput**: Requests per second

### GCP Monitoring

Monitor your deployment using:

```bash
# Check pod status
kubectl get pods

# Check service status
kubectl get services

# View logs
kubectl logs -f deployment/rest-grpc-service

# Check resource usage
kubectl top pods
```

## Expected Performance Results

Based on local testing, expected performance rankings:

1. **gRPC Streaming**: ~54ms average (fastest)
2. **REST**: ~216ms average
3. **gRPC Unary**: ~230ms average

GCP deployment may show different results due to:
- Network latency
- Cloud Spanner performance
- Managed Kafka latency
- GKE cluster resources

## Troubleshooting

### Common Issues

1. **Service not accessible**:
   ```bash
   kubectl get svc rest-grpc-service
   kubectl describe svc rest-grpc-service
   ```

2. **Pod not starting**:
   ```bash
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

3. **Spanner connection issues**:
   - Verify service account permissions
   - Check Spanner instance is running
   - Validate database schema

4. **Kafka connection issues**:
   - Verify Kafka cluster is accessible
   - Check network policies
   - Validate authentication credentials

### Health Checks

```bash
# Main service health
curl http://YOUR_EXTERNAL_IP:8080/actuator/health

# Client service health
curl http://YOUR_EXTERNAL_IP:9090/actuator/health

# Test endpoints
curl -X POST http://YOUR_EXTERNAL_IP:9090/api/benchmark/single \
  -H "Content-Type: application/json" \
  -d '{"id":"test","content":"Test message","timestamp":"2025-06-18T10:00:00Z","protocol":"TEST"}'
```

## Performance Analysis

### Metrics to Analyze

1. **Throughput**: Requests per second per protocol
2. **Latency**: Average, P95, P99 response times
3. **Error Rates**: Success/failure ratios
4. **Resource Utilization**: CPU, memory usage
5. **Scalability**: Performance under increasing load

### Expected Insights

- **gRPC Streaming**: Should show lowest latency due to persistent connections
- **REST**: Moderate performance, good for general use cases
- **gRPC Unary**: May show higher latency due to connection overhead
- **Load Scaling**: Performance degradation patterns under high load

## Cleanup

To clean up GCP resources:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete Docker images (optional)
gcloud artifacts docker images delete australia-southeast2-docker.pkg.dev/silent-oxide-210505/rest-grpc-repo/rest-grpc-service:latest
```

## Results Documentation

After running load tests, document:

1. **Performance Comparison**: Response times per protocol
2. **Scalability Analysis**: Performance at different load levels
3. **Resource Usage**: CPU/memory consumption
4. **Error Analysis**: Types and frequencies of errors
5. **Recommendations**: Optimal protocol for different use cases

## Next Steps

1. Run comprehensive load tests
2. Analyze performance metrics
3. Document findings and recommendations
4. Consider optimizations based on results
5. Plan production deployment strategy 