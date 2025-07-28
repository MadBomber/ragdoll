# Multi-Modal Architecture

Ragdoll's multi-modal architecture is one of its most sophisticated features, designed from the ground up to handle text, image, and audio content as first-class citizens through a polymorphic database design.

## Overview

Unlike most RAG systems that retrofit multi-modal support, Ragdoll implements a **native multi-modal architecture** where different content types are unified through polymorphic associations while maintaining specialized handling for each media type.

## Architecture Design

### Schema Optimization

Ragdoll uses an **optimized polymorphic schema** that eliminates field duplication while maintaining full functionality:

- **Embedding model information** is stored in the content-specific tables (text_contents, image_contents, audio_contents)
- **Embeddings table** contains only embedding-specific data (vector, content chunk, metadata)
- **Polymorphic relationships** provide seamless access to embedding model information
- **Zero data duplication** across the schema while preserving all functionality

This design provides better data normalization, reduced storage requirements, and maintains referential integrity across all content types.

### Polymorphic Content System

```ruby
# Unified embedding storage across all content types
Embedding.where(embeddable_type: 'TextContent')
Embedding.where(embeddable_type: 'ImageContent')
Embedding.where(embeddable_type: 'AudioContent')

# Access embedding model through polymorphic relationship
embedding = Embedding.find(123)
embedding.embedding_model  # Returns content-specific embedding model
# e.g., 'text-embedding-3-small', 'clip-vit-large-patch14', 'whisper-embedding-v1'

# Cross-modal search
results = SearchEngine.search_similar_content("machine learning diagram")
# Can return text, image, and audio results in a single query
```

### Database Schema

```sql
-- Central document entity
ragdoll_documents
├── file_data (Shrine attachment)
├── metadata (LLM-generated content analysis)
├── file_metadata (system file properties)
└── document_type (text/image/audio/pdf/mixed)

-- Content-specific tables (each stores embedding_model)
ragdoll_text_contents
├── document_id (foreign key)
├── content (extracted text)
├── chunk_size, chunk_overlap (processing parameters)
├── embedding_model (model used for this content type)
└── language_detected

ragdoll_image_contents
├── document_id (foreign key)
├── file_data (Shrine image attachment)
├── description (AI-generated description)
├── embedding_model (model used for this content type)
├── width, height (image dimensions)
└── alt_text

ragdoll_audio_contents
├── document_id (foreign key)
├── file_data (Shrine audio attachment)
├── transcript (speech-to-text result)
├── embedding_model (model used for this content type)
├── duration_seconds
└── language_detected

-- Polymorphic embeddings (normalized schema - no duplicated fields)
ragdoll_embeddings
├── embeddable_type (TextContent/ImageContent/AudioContent)
├── embeddable_id (references content table)
├── embedding_vector (pgvector)
├── content (original text/description/transcript chunk)
├── chunk_index (position within embeddable content)
└── metadata (embedding-specific data only)
```

## Content Type Support

### Text Content

**Fully Implemented** with comprehensive processing:

```ruby
# Supported formats
text_content = TextContent.create!(
  document: document,
  content: extracted_text,
  chunk_size: 1000,
  chunk_overlap: 200,
  embedding_model: 'text-embedding-3-small',
  language_detected: 'en'
)

# Automatic chunking and embedding generation
GenerateEmbeddingsJob.perform_later(text_content)
```

**Features:**
- ✅ Intelligent text chunking with boundary detection
- ✅ Language detection and encoding handling
- ✅ Configurable chunk size and overlap
- ✅ Sentence/paragraph boundary preservation
- ✅ Code-aware chunking for technical documents

### Image Content

**Fully Implemented** with AI-powered analysis:

```ruby
# Image processing with Shrine
image_content = ImageContent.create!(
  document: document,
  file: uploaded_file,  # Shrine attachment
  description: ai_generated_description,
  embedding_model: 'clip-vit-large-patch14',
  width: 1920,
  height: 1080,
  alt_text: "Machine learning workflow diagram"
)

# AI description generation
MetadataGeneratorService.generate_image_description(image_content)
```

