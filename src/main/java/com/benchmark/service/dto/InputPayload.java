package com.benchmark.service.dto;

public class InputPayload {
    private String id;
    private String content;
    private String timestamp;
    private String protocol;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    
    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
    
    public String getProtocol() { return protocol; }
    public void setProtocol(String protocol) { this.protocol = protocol; }
}

