# Production Deployment Guide

This guide covers deploying Ragdoll in production environments with PostgreSQL + pgvector, focusing on performance, scalability, reliability, and security considerations for enterprise workloads.

## Overview

Ragdoll is designed for production deployment with:

- **PostgreSQL + pgvector**: Production-grade vector search capabilities
- **Background Processing**: Scalable document processing with ActiveJob
- **Multi-Modal Support**: Text, image, and audio content handling
- **Enterprise Features**: Comprehensive logging, monitoring, and analytics
- **High Availability**: Connection pooling, error handling, and failover support

## Infrastructure Requirements

### Minimum Requirements

```yaml
# Production minimum specifications
Database Server:
  CPU: 4 cores
  RAM: 8 GB
  Storage: 100 GB SSD
  PostgreSQL: 12+ with pgvector extension

Application Server:
  CPU: 2 cores  
  RAM: 4 GB
  Storage: 20 GB

Background Workers:
  CPU: 2 cores per worker
  RAM: 2 GB per worker
  Recommended: 2-4 worker processes
```

### Recommended Production Setup

```yaml
# High-performance production setup
Database Server:
  CPU: 8-16 cores
  RAM: 32-64 GB
  Storage: 500 GB+ NVMe SSD
  Network: 10 Gbps
  PostgreSQL: 14+ with pgvector extension

Application Servers (2+ instances):
  CPU: 4-8 cores
  RAM: 8-16 GB  
  Storage: 50 GB SSD

Background Workers (4-8 instances):
  CPU: 4 cores
  RAM: 4 GB
  Specialized by job type (embeddings, processing, analysis)

Load Balancer:
  HAProxy, nginx, or cloud load balancer
  SSL termination
  Health checks

Monitoring:
  Prometheus + Grafana
  Application metrics
  Database monitoring
```

## PostgreSQL + pgvector Setup

### Installation

#### Ubuntu/Debian

```bash
# Install PostgreSQL 14+
sudo apt update
sudo apt install postgresql-14 postgresql-contrib-14

# Install pgvector extension
sudo apt install postgresql-14-pgvector

# Or compile from source
git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

#### RHEL/CentOS

```bash
# Install PostgreSQL
sudo dnf install postgresql14-server postgresql14-contrib

# Install pgvector
sudo dnf install postgresql14-pgvector

# Or compile from source (requires development packages)
sudo dnf groupinstall "Development Tools"
sudo dnf install postgresql14-devel
git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

#### Docker Setup

```dockerfile
# Dockerfile for PostgreSQL + pgvector
FROM postgres:14

# Install pgvector
RUN apt-get update && \
    apt-get install -y postgresql-14-pgvector && \
    rm -rf /var/lib/apt/lists/*

# Custom initialization
COPY init-scripts/ /docker-entrypoint-initdb.d/
```

### Database Configuration

#### postgresql.conf Optimization

```ini
# postgresql.conf optimizations for Ragdoll

# Memory settings
shared_buffers = 2GB                    # 25% of system RAM
effective_cache_size = 6GB              # 75% of system RAM
work_mem = 256MB                        # For sorting/hashing operations
maintenance_work_mem = 1GB              # For index creation

# Connection settings
max_connections = 200
shared_preload_libraries = 'vector'     # Enable pgvector

# Write performance
wal_buffers = 64MB
checkpoint_completion_target = 0.9
max_wal_size = 2GB
min_wal_size = 512MB

# Query optimization
default_statistics_target = 1000        # Better query planning
random_page_cost = 1.1                  # SSD optimization
effective_io_concurrency = 200          # SSD optimization

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d.log'
log_min_duration_statement = 1000      # Log slow queries
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

#### Database Initialization

```sql
-- Create database and user
CREATE DATABASE ragdoll_production;
CREATE USER ragdoll_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE ragdoll_production TO ragdoll_user;

-- Connect to ragdoll database
\c ragdoll_production

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant usage to ragdoll user
GRANT USAGE ON SCHEMA public TO ragdoll_user;
GRANT CREATE ON SCHEMA public TO ragdoll_user;
```

#### Index Optimization

```sql
-- Optimized indexes for production performance

-- Vector similarity search (IVFFlat)
CREATE INDEX CONCURRENTLY idx_embeddings_vector_ivfflat 
ON ragdoll_embeddings 
USING ivfflat (embedding_vector vector_cosine_ops) 
WITH (lists = 1000);

