# Jobs Reference

Ragdoll uses ActiveJob for background processing of document analysis, content extraction, and embedding generation. The job system provides reliable, asynchronous processing with comprehensive error handling and monitoring capabilities.

## Background Job System

The background job system orchestrates multi-step document processing workflows, ensuring efficient handling of large documents and compute-intensive AI operations. All jobs inherit from `ActiveJob::Base` and integrate seamlessly with Rails job queue adapters including Sidekiq, Resque, and Delayed Job.

**Key Features:**
- Asynchronous document processing pipeline
- Automatic job chaining and dependency management
- Comprehensive error handling with status tracking
- Built-in retry mechanisms with exponential backoff
- Integration with document status lifecycle management

## Core Jobs

Ragdoll includes four primary job classes that handle the complete document processing pipeline:

### ExtractText

The `ExtractText` job initiates the document processing pipeline by extracting text content from uploaded files.

```ruby
module Ragdoll
  module Core
    module Jobs
      class ExtractText < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
          return unless document.file_attached?
          return if document.content.present?

          document.update!(status: "processing")

          extracted_content = document.extract_text_from_file

          if extracted_content.present?
            document.update!(
              content: extracted_content,
              status: "processed"
            )

            # Queue follow-up jobs
            GenerateSummaryJob.perform_later(document_id)
            GenerateKeywordsJob.perform_later(document_id)
            GenerateEmbeddingsJob.perform_later(document_id)
          else
            document.update!(status: "error")
          end
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          document&.update!(status: "error")
          raise e
        end
      end
    end
  end
end
```

**Key Responsibilities:**
- **File Processing**: Extracts text from PDF, DOCX, HTML, and other supported formats
- **Status Management**: Updates document status through processing lifecycle
- **Job Orchestration**: Triggers downstream jobs upon successful completion
- **Error Recovery**: Handles file access errors and processing failures

**Usage Examples:**
```ruby
# Queue text extraction for a document
Ragdoll::Core::Jobs::ExtractText.perform_later(document.id)

# Process immediately (synchronous)
Ragdoll::Core::Jobs::ExtractText.perform_now(document.id)

# Schedule for later processing
Ragdoll::Core::Jobs::ExtractText.set(wait: 1.hour).perform_later(document.id)
```

### GenerateEmbeddings

The `GenerateEmbeddings` job creates vector embeddings for all content associated with a document.

```ruby
module Ragdoll
  module Core
    module Jobs
      class GenerateEmbeddings < ActiveJob::Base
        queue_as :default

        def perform(document_id, chunk_size: nil, chunk_overlap: nil)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.all_embeddings.exists?

          # Process all content records using their own generate_embeddings! methods
          document.contents.each(&:generate_embeddings!)

          # Update document status to processed
          document.update!(status: "processed")
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          if defined?(Rails)
            Rails.logger.error "Failed to generate embeddings for document #{document_id}: #{e.message}"
          end
          raise e
        end
      end
    end
  end
end
```

**Key Features:**
- **Multi-Modal Support**: Handles text, image, and audio content embeddings
- **Chunking Integration**: Respects content-specific chunking strategies  
- **Batch Processing**: Processes multiple content chunks efficiently
- **Provider Abstraction**: Works with OpenAI, Hugging Face, and other embedding providers

**Configuration Options:**
```ruby
# Custom chunk sizing
Ragdoll::Core::Jobs::GenerateEmbeddings.perform_later(
  document.id,
  chunk_size: 1500,
  chunk_overlap: 300
)

# Monitor embedding generation
document.contents.each do |content|
  puts "Embeddings for #{content.type}: #{content.embeddings.count}"
end
```

### ExtractKeywords

The `ExtractKeywords` job uses LLM-powered analysis to extract relevant keywords from document content.

```ruby
module Ragdoll
  module Core
    module Jobs
      class ExtractKeywords < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.keywords.present?

          text_service = TextGenerationService.new
          keywords_array = text_service.extract_keywords(document.content)

          if keywords_array.present?
            keywords_string = keywords_array.join(", ")
            document.update!(keywords: keywords_string)
          end
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          Rails.logger.error "Failed to generate keywords for document #{document_id}: #{e.message}" if defined?(Rails)
          raise e
        end
      end
    end
  end
end
```

**LLM Integration:**
- Uses configured LLM provider (OpenAI, Anthropic, etc.)
- Applies intelligent keyword extraction prompts
- Validates and formats keyword output
- Stores keywords as searchable metadata

**Quality Controls:**
```ruby
# Keywords are stored as comma-separated strings
document.keywords # => "machine learning, artificial intelligence, neural networks"

# Access as array for programmatic use
document.keywords_array # => ["machine learning", "artificial intelligence", "neural networks"]

# Add/remove keywords programmatically
document.add_keyword("deep learning")
document.remove_keyword("outdated term")
```

### GenerateSummary

The `GenerateSummary` job creates concise summaries of document content using LLM providers.

```ruby
module Ragdoll
  module Core
    module Jobs
      class GenerateSummary < ActiveJob::Base
        queue_as :default

        def perform(document_id)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.summary.present?

          text_service = TextGenerationService.new
          summary = text_service.generate_summary(document.content)

          document.update!(summary: summary) if summary.present?
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          Rails.logger.error "Failed to generate summary for document #{document_id}: #{e.message}" if defined?(Rails)
          raise e
        end
      end
    end
  end
end
```

**Summarization Features:**
- **Configurable Length**: Respects `summary_max_length` configuration
- **Content Analysis**: Identifies key themes and concepts
- **Multi-Provider Support**: Works with GPT, Claude, Gemini, and other LLMs
- **Quality Validation**: Ensures summary quality and relevance

**Configuration Examples:**
```ruby
# Configure summarization in Ragdoll config
Ragdoll::Core.configure do |config|
  config.summarization_config[:enable] = true
  config.summarization_config[:max_length] = 300
  config.summarization_config[:min_content_length] = 500
end

# Access generated summaries
document.summary # => "This document discusses machine learning applications..."
document.has_summary? # => true
```

## Job Configuration

Ragdoll jobs are built on ActiveJob, providing flexible configuration options for different deployment scenarios.

### Queue Adapters

Support for all major ActiveJob queue adapters:

```ruby
# config/application.rb or initializer
config.active_job.queue_adapter = :sidekiq    # Production recommended
# config.active_job.queue_adapter = :resque   # Alternative production option
# config.active_job.queue_adapter = :inline   # Development/testing only
# config.active_job.queue_adapter = :async    # Development with background processing
```

**Sidekiq Configuration (Recommended for Production):**
```ruby
# config/sidekiq.yml
:concurrency: 10
:queues:
  - default
  - ragdoll_processing
  - ragdoll_embeddings

# Gemfile
gem 'sidekiq'
gem 'redis' # Required for Sidekiq

# config/routes.rb (for web UI)
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

**Queue-Specific Configuration:**
```ruby
# Custom job queues for different processing types
class ExtractText < ActiveJob::Base
  queue_as :document_processing
end

class GenerateEmbeddings < ActiveJob::Base
  queue_as :ai_processing  # Separate queue for AI operations
end

# Environment-specific queue names
class ExtractKeywords < ActiveJob::Base
  queue_as Rails.env.production? ? :production_ai : :development_ai
end
```

### Retry Policies and Backoff

Comprehensive retry configuration with exponential backoff:

```ruby
module Ragdoll
  module Core
    module Jobs
      class BaseJob < ActiveJob::Base
        # Default retry configuration for all Ragdoll jobs
        retry_on StandardError, wait: :exponentially_longer, attempts: 5
        retry_on Timeout::Error, wait: 30.seconds, attempts: 3
        retry_on ActiveRecord::ConnectionNotEstablished, wait: 5.seconds, attempts: 10
        
        # Specific handling for different error types
        retry_on Net::TimeoutError, wait: :exponentially_longer, attempts: 3
        discard_on ActiveRecord::RecordNotFound
        discard_on ArgumentError
        
        # Custom retry logic
        retry_on CustomAPIError do |job, exception|
          if exception.response_code == 429 # Rate limited
            job.retry_job(wait: 1.minute)
          elsif exception.response_code >= 500
            job.retry_job(wait: :exponentially_longer)
          else
            job.discard_job
          end
        end
      end
    end
  end
