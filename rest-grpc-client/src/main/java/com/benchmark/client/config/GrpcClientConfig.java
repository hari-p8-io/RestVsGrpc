package com.benchmark.client.config;

import com.benchmark.service.grpc.PayloadServiceGrpc;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GrpcClientConfig {

    @Value("${grpc.server.host:localhost}")
    private String grpcServerHost;

    @Value("${grpc.server.port:6565}")
    private int grpcServerPort;

    @Bean
    public ManagedChannel grpcChannel() {
        return ManagedChannelBuilder.forAddress(grpcServerHost, grpcServerPort)
                .usePlaintext()
                .build();
    }

    @Bean
    public PayloadServiceGrpc.PayloadServiceBlockingStub payloadServiceBlockingStub(ManagedChannel channel) {
        return PayloadServiceGrpc.newBlockingStub(channel);
    }

    @Bean
    public PayloadServiceGrpc.PayloadServiceStub payloadServiceAsyncStub(ManagedChannel channel) {
        return PayloadServiceGrpc.newStub(channel);
    }
} 