**Features:**
- ✅ Shrine file attachment with validation
- ✅ AI-powered image description generation
- ✅ Metadata extraction (dimensions, format, size)
- ✅ Embedding generation from descriptions
- ✅ Cross-modal search (find images from text queries)

### Audio Content

**Fully Implemented** with transcription support:

```ruby
# Audio processing with transcription
audio_content = AudioContent.create!(
  document: document,
  file: uploaded_file,  # Shrine attachment
  transcript: speech_to_text_result,
  embedding_model: 'whisper-embedding-v1',
  duration_seconds: 125.5,
  language_detected: 'en'
)

# Transcription and embedding
ExtractTextJob.perform_later(audio_content)
GenerateEmbeddingsJob.perform_later(audio_content)
```

**Features:**
- ✅ Shrine file attachment with audio validation
- ✅ Speech-to-text transcription integration
- ✅ Duration and metadata extraction
- ✅ Language detection
- ✅ Embedding generation from transcripts
- ✅ Searchable by spoken content

## Cross-Modal Search

The unified embedding system enables sophisticated cross-modal search capabilities:

### Search Across All Content Types

```ruby
# Single query searches text, image descriptions, and audio transcripts
results = Ragdoll::Core.search(
  query: "neural network architecture",
  content_types: ['text', 'image', 'audio']  # optional filter
)

# Results include:
# - Text documents mentioning neural networks
# - Images with AI-generated descriptions about neural networks
# - Audio files with transcripts discussing neural networks
```

### Content-Type Specific Search

```ruby
# Search only images
image_results = Ragdoll::Core.search(
  query: "machine learning diagram",
  content_type: 'image'
)

# Search only audio transcripts
audio_results = Ragdoll::Core.search(
  query: "podcast about AI",
  content_type: 'audio'
)
```

### Advanced Multi-Modal Queries

```ruby
# Complex cross-modal search with metadata filters
results = Ragdoll::Core.search(
  query: "deep learning",
  content_types: ['text', 'image'],
  metadata_filters: {
    classification: 'technical',
    topics: ['artificial intelligence']
  },
  similarity_threshold: 0.8
)
```

## File Upload and Processing

### Shrine Integration

Each content type uses Shrine for production-grade file handling:

```ruby
# Configuration in shrine_config.rb
Shrine.configure do |config|
  config.storages = {
    cache: Shrine::Storage::FileSystem.new("tmp", prefix: "uploads/cache"),
    store: Shrine::Storage::FileSystem.new("storage", prefix: "uploads")
  }
end

# Automatic file validation by content type
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10.megabytes
    validate_mime_type %w[image/jpeg image/png image/gif image/webp]
  end
end
```

### Processing Pipeline

```ruby
# Multi-modal document processing
document = Document.create!(
  location: file_path,
  document_type: 'mixed'  # Can contain multiple content types
)

# Automatic content type detection and processing
DocumentProcessor.process(document) do |processor|
  case processor.detected_type
  when 'image'
    processor.create_image_content_with_description
  when 'audio'
    processor.create_audio_content_with_transcription
  when 'text'
    processor.create_text_content_with_chunking
  end
end
```

## Background Processing

All multi-modal operations are designed for background processing:

```ruby
# Jobs for each content type
GenerateEmbeddingsJob.perform_later(text_content)
GenerateEmbeddingsJob.perform_later(image_content)  # From description
GenerateEmbeddingsJob.perform_later(audio_content)  # From transcript

# Content analysis jobs
ExtractTextJob.perform_later(audio_content)         # Speech-to-text
GenerateSummaryJob.perform_later(text_content)      # Summarization
ExtractKeywordsJob.perform_later(image_content)     # Image analysis
```

## Usage Analytics

Multi-modal search includes sophisticated analytics:

```ruby
# Usage tracking across content types
embedding.update!(
  usage_count: embedding.usage_count + 1,
  returned_at: Time.current
)

# Analytics by content type
Document.joins(:embeddings)
        .where(embeddings: { embeddable_type: 'ImageContent' })
        .group(:document_type)
        .count

# Cross-modal performance metrics
SearchEngine.analytics_for_query("machine learning")
# Returns usage stats across text, image, and audio results
```