end

# Job-specific retry policies
class GenerateEmbeddings < BaseJob
  # AI API calls may need different retry behavior
  retry_on OpenAI::APIError, wait: 2.minutes, attempts: 3
  retry_on Anthropic::RateLimitError, wait: 5.minutes, attempts: 2
end
```

### Timeout Settings

Configurable timeouts for different job types:

```ruby
# Per-job timeout configuration
class ExtractText < ActiveJob::Base
  # Large PDFs may take time to process
  queue_with_priority 10
  timeout 15.minutes
end

class GenerateEmbeddings < ActiveJob::Base
  # AI operations can be slow
  timeout 30.minutes
end

# Global timeout configuration
# config/application.rb
config.active_job.default_timeout = 10.minutes

# Sidekiq-specific timeout
# config/sidekiq.yml
:timeout: 1800  # 30 minutes
```

### Priority Levels

Job prioritization for optimal resource allocation:

```ruby
# High priority for user-facing operations
class ExtractText < ActiveJob::Base
  queue_with_priority 100  # Higher number = higher priority
end

# Lower priority for background optimization
class GenerateEmbeddings < ActiveJob::Base
  queue_with_priority 50
end

# Dynamic priority based on content
class ProcessDocument
  def self.enqueue_with_priority(document)
    priority = case document.document_type
               when 'urgent' then 100
               when 'normal' then 50
               else 10
               end
    
    ExtractText.set(priority: priority).perform_later(document.id)
  end
end

# Sidekiq priority queues
# config/sidekiq.yml
:queues:
  - [urgent, 10]      # High priority, weight 10
  - [normal, 5]       # Normal priority, weight 5
  - [background, 1]   # Low priority, weight 1
```

## Queue Management

Efficient queue management ensures optimal resource utilization and processing performance across different workload types.

### Queue Naming Conventions

Standardized queue naming for clear operational management:

```ruby
# Ragdoll queue naming conventions
module Ragdoll
  module Core
    module Jobs
      # Primary processing queues
      class ExtractText < ActiveJob::Base
        queue_as 'ragdoll_extraction'
      end
      
      class GenerateEmbeddings < ActiveJob::Base
        queue_as 'ragdoll_embeddings'
      end
      
      class GenerateSummary < ActiveJob::Base
        queue_as 'ragdoll_ai_processing'
      end
      
      class ExtractKeywords < ActiveJob::Base
        queue_as 'ragdoll_ai_processing'
      end
    end
  end
end

# Environment-specific queue names
class BaseJob < ActiveJob::Base
  queue_as ->(job) {
    env_prefix = Rails.env.production? ? 'prod' : Rails.env
    "#{env_prefix}_#{job.class.name.demodulize.underscore}"
  }
end

# Queue naming by workload characteristics
queue_names = {
  cpu_intensive: 'ragdoll_cpu_heavy',     # AI processing, text analysis
  io_intensive: 'ragdoll_io_heavy',       # File processing, network calls
  memory_intensive: 'ragdoll_memory_heavy', # Large document processing
  quick_tasks: 'ragdoll_quick',           # Fast operations
  batch_processing: 'ragdoll_batch'       # Bulk operations
}
```

### Worker Configuration

Optimized worker configuration for different processing types:

```ruby
# Sidekiq worker configuration
# config/sidekiq.yml
:concurrency: 20
:timeout: 3600
:verbose: false

:queues:
  - [ragdoll_quick, 10]        # Fast jobs, high concurrency
  - [ragdoll_extraction, 5]    # File processing
  - [ragdoll_embeddings, 3]    # AI embeddings (resource intensive)
  - [ragdoll_ai_processing, 2] # LLM operations (rate limited)
  - [ragdoll_batch, 1]         # Batch operations (low priority)

# Environment-specific configurations
production:
  :concurrency: 50
  :timeout: 7200
  :queues:
    - [ragdoll_quick, 20]
    - [ragdoll_extraction, 15]
    - [ragdoll_embeddings, 10]
    - [ragdoll_ai_processing, 5]

development:
  :concurrency: 5
  :timeout: 300
  :queues:
    - [ragdoll_quick, 3]
    - [ragdoll_extraction, 2]
    - [ragdoll_embeddings, 1]
```

**Per-Worker Resource Limits:**
```ruby
# Worker-specific configuration
class AIProcessingWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'ragdoll_ai_processing',
                  concurrency: 2,        # Limit concurrent AI calls
                  memory_limit: '2GB',   # Memory constraint
                  timeout: 1800         # 30 minute timeout
end

# Resource-aware job assignment
class ResourceManager
  def self.optimal_queue_for_job(job_type, content_size)
    case job_type
    when :embedding_generation
      content_size > 10_000 ? 'ragdoll_embeddings_large' : 'ragdoll_embeddings'
    when :text_extraction
      content_size > 50_000 ? 'ragdoll_extraction_large' : 'ragdoll_extraction'
    else
      'ragdoll_default'
    end
  end
end
```

### Scaling Strategies

Horizontal and vertical scaling approaches for different workloads:

```ruby
# Auto-scaling configuration
class AutoScaler
  def self.scale_workers_based_on_queue_depth
    queue_depths = Sidekiq::Queue.all.map { |q| [q.name, q.size] }.to_h
    
    scaling_rules = {
      'ragdoll_embeddings' => { threshold: 50, max_workers: 10 },
      'ragdoll_extraction' => { threshold: 100, max_workers: 20 },
      'ragdoll_ai_processing' => { threshold: 20, max_workers: 5 }
    }
    
    scaling_rules.each do |queue_name, config|
      current_depth = queue_depths[queue_name] || 0
      
      if current_depth > config[:threshold]
        scale_up_workers(queue_name, config[:max_workers])
      elsif current_depth < config[:threshold] / 4
        scale_down_workers(queue_name)
      end
    end
  end
  
  private
  
  def self.scale_up_workers(queue_name, max_workers)
    # Kubernetes/Docker scaling logic
    current_workers = get_current_worker_count(queue_name)
    return if current_workers >= max_workers
    
    target_workers = [current_workers + 2, max_workers].min
    execute_scaling_command(queue_name, target_workers)
  end
end

# Kubernetes horizontal pod autoscaler configuration
# k8s/ragdoll-workers-hpa.yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ragdoll-workers
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ragdoll-sidekiq-workers
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: sidekiq_queue_depth
      target:
        type: AverageValue
        averageValue: "10"
```

### Load Balancing

Intelligent load distribution across workers and queues:

```ruby
# Queue load balancing
class LoadBalancer
  def self.distribute_job(job_class, *args)
    # Find least loaded queue for job type
    available_queues = queues_for_job_type(job_class)
    optimal_queue = find_least_loaded_queue(available_queues)
    
    job_class.set(queue: optimal_queue).perform_later(*args)
  end
  
  def self.queues_for_job_type(job_class)
    case job_class.name
    when /Extract/
      %w[ragdoll_extraction_1 ragdoll_extraction_2 ragdoll_extraction_3]
    when /Generate.*Embedding/
      %w[ragdoll_embeddings_1 ragdoll_embeddings_2]
    when /AI|Summary|Keywords/
      %w[ragdoll_ai_1 ragdoll_ai_2]
    else
      %w[ragdoll_default]
    end
  end
  
  def self.find_least_loaded_queue(queue_names)
    queue_loads = queue_names.map do |name|
      queue = Sidekiq::Queue.new(name)
      [name, queue.size + active_jobs_count(name)]
    end
    
    queue_loads.min_by { |_, load| load }.first
  end
  
  private
  
  def self.active_jobs_count(queue_name)
    Sidekiq::Workers.new.count { |_, _, work| work['queue'] == queue_name }
  end
end