-- Usage analytics indexes
CREATE INDEX CONCURRENTLY idx_embeddings_usage_analytics 
ON ragdoll_embeddings (usage_count DESC, returned_at DESC);

-- Polymorphic content indexes
CREATE INDEX CONCURRENTLY idx_embeddings_content_type 
ON ragdoll_embeddings (embeddable_type, embeddable_id);

-- Document status and type indexes
CREATE INDEX CONCURRENTLY idx_documents_status_type 
ON ragdoll_documents (status, document_type);

-- Full-text search indexes
CREATE INDEX CONCURRENTLY idx_embeddings_content_fulltext 
ON ragdoll_embeddings 
USING GIN (to_tsvector('english', content));

-- Metadata search indexes (JSONB)
CREATE INDEX CONCURRENTLY idx_documents_metadata_gin 
ON ragdoll_documents 
USING GIN (metadata);

-- Composite indexes for common queries
CREATE INDEX CONCURRENTLY idx_embeddings_search_composite
ON ragdoll_embeddings (embeddable_type, usage_count DESC, returned_at DESC);

-- Analyze tables for accurate statistics
ANALYZE ragdoll_documents;
ANALYZE ragdoll_embeddings;
ANALYZE ragdoll_text_contents;
ANALYZE ragdoll_image_contents;
ANALYZE ragdoll_audio_contents;
```

## Application Configuration

### Production Configuration

```ruby
# config/environments/production.rb
Ragdoll::Core.configure do |config|
  # LLM Provider
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  config.summary_model = 'gpt-4'
  config.keywords_model = 'gpt-3.5-turbo'
  
  # Production database
  config.database_config = {
    adapter: 'postgresql',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    database: ENV['DATABASE_NAME'] || 'ragdoll_production',
    username: ENV['DATABASE_USERNAME'] || 'ragdoll_user',
    password: ENV['DATABASE_PASSWORD'],
    pool: ENV.fetch('RAILS_MAX_THREADS', 25).to_i,
    timeout: 5000,
    checkout_timeout: 5,
    reaping_frequency: 10,
    idle_timeout: 300,
    auto_migrate: false,  # Handle migrations separately
    
    # SSL configuration
    sslmode: ENV['DATABASE_SSL_MODE'] || 'require',
    sslcert: ENV['DATABASE_SSL_CERT'],
    sslkey: ENV['DATABASE_SSL_KEY'],
    sslrootcert: ENV['DATABASE_SSL_CA'],
    
    # Performance settings
    prepared_statements: true,
    advisory_locks: true
  }
  
  # Production logging
  config.log_level = :info
  config.log_file = ENV['RAGDOLL_LOG_FILE'] || '/var/log/ragdoll/ragdoll.log'
  config.log_format = :json
  config.log_rotation = 'daily'
  config.log_max_size = 100.megabytes
  
  # Background processing
  config.enable_background_processing = true
  config.job_queue_prefix = ENV['RAGDOLL_QUEUE_PREFIX'] || 'ragdoll_production'
  config.job_timeout = 600.seconds
  config.max_retry_attempts = 3
  
  # Performance settings
  config.chunk_size = 1000
  config.chunk_overlap = 200
  config.search_similarity_threshold = 0.75
  config.max_search_results = 50
  
  # Enable production features
  config.enable_usage_analytics = true
  config.enable_document_summarization = true
  config.enable_keyword_extraction = true
  config.enable_performance_monitoring = true
  
  # Cache settings
  config.search_cache_ttl = 300.seconds
  config.embedding_cache_ttl = 3600.seconds
  config.metadata_cache_ttl = 1800.seconds
  
  # Security settings
  config.enable_request_logging = false    # May contain sensitive data
  config.log_embedding_content = false     # Don't log actual content
  config.sanitize_error_messages = true
end
```

### Environment Variables

```bash
# .env.production
# Database configuration
DATABASE_HOST=postgres.example.com
DATABASE_PORT=5432
DATABASE_NAME=ragdoll_production
DATABASE_USERNAME=ragdoll_user
DATABASE_PASSWORD=your_secure_password
DATABASE_SSL_MODE=require
DATABASE_POOL=25

# LLM API keys
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
GOOGLE_API_KEY=your-google-api-key

