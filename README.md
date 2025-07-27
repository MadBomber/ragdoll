<div align="center" style="background-color: yellow; color: black; padding: 20px; margin: 20px 0; border: 2px solid black; font-size: 48px; font-weight: bold;">
  ⚠️ CAUTION ⚠️<br />
  Software Under Development by a Crazy Man
</div>

<div align="center">
  <table>
    <tr>
      <td width="50%">
        <a href="https://research.ibm.com/blog/retrieval-augmented-generation-RAG" target="_blank">
          <img src="rag_doll.png" alt="Ragdoll" width="800">
        </a>
      </td>
      <td width="50%" valign="top">
        <p>Multi-modal RAG (Retrieval-Augmented Generation) is an architecture that integrates multiple data types (such as text, images, and audio) to enhance AI response generation. It combines retrieval-based methods, which fetch relevant information from a knowledge base, with generative large languagemodels (LLMs) that create coherent and contextually appropriate outputs. This approach allows for more comprehensive and engaging user interactions, such as chatbots that respond with both text and images or educational tools that incorporate visual aids into learning materials. By leveraging various modalities, multi-modal RAG systems improve context understanding and user experience.</p>
      </td>
    </tr>
  </table>
</div>

# Ragdoll::Core

Database-oriented multi-modal RAG (Retrieval-Augmented Generation) library built on ActiveRecord. Features PostgreSQL + pgvector for high-performance semantic search, polymorphic content architecture, and dual metadata design for sophisticated document analysis.

## Quick Start

```ruby
require 'ragdoll'

# Configure with PostgreSQL + pgvector
Ragdoll::Core.configure do |config|
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
result = Ragdoll::Core.add_document(path: 'research_paper.pdf')
puts result[:message]  # "Document 'research_paper' added successfully with ID 123"
doc_id = result[:document_id]

# Check document status
status = Ragdoll::Core.document_status(id: doc_id)
puts status[:message]  # Shows processing status and embeddings count

# Search across content
results = Ragdoll::Core.search(query: 'neural networks')

# Get detailed document information
document = Ragdoll::Core.get_document(id: doc_id)
```

## High-Level API

The `Ragdoll` module provides a convenient high-level API for common operations:

### Document Management

```ruby
# Add single document - returns detailed result hash
result = Ragdoll::Core.add_document(path: 'document.pdf')
puts result[:success]         # true
puts result[:document_id]     # "123"
puts result[:message]         # "Document 'document' added successfully with ID 123"
puts result[:embeddings_queued] # true

# Check document processing status
status = Ragdoll::Core.document_status(id: result[:document_id])
puts status[:status]          # "processed"
puts status[:embeddings_count] # 15
puts status[:embeddings_ready] # true
puts status[:message]         # "Document processed successfully with 15 embeddings"

# Get detailed document information
document = Ragdoll::Core.get_document(id: result[:document_id])
puts document[:title]         # "document"
puts document[:status]        # "processed"
puts document[:embeddings_count] # 15
puts document[:content_length]   # 5000

# Update document metadata
Ragdoll::Core.update_document(id: result[:document_id], title: 'New Title')

# Delete document
Ragdoll::Core.delete_document(id: result[:document_id])

# List all documents
documents = Ragdoll::Core.list_documents(limit: 10)

# System statistics
stats = Ragdoll::Core.stats
puts stats[:total_documents]  # 50
puts stats[:total_embeddings] # 1250
```

### Search and Retrieval

```ruby
# Semantic search across all content types
results = Ragdoll::Core.search(query: 'artificial intelligence')

# Search specific content types
text_results = Ragdoll::Core.search(query: 'machine learning', content_type: 'text')
image_results = Ragdoll::Core.search(query: 'neural network diagram', content_type: 'image')
audio_results = Ragdoll::Core.search(query: 'AI discussion', content_type: 'audio')

# Advanced search with metadata filters
results = Ragdoll::Core.search(
  query: 'deep learning',
  classification: 'research',
  keywords: ['AI', 'neural networks'],
  tags: ['technical']
)

# Get context for RAG applications
context = Ragdoll::Core.get_context(query: 'machine learning', limit: 5)

# Enhanced prompt with context
enhanced = Ragdoll::Core.enhance_prompt(
  prompt: 'What is machine learning?',
  context_limit: 5
)

# Hybrid search combining semantic and full-text
results = Ragdoll::Core.hybrid_search(
  query: 'neural networks',
  semantic_weight: 0.7,
  text_weight: 0.3
)
```

### System Operations

```ruby
# Get system statistics
stats = Ragdoll::Core.stats
# Returns information about documents, content types, embeddings, etc.

# Health check
healthy = Ragdoll::Core.healthy?

# Get configuration
config = Ragdoll::Core.configuration

# Reset configuration (useful for testing)
Ragdoll::Core.reset_configuration!
```

### Configuration

```ruby
# Configure the system
Ragdoll::Core.configure do |config|
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
- **Text document processing**: PDF, DOCX, HTML, Markdown, plain text files
- **Embedding generation**: Text chunking and vector embedding creation
- **Database schema**: Multi-modal polymorphic architecture with PostgreSQL + pgvector
- **Dual metadata architecture**: Separate LLM-generated content analysis and file properties
- **Search functionality**: Semantic search with cosine similarity and usage analytics
- **Document management**: Add, update, delete, list operations
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
result = Ragdoll::Core.add_document(path: 'document.pdf')

# Check processing status
status = Ragdoll::Core.document_status(id: result[:document_id])

# Search the content
results = Ragdoll::Core.search(query: 'machine learning')
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
Ragdoll::Core.configure do |config|
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

## Related Projects

- **ragdoll-cli**: Standalone CLI application using ragdoll
- **ragdoll-rails**: Rails engine with web interface for ragdoll

## Key Design Principles

1. **Database-Oriented**: Built on ActiveRecord with PostgreSQL + pgvector for production performance
2. **Multi-Modal First**: Text, image, and audio content as first-class citizens via polymorphic architecture
3. **Dual Metadata Design**: Separates LLM-generated content analysis from file properties
4. **LLM-Enhanced**: Structured metadata generation with schema validation using latest AI capabilities
5. **High-Level API**: Simple, intuitive interface for complex operations
6. **Scalable**: Designed for production workloads with background processing and proper indexing
7. **Extensible**: Easy to add new content types and embedding models through polymorphic design