# Geographic load balancing for distributed deployments
class GeographicLoadBalancer
  REGIONS = {
    'us-east-1' => %w[ragdoll_us_east_1 ragdoll_us_east_2],
    'us-west-2' => %w[ragdoll_us_west_1 ragdoll_us_west_2],
    'eu-west-1' => %w[ragdoll_eu_west_1 ragdoll_eu_west_2]
  }
  
  def self.route_job_by_region(job_class, region, *args)
    regional_queues = REGIONS[region] || REGIONS['us-east-1']
    optimal_queue = LoadBalancer.find_least_loaded_queue(regional_queues)
    
    job_class.set(queue: optimal_queue).perform_later(*args)
  end
end

# Usage examples
# Route to least loaded extraction queue
LoadBalancer.distribute_job(Ragdoll::Core::Jobs::ExtractText, document.id)

# Route by geographic region
GeographicLoadBalancer.route_job_by_region(
  Ragdoll::Core::Jobs::GenerateEmbeddings,
  'us-west-2',
  document.id
)
```

## Error Handling

Robust error handling ensures reliable document processing and provides comprehensive failure recovery mechanisms.

### Retry Strategies

Multi-layered retry logic with intelligent backoff and error classification:

```ruby
module Ragdoll
  module Core
    module Jobs
      class BaseJob < ActiveJob::Base
        # Comprehensive retry configuration
        retry_on StandardError, wait: :exponentially_longer, attempts: 5 do |job, exception|
          # Log retry attempt
          Rails.logger.warn "Retrying #{job.class.name} (attempt #{job.executions}): #{exception.message}" if defined?(Rails)
          
          # Update document status if applicable
          if job.respond_to?(:document_id) && job.arguments.first
            document = Models::Document.find_by(id: job.arguments.first)
            document&.update(status: 'processing') # Keep as processing during retries
          end
        end
        
        # Specific retry policies for different error types
        retry_on Net::TimeoutError, wait: 30.seconds, attempts: 3
        retry_on ActiveRecord::ConnectionNotEstablished, wait: 5.seconds, attempts: 10
        retry_on Errno::ECONNREFUSED, wait: 1.minute, attempts: 5
        
        # AI API specific retries
        retry_on OpenAI::RateLimitError, wait: 2.minutes, attempts: 3
        retry_on OpenAI::APIConnectionError, wait: :exponentially_longer, attempts: 5
        
        # Immediate failures - don't retry
        discard_on ActiveRecord::RecordNotFound
        discard_on ArgumentError
        discard_on JSON::ParserError
        
        # Custom retry logic for specific scenarios
        retry_on CustomProcessingError do |job, exception|
          case exception.error_code
          when 'file_corrupted'
            job.discard_job # Don't retry corrupted files
          when 'temporary_unavailable'
            job.retry_job(wait: 5.minutes)
          when 'rate_limited'
            job.retry_job(wait: exception.retry_after || 60.seconds)
          else
            job.retry_job(wait: :exponentially_longer)
          end
        end
        
        # Final failure handling
        discard_on StandardError do |job, exception|
          handle_final_failure(job, exception)
        end
        
        private
        
        def self.handle_final_failure(job, exception)
          # Mark document as failed if applicable
          if job.respond_to?(:document_id) && job.arguments.first
            document = Models::Document.find_by(id: job.arguments.first)
            if document
              document.update!(
                status: 'error',
                metadata: document.metadata.merge(
                  'error' => {
                    'message' => exception.message,
                    'backtrace' => exception.backtrace&.first(5),
                    'job_class' => job.class.name,
                    'failed_at' => Time.current.iso8601,
                    'attempts' => job.executions
                  }
                )
              )
            end
          end
          
          # Send failure notification
          ErrorNotifier.notify_job_failure(job, exception)
        end
      end
    end
  end
end

# Job-specific retry strategies
class ExtractText < BaseJob
  # File processing may have different retry needs
  retry_on Errno::ENOENT, attempts: 1 # File not found - don't retry
  retry_on PDF::Reader::MalformedPDFError, attempts: 2, wait: 10.seconds
  retry_on Docx::DocumentCorrupted, attempts: 1 # Don't retry corrupted docs
end

class GenerateEmbeddings < BaseJob
  # AI operations need careful retry handling
  retry_on OpenAI::APIError do |job, exception|
    if exception.response&.dig('error', 'code') == 'context_length_exceeded'
      # Try with smaller chunks
      job.arguments[1] = (job.arguments[1] || 1000) * 0.8 # Reduce chunk size
      job.retry_job(wait: 1.minute) if job.executions < 3
    else
      job.retry_job(wait: :exponentially_longer)
    end
  end
end
```

### Dead Letter Queues

Manage permanently failed jobs with comprehensive tracking:

```ruby
# Dead letter queue implementation
module Ragdoll
  module Core
    class DeadLetterQueue
      def self.store_failed_job(job, exception)
        failed_job_record = {
          id: SecureRandom.uuid,
          job_class: job.class.name,
          job_arguments: job.arguments,
          queue_name: job.queue_name,
          failed_at: Time.current,
          exception_class: exception.class.name,
          exception_message: exception.message,
          exception_backtrace: exception.backtrace,
          job_executions: job.executions,
          enqueued_at: job.enqueued_at,
          created_at: Time.current
        }
        
        # Store in database table or external storage
        store_failed_job_record(failed_job_record)
        
        # Optional: Store in Redis for quick access
        Redis.current.lpush('ragdoll:dead_letter_queue', failed_job_record.to_json)
        Redis.current.expire('ragdoll:dead_letter_queue', 30.days)
      end
      
      def self.replay_failed_job(failed_job_id)
        failed_job = get_failed_job_record(failed_job_id)
        return false unless failed_job
        
        job_class = failed_job[:job_class].constantize
        job_class.perform_later(*failed_job[:job_arguments])
        
        # Mark as replayed
        mark_job_replayed(failed_job_id)
        true
      rescue => e
        Rails.logger.error "Failed to replay job #{failed_job_id}: #{e.message}" if defined?(Rails)
        false
      end
      
      def self.failed_jobs_summary
        # Get failed jobs statistics
        {
          total_failed: count_failed_jobs,
          by_job_class: failed_jobs_by_class,
          by_error_type: failed_jobs_by_error,
          recent_failures: recent_failed_jobs(24.hours),
          retry_candidates: jobs_eligible_for_retry
        }
      end
      
      private
      
      def self.store_failed_job_record(record)
        # Implementation depends on storage choice
        # Could be database table, file system, or external service
        Rails.logger.error "FAILED JOB: #{record.to_json}" if defined?(Rails)
      end
    end
  end
end

# Sidekiq dead job handling
class SidekiqDeadJobHandler
  def self.process_dead_jobs
    dead_set = Sidekiq::DeadSet.new
    
    dead_set.each do |job|
      if job['class'].start_with?('Ragdoll::Core::Jobs::')
        # Extract Ragdoll-specific failed jobs
        failed_job_data = {
          job_class: job['class'],
          arguments: job['args'],
          error_message: job['error_message'],
          failed_at: Time.at(job['failed_at']),
          retry_count: job['retry_count']
        }
        
        Ragdoll::Core::DeadLetterQueue.store_failed_job_data(failed_job_data)
      end
    end
  end
  
  def self.clear_old_dead_jobs(older_than: 30.days)
    dead_set = Sidekiq::DeadSet.new
    cutoff_time = older_than.ago
    
    dead_set.select { |job| Time.at(job['failed_at']) < cutoff_time }.each(&:delete)
  end
