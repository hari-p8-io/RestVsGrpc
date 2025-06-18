# GKE Deployment Guide for REST vs gRPC Performance Testing

This guide explains how to deploy and run the REST vs gRPC performance tests on Google Kubernetes Engine (GKE).

## Prerequisites

Before you begin, make sure you have:

1. **Google Cloud Account** with billing enabled
2. **Google Cloud CLI** installed and configured
3. **Docker** installed on your local machine
4. **kubectl** installed
5. **Maven** (for building the Java application)
6. **A GCP Project** with the following APIs enabled:
   - Kubernetes Engine API
   - Artifact Registry API

## Quick Start

### 1. Setup GKE Cluster

First, update the configuration variables in the scripts:

```bash
# Edit these variables in all scripts:
PROJECT_ID="silent-oxide-210505"
CLUSTER_NAME="autopilot-cluster-1"
ZONE="australia-southeast2-a"
```

Then run the setup script:

```bash
chmod +x gke-setup.sh
./gke-setup.sh
```

This script will:
- Verify prerequisites
- Create an Artifact Registry repository
- Create a GKE cluster with autoscaling
- Configure kubectl

### 2. Build and Deploy Application

```bash
chmod +x build-and-deploy.sh
./build-and-deploy.sh
```

This script will:
- Build the Spring Boot application
- Create Docker images for the app and k6 tests
- Push images to Artifact Registry
- Deploy the application to GKE
- Expose the service via LoadBalancer

### 3. Run Performance Tests

```bash
chmod +x run-k6-tests.sh
./run-k6-tests.sh
```

This script will:
- Wait for the service to be ready
- Run REST performance tests
- Run gRPC performance tests
- Display results from both tests

### 4. Cleanup Resources

When you're done testing:

```bash
chmod +x cleanup-gke.sh
./cleanup-gke.sh
```

## Manual Deployment Steps

If you prefer to run commands manually:

### 1. Authenticate and Setup

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable container.googleapis.com artifactregistry.googleapis.com
```

### 2. Create Artifact Registry

```bash
gcloud artifacts repositories create rest-grpc-repo \
    --repository-format=docker \
    --location=australia-southeast2 \
    --description="REST vs gRPC test images"
```

### 3. Create GKE Cluster

```bash
gcloud container clusters create rest-grpc-test-cluster \
    --zone=australia-southeast2-a \
    --machine-type=e2-standard-4 \
    --num-nodes=3 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5
```

### 4. Build and Push Images

```bash
# Build application
./mvnw clean package -DskipTests

# Build Docker images
docker build -t rest-grpc-service:latest .
docker build -f Dockerfile.k6 -t k6-loadtest:latest .

# Tag for registry
docker tag rest-grpc-service:latest australia-southeast2-docker.pkg.dev/PROJECT_ID/rest-grpc-repo/rest-grpc-service:latest
docker tag k6-loadtest:latest australia-southeast2-docker.pkg.dev/PROJECT_ID/rest-grpc-repo/k6-loadtest:latest

# Push to registry
docker push australia-southeast2-docker.pkg.dev/PROJECT_ID/rest-grpc-repo/rest-grpc-service:latest
docker push australia-southeast2-docker.pkg.dev/PROJECT_ID/rest-grpc-repo/k6-loadtest:latest
```

### 5. Deploy Application

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 6. Run Tests

```bash
kubectl apply -f k8s/k6-rest-ramp-job-gke.yaml
kubectl apply -f k8s/k6-grpc-ramp-job-gke.yaml
```

## Monitoring and Troubleshooting

### Check Deployment Status

```bash
kubectl get pods
kubectl get services
kubectl describe deployment rest-grpc-service
```

### View Logs

```bash
# Application logs
kubectl logs -l app=rest-grpc-service

# Test job logs
kubectl logs job/k6-rest-ramp-loadtest-gke
kubectl logs job/k6-grpc-ramp-loadtest-gke
```

### Check Resource Usage

```bash
kubectl top nodes
kubectl top pods
```

### Debug Network Issues

```bash
# Test internal connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- sh
# Inside the pod:
curl http://rest-grpc-service:8080/actuator/health
```

## Configuration Options

### Cluster Sizing

For different test scales, adjust the cluster configuration:

- **Small tests**: `e2-standard-2` with 2-3 nodes
- **Medium tests**: `e2-standard-4` with 3-5 nodes  
- **Large tests**: `c2-standard-8` with 5-10 nodes

### Test Configuration

The k6 tests use these files:
- `k6-rest-cluster.js` - REST performance test
- `k6-grpc-cluster.js` - gRPC performance test

Modify these files to adjust:
- Test duration
- Virtual user count
- Request patterns
- Load profiles

### Resource Limits

Adjust resource requests/limits in the job YAML files:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

## Cost Optimization

To minimize costs:

1. **Use Preemptible Nodes**:
   ```bash
   --preemptible
   ```

2. **Set Cluster Autoscaling**:
   ```bash
   --enable-autoscaling --min-nodes=1 --max-nodes=5
   ```

3. **Delete Resources After Testing**:
   ```bash
   ./cleanup-gke.sh
   ```

4. **Use Regional Persistent Disks** only if needed

## Security Considerations

- The service is exposed via LoadBalancer for testing purposes
- In production, consider using Internal LoadBalancer
- Use private clusters for enhanced security
- Enable network policies if needed
- Regularly update cluster and node versions

## Estimated Costs

For a 3-node `e2-standard-4` cluster running for 2 hours:
- **Compute**: ~$1.20/hour × 3 nodes × 2 hours = ~$7.20
- **LoadBalancer**: ~$0.025/hour × 2 hours = ~$0.05
- **Storage**: ~$0.10/month (minimal)
- **Total**: ~$7.25 for 2 hours of testing

Always check current GCP pricing for accurate estimates. 