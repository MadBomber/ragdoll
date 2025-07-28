# Background Processing

Ragdoll implements a comprehensive background processing system using ActiveJob to handle computationally intensive operations without blocking the main application thread. This system is essential for production deployments where document processing, embedding generation, and content analysis must scale efficiently.

## Overview

**Schema Note**: Following recent schema optimization, the `embedding_model` field is now stored in content-specific tables (text_contents, image_contents, audio_contents) rather than in individual embeddings. This eliminates field duplication while maintaining full functionality through polymorphic relationships.

The background processing architecture consists of four specialized job types that handle different aspects of document intelligence:

- **GenerateEmbeddingsJob**: Vector embedding creation for search
- **ExtractTextJob**: Content extraction from various file formats  
- **ExtractKeywordsJob**: AI-powered keyword analysis
- **GenerateSummaryJob**: Document summarization

All jobs are designed to work together in a coordinated pipeline while maintaining individual reliability and error handling.

## Architecture

### Job Inheritance Structure

```ruby
# Base job class with shared functionality
class ApplicationJob < ActiveJob::Base
  include Ragdoll::Core::Jobs::SharedMethods
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError
  
  around_perform :with_job_logging
  around_perform :with_error_handling
end

# Specialized job implementations
class GenerateEmbeddingsJob < ApplicationJob
class ExtractTextJob < ApplicationJob  
class ExtractKeywordsJob < ApplicationJob
class GenerateSummaryJob < ApplicationJob
```

### Queue Configuration

```ruby
# Queue priorities and routing
class GenerateEmbeddingsJob < ApplicationJob
  queue_as :embeddings
  queue_with_priority 10  # High priority for search functionality
end

class ExtractTextJob < ApplicationJob
  queue_as :processing
  queue_with_priority 5   # Medium priority for content extraction
end

class GenerateSummaryJob < ApplicationJob
  queue_as :analysis
  queue_with_priority 1   # Lower priority for enhancement features
end
```

## Job Types

### 1. GenerateEmbeddingsJob

**Purpose**: Creates vector embeddings for semantic search functionality.

**Implementation**:
```ruby
class GenerateEmbeddingsJob < ApplicationJob
  def perform(embeddable_id, embeddable_type, options = {})
    embeddable = embeddable_type.constantize.find(embeddable_id)
    
    # Extract content based on type
    content = extract_content_for_embedding(embeddable)
    
    # Generate vector embedding
    vector = EmbeddingService.generate_embedding(
      content,
      model: options[:model] || Configuration.embedding_model
    )
    
    # Store embedding with metadata (embedding_model accessed via polymorphic relationship)
    embeddable.embeddings.create!(
      embedding_vector: vector,
      content: content,
      chunk_index: options[:chunk_index],
      metadata: build_embedding_metadata(embeddable, options)
    )
    
    # Update document processing status
    update_document_status(embeddable.document)
    
  rescue EmbeddingService::Error => e
    handle_embedding_error(e, embeddable)
    raise
  end
  
  private
  
  def extract_content_for_embedding(embeddable)
    case embeddable
    when TextContent
      embeddable.content
    when ImageContent
      embeddable.description || embeddable.alt_text
    when AudioContent
      embeddable.transcript
    else
      raise ArgumentError, "Unsupported embeddable type: #{embeddable.class}"
    end
  end
end
```

**Features**:
- ✅ Multi-modal content support (text, image descriptions, audio transcripts)
- ✅ Configurable embedding models per job
- ✅ Chunk-aware processing for large documents
- ✅ Automatic retry with exponential backoff
- ✅ Error handling with fallback strategies
- ✅ Progress tracking and status updates

**Usage**:
```ruby
# Queue embedding generation for text content
text_content = TextContent.find(123)
GenerateEmbeddingsJob.perform_later(text_content.id, 'TextContent')

# Batch processing with options
TextContent.where(embeddings_count: 0).find_each do |content|
  GenerateEmbeddingsJob.perform_later(
    content.id, 
    'TextContent',
    model: 'text-embedding-3-large',
    chunk_index: content.calculate_chunk_index
  )
end
```

### 2. ExtractTextJob

