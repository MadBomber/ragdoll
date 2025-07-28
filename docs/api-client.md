# Client API Reference

The Ragdoll Client provides a high-level interface for all document intelligence operations. This comprehensive API handles document management, search operations, RAG enhancement, and system monitoring through a clean, intuitive interface.

## Overview

**Schema Note**: Following recent schema optimization, the Ragdoll database now uses a normalized schema where `embedding_model` information is stored in content-specific tables rather than duplicated in individual embeddings. This provides better data organization while maintaining all API functionality.

The Client class serves as the primary orchestration layer, providing:

- **Document Lifecycle Management**: Add, update, delete, and monitor documents
- **Multi-Modal Content Support**: Handle text, image, and audio content seamlessly
- **Advanced Search Operations**: Semantic, full-text, and hybrid search capabilities
- **RAG Enhancement**: Context retrieval and prompt enhancement for LLM applications
- **System Analytics**: Health monitoring, usage statistics, and performance metrics
- **Background Processing**: Asynchronous job management and status tracking

## Client Initialization

### Basic Initialization

```ruby
# Using default configuration
client = Ragdoll::Core::Client.new

# Using custom configuration
client = Ragdoll::Core::Client.new(
  llm_provider: :openai,
  embedding_model: 'text-embedding-3-large',
  database_config: {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    # ... other database settings
  }
)

# Using delegation (recommended)
Ragdoll::Core.configure do |config|
  # ... configuration
end

# Access via module delegation
result = Ragdoll::Core.add_document(path: 'document.pdf')
```

### Configuration Override

```ruby
# Temporarily override configuration for specific operations
client.with_configuration(embedding_model: 'text-embedding-3-large') do
  # Use larger embedding model for this operation
  result = client.add_document(path: 'important_document.pdf')
end
```

## Document Management

### Adding Documents

#### Single Document Addition

```ruby
# Add document from file path
result = client.add_document(path: 'research_paper.pdf')
# Returns:
# {
#   success: true,
#   document_id: "123",
#   message: "Document 'research_paper' added successfully with ID 123",
#   embeddings_queued: true,
#   processing_jobs: ["GenerateEmbeddingsJob", "ExtractKeywordsJob", "GenerateSummaryJob"]
# }

# Add document with options
result = client.add_document(
  path: 'document.pdf',
  title: 'Custom Document Title',
  metadata: {
    author: 'John Doe',
    category: 'research',
    tags: ['AI', 'machine learning']
  },
  chunk_size: 1500,
  chunk_overlap: 300,
  background_processing: true
)
```

#### Text Content Addition

```ruby
# Add raw text content
result = client.add_text(
  content: "This is the text content to be processed...",
  title: "Text Document",
  metadata: {
    source: 'user_input',
    language: 'en'
  }
)

# Add text with custom chunking
result = client.add_text(
  content: long_text_content,
  chunk_size: 800,
  chunk_overlap: 150,
  preserve_structure: true  # Maintain paragraph boundaries
)
```

#### Multi-Modal Content Addition

```ruby
# Add image with description
result = client.add_image(
  image_path: 'diagram.png',
  description: 'Neural network architecture diagram',
  alt_text: 'Diagram showing layers of a convolutional neural network',
  document_id: existing_document_id  # Optional: attach to existing document
)

# Add audio with transcript
result = client.add_audio(
  audio_path: 'lecture.mp3',
  transcript: 'Today we will discuss machine learning fundamentals...',
  document_id: existing_document_id  # Optional: attach to existing document
)

# Add mixed content document
result = client.add_mixed_document(
  files: [
    { type: 'text', path: 'notes.txt' },
    { type: 'image', path: 'chart.png', description: 'Performance chart' },
    { type: 'audio', path: 'recording.mp3' }
  ],
  title: 'Complete Research Package'
)
```

### Directory Processing

```ruby
# Process entire directory
result = client.add_directory(
  path: '/path/to/documents',
  recursive: true,
  file_patterns: ['*.pdf', '*.docx', '*.txt'],
  exclude_patterns: ['*temp*', '*.log'],
  batch_size: 10,
  parallel_processing: true
)

# Returns:
# {
#   success: true,
#   processed_files: 25,
#   skipped_files: 3,
#   failed_files: 1,
#   document_ids: ["123", "124", "125", ...],
#   processing_jobs: 75,
#   estimated_completion: "2024-01-15T10:30:00Z"
# }
```

### Document Retrieval

#### Single Document Retrieval

