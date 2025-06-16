package com.benchmark.service.dto;

public class OutgoingMqMessage {
    private String userId;
    private String userName;
    private String notificationType;
    // Add more fields as needed for outgoing MQ message

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
    public String getNotificationType() { return notificationType; }
    public void setNotificationType(String notificationType) { this.notificationType = notificationType; }
}

