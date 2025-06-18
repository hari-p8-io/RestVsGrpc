package com.benchmark.client.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class PayloadResponse {
    private String status;
    private String message;

    public PayloadResponse() {}

    public PayloadResponse(String status, String message) {
        this.status = status;
        this.message = message;
    }

    @JsonProperty("status")
    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    @JsonProperty("message")
    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    @Override
    public String toString() {
        return "PayloadResponse{" +
                "status='" + status + '\'' +
                ", message='" + message + '\'' +
                '}';
    }
} 