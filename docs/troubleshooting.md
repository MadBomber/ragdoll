# Troubleshooting

## Common Issues and Solutions

This guide provides comprehensive troubleshooting information for Ragdoll, covering installation, runtime, configuration, and performance issues with practical solutions.

### Quick Diagnostic Commands

```ruby
# Check system health
client = Ragdoll::Core.client
puts "System healthy: #{client.healthy?}"
puts "Database connected: #{Ragdoll::Core::Database.connected?}"
puts client.stats
```

## Installation Issues

### Dependency Problems

#### Ruby Version Compatibility

**Issue**: Ragdoll requires Ruby 3.0+
```
ERROR: ragdoll requires Ruby version >= 3.0.0
```

**Solution**:
```bash
# Check Ruby version
ruby --version

# Install Ruby 3.2+ with rbenv
rbenv install 3.2.0
rbenv global 3.2.0

# Or with RVM
rvm install 3.2.0
rvm use 3.2.0 --default
```

#### Gem Installation Failures

**Issue**: Native extension compilation fails
```
ERROR: Failed to build gem native extension.
```

**Solution**:
```bash
# macOS - Install Xcode command line tools
xcode-select --install

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install build-essential libpq-dev

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install postgresql-devel
```

#### System Library Requirements

**Issue**: Missing system dependencies
```
ERROR: pg requires libpq-dev
```

**Solution**:
```bash
# macOS with Homebrew
brew install postgresql libpq

# Ubuntu/Debian
sudo apt-get install libpq-dev postgresql-client

# Add to environment
export PATH="/usr/local/opt/libpq/bin:$PATH"
```

### Database Setup Issues

#### PostgreSQL Connection Problems

**Issue**: Cannot connect to PostgreSQL
```
ERROR: connection to server on socket "/tmp/.s.PGSQL.5432" failed
```

**Diagnosis**:
```ruby
# Test database connection
begin
  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: 'your_password',
    host: 'localhost',
    port: 5432
  )
  puts "Connection successful"
rescue => e
  puts "Connection failed: #{e.message}"
end
```

**Solutions**:
```bash
# Start PostgreSQL service
# macOS with Homebrew
brew services start postgresql

# Ubuntu/Debian
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql
CREATE DATABASE ragdoll_development;
CREATE USER ragdoll WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;
\q
```

#### pgvector Extension Installation

**Issue**: pgvector extension not available
```
ERROR: extension "vector" is not available
```

**Solution**:
```bash
# Install pgvector
# macOS with Homebrew
brew install pgvector

# Ubuntu/Debian
sudo apt install postgresql-16-pgvector

# Manual installation
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Enable extension in database
sudo -u postgres psql -d ragdoll_development
CREATE EXTENSION vector;
\q
```

#### Migration Failures

**Issue**: Database migrations fail
```
ERROR: relation "ragdoll_documents" already exists
```

**Diagnosis**:
```ruby
# Check migration status
Ragdoll::Core::Database.setup(auto_migrate: false)
ActiveRecord::Base.connection.execute(
  "SELECT version FROM schema_migrations ORDER BY version"
)
```

**Solution**:
```ruby
# Reset database (DESTRUCTIVE - development only)
Ragdoll::Core::Database.reset!

# Or manually fix migration state
ActiveRecord::Base.connection.execute(
  "DELETE FROM schema_migrations WHERE version = '004'"
)
Ragdoll::Core::Database.migrate!
```

## Runtime Issues

### Document Processing Errors

#### File Format Parsing Failures

**Issue**: Unsupported or corrupted file formats
```
ERROR: Unable to parse PDF file: Invalid PDF structure
```

**Diagnosis**:
```ruby
# Test document parsing
begin
  result = Ragdoll::Core::DocumentProcessor.parse('/path/to/document.pdf')
  puts "Parsing successful: #{result[:document_type]}"
  puts "Content length: #{result[:content]&.length || 0}"
rescue => e
  puts "Parsing failed: #{e.message}"
  puts "Error class: #{e.class}"
end
```

**Solutions**:
```ruby
# Check file integrity
file_path = '/path/to/document.pdf'
if File.exist?(file_path)
  puts "File size: #{File.size(file_path)} bytes"
  puts "File readable: #{File.readable?(file_path)}"
  
  # Try alternative parsing approach
  begin
    content = File.read(file_path, encoding: 'binary')
    puts "File header: #{content[0..10].bytes.map(&:to_s).join(' ')}"
  rescue => e
    puts "Cannot read file: #{e.message}"
  end
else
  puts "File does not exist: #{file_path}"
end
```

#### Content Extraction Problems

**Issue**: Empty or garbled content extraction
```
WARNING: Extracted content is empty or contains only whitespace
```

**Diagnosis**:
```ruby
# Debug content extraction
class DebugDocumentProcessor < Ragdoll::Core::DocumentProcessor
  def self.parse_with_debug(file_path)
    puts "Processing: #{file_path}"
    puts "File size: #{File.size(file_path)}"
    
    result = parse(file_path)
    
    puts "Document type: #{result[:document_type]}"
    puts "Content length: #{result[:content]&.length || 0}"
    puts "Content preview: #{result[:content]&.[](0..200)}"
    puts "Metadata keys: #{result[:metadata]&.keys}"
    
    result
  end
end
```

