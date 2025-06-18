package com.benchmark.client.service;

import com.benchmark.client.dto.PayloadRequest;
import com.benchmark.client.dto.PayloadResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;

@Service
public class RestClientService {

    private static final Logger logger = LoggerFactory.getLogger(RestClientService.class);

    @Autowired
    private WebClient webClient;

    public PayloadResponse sendPayload(PayloadRequest request) {
        logger.info("Sending REST payload: {}", request);
        
        try {
            PayloadResponse response = webClient
                    .post()
                    .uri("/camel/api/payload")
                    .body(Mono.just(request), PayloadRequest.class)
                    .retrieve()
                    .bodyToMono(PayloadResponse.class)
                    .timeout(Duration.ofSeconds(30))
                    .block();
            
            logger.info("Received REST response: {}", response);
            return response;
        } catch (Exception e) {
            logger.error("Error sending REST payload", e);
            return new PayloadResponse("error", "REST call failed: " + e.getMessage());
        }
    }

    public String healthCheck() {
        try {
            String response = webClient
                    .get()
                    .uri("/camel/api/health")
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofSeconds(10))
                    .block();
            
            logger.info("REST health check response: {}", response);
            return response;
        } catch (Exception e) {
            logger.error("REST health check failed", e);
            return "{\"status\":\"DOWN\",\"message\":\"" + e.getMessage() + "\"}";
        }
    }
} 