end
```

### Error Notification

Comprehensive error notification system:

```ruby
module Ragdoll
  module Core
    class ErrorNotifier
      def self.notify_job_failure(job, exception)
        notification_data = {
          job_class: job.class.name,
          job_id: job.job_id,
          arguments: sanitize_arguments(job.arguments),
          exception: {
            class: exception.class.name,
            message: exception.message,
            backtrace: exception.backtrace&.first(10)
          },
          context: {
            queue: job.queue_name,
            executions: job.executions,
            enqueued_at: job.enqueued_at,
            failed_at: Time.current
          },
          environment: Rails.env,
          severity: determine_severity(job, exception)
        }
        
        # Send to multiple notification channels
        send_to_configured_channels(notification_data)
      end
      
      def self.notify_queue_backlog(queue_name, depth)
        return unless depth > backlog_threshold(queue_name)
        
        notification = {
          type: 'queue_backlog',
          queue: queue_name,
          depth: depth,
          threshold: backlog_threshold(queue_name),
          severity: depth > (backlog_threshold(queue_name) * 2) ? 'critical' : 'warning'
        }
        
        send_to_configured_channels(notification)
      end
      
      private
      
      def self.send_to_configured_channels(data)
        channels = Ragdoll.config&.notification_channels || [:log]
        
        channels.each do |channel|
          case channel
          when :log
            log_error(data)
          when :email
            send_email_notification(data)
          when :slack
            send_slack_notification(data)
          when :webhook
            send_webhook_notification(data)
          when :sentry
            send_sentry_notification(data)
          end
        end
      end
      
      def self.log_error(data)
        logger = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
        logger.error "[RAGDOLL JOB FAILURE] #{data[:job_class]}: #{data[:exception][:message]}"
      end
      
      def self.send_slack_notification(data)
        return unless ENV['SLACK_WEBHOOK_URL']
        
        payload = {
          text: "Ragdoll Job Failure: #{data[:job_class]}",
          attachments: [{
            color: data[:severity] == 'critical' ? 'danger' : 'warning',
            fields: [
              { title: 'Job Class', value: data[:job_class], short: true },
              { title: 'Queue', value: data[:context][:queue], short: true },
              { title: 'Error', value: data[:exception][:message], short: false },
              { title: 'Attempts', value: data[:context][:executions], short: true }
            ],
            timestamp: Time.current.to_i
          }]
        }
        
        # Send webhook (implementation depends on HTTP library)
        send_webhook(ENV['SLACK_WEBHOOK_URL'], payload)
      end
      
      def self.determine_severity(job, exception)
        case exception
        when ActiveRecord::RecordNotFound, ArgumentError
          'low'      # Expected failures
        when Net::TimeoutError, Errno::ECONNREFUSED
          'medium'   # Infrastructure issues
        when OpenAI::RateLimitError
          'medium'   # External service limits
        else
          job.executions >= 3 ? 'high' : 'medium'
        end
      end
    end
  end
end
```

### Debugging Approaches

Comprehensive debugging tools and techniques:

```ruby
# Job debugging utilities
module Ragdoll
  module Core
    module JobDebugging
      def self.debug_failed_document(document_id)
        document = Models::Document.find(document_id)
        
        debug_info = {
          document: {
            id: document.id,
            status: document.status,
            document_type: document.document_type,
            location: document.location,
            content_present: document.content.present?,
            content_length: document.content&.length,
            metadata: document.metadata
          },
          processing_history: get_processing_history(document_id),
          related_jobs: get_related_jobs(document_id),
          system_state: get_system_state_at_failure(document_id)
        }
        
        puts JSON.pretty_generate(debug_info)
        debug_info
      end
      
      def self.trace_job_execution(job_class, *args)
        # Enable detailed logging for specific job execution
        original_log_level = Rails.logger.level if defined?(Rails)
        
        begin
          Rails.logger.level = Logger::DEBUG if defined?(Rails)
          
          # Add execution tracing
          job_instance = job_class.new(*args)
          
          puts "=== Starting #{job_class.name} execution ==="
          puts "Arguments: #{args.inspect}"
          puts "Queue: #{job_instance.queue_name}"
          
          start_time = Time.current
          result = job_instance.perform_now
          end_time = Time.current
          
          puts "=== Completed in #{((end_time - start_time) * 1000).round(2)}ms ==="
          puts "Result: #{result.inspect}"
          
          result
        rescue => e
          puts "=== FAILED with #{e.class.name}: #{e.message} ==="
          puts "Backtrace:"
          puts e.backtrace.first(10).map { |line| "  #{line}" }
          raise e
        ensure
          Rails.logger.level = original_log_level if defined?(Rails) && original_log_level
        end
      end
      
      def self.analyze_queue_performance(queue_name, period: 24.hours)
        # Analyze job performance in specific queue
        stats = {
          queue_name: queue_name,
          period: period,
          current_depth: Sidekiq::Queue.new(queue_name).size,
          processed_jobs: get_processed_jobs_count(queue_name, period),
          failed_jobs: get_failed_jobs_count(queue_name, period),
          avg_processing_time: calculate_avg_processing_time(queue_name, period),
          slowest_jobs: get_slowest_jobs(queue_name, period, limit: 5)
        }
        
        puts "=== Queue Performance Analysis: #{queue_name} ==="
        puts JSON.pretty_generate(stats)
        stats
      end
      
      private
      
      def self.get_processing_history(document_id)
        # Get timeline of document processing attempts
        # This would typically come from application logs or database
        [
          # Mock data structure
          {
            timestamp: 1.hour.ago,
            event: 'ExtractText queued',
            details: { queue: 'ragdoll_extraction' }
          },
          {
            timestamp: 55.minutes.ago,
            event: 'ExtractText started',
            details: { worker_id: 'worker-1' }
          },
          {
            timestamp: 50.minutes.ago,
            event: 'ExtractText failed',
            details: { error: 'PDF parsing error', attempt: 1 }
          }
        ]
      end
    end
  end
end

# Usage examples
# Debug a specific failed document
Ragdoll::Core::JobDebugging.debug_failed_document(123)

# Trace a job execution with detailed logging
Ragdoll::Core::JobDebugging.trace_job_execution(
  Ragdoll::Core::Jobs::ExtractText,
  document.id
)

# Analyze queue performance
Ragdoll::Core::JobDebugging.analyze_queue_performance(
  'ragdoll_embeddings',
  period: 7.days
)
```

## Monitoring

Comprehensive monitoring and observability for job performance, queue health, and system reliability.

### Job Status Tracking

Real-time tracking of job execution status through document lifecycle:

```ruby
module Ragdoll
  module Core
    class JobStatusTracker
      def self.document_processing_status(document_id)
        document = Models::Document.find(document_id)
        
        {
          document_id: document.id,
          current_status: document.status,
          processing_stages: {
            text_extraction: check_text_extraction_status(document),
            embedding_generation: check_embedding_status(document),
            summary_generation: check_summary_status(document),
            keyword_extraction: check_keyword_status(document)
          },
          queue_positions: get_queue_positions(document_id),
          estimated_completion: estimate_completion_time(document),
          processing_metrics: get_processing_metrics(document)
        }
      end
      
      def self.system_processing_overview
        {
          total_documents: Models::Document.count,
          status_distribution: Models::Document.group(:status).count,
          processing_pipeline: {
            pending_extraction: Models::Document.where(status: 'pending').count,
            currently_processing: Models::Document.where(status: 'processing').count,
            completed_today: Models::Document
              .where(status: 'processed')
              .where('updated_at > ?', Date.current)
              .count,
            failed_processing: Models::Document.where(status: 'error').count
          },
          queue_depths: get_all_queue_depths,
          active_workers: get_active_worker_count
        }
      end
      
      private
      
      def self.check_text_extraction_status(document)
        {
          completed: document.content.present?,
          content_length: document.content&.length || 0,
          extraction_method: determine_extraction_method(document)
        }
      end
      
      def self.check_embedding_status(document)
        embeddings_count = document.total_embedding_count
        {
          completed: embeddings_count > 0,
          embeddings_count: embeddings_count,
          by_content_type: document.embeddings_by_type
        }
      end
      
      def self.get_queue_positions(document_id)
        # Check position in various queues
        positions = {}
        
        %w[ragdoll_extraction ragdoll_embeddings ragdoll_ai_processing].each do |queue_name|
          queue = Sidekiq::Queue.new(queue_name)
          position = queue.find_job { |job| job.args.first == document_id }
          positions[queue_name] = position ? queue.to_a.index(position) + 1 : nil
        end
        
        positions
      end
    end
  end
