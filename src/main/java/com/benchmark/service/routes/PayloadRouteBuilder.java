package com.benchmark.service.routes;

import com.benchmark.service.dto.InputPayload;
import com.benchmark.service.dto.PayloadResponse;
import com.benchmark.service.service.TransactionalPayloadService;
import com.benchmark.service.util.GrpcPayloadConverter;
import org.apache.camel.Exchange;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.rest.RestBindingMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class PayloadRouteBuilder extends RouteBuilder {

    private static final Logger logger = LoggerFactory.getLogger(PayloadRouteBuilder.class);

    @Autowired
    private TransactionalPayloadService payloadService;

    @Override
    public void configure() throws Exception {
        
        // Configure REST component to use servlet
        restConfiguration()
            .component("servlet")
            .bindingMode(RestBindingMode.json)
            .dataFormatProperty("prettyPrint", "true")
            .contextPath("/")
            .port(8080);

        // Health endpoint - direct route
        from("direct:health")
            .routeId("health")
            .setBody(constant("{\"status\":\"UP\",\"message\":\"Service is healthy\"}"))
            .setHeader("Content-Type", constant("application/json"));

        // Direct route for processing payloads
        from("direct:processPayloadRest")
            .routeId("process-payload-rest-route")
            .log("Processing REST payload: ${body}")
            .process(exchange -> {
                InputPayload payload = exchange.getIn().getBody(InputPayload.class);
                String result = payloadService.processPayload(payload, "REST");
                PayloadResponse response = new PayloadResponse("success", result);
                exchange.getIn().setBody(response);
            });

        // REST endpoints using servlet component
        rest("/api")
            .post("/payload")
                .type(InputPayload.class)
                .produces("application/json")
                .to("direct:processPayloadRest")
            .get("/health")
                .produces("application/json") 
                .to("direct:health");

        // gRPC endpoint with transactional service integration
        from("grpc://0.0.0.0:6565/com.benchmark.service.grpc.PayloadService?method=SendPayload")
            .routeId("grpc-payload-route-transactional")
            .process(exchange -> {
                com.benchmark.service.grpc.InputPayload proto = exchange.getIn().getBody(com.benchmark.service.grpc.InputPayload.class);
                
                // Convert protobuf to DTO
                InputPayload payload = new InputPayload();
                payload.setId(proto.getId());
                payload.setContent(proto.getContent());
                payload.setTimestamp(proto.getTimestamp());
                payload.setProtocol(proto.getProtocol());

                // Use the transactional service
                String result = payloadService.processPayload(payload, "gRPC");
                
                // Return response with correlation ID
                com.benchmark.service.grpc.PayloadResponse response = com.benchmark.service.grpc.PayloadResponse.newBuilder()
                    .setStatus("success")
                    .setMessage(result)
                    .build();
                exchange.getIn().setBody(response);
            })
            .log("gRPC payload processed successfully");
    }
}