# Application settings
RAILS_ENV=production
RAILS_MAX_THREADS=25
RAGDOLL_LOG_FILE=/var/log/ragdoll/ragdoll.log
RAGDOLL_QUEUE_PREFIX=ragdoll_production

# Redis (for Sidekiq)
REDIS_URL=redis://redis.example.com:6379/0

# Monitoring
PROMETHEUS_METRICS_PORT=9394
HEALTH_CHECK_PORT=8080

# File storage
RAGDOLL_STORAGE_PATH=/var/lib/ragdoll/storage
RAGDOLL_CACHE_PATH=/var/lib/ragdoll/cache
```

## Background Processing Setup

### Sidekiq Configuration

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  
  # Queue configuration
  config.queues = %w[
    embeddings:3
    processing:2  
    analysis:1
    default:1
  ]
  
  # Concurrency settings
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i
  
  # Error handling
  config.death_handlers << lambda do |job, exception|
    # Custom error handling for failed jobs
    RagdollErrorHandler.handle_job_death(job, exception)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end
```

### Docker Compose Setup

```yaml
# docker-compose.production.yml
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg14
    environment:
      POSTGRES_DB: ragdoll_production
      POSTGRES_USER: ragdoll_user
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf
    ports:
      - "5432:5432"
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
      
  ragdoll-app:
    build: .
    environment:
      - DATABASE_URL=postgresql://ragdoll_user:${DATABASE_PASSWORD}@postgres:5432/ragdoll_production
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    volumes:
      - storage_data:/var/lib/ragdoll/storage
      - log_data:/var/log/ragdoll
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - redis
      
  ragdoll-embeddings:
    build: .
    command: bundle exec sidekiq -q embeddings -c 3
    environment:
      - DATABASE_URL=postgresql://ragdoll_user:${DATABASE_PASSWORD}@postgres:5432/ragdoll_production
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    volumes:
      - storage_data:/var/lib/ragdoll/storage
      - log_data:/var/log/ragdoll
    depends_on:
      - postgres
      - redis
      
  ragdoll-processing:
    build: .
    command: bundle exec sidekiq -q processing -c 2
    environment:
      - DATABASE_URL=postgresql://ragdoll_user:${DATABASE_PASSWORD}@postgres:5432/ragdoll_production
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    volumes:
      - storage_data:/var/lib/ragdoll/storage
      - log_data:/var/log/ragdoll
    depends_on:
      - postgres
      - redis
      
  ragdoll-analysis:
    build: .
    command: bundle exec sidekiq -q analysis -c 1
    environment:
      - DATABASE_URL=postgresql://ragdoll_user:${DATABASE_PASSWORD}@postgres:5432/ragdoll_production
      - REDIS_URL=redis://redis:6379/0
      - RAILS_ENV=production
    volumes:
      - storage_data:/var/lib/ragdoll/storage
      - log_data:/var/log/ragdoll
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
  redis_data:
  storage_data:
  log_data:
```

## Load Balancing and High Availability

### nginx Configuration

```nginx
# /etc/nginx/sites-available/ragdoll
upstream ragdoll_app {
    server app1.example.com:3000 max_fails=3 fail_timeout=30s;
    server app2.example.com:3000 max_fails=3 fail_timeout=30s;
    server app3.example.com:3000 max_fails=3 fail_timeout=30s backup;
}

server {
    listen 80;
    listen 443 ssl http2;
    server_name ragdoll.example.com;
    
    # SSL configuration
    ssl_certificate /etc/ssl/certs/ragdoll.example.com.pem;
    ssl_certificate_key /etc/ssl/private/ragdoll.example.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    # File upload size
    client_max_body_size 100M;
    
    # Proxy settings
    location / {
        proxy_pass http://ragdoll_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Health checks
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://ragdoll_app/health;
        access_log off;
    }
    
    # Static files
    location /assets {
        root /var/www/ragdoll/public;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### Health Checks

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/health', to: 'health#check'
  get '/health/detailed', to: 'health#detailed'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def check
    health_status = Ragdoll::Core.client.health_check
    
    if health_status[:status] == 'healthy'
      render json: { status: 'ok', timestamp: Time.current }, status: :ok
    else
      render json: { 
        status: 'error', 
        details: health_status, 
        timestamp: Time.current 
      }, status: :service_unavailable
    end
  end
  
  def detailed
    render json: Ragdoll::Core.client.detailed_health_check
  end
end
```

