package com.benchmark.service.grpc;

import com.benchmark.service.dto.InputPayload;
import com.benchmark.service.service.TransactionalPayloadService;
import io.grpc.stub.StreamObserver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class PayloadServiceImpl extends PayloadServiceGrpc.PayloadServiceImplBase {

    private static final Logger logger = LoggerFactory.getLogger(PayloadServiceImpl.class);

    @Autowired
    private TransactionalPayloadService payloadService;

    @Override
    public void sendPayload(com.benchmark.service.grpc.InputPayload request,
                           StreamObserver<PayloadResponse> responseObserver) {
        logger.info("Received gRPC unary request: {}", request.getId());
        
        try {
            // Convert protobuf to DTO
            InputPayload payload = new InputPayload();
            payload.setId(request.getId());
            payload.setContent(request.getContent());
            payload.setTimestamp(request.getTimestamp());
            payload.setProtocol(request.getProtocol());

            // Process the payload
            String result = payloadService.processPayload(payload, "gRPC-Unary");
            
            // Build response
            PayloadResponse response = PayloadResponse.newBuilder()
                    .setStatus("success")
                    .setMessage(result)
                    .build();
            
            responseObserver.onNext(response);
            responseObserver.onCompleted();
            
            logger.info("gRPC unary response sent for ID: {}", request.getId());
            
        } catch (Exception e) {
            logger.error("Error processing gRPC unary request", e);
            PayloadResponse errorResponse = PayloadResponse.newBuilder()
                    .setStatus("error")
                    .setMessage("Processing failed: " + e.getMessage())
                    .build();
            responseObserver.onNext(errorResponse);
            responseObserver.onCompleted();
        }
    }

    @Override
    public StreamObserver<com.benchmark.service.grpc.InputPayload> streamPayloads(
            StreamObserver<PayloadResponse> responseObserver) {
        
        logger.info("Starting gRPC bidirectional streaming");
        
        return new StreamObserver<com.benchmark.service.grpc.InputPayload>() {
            @Override
            public void onNext(com.benchmark.service.grpc.InputPayload request) {
                logger.info("Received streaming request: {}", request.getId());
                
                try {
                    // Convert protobuf to DTO
                    InputPayload payload = new InputPayload();
                    payload.setId(request.getId());
                    payload.setContent(request.getContent());
                    payload.setTimestamp(request.getTimestamp());
                    payload.setProtocol(request.getProtocol());

                    // Process the payload
                    String result = payloadService.processPayload(payload, "gRPC-Streaming");
                    
                    // Build response
                    PayloadResponse response = PayloadResponse.newBuilder()
                            .setStatus("success")
                            .setMessage(result)
                            .build();
                    
                    responseObserver.onNext(response);
                    logger.info("Streaming response sent for ID: {}", request.getId());
                    
                } catch (Exception e) {
                    logger.error("Error processing streaming request", e);
                    PayloadResponse errorResponse = PayloadResponse.newBuilder()
                            .setStatus("error")
                            .setMessage("Streaming processing failed: " + e.getMessage())
                            .build();
                    responseObserver.onNext(errorResponse);
                }
            }

            @Override
            public void onError(Throwable t) {
                logger.error("Error in streaming request", t);
                responseObserver.onError(t);
            }

            @Override
            public void onCompleted() {
                logger.info("Streaming request completed");
                responseObserver.onCompleted();
            }
        };
    }
} 