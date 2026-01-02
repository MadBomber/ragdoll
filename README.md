> [!CAUTION]<br />
> **Software Under Development by a Crazy Man**<br />
> Gave up on the multi-modal vectorization approach,<br />
> now using a unified text-based RAG architecture.
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
        <p><strong>🔄 NEW: Unified Text-Based RAG Architecture</strong></p>
        <p>Ragdoll has evolved to a unified text-based RAG (Retrieval-Augmented Generation) architecture that converts all media types—text, images, audio, and video—to comprehensive text representations before vectorization. This approach enables true cross-modal search where you can find images through their AI-generated descriptions, audio through transcripts, and all content through a single, powerful text-based search index.</p>
      </td>
    </tr>
  </table>
</div>

# Ragdoll

**Unified Text-Based RAG (Retrieval-Augmented Generation) library built on ActiveRecord.** Features PostgreSQL + pgvector for high-performance semantic search with a simplified architecture that converts all media types to searchable text.

RAG does not have to be hard. The new unified approach eliminates the complexity of multi-modal vectorization while enabling powerful cross-modal search capabilities. See: [https://0x1eef.github.io/posts/an-introduction-to-rag-with-llm.rb/](https://0x1eef.github.io/posts/an-introduction-to-rag-with-llm.rb/)

## 🆕 **What's New: Unified Text-Based Architecture**

Ragdoll 2.0 introduces a revolutionary unified approach:

- **All Media → Text**: Images become comprehensive descriptions, audio becomes transcripts
- **Single Embedding Model**: One text embedding model for all content types
- **Cross-Modal Search**: Find images through descriptions, audio through transcripts
- **Simplified Architecture**: No more complex STI (Single Table Inheritance) models
- **Better Search**: Unified text index enables more sophisticated queries
- **Migration Path**: Smooth transition from the previous multi-modal system

## Overview

Ragdoll is a database-first, unified text-based Retrieval-Augmented Generation (RAG) library for Ruby. It pairs PostgreSQL + pgvector with an ActiveRecord-driven schema to deliver fast, production-grade semantic search through a simplified unified architecture.

The library converts all document types to rich text representations: PDFs and documents are extracted as text, images are converted to comprehensive AI-generated descriptions, and audio files are transcribed. This unified approach enables powerful cross-modal search while maintaining simplicity.

### Why the New Unified Architecture?

- **Simplified Complexity**: Single content model instead of multiple polymorphic types
- **Cross-Modal Search**: Find images by searching for objects or concepts in their descriptions
- **Unified Index**: One text-based search index for all content types
- **Better Retrieval**: Text descriptions often contain more searchable information than raw media
- **Cost Effective**: Single embedding model instead of specialized models per media type
- **Easier Maintenance**: One embedding pipeline to maintain and optimize

### Key Capabilities

- **Universal Text Conversion**: Converts any media type to searchable text
- **AI-Powered Descriptions**: Comprehensive image descriptions using vision models
- **Audio Transcription**: Speech-to-text conversion for audio content
- **Semantic Search**: Vector similarity search across all converted content
- **Cross-Modal Retrieval**: Search for images using text descriptions of their content
- **Content Quality Assessment**: Automatic scoring of converted content quality
- **Migration Support**: Tools to migrate from previous multi-modal architecture

## Table of Contents

- [Quick Start](#quick-start)
- [Unified Architecture Guide](#unified-architecture-guide)
- [Document Processing Pipeline](#document-processing-pipeline)
- [Cross-Modal Search](#cross-modal-search)
- [Migration from Multi-Modal](#migration-from-multi-modal)
- [API Overview](#api-overview)
- [Configuration](#configuration)
- [Installation](#installation)
- [Requirements](#requirements)
- [Performance Features](#performance-features)
- [Troubleshooting](#troubleshooting)

## Quick Start

```ruby
require 'ragdoll'

# Configure with unified text-based architecture
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

  # Enable unified text-based models
  config.use_unified_models = true

  # Text conversion settings
  config.text_conversion = {
    image_detail_level: :comprehensive,  # :minimal, :standard, :comprehensive, :analytical
    audio_transcription_provider: :openai,  # :azure, :google, :whisper_local
    enable_fallback_descriptions: true
  }

  # Single embedding model for all content
  config.embedding_model = "text-embedding-3-large"
  config.embedding_provider = :openai

  # Ruby LLM configuration
  config.ruby_llm_config[:openai][:api_key] = ENV['OPENAI_API_KEY']
end

# Add documents - all types converted to text
result = Ragdoll.add_document(path: 'research_paper.pdf')
image_result = Ragdoll.add_document(path: 'diagram.png')  # Converted to description
audio_result = Ragdoll.add_document(path: 'lecture.mp3')  # Converted to transcript

# Cross-modal search - find images by describing their content
results = Ragdoll.search(query: 'neural network architecture diagram')
# This can return the image document if its AI description mentions neural networks

# Search for audio content by transcript content
results = Ragdoll.search(query: 'machine learning discussion')
# Returns audio documents whose transcripts mention machine learning

# Check content quality
document = Ragdoll.get_document(id: result[:document_id])
puts document[:content_quality_score]  # 0.0 to 1.0 rating
```

## Unified Architecture Guide

### Document Processing Pipeline

The new unified pipeline converts all media types to searchable text:

```ruby
# Text files: Direct extraction
text_doc = Ragdoll.add_document(path: 'article.md')
# Content: Original markdown text

# PDF/DOCX: Text extraction
pdf_doc = Ragdoll.add_document(path: 'research.pdf')
# Content: Extracted text from all pages

# Images: AI-generated descriptions
image_doc = Ragdoll.add_document(path: 'chart.png')
# Content: "Bar chart showing quarterly sales data with increasing trend..."

# Audio: Speech-to-text transcription
audio_doc = Ragdoll.add_document(path: 'meeting.mp3')
# Content: "In this meeting we discussed the quarterly results..."

# Video: Audio transcription + metadata
video_doc = Ragdoll.add_document(path: 'presentation.mp4')
# Content: Combination of audio transcript and video metadata
```

### Text Conversion Services

```ruby
# Use individual conversion services
text_content = Ragdoll::TextExtractionService.extract('document.pdf')
image_description = Ragdoll::ImageToTextService.convert('photo.jpg', detail_level: :comprehensive)
audio_transcript = Ragdoll::AudioToTextService.transcribe('speech.wav')

# Use unified converter (orchestrates all services)
unified_text = Ragdoll::DocumentConverter.convert_to_text('any_file.ext')

# Manage documents with unified approach
management = Ragdoll::UnifiedDocumentManagement.new
document = management.add_document('mixed_media_file.mov')
```

### Content Quality Assessment

```ruby
# Get content quality scores
document = Ragdoll::UnifiedDocument.find(id)
quality = document.content_quality_score  # 0.0 to 1.0

# Quality factors:
# - Content length (50-2000 words optimal)
# - Original media type (text > documents > descriptions > placeholders)
# - Conversion success (full content > partial > fallback)

# Batch quality assessment
stats = Ragdoll::UnifiedContent.stats
puts stats[:content_quality_distribution]
# => { high: 150, medium: 75, low: 25 }
```

## Cross-Modal Search

The unified architecture enables powerful cross-modal search capabilities:

```ruby
# Find images by describing their visual content
image_results = Ragdoll.search(query: 'red sports car in parking lot')
# Returns image documents whose AI descriptions match the query

# Search for audio by spoken content
audio_results = Ragdoll.search(query: 'quarterly sales meeting discussion')
# Returns audio documents whose transcripts contain these topics

# Mixed results across all media types
all_results = Ragdoll.search(query: 'artificial intelligence')
# Returns text documents, images with AI descriptions, and audio transcripts
# all ranked by relevance to the query

# Filter by original media type while searching text
image_only = Ragdoll.search(
  query: 'machine learning workflow',
  original_media_type: 'image'
)

# Search with quality filtering
high_quality = Ragdoll.search(
  query: 'deep learning',
  min_quality_score: 0.7
)
```

## Migration from Multi-Modal

Migrate smoothly from the previous multi-modal architecture:

```ruby
# Check migration readiness
migration_service = Ragdoll::MigrationService.new
report = migration_service.create_comparison_report

puts "Migration Benefits:"
report[:benefits].each { |benefit, description| puts "- #{description}" }

# Migrate all documents
results = Ragdoll::MigrationService.migrate_all_documents(
  batch_size: 50,
  process_embeddings: true
)

puts "Migrated: #{results[:migrated]} documents"
puts "Errors: #{results[:errors].length}"

# Validate migration integrity
validation = migration_service.validate_migration
puts "Validation passed: #{validation[:passed]}/#{validation[:total_checks]} checks"

# Migrate individual document
migrated_doc = Ragdoll::MigrationService.migrate_document(old_document_id)
```

## API Overview

### Unified Document Management

```ruby
# Add documents with automatic text conversion
result = Ragdoll.add_document(path: 'any_file.ext')
puts result[:document_id]
puts result[:content_preview]  # First 100 characters of converted text

# Batch processing with unified pipeline
files = ['doc.pdf', 'image.jpg', 'audio.mp3']
results = Ragdoll::UnifiedDocumentManagement.new.batch_process_documents(files)

# Reprocess with different conversion settings
Ragdoll::UnifiedDocumentManagement.new.reprocess_document(
  document_id,
  image_detail_level: :analytical
)
```

### Search API

```ruby
# Unified search across all content types
results = Ragdoll.search(query: 'machine learning algorithms')

# Search with original media type context
results.each do |doc|
  puts "#{doc.title} (originally #{doc.original_media_type})"
  puts "Quality: #{doc.content_quality_score.round(2)}"
  puts "Content: #{doc.content[0..100]}..."
end

# Advanced search with content quality
high_quality_results = Ragdoll.search(
  query: 'neural networks',
  min_quality_score: 0.8,
  limit: 10
)
```

### Content Analysis

```ruby
# Analyze converted content
document = Ragdoll::UnifiedDocument.find(id)

# Check original media type
puts document.unified_contents.first.original_media_type  # 'image', 'audio', 'text', etc.

# View conversion metadata
content = document.unified_contents.first
puts content.conversion_method  # 'image_to_text', 'audio_transcription', etc.
puts content.metadata  # Conversion settings and results

# Quality metrics
puts content.word_count
puts content.character_count
puts content.content_quality_score
```

## Configuration

Ragdoll uses the `anyway_config` gem for flexible, layered configuration with XDG Base Directory support.

### Configuration Priority

Configuration is loaded from multiple sources (lowest to highest priority):

1. Bundled defaults (`lib/ragdoll/core/config/defaults.yml`)
2. XDG user config (`~/.config/ragdoll/ragdoll.yml`)
3. Project config (`./config/ragdoll.yml`)
4. Environment variables (`RAGDOLL_*`)
5. Programmatic (`Ragdoll.configure` block)

### Quick Start

```ruby
require 'ragdoll-core'

# Access configuration (automatically loaded)
config = Ragdoll.config

# Read values using method access
config.embedding.provider      # => :ollama
config.embedding.model         # => "nomic-embed-text:latest"
config.database.host           # => "localhost"
config.ollama_url              # => "http://localhost:11434"

# Environment helpers
config.development?            # => true/false
config.test?                   # => true/false
config.production?             # => true/false
```

### Configuration File

Create `~/.config/ragdoll/ragdoll.yml`:

```yaml
database:
  host: localhost
  port: 5432
  name: ragdoll_production

embedding:
  provider: openai
  model: text-embedding-3-small
  dimensions: 1536

chunking:
  size: 1000
  overlap: 200

search:
  similarity_threshold: 0.7
  max_results: 10

providers:
  openai:
    api_key: sk-...
  ollama:
    url: http://localhost:11434
```

### Environment Variables

Use the `RAGDOLL_` prefix with double underscores for nested keys:

```bash
# Database
export RAGDOLL_DATABASE__HOST=db.example.com
export RAGDOLL_DATABASE__NAME=ragdoll_production

# Embedding
export RAGDOLL_EMBEDDING__PROVIDER=openai
export RAGDOLL_EMBEDDING__MODEL=text-embedding-3-small

# Provider credentials
export RAGDOLL_PROVIDERS__OPENAI__API_KEY=sk-...
export RAGDOLL_PROVIDERS__OLLAMA__URL=http://localhost:11434

# Environment
export RAGDOLL_ENV=production
```

### Programmatic Configuration

```ruby
Ragdoll.configure do |config|
  # Override embedding settings
  config.embedding.provider = :openai
  config.embedding.model = "text-embedding-3-small"

  # Override database settings
  config.database.name = "my_ragdoll_db"

  # Provider credentials
  config.providers.openai.api_key = ENV['OPENAI_API_KEY']
end
```

See the [Configuration Guide](docs/docs/getting-started/configuration.md) for complete documentation.

## Performance Features

- **Unified Index**: Single text-based search index for all content types
- **Optimized Conversion**: Efficient text extraction and AI-powered description generation
- **Quality Scoring**: Automatic assessment of converted content quality
- **Batch Processing**: Efficient bulk document processing with progress tracking
- **Smart Caching**: Caches conversion results to avoid reprocessing
- **Background Jobs**: Asynchronous processing for large files
- **Cross-Modal Optimization**: Specialized optimizations for different media type conversions

## Installation

```bash
# Install system dependencies
brew install postgresql pgvector  # macOS
# or
apt-get install postgresql postgresql-contrib  # Ubuntu

# For image processing
brew install imagemagick

# For audio processing (optional, depending on provider)
brew install ffmpeg

# Install gem
gem install ragdoll

# Or add to Gemfile
gem 'ragdoll'
```

## Requirements

- **Ruby**: 3.2+
- **PostgreSQL**: 12+ with pgvector extension
- **ImageMagick**: For image processing and metadata extraction
- **FFmpeg**: Optional, for advanced audio/video processing
- **Dependencies**: activerecord, pg, pgvector, neighbor, ruby_llm, pdf-reader, docx, rmagick, tempfile

### Vision Model Requirements

For comprehensive image descriptions:
- **OpenAI**: GPT-4 Vision (recommended)
- **Google**: Gemini Pro Vision
- **Anthropic**: Claude 3 with vision capabilities
- **Local**: Ollama with vision-capable models

### Audio Transcription Requirements

- **OpenAI**: Whisper API (recommended)
- **Azure**: Speech Services
- **Google**: Cloud Speech-to-Text
- **Local**: Whisper installation

## Troubleshooting

### Image Processing Issues

```bash
# Verify ImageMagick installation
convert -version

# Check vision model access
irb -r ragdoll
> Ragdoll::ImageToTextService.new.convert('test_image.jpg')
```

### Audio Processing Issues

```bash
# For Whisper local installation
pip install openai-whisper

# Test audio file support
irb -r ragdoll
> Ragdoll::AudioToTextService.new.transcribe('test_audio.wav')
```

### Content Quality Issues

```ruby
# Check content quality distribution
stats = Ragdoll::UnifiedContent.stats
puts stats[:content_quality_distribution]

# Reprocess low-quality content
low_quality = Ragdoll::UnifiedDocument.joins(:unified_contents)
  .where('unified_contents.content_quality_score < 0.5')

low_quality.each do |doc|
  Ragdoll::UnifiedDocumentManagement.new.reprocess_document(
    doc.id,
    image_detail_level: :analytical
  )
end
```

## Use Cases

- **Knowledge Bases**: Search across text documents, presentation images, and recorded meetings
- **Media Libraries**: Find images by visual content, audio by spoken topics
- **Research Collections**: Unified search across papers (text), charts (images), and interviews (audio)
- **Documentation Systems**: Search technical docs, architecture diagrams, and explanation videos
- **Educational Content**: Find learning materials across all media types through unified text search

## Key Design Principles

1. **Unified Text Representation**: All media types converted to searchable text
2. **Cross-Modal Search**: Images findable through descriptions, audio through transcripts
3. **Quality-Driven**: Automatic assessment and optimization of converted content
4. **Simplified Architecture**: Single content model instead of complex polymorphic relationships
5. **AI-Enhanced Conversion**: Leverages latest vision and speech models for rich text conversion
6. **Migration-Friendly**: Smooth transition path from previous multi-modal architecture
7. **Performance-Optimized**: Single embedding model and unified search index for speed
