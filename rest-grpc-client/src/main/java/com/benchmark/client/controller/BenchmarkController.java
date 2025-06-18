package com.benchmark.client.controller;

import com.benchmark.client.dto.BenchmarkResult;
import com.benchmark.client.dto.PayloadRequest;
import com.benchmark.client.dto.PayloadResponse;
import com.benchmark.client.service.BenchmarkService;
import com.benchmark.client.service.GrpcClientService;
import com.benchmark.client.service.RestClientService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/benchmark")
public class BenchmarkController {

    private static final Logger logger = LoggerFactory.getLogger(BenchmarkController.class);

    @Autowired
    private BenchmarkService benchmarkService;

    @Autowired
    private RestClientService restClientService;

    @Autowired
    private GrpcClientService grpcClientService;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "RestGrpcClient",
            "timestamp", Instant.now().toString()
        ));
    }

    @PostMapping("/single")
    public ResponseEntity<Map<String, BenchmarkResult>> runSingleCallBenchmark(@RequestBody PayloadRequest request) {
        logger.info("Running single call benchmark with request: {}", request);
        
        try {
            Map<String, BenchmarkResult> results = benchmarkService.runSingleCallComparison(request);
            return ResponseEntity.ok(results);
        } catch (Exception e) {
            logger.error("Error running single call benchmark", e);
            return ResponseEntity.internalServerError().build();
        }
    }



    @PostMapping("/rest")
    public ResponseEntity<PayloadResponse> testRest(@RequestBody PayloadRequest request) {
        logger.info("Testing REST endpoint with request: {}", request);
        
        try {
            PayloadResponse response = restClientService.sendPayload(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error testing REST endpoint", e);
            return ResponseEntity.internalServerError().body(
                new PayloadResponse("error", "REST test failed: " + e.getMessage())
            );
        }
    }

    @PostMapping("/grpc/unary")
    public ResponseEntity<PayloadResponse> testGrpcUnary(@RequestBody PayloadRequest request) {
        logger.info("Testing gRPC unary endpoint with request: {}", request);
        
        try {
            PayloadResponse response = grpcClientService.sendPayloadUnary(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error testing gRPC unary endpoint", e);
            return ResponseEntity.internalServerError().body(
                new PayloadResponse("error", "gRPC unary test failed: " + e.getMessage())
            );
        }
    }

    @PostMapping("/grpc/streaming")
    public ResponseEntity<PayloadResponse> testGrpcStreaming(@RequestBody PayloadRequest request) {
        logger.info("Testing gRPC streaming endpoint with request: {}", request);
        
        try {
            PayloadResponse response = grpcClientService.sendPayloadStreaming(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error testing gRPC streaming endpoint", e);
            return ResponseEntity.internalServerError().body(
                new PayloadResponse("error", "gRPC streaming test failed: " + e.getMessage())
            );
        }
    }

    @GetMapping("/health/rest")
    public ResponseEntity<String> testRestHealth() {
        try {
            String response = restClientService.healthCheck();
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error testing REST health", e);
            return ResponseEntity.internalServerError().body(
                "{\"status\":\"DOWN\",\"message\":\"" + e.getMessage() + "\"}"
            );
        }
    }
} 