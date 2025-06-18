package com.benchmark.service.config;

import com.benchmark.service.grpc.PayloadServiceImpl;
import io.grpc.Server;
import io.grpc.ServerBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.io.IOException;

@Configuration
public class GrpcServerConfig {

    private static final Logger logger = LoggerFactory.getLogger(GrpcServerConfig.class);

    @Value("${grpc.server.port:6566}")
    private int grpcPort;

    @Autowired
    private PayloadServiceImpl payloadServiceImpl;

    private Server grpcServer;

    @PostConstruct
    public void startGrpcServer() {
        try {
            grpcServer = ServerBuilder.forPort(grpcPort)
                    .addService(payloadServiceImpl)
                    .build()
                    .start();
            
            logger.info("gRPC server started on port {}", grpcPort);
            
            // Add shutdown hook
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                logger.info("Shutting down gRPC server");
                if (grpcServer != null) {
                    grpcServer.shutdown();
                }
            }));
            
        } catch (IOException e) {
            logger.error("Failed to start gRPC server", e);
            throw new RuntimeException("Failed to start gRPC server", e);
        }
    }

    @PreDestroy
    public void stopGrpcServer() {
        if (grpcServer != null) {
            logger.info("Stopping gRPC server");
            grpcServer.shutdown();
        }
    }
} 