```ruby
# Get document by ID
document = client.get_document(id: "123")
# Returns:
# {
#   id: "123",
#   title: "research_paper",
#   location: "/path/to/research_paper.pdf",
#   document_type: "pdf",
#   status: "processed",
#   created_at: "2024-01-15T09:00:00Z",
#   updated_at: "2024-01-15T09:05:00Z",
#   metadata: {
#     summary: "This paper explores...",
#     keywords: ["AI", "neural networks"],
#     classification: "research",
#     topics: ["artificial intelligence"]
#   },
#   file_metadata: {
#     size: 2048576,
#     mime_type: "application/pdf",
#     pages: 15
#   },
#   content_summary: {
#     text_contents: 1,
#     image_contents: 3,
#     audio_contents: 0,
#     embeddings_count: 24,
#     embeddings_ready: true
#   }
# }

# Get document with content
document = client.get_document(id: "123", include_content: true)
# Includes actual text, image descriptions, and audio transcripts
```

#### Document Listing

```ruby
# List all documents
documents = client.list_documents

# List with pagination
documents = client.list_documents(
  page: 1,
  per_page: 20,
  sort: 'created_at',
  order: 'desc'
)

# List with filters
documents = client.list_documents(
  status: 'processed',
  document_type: ['pdf', 'docx'],
  created_after: 1.week.ago,
  has_embeddings: true,
  classification: 'research'
)

# Returns:
# {
#   documents: [
#     { id: "123", title: "doc1", status: "processed", ... },
#     { id: "124", title: "doc2", status: "processing", ... }
#   ],
#   pagination: {
#     current_page: 1,
#     total_pages: 5,
#     total_count: 89,
#     per_page: 20
#   }
# }
```

### Document Updates

```ruby
# Update document metadata
result = client.update_document(
  id: "123",
  title: "Updated Title",
  metadata: {
    category: 'technical',
    priority: 'high',
    last_reviewed: Date.current
  }
)

# Reprocess document with new settings
result = client.reprocess_document(
  id: "123",
  chunk_size: 1200,
  regenerate_embeddings: true,
  update_summary: true,
  extract_keywords: true
)
```

### Document Deletion

```ruby
# Delete single document
result = client.delete_document(id: "123")
# Returns:
# {
#   success: true,
#   message: "Document 123 and associated content deleted successfully",
#   deleted_embeddings: 24,
#   deleted_content_items: 4
# }

# Delete multiple documents
result = client.delete_documents(ids: ["123", "124", "125"])

# Delete with criteria
result = client.delete_documents(
  status: 'error',
  created_before: 1.month.ago,
  confirm: true  # Safety check for bulk deletion
)
```

## Search Operations

### Basic Search

```ruby
# Simple semantic search
results = client.search(query: "machine learning algorithms")

# Search with options
results = client.search(
  query: "neural network architectures",
  limit: 25,
  similarity_threshold: 0.8,
  content_types: ['text', 'image'],
  include_metadata: true
)

# Returns:
# {
#   query: "neural network architectures",
#   total_results: 15,
#   search_time: 0.234,
#   results: [
#     {
#       id: "emb_456",
#       document_id: "123",
#       content: "Neural networks are computational models...",
#       content_type: "text",
#       similarity_score: 0.92,
#       usage_score: 0.15,
#       composite_score: 0.87,
#       document_title: "Deep Learning Fundamentals",
#       metadata: { classification: "research", topics: ["AI"] },
#       chunk_index: 3,
#       returned_count: 5
#     }
#   ]
# }
```

### Advanced Search

#### Faceted Search

```ruby
# Search with facets
results = client.search_with_facets(
  query: "artificial intelligence",
  facets: {
    content_type: ['text', 'image'],
    classification: ['research', 'technical'],
    topics: ['machine learning', 'neural networks'],
    date_range: [6.months.ago, Time.current]
  },
  include_facet_counts: true
)

# Returns results plus facet breakdown:
# {
#   results: [...],
#   facets: {
#     content_type: { text: 45, image: 12, audio: 3 },
#     classification: { research: 30, technical: 20, educational: 10 },
#     topics: { "machine learning": 35, "neural networks": 25 }
#   }
# }
```

#### Hybrid Search

```ruby
# Combine semantic and full-text search
results = client.hybrid_search(
  query: "convolutional neural networks",
  semantic_weight: 0.7,
  fulltext_weight: 0.3,
  limit: 30
)

# Advanced hybrid search with filters
results = client.hybrid_search(
  query: "deep learning optimization",
  semantic_weight: 0.6,
  fulltext_weight: 0.4,
  filters: {
    classification: 'research',
    min_usage_count: 2
  },
  boost_recent: true  # Boost recently added documents
)
```

#### Multi-Modal Search

```ruby
# Search across content types
results = client.cross_modal_search(
  query: "neural network diagram",
  content_types: ['text', 'image', 'audio'],
  content_weights: {
    'text' => 1.0,
    'image' => 0.9,    # Slightly lower weight for images
    'audio' => 0.7     # Lower weight for audio transcripts
  }
)

# Content-type specific search
text_results = client.search_text_content(
  query: "machine learning theory",
  chunk_overlap_tolerance: 0.1  # Handle overlapping chunks
)

image_results = client.search_image_content(
  query: "architecture visualization",
  include_alt_text: true
)

audio_results = client.search_audio_content(
  query: "lecture on AI ethics",
  transcript_confidence_threshold: 0.8
)
```

