package com.benchmark.client.service;

import com.benchmark.client.dto.BenchmarkResult;
import com.benchmark.client.dto.PayloadRequest;
import com.benchmark.client.dto.PayloadResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class BenchmarkService {

    private static final Logger logger = LoggerFactory.getLogger(BenchmarkService.class);

    @Autowired
    private RestClientService restClientService;

    @Autowired
    private GrpcClientService grpcClientService;

    public Map<String, BenchmarkResult> runSingleCallComparison(PayloadRequest request) {
        logger.info("Running single call comparison for request: {}", request);
        
        Map<String, BenchmarkResult> results = new HashMap<>();
        
        // Test REST
        long restStart = System.currentTimeMillis();
        PayloadResponse restResponse = restClientService.sendPayload(request);
        long restEnd = System.currentTimeMillis();
        long restDuration = restEnd - restStart;
        
        results.put("REST", new BenchmarkResult(
            "REST", 
            restDuration, 
            restResponse.getStatus(), 
            restResponse.getMessage(),
            restStart,
            restEnd
        ));
        
        // Test gRPC Unary
        long grpcUnaryStart = System.currentTimeMillis();
        PayloadResponse grpcUnaryResponse = grpcClientService.sendPayloadUnary(request);
        long grpcUnaryEnd = System.currentTimeMillis();
        long grpcUnaryDuration = grpcUnaryEnd - grpcUnaryStart;
        
        results.put("gRPC_Unary", new BenchmarkResult(
            "gRPC_Unary", 
            grpcUnaryDuration, 
            grpcUnaryResponse.getStatus(), 
            grpcUnaryResponse.getMessage(),
            grpcUnaryStart,
            grpcUnaryEnd
        ));
        
        // Test gRPC Streaming
        long grpcStreamStart = System.currentTimeMillis();
        PayloadResponse grpcStreamResponse = grpcClientService.sendPayloadStreaming(request);
        long grpcStreamEnd = System.currentTimeMillis();
        long grpcStreamDuration = grpcStreamEnd - grpcStreamStart;
        
        results.put("gRPC_Streaming", new BenchmarkResult(
            "gRPC_Streaming", 
            grpcStreamDuration, 
            grpcStreamResponse.getStatus(), 
            grpcStreamResponse.getMessage(),
            grpcStreamStart,
            grpcStreamEnd
        ));
        
        logger.info("Single call comparison completed. REST: {}ms, gRPC Unary: {}ms, gRPC Streaming: {}ms", 
                   restDuration, grpcUnaryDuration, grpcStreamDuration);
        
        return results;
    }


} 