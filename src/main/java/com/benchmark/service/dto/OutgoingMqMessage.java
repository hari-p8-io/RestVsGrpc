package com.benchmark.service.dto;

public class OutgoingMqMessage {
    private String userId;
    private String userName;
    private String notificationType;
    private String correlationId;
    private String protocol;
    private Long processingStartTime;
    private String timestamp;

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
    public String getNotificationType() { return notificationType; }
    public void setNotificationType(String notificationType) { this.notificationType = notificationType; }
    public String getCorrelationId() { return correlationId; }
    public void setCorrelationId(String correlationId) { this.correlationId = correlationId; }
    public String getProtocol() { return protocol; }
    public void setProtocol(String protocol) { this.protocol = protocol; }
    public Long getProcessingStartTime() { return processingStartTime; }
    public void setProcessingStartTime(Long processingStartTime) { this.processingStartTime = processingStartTime; }
    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
}