### Search Analytics

```ruby
# Get search suggestions
suggestions = client.get_search_suggestions(
  partial_query: "machine",
  limit: 10,
  include_recent: true
)
# Returns: ["machine learning", "machine vision", "machine translation", ...]

# Search analytics
analytics = client.search_analytics(
  date_range: 1.month.ago..Time.current,
  include_top_queries: true,
  include_performance_metrics: true
)

# Returns:
# {
#   total_searches: 1250,
#   unique_queries: 380,
#   average_results_per_search: 12.5,
#   average_search_time: 0.156,
#   top_queries: [
#     { query: "machine learning", count: 45, avg_results: 15 },
#     { query: "neural networks", count: 32, avg_results: 18 }
#   ],
#   content_type_distribution: { text: 70, image: 20, audio: 10 }
# }
```

## RAG Enhancement

### Context Retrieval

```ruby
# Get relevant context for a query
context = client.get_context(
  query: "How do neural networks learn?",
  limit: 5,
  min_similarity: 0.75,
  max_context_length: 2000  # Character limit
)

# Returns:
# {
#   query: "How do neural networks learn?",
#   context_items: [
#     {
#       content: "Neural networks learn through backpropagation...",
#       source: "Deep Learning Textbook, Chapter 3",
#       similarity: 0.91,
#       content_type: "text"
#     }
#   ],
#   total_context_length: 1850,
#   sources: ["Deep Learning Textbook", "AI Research Paper"]
# }
```

### Prompt Enhancement

```ruby
# Enhance prompt with relevant context
enhanced = client.enhance_prompt(
  prompt: "Explain how neural networks learn",
  context_limit: 5,
  max_context_length: 1500,
  template: :academic,  # Use academic writing template
  include_sources: true
)

# Returns:
# {
#   original_prompt: "Explain how neural networks learn",
#   enhanced_prompt: "Based on the following context...\n\n[CONTEXT]\n\nExplain how neural networks learn",
#   context_used: 3,
#   context_length: 1200,
#   sources: ["Source A", "Source B", "Source C"],
#   template_applied: "academic"
# }

# Custom prompt templates
enhanced = client.enhance_prompt(
  prompt: "What is deep learning?",
  template: {
    prefix: "You are an AI expert. Using the provided context:",
    context_separator: "\n---\n",
    suffix: "\nProvide a comprehensive answer with examples.",
    include_source_attribution: true
  }
)
```

### RAG Pipeline

```ruby
# Complete RAG workflow
rag_result = client.rag_query(
  query: "What are the latest developments in transformer architectures?",
  llm_provider: :openai,
  model: 'gpt-4',
  context_limit: 7,
  temperature: 0.1,
  include_sources: true,
  stream_response: false
)

# Returns:
# {
#   query: "What are the latest developments in transformer architectures?",
#   context_retrieved: 7,
#   llm_response: "Recent developments in transformer architectures include...",
#   sources_used: [
#     { title: "Attention is All You Need", similarity: 0.94 },
#     { title: "BERT: Bidirectional Encoder Representations", similarity: 0.89 }
#   ],
#   response_metadata: {
#     model: "gpt-4",
#     tokens_used: 450,
#     response_time: 2.3
#   }
# }
```

## Document Status and Monitoring

### Processing Status

```ruby
# Check document processing status
status = client.document_status(id: "123")
# Returns:
# {
#   document_id: "123",
#   status: "processing",  # pending, processing, processed, error
#   progress: 65,          # Percentage complete
#   message: "Generating embeddings (15/24 chunks complete)",
#   jobs_queued: 2,
#   jobs_completed: 6,
#   estimated_completion: "2024-01-15T10:30:00Z",
#   processing_steps: {
#     text_extraction: "completed",
#     embedding_generation: "in_progress",
#     keyword_extraction: "queued",
#     summary_generation: "queued"
#   },
#   error_details: nil
# }

# Batch status check
statuses = client.batch_document_status(ids: ["123", "124", "125"])
```

### Background Job Management

```ruby
# Monitor background jobs
job_status = client.job_status
# Returns:
# {
#   active_jobs: 12,
#   queued_jobs: 5,
#   failed_jobs: 1,
#   queue_status: {
#     embeddings: { size: 3, latency: 2.5 },
#     processing: { size: 2, latency: 1.1 },
#     analysis: { size: 0, latency: 0.0 }
#   },
#   worker_status: {
#     busy_workers: 4,
#     idle_workers: 2,
#     total_workers: 6
#   }
# }

# Retry failed jobs
result = client.retry_failed_jobs(
  job_types: ['GenerateEmbeddingsJob'],
  older_than: 1.hour.ago
)
```

