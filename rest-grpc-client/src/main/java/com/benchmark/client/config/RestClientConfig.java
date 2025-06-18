package com.benchmark.client.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class RestClientConfig {

    @Value("${rest.server.host:localhost}")
    private String restServerHost;

    @Value("${rest.server.port:8080}")
    private int restServerPort;

    @Bean
    public WebClient webClient() {
        return WebClient.builder()
                .baseUrl("http://" + restServerHost + ":" + restServerPort)
                .build();
    }
} 