**Purpose**: Extracts text content from various file formats and prepares it for processing.

**Implementation**:
```ruby
class ExtractTextJob < ApplicationJob
  def perform(document_id, options = {})
    document = Document.find(document_id)
    
    # Extract text based on document type
    extracted_text = case document.document_type
    when 'pdf'
      extract_from_pdf(document)
    when 'docx'
      extract_from_docx(document)
    when 'audio'
      extract_from_audio(document)  # Speech-to-text
    when 'image'
      extract_from_image(document)  # OCR
    else
      extract_from_file(document)
    end
    
    # Create text content with chunking and embedding model
    text_content = document.text_contents.create!(
      content: extracted_text,
      language_detected: detect_language(extracted_text),
      embedding_model: options[:embedding_model] || Configuration.embedding_model,
      chunk_size: options[:chunk_size] || Configuration.chunk_size,
      chunk_overlap: options[:chunk_overlap] || Configuration.chunk_overlap,
      extraction_method: determine_extraction_method(document),
      extracted_at: Time.current
    )
    
    # Queue embedding generation
    GenerateEmbeddingsJob.perform_later(text_content.id, 'TextContent')
    
    # Queue additional analysis
    if Configuration.enable_keyword_extraction?
      ExtractKeywordsJob.perform_later(text_content.id)
    end
    
    if Configuration.enable_document_summarization?
      GenerateSummaryJob.perform_later(text_content.id)
    end
    
    # Update document status
    document.update!(status: 'processed') if document.processing_complete?
    
  rescue DocumentProcessor::ExtractionError => e
    handle_extraction_error(e, document)
    raise
  end
end
```

**Features**:
- ✅ Multi-format support (PDF, DOCX, audio, images)
- ✅ Language detection and encoding handling
- ✅ Intelligent text chunking
- ✅ OCR integration for image-based text
- ✅ Speech-to-text for audio content
- ✅ Automatic downstream job queuing
- ✅ Progress tracking and status management

### 3. ExtractKeywordsJob

**Purpose**: Performs AI-powered keyword and topic extraction from text content.

**Implementation**:
```ruby
class ExtractKeywordsJob < ApplicationJob
  def perform(text_content_id, options = {})
    text_content = TextContent.find(text_content_id)
    
    # Generate keywords using LLM
    keywords_result = TextGenerationService.extract_keywords(
      text_content.content,
      model: options[:model] || Configuration.keywords_model,
      max_keywords: options[:max_keywords] || 10,
      include_topics: options[:include_topics] || true
    )
    
    # Update document metadata
    document = text_content.document
    current_metadata = document.metadata || {}
    
    document.update!(
      metadata: current_metadata.merge(
        keywords: keywords_result[:keywords],
        topics: keywords_result[:topics],
        keyword_extraction: {
          model: keywords_result[:model],
          extracted_at: Time.current,
          confidence_scores: keywords_result[:confidence_scores]
        }
      )
    )
    
    # Trigger re-indexing for search
    if Configuration.enable_search_indexing?
      reindex_document_for_search(document)
    end
    
  rescue TextGenerationService::Error => e
    handle_keyword_extraction_error(e, text_content)
    raise
  end
end
```

**Features**:
- ✅ LLM-powered keyword extraction
- ✅ Topic modeling and categorization
- ✅ Confidence scoring for extracted terms
- ✅ Metadata integration with document search
- ✅ Configurable extraction parameters
- ✅ Search index updates

### 4. GenerateSummaryJob

**Purpose**: Creates AI-generated summaries of document content.

**Implementation**:
```ruby
class GenerateSummaryJob < ApplicationJob
  def perform(text_content_id, options = {})
    text_content = TextContent.find(text_content_id)
    
    # Generate summary using LLM
    summary_result = TextGenerationService.generate_summary(
      text_content.content,
      model: options[:model] || Configuration.summary_model,
      max_length: options[:max_length] || 200,
      style: options[:style] || 'academic'
    )
    
    # Update document metadata
    document = text_content.document
    current_metadata = document.metadata || {}
    
    document.update!(
      metadata: current_metadata.merge(
        summary: summary_result[:summary],
        summary_metadata: {
          model: summary_result[:model],
          length: summary_result[:summary].length,
          generated_at: Time.current,
          style: options[:style],
          reading_time_minutes: estimate_reading_time(summary_result[:summary])
        }
      )
    )
    
    # Create searchable summary embedding
    if Configuration.enable_summary_embeddings?
      GenerateEmbeddingsJob.perform_later(
        document.id,
        'Document', 
        content_type: 'summary',
        content: summary_result[:summary]
      )
    end
    
  rescue TextGenerationService::Error => e
    handle_summary_generation_error(e, text_content)
    raise
  end
end
```

