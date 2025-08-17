<div align="center" style="background-color: yellow; color: black; padding: 20px; margin: 20px 0; border: 2px solid black; font-size: 48px; font-weight: bold;">
  ⚠️ CAUTION ⚠️<br />
  Software Under Development by a Crazy Man
</div>
<br />
<div align="center">
  <table>
    <tr>
      <td width="50%">
        <a href="https://research.ibm.com/blog/retrieval-augmented-generation-RAG" target="_blank">
          <img src="ragdoll.png" alt="Ragdoll" width="800">
        </a>
      </td>
      <td width="50%" valign="top">
        <p>Multi-modal RAG (Retrieval-Augmented Generation) is an architecture that integrates multiple data types (such as text, images, and audio) to enhance AI response generation. It combines retrieval-based methods, which fetch relevant information from a knowledge base, with generative large language models (LLMs) that create coherent and contextually appropriate outputs. This approach allows for more comprehensive and engaging user interactions, such as chatbots that respond with both text and images or educational tools that incorporate visual aids into learning materials. By leveraging various modalities, multi-modal RAG systems improve context understanding and user experience.</p>
      </td>
    </tr>
  </table>
</div>

# Ragdoll

Database-oriented multi-modal RAG (Retrieval-Augmented Generation) library built on ActiveRecord. Features PostgreSQL + pgvector for high-performance semantic search, polymorphic content architecture, and dual metadata design for sophisticated document analysis.