## API Examples

### Adding Multi-Modal Content

```ruby
# Mixed document with multiple content types
result = Ragdoll::Core.add_document(path: 'presentation.pptx')
# Automatically extracts:
# - Text from slides → TextContent
# - Images from slides → ImageContent
# - Speaker notes → TextContent

# Manual content addition
doc_id = Ragdoll::Core.add_document(path: 'research_paper.pdf')[:document_id]

# Add supplementary image
Ragdoll::Core.add_image(
  document_id: doc_id,
  image_path: 'diagram.png',
  description: 'Neural network architecture diagram'
)

# Add supplementary audio
Ragdoll::Core.add_audio(
  document_id: doc_id,
  audio_path: 'presentation.mp3',
  transcript: 'Today we discuss neural network architectures...'
)
```

### Searching Multi-Modal Content

```ruby
# Unified search across all content
results = Ragdoll::Core.search(query: 'convolutional neural networks')

results.each do |result|
  case result[:content_type]
  when 'text'
    puts "Text: #{result[:content]}"
  when 'image'
    puts "Image: #{result[:description]} (#{result[:file_url]})"
  when 'audio'
    puts "Audio: #{result[:transcript]} (#{result[:duration]}s)"
  end
end
```

## Performance Considerations

### Vector Storage Optimization

```sql
-- Polymorphic embeddings with optimized indexing
CREATE INDEX idx_embeddings_polymorphic_search
ON ragdoll_embeddings (embeddable_type, embedding_vector)
USING ivfflat (embedding_vector vector_cosine_ops);

-- Content-type specific indexes
CREATE INDEX idx_embeddings_text_usage
ON ragdoll_embeddings (embeddable_type, usage_count DESC)
WHERE embeddable_type = 'TextContent';
```

### Batch Processing

```ruby
# Efficient batch embedding generation
TextContent.where(embeddings_count: 0)
           .find_in_batches(batch_size: 100) do |batch|
  GenerateEmbeddingsJob.perform_later(batch.map(&:id))
end

# Cross-modal batch search
queries = ['AI research', 'neural networks', 'deep learning']
results = SearchEngine.batch_search(queries, content_types: ['text', 'image'])
```

## Extending Multi-Modal Support

### Adding New Content Types

```ruby
# 1. Create new content model
class VideoContent < ApplicationRecord
  belongs_to :document
  has_many :embeddings, as: :embeddable

  # Shrine attachment for video files
  include VideoUploader::Attachment(:file)
end

# 2. Add processing logic
class DocumentProcessor
  def process_video(video_file)
    # Extract frames, transcribe audio, analyze content
    VideoContent.create!(
      document: @document,
      file: video_file,
      transcript: extract_audio_transcript(video_file),
      frame_descriptions: extract_key_frames(video_file),
      duration_seconds: get_video_duration(video_file)
    )
  end
end

# 3. Add embedding generation
class GenerateEmbeddingsJob
  def perform_for_video(video_content)
    # Generate embeddings from transcript + frame descriptions
    combined_text = "#{video_content.transcript} #{video_content.frame_descriptions.join(' ')}"
    vector = EmbeddingService.generate_embedding(combined_text)

    video_content.embeddings.create!(
      embedding_vector: vector,
      content: combined_text,
      embedding_model: current_model
    )
  end
end
```

## Best Practices

### 1. Content Type Strategy
- Use appropriate content types for your data
- Consider mixed documents for complex files (PDFs, presentations)
- Leverage cross-modal search for comprehensive results

### 2. Performance Optimization
- Process large files in background jobs
- Use batch operations for multiple files
- Implement appropriate caching for frequently accessed content

### 3. Search Strategy
- Start with broad cross-modal searches
- Use content-type filters to narrow results
- Combine with metadata filters for precision

### 4. Storage Management
- Configure appropriate Shrine storage backends
- Implement file validation and size limits
- Plan for storage scaling in production

The multi-modal architecture in Ragdoll provides a powerful foundation for building sophisticated document intelligence applications that can understand and search across different types of content seamlessly.
