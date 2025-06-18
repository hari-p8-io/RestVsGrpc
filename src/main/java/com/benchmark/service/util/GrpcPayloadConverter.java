package com.benchmark.service.util;

public class GrpcPayloadConverter {
    public static com.benchmark.service.dto.InputPayload fromProto(com.benchmark.service.grpc.InputPayload proto) {
        com.benchmark.service.dto.InputPayload dto = new com.benchmark.service.dto.InputPayload();
        dto.setId(proto.getId());
        dto.setContent(proto.getContent());
        dto.setTimestamp(proto.getTimestamp());
        dto.setProtocol(proto.getProtocol());
        return dto;
    }
    
    public static com.benchmark.service.grpc.PayloadResponse createSuccessResponse() {
        return com.benchmark.service.grpc.PayloadResponse.newBuilder()
            .setStatus("OK")
            .setMessage("Processed successfully")
            .build();
    }
}
