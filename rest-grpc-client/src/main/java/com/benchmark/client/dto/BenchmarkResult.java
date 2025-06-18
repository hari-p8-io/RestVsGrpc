package com.benchmark.client.dto;

public class BenchmarkResult {
    private String protocol;
    private long duration;
    private String status;
    private String message;
    private long startTime;
    private long endTime;

    public BenchmarkResult() {}

    public BenchmarkResult(String protocol, long duration, String status, String message, long startTime, long endTime) {
        this.protocol = protocol;
        this.duration = duration;
        this.status = status;
        this.message = message;
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public String getProtocol() {
        return protocol;
    }

    public void setProtocol(String protocol) {
        this.protocol = protocol;
    }

    public long getDuration() {
        return duration;
    }

    public void setDuration(long duration) {
        this.duration = duration;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public long getStartTime() {
        return startTime;
    }

    public void setStartTime(long startTime) {
        this.startTime = startTime;
    }

    public long getEndTime() {
        return endTime;
    }

    public void setEndTime(long endTime) {
        this.endTime = endTime;
    }

    @Override
    public String toString() {
        return "BenchmarkResult{" +
                "protocol='" + protocol + '\'' +
                ", duration=" + duration +
                ", status='" + status + '\'' +
                ", message='" + message + '\'' +
                ", startTime=" + startTime +
                ", endTime=" + endTime +
                '}';
    }
} 