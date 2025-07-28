# Configuration Guide

Ragdoll features a comprehensive configuration system that supports enterprise-grade deployments with fine-grained control over all aspects of the system. The configuration supports multiple LLM providers, database adapters, processing parameters, and operational settings.

## Overview

The configuration system provides 25+ configurable options organized into logical groups:

- **LLM Provider Configuration**: Multiple provider support with API key management
- **Database Configuration**: PostgreSQL with pgvector extension (REQUIRED)
- **Processing Parameters**: Chunking, embedding, and content analysis settings
- **Search Configuration**: Similarity thresholds, ranking weights, and result limits
- **Operational Settings**: Logging, monitoring, background processing, and performance tuning
- **Feature Toggles**: Enable/disable optional features and advanced capabilities

## Basic Configuration

### Simple Setup

```ruby
require 'ragdoll'

Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  # Database (PostgreSQL REQUIRED)
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end
```

### Production Setup

```ruby
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:openai][:organization] = ENV['OPENAI_ORGANIZATION']
  config.ruby_llm_config[:openai][:project] = ENV['OPENAI_PROJECT']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  config.models[:summary] = 'openai/gpt-4o'
  config.models[:keywords] = 'openai/gpt-4o-mini'
  
  # Production PostgreSQL with pgvector
  config.database_config = {
    adapter: 'postgresql',
    database: ENV['DATABASE_NAME'] || 'ragdoll_production',
    username: ENV['DATABASE_USERNAME'] || 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    pool: ENV['DATABASE_POOL'] || 20,
    auto_migrate: false  # Handle migrations separately in production
  }
  
  # Production logging
  config.logging_config[:log_level] = :info
  config.logging_config[:log_filepath] = '/var/log/ragdoll/ragdoll.log'
  
  # Performance settings
  config.chunking[:text][:max_tokens] = 1000
  config.chunking[:text][:overlap] = 200
  config.search[:similarity_threshold] = 0.75
  config.search[:max_results] = 50
  
  # Enable summarization
  config.summarization_config[:enable] = true
  config.summarization_config[:max_length] = 300
end
```

## LLM Provider Configuration

### Supported Providers

Ragdoll supports 7 LLM providers through the ruby_llm integration:

```ruby
# OpenAI (recommended for production)
config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
config.ruby_llm_config[:openai][:organization] = ENV['OPENAI_ORGANIZATION']
config.ruby_llm_config[:openai][:project] = ENV['OPENAI_PROJECT']
config.models[:embedding][:text] = 'text-embedding-3-small'  # or text-embedding-3-large
config.models[:default] = 'openai/gpt-4o'
config.models[:summary] = 'openai/gpt-4o'
config.models[:keywords] = 'openai/gpt-4o-mini'

# Anthropic Claude
config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']  # Still needed for embeddings
config.models[:embedding][:text] = 'text-embedding-3-small'  # OpenAI embeddings
config.models[:default] = 'anthropic/claude-3-sonnet-20240229'
config.models[:summary] = 'anthropic/claude-3-sonnet-20240229'
config.models[:keywords] = 'anthropic/claude-3-haiku-20240307'

# Google Gemini
config.ruby_llm_config[:google][:api_key] = ENV['GOOGLE_API_KEY']
config.ruby_llm_config[:google][:project_id] = ENV['GOOGLE_PROJECT_ID']
config.models[:default] = 'google/gemini-1.5-pro'
config.models[:summary] = 'google/gemini-1.5-pro'
config.models[:keywords] = 'google/gemini-1.5-flash'

# Azure OpenAI
config.ruby_llm_config[:azure][:api_key] = ENV['AZURE_OPENAI_API_KEY']
config.ruby_llm_config[:azure][:endpoint] = ENV['AZURE_OPENAI_ENDPOINT']
config.ruby_llm_config[:azure][:api_version] = ENV['AZURE_OPENAI_API_VERSION']
config.models[:embedding][:text] = 'text-embedding-ada-002'
config.models[:default] = 'azure/gpt-4'

# Ollama (local deployment)
config.ruby_llm_config[:ollama][:endpoint] = ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434/v1'
config.models[:default] = 'ollama/llama3:8b'
config.models[:summary] = 'ollama/llama3:8b'
config.models[:keywords] = 'ollama/llama3:8b'
config.models[:embedding][:text] = 'nomic-embed-text'

# HuggingFace
config.ruby_llm_config[:huggingface][:api_key] = ENV['HUGGINGFACE_API_KEY']
config.models[:default] = 'huggingface/microsoft/DialoGPT-medium'
config.models[:embedding][:text] = 'sentence-transformers/all-MiniLM-L6-v2'

# OpenRouter (access to multiple models)
config.ruby_llm_config[:openrouter][:api_key] = ENV['OPENROUTER_API_KEY']
config.models[:default] = 'openrouter/anthropic/claude-3-sonnet'
config.models[:summary] = 'openrouter/anthropic/claude-3-sonnet'
config.models[:keywords] = 'openrouter/openai/gpt-3.5-turbo'
```