### Search and Embedding Issues

#### Vector Generation Failures

**Issue**: Embedding service errors
```
ERROR: Failed to generate embedding: OpenAI API key not configured
```

**Diagnosis**:
```ruby
# Test embedding generation
service = Ragdoll::Core::EmbeddingService.new
begin
  embedding = service.generate_embedding("test text")
  puts "Embedding generated: #{embedding&.length || 0} dimensions"
rescue => e
  puts "Embedding failed: #{e.message}"
  puts "Configuration check:"
  puts "OpenAI API Key: #{ENV['OPENAI_API_KEY'] ? 'Set' : 'Missing'}"
end
```

**Solutions**:
```ruby
# Check and fix configuration
Ragdoll::Core.configure do |config|
  # Verify API keys are set
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  if ENV['OPENAI_API_KEY'].nil? || ENV['OPENAI_API_KEY'].empty?
    puts "ERROR: OPENAI_API_KEY environment variable not set"
    puts "Set it with: export OPENAI_API_KEY=your_api_key"
  end
end
```

#### Similarity Search Problems

**Issue**: Search returns no results despite having documents
```
INFO: Search query returned 0 results
```

**Diagnosis**:
```ruby
# Debug search process
client = Ragdoll::Core.client
query = "machine learning"

puts "Documents in database: #{Ragdoll::Core::Models::Document.count}"
puts "Embeddings in database: #{Ragdoll::Core::Models::Embedding.count}"

# Test embedding generation
embedding_service = Ragdoll::Core::EmbeddingService.new
query_embedding = embedding_service.generate_embedding(query)
puts "Query embedding dimensions: #{query_embedding&.length || 0}"

# Test direct embedding search
results = Ragdoll::Core::Models::Embedding.search_similar(
  query_embedding,
  limit: 10,
  threshold: 0.1  # Lower threshold for debugging
)
puts "Direct search results: #{results.length}"
```

### Database Problems

#### Connection Timeouts

**Issue**: Database operations timing out
```
ERROR: connection timed out
```

**Solutions**:
```ruby
# Increase connection timeout
Ragdoll::Core.configure do |config|
  config.database_config.merge!({
    pool: 10,
    timeout: 10000,  # 10 seconds
    checkout_timeout: 5,
    reaping_frequency: 10
  })
end

# Monitor connection pool
pool = ActiveRecord::Base.connection_pool
puts "Pool size: #{pool.size}"
puts "Checked out: #{pool.checked_out_connections.size}"
puts "Available: #{pool.available_connection_count}"
```

#### Index Performance Issues

**Issue**: Slow vector similarity searches
```
WARNING: Vector search took 5.2 seconds
```

**Diagnosis**:
```sql
-- Check index usage
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM ragdoll_embeddings 
ORDER BY embedding_vector <-> '[0.1,0.2,0.3,...]'::vector 
LIMIT 10;

-- Check index statistics
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE tablename = 'ragdoll_embeddings';
```

**Solutions**:
```sql
-- Recreate vector index with better parameters
DROP INDEX IF EXISTS ragdoll_embeddings_vector_idx;
CREATE INDEX CONCURRENTLY ragdoll_embeddings_vector_idx 
ON ragdoll_embeddings 
USING ivfflat (embedding_vector vector_cosine_ops) 
WITH (lists = 100);

-- Or use HNSW for better performance
CREATE INDEX CONCURRENTLY ragdoll_embeddings_hnsw_idx 
ON ragdoll_embeddings 
USING hnsw (embedding_vector vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);
```

## Configuration Issues

### LLM Provider Configuration

#### API Key Validation

**Issue**: Invalid or expired API keys
```
ERROR: Authentication failed for OpenAI API
```

**Validation Script**:
```ruby
# Test API key validity
class APIKeyValidator
  def self.validate_openai_key(api_key)
    require 'faraday'
    
    conn = Faraday.new(url: 'https://api.openai.com')
    response = conn.get('/v1/models') do |req|
      req.headers['Authorization'] = "Bearer #{api_key}"
    end
    
    case response.status
    when 200
      puts "✓ OpenAI API key is valid"
      true
    when 401
      puts "✗ OpenAI API key is invalid or expired"
      false
    else
      puts "? Unexpected response: #{response.status}"
      false
    end
  end
end

APIKeyValidator.validate_openai_key(ENV['OPENAI_API_KEY'])
```

#### Provider-Specific Issues

**Issue**: Rate limiting errors
```
ERROR: Rate limit exceeded for OpenAI API
```

**Solutions**:
```ruby
# Implement exponential backoff
class RateLimitHandler
  def self.with_retry(max_retries: 3, base_delay: 1)
    retries = 0
    
    begin
      yield
    rescue => e
      if e.message.include?('rate limit') && retries < max_retries
        delay = base_delay * (2 ** retries)
        puts "Rate limited, retrying in #{delay} seconds..."
        sleep(delay)
        retries += 1
        retry
      else
        raise e
      end
    end
  end
end

# Use with embedding generation
RateLimitHandler.with_retry do
  service.generate_embedding(text)
end
```