end

# Real-time status updates using ActionCable (if in Rails app)
class JobStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "job_status_#{params[:document_id]}"
  end
  
  def self.broadcast_status_update(document_id, status_data)
    ActionCable.server.broadcast(
      "job_status_#{document_id}",
      status_data
    )
  end
end

# Update status from jobs
# In job classes:
after_perform do |job|
  if job.arguments.first # document_id
    status_data = JobStatusTracker.document_processing_status(job.arguments.first)
    JobStatusChannel.broadcast_status_update(job.arguments.first, status_data)
  end
end
```

### Performance Metrics

Detailed performance tracking and analysis:

```ruby
class JobPerformanceMetrics
  def self.collect_performance_data
    {
      timestamp: Time.current.iso8601,
      processing_times: calculate_processing_times,
      throughput_metrics: calculate_throughput,
      resource_utilization: measure_resource_usage,
      error_rates: calculate_error_rates,
      queue_performance: analyze_queue_performance
    }
  end
  
  def self.calculate_processing_times
    recent_docs = Models::Document
      .where('updated_at > ?', 24.hours.ago)
      .where(status: 'processed')
      .includes(:contents)
    
    processing_times = recent_docs.map do |doc|
      total_time = (doc.updated_at - doc.created_at).to_i
      {
        document_id: doc.id,
        document_type: doc.document_type,
        content_size: doc.content&.length || 0,
        processing_time_seconds: total_time,
        embedding_count: doc.total_embedding_count
      }
    end
    
    {
      individual_times: processing_times,
      averages: {
        overall: processing_times.map { |t| t[:processing_time_seconds] }.sum / processing_times.length,
        by_document_type: processing_times.group_by { |t| t[:document_type] }
                                         .transform_values { |times| 
                                           times.map { |t| t[:processing_time_seconds] }.sum / times.length 
                                         },
        by_content_size: calculate_time_by_content_size(processing_times)
      }
    }
  end
  
  def self.calculate_throughput
    time_periods = {
      last_hour: 1.hour.ago,
      last_24_hours: 24.hours.ago,
      last_week: 1.week.ago
    }
    
    throughput_data = {}
    
    time_periods.each do |period, start_time|
      processed_count = Models::Document
        .where('updated_at > ?', start_time)
        .where(status: 'processed')
        .count
      
      time_span_hours = (Time.current - start_time) / 1.hour
      
      throughput_data[period] = {
        documents_processed: processed_count,
        documents_per_hour: processed_count / time_span_hours,
        embeddings_generated: calculate_embeddings_in_period(start_time),
        summaries_created: Models::Document
          .where('updated_at > ?', start_time)
          .where.not(summary: [nil, ''])
          .count
      }
    end
    
    throughput_data
  end
  
  def self.measure_resource_usage
    {
      memory: {
        current_mb: `ps -o rss= -p #{Process.pid}`.to_i / 1024,
        gc_stats: GC.stat
      },
      database: {
        active_connections: ActiveRecord::Base.connection_pool.stat[:checked_out],
        pool_size: ActiveRecord::Base.connection_pool.stat[:size],
        connection_usage_percent: (
          ActiveRecord::Base.connection_pool.stat[:checked_out].to_f / 
          ActiveRecord::Base.connection_pool.stat[:size] * 100
        ).round(2)
      },
      redis: redis_memory_usage,
      sidekiq: {
        busy_workers: Sidekiq::Workers.new.size,
        total_processed: Sidekiq::Stats.new.processed,
        total_failed: Sidekiq::Stats.new.failed
      }
    }
  end
  
  def self.calculate_error_rates
    time_periods = [1.hour.ago, 24.hours.ago, 1.week.ago]
    
    error_rates = {}
    
    time_periods.each do |start_time|
      period_name = case start_time
                    when 1.hour.ago then :last_hour
                    when 24.hours.ago then :last_24_hours
                    else :last_week
                    end
      
      total_attempts = Models::Document.where('created_at > ?', start_time).count
      failed_attempts = Models::Document
        .where('created_at > ?', start_time)
        .where(status: 'error')
        .count
      
      error_rates[period_name] = {
        total_attempts: total_attempts,
        failed_attempts: failed_attempts,
        error_rate_percent: total_attempts > 0 ? (failed_attempts.to_f / total_attempts * 100).round(2) : 0,
        error_types: get_error_types_in_period(start_time)
      }
    end
    
    error_rates
  end
  
  private
  
  def self.redis_memory_usage
    return {} unless defined?(Redis)
    
    redis_info = Redis.current.info
    {
      used_memory_mb: redis_info['used_memory'].to_i / (1024 * 1024),
      connected_clients: redis_info['connected_clients'].to_i,
      total_commands_processed: redis_info['total_commands_processed'].to_i
    }
  rescue
    { error: 'Redis connection unavailable' }
  end
end

# Automated performance reporting
class PerformanceReportJob < ActiveJob::Base
  queue_as :default
  
  def perform
    metrics = JobPerformanceMetrics.collect_performance_data
    
    # Store metrics for historical analysis
    store_performance_metrics(metrics)
    
    # Send alerts if performance degrades
    check_performance_alerts(metrics)
    
    # Generate daily/weekly reports
    generate_performance_report(metrics) if should_generate_report?
  end
  
  private
  
  def check_performance_alerts(metrics)
    alerts = []
    
    # Check processing time alerts
    avg_processing_time = metrics[:processing_times][:averages][:overall]
    if avg_processing_time > 300 # 5 minutes
      alerts << {
        type: :slow_processing,
        severity: avg_processing_time > 600 ? :critical : :warning,
        message: "Average processing time: #{avg_processing_time}s"
      }
    end
    
    # Check error rate alerts
    error_rate = metrics[:error_rates][:last_hour][:error_rate_percent]
    if error_rate > 5
      alerts << {
        type: :high_error_rate,
        severity: error_rate > 15 ? :critical : :warning,
        message: "Error rate in last hour: #{error_rate}%"
      }
    end
    
    # Send alerts if any found
    alerts.each { |alert| send_performance_alert(alert) }
  end