### Multi-Provider Configuration

```ruby
# Use different providers for different tasks
Ragdoll::Core.configure do |config|
  # Configure multiple Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
  config.ruby_llm_config[:ollama][:endpoint] = 'http://localhost:11434/v1'
  
  # Configure models for different tasks
  config.models[:embedding][:text] = 'text-embedding-3-small'  # OpenAI embeddings
  config.models[:default] = 'openai/gpt-4o-mini'              # OpenAI for general tasks
  config.models[:summary] = 'anthropic/claude-3-sonnet-20240229'  # Claude for summarization
  config.models[:keywords] = 'ollama/llama3:8b'               # Local Ollama for keywords
end
```

## Database Configuration

**Important Note**: Ragdoll ONLY supports PostgreSQL. The system requires the pgvector extension for vector similarity search and uses PostgreSQL-specific features. SQLite is not supported.

### PostgreSQL with pgvector (Recommended for Production)

```ruby
config.database_config = {
  adapter: 'postgresql',
  database: 'ragdoll_production',
  username: 'ragdoll_user',
  password: ENV['DATABASE_PASSWORD'],
  host: 'postgres.example.com',
  port: 5432,
  pool: 25,                    # Connection pool size
  timeout: 5000,               # Connection timeout (ms)
  auto_migrate: false,         # Handle migrations separately
  sslmode: 'require',          # SSL configuration
  
  # pgvector specific settings
  extensions: ['vector'],
  search_path: ['public', 'vector'],
  
  # Performance tuning
  prepared_statements: true,
  advisory_locks: true,
  variables: {
    'shared_preload_libraries' => 'vector',
    'max_connections' => '200',
    'shared_buffers' => '256MB',
    'effective_cache_size' => '1GB'
  }
}
```

### Important: PostgreSQL Only

Ragdoll exclusively supports PostgreSQL with the pgvector extension. This is required for:

- Vector similarity search operations  
- Advanced PostgreSQL features like GIN indexes for full-text search
- JSON field operations and queries
- Optimized performance for large document collections

No other database adapters are supported.

### Database Environment Configuration

```ruby
# Environment-specific database configuration (PostgreSQL for all environments)
case Rails.env
when 'development'
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
when 'test'
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_test',
    username: 'ragdoll',  
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
when 'production'
  config.database_config = {
    adapter: 'postgresql',
    url: ENV['DATABASE_URL'],  # Use connection URL
    pool: ENV.fetch('RAILS_MAX_THREADS', 25).to_i,
    auto_migrate: false
  }
end
```

## Processing Configuration

### Text Processing

**Schema Note**: The `embedding_model` is now stored per content type (text, image, audio) rather than duplicated in individual embeddings. This provides better data normalization while maintaining functionality through polymorphic relationships.

```ruby
config.chunk_size = 1000              # Characters per text chunk
config.chunk_overlap = 200            # Overlap between chunks
config.max_chunk_size = 2000          # Maximum chunk size limit
config.min_chunk_size = 100           # Minimum chunk size limit

# Language and encoding
config.default_language = 'en'       # Default language for processing
config.auto_detect_language = true   # Enable language detection
config.encoding_fallbacks = ['UTF-8', 'ISO-8859-1', 'Windows-1252']

# Text cleaning
config.remove_extra_whitespace = true
config.normalize_unicode = true
config.strip_html_tags = true
config.preserve_code_blocks = true
```

### Document Processing

```ruby
# PDF processing
config.pdf_max_pages = 1000           # Maximum pages to process
config.pdf_extract_images = true     # Extract images from PDFs
config.pdf_extract_tables = true     # Extract table content
config.pdf_ocr_fallback = true       # Use OCR for scanned PDFs

# Image processing
config.image_max_size = 10.megabytes # Maximum image file size
config.image_formats = %w[jpg jpeg png gif webp bmp tiff]
config.generate_image_descriptions = true
config.image_description_model = 'gpt-4-vision-preview'

# Audio processing
config.audio_max_duration = 3600     # Maximum audio duration (seconds)
config.audio_formats = %w[mp3 wav flac m4a ogg]
config.speech_to_text_provider = :openai
config.audio_chunk_duration = 300    # Chunk audio files (seconds)
```

## Search Configuration

### Basic Search Settings

```ruby
config.search_similarity_threshold = 0.7    # Minimum similarity score
config.max_search_results = 20              # Maximum results per search
config.enable_usage_analytics = true       # Track search usage
config.search_cache_ttl = 300.seconds      # Cache search results

# Cross-modal search
config.enable_cross_modal_search = true
config.content_type_weights = {
  'text' => 1.0,
  'image' => 0.8,
  'audio' => 0.7
}
```