## Performance Issues

### Slow Search Performance

**Diagnosis Tools**:
```ruby
# Performance profiler
class SearchProfiler
  def self.profile_search(query, iterations: 10)
    times = []
    
    iterations.times do
      start_time = Time.current
      client = Ragdoll::Core.client
      results = client.search(query: query)
      end_time = Time.current
      
      duration = (end_time - start_time) * 1000
      times << duration
      
      puts "Search #{iterations}: #{duration.round(2)}ms (#{results[:total_results]} results)"
    end
    
    avg_time = times.sum / times.length
    puts "Average search time: #{avg_time.round(2)}ms"
    puts "Min: #{times.min.round(2)}ms, Max: #{times.max.round(2)}ms"
  end
end

SearchProfiler.profile_search("machine learning")
```

### Background Job Issues

#### Queue Backlog Problems

**Diagnosis**:
```ruby
# Monitor job queues
if defined?(Sidekiq)
  puts "Queue sizes:"
  Sidekiq::Queue.all.each do |queue|
    puts "  #{queue.name}: #{queue.size} jobs"
  end
  
  puts "\nFailed jobs: #{Sidekiq::RetrySet.new.size}"
  puts "Dead jobs: #{Sidekiq::DeadSet.new.size}"
else
  puts "Using inline job processing"
end
```

**Solutions**:
```ruby
# Scale workers dynamically
class JobQueueMonitor
  def self.monitor_and_scale
    queue = Sidekiq::Queue.new('embeddings')
    
    if queue.size > 100
      puts "High queue size detected: #{queue.size}"
      # Scale up workers (implementation depends on deployment)
      scale_workers_up
    elsif queue.size < 10
      puts "Low queue size: #{queue.size}"
      # Scale down workers
      scale_workers_down
    end
  end
end
```

## Debugging Tools

### Logging Configuration

```ruby
# Enhanced logging setup
Ragdoll::Core.configure do |config|
  config.logging_config[:level] = :debug
  
  # Custom logger with detailed formatting
  logger = Logger.new(STDOUT)
  logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} #{progname}: #{msg}\n"
  end
  
  config.database_config[:logger] = logger
end
```

### Development Console

```ruby
# Debug console helpers
class RagdollDebug
  def self.system_info
    {
      ruby_version: RUBY_VERSION,
      rails_version: defined?(Rails) ? Rails.version : 'N/A',
      database_adapter: ActiveRecord::Base.connection.adapter_name,
      total_documents: Ragdoll::Core::Models::Document.count,
      total_embeddings: Ragdoll::Core::Models::Embedding.count,
      last_document: Ragdoll::Core::Models::Document.last&.title,
      system_healthy: Ragdoll::Core.client.healthy?
    }
  end
  
  def self.test_pipeline(text = "Hello world")
    puts "Testing complete pipeline..."
    
    # Test embedding generation
    service = Ragdoll::Core::EmbeddingService.new
    embedding = service.generate_embedding(text)
    puts "✓ Embedding generated: #{embedding.length} dimensions"
    
    # Test search
    client = Ragdoll::Core.client
    results = client.search(query: text)
    puts "✓ Search completed: #{results[:total_results]} results"
    
    true
  rescue => e
    puts "✗ Pipeline test failed: #{e.message}"
    false
  end
end

# Usage in console
RagdollDebug.system_info
RagdollDebug.test_pipeline
```

## Error Reference

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Ragdoll::Core::EmbeddingError` | LLM API issues | Check API keys and network |
| `Ragdoll::Core::DocumentError` | File processing failure | Verify file format and permissions |
| `Ragdoll::Core::SearchError` | Search operation failure | Check database indexes |
| `Ragdoll::Core::ConfigurationError` | Invalid configuration | Validate configuration settings |
| `ActiveRecord::ConnectionNotEstablished` | Database connection failure | Check PostgreSQL service and credentials |

## Support Resources

### Self-Diagnosis Checklist

- [ ] Ruby version 3.0+ installed
- [ ] PostgreSQL service running
- [ ] pgvector extension installed
- [ ] Database user has proper permissions
- [ ] API keys configured in environment
- [ ] Required system libraries installed
- [ ] Network connectivity to LLM providers
- [ ] Sufficient disk space for embeddings
- [ ] Memory allocation adequate for workload
- [ ] Background job system functioning

### Getting Help

1. **Documentation**: Check the [Architecture Guide](architecture.md) and [Configuration Guide](configuration.md)
2. **Logs**: Enable debug logging and examine error messages
3. **System Health**: Run the diagnostic commands provided above  
4. **Community**: Search existing issues and discussions
5. **Issue Reporting**: Provide system info, error logs, and reproduction steps

### Emergency Recovery

```ruby
# Complete system reset (DEVELOPMENT ONLY)
Ragdoll::Core::Database.reset!
Ragdoll::Core.configure do |config|
  # Restore minimal configuration
  config.database_config[:auto_migrate] = true
end

# Verify system health
client = Ragdoll::Core.client
puts "System recovered: #{client.healthy?}"
```

---

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*