**Features**:
- ✅ AI-powered summarization with style options
- ✅ Configurable summary length and format
- ✅ Reading time estimation
- ✅ Summary embedding generation for search
- ✅ Metadata enrichment
- ✅ Multiple summarization models

## Job Orchestration

### Processing Pipeline

```ruby
# Complete document processing pipeline
class DocumentProcessingOrchestrator
  def self.process_document(document)
    # 1. Extract text content
    ExtractTextJob.perform_later(document.id)
    
    # 2. Handle multi-modal content
    if document.has_images?
      document.image_contents.each do |image|
        GenerateImageDescriptionJob.perform_later(image.id)
      end
    end
    
    if document.has_audio?
      document.audio_contents.each do |audio|
        ExtractTextJob.perform_later(audio.id, content_type: 'audio')
      end
    end
    
    # 3. Generate embeddings (triggered by content creation)
    # 4. Extract keywords (triggered by text content creation)
    # 5. Generate summary (triggered by text content creation)
  end
end
```

### Batch Processing

```ruby
# Efficient batch processing for large document collections
class BatchProcessor
  def self.process_document_batch(document_ids)
    # Group by document type for optimized processing
    documents = Document.where(id: document_ids).includes(:text_contents)
    
    documents.group_by(&:document_type).each do |type, docs|
      case type
      when 'pdf'
        queue_pdf_batch(docs)
      when 'audio'
        queue_audio_batch(docs)
      when 'image'
        queue_image_batch(docs)
      end
    end
  end
  
  private
  
  def self.queue_pdf_batch(documents)
    # Batch PDF processing with staggered job scheduling
    documents.each_with_index do |doc, index|
      ExtractTextJob.set(wait: index * 2.seconds).perform_later(doc.id)
    end
  end
end
```

## Error Handling

### Retry Strategies

```ruby
class ApplicationJob < ActiveJob::Base
  # Exponential backoff for transient errors
  retry_on EmbeddingService::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on Net::TimeoutError, wait: 10.seconds, attempts: 3
  
  # Discard jobs that can't be retried
  discard_on ActiveRecord::RecordNotFound
  discard_on DocumentProcessor::UnsupportedFormatError
  
  # Custom retry logic for specific errors
  retry_on TextGenerationService::ModelUnavailableError do |job, error|
    # Try alternative model
    job.arguments[1] = { model: 'fallback-model' }
    job.retry_job(wait: 30.seconds)
  end
end
```

### Error Monitoring

```ruby
class ApplicationJob < ActiveJob::Base
  around_perform :with_error_tracking
  
  private
  
  def with_error_tracking
    start_time = Time.current
    yield
    track_job_success(Time.current - start_time)
  rescue => error
    track_job_failure(error, Time.current - start_time)
    
    # Update document status on critical failures
    if respond_to?(:document) && document.present?
      document.update!(
        status: 'error',
        error_message: error.message,
        error_details: {
          job_class: self.class.name,
          error_class: error.class.name,
          backtrace: error.backtrace.first(10),
          occurred_at: Time.current
        }
      )
    end
    
    raise
  end
end
```

## Monitoring and Analytics

### Job Status Tracking

```ruby
# Track job progress for user feedback
class JobStatusTracker
  def self.track_document_processing(document)
    {
      document_id: document.id,
      status: document.status,
      jobs_queued: count_queued_jobs(document),
      jobs_completed: count_completed_jobs(document),
      estimated_completion: estimate_completion_time(document),
      processing_steps: {
        text_extraction: job_status('ExtractTextJob', document),
        embedding_generation: job_status('GenerateEmbeddingsJob', document),
        keyword_extraction: job_status('ExtractKeywordsJob', document),
        summary_generation: job_status('GenerateSummaryJob', document)
      }
    }
  end
end

# Usage in API
GET /api/documents/123/status
{
  "document_id": 123,
  "status": "processing",
  "progress": 65,
  "jobs_queued": 2,
  "jobs_completed": 6,
  "estimated_completion": "2024-01-15T10:30:00Z"
}
```

