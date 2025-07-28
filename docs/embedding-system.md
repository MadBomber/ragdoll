# Embedding System

Ragdoll provides a sophisticated embedding system that transforms text, images, and audio content into high-dimensional vector representations for semantic search. The system leverages PostgreSQL's pgvector extension for efficient similarity search and supports multiple embedding models across different providers.

## Vector Generation and Similarity Search

The embedding system operates through a comprehensive pipeline that handles:

- **Multi-Modal Vector Generation**: Supports text, image, and audio content embedding
- **Provider Agnostic Architecture**: Works with OpenAI, Anthropic, Google, Azure, Ollama, and HuggingFace
- **PostgreSQL pgvector Integration**: High-performance vector storage and similarity search
- **Usage Analytics**: Tracks embedding usage for intelligent result ranking
- **Configurable Chunking**: Optimal content segmentation for embedding generation
- **Batch Processing**: Efficient bulk embedding generation with background jobs

## Embedding Models

Ragdoll supports a wide range of embedding models optimized for different content types:

### Text Embeddings

**OpenAI Models (Recommended)**
```ruby
config.embedding_config[:text][:model] = 'openai/text-embedding-3-large'  # 3072 dimensions
config.embedding_config[:text][:model] = 'openai/text-embedding-3-small'  # 1536 dimensions
config.embedding_config[:text][:model] = 'openai/text-embedding-ada-002'  # 1536 dimensions (legacy)
```

**Features:**
- High semantic accuracy for English and multilingual content
- Optimized for retrieval and similarity tasks
- Consistent performance across diverse document types
- Built-in rate limiting and error handling

**Azure OpenAI Embeddings**
```ruby
config.ruby_llm_config[:azure][:api_key] = ENV['AZURE_OPENAI_API_KEY']
config.ruby_llm_config[:azure][:endpoint] = ENV['AZURE_OPENAI_ENDPOINT']
config.embedding_config[:text][:model] = 'azure/text-embedding-ada-002'
```

**Google Vertex AI Embeddings**
```ruby
config.ruby_llm_config[:google][:api_key] = ENV['GOOGLE_API_KEY']
config.embedding_config[:text][:model] = 'google/textembedding-gecko@003'
config.embedding_config[:text][:model] = 'google/text-embedding-004'  # Latest model
```

**Local/Ollama Embeddings**
```ruby
config.ruby_llm_config[:ollama][:endpoint] = 'http://localhost:11434/v1'
config.embedding_config[:text][:model] = 'ollama/nomic-embed-text'      # 768 dimensions
config.embedding_config[:text][:model] = 'ollama/mxbai-embed-large'     # 1024 dimensions
config.embedding_config[:text][:model] = 'ollama/all-minilm'            # 384 dimensions
```

**Benefits of Local Models:**
- Complete data privacy and control
- No API rate limits or costs
- Custom model fine-tuning capabilities
- Offline operation support

**HuggingFace Models**
```ruby
config.ruby_llm_config[:huggingface][:api_key] = ENV['HUGGINGFACE_API_KEY']
config.embedding_config[:text][:model] = 'huggingface/sentence-transformers/all-MiniLM-L6-v2'
config.embedding_config[:text][:model] = 'huggingface/sentence-transformers/all-mpnet-base-v2'
```

### Image Embeddings (Planned)

**CLIP Models for Vision Understanding**
```ruby
# Future implementation
config.embedding_config[:image][:model] = 'openai/clip-vit-large-patch14'  # 768 dimensions
config.embedding_config[:image][:model] = 'openai/clip-vit-base-patch32'   # 512 dimensions
```

**Features (Planned):**
- Multi-modal understanding (image + text)
- Object detection and scene recognition
- Visual similarity search capabilities
- Integration with existing text embeddings

**Vision Transformer Models (Planned)**
```ruby
config.embedding_config[:image][:model] = 'google/vit-base-patch16-224'
config.embedding_config[:image][:model] = 'microsoft/resnet-50'
```

### Audio Embeddings (Planned)

**Whisper-Based Embeddings**
```ruby
# Future implementation
config.embedding_config[:audio][:model] = 'openai/whisper-embedding-v1'   # 1024 dimensions
config.embedding_config[:audio][:model] = 'openai/whisper-large-v3'       # 1280 dimensions
```

**Audio Feature Extraction (Planned)**
```ruby
config.embedding_config[:audio][:model] = 'facebook/wav2vec2-base-960h'
config.embedding_config[:audio][:model] = 'microsoft/speecht5_asr'
```

**Speech-to-Text Integration**
- Automatic transcription with embedding generation
- Speaker identification and segmentation
- Multi-language audio processing
- Timestamp-aware chunk embeddings

## Vector Storage

Ragdoll uses PostgreSQL with the pgvector extension for high-performance vector storage and similarity search:

### pgvector Integration for PostgreSQL

**Database Schema:**
```sql
CREATE TABLE ragdoll_embeddings (
  id BIGSERIAL PRIMARY KEY,
  embeddable_type VARCHAR NOT NULL,
  embeddable_id BIGINT NOT NULL,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  embedding_vector VECTOR(1536) NOT NULL,  -- Configurable dimensions
  usage_count INTEGER DEFAULT 0,
  returned_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

**Polymorphic Relationships:**
```ruby
# Embeddings belong to content via polymorphic association
belongs_to :embeddable, polymorphic: true

# Content types that can have embeddings:
# - Ragdoll::Core::Models::TextContent
# - Ragdoll::Core::Models::ImageContent  
# - Ragdoll::Core::Models::AudioContent
```

### Vector Dimensionality Handling

**Dynamic Dimension Support:**
```ruby
# Configure dimensions per model
config.embedding_config[:text].tap do |c|
  c[:model] = 'openai/text-embedding-3-large'
  c[:dimensions] = 3072  # OpenAI's large model
end

config.embedding_config[:text].tap do |c|
  c[:model] = 'openai/text-embedding-3-small' 
  c[:dimensions] = 1536  # OpenAI's small model
end
```

**Migration Support:**
```ruby
# Automatic schema migration for dimension changes
class UpdateEmbeddingDimensions < ActiveRecord::Migration[7.0]
  def up
    # Change vector dimensions when switching models
    execute "ALTER TABLE ragdoll_embeddings ALTER COLUMN embedding_vector TYPE vector(3072)"
    
    # Rebuild indexes with new dimensions
    execute "DROP INDEX IF EXISTS idx_embeddings_vector_cosine"
    execute "CREATE INDEX idx_embeddings_vector_cosine ON ragdoll_embeddings 
             USING ivfflat (embedding_vector vector_cosine_ops)"
  end
end
```

### Index Types (IVFFlat, HNSW)

**IVFFlat Index (Default)**
```sql
-- Inverted File Flat index for large datasets
CREATE INDEX idx_embeddings_vector_cosine ON ragdoll_embeddings 
USING ivfflat (embedding_vector vector_cosine_ops)
WITH (lists = 100);