end
```

### Queue Health Monitoring

Comprehensive queue monitoring and health checks:

```ruby
class QueueHealthMonitor
  HEALTH_THRESHOLDS = {
    queue_depth: {
      warning: 50,
      critical: 200
    },
    processing_rate: {
      warning: 10,  # jobs per minute
      critical: 5
    },
    worker_utilization: {
      warning: 80,  # percentage
      critical: 95
    }
  }
  
  def self.check_all_queues
    queue_names = %w[
      ragdoll_extraction
      ragdoll_embeddings
      ragdoll_ai_processing
      ragdoll_quick
    ]
    
    health_report = {
      timestamp: Time.current.iso8601,
      overall_health: 'healthy',
      queues: {},
      alerts: []
    }
    
    queue_names.each do |queue_name|
      queue_health = analyze_queue_health(queue_name)
      health_report[:queues][queue_name] = queue_health
      
      # Collect alerts
      if queue_health[:alerts].any?
        health_report[:alerts].concat(queue_health[:alerts])
      end
      
      # Update overall health
      if queue_health[:status] == 'critical'
        health_report[:overall_health] = 'critical'
      elsif queue_health[:status] == 'warning' && health_report[:overall_health] == 'healthy'
        health_report[:overall_health] = 'warning'
      end
    end
    
    health_report
  end
  
  def self.analyze_queue_health(queue_name)
    queue = Sidekiq::Queue.new(queue_name)
    
    health_data = {
      name: queue_name,
      depth: queue.size,
      latency: queue.latency,
      processing_rate: calculate_processing_rate(queue_name),
      worker_utilization: calculate_worker_utilization(queue_name),
      oldest_job_age: calculate_oldest_job_age(queue),
      status: 'healthy',
      alerts: []
    }
    
    # Check depth threshold
    if health_data[:depth] >= HEALTH_THRESHOLDS[:queue_depth][:critical]
      health_data[:status] = 'critical'
      health_data[:alerts] << {
        type: :queue_depth,
        severity: :critical,
        message: "Queue depth #{health_data[:depth]} exceeds critical threshold"
      }
    elsif health_data[:depth] >= HEALTH_THRESHOLDS[:queue_depth][:warning]
      health_data[:status] = 'warning'
      health_data[:alerts] << {
        type: :queue_depth,
        severity: :warning,
        message: "Queue depth #{health_data[:depth]} exceeds warning threshold"
      }
    end
    
    # Check processing rate
    if health_data[:processing_rate] <= HEALTH_THRESHOLDS[:processing_rate][:critical]
      health_data[:status] = 'critical'
      health_data[:alerts] << {
        type: :slow_processing,
        severity: :critical,
        message: "Processing rate #{health_data[:processing_rate]} jobs/min is critically low"
      }
    elsif health_data[:processing_rate] <= HEALTH_THRESHOLDS[:processing_rate][:warning]
      health_data[:status] = 'warning' if health_data[:status] == 'healthy'
      health_data[:alerts] << {
        type: :slow_processing,
        severity: :warning,
        message: "Processing rate #{health_data[:processing_rate]} jobs/min is below normal"
      }
    end
    
    health_data
  end
  
  def self.queue_trending_analysis(period: 24.hours)
    # Analyze queue depth trends over time
    queue_names = %w[ragdoll_extraction ragdoll_embeddings ragdoll_ai_processing]
    
    trending_data = {}
    
    queue_names.each do |queue_name|
      # This would typically come from stored metrics
      # For now, simulate trend analysis
      trending_data[queue_name] = {
        current_depth: Sidekiq::Queue.new(queue_name).size,
        trend_direction: calculate_trend_direction(queue_name, period),
        peak_depth_24h: get_peak_depth(queue_name, period),
        average_depth_24h: get_average_depth(queue_name, period),
        prediction: predict_queue_behavior(queue_name)
      }
    end
    
    trending_data
  end
  
  private
  
  def self.calculate_processing_rate(queue_name)
    # Calculate jobs processed per minute for this queue
    # This would come from Sidekiq stats or custom metrics
    processed_count = get_processed_jobs_last_hour(queue_name)
    processed_count / 60.0 # per minute
  end
  
  def self.calculate_worker_utilization(queue_name)
    # Calculate percentage of workers busy with this queue
    total_workers = Sidekiq::ProcessSet.new.sum(&:busy)
    queue_workers = count_workers_processing_queue(queue_name)
    
    return 0 if total_workers == 0
    (queue_workers.to_f / total_workers * 100).round(2)
  end
end

# Health monitoring job
class QueueHealthCheckJob < ActiveJob::Base
  queue_as :default
  
  def perform
    health_report = QueueHealthMonitor.check_all_queues
    
    # Store health metrics
    store_health_report(health_report)
    
    # Send alerts for critical issues
    critical_alerts = health_report[:alerts].select { |a| a[:severity] == :critical }
    critical_alerts.each { |alert| send_critical_alert(alert) }
    
    # Log health status
    Rails.logger.info "Queue Health: #{health_report[:overall_health]}" if defined?(Rails)
    
    health_report
  end
end
```

### Alerting Strategies

Intelligent alerting with escalation and noise reduction:

```ruby
class JobAlertingSystem
  ALERT_RULES = {
    queue_backlog: {
      thresholds: { warning: 50, critical: 200 },
      escalation_time: 15.minutes,
      channels: [:log, :slack, :email]
    },
    high_error_rate: {
      thresholds: { warning: 5, critical: 15 }, # percentage
      escalation_time: 5.minutes,
      channels: [:log, :slack, :webhook]
    },
    slow_processing: {
      thresholds: { warning: 300, critical: 600 }, # seconds
      escalation_time: 30.minutes,
      channels: [:log, :email]
    },
    worker_shortage: {
      thresholds: { warning: 90, critical: 100 }, # utilization percentage
      escalation_time: 10.minutes,
      channels: [:log, :slack, :pager]
    }
  }
  
  def self.evaluate_alerts
    current_metrics = collect_current_metrics
    active_alerts = []
    
    ALERT_RULES.each do |alert_type, config|
      alert_value = extract_metric_value(current_metrics, alert_type)
      
      severity = determine_severity(alert_value, config[:thresholds])
      
      if severity
        alert = create_alert(alert_type, severity, alert_value, config)
        active_alerts << alert
        
        # Check if this is a new alert or escalation
        if should_send_alert?(alert)
          send_alert(alert, config[:channels])
        end
      end
    end
    
    # Update alert history
    update_alert_history(active_alerts)
    
    active_alerts
  end
  
  def self.create_alert(alert_type, severity, current_value, config)
    {
      id: generate_alert_id(alert_type, severity),
      type: alert_type,
      severity: severity,
      current_value: current_value,
      threshold: config[:thresholds][severity],
      message: generate_alert_message(alert_type, severity, current_value),
      timestamp: Time.current,
      escalation_time: config[:escalation_time],
      channels: config[:channels]
    }
  end
  
  def self.should_send_alert?(alert)
    # Prevent alert spam by checking recent alert history
    recent_similar = get_recent_alerts(alert[:type], alert[:severity], 30.minutes)
    
    # Send if no recent similar alerts
    return true if recent_similar.empty?
    
    # Send if value has significantly worsened
    last_alert = recent_similar.last
    return true if alert[:current_value] > (last_alert[:current_value] * 1.5)
    
    # Send if escalation time has passed
    time_since_last = Time.current - last_alert[:timestamp]
    return true if time_since_last >= alert[:escalation_time]
    
    false
  end
  
  def self.generate_alert_message(alert_type, severity, current_value)
    case alert_type
    when :queue_backlog
      "Queue backlog #{severity}: #{current_value} jobs waiting"
    when :high_error_rate
      "High error rate #{severity}: #{current_value}% of jobs failing"
    when :slow_processing
      "Slow processing #{severity}: Average #{current_value}s per job"
    when :worker_shortage
      "Worker shortage #{severity}: #{current_value}% utilization"
    else
      "System alert #{severity}: #{alert_type} = #{current_value}"
    end
  end
  
  def self.send_alert(alert, channels)
    channels.each do |channel|
      case channel
      when :log
        log_alert(alert)
      when :slack
        send_slack_alert(alert)
      when :email
        send_email_alert(alert)
      when :webhook
        send_webhook_alert(alert)
      when :pager
        send_pager_alert(alert) if alert[:severity] == :critical
      end
    end
  end
  
  private
  
  def self.collect_current_metrics
    {
      queue_depths: get_all_queue_depths,
      error_rates: calculate_current_error_rates,
      processing_times: get_recent_processing_times,
      worker_utilization: calculate_worker_utilization
    }
  end
end

# Scheduled alert evaluation
class AlertEvaluationJob < ActiveJob::Base
  queue_as :default
  
  def perform
    alerts = JobAlertingSystem.evaluate_alerts
    
    # Log alert summary
    if alerts.any?
      critical_count = alerts.count { |a| a[:severity] == :critical }
      warning_count = alerts.count { |a| a[:severity] == :warning }
      
      Rails.logger.info "Active alerts: #{critical_count} critical, #{warning_count} warnings" if defined?(Rails)
    end
    
    alerts
  end
end

# Schedule alert evaluation every 5 minutes
# In Rails initializer:
# AlertEvaluationJob.set(cron: '*/5 * * * *').perform_later
```

## Custom Jobs

Create custom background jobs that integrate seamlessly with Ragdoll's processing pipeline and follow established patterns.

### Job Class Patterns

Standardized patterns for creating custom jobs:

```ruby
module Ragdoll
  module Core
    module Jobs
      # Base class for all custom Ragdoll jobs
      class CustomBaseJob < ActiveJob::Base
        # Inherit standard retry and error handling
        include JobErrorHandling
        
        queue_as :custom_processing
        
        # Standard retry configuration
        retry_on StandardError, wait: :exponentially_longer, attempts: 3
        discard_on ActiveRecord::RecordNotFound
        
        private
        
        # Helper method for document status updates
        def update_document_status(document_id, status, metadata = {})
          document = Models::Document.find_by(id: document_id)
          return unless document
          
          update_data = { status: status }
          if metadata.any?
            update_data[:metadata] = document.metadata.merge(metadata)
          end
          
          document.update!(update_data)
        end
        
        # Helper for logging job progress
        def log_progress(message, document_id: nil)
          log_data = {
            job_class: self.class.name,
            message: message,
            job_id: job_id,
            timestamp: Time.current.iso8601
          }
          log_data[:document_id] = document_id if document_id
          
          Rails.logger.info log_data.to_json if defined?(Rails)
        end
      end
    end
  end
