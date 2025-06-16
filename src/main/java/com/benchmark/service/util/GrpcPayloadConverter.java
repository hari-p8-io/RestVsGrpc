package com.benchmark.service.util;


import com.google.protobuf.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;

public class GrpcPayloadConverter {
    public static com.benchmark.service.dto.InputPayload fromProto(com.benchmark.service.grpc.InputPayload proto) {
        com.benchmark.service.dto.InputPayload dto = new com.benchmark.service.dto.InputPayload();
        dto.setId(proto.getId());
        dto.setName(proto.getName());
        dto.setEmail(proto.getEmail());
        dto.setAge(proto.getAge());
        dto.setCreatedDate(toLocalDate(proto.getCreatedDate()));
        dto.setUpdatedDate(toLocalDateTime(proto.getUpdatedDate()));
        dto.setBirthDate(toLocalDate(proto.getBirthDate()));
        return dto;
    }

    private static LocalDate toLocalDate(Timestamp ts) {
        if (ts == null || ts.getSeconds() == 0) return null;
        return Instant.ofEpochSecond(ts.getSeconds()).atZone(ZoneId.systemDefault()).toLocalDate();
    }

    private static LocalDateTime toLocalDateTime(Timestamp ts) {
        if (ts == null || ts.getSeconds() == 0) return null;
        return Instant.ofEpochSecond(ts.getSeconds()).atZone(ZoneId.systemDefault()).toLocalDateTime();
    }
}