RAG does not have to be hard.  Every week its getting simpler.  The frontier LLM providers are starting to encorporate RAG services.  For example OpenAI offers a vector search service.  See: [https://0x1eef.github.io/posts/an-introduction-to-rag-with-llm.rb/](https://0x1eef.github.io/posts/an-introduction-to-rag-with-llm.rb/)

## Overview

Ragdoll is a database-first, multi-modal Retrieval-Augmented Generation (RAG) library for Ruby. It pairs PostgreSQL + pgvector with an ActiveRecord-driven schema to deliver fast, production-grade semantic search and clean data modeling. Today it ships with robust text processing; image and audio pipelines are scaffolded and actively being completed.

The library emphasizes a dual-metadata design: LLM-derived semantic metadata for understanding content, and system file metadata for managing assets. With built-in analytics, background processing, and a high-level API, you can go from ingest to answer quickly—and scale confidently.

### Why Ragdoll?

- Database-first foundation on ActiveRecord (PostgreSQL + pgvector only) for performance and reliability
- Multi-modal architecture (text today; image/audio next) via polymorphic content design
- Dual metadata model separating semantic analysis from file properties
- Provider-agnostic LLM integration via `ruby_llm` (OpenAI, Anthropic, Google)
- Production-friendly: background jobs, connection pooling, indexing, and search analytics
- Simple, ergonomic high-level API to keep your application code clean

### Key Capabilities

- Semantic search with vector similarity (cosine) across polymorphic content
- Text ingestion, chunking, and embedding generation
- LLM-powered structured metadata with schema validation
- Search tracking and analytics (CTR, performance, similarity of queries)
- Hybrid search (semantic + full-text) planned
- Extensible model and configuration system

## Table of Contents

- [Quick Start](#quick-start)
- [API Overview](#api-overview)
- [Search and Retrieval](#search-and-retrieval)
- [Search Analytics and Tracking](#search-analytics-and-tracking)
- [System Operations](#system-operations)
- [Configuration](#configuration)
- [Current Implementation Status](#current-implementation-status)
- [Architecture Highlights](#architecture-highlights)
- [Text Document Processing](#text-document-processing-current)
- [PostgreSQL + pgvector Configuration](#postgresql--pgvector-configuration)
- [Performance Features](#performance-features)
- [Installation](#installation)
- [Requirements](#requirements)
- [Use Cases](#use-cases)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)
- [Related Projects](#related-projects)
- [Key Design Principles](#key-design-principles)
- [Contributing & Support](#contributing--support)

## Quick Start

```ruby
require 'ragdoll'

# Configure with PostgreSQL + pgvector
Ragdoll.configure do |config|
  # Database configuration (PostgreSQL only)
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }

  # Ruby LLM configuration
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:openai][:organization] = ENV['OPENAI_ORGANIZATION']
  config.ruby_llm_config[:openai][:project] = ENV['OPENAI_PROJECT']

  # Model configuration
  config.models[:default] = 'openai/gpt-4o'
  config.models[:embedding][:text] = 'text-embedding-3-small'

  # Logging configuration
  config.logging_config[:log_level] = :warn
  config.logging_config[:log_filepath] = File.join(Dir.home, '.ragdoll', 'ragdoll.log')
end

# Add documents - returns detailed result
result = Ragdoll.add_document(path: 'research_paper.pdf')
puts result[:message]  # "Document 'research_paper' added successfully with ID 123"
doc_id = result[:document_id]

# Check document status
status = Ragdoll.document_status(id: doc_id)
puts status[:message]  # Shows processing status and embeddings count

# Search across content
results = Ragdoll.search(query: 'neural networks')

# Get detailed document information
document = Ragdoll.get_document(id: doc_id)
```

## API Overview

The `Ragdoll` module provides a convenient high-level API for common operations:

### Document Management

```ruby
# Add single document - returns detailed result hash
result = Ragdoll.add_document(path: 'document.pdf')
puts result[:success]         # true
puts result[:document_id]     # "123"
puts result[:message]         # "Document 'document' added successfully with ID 123"
puts result[:embeddings_queued] # true

# Add document with force option to override duplicate detection
result = Ragdoll.add_document(path: 'document.pdf', force: true)
# Creates new document even if duplicate exists

# Check document processing status
status = Ragdoll.document_status(id: result[:document_id])
puts status[:status]          # "processed"
puts status[:embeddings_count] # 15
puts status[:embeddings_ready] # true
puts status[:message]         # "Document processed successfully with 15 embeddings"

# Get detailed document information
document = Ragdoll.get_document(id: result[:document_id])
puts document[:title]         # "document"
puts document[:status]        # "processed"
puts document[:embeddings_count] # 15
puts document[:content_length]   # 5000

# Update document metadata
Ragdoll.update_document(id: result[:document_id], title: 'New Title')

# Delete document
Ragdoll.delete_document(id: result[:document_id])

# List all documents
documents = Ragdoll.list_documents(limit: 10)

# System statistics
stats = Ragdoll.stats
puts stats[:total_documents]  # 50
puts stats[:total_embeddings] # 1250
```

### Duplicate Detection

Ragdoll includes sophisticated duplicate detection to prevent redundant document processing:

```ruby
# Automatic duplicate detection (default behavior)
result1 = Ragdoll.add_document(path: 'research.pdf')
result2 = Ragdoll.add_document(path: 'research.pdf')
# result2 returns the same document_id as result1 (duplicate detected)

# Force adding a duplicate document
result3 = Ragdoll.add_document(path: 'research.pdf', force: true)
# Creates a new document with modified location identifier

# Duplicate detection criteria:
# 1. Exact location/path match
# 2. File modification time (for files)
# 3. File content hash (SHA256)
# 4. Content hash for text
# 5. File size and metadata similarity
# 6. Document title and type matching
```

**Duplicate Detection Features:**
- **Multi-level detection**: Checks location, file hash, content hash, and metadata
- **Smart similarity**: Detects duplicates even with minor differences (5% content tolerance)
- **File integrity**: SHA256 hashing for reliable file comparison
- **URL support**: Content-based detection for web documents
- **Force option**: Override detection when needed
- **Performance optimized**: Database indexes for fast lookups

### Search and Retrieval

```ruby
# Semantic search across all content types
results = Ragdoll.search(query: 'artificial intelligence')

# Search with automatic tracking (default)
results = Ragdoll.search(
  query: 'machine learning',
  session_id: 123,  # Optional: track user sessions
  user_id:    456   # Optional: track by user
)

# Search specific content types
text_results = Ragdoll.search(query: 'machine learning', content_type: 'text')
image_results = Ragdoll.search(query: 'neural network diagram', content_type: 'image')
audio_results = Ragdoll.search(query: 'AI discussion', content_type: 'audio')

# Advanced search with metadata filters
results = Ragdoll.search(
  query: 'deep learning',
  classification: 'research',
  keywords: ['AI', 'neural networks'],
  tags: ['technical']
)

# Get context for RAG applications
context = Ragdoll.get_context(query: 'machine learning', limit: 5)

# Enhanced prompt with context
enhanced = Ragdoll.enhance_prompt(
  prompt: 'What is machine learning?',
  context_limit: 5
)

# Hybrid search combining semantic and full-text
results = Ragdoll.hybrid_search(
  query: 'neural networks',
  semantic_weight: 0.7,
  text_weight: 0.3
)
```

### Keywords Search

Ragdoll supports powerful keywords-based search that can be used standalone or combined with semantic search. The keywords system uses PostgreSQL array operations for high performance and supports both partial matching (overlap) and exact matching (contains all).

```ruby
# Keywords-only search (overlap - documents containing any of the keywords)
results = Ragdoll::Document.search_by_keywords(['machine', 'learning', 'ai'])

# Results are sorted by match count (documents with more keyword matches rank higher)
results.each do |doc|
  puts "#{doc.title}: #{doc.keywords_match_count} matches"
end

# Exact keywords search (contains all - documents must have ALL keywords)
results = Ragdoll::Document.search_by_keywords_all(['ruby', 'programming'])

# Results are sorted by focus (fewer total keywords = more focused document)
results.each do |doc|
  puts "#{doc.title}: #{doc.total_keywords_count} total keywords"
end

# Combined semantic + keywords search for best results
results = Ragdoll.search(
  query: 'artificial intelligence applications',
  keywords: ['ai', 'machine learning', 'neural networks'],
  limit: 10
)

# Keywords search with options
results = Ragdoll::Document.search_by_keywords(
  ['web', 'javascript', 'frontend'],
  limit: 20
)

# Case-insensitive keyword matching (automatically normalized)
results = Ragdoll::Document.search_by_keywords(['Python', 'DATA-SCIENCE', 'ai'])
# Will match documents with keywords: ['python', 'data-science', 'ai']
```

**Keywords Search Features:**
- **High Performance**: Uses PostgreSQL GIN indexes for fast array operations
- **Flexible Matching**: Supports both overlap (`&&`) and contains (`@>`) operators
- **Smart Scoring**: Results ordered by match count or document focus
- **Case Insensitive**: Automatic keyword normalization
- **Integration Ready**: Works seamlessly with semantic search
- **Inspired by `find_matching_entries.rb`**: Optimized for PostgreSQL arrays

### Search Analytics and Tracking

Ragdoll automatically tracks all searches to provide comprehensive analytics and improve search relevance over time:

```ruby
# Get search analytics for the last 30 days
analytics = Ragdoll::Search.search_analytics(days: 30)
puts "Total searches: #{analytics[:total_searches]}"
puts "Unique queries: #{analytics[:unique_queries]}"
puts "Average execution time: #{analytics[:avg_execution_time]}ms"
puts "Click-through rate: #{analytics[:click_through_rate]}%"

# Find similar searches using vector similarity
search = Ragdoll::Search.first
similar_searches = search.nearest_neighbors(:query_embedding, distance: :cosine).limit(5)

similar_searches.each do |similar|
  puts "Query: #{similar.query}"
  puts "Similarity: #{similar.neighbor_distance}"
  puts "Results: #{similar.results_count}"
end

# Track user interactions (clicks on search results)
search_result = Ragdoll::SearchResult.first
search_result.mark_as_clicked!

# Disable tracking for specific searches if needed
results = Ragdoll.search(
  query: 'private query',
  track_search: false
)
```

### System Operations

```ruby
# Get system statistics
stats = Ragdoll.stats
# Returns information about documents, content types, embeddings, etc.

# Health check
healthy = Ragdoll.healthy?

# Get configuration
config = Ragdoll.configuration

# Reset configuration (useful for testing)
Ragdoll.reset_configuration!
```

### Configuration

```ruby
# Configure the system
Ragdoll.configure do |config|
  # Database configuration (PostgreSQL only - REQUIRED)
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }

  # Ruby LLM configuration for multiple providers
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
  config.ruby_llm_config[:openai][:organization] = ENV['OPENAI_ORGANIZATION']
  config.ruby_llm_config[:openai][:project] = ENV['OPENAI_PROJECT']

  config.ruby_llm_config[:anthropic][:api_key] = ENV['ANTHROPIC_API_KEY']
  config.ruby_llm_config[:google][:api_key] = ENV['GOOGLE_API_KEY']

  # Model configuration
  config.models[:default] = 'openai/gpt-4o'
  config.models[:summary] = 'openai/gpt-4o'
  config.models[:keywords] = 'openai/gpt-4o'
  config.models[:embedding][:text] = 'text-embedding-3-small'
  config.models[:embedding][:image] = 'image-embedding-3-small'
  config.models[:embedding][:audio] = 'audio-embedding-3-small'

  # Logging configuration
  config.logging_config[:log_level] = :warn  # :debug, :info, :warn, :error, :fatal
  config.logging_config[:log_filepath] = File.join(Dir.home, '.ragdoll', 'ragdoll.log')

  # Processing settings
  config.chunking[:text][:max_tokens] = 1000
  config.chunking[:text][:overlap] = 200
  config.search[:similarity_threshold] = 0.7
  config.search[:max_results] = 10
end
```

## Current Implementation Status

### ✅ **Fully Implemented**
- **Text document processing**: PDF, DOCX, HTML, Markdown, plain text files with encoding fallback
- **Embedding generation**: Text chunking and vector embedding creation
- **Database schema**: Multi-modal polymorphic architecture with PostgreSQL + pgvector
- **Dual metadata architecture**: Separate LLM-generated content analysis and file properties
- **Search functionality**: Semantic search with cosine similarity and usage analytics
- **Search tracking system**: Comprehensive analytics with query embeddings, click-through tracking, and performance monitoring
- **Document management**: Add, update, delete, list operations
- **Duplicate detection**: Multi-level duplicate prevention with file hash, content hash, and metadata comparison
- **Background processing**: ActiveJob integration for async embedding generation
- **LLM metadata generation**: AI-powered structured content analysis with schema validation
- **Logging**: Configurable file-based logging with multiple levels

### 🚧 **In Development**
- **Image processing**: Framework exists but vision AI integration needs completion
- **Audio processing**: Framework exists but speech-to-text integration needs completion
- **Hybrid search**: Combining semantic and full-text search capabilities

### 📋 **Planned Features**
- **Multi-modal search**: Search across text, image, and audio content types
- **Content-type specific embedding models**: Different models for text, image, audio
- **Enhanced metadata schemas**: Domain-specific metadata templates

## Architecture Highlights

### Dual Metadata Design

Ragdoll uses a sophisticated dual metadata architecture to separate concerns:

- **`metadata` (JSON)**: LLM-generated content analysis including summary, keywords, classification, topics, sentiment, and domain-specific insights
- **`file_metadata` (JSON)**: System-generated file properties including size, MIME type, dimensions, processing parameters, and technical characteristics

This separation enables both semantic search operations on content meaning and efficient file management operations.

### Polymorphic Multi-Modal Architecture

The database schema uses polymorphic associations to elegantly support multiple content types:

- **Documents**: Central entity with dual metadata columns
- **Content Types**: Specialized tables for `text_contents`, `image_contents`, `audio_contents`
- **Embeddings**: Unified vector storage via polymorphic `embeddable` associations

## Text Document Processing (Current)

Currently, Ragdoll processes text documents through:

1. **Content Extraction**: Extracts text from PDF, DOCX, HTML, Markdown, and plain text
2. **Metadata Generation**: AI-powered analysis creates structured content metadata
3. **Text Chunking**: Splits content into manageable chunks with configurable size/overlap
4. **Embedding Generation**: Creates vector embeddings using OpenAI or other providers
5. **Database Storage**: Stores in polymorphic multi-modal architecture with dual metadata
6. **Search**: Semantic search using cosine similarity with usage analytics

### Example Usage

```ruby
# Add a text document
result = Ragdoll.add_document(path: 'document.pdf')

# Check processing status
status = Ragdoll.document_status(id: result[:document_id])

# Search the content
results = Ragdoll.search(query: 'machine learning')
```

## PostgreSQL + pgvector Configuration

### Database Setup

```bash
# Install PostgreSQL and pgvector
brew install postgresql pgvector  # macOS
# or
apt-get install postgresql postgresql-contrib  # Ubuntu

# Create database and enable pgvector extension
createdb ragdoll_production
psql -d ragdoll_production -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Configuration Example

```ruby
Ragdoll.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    pool: 20,
    auto_migrate: true
  }
end
```

## Performance Features

- **Native pgvector**: Hardware-accelerated similarity search
- **IVFFlat indexing**: Fast approximate nearest neighbor search
- **Polymorphic embeddings**: Unified search across content types
- **Batch processing**: Efficient bulk operations
- **Background jobs**: Asynchronous document processing
- **Connection pooling**: High-concurrency support

## Installation

```bash
# Install system dependencies
brew install postgresql pgvector  # macOS
# or
apt-get install postgresql postgresql-contrib  # Ubuntu

# Install gem
gem install ragdoll

# Or add to Gemfile
gem 'ragdoll'
```

## Requirements

- **Ruby**: 3.2+
- **PostgreSQL**: 12+ with pgvector extension (REQUIRED - no other databases supported)
- **Dependencies**: activerecord, pg, pgvector, neighbor, ruby_llm, pdf-reader, docx, rubyzip, shrine, rmagick, opensearch-ruby, searchkick, ruby-progressbar

## Use Cases

- Internal knowledge bases and chat assistants grounded in your documents
- Product documentation and support search with analytics and relevance feedback
- Research corpora exploration (summaries, topics, similarity) across large text sets
- Incident retrospectives and operational analytics with searchable write-ups
- Media libraries preparing for text + image + audio pipelines (image/audio in progress)

## Environment Variables

Set the following as environment variables (do not commit secrets to source control):

- `OPENAI_API_KEY` — required for OpenAI models
- `OPENAI_ORGANIZATION` — optional, for OpenAI org scoping
- `OPENAI_PROJECT` — optional, for OpenAI project scoping
- `ANTHROPIC_API_KEY` — optional, for Anthropic models
- `GOOGLE_API_KEY` — optional, for Google models
- `DATABASE_PASSWORD` — your PostgreSQL password if not using peer auth

## Troubleshooting

### pgvector extension missing

- Ensure the extension is enabled in your database:

```bash
psql -d ragdoll_production -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

- If the command fails, verify PostgreSQL and pgvector are installed and that you’re connecting to the correct database.

### Document stuck in "processing"

- Confirm your API keys are set and valid.
- Ensure `auto_migrate: true` in configuration (or run migrations if you manage schema yourself).
- Check logs at the path configured by `logging_config[:log_filepath]` for errors.

## Related Projects

- **ragdoll-cli**: Standalone CLI application using ragdoll
- **ragdoll-rails**: Rails engine with web interface for ragdoll

## Contributing & Support

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request. For questions and feedback, open an issue in this repository.

## Key Design Principles

1. **Database-Oriented**: Built on ActiveRecord with PostgreSQL + pgvector for production performance
2. **Multi-Modal First**: Text, image, and audio content as first-class citizens via polymorphic architecture
3. **Dual Metadata Design**: Separates LLM-generated content analysis from file properties
4. **LLM-Enhanced**: Structured metadata generation with schema validation using latest AI capabilities
5. **High-Level API**: Simple, intuitive interface for complex operations
6. **Scalable**: Designed for production workloads with background processing and proper indexing
7. **Extensible**: Easy to add new content types and embedding models through polymorphic design