end

# Example custom job: Advanced content analysis
class AdvancedContentAnalysis < Ragdoll::Core::Jobs::CustomBaseJob
  def perform(document_id, analysis_options = {})
    log_progress("Starting advanced content analysis", document_id: document_id)
    
    document = Models::Document.find(document_id)
    return unless document.content.present?
    
    # Update status to show processing
    update_document_status(document_id, 'processing', {
      'analysis_stage' => 'advanced_analysis',
      'analysis_options' => analysis_options
    })
    
    analysis_results = {
      sentiment_analysis: perform_sentiment_analysis(document.content),
      topic_modeling: perform_topic_modeling(document.content),
      entity_extraction: extract_named_entities(document.content),
      readability_score: calculate_readability(document.content)
    }
    
    # Store analysis results in metadata
    update_document_status(document_id, 'processed', {
      'advanced_analysis' => analysis_results,
      'analysis_completed_at' => Time.current.iso8601
    })
    
    log_progress("Advanced content analysis completed", document_id: document_id)
    
    # Queue follow-up jobs if needed
    if analysis_results[:sentiment_analysis][:score] < -0.5
      ContentModerationJob.perform_later(document_id)
    end
    
    analysis_results
  end
  
  private
  
  def perform_sentiment_analysis(content)
    # Integration with sentiment analysis service
    # This could use various APIs or libraries
    {
      score: rand(-1.0..1.0), # Mock score
      label: %w[positive negative neutral].sample,
      confidence: rand(0.5..1.0)
    }
  end
  
  def perform_topic_modeling(content)
    # Topic modeling implementation
    {
      primary_topics: ['technology', 'business', 'science'],
      topic_distribution: { 'technology' => 0.6, 'business' => 0.3, 'science' => 0.1 }
    }
  end
end

# Example: Batch processing job
class BatchDocumentProcessor < Ragdoll::Core::Jobs::CustomBaseJob
  queue_as :batch_processing
  
  def perform(document_ids, processing_options = {})
    log_progress("Starting batch processing of #{document_ids.length} documents")
    
    results = {
      total_documents: document_ids.length,
      successful: 0,
      failed: 0,
      processing_times: [],
      errors: []
    }
    
    document_ids.each_with_index do |document_id, index|
      start_time = Time.current
      
      begin
        process_single_document(document_id, processing_options)
        results[:successful] += 1
        
        processing_time = Time.current - start_time
        results[:processing_times] << processing_time
        
        # Progress reporting every 10 documents
        if (index + 1) % 10 == 0
          log_progress("Processed #{index + 1}/#{document_ids.length} documents")
        end
        
      rescue => e
        results[:failed] += 1
        results[:errors] << {
          document_id: document_id,
          error: e.message,
          backtrace: e.backtrace&.first(3)
        }
        
        Rails.logger.error "Batch processing failed for document #{document_id}: #{e.message}" if defined?(Rails)
      end
    end
    
    log_progress("Batch processing completed: #{results[:successful]} successful, #{results[:failed]} failed")
    results
  end
  
  private
  
  def process_single_document(document_id, options)
    # Queue individual processing jobs
    ExtractText.perform_now(document_id) if options[:extract_text]
    GenerateEmbeddings.perform_now(document_id) if options[:generate_embeddings]
    GenerateSummary.perform_now(document_id) if options[:generate_summary]
  end
end
```

### Integration with Core Services

Seamless integration with Ragdoll services:

```ruby
# Custom job using core services
class CustomEmbeddingEnhancement < Ragdoll::Core::Jobs::CustomBaseJob
  def perform(document_id, enhancement_type)
    document = Models::Document.find(document_id)
    
    # Use core embedding service
    embedding_service = Ragdoll::Core::EmbeddingService.new
    
    case enhancement_type
    when 'multi_provider'
      enhance_with_multiple_providers(document, embedding_service)
    when 'contextual_chunks'
      create_contextual_embeddings(document, embedding_service)
    when 'semantic_clustering'
      cluster_document_embeddings(document, embedding_service)
    end
  end
  
  private
  
  def enhance_with_multiple_providers(document, embedding_service)
    # Generate embeddings using different providers for comparison
    providers = ['openai', 'huggingface', 'cohere']
    
    providers.each do |provider|
      begin
        # Configure service for specific provider
        embedding_service.configure_provider(provider)
        
        # Generate embeddings
        embeddings = embedding_service.generate_embeddings_for_content(
          document.content,
          model: get_model_for_provider(provider)
        )
        
        # Store with provider-specific metadata
        store_provider_embeddings(document.id, provider, embeddings)
        
      rescue => e
        Rails.logger.warn "Failed to generate embeddings with #{provider}: #{e.message}" if defined?(Rails)
      end
    end
  end
  
  def create_contextual_embeddings(document, embedding_service)
    # Use text chunker for intelligent content splitting
    text_chunker = Ragdoll::Core::TextChunker.new
    
    chunks = text_chunker.chunk_text(
      document.content,
      max_tokens: 512,
      overlap: 128,
      preserve_sentences: true
    )
    
    # Generate embeddings with surrounding context
    chunks.each_with_index do |chunk, index|
      # Add context from adjacent chunks
      contextual_content = build_contextual_content(chunks, index)
      
      embedding = embedding_service.generate_embedding(
        contextual_content,
        metadata: {
          chunk_index: index,
          has_context: true,
          context_size: contextual_content.length - chunk.length
        }
      )
      
      # Store contextual embedding
      store_contextual_embedding(document.id, chunk, embedding, index)
    end
  end
end

# Custom job using search engine
class DocumentSimilarityAnalysis < Ragdoll::Core::Jobs::CustomBaseJob
  def perform(document_id, similarity_threshold = 0.8)
    document = Models::Document.find(document_id)
    
    # Use core search engine
    embedding_service = Ragdoll::Core::EmbeddingService.new
    search_engine = Ragdoll::Core::SearchEngine.new(embedding_service)
    
    # Find similar documents
    similar_documents = search_engine.search_documents(
      document.content[0..1000], # Use first 1000 chars as query
      limit: 20,
      threshold: similarity_threshold,
      filters: {
        document_type: document.document_type
      }
    )
    
    # Analyze similarity patterns
    similarity_analysis = {
      total_similar: similar_documents.length,
      avg_similarity: calculate_average_similarity(similar_documents),
      similarity_clusters: group_by_similarity_ranges(similar_documents),
      related_keywords: extract_common_keywords(similar_documents)
    }
    
    # Update document metadata with similarity analysis
    update_document_status(document_id, document.status, {
      'similarity_analysis' => similarity_analysis,
      'similar_document_ids' => similar_documents.map { |d| d[:document_id] }
    })
    
    similarity_analysis
  end
end
```

### Testing Approaches

Comprehensive testing strategies for custom jobs:

```ruby
# Test helper for job testing
module JobTestHelpers
  def perform_job_now(job_class, *args)
    # Perform job synchronously for testing
    job_class.perform_now(*args)
  end
  
  def assert_job_enqueued(job_class, *args)
    assert_enqueued_with(job: job_class, args: args)
  end
  
  def create_test_document(attributes = {})
    default_attributes = {
      title: 'Test Document',
      location: '/tmp/test.txt',
      document_type: 'text',
      content: 'This is test content for processing.',
      status: 'pending',
      file_modified_at: Time.current
    }
    
    Ragdoll::Core::Models::Document.create!(default_attributes.merge(attributes))
  end
