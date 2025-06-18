package com.benchmark.client.service;

import com.benchmark.client.dto.PayloadRequest;
import com.benchmark.client.dto.PayloadResponse;
import com.benchmark.service.grpc.InputPayload;
import com.benchmark.service.grpc.PayloadServiceGrpc;
import io.grpc.stub.StreamObserver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

@Service
public class GrpcClientService {

    private static final Logger logger = LoggerFactory.getLogger(GrpcClientService.class);

    @Autowired
    private PayloadServiceGrpc.PayloadServiceBlockingStub blockingStub;

    @Autowired
    private PayloadServiceGrpc.PayloadServiceStub asyncStub;

    public PayloadResponse sendPayloadUnary(PayloadRequest request) {
        logger.info("Sending gRPC unary payload: {}", request);
        
        try {
            InputPayload grpcRequest = InputPayload.newBuilder()
                    .setId(request.getId())
                    .setContent(request.getContent())
                    .setTimestamp(request.getTimestamp())
                    .setProtocol("gRPC")
                    .build();

            com.benchmark.service.grpc.PayloadResponse grpcResponse = blockingStub.sendPayload(grpcRequest);
            
            PayloadResponse response = new PayloadResponse(grpcResponse.getStatus(), grpcResponse.getMessage());
            logger.info("Received gRPC unary response: {}", response);
            return response;
        } catch (Exception e) {
            logger.error("Error sending gRPC unary payload", e);
            return new PayloadResponse("error", "gRPC unary call failed: " + e.getMessage());
        }
    }

    public PayloadResponse sendPayloadStreaming(PayloadRequest request) {
        logger.info("Sending gRPC streaming payload: {}", request);
        
        try {
            CountDownLatch latch = new CountDownLatch(1);
            AtomicReference<PayloadResponse> responseRef = new AtomicReference<>();
            AtomicReference<Exception> errorRef = new AtomicReference<>();

            // Create response observer
            StreamObserver<com.benchmark.service.grpc.PayloadResponse> responseObserver = 
                new StreamObserver<com.benchmark.service.grpc.PayloadResponse>() {
                    @Override
                    public void onNext(com.benchmark.service.grpc.PayloadResponse value) {
                        logger.info("Received streaming response: {}", value);
                        responseRef.set(new PayloadResponse(value.getStatus(), value.getMessage()));
                    }

                    @Override
                    public void onError(Throwable t) {
                        logger.error("Streaming error", t);
                        errorRef.set(new RuntimeException(t));
                        latch.countDown();
                    }

                    @Override
                    public void onCompleted() {
                        logger.info("Streaming completed");
                        latch.countDown();
                    }
                };

            // Create request observer
            StreamObserver<InputPayload> requestObserver = asyncStub.streamPayloads(responseObserver);

            // Send the payload
            InputPayload grpcRequest = InputPayload.newBuilder()
                    .setId(request.getId())
                    .setContent(request.getContent())
                    .setTimestamp(request.getTimestamp())
                    .setProtocol("gRPC")
                    .build();

            requestObserver.onNext(grpcRequest);
            requestObserver.onCompleted();

            // Wait for response with timeout
            if (latch.await(30, TimeUnit.SECONDS)) {
                if (errorRef.get() != null) {
                    throw errorRef.get();
                }
                PayloadResponse response = responseRef.get();
                if (response != null) {
                    logger.info("Received gRPC streaming response: {}", response);
                    return response;
                } else {
                    return new PayloadResponse("error", "No response received from streaming call");
                }
            } else {
                return new PayloadResponse("error", "gRPC streaming call timed out");
            }
        } catch (Exception e) {
            logger.error("Error sending gRPC streaming payload", e);
            return new PayloadResponse("error", "gRPC streaming call failed: " + e.getMessage());
        }
    }

    public CompletableFuture<PayloadResponse> sendMultiplePayloadsStreaming(PayloadRequest[] requests) {
        logger.info("Sending {} gRPC streaming payloads", requests.length);
        
        CompletableFuture<PayloadResponse> future = new CompletableFuture<>();
        
        try {
            CountDownLatch latch = new CountDownLatch(requests.length);
            AtomicReference<PayloadResponse> lastResponseRef = new AtomicReference<>();
            AtomicReference<Exception> errorRef = new AtomicReference<>();

            // Create response observer
            StreamObserver<com.benchmark.service.grpc.PayloadResponse> responseObserver = 
                new StreamObserver<com.benchmark.service.grpc.PayloadResponse>() {
                    @Override
                    public void onNext(com.benchmark.service.grpc.PayloadResponse value) {
                        logger.info("Received streaming response: {}", value);
                        lastResponseRef.set(new PayloadResponse(value.getStatus(), value.getMessage()));
                        latch.countDown();
                    }

                    @Override
                    public void onError(Throwable t) {
                        logger.error("Streaming error", t);
                        errorRef.set(new RuntimeException(t));
                        future.completeExceptionally(t);
                    }

                    @Override
                    public void onCompleted() {
                        logger.info("Multiple payloads streaming completed");
                        if (errorRef.get() == null) {
                            future.complete(lastResponseRef.get());
                        }
                    }
                };

            // Create request observer
            StreamObserver<InputPayload> requestObserver = asyncStub.streamPayloads(responseObserver);

            // Send all payloads
            for (PayloadRequest request : requests) {
                InputPayload grpcRequest = InputPayload.newBuilder()
                        .setId(request.getId())
                        .setContent(request.getContent())
                        .setTimestamp(request.getTimestamp())
                        .setProtocol("gRPC")
                        .build();

                requestObserver.onNext(grpcRequest);
            }
            requestObserver.onCompleted();

        } catch (Exception e) {
            logger.error("Error sending multiple gRPC streaming payloads", e);
            future.complete(new PayloadResponse("error", "gRPC multiple streaming call failed: " + e.getMessage()));
        }
        
        return future;
    }
} 