## System Operations

### Health Monitoring

```ruby
# System health check
health = client.health_check
# Returns:
# {
#   status: "healthy",  # healthy, degraded, unhealthy
#   components: {
#     database: "healthy",
#     embedding_service: "healthy",
#     background_jobs: "healthy",
#     search_index: "healthy"
#   },
#   performance: {
#     avg_search_time: 0.156,
#     avg_embedding_time: 0.089,
#     queue_depth: 3
#   },
#   last_check: "2024-01-15T10:00:00Z"
# }

# Detailed health information
detailed_health = client.detailed_health_check
```

### System Statistics

```ruby
# Comprehensive system statistics
stats = client.stats
# Returns:
# {
#   documents: {
#     total: 1250,
#     by_type: { pdf: 450, docx: 300, text: 250, image: 150, audio: 100 },
#     by_status: { processed: 1200, processing: 30, error: 20 },
#     total_size: "2.5 GB"
#   },
#   content: {
#     text_contents: 1150,
#     image_contents: 250,
#     audio_contents: 180,
#     mixed_documents: 75
#   },
#   embeddings: {
#     total: 28500,
#     by_model: { "text-embedding-3-small": 25000, "text-embedding-ada-002": 3500 },
#     avg_per_document: 22.8,
#     index_size: "1.2 GB"
#   },
#   search: {
#     total_searches: 5600,
#     avg_results_per_search: 15.2,
#     avg_search_time: 0.145,
#     top_queries: ["machine learning", "neural networks", "AI research"]
#   },
#   usage: {
#     active_users: 45,
#     searches_today: 230,
#     documents_added_today: 12,
#     storage_used: "3.1 GB",
#     api_calls_today: 1250
#   }
# }

# Time-series statistics
time_stats = client.time_series_stats(
  period: 1.month.ago..Time.current,
  granularity: 'day'  # hour, day, week, month
)
```

### Configuration Management

```ruby
# Get current configuration (sanitized)
config = client.configuration
# Returns configuration without sensitive data (API keys masked)

# Update configuration at runtime
result = client.update_configuration(
  search_similarity_threshold: 0.8,
  max_search_results: 30
)

# Reset to defaults
client.reset_configuration(preserve_credentials: true)
```

## Error Handling

### Standard Error Response Format

```ruby
# All methods return structured error information on failure
begin
  result = client.add_document(path: 'nonexistent.pdf')
rescue Ragdoll::Core::DocumentNotFoundError => e
  puts e.message  # "File not found: nonexistent.pdf"
  puts e.error_code  # "DOCUMENT_NOT_FOUND"
  puts e.details  # { path: 'nonexistent.pdf', checked_locations: [...] }
end

# Check for errors in response
result = client.search(query: "test")
if result[:success]
  # Process results
  puts result[:results]
else
  # Handle error
  puts result[:error]
  puts result[:error_code]
  puts result[:details]
end
```

### Common Error Types

```ruby
# Document processing errors
Ragdoll::Core::DocumentNotFoundError
Ragdoll::Core::UnsupportedDocumentTypeError
Ragdoll::Core::DocumentProcessingError

# Search errors
Ragdoll::Core::InvalidQueryError
Ragdoll::Core::SearchTimeoutError
Ragdoll::Core::EmbeddingGenerationError

# Configuration errors
Ragdoll::Core::ConfigurationError
Ragdoll::Core::InvalidProviderError
Ragdoll::Core::MissingCredentialsError

# System errors
Ragdoll::Core::DatabaseConnectionError
Ragdoll::Core::BackgroundJobError
Ragdoll::Core::SystemHealthError
```

## Best Practices

### 1. Error Handling
- Always check for errors in responses
- Implement retry logic for transient failures
- Log errors with sufficient context for debugging
- Use appropriate error handling strategies for different error types

### 2. Performance Optimization
- Use batch operations for multiple documents
- Implement appropriate caching for frequently accessed data
- Monitor search performance and adjust thresholds accordingly
- Use background processing for large document collections

### 3. Search Strategy
- Start with default settings and tune based on results quality
- Use faceted search to help users navigate large result sets
- Implement search suggestions to improve user experience
- Monitor search analytics to understand usage patterns

### 4. RAG Implementation
- Choose appropriate context limits based on your LLM's capabilities
- Use prompt templates for consistent formatting
- Include source attribution for transparency
- Monitor RAG response quality and adjust context retrieval accordingly

The Client API provides a comprehensive interface for building sophisticated document intelligence applications with Ragdoll, offering both simplicity for basic use cases and advanced features for complex requirements.