-- L2 distance index alternative
CREATE INDEX idx_embeddings_vector_l2 ON ragdoll_embeddings 
USING ivfflat (embedding_vector vector_l2_ops)
WITH (lists = 100);
```

**HNSW Index (High Performance)**
```sql
-- Hierarchical Navigable Small World index for faster queries
CREATE INDEX idx_embeddings_vector_hnsw ON ragdoll_embeddings 
USING hnsw (embedding_vector vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

**Index Configuration:**
```ruby
config.vector_index_config.tap do |c|
  c[:type] = 'ivfflat'  # or 'hnsw'
  c[:lists] = 100       # IVFFlat parameter
  c[:m] = 16           # HNSW parameter
  c[:ef_construction] = 64  # HNSW parameter
  c[:distance_metric] = 'cosine'  # cosine, l2, inner_product
end
```

**Performance Comparison:**
| Index Type | Build Time | Query Speed | Memory Usage | Best For |
|------------|------------|-------------|--------------|----------|
| IVFFlat    | Fast       | Good        | Low          | Large datasets (>100K vectors) |
| HNSW       | Slow       | Excellent   | High         | Real-time queries (<100K vectors) |

### Storage Optimization

**Compression and Quantization:**
```ruby
config.vector_optimization.tap do |c|
  c[:enable_compression] = true
  c[:quantization_bits] = 8      # 8-bit quantization for space savings
  c[:normalize_vectors] = true   # L2 normalization for cosine similarity
  c[:remove_duplicates] = true   # Automatic deduplication
end
```

**Partitioning Strategy:**
```sql
-- Partition by embeddable_type for query optimization
CREATE TABLE ragdoll_embeddings_text 
PARTITION OF ragdoll_embeddings 
FOR VALUES IN ('Ragdoll::Core::Models::TextContent');

CREATE TABLE ragdoll_embeddings_image 
PARTITION OF ragdoll_embeddings 
FOR VALUES IN ('Ragdoll::Core::Models::ImageContent');
```

**Storage Monitoring:**
```ruby
# Monitor vector storage statistics
class VectorStorageStats
  def self.storage_summary
    {
      total_embeddings: Embedding.count,
      by_type: Embedding.group(:embeddable_type).count,
      by_dimensions: Embedding.joins(:embeddable).group('embedding_model').count,
      storage_size: estimate_storage_size,
      index_sizes: get_index_sizes,
      compression_ratio: calculate_compression_ratio
    }
  end
end
```

**Cleanup and Maintenance:**
```ruby
# Automated cleanup job
class VectorMaintenanceJob < ApplicationJob
  def perform
    # Remove orphaned embeddings
    Embedding.left_joins(:embeddable).where(embeddable: { id: nil }).delete_all
    
    # Rebuild indexes periodically
    if should_rebuild_indexes?
      rebuild_vector_indexes
    end
    
    # Update usage statistics
    update_vector_statistics
  end
end
```

## Similarity Search

Ragdoll implements advanced similarity search algorithms optimized for semantic retrieval:

### Cosine Similarity Calculation

**Primary Search Method:**
```ruby
# PostgreSQL pgvector cosine similarity
results = Embedding.search_similar(
  query_embedding,
  limit: 20,
  threshold: 0.7,
  filters: { document_type: 'pdf' }
)

# Ruby implementation for verification
def cosine_similarity(vec1, vec2)
  dot_product = vec1.zip(vec2).sum { |a, b| a * b }
  magnitude1 = Math.sqrt(vec1.sum { |a| a * a })
  magnitude2 = Math.sqrt(vec2.sum { |a| a * a })
  
  return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0
  
  dot_product / (magnitude1 * magnitude2)
end
```

**Optimized PostgreSQL Query:**
```sql
-- Using pgvector's cosine distance operator
SELECT 
  id,
  content,
  1 - (embedding_vector <=> $1::vector) AS similarity,
  embedding_vector <=> $1::vector AS distance
FROM ragdoll_embeddings
WHERE 1 - (embedding_vector <=> $1::vector) > $2  -- threshold
ORDER BY embedding_vector <=> $1::vector
LIMIT $3;
```

### Euclidean Distance Options

**L2 Distance Search:**
```ruby
# Configure L2 distance for geometric similarity
config.search_config.tap do |c|
  c[:distance_metric] = 'l2'  # or 'cosine', 'inner_product'
  c[:normalize_vectors] = false  # Don't normalize for L2
end

# Search using L2 distance
results = Embedding.search_with_distance(
  query_embedding,
  distance_metric: 'l2',
  max_distance: 0.5
)
```

**Distance Metrics Comparison:**
```ruby
class SimilarityMetrics
  def self.compare_metrics(query, candidates)
    results = {}
    
    candidates.each do |candidate|
      results[candidate.id] = {
        cosine: cosine_similarity(query, candidate.embedding_vector),
        l2: l2_distance(query, candidate.embedding_vector),
        inner_product: inner_product(query, candidate.embedding_vector)
      }
    end
    
    results
  end
end
```

### Hybrid Search Combining Multiple Metrics

**Multi-Score Ranking:**
```ruby
def self.hybrid_search(query_embedding, **options)
  # Get semantic similarity results
  semantic_results = search_similar(query_embedding, **options)
  
  # Enhance with additional ranking factors
  enhanced_results = semantic_results.map do |result|
    # Usage-based scoring
    usage_score = calculate_usage_score(result[:embedding_id])
    
    # Recency scoring
    recency_score = calculate_recency_score(result[:returned_at])
    
    # Content quality scoring
    quality_score = calculate_content_quality(result[:content])
    
    # Combined weighted score
    result[:combined_score] = (
      result[:similarity] * 0.6 +      # Semantic similarity
      usage_score * 0.2 +              # Usage frequency
      recency_score * 0.1 +            # Recency
      quality_score * 0.1              # Content quality
    )
    
    result
  end
  
  enhanced_results.sort_by { |r| -r[:combined_score] }
end
```

**Contextual Re-ranking:**
```ruby
# Re-rank results based on document context
def self.contextual_rerank(results, query_context)
  results.each do |result|
    # Document type preference
    doc_type_bonus = document_type_relevance(result[:document_type], query_context)
    
    # Content freshness
    freshness_bonus = content_freshness_score(result[:created_at])
    
    # Authority scoring (based on document metadata)
    authority_bonus = document_authority_score(result[:document_id])
    
    result[:final_score] = result[:combined_score] + 
                          doc_type_bonus + 
                          freshness_bonus + 
                          authority_bonus
  end
  
  results.sort_by { |r| -r[:final_score] }
end
```

### Performance Benchmarking

**Search Performance Metrics:**
```ruby
class SearchBenchmark
  def self.benchmark_search_performance
    query_embedding = generate_test_embedding
    
    # Benchmark different configurations
    results = {}
    
    # Test different limits
    [10, 50, 100, 500].each do |limit|
      time = Benchmark.realtime do
        Embedding.search_similar(query_embedding, limit: limit)
      end
      results["limit_#{limit}"] = time
    end
    
    # Test different thresholds
    [0.5, 0.7, 0.8, 0.9].each do |threshold|
      time = Benchmark.realtime do
        Embedding.search_similar(query_embedding, threshold: threshold)
      end
      results["threshold_#{threshold}"] = time
    end
    
    # Test index performance
    ['ivfflat', 'hnsw'].each do |index_type|
      time = benchmark_with_index(query_embedding, index_type)
      results["index_#{index_type}"] = time
    end
    
    results
  end
end
```

**Performance Optimization Strategies:**
```ruby
# Query optimization techniques
config.search_optimization.tap do |c|
  c[:enable_query_cache] = true
  c[:cache_similar_queries] = true
  c[:query_cache_ttL] = 300.seconds
  
  # Precompute popular embeddings
  c[:precompute_popular] = true
  c[:popularity_threshold] = 10  # usage_count > 10
  
  # Approximate search for large datasets
  c[:enable_approximate_search] = true
  c[:approximation_factor] = 0.95  # 95% accuracy for speed
end
```

**Query Performance Monitoring:**
```ruby
# Monitor search performance in production
class SearchPerformanceMonitor
  def self.track_query(query_embedding, options = {})
    start_time = Time.current
    
    begin
      results = Embedding.search_similar(query_embedding, **options)
      duration = Time.current - start_time
      
      # Log performance metrics
      Rails.logger.info {
        "Search Performance: #{duration}s, " +
        "results: #{results.length}, " +
        "limit: #{options[:limit]}, " +
        "threshold: #{options[:threshold]}"
      }
      
      # Send to monitoring service
      StatsD.histogram('search.duration', duration * 1000)
      StatsD.increment('search.queries')
      StatsD.histogram('search.results', results.length)
      
      results
    rescue => e
      StatsD.increment('search.errors')
      raise
    end
  end
end
```

## Chunking Strategy

Ragdoll implements intelligent text chunking to optimize embedding generation and search relevance:

### Configurable Chunk Sizes

**Token-Based Chunking:**
```ruby
config.chunking[:text].tap do |c|
  c[:max_tokens] = 1000        # Maximum tokens per chunk
  c[:min_tokens] = 100         # Minimum viable chunk size
  c[:target_tokens] = 800      # Preferred chunk size
  c[:overlap] = 200            # Token overlap between chunks
end

# Model-specific optimizations
config.chunking[:models] = {
  'openai/text-embedding-3-large' => {
    max_tokens: 8000,    # Large context window
    optimal_size: 1500
  },
  'openai/text-embedding-3-small' => {
    max_tokens: 8000,
    optimal_size: 1000
  },
  'ollama/nomic-embed-text' => {
    max_tokens: 2048,    # Smaller local model
    optimal_size: 512
  }
}
```

**Character-Based Fallback:**
```ruby
# When token counting is unavailable
config.chunking[:character_fallback].tap do |c|
  c[:max_chars] = 4000         # ~1000 tokens
  c[:min_chars] = 400          # ~100 tokens
  c[:overlap_chars] = 800      # ~200 tokens
end
```

### Overlap Strategies

**Sliding Window Overlap:**
```ruby
class TextChunker
  def chunk_with_sliding_window(text, chunk_size: 1000, overlap: 200)
    chunks = []
    tokens = tokenize(text)
    
    start_pos = 0
    while start_pos < tokens.length
      end_pos = start_pos + chunk_size
      chunk_tokens = tokens[start_pos...end_pos]
      
      # Ensure minimum chunk size
      break if chunk_tokens.length < config.chunking[:text][:min_tokens]
      
      chunks << {
        content: detokenize(chunk_tokens),
        start_token: start_pos,
        end_token: end_pos,
        index: chunks.length
      }
      
      # Move window with overlap
      start_pos += chunk_size - overlap
    end
    
    chunks
  end
end
```

**Semantic Boundary Preservation:**
```ruby
# Respect sentence and paragraph boundaries
def chunk_with_boundaries(text, **options)
  sentences = split_into_sentences(text)
  paragraphs = group_into_paragraphs(sentences)
  
  chunks = []
  current_chunk = []
  current_size = 0
  
  paragraphs.each do |paragraph|
    paragraph_size = estimate_tokens(paragraph.join(' '))
    
    # If paragraph fits in current chunk
    if current_size + paragraph_size <= options[:max_tokens]
      current_chunk.concat(paragraph)
      current_size += paragraph_size
    else
      # Finalize current chunk if not empty
      if current_chunk.any?
        chunks << create_chunk(current_chunk, chunks.length)
      end
      
      # Start new chunk with current paragraph
      current_chunk = paragraph
      current_size = paragraph_size
    end
  end
  
  # Add final chunk
  chunks << create_chunk(current_chunk, chunks.length) if current_chunk.any?
  
  chunks
end
```

### Content-Aware Chunking

**Document Structure Recognition:**
```ruby
class StructuralChunker
  def chunk_by_structure(text, document_type:)
    case document_type
    when 'markdown'
      chunk_markdown_by_headers(text)
    when 'code'
      chunk_code_by_functions(text)
    when 'academic'
      chunk_academic_by_sections(text)
    when 'legal'
      chunk_legal_by_clauses(text)
    else
      chunk_generic_by_paragraphs(text)
    end
  end
  
  private
  
  def chunk_markdown_by_headers(text)
    sections = text.split(/^#{1,6}\s+/)
    
    sections.map.with_index do |section, index|
      {
        content: section.strip,
        type: 'markdown_section',
        header_level: detect_header_level(section),
        index: index
      }
    end
  end
  
  def chunk_code_by_functions(text)
    # Language-specific function extraction
    functions = extract_functions(text)
    
    functions.map.with_index do |func, index|
      {
        content: func[:code],
        type: 'code_function',
        function_name: func[:name],
        language: func[:language],
        index: index
      }
    end
  end
end
```

**Context Preservation:**
```ruby
# Maintain context across chunk boundaries
def enhance_chunks_with_context(chunks, text)
  enhanced_chunks = []
  
  chunks.each_with_index do |chunk, index|
    enhanced_chunk = chunk.dup
    
    # Add previous context for continuity
    if index > 0
      prev_chunk = chunks[index - 1]
      context_size = [prev_chunk[:content].length, 200].min
      enhanced_chunk[:prev_context] = prev_chunk[:content][-context_size..-1]
    end
    
    # Add next context for completeness
    if index < chunks.length - 1
      next_chunk = chunks[index + 1]
      context_size = [next_chunk[:content].length, 200].min
      enhanced_chunk[:next_context] = next_chunk[:content][0...context_size]
    end
    
    # Add document-level context
    enhanced_chunk[:document_context] = extract_document_context(text)
    
    enhanced_chunks << enhanced_chunk
  end
  
  enhanced_chunks
end
```

### Multi-Modal Content Handling

**Image Content Chunking:**
```ruby
class ImageContentChunker
  def chunk_image_content(image_content)
    # Image descriptions are typically single chunks
    [{
      content: image_content.content,  # AI-generated description
      type: 'image_description',
      metadata: {
        dimensions: "#{image_content.metadata['width']}x#{image_content.metadata['height']}",
        file_size: image_content.metadata['file_size'],
        format: image_content.metadata['file_type']
      },
      index: 0
    }]
  end
end
```

**Audio Content Chunking (Planned):**
```ruby
class AudioContentChunker
  def chunk_audio_transcript(audio_content, chunk_duration: 30.seconds)
    transcript = audio_content.content  # Full transcript
    timestamps = audio_content.metadata['timestamps'] || []
    
    chunks = []
    current_chunk = []
    chunk_start_time = 0
    
    timestamps.each do |timestamp|
      if timestamp[:time] - chunk_start_time >= chunk_duration
        if current_chunk.any?
          chunks << create_audio_chunk(
            current_chunk, 
            chunk_start_time, 
            timestamp[:time],
            chunks.length
          )
        end
        
        current_chunk = [timestamp]
        chunk_start_time = timestamp[:time]
      else
        current_chunk << timestamp
      end
    end
    
    # Add final chunk
    if current_chunk.any?
      chunks << create_audio_chunk(
        current_chunk,
        chunk_start_time,
        timestamps.last[:time],
        chunks.length
      )
    end
    
    chunks
  end
end
```

**Cross-Modal Context:**
```ruby
# Maintain context across different content types in multi-modal documents
class MultiModalChunker
  def chunk_mixed_content(document)
    all_chunks = []
    
    # Process each content type
    document.text_contents.each do |text_content|
      text_chunks = TextChunker.new.chunk(text_content.content)
      text_chunks.each { |chunk| chunk[:content_type] = 'text' }
      all_chunks.concat(text_chunks)
    end
    
    document.image_contents.each do |image_content|
      image_chunks = ImageContentChunker.new.chunk_image_content(image_content)
      image_chunks.each { |chunk| chunk[:content_type] = 'image' }
      all_chunks.concat(image_chunks)
    end
    
    # Sort by creation order to maintain document flow
    all_chunks.sort_by! { |chunk| [chunk[:content_type], chunk[:index]] }
    
    # Add cross-modal references
    enhance_with_cross_modal_context(all_chunks)
  end
end
```

## Usage Analytics

Ragdoll tracks embedding usage to optimize search results and system performance:

### Usage Frequency Tracking

**Automatic Usage Recording:**
```ruby
# Every search result interaction is tracked
def self.search_similar(query_embedding, **options)
  results = perform_vector_search(query_embedding, **options)
  
  # Mark embeddings as used (batch update for performance)
  embedding_ids = results.map { |r| r[:embedding_id] }
  mark_embeddings_as_used(embedding_ids)
  
  results
end

# Batch update for performance
def self.mark_embeddings_as_used(embedding_ids)
  where(id: embedding_ids).update_all(
    usage_count: arel_table[:usage_count] + 1,
    returned_at: Time.current,
    updated_at: Time.current
  )
end
```

**Usage-Based Scoring:**
```ruby
def self.calculate_usage_score(embedding)
  return 0.0 unless embedding.usage_count > 0
  
  # Frequency component (logarithmic scaling)
  frequency_score = Math.log(embedding.usage_count + 1) / Math.log(100)
  frequency_score = [frequency_score, 1.0].min  # Cap at 1.0
  
  # Recency component (exponential decay)
  if embedding.returned_at
    days_since_use = (Time.current - embedding.returned_at) / 1.day
    recency_score = Math.exp(-days_since_use / 30)  # 30-day half-life
  else
    recency_score = 0.0
  end
  
  # Weighted combination
  frequency_weight = 0.7
  recency_weight = 0.3
  
  frequency_weight * frequency_score + recency_weight * recency_score
end
```

### Recency-Based Ranking

**Time-Aware Search Results:**
```ruby
def self.search_with_recency_boost(query_embedding, **options)
  base_results = search_similar(query_embedding, **options)
  
  base_results.map do |result|
    # Calculate recency boost
    recency_boost = calculate_recency_boost(result[:returned_at])
    
    # Apply boost to similarity score
    result[:boosted_similarity] = result[:similarity] + recency_boost
    result[:recency_boost] = recency_boost
    
    result
  end.sort_by { |r| -r[:boosted_similarity] }
end

def self.calculate_recency_boost(last_used_at)
  return 0.0 unless last_used_at
  
  hours_since_use = (Time.current - last_used_at) / 1.hour
  
  case hours_since_use
  when 0..1    then 0.10   # Very recent: significant boost
  when 1..6    then 0.05   # Recent: moderate boost
  when 6..24   then 0.02   # Same day: small boost
  when 24..168 then 0.01   # Same week: minimal boost
  else 0.0                 # Older: no boost
  end
end
```

**Trending Content Detection:**
```ruby
class TrendingAnalyzer
  def self.detect_trending_embeddings(time_window: 24.hours)
    recent_usage = Embedding
      .where(returned_at: time_window.ago..Time.current)
      .group(:id)
      .having('COUNT(*) > ?', 5)  # Minimum usage threshold
      .order('COUNT(*) DESC')
      .limit(100)
    
    trending_scores = recent_usage.map do |embedding|
      {
        embedding_id: embedding.id,
        recent_usage: embedding.usage_count,
        velocity: calculate_usage_velocity(embedding),
        trending_score: calculate_trending_score(embedding)
      }
    end
    
    trending_scores.sort_by { |t| -t[:trending_score] }
  end
end
```

### Performance Metrics

**Search Quality Metrics:**
```ruby
class SearchQualityMetrics
  def self.calculate_metrics(time_period: 7.days)
    searches = SearchLog.where(created_at: time_period.ago..Time.current)
    
    {
      # Query performance
      avg_query_time: searches.average(:duration),
      median_query_time: searches.median(:duration),
      p95_query_time: searches.percentile(:duration, 95),
      
      # Result quality
      avg_similarity_score: searches.average(:avg_similarity),
      results_per_query: searches.average(:result_count),
      
      # User engagement
      click_through_rate: calculate_ctr(searches),
      zero_result_rate: searches.where(result_count: 0).count.to_f / searches.count,
      
      # System health
      error_rate: searches.where.not(error: nil).count.to_f / searches.count,
      cache_hit_rate: searches.where(cache_hit: true).count.to_f / searches.count
    }
  end
end
```

**Embedding Quality Assessment:**
```ruby
class EmbeddingQualityAssessment
  def self.assess_embedding_quality(embedding)
    {
      # Usage-based quality indicators
      usage_score: embedding.usage_count > 0 ? Math.log(embedding.usage_count + 1) : 0,
      recency_score: calculate_recency_score(embedding.returned_at),
      
      # Content-based quality indicators
      content_length: embedding.content.length,
      content_complexity: calculate_content_complexity(embedding.content),
      
      # Vector quality indicators
      vector_magnitude: calculate_vector_magnitude(embedding.embedding_vector),
      vector_uniqueness: calculate_vector_uniqueness(embedding),
      
      # Overall quality score
      overall_quality: calculate_overall_quality(embedding)
    }
  end
end
```

### Search Analytics Integration

**Comprehensive Search Logging:**
```ruby
class SearchAnalytics
  def self.log_search(query, results, metadata = {})
    SearchLog.create!(
      query_hash: Digest::SHA256.hexdigest(query.to_s),
      query_embedding_model: metadata[:embedding_model],
      result_count: results.length,
      avg_similarity: results.map { |r| r[:similarity] }.sum / results.length,
      max_similarity: results.map { |r| r[:similarity] }.max,
      min_similarity: results.map { |r| r[:similarity] }.min,
      duration: metadata[:duration],
      filters_applied: metadata[:filters]&.keys || [],
      cache_hit: metadata[:cache_hit] || false,
      user_id: metadata[:user_id],
      session_id: metadata[:session_id],
      created_at: Time.current
    )
  end
end
```

**Real-time Analytics Dashboard:**
```ruby
class AnalyticsDashboard
  def self.realtime_stats
    {
      current_searches_per_minute: current_search_rate,
      active_embeddings: Embedding.where(returned_at: 1.hour.ago..Time.current).count,
      top_queries: top_queries_last_hour,
      search_performance: {
        avg_duration: recent_searches.average(:duration),
        success_rate: calculate_success_rate,
        error_rate: calculate_error_rate
      },
      embedding_stats: {
        total_embeddings: Embedding.count,
        embeddings_created_today: Embedding.where(created_at: Date.current.beginning_of_day..Time.current).count,
        most_used_models: Embedding.joins(:embeddable).group('embedding_model').count
      }
    }
  end
end
```

**Predictive Analytics:**
```ruby
class PredictiveAnalytics
  def self.predict_popular_content(lookahead: 7.days)
    # Analyze usage patterns to predict trending content
    historical_data = gather_historical_usage_data
    
    predictions = historical_data.map do |embedding_data|
      {
        embedding_id: embedding_data[:id],
        current_usage: embedding_data[:usage_count],
        predicted_usage: predict_future_usage(embedding_data, lookahead),
        confidence: calculate_prediction_confidence(embedding_data),
        trending_probability: calculate_trending_probability(embedding_data)
      }
    end
    
    predictions.sort_by { |p| -p[:predicted_usage] }
  end
end
```

## Configuration

Ragdoll provides comprehensive configuration options for embedding generation and search:

### Model Selection Per Content Type

**Content-Type Specific Models:**
```ruby
Ragdoll::Core.configure do |config|
  # Text content embeddings
  config.embedding_config[:text].tap do |c|
    c[:model] = 'openai/text-embedding-3-large'
    c[:dimensions] = 3072
    c[:batch_size] = 100
    c[:max_tokens] = 8000
  end
  
  # Image content embeddings (planned)
  config.embedding_config[:image].tap do |c|
    c[:model] = 'openai/clip-vit-large-patch14'
    c[:dimensions] = 768
    c[:batch_size] = 32
    c[:preprocessing] = true
  end
  
  # Audio content embeddings (planned)
  config.embedding_config[:audio].tap do |c|
    c[:model] = 'openai/whisper-embedding-v1'
    c[:dimensions] = 1024
    c[:batch_size] = 16
    c[:chunk_duration] = 30.seconds
  end
end
```

**Model Performance Profiles:**
```ruby
# Define performance characteristics for different models
config.model_profiles = {
  'openai/text-embedding-3-large' => {
    quality: 'high',
    speed: 'medium',
    cost: 'high',
    max_tokens: 8192,
    optimal_chunk_size: 1500,
    recommended_for: ['technical_docs', 'academic_papers', 'complex_content']
  },
  'openai/text-embedding-3-small' => {
    quality: 'good',
    speed: 'fast',
    cost: 'low',
    max_tokens: 8192,
    optimal_chunk_size: 1000,
    recommended_for: ['general_content', 'chat_messages', 'simple_docs']
  },
  'ollama/nomic-embed-text' => {
    quality: 'medium',
    speed: 'very_fast',
    cost: 'free',
    max_tokens: 2048,
    optimal_chunk_size: 512,
    recommended_for: ['privacy_sensitive', 'offline_processing', 'development']
  }
}
```

### Dimension Limits and Optimization

**Dynamic Dimension Handling:**
```ruby
config.vector_optimization.tap do |c|
  # Dimension limits per model
  c[:max_dimensions] = {
    'openai/text-embedding-3-large' => 3072,
    'openai/text-embedding-3-small' => 1536,
    'ollama/nomic-embed-text' => 768
  }
  
  # Dimension reduction options
  c[:enable_dimension_reduction] = false
  c[:target_dimensions] = 512  # Reduce to this if enabled
  c[:reduction_method] = 'pca'  # 'pca', 'truncate', 'quantize'
  
  # Vector normalization
  c[:normalize_vectors] = true
  c[:normalization_method] = 'l2'  # 'l2', 'unit', 'minmax'
end
```

**Storage Optimization:**
```ruby
config.storage_optimization.tap do |c|
  # Vector compression
  c[:enable_compression] = false  # Experimental
  c[:compression_ratio] = 0.8
  c[:compression_algorithm] = 'quantization'
  
  # Index optimization
  c[:index_type] = 'ivfflat'  # 'ivfflat', 'hnsw'
  c[:index_parameters] = {
    ivfflat: { lists: 100 },
    hnsw: { m: 16, ef_construction: 64 }
  }
  
  # Cleanup settings
  c[:cleanup_orphaned_embeddings] = true
  c[:cleanup_interval] = 1.day
  c[:max_embedding_age] = 90.days
end
```

### Batch Processing Settings

**Batch Configuration:**
```ruby
config.batch_processing.tap do |c|
  # Batch sizes per provider
  c[:batch_sizes] = {
    openai: 100,      # OpenAI can handle large batches efficiently
    anthropic: 50,    # Conservative batch size
    google: 75,       # Good balance for Google models
    ollama: 25,       # Local processing, smaller batches
    huggingface: 32   # Variable based on model size
  }
  
  # Batch processing timeouts
  c[:batch_timeout] = 300.seconds
  c[:retry_failed_batches] = true
  c[:max_retry_attempts] = 3
  
  # Queue management
  c[:max_queue_size] = 1000
  c[:queue_priority] = 'high'  # 'high', 'medium', 'low'
  c[:parallel_batches] = 2     # Number of concurrent batch jobs
end
```

**Background Job Configuration:**
```ruby
config.embedding_jobs.tap do |c|
  c[:queue_name] = 'embeddings'
  c[:job_timeout] = 600.seconds
  c[:retry_on_failure] = true
  
  # Job scheduling
  c[:immediate_processing] = false  # Set to true for real-time embedding
  c[:batch_delay] = 30.seconds      # Wait time before processing batch
  c[:priority_processing] = true    # Process high-priority content first
end
```

### Caching Strategies

**Multi-Level Caching:**
```ruby
config.caching.tap do |c|
  # Query result caching
  c[:enable_query_cache] = true
  c[:query_cache_ttl] = 300.seconds
  c[:query_cache_size] = 1000  # Number of cached queries
  
  # Embedding caching
  c[:enable_embedding_cache] = true
  c[:embedding_cache_ttl] = 1.hour
  c[:cache_negative_results] = false  # Don't cache failures
  
  # Vector similarity caching
  c[:enable_similarity_cache] = true
  c[:similarity_cache_ttl] = 15.minutes
  c[:cache_threshold] = 0.95  # Only cache high-similarity results
end
```

**Cache Implementation:**
```ruby
class EmbeddingCache
  def self.cached_search(query_embedding, **options)
    cache_key = generate_cache_key(query_embedding, options)
    
    # Try to get from cache first
    cached_result = Rails.cache.read(cache_key)
    return cached_result if cached_result
    
    # Perform actual search
    results = Embedding.search_similar(query_embedding, **options)
    
    # Cache the results
    Rails.cache.write(
      cache_key, 
      results, 
      expires_in: Ragdoll.config.caching[:query_cache_ttl]
    )
    
    results
  end
  
  private
  
  def self.generate_cache_key(query_embedding, options)
    # Create a stable hash of the query and options
    embedding_hash = Digest::SHA256.hexdigest(query_embedding.to_s)
    options_hash = Digest::SHA256.hexdigest(options.to_s)
    
    "embedding_search:#{embedding_hash}:#{options_hash}"
  end
end
```

**Performance Monitoring:**
```ruby
config.performance_monitoring.tap do |c|
  c[:enable_metrics] = true
  c[:metrics_interval] = 60.seconds
  
  # Metrics to track
  c[:track_query_performance] = true
  c[:track_embedding_generation] = true
  c[:track_cache_hit_rates] = true
  c[:track_model_usage] = true
  
  # Alerting thresholds
  c[:slow_query_threshold] = 5.seconds
  c[:low_cache_hit_threshold] = 0.3  # 30%
  c[:high_error_rate_threshold] = 0.05  # 5%
end
```

**Environment-Specific Configuration:**
```ruby
# Development configuration
if Rails.env.development?
  config.embedding_config[:text][:model] = 'openai/text-embedding-3-small'  # Faster, cheaper
  config.batch_processing[:batch_sizes][:openai] = 10  # Smaller batches
  config.caching[:enable_query_cache] = false  # Disable caching for testing
end

# Production configuration
if Rails.env.production?
  config.embedding_config[:text][:model] = 'openai/text-embedding-3-large'  # Best quality
  config.batch_processing[:parallel_batches] = 4  # More concurrent processing
  config.caching[:enable_query_cache] = true  # Enable all caching
  config.performance_monitoring[:enable_metrics] = true  # Full monitoring
end

# Test configuration
if Rails.env.test?
  config.embedding_config[:text][:model] = 'test/mock-embedding-model'
  config.batch_processing[:immediate_processing] = true  # Synchronous for tests
  config.caching[:enable_query_cache] = false  # Predictable test results
end
```

---

*This document is part of the Ragdoll documentation suite. For immediate help, see the [Quick Start Guide](quick-start.md) or [API Reference](api-client.md).*