end

# Example test class
class AdvancedContentAnalysisTest < ActiveJob::TestCase
  include JobTestHelpers
  
  setup do
    @document = create_test_document(
      content: 'This is a comprehensive test document with substantial content for analysis.'
    )
  end
  
  test 'processes document successfully' do
    # Test synchronous execution
    result = perform_job_now(AdvancedContentAnalysis, @document.id)
    
    assert_not_nil result
    assert_includes result.keys, :sentiment_analysis
    assert_includes result.keys, :topic_modeling
    
    # Verify document status updated
    @document.reload
    assert_equal 'processed', @document.status
    assert_not_nil @document.metadata['advanced_analysis']
  end
  
  test 'handles missing document gracefully' do
    # Test with non-existent document ID
    assert_nothing_raised do
      perform_job_now(AdvancedContentAnalysis, 999999)
    end
  end
  
  test 'queues follow-up jobs for negative sentiment' do
    # Mock sentiment analysis to return negative score
    AdvancedContentAnalysis.any_instance.stubs(:perform_sentiment_analysis)
                           .returns({ score: -0.8, label: 'negative', confidence: 0.9 })
    
    assert_enqueued_with(job: ContentModerationJob) do
      perform_job_now(AdvancedContentAnalysis, @document.id)
    end
  end
  
  test 'handles service errors gracefully' do
    # Simulate service failure
    AdvancedContentAnalysis.any_instance.stubs(:perform_sentiment_analysis)
                           .raises(StandardError, 'Service unavailable')
    
    assert_raises(StandardError) do
      perform_job_now(AdvancedContentAnalysis, @document.id)
    end
    
    # Verify document marked as error
    @document.reload
    assert_equal 'error', @document.status
  end
  
  test 'processes with custom options' do
    options = { include_entities: true, deep_analysis: false }
    
    result = perform_job_now(AdvancedContentAnalysis, @document.id, options)
    
    @document.reload
    stored_options = @document.metadata['analysis_options']
    assert_equal options, stored_options
  end
end

# Integration testing with real services
class CustomJobIntegrationTest < ActiveJob::TestCase
  include JobTestHelpers
  
  setup do
    # Setup real service connections for integration testing
    @original_config = Ragdoll.config.dup
    
    Ragdoll::Core.configure do |config|
      config.ruby_llm_config[:openai][:api_key] = ENV['TEST_OPENAI_API_KEY']
      config.embedding_config[:text][:model] = 'text-embedding-3-small'
    end
  end
  
  teardown do
    # Restore original configuration
    Ragdoll.config = @original_config
  end
  
  test 'integration with real embedding service' do
    skip 'Requires API keys' unless ENV['TEST_OPENAI_API_KEY']
    
    document = create_test_document(
      content: 'Machine learning is transforming artificial intelligence applications.'
    )
    
    # This will make real API calls
    result = perform_job_now(CustomEmbeddingEnhancement, document.id, 'multi_provider')
    
    # Verify embeddings were created
    assert document.embeddings.count > 0
    
    # Verify embedding quality
    embedding = document.embeddings.first
    assert embedding.embedding_vector.present?
    assert_equal 1536, embedding.embedding_vector.length # OpenAI embedding size
  end
end
```

### Performance Considerations

Optimization strategies for custom jobs:

```ruby
# Performance-optimized job patterns
class PerformantCustomJob < Ragdoll::Core::Jobs::CustomBaseJob
  # Configuration for performance optimization
  queue_as :high_performance
  timeout 30.minutes
  
  def perform(document_ids, options = {})
    # Batch processing for efficiency
    documents = Models::Document.includes(:contents, :embeddings)
                               .where(id: document_ids)
    
    # Pre-load services to avoid repeated initialization
    services = initialize_services
    
    # Process in batches to manage memory
    documents.find_in_batches(batch_size: 50) do |batch|
      process_batch(batch, services, options)
      
      # Periodic garbage collection for long-running jobs
      GC.start if should_run_gc?
    end
  end
  
  private
  
  def initialize_services
    {
      embedding_service: Ragdoll::Core::EmbeddingService.new,
      text_chunker: Ragdoll::Core::TextChunker.new,
      search_engine: Ragdoll::Core::SearchEngine.new(embedding_service)
    }
  end
  
  def process_batch(documents, services, options)
    # Batch database operations
    updates = []
    
    documents.each do |document|
      result = process_single_document(document, services, options)
      
      if result
        updates << {
          id: document.id,
          metadata: document.metadata.merge(result)
        }
      end
    end
    
    # Bulk update to reduce database round trips
    bulk_update_documents(updates) if updates.any?
  end
  
  def bulk_update_documents(updates)
    # Use raw SQL for efficient bulk updates
    updates.each_slice(100) do |batch|
      update_sql = build_bulk_update_sql(batch)
      ActiveRecord::Base.connection.execute(update_sql)
    end
  end
  
  def should_run_gc?
    # Run GC every 100 processed documents or when memory usage is high
    @processed_count ||= 0
    @processed_count += 1
    
    (@processed_count % 100 == 0) || (get_memory_usage > 500) # 500MB threshold
  end
  
  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024 # MB
  end
end

# Memory-efficient streaming job
class StreamingProcessorJob < Ragdoll::Core::Jobs::CustomBaseJob
  def perform(large_document_id)
    document = Models::Document.find(large_document_id)
    
    # Process document in chunks to avoid loading entire content into memory
    process_in_chunks(document) do |chunk, chunk_index|
      # Process each chunk individually
      result = process_chunk(chunk, chunk_index)
      
      # Yield control to allow other jobs to run
      sleep(0.01) if chunk_index % 10 == 0
      
      result
    end
  end
  
  private
  
  def process_in_chunks(document)
    chunk_size = 1000 # characters
    content_length = document.content.length
    
    (0...content_length).step(chunk_size).each_with_index do |start, index|
      chunk = document.content[start, chunk_size]
      yield chunk, index
    end
  end
end

# Concurrent processing job (be careful with database connections)
class ConcurrentProcessingJob < Ragdoll::Core::Jobs::CustomBaseJob
  def perform(document_ids, max_concurrency: 5)
    require 'concurrent-ruby'
    
    # Use thread pool for concurrent processing
    pool = Concurrent::FixedThreadPool.new(max_concurrency)
    futures = []
    
    document_ids.each do |document_id|
      future = Concurrent::Future.execute(executor: pool) do
        # Each thread needs its own database connection
        ActiveRecord::Base.connection_pool.with_connection do
          process_single_document(document_id)
        end
      end
      
      futures << future
    end
    
    # Wait for all to complete
    results = futures.map(&:value)
    
    # Shutdown thread pool
    pool.shutdown
    pool.wait_for_termination(30) # 30 second timeout
    
    results
  rescue => e
    pool&.shutdown
    raise e
  end
end
```

---

## Summary

Ragdoll's background job system provides a robust, scalable foundation for asynchronous document processing. Built on ActiveJob, the system offers:

**Core Jobs:**
- `ExtractText`: File processing and content extraction
- `GenerateEmbeddings`: Vector embedding generation for all content types
- `ExtractKeywords`: AI-powered keyword extraction using LLMs
- `GenerateSummary`: Document summarization with configurable length

**Key Features:**
- **Flexible Configuration**: Support for all major queue adapters (Sidekiq, Resque, etc.)
- **Intelligent Retry Logic**: Exponential backoff with error-specific retry policies
- **Comprehensive Monitoring**: Job status tracking, performance metrics, and queue health
- **Error Handling**: Dead letter queues, failure notifications, and recovery tools
- **Custom Job Support**: Extensible framework for domain-specific processing

**Production Ready:**
- Horizontal scaling with load balancing
- Resource-aware job distribution 
- Automated alerting and escalation
- Performance optimization patterns
- Comprehensive testing approaches

The job system seamlessly integrates with Ragdoll's document processing pipeline, ensuring reliable and efficient handling of AI operations at scale.

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*