## Monitoring and Observability

### Prometheus Metrics

```ruby
# config/initializers/prometheus.rb
require 'prometheus/client'
require 'prometheus/client/rack/collector'
require 'prometheus/client/rack/exporter'

# Custom metrics for Ragdoll
module RagdollMetrics
  PROMETHEUS = Prometheus::Client.registry
  
  SEARCH_DURATION = PROMETHEUS.histogram(
    :ragdoll_search_duration_seconds,
    docstring: 'Time spent on search operations',
    labels: [:query_type, :content_type]
  )
  
  DOCUMENT_PROCESSING = PROMETHEUS.counter(
    :ragdoll_documents_processed_total,
    docstring: 'Total number of documents processed',
    labels: [:document_type, :status]
  )
  
  EMBEDDING_GENERATION = PROMETHEUS.histogram(
    :ragdoll_embedding_generation_seconds,
    docstring: 'Time spent generating embeddings',
    labels: [:model, :content_type]
  )
  
  BACKGROUND_JOBS = PROMETHEUS.counter(
    :ragdoll_background_jobs_total,
    docstring: 'Total background jobs processed',
    labels: [:job_type, :status]
  )
end

# Instrument search operations
module SearchInstrumentation
  def search_similar_content(query, options = {})
    start_time = Time.current
    result = super
    
    RagdollMetrics::SEARCH_DURATION.observe(
      Time.current - start_time,
      labels: { 
        query_type: 'semantic',
        content_type: options[:content_types]&.join(',') || 'all'
      }
    )
    
    result
  end
end

Ragdoll::Core::SearchEngine.prepend(SearchInstrumentation)
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Ragdoll Production Dashboard",
    "panels": [
      {
        "title": "Search Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(ragdoll_search_duration_seconds[5m])",
            "legendFormat": "Search Rate"
          },
          {
            "expr": "histogram_quantile(0.95, ragdoll_search_duration_seconds)",
            "legendFormat": "95th Percentile"
          }
        ]
      },
      {
        "title": "Document Processing",
        "type": "graph", 
        "targets": [
          {
            "expr": "rate(ragdoll_documents_processed_total[5m])",
            "legendFormat": "Processing Rate"
          }
        ]
      },
      {
        "title": "Background Jobs",
        "type": "singlestat",
        "targets": [
          {
            "expr": "sidekiq_queue_size",
            "legendFormat": "Queue Depth"
          }
        ]
      },
      {
        "title": "Database Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "postgresql_stat_database_tup_returned",
            "legendFormat": "Rows Returned"
          },
          {
            "expr": "postgresql_stat_database_tup_fetched", 
            "legendFormat": "Rows Fetched"
          }
        ]
      }
    ]
  }
}
```

### Log Aggregation

```yaml
# docker-compose.logging.yml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
      
  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    volumes:
      - ./config/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    ports:
      - "5044:5044"
    depends_on:
      - elasticsearch
      
  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  elasticsearch_data:
```

## Security Configuration

### Application Security

```ruby
# Security configuration
Ragdoll::Core.configure do |config|
  # API key encryption
  config.encrypt_api_keys = true
  config.encryption_key = ENV['RAGDOLL_ENCRYPTION_KEY']
  
  # Request validation
  config.validate_request_origin = true
  config.allowed_origins = ENV['ALLOWED_ORIGINS']&.split(',') || []
  
  # Content filtering
  config.content_filtering = {
    max_file_size: 100.megabytes,
    allowed_file_types: %w[pdf docx txt html md mp3 wav jpg png],
    scan_for_malware: true,
    sanitize_content: true
  }
  
  # Access logging
  config.audit_logging = true
  config.log_access_patterns = true
  config.sensitive_data_masking = true
end
```

### Database Security

```sql
-- Row-level security example
ALTER TABLE ragdoll_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY documents_access_policy ON ragdoll_documents
FOR ALL TO ragdoll_user
USING (
  -- Add your access control logic here
  tenant_id = current_setting('app.current_tenant_id')::uuid
);

-- Audit logging
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER SYSTEM SET pgaudit.log = 'all';
```

## Backup and Recovery

### Database Backup

