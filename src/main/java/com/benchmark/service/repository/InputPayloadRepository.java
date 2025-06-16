package com.benchmark.service.repository;

import com.benchmark.service.entity.InputPayloadEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InputPayloadRepository extends JpaRepository<InputPayloadEntity, String> {
}
