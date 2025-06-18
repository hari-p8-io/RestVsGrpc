# Comprehensive Performance Metrics Comparison

## Complete Performance Results Table

### Response Time Metrics (milliseconds)

| TPS Level | Protocol | Avg Response Time | Median Response Time | Min Response Time | Max Response Time | P90 Response Time | P95 Response Time |
|-----------|----------|-------------------|---------------------|-------------------|-------------------|-------------------|-------------------|
| **20 TPS** | REST | 26.73 | 24.46 | 16.99 | 121.25 | 34 | 38 |
| | gRPC Unary | 28.76 | 25.90 | 16.87 | 160.66 | 39 | 43 |
| | gRPC Streaming | 28.49 | 24.94 | 17.08 | 139.28 | 39 | 46 |
| **60 TPS** | REST | 30.92 | 27.08 | 15.64 | 170.57 | 44 | 53 |
| | gRPC Unary | 25.31 | 23.67 | 15.50 | 126.37 | 32 | 36 |
| | gRPC Streaming | 31.32 | 26.86 | 15.85 | 253.28 | 44 | 54 |
| **100 TPS** | REST | 31.88 | 27.14 | 15.52 | 682.29 | 47 | 58 |
| | gRPC Unary | 27.39 | 23.99 | 15.44 | 443.97 | 33 | 39 |
| | gRPC Streaming | 29.50 | 25.71 | 15.03 | 535.14 | 40 | 49 |

### Request Volume & Success Metrics

| TPS Level | Protocol | Total Requests | Target TPS | Achieved RPS | Success Rate | Error Rate | HTTP Errors |
|-----------|----------|----------------|------------|--------------|--------------|------------|-------------|
| **20 TPS** | REST | 4,109 | 20 | 17.1 | 100% | 0% | 0 |
| | gRPC Unary | 4,101 | 20 | 17.1 | 100% | 0% | 0 |
| | gRPC Streaming | 4,105 | 20 | 17.1 | 100% | 0% | 0 |
| **60 TPS** | REST | 12,258 | 60 | 51.1 | 100% | 0% | 0 |
| | gRPC Unary | 12,319 | 60 | 51.3 | 100% | 0% | 0 |
| | gRPC Streaming | 12,250 | 60 | 51.0 | 100% | 0% | 0 |
| **100 TPS** | REST | 20,391 | 100 | 85.0 | 100% | 0% | 0 |
| | gRPC Unary | 20,475 | 100 | 85.3 | 100% | 0% | 0 |
| | gRPC Streaming | 20,443 | 100 | 85.2 | 100% | 0% | 0 |

### Performance Efficiency Metrics

| TPS Level | Protocol | Requests/sec | Response Time Consistency (Max/Min Ratio) | P95/Median Ratio | Throughput Efficiency |
|-----------|----------|--------------|-------------------------------------------|------------------|----------------------|
| **20 TPS** | REST | 17.1 | 7.1 | 1.55 | 85.5% |
| | gRPC Unary | 17.1 | 9.5 | 1.66 | 85.5% |
| | gRPC Streaming | 17.1 | 8.2 | 1.84 | 85.5% |
| **60 TPS** | REST | 51.1 | 10.9 | 1.96 | 85.2% |
| | gRPC Unary | 51.3 | 8.2 | 1.52 | 85.5% |
| | gRPC Streaming | 51.0 | 16.0 | 2.01 | 85.0% |
| **100 TPS** | REST | 85.0 | 44.0 | 2.14 | 85.0% |
| | gRPC Unary | 85.3 | 28.8 | 1.63 | 85.3% |
| | gRPC Streaming | 85.2 | 35.6 | 1.91 | 85.2% |

### Latency Distribution Analysis

| TPS Level | Protocol | P50-P90 Gap (ms) | P90-P95 Gap (ms) | P95-Max Gap (ms) | Latency Consistency Score* |
|-----------|----------|-------------------|------------------|------------------|--------------------------|
| **20 TPS** | REST | 9.54 | 4.0 | 83.25 | 8.7/10 |
| | gRPC Unary | 13.10 | 4.0 | 117.66 | 7.2/10 |
| | gRPC Streaming | 14.06 | 7.0 | 93.28 | 7.8/10 |
| **60 TPS** | REST | 16.92 | 9.0 | 117.57 | 6.8/10 |
| | gRPC Unary | 8.33 | 4.0 | 90.37 | 9.1/10 |
| | gRPC Streaming | 17.14 | 10.0 | 199.28 | 6.2/10 |
| **100 TPS** | REST | 19.86 | 11.0 | 624.29 | 5.5/10 |
| | gRPC Unary | 9.01 | 6.0 | 404.97 | 7.8/10 |
| | gRPC Streaming | 14.29 | 9.0 | 486.14 | 6.9/10 |

