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
# Setup configuration first
Ragdoll::Core.configure do |config|
  config.llm_providers[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.models[:embedding][:text] = 'openai/text-embedding-3-small'
  config.models[:text_generation][:default] = 'openai/gpt-4o-mini'
  config.database = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['RAGDOLL_DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end

# Initialize client (uses global configuration)
client = Ragdoll::Core::Client.new
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
#   title: "research_paper",
#   document_type: "pdf",
#   content_length: 15000,
#   embeddings_queued: true,
#   message: "Document 'research_paper' added successfully with ID 123"
# }
```

#### Text Content Addition

```ruby
# Add raw text content
doc_id = client.add_text(
  content: "This is the text content to be processed...",
  title: "Text Document",
  source: 'user_input',
  language: 'en'
)

# Add text with custom chunking
doc_id = client.add_text(
  content: long_text_content,
  title: "Long Text Document",
  chunk_size: 800,
  chunk_overlap: 150
)
```


### Directory Processing

```ruby
# Process entire directory
results = client.add_directory(
  path: '/path/to/documents',
  recursive: true
)

# Returns array of results:
# [
#   { file: "/path/to/doc1.pdf", document_id: "123", status: "success" },
#   { file: "/path/to/doc2.txt", document_id: "124", status: "success" },
#   { file: "/path/to/bad.doc", error: "Unsupported format", status: "error" }
# ]
```

### Document Retrieval

#### Single Document Retrieval

```ruby
# Get document by ID
document = client.get_document(id: "123")
# Returns document hash with basic information

# Get document status
status = client.document_status(id: "123")
# Returns:
# {
#   id: "123",
#   title: "research_paper",
#   status: "processed",
#   embeddings_count: 24,
#   embeddings_ready: true,
#   content_preview: "This research paper discusses...",
#   message: "Document processed successfully with 24 embeddings"
# }
```

#### Document Listing

```ruby
# List documents with basic options
documents = client.list_documents

# List with options
documents = client.list_documents(
  status: 'processed',
  document_type: 'pdf',
  limit: 20
)
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
  threshold: 0.8
)

# Returns:
# {
#   query: "neural network architectures",
#   results: [
#     {
#       embedding_id: "456",
#       document_id: "123",
#       document_title: "Deep Learning Fundamentals",
#       document_location: "/path/to/document.pdf",
#       content: "Neural networks are computational models...",
#       similarity: 0.92,
#       chunk_index: 3,
#       usage_count: 5
#     }
#   ],
#   total_results: 15
# }

# Hybrid search (semantic + full-text)
results = client.hybrid_search(
  query: "neural networks",
  semantic_weight: 0.7,
  text_weight: 0.3
)
```

### Search Analytics

```ruby
# Simple search analytics available
analytics = client.search_analytics(days: 30)
# Returns basic usage statistics
```

## RAG Enhancement

### Context Retrieval

```ruby
# Get relevant context for a query
context = client.get_context(
  query: "How do neural networks learn?",
  limit: 5
)

# Returns:
# {
#   context_chunks: [
#     {
#       content: "Neural networks learn through backpropagation...",
#       source: "/path/to/textbook.pdf",
#       similarity: 0.91,
#       chunk_index: 3
#     }
#   ],
#   combined_context: "Neural networks learn through backpropagation...",
#   total_chunks: 5
# }
```

### Prompt Enhancement

```ruby
# Enhance prompt with relevant context
enhanced = client.enhance_prompt(
  prompt: "Explain how neural networks learn",
  context_limit: 5
)

# Returns:
# {
#   enhanced_prompt: "You are an AI assistant. Use the following context...",
#   original_prompt: "Explain how neural networks learn",
#   context_sources: ["/path/to/textbook.pdf", "/path/to/paper.pdf"],
#   context_count: 3
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
# Simple health check
healthy = client.healthy?
# Returns true/false

# Basic system statistics
stats = client.stats
# Returns document statistics hash
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