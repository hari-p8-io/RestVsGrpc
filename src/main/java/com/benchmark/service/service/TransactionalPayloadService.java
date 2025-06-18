package com.benchmark.service.service;

import com.benchmark.service.dto.InputPayload;
import com.benchmark.service.dto.OutgoingMqMessage;
import com.benchmark.service.entity.InputPayloadEntity;
import com.benchmark.service.repository.InputPayloadRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class TransactionalPayloadService {

    private static final Logger logger = LoggerFactory.getLogger(TransactionalPayloadService.class);

    @Autowired
    private InputPayloadRepository repository;

    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @Transactional
    public String processPayload(InputPayload payload, String protocol) {
        try {
            String correlationId = UUID.randomUUID().toString();
            Instant startTime = Instant.now();
            
            logger.info("Processing {} payload with correlation ID: {}", protocol, correlationId);

            // 1. Save to Spanner database
            InputPayloadEntity entity = new InputPayloadEntity();
            entity.setId(payload.getId());
            entity.setContent(payload.getContent());
            
            // Convert string timestamp to Instant
            if (payload.getTimestamp() != null && !payload.getTimestamp().isEmpty()) {
                try {
                    entity.setTimestamp(Instant.parse(payload.getTimestamp()));
                } catch (Exception e) {
                    logger.warn("Failed to parse timestamp '{}', using current time", payload.getTimestamp());
                    entity.setTimestamp(Instant.now());
                }
            } else {
                entity.setTimestamp(Instant.now());
            }
            
            entity.setProtocol(protocol);

            repository.save(entity);
            logger.info("Saved payload to Spanner with ID: {}", payload.getId());

            // 2. Prepare and send Kafka message
            OutgoingMqMessage mqMsg = new OutgoingMqMessage();
            mqMsg.setUserId(payload.getId());
            mqMsg.setUserName(payload.getContent()); // Use content instead of name
            mqMsg.setNotificationType("NEW_PAYLOAD");
            mqMsg.setCorrelationId(correlationId);
            mqMsg.setProtocol(protocol);
            mqMsg.setProcessingStartTime(startTime.toEpochMilli());
            mqMsg.setTimestamp(Instant.now().toString());
            
            // Send to protocol-specific topic
            String topicName = protocol.toLowerCase() + "-payload-topic";
            kafkaTemplate.send(topicName, correlationId, objectMapper.writeValueAsString(mqMsg));
            logger.info("Sent message to Kafka topic: {} with correlation ID: {}", topicName, correlationId);

            return "SUCCESS: Processed " + protocol + " payload with correlation ID: " + correlationId;
            
        } catch (Exception e) {
            logger.error("Error processing {} payload: {}", protocol, e.getMessage(), e);
            throw new RuntimeException("Failed to process " + protocol + " payload: " + e.getMessage(), e);
        }
    }
} 