### Performance Metrics

```ruby
# Background job performance monitoring
class JobMetrics
  def self.embedding_generation_stats
    {
      average_duration: calculate_average_duration('GenerateEmbeddingsJob'),
      success_rate: calculate_success_rate('GenerateEmbeddingsJob'),
      throughput_per_hour: calculate_throughput('GenerateEmbeddingsJob'),
      queue_depth: queue_depth('embeddings'),
      error_types: error_breakdown('GenerateEmbeddingsJob')
    }
  end
end
```

## Configuration

### Queue Adapter Setup

```ruby
# Production: Sidekiq configuration
# config/application.rb
config.active_job.queue_adapter = :sidekiq

# Queue priorities and routing
# config/schedule.yml
:queues:
  - [embeddings, 3]     # High priority, 3 workers
  - [processing, 2]     # Medium priority, 2 workers  
  - [analysis, 1]       # Low priority, 1 worker

# Development: Async configuration
# config/environments/development.rb
config.active_job.queue_adapter = :async

# Test: Inline configuration
# config/environments/test.rb
config.active_job.queue_adapter = :test
```

### Ragdoll Configuration

```ruby
Ragdoll::Core.configure do |config|
  # Background processing settings
  config.enable_background_processing = true
  config.job_queue_prefix = 'ragdoll'
  
  # Job-specific settings
  config.enable_keyword_extraction = true
  config.enable_document_summarization = true
  config.enable_summary_embeddings = true
  
  # Performance tuning
  config.batch_size = 100
  config.job_timeout = 300.seconds
  config.max_retry_attempts = 3
  
  # Model configuration for jobs
  config.embedding_model = 'text-embedding-3-small'
  config.summary_model = 'gpt-4'
  config.keywords_model = 'gpt-3.5-turbo'
end
```

## Production Deployment

### Scaling Strategy

```ruby
# Horizontal scaling with multiple job types
# docker-compose.yml
services:
  ragdoll-embeddings:
    image: ragdoll-app
    command: bundle exec sidekiq -q embeddings -c 3
    
  ragdoll-processing:
    image: ragdoll-app  
    command: bundle exec sidekiq -q processing -c 2
    
  ragdoll-analysis:
    image: ragdoll-app
    command: bundle exec sidekiq -q analysis -c 1
```

### Health Checks

```ruby
# Job queue health monitoring
class JobHealthCheck
  def self.status
    {
      queues: queue_status,
      workers: worker_status,
      failed_jobs: failed_job_count,
      processing_lag: calculate_processing_lag,
      alerts: generate_alerts
    }
  end
  
  def self.queue_status
    %w[embeddings processing analysis].map do |queue|
      {
        name: queue,
        size: Sidekiq::Queue.new(queue).size,
        latency: Sidekiq::Queue.new(queue).latency,
        busy: Sidekiq::Workers.new.select { |_, _, work| work['queue'] == queue }.size
      }
    end
  end
end
```

## Best Practices

### 1. Job Design
- Keep jobs focused on single responsibilities
- Use appropriate queue priorities
- Implement comprehensive error handling
- Design for idempotency when possible

### 2. Performance Optimization
- Batch similar operations when feasible
- Use appropriate retry strategies
- Monitor queue depths and processing times
- Scale workers based on job types and volumes

### 3. Error Management
- Implement dead letter queues for failed jobs
- Log comprehensive error context
- Provide user feedback on job status
- Plan for graceful degradation

### 4. Monitoring
- Track job performance metrics
- Monitor queue health and worker utilization
- Set up alerts for processing delays
- Analyze failure patterns for improvements

The background processing system in Ragdoll provides a robust foundation for scalable document intelligence operations, ensuring that computationally intensive tasks don't impact user experience while maintaining reliability and observability in production environments.