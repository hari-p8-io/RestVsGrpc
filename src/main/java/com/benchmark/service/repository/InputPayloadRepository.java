package com.benchmark.service.repository;

import com.benchmark.service.entity.InputPayloadEntity;
import com.google.cloud.spring.data.spanner.repository.SpannerRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InputPayloadRepository extends SpannerRepository<InputPayloadEntity, String> {
}