```bash
#!/bin/bash
# backup_ragdoll.sh

# Configuration
DB_HOST="${DATABASE_HOST:-localhost}"
DB_NAME="${DATABASE_NAME:-ragdoll_production}"
DB_USER="${DATABASE_USERNAME:-ragdoll_user}"
BACKUP_DIR="/var/backups/ragdoll"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate backup filename
BACKUP_FILE="$BACKUP_DIR/ragdoll_$(date +%Y%m%d_%H%M%S).sql.gz"

# Create backup
pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
  --verbose \
  --no-password \
  --format=custom \
  --compress=9 \
  | gzip > "$BACKUP_FILE"

# Verify backup
if [ $? -eq 0 ]; then
  echo "Backup completed successfully: $BACKUP_FILE"
  
  # Remove old backups
  find "$BACKUP_DIR" -name "ragdoll_*.sql.gz" -mtime +$RETENTION_DAYS -delete
else
  echo "Backup failed!" >&2
  exit 1
fi
```

### Recovery Procedures

```bash
#!/bin/bash
# restore_ragdoll.sh

BACKUP_FILE="$1"
DB_HOST="${DATABASE_HOST:-localhost}"
DB_NAME="${DATABASE_NAME:-ragdoll_production}"
DB_USER="${DATABASE_USERNAME:-ragdoll_user}"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup_file.sql.gz>"
  exit 1
fi

# Stop application services
docker-compose stop ragdoll-app ragdoll-embeddings ragdoll-processing ragdoll-analysis

# Restore database
gunzip -c "$BACKUP_FILE" | pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" --clean --if-exists

# Restart services
docker-compose start ragdoll-app ragdoll-embeddings ragdoll-processing ragdoll-analysis

echo "Database restore completed"
```

## Performance Tuning

### Database Optimization

```sql
-- Maintenance tasks
VACUUM ANALYZE ragdoll_documents;
VACUUM ANALYZE ragdoll_embeddings;
REINDEX INDEX CONCURRENTLY idx_embeddings_vector_ivfflat;

-- Statistics update
ANALYZE ragdoll_documents;
ANALYZE ragdoll_embeddings;

-- Index maintenance
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;
```

### Application Optimization

```ruby
# Connection pooling optimization
Ragdoll::Core.configure do |config|
  config.database_config = {
    # ... other settings
    pool: ENV.fetch('DATABASE_POOL', 25).to_i,
    checkout_timeout: 5,
    reaping_frequency: 10,
    idle_timeout: 300,
    
    # Query optimization
    prepared_statements: true,
    statement_timeout: 30000,  # 30 seconds
    advisory_locks: true
  }
  
  # Cache optimization
  config.search_cache_ttl = 300.seconds
  config.embedding_cache_ttl = 3600.seconds
  config.enable_query_cache = true
  
  # Batch processing optimization
  config.batch_processing_size = 100
  config.parallel_processing = true
  config.worker_concurrency = 4
end
```

## Deployment Checklist

### Pre-Deployment

- [ ] Database server provisioned with adequate resources
- [ ] pgvector extension installed and tested
- [ ] Application servers configured with proper resource limits
- [ ] Background worker processes planned and configured
- [ ] Load balancer configured with health checks
- [ ] SSL certificates installed and configured
- [ ] Environment variables securely configured
- [ ] Database migrations tested in staging
- [ ] Backup and recovery procedures tested
- [ ] Monitoring and alerting configured

### Post-Deployment

- [ ] Health checks passing
- [ ] Database performance metrics within acceptable ranges
- [ ] Background job processing functioning correctly
- [ ] Search operations performing within SLA
- [ ] Log aggregation and monitoring operational
- [ ] Backup procedures validated
- [ ] Security scanning completed
- [ ] Performance baseline established
- [ ] Documentation updated with production specifics
- [ ] Team trained on operational procedures

### Ongoing Maintenance

- [ ] Regular database maintenance (VACUUM, ANALYZE)
- [ ] Index performance monitoring and optimization
- [ ] Log rotation and cleanup
- [ ] Security updates and patches
- [ ] Performance monitoring and tuning
- [ ] Backup validation and recovery testing
- [ ] Capacity planning and scaling decisions
- [ ] Configuration optimization based on usage patterns

This deployment guide provides a comprehensive foundation for running Ragdoll in production environments, ensuring high performance, reliability, and maintainability for enterprise document intelligence applications.