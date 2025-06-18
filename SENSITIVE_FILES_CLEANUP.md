# 🔐 Sensitive Files and Credentials Cleanup Guide

## 🚨 **CRITICAL: Files with Sensitive Information**

### **1. GCP Service Account Keys** ⚠️
- `local-sa.json` - **CONTAINS PRIVATE KEY** 
- `gcp-sa-key.json` - **CONTAINS PRIVATE KEY**
- `k8s/gcp-credentials-secret.yaml` - **CONTAINS PRIVATE KEY**

### **2. Configuration Files with Credentials**
- `src/main/resources/application.properties` - References credential file location
- `src/main/resources/application-k8s.properties` - Contains Kafka password
- `target/classes/application.properties` - Copy with credential references
- `target/classes/application-k8s.properties` - Copy with Kafka password

### **3. Kubernetes Deployment Files**
- `k8s/deployment.yaml` - References secret mounts and credential paths

### **4. Documentation with Credential References**
- `100TPS-RABBITMQ-GUIDE.md` - Contains RabbitMQ default password

## 🧹 **Immediate Cleanup Actions Required**

### **Step 1: Delete Credential Files**
```bash
# Remove GCP service account key files
rm -f local-sa.json
rm -f gcp-sa-key.json
rm -f k8s/gcp-credentials-secret.yaml

# Clean build artifacts
rm -rf target/
```

### **Step 2: Update .gitignore**
```bash
# Add to .gitignore to prevent future commits
echo "local-sa.json" >> .gitignore
echo "gcp-sa-key.json" >> .gitignore
echo "*.json" >> .gitignore  # Be careful - this excludes ALL json files
echo "*credentials*" >> .gitignore
```

### **Step 3: Clean Configuration Files**
- Remove hardcoded passwords from properties files
- Use environment variables instead
- Remove credential file paths

### **Step 4: Git History Cleanup** ⚠️
```bash
# WARNING: This rewrites git history - coordinate with team
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch local-sa.json gcp-sa-key.json k8s/gcp-credentials-secret.yaml' \
  --prune-empty --tag-name-filter cat -- --all
```

## 🔒 **Security Best Practices Going Forward**

### **1. Use Environment Variables**
```properties
# Instead of hardcoded values
spring.kafka.properties.sasl.jaas.config=${KAFKA_SASL_CONFIG}
spring.cloud.gcp.credentials.location=${GOOGLE_APPLICATION_CREDENTIALS}
```

### **2. Use Kubernetes Secrets**
```yaml
# Create secrets externally, reference in deployment
- name: GOOGLE_APPLICATION_CREDENTIALS
  valueFrom:
    secretKeyRef:
      name: gcp-credentials
      key: service-account-key
```

### **3. Use GCP Workload Identity**
- Avoid service account key files entirely
- Use IAM bindings for pod-level authentication

### **4. Credential Rotation**
- Rotate the exposed service account keys immediately
- Create new service accounts with minimal permissions

## 📝 **Files Safe to Keep** ✅
- Test result JSON files (`*-results.json`)
- Performance analysis documents
- K6 load testing scripts
- Application source code (after credential cleanup)

## 🚨 **URGENT: Immediate Actions**
1. **Rotate GCP service account keys** - The private keys are exposed
2. **Remove credential files** from workspace
3. **Clean git history** if files were committed
4. **Update deployment** to use Workload Identity
5. **Change Kafka passwords** if using real credentials

Remember: **Never commit credential files to version control!** 