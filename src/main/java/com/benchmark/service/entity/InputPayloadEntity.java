package com.benchmark.service.entity;

import com.google.cloud.spring.data.spanner.core.mapping.Table;
import com.google.cloud.spring.data.spanner.core.mapping.PrimaryKey;
import java.time.Instant;

@Table(name = "input_payload")
public class InputPayloadEntity {
    @PrimaryKey
    private String id;
    private String content;
    private Instant timestamp;
    private String protocol;

    // Getters and setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    
    public Instant getTimestamp() { return timestamp; }
    public void setTimestamp(Instant timestamp) { this.timestamp = timestamp; }
    
    public String getProtocol() { return protocol; }
    public void setProtocol(String protocol) { this.protocol = protocol; }
}
