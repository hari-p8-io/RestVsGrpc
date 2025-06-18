# Load Testing Configuration

This document explains how to configure the load testing suite to work with different environments.

## Environment Variables

The load testing scripts use environment variables to avoid hardcoded IP addresses. Set these variables before running the tests:

### Required Variables

- `CLIENT_BASE_URL`: URL of the client service that K6 tests will target
- `MAIN_SERVICE_URL`: URL of the main service for health checks

### Default Values

If not set, the scripts will use localhost defaults:
- `CLIENT_BASE_URL`: `http://localhost:9090`
- `MAIN_SERVICE_URL`: `http://localhost:8080`

## Usage Examples

### Local Development
```bash
export CLIENT_BASE_URL=http://localhost:9090
export MAIN_SERVICE_URL=http://localhost:8080
./run-comprehensive-load-tests.sh
```

### GCP Deployment
```bash
export CLIENT_BASE_URL=http://your-client-ip:9090
export MAIN_SERVICE_URL=http://your-main-service-ip:8080
./run-comprehensive-load-tests.sh
```

### Running Individual K6 Tests
```bash
export CLIENT_BASE_URL=http://your-client-ip:9090
k6 run k6-gcp-rest-60tps.js
```

## Configuration Validation

The comprehensive test script (`run-comprehensive-load-tests.sh`) includes validation that:
- Checks if environment variables are set
- Warns when using default localhost values
- Validates service health before starting tests

## Security Note

Never commit hardcoded production IP addresses to version control. Always use environment variables for environment-specific configurations. 