### Advanced Search Configuration

```ruby
# Ranking algorithm weights
config.ranking_weights = {
  similarity: 0.6,                    # Semantic similarity weight
  usage: 0.3,                         # Usage frequency weight
  recency: 0.1                        # Document recency weight
}

# Hybrid search settings
config.enable_fulltext_search = true
config.fulltext_search_weight = 0.3
config.semantic_search_weight = 0.7

# Search suggestions
config.enable_search_suggestions = true
config.suggestion_cache_ttl = 3600.seconds
config.max_suggestions = 10

# Performance settings
config.vector_index_lists = 100      # IVFFlat index lists
config.search_timeout = 30.seconds   # Search operation timeout
config.embedding_cache_size = 1000   # LRU cache for embeddings
```

## Background Processing Configuration

### Job Queue Settings

```ruby
config.enable_background_processing = true
config.job_queue_prefix = 'ragdoll'
config.job_timeout = 300.seconds
config.max_retry_attempts = 3

# Queue priorities
config.embedding_queue_priority = 10    # High priority
config.processing_queue_priority = 5    # Medium priority
config.analysis_queue_priority = 1      # Low priority

# Batch processing
config.batch_processing_size = 100
config.batch_processing_delay = 5.seconds
```

### Feature Toggles

```ruby
# Optional features
config.enable_keyword_extraction = true
config.enable_document_summarization = true
config.enable_summary_embeddings = true
config.enable_image_descriptions = true
config.enable_audio_transcription = true

# Analytics and monitoring
config.enable_usage_analytics = true
config.enable_performance_monitoring = true
config.enable_search_analytics = true
config.analytics_batch_size = 100
config.analytics_flush_interval = 60.seconds
```

## Logging Configuration

### Log Levels and Output

```ruby
# Log level configuration
config.log_level = :info              # :debug, :info, :warn, :error, :fatal
config.log_file = '/var/log/ragdoll/ragdoll.log'
config.log_rotation = 'daily'         # 'daily', 'weekly', 'monthly'
config.log_max_size = 100.megabytes   # Maximum log file size

# Structured logging
config.log_format = :json             # :json, :logfmt, :plain
config.log_timestamp = true
config.log_correlation_id = true      # Include correlation IDs

# Component-specific logging
config.log_levels = {
  'SearchEngine' => :debug,
  'EmbeddingService' => :info,
  'DocumentProcessor' => :warn,
  'BackgroundJobs' => :info
}
```

### Development Logging

```ruby
# Development-specific logging
if Rails.env.development?
  config.log_level = :debug
  config.log_file = nil              # Log to stdout
  config.log_format = :plain
  config.log_sql_queries = true
  config.log_embedding_requests = true
  config.log_search_queries = true
end
```

## Performance Configuration

### Memory and Caching

```ruby
# Cache configuration
config.enable_query_cache = true
config.embedding_cache_ttl = 3600.seconds
config.search_cache_ttl = 300.seconds
config.metadata_cache_ttl = 1800.seconds

# Memory management
config.max_memory_usage = 2.gigabytes
config.garbage_collection_frequency = 1000  # Requests between GC
config.connection_pool_size = 25
config.connection_checkout_timeout = 5.seconds
```

### Database Optimization

```ruby
# Query optimization
config.use_prepared_statements = true
config.enable_query_logging = false   # Disable in production
config.statement_timeout = 30.seconds
config.idle_transaction_timeout = 60.seconds

# Index configuration
config.auto_create_indexes = true
config.vector_index_type = 'ivfflat'  # 'ivfflat' or 'hnsw'
config.index_maintenance_interval = 1.day
```

## Environment-Specific Configuration

### Development Configuration

```ruby
# config/environments/development.rb
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  
  config.logging_config[:log_level] = :debug
  config.logging_config[:log_filepath] = nil  # stdout
  
  # Disable expensive features in development
  config.summarization_config[:enable] = false
  config.keywords_config[:enable] = false
  config.background_processing_config[:enable] = false
  
  # Fast development settings
  config.chunking[:text][:max_tokens] = 500
  config.search[:max_results] = 10
  config.search[:cache_ttl] = 60
end
```

### Test Configuration

```ruby
# config/environments/test.rb
Ragdoll::Core.configure do |config|
  # Use test doubles for LLM services
  config.ruby_llm_config[:test][:api_key] = 'test-key'
  
  # Configure test models
  config.models[:embedding][:text] = 'test-embedding-model'
  config.models[:default] = 'test/test-model'
  
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_test',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  
  config.logging_config[:log_level] = :fatal  # Suppress logs in tests
  
  # Disable external services
  config.background_processing_config[:enable] = false
  config.analytics_config[:enable] = false
  config.summarization_config[:enable] = false
  
  # Fast test settings
  config.chunking[:text][:max_tokens] = 100
  config.search[:max_results] = 5
  config.search[:similarity_threshold] = 0.5
end
```

### Production Configuration

```ruby
# config/environments/production.rb
Ragdoll::Core.configure do |config|
  # Configure Ruby LLM providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  
  # Configure production models
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:default] = 'openai/gpt-4o-mini'
  
  config.database_config = {
    adapter: 'postgresql',
    url: ENV['DATABASE_URL'],
    pool: ENV.fetch('RAILS_MAX_THREADS', 25).to_i,
    auto_migrate: false
  }
  
  config.logging_config[:log_level] = :info
  config.logging_config[:log_filepath] = '/var/log/ragdoll/ragdoll.log'
  config.logging_config[:format] = :json
  
  # Enable all production features
  config.background_processing_config[:enable] = true
  config.analytics_config[:enable] = true
  config.summarization_config[:enable] = true
  config.keywords_config[:enable] = true
  
  # Production performance settings
  config.chunking[:text][:max_tokens] = 1000
  config.chunking[:text][:overlap] = 200
  config.search[:max_results] = 50
  config.search[:similarity_threshold] = 0.75
  
  # Cache settings
  config.search[:cache_ttl] = 300
  config.embedding_cache[:ttl] = 3600
  
  # Security settings
  config.logging_config[:log_requests] = false  # May contain sensitive data
  config.logging_config[:log_embedding_content] = false   # Don't log actual content
end
```

## Configuration Validation

### Validation Rules

```ruby
class ConfigurationValidator
  def self.validate!(config)
    validate_required_settings!(config)
    validate_llm_provider!(config)
    validate_database_config!(config)
    validate_numeric_ranges!(config)
    validate_feature_dependencies!(config)
  end
  
  private
  
  def self.validate_required_settings!(config)
    required = [:llm_provider, :embedding_model, :database_config]
    missing = required.select { |setting| config.send(setting).nil? }
    
    unless missing.empty?
      raise ConfigurationError, "Missing required settings: #{missing.join(', ')}"
    end
  end
  
  def self.validate_llm_provider!(config)
    valid_providers = [:openai, :anthropic, :google, :azure, :ollama, :huggingface, :openrouter]
    
    unless valid_providers.include?(config.llm_provider)
      raise ConfigurationError, "Invalid LLM provider: #{config.llm_provider}"
    end
    
    # Validate provider-specific settings
    case config.llm_provider
    when :openai
      raise ConfigurationError, "OpenAI API key required" if config.openai_api_key.blank?
    when :anthropic
      raise ConfigurationError, "Anthropic API key required" if config.anthropic_api_key.blank?
    # ... other providers
    end
  end
end
```

## Dynamic Configuration

### Runtime Configuration Updates

```ruby
# Update configuration at runtime
Ragdoll::Core.configure do |config|
  config.search_similarity_threshold = 0.8
  config.max_search_results = 30
end

# Temporary configuration for specific operations
Ragdoll::Core.with_configuration(llm_provider: :anthropic) do
  # Use Anthropic for this operation
  result = Ragdoll::Core.search("complex query requiring Claude")
end
```

### Configuration Monitoring

```ruby
# Monitor configuration changes
class ConfigurationMonitor
  def self.track_changes
    Ragdoll::Core.configuration.on_change do |setting, old_value, new_value|
      Rails.logger.info "Configuration changed: #{setting} = #{new_value} (was #{old_value})"
      
      # Trigger cache invalidation if needed
      if [:search_similarity_threshold, :max_search_results].include?(setting)
        SearchCache.clear
      end
    end
  end
end
```

## Best Practices

### 1. Environment Management
- Use environment variables for sensitive settings (API keys, database passwords)
- Create environment-specific configuration files
- Validate configuration on application startup
- Document all configuration options for your team

### 2. Security Considerations
- Never commit API keys or passwords to version control
- Use encrypted credential management in production
- Disable verbose logging of sensitive data in production
- Implement configuration validation and sanitization

### 3. Performance Optimization
- Tune chunk sizes based on your content characteristics
- Adjust similarity thresholds based on search quality requirements
- Configure appropriate cache TTLs for your usage patterns
- Monitor and adjust database connection pool sizes

### 4. Operational Excellence
- Implement configuration monitoring and alerting
- Use structured logging for better observability
- Plan for configuration changes without service restarts
- Document configuration dependencies and interactions

The configuration system in Ragdoll provides the flexibility needed for both development simplicity and production sophistication, enabling you to tune the system precisely for your specific use case and operational requirements.