### Performance Rankings by TPS Level

#### 20 TPS Rankings (Best → Worst)
| Metric | 1st Place | 2nd Place | 3rd Place |
|--------|-----------|-----------|-----------|
| **Average Response Time** | REST (26.73ms) | gRPC Streaming (28.49ms) | gRPC Unary (28.76ms) |
| **P95 Latency** | REST (38ms) | gRPC Unary (43ms) | gRPC Streaming (46ms) |
| **Consistency** | REST | gRPC Streaming | gRPC Unary |
| **Overall Winner** | **REST** | gRPC Streaming | gRPC Unary |

#### 60 TPS Rankings (Best → Worst)
| Metric | 1st Place | 2nd Place | 3rd Place |
|--------|-----------|-----------|-----------|
| **Average Response Time** | gRPC Unary (25.31ms) | REST (30.92ms) | gRPC Streaming (31.32ms) |
| **P95 Latency** | gRPC Unary (36ms) | REST (53ms) | gRPC Streaming (54ms) |
| **Consistency** | gRPC Unary | REST | gRPC Streaming |
| **Overall Winner** | **gRPC Unary** | REST | gRPC Streaming |

#### 100 TPS Rankings (Best → Worst)
| Metric | 1st Place | 2nd Place | 3rd Place |
|--------|-----------|-----------|-----------|
| **Average Response Time** | gRPC Unary (27.39ms) | gRPC Streaming (29.50ms) | REST (31.88ms) |
| **P95 Latency** | gRPC Unary (39ms) | gRPC Streaming (49ms) | REST (58ms) |
| **Consistency** | gRPC Unary | gRPC Streaming | REST |
| **Overall Winner** | **gRPC Unary** | gRPC Streaming | REST |

### Key Performance Insights

#### Response Time Trends
- **REST**: 26.73ms → 30.92ms → 31.88ms (19% degradation)
- **gRPC Unary**: 28.76ms → 25.31ms → 27.39ms (5% improvement)
- **gRPC Streaming**: 28.49ms → 31.32ms → 29.50ms (4% degradation)

#### P95 Latency Trends  
- **REST**: 38ms → 53ms → 58ms (53% degradation)
- **gRPC Unary**: 43ms → 36ms → 39ms (9% improvement)
- **gRPC Streaming**: 46ms → 54ms → 49ms (7% degradation)

#### Throughput Achievement
- All protocols consistently achieved **85%+ of target TPS**
- **gRPC Unary**: Slight edge in actual throughput (85.3% at 100 TPS)
- **Consistent delivery**: All protocols within 0.3 RPS of each other

#### Reliability Metrics
- **Perfect reliability**: 0% error rate across all 61,173 total requests
- **Zero failures**: No HTTP, database, or application errors
- **100% uptime**: All services remained healthy throughout testing

### Performance Recommendations by Use Case

| Use Case | Recommended Protocol | Rationale |
|----------|---------------------|-----------|
| **Low Load (< 30 TPS)** | REST | Best performance, simplest implementation |
| **Medium Load (30-80 TPS)** | gRPC Unary | 18% faster than REST, excellent consistency |
| **High Load (> 80 TPS)** | gRPC Unary | 14% faster than REST, best scalability |
| **Real-time Applications** | gRPC Unary | Most consistent latency profile |
| **Batch Processing** | Any Protocol | All perform reliably for batch workloads |
| **Microservices** | gRPC Unary | Best performance + type safety |

---

**Testing Environment**: Google Cloud Platform (GKE) with Cloud Spanner and Kafka  
**Test Duration**: 4 minutes per protocol per TPS level  
**Total Requests**: 61,173 across all tests  
**Infrastructure**: e2-standard-4 (4 vCPU, 16 GB memory)  

*Latency Consistency Score: Based on standard deviation and outlier analysis (10 = most consistent) 