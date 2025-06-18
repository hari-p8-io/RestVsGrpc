package com.benchmark.client.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class PayloadRequest {
    private String id;
    private String content;
    private String timestamp;
    private String protocol;

    public PayloadRequest() {}

    public PayloadRequest(String id, String content, String timestamp, String protocol) {
        this.id = id;
        this.content = content;
        this.timestamp = timestamp;
        this.protocol = protocol;
    }

    @JsonProperty("id")
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    @JsonProperty("content")
    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    @JsonProperty("timestamp")
    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    @JsonProperty("protocol")
    public String getProtocol() {
        return protocol;
    }

    public void setProtocol(String protocol) {
        this.protocol = protocol;
    }

    @Override
    public String toString() {
        return "PayloadRequest{" +
                "id='" + id + '\'' +
                ", content='" + content + '\'' +
                ", timestamp='" + timestamp + '\'' +
                ", protocol='" + protocol + '\'' +
                '}';
    }
} 