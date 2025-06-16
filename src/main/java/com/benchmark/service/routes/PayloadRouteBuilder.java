package com.benchmark.service.routes;

import com.benchmark.service.dto.InputPayload;
import com.benchmark.service.dto.OutgoingMqMessage;
import com.benchmark.service.entity.InputPayloadEntity;
import com.benchmark.service.repository.InputPayloadRepository;
import org.apache.camel.Exchange;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.model.rest.RestBindingMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.BeanUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;

@Component
public class PayloadRouteBuilder extends RouteBuilder {

    private static final Logger logger = LoggerFactory.getLogger(PayloadRouteBuilder.class);

    @Autowired
    private InputPayloadRepository repository;

    @Value("${endpoint.type:rest}")
    private String endpointType;

    @Override
    public void configure() throws Exception {
        // REST endpoint
        if ("rest".equalsIgnoreCase(endpointType)) {
            restConfiguration()
                .component("servlet")
                .bindingMode(RestBindingMode.json);
            rest("/api")
                .post("/payload")
                .type(InputPayload.class)
                .to("direct:processPayload");
        }

        // gRPC endpoint
        if ("grpc".equalsIgnoreCase(endpointType)) {
            from("grpc://localhost:6565/com.benchmark.service.grpc.PayloadService?method=SendPayload")
                .routeId("grpc-payload-route")
                .process(exchange -> {
                    com.benchmark.service.grpc.InputPayload proto = exchange.getIn().getBody(com.benchmark.service.grpc.InputPayload.class);
                    InputPayload payload = com.benchmark.service.util.GrpcPayloadConverter.fromProto(proto);
                    exchange.getIn().setBody(payload);
                })
                .to("direct:processPayload")
                .setBody(constant("{\"status\":\"OK\",\"message\":\"Processed\"}"))
                .setHeader(Exchange.CONTENT_TYPE, constant("application/json"));
        }

        // Common processing route
        from("direct:processPayload")
            .routeId("process-payload-route")
            .process(exchange -> {
                InputPayload payload = exchange.getIn().getBody(InputPayload.class);
                logger.info("Received payload: {}", payload);
                // Persist to DB
                InputPayloadEntity entity = new InputPayloadEntity();
                BeanUtils.copyProperties(payload, entity);
                repository.save(entity);
                // Prepare outgoing MQ message
                OutgoingMqMessage mqMsg = new OutgoingMqMessage();
                mqMsg.setUserId(payload.getId());
                mqMsg.setUserName(payload.getName());
                mqMsg.setNotificationType("NEW_PAYLOAD");
                exchange.getIn().setBody(mqMsg);
            })
            .marshal().json()
            .to("rabbitmq:exchange1?queue=queue1&routingKey=route1&autoDelete=false");
    }


}
