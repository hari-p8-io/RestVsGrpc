package com.benchmark.service.service;

import com.benchmark.service.dto.InputPayload;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
public class SimplePayloadService {

    private static final Logger logger = LoggerFactory.getLogger(SimplePayloadService.class);

    public String processPayload(InputPayload payload, String protocol) {
        try {
            String correlationId = UUID.randomUUID().toString();
            Instant startTime = Instant.now();
            
            logger.info("Processing {} payload with correlation ID: {}", protocol, correlationId);
            logger.info("Payload ID: {}, Content: {}, Timestamp: {}", 
                       payload.getId(), payload.getContent(), payload.getTimestamp());

            // Simulate some processing time
            Thread.sleep(10);

            return "SUCCESS: Processed " + protocol + " payload with correlation ID: " + correlationId;
            
        } catch (Exception e) {
            logger.error("Error processing {} payload: {}", protocol, e.getMessage(), e);
            throw new RuntimeException("Failed to process " + protocol + " payload: " + e.getMessage(), e);
        }
    }
} 