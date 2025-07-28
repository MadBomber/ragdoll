# Search & Analytics

Ragdoll implements a sophisticated search and analytics system that goes far beyond basic semantic similarity. The system combines vector search with usage analytics, full-text search capabilities, and intelligent ranking algorithms to provide enterprise-grade search functionality.

## Overview

The search system consists of several integrated components:

- **Semantic Search**: pgvector-powered similarity search with cosine distance
- **Usage Analytics**: Frequency and recency-based ranking algorithms
- **Full-Text Search**: PostgreSQL GIN indexes with tsquery support
- **Cross-Modal Search**: Unified search across text, image, and audio content
- **Hybrid Search**: Combining semantic and full-text search with keyword extraction
- **Keyword Extraction**: Intelligent keyword extraction for enhanced search relevance
- **Smart Ranking**: Usage patterns, similarity scores, and metadata weighting

## Architecture

### SearchEngine Core

```ruby
class SearchEngine
  def search_similar_content(query, options = {})
    # 1. Generate query embedding
    query_vector = EmbeddingService.generate_embedding(query)
    
    # 2. Perform vector similarity search
    similar_embeddings = find_similar_embeddings(
      query_vector, 
      options[:similarity_threshold] || Configuration.search_similarity_threshold,
      options[:limit] || Configuration.max_search_results
    )
    
    # 3. Apply usage-based ranking
    ranked_results = apply_usage_ranking(similar_embeddings, options)
    
    # 4. Enhance with metadata and formatting
    format_search_results(ranked_results, options)
  end
end
```

### Database Optimization

```sql
-- Optimized pgvector indexes for fast similarity search
CREATE INDEX idx_embeddings_vector_cosine 
ON ragdoll_embeddings 
USING ivfflat (embedding_vector vector_cosine_ops) 
WITH (lists = 100);

-- Usage analytics indexes
CREATE INDEX idx_embeddings_usage_analytics 
ON ragdoll_embeddings (usage_count DESC, returned_at DESC);

-- Polymorphic content type indexes
CREATE INDEX idx_embeddings_content_type 
ON ragdoll_embeddings (embeddable_type, embeddable_id);

-- Full-text search indexes
CREATE INDEX idx_embeddings_content_fulltext 
ON ragdoll_embeddings 
USING GIN (to_tsvector('english', content));
```

## Semantic Search

### Vector Similarity Search

```ruby
# Core similarity search implementation
def find_similar_embeddings(query_vector, threshold, limit)
  Embedding.select(
    "*, " \
    "embedding_vector <=> '#{query_vector}' as distance, " \
    "1 - (embedding_vector <=> '#{query_vector}') as similarity"
  )
  .where("1 - (embedding_vector <=> '#{query_vector}') >= ?", threshold)
  .order("embedding_vector <=> '#{query_vector}'")
  .limit(limit)
end

# Usage example
results = SearchEngine.search_similar_content(
  "machine learning algorithms",
  similarity_threshold: 0.8,
  limit: 20
)
```

### Multi-Modal Search

```ruby
# Search across all content types
def cross_modal_search(query, content_types: nil)
  base_query = Embedding.joins(:embeddable)
  
  if content_types.present?
    base_query = base_query.where(embeddable_type: content_types.map(&:classify))
  end
  
  # Generate embeddings and search
  query_vector = EmbeddingService.generate_embedding(query)
  
  base_query.select(
    "ragdoll_embeddings.*, " \
    "embedding_vector <=> '#{query_vector}' as distance, " \
    "embeddable_type as content_type"
  )
  .where("1 - (embedding_vector <=> '#{query_vector}') >= ?", similarity_threshold)
  .order("embedding_vector <=> '#{query_vector}'")
end

# Search specific content types
text_results = SearchEngine.search_similar_content(
  "neural networks",
  content_types: ['text']
)

image_results = SearchEngine.search_similar_content(
  "architecture diagram", 
  content_types: ['image']
)

# Combined cross-modal search
all_results = SearchEngine.search_similar_content(
  "deep learning concepts",
  content_types: ['text', 'image', 'audio']
)
```

## Hybrid Search

Ragdoll's hybrid search combines semantic vector search with keyword-based full-text search to provide more comprehensive and relevant results.

### Architecture

```ruby
# High-level hybrid search interface
results = Ragdoll::Core.hybrid_search(
  query: "neural networks and deep learning",
  semantic_weight: 0.7,    # Weight for vector similarity (0.0 - 1.0)
  text_weight: 0.3,        # Weight for full-text search (0.0 - 1.0)
  limit: 20
)
```

### How Hybrid Search Works

1. **Query Processing**: The input query is processed through both semantic and lexical pipelines
2. **Keyword Extraction**: Keywords are extracted from the query using `extract_keywords`
3. **Semantic Search**: Vector embeddings are generated and similarity search is performed
4. **Full-Text Search**: PostgreSQL full-text search using GIN indexes
5. **Result Combination**: Results are merged with configurable weighting
6. **Ranking**: Combined scores determine final result ordering

### Implementation Details

```ruby
class Document < ActiveRecord::Base
  # Extract keywords from query string (words > 4 characters)
  def self.extract_keywords(query:)
    return [] if query.nil? || query.strip.empty?
    
    query.split(/\s+/)
         .map(&:strip)
         .reject(&:empty?)
         .select { |word| word.length > 4 }
  end

  # Hybrid search combining semantic and full-text approaches
  def self.hybrid_search(query, query_embedding: nil, **options)
    limit = options[:limit] || 20
    semantic_weight = options[:semantic_weight] || 0.7
    text_weight = options[:text_weight] || 0.3
    
    results = []
    
    # Get semantic search results if embedding provided
    if query_embedding
      semantic_results = embeddings_search(query_embedding, limit: limit)
      results.concat(semantic_results.map do |result|
        result.merge(
          search_type: 'semantic',
          weighted_score: result[:combined_score] * semantic_weight
        )
      end)
    end
    
    # Get PostgreSQL full-text search results
    text_results = search_content(query, limit: limit)
    text_results.each_with_index do |doc, index|
      score = (limit - index).to_f / limit * text_weight
      results << {
        document_id: doc.id.to_s,
        document_title: doc.title,
        content: doc.content[0..500],
        search_type: 'full_text',
        weighted_score: score,
        document: doc
      }
    end
    
    # Combine and deduplicate by document_id
    combined = results.group_by { |r| r[:document_id] }
                      .map do |_doc_id, doc_results|
      best_result = doc_results.max_by { |r| r[:weighted_score] }
      total_score = doc_results.sum { |r| r[:weighted_score] }
      search_types = doc_results.map { |r| r[:search_type] }.uniq
      
      best_result.merge(
        combined_score: total_score,
        search_types: search_types
      )
    end
    
    combined.sort_by { |r| -r[:combined_score] }.take(limit)
  end
end
```

### Usage Examples

```ruby
# Basic hybrid search
results = client.hybrid_search(
  query: "machine learning algorithms for text processing"
)

# Emphasize semantic similarity
results = client.hybrid_search(
  query: "neural network architectures",
  semantic_weight: 0.8,
  text_weight: 0.2
)

# Emphasize keyword matching
results = client.hybrid_search(
  query: "specific technical term",
  semantic_weight: 0.3,
  text_weight: 0.7
)

# Large result set for comprehensive analysis
results = client.hybrid_search(
  query: "artificial intelligence research",
  limit: 50,
  semantic_weight: 0.6,
  text_weight: 0.4
)
```

### Keyword Extraction

The `extract_keywords` method intelligently identifies significant terms from search queries:

```ruby
# Extract meaningful keywords from queries
keywords = Ragdoll::Core::Models::Document.extract_keywords(
  query: "machine learning algorithms neural networks"
)
# Returns: ["machine", "learning", "algorithms", "neural", "networks"]

# Handles punctuation and formatting
keywords = Ragdoll::Core::Models::Document.extract_keywords(
  query: "deep-learning, artificial-intelligence!"
)  
# Returns: ["deep-learning,", "artificial-intelligence!"]

# Filters short words automatically
keywords = Ragdoll::Core::Models::Document.extract_keywords(
  query: "AI and ML for big data analysis"
)
# Returns: ["analysis"] # Only words > 4 characters
```

### Best Practices

**Query Optimization**:
- Use descriptive queries with both specific terms and conceptual language
- For technical searches, use higher text weights to prioritize exact matches
- For conceptual searches, use higher semantic weights for broader relevance

**Weight Configuration**:
- **Semantic-Heavy (0.8/0.2)**: Conceptual searches, exploratory research
- **Balanced (0.6/0.4)**: General purpose searches, mixed content
- **Text-Heavy (0.3/0.7)**: Technical documentation, specific term searches

**Performance Considerations**:
- Hybrid search is more computationally expensive than single-mode search
- Consider caching frequently used query patterns
- Use appropriate limits to balance comprehensiveness with performance
```

## Usage Analytics

### Analytics Data Collection

```ruby
class Embedding < ApplicationRecord
  # Automatic usage tracking
  after_find :track_usage, if: :search_context?
  
  def track_usage
    increment!(:usage_count)
    update_column(:returned_at, Time.current)
    
    # Record detailed analytics
    SearchAnalytics.record_access(
      embedding: self,
      query: current_search_query,
      user_id: current_user_id,
      session_id: current_session_id,
      timestamp: Time.current
    )
  end
  
  # Usage-based scoring
  def usage_score
    recency_score = calculate_recency_score
    frequency_score = calculate_frequency_score
    
    (recency_score * 0.3) + (frequency_score * 0.7)
  end
  
  private
  
  def calculate_recency_score
    return 0 unless returned_at
    
    days_since = (Time.current - returned_at) / 1.day
    Math.exp(-days_since / 30.0)  # Exponential decay over 30 days
  end
  
  def calculate_frequency_score
    return 0 if usage_count.zero?
    
    # Logarithmic scaling for usage frequency
    Math.log(usage_count + 1) / Math.log(100)  # Max score at 100 uses
  end
end
```

### Smart Ranking Algorithm

```ruby
class SearchRanker
  def rank_results(embeddings, options = {})
    embeddings.map do |embedding|
      {
        embedding: embedding,
        similarity_score: embedding.similarity,
        usage_score: embedding.usage_score,
        metadata_score: calculate_metadata_score(embedding, options),
        composite_score: calculate_composite_score(embedding, options)
      }
    end.sort_by { |result| -result[:composite_score] }
  end
  
  private
  
  def calculate_composite_score(embedding, options)
    weights = options[:ranking_weights] || default_weights
    
    similarity_weight = weights[:similarity] || 0.6
    usage_weight = weights[:usage] || 0.3
    metadata_weight = weights[:metadata] || 0.1
    
    (embedding.similarity * similarity_weight) +
    (embedding.usage_score * usage_weight) +
    (calculate_metadata_score(embedding, options) * metadata_weight)
  end
  
  def calculate_metadata_score(embedding, options)
    document = embedding.embeddable.document
    score = 0.0
    
    # Boost recent documents
    if document.created_at > 30.days.ago
      score += 0.2
    end
    
    # Boost documents with rich metadata
    if document.metadata&.key?('classification')
      score += 0.1
    end
    
    # Classification matching
    if options[:preferred_classification] && 
       document.metadata&.dig('classification') == options[:preferred_classification]
      score += 0.3
    end
    
    # Topic relevance scoring
    if options[:topic_filters].present? && document.metadata&.key?('topics')
      overlap = (options[:topic_filters] & document.metadata['topics']).size
      score += (overlap.to_f / options[:topic_filters].size) * 0.4
    end
    
    [score, 1.0].min  # Cap at 1.0
  end
end
```

## Full-Text Search Integration

### PostgreSQL Full-Text Search

```ruby
class HybridSearchEngine
  def hybrid_search(query, semantic_weight: 0.7, text_weight: 0.3, options: {})
    # 1. Semantic search results
    semantic_results = semantic_search(query, options)
    
    # 2. Full-text search results
    fulltext_results = fulltext_search(query, options)
    
    # 3. Combine and weight results
    combine_search_results(
      semantic_results, 
      fulltext_results,
      semantic_weight: semantic_weight,
      text_weight: text_weight
    )
  end
  
  private
  
  def fulltext_search(query, options)
    # PostgreSQL full-text search with ranking
    Embedding.select(
      "*, " \
      "ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?)) as text_rank"
    )
    .where("to_tsvector('english', content) @@ plainto_tsquery('english', ?)", query)
    .where("ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?)) > 0.1", query)
    .order("text_rank DESC")
    .limit(options[:limit] || 50)
  end
  
  def combine_search_results(semantic_results, fulltext_results, weights)
    all_results = {}
    
    # Add semantic results with weighting
    semantic_results.each do |result|
      all_results[result.id] = {
        embedding: result,
        semantic_score: result.similarity * weights[:semantic_weight],
        text_score: 0,
        composite_score: result.similarity * weights[:semantic_weight]
      }
    end
    
    # Add/enhance with full-text results
    fulltext_results.each do |result|
      if all_results[result.id]
        # Enhance existing result
        all_results[result.id][:text_score] = result.text_rank * weights[:text_weight]
        all_results[result.id][:composite_score] += result.text_rank * weights[:text_weight]
      else
        # Add new result
        all_results[result.id] = {
          embedding: result,
          semantic_score: 0,
          text_score: result.text_rank * weights[:text_weight],
          composite_score: result.text_rank * weights[:text_weight]
        }
      end
    end
    
    # Sort by composite score and apply usage ranking
    ranked_results = all_results.values
                               .sort_by { |r| -r[:composite_score] }
                               .first(weights[:limit] || 20)
    
    apply_usage_ranking(ranked_results)
  end
end
```

## Advanced Search Features

### Faceted Search

```ruby
class FacetedSearch
  def search_with_facets(query, facets: {})
    base_results = SearchEngine.search_similar_content(query)
    
    # Apply facet filters
    filtered_results = apply_facet_filters(base_results, facets)
    
    # Calculate facet counts for UI
    facet_counts = calculate_facet_counts(base_results, facets.keys)
    
    {
      results: filtered_results,
      facets: facet_counts,
      total_count: filtered_results.size
    }
  end
  
  private
  
  def apply_facet_filters(results, facets)
    filtered = results.includes(embeddable: :document)
    
    facets.each do |facet_type, values|
      case facet_type
      when :content_type
        filtered = filtered.where(embeddable_type: values.map(&:classify))
      when :classification
        filtered = filtered.joins(embeddable: :document)
                          .where("ragdoll_documents.metadata ->> 'classification' IN (?)", values)
      when :topics
        filtered = filtered.joins(embeddable: :document)
                          .where("ragdoll_documents.metadata -> 'topics' ?| array[?]", values)
      when :date_range
        start_date, end_date = values
        filtered = filtered.joins(embeddable: :document)
                          .where(ragdoll_documents: { created_at: start_date..end_date })
      end
    end
    
    filtered
  end
end

# Usage example
results = FacetedSearch.search_with_facets(
  "machine learning",
  facets: {
    content_type: ['text', 'image'],
    classification: ['research', 'technical'],
    topics: ['artificial intelligence', 'neural networks'],
    date_range: [1.year.ago, Time.current]
  }
)
```

### Search Suggestions and Autocomplete

```ruby
class SearchSuggestions
  def suggest_queries(partial_query, limit: 10)
    # 1. Historical query suggestions
    historical = suggest_from_history(partial_query, limit: limit / 2)
    
    # 2. Content-based suggestions  
    content_based = suggest_from_content(partial_query, limit: limit / 2)
    
    # 3. Combine and rank suggestions
    combine_suggestions(historical, content_based).first(limit)
  end
  
  private
  
  def suggest_from_history(partial_query, limit:)
    SearchAnalytics.where("query ILIKE ?", "#{partial_query}%")
                   .group(:query)
                   .order("COUNT(*) DESC")
                   .limit(limit)
                   .pluck(:query)
  end
  
  def suggest_from_content(partial_query, limit:)
    # Extract common phrases from content
    Embedding.where("content ILIKE ?", "%#{partial_query}%")
             .select("regexp_split_to_table(content, E'\\\\s+') as word")
             .where("word ILIKE ?", "#{partial_query}%")
             .group("word")
             .order("COUNT(*) DESC")
             .limit(limit)
             .pluck("word")
  end
end
```

## Analytics and Reporting

### Search Analytics Dashboard

```ruby
class SearchAnalytics
  def self.dashboard_metrics(date_range = 30.days.ago..Time.current)
    {
      total_searches: total_searches(date_range),
      unique_queries: unique_queries(date_range),
      top_queries: top_queries(date_range, limit: 10),
      search_trends: search_trends(date_range),
      content_type_distribution: content_type_distribution(date_range),
      average_results_per_search: average_results_per_search(date_range),
      user_engagement: user_engagement_metrics(date_range),
      performance_metrics: performance_metrics(date_range)
    }
  end
  
  def self.search_trends(date_range)
    group_by_day(date_range)
      .group(:query)
      .count
      .group_by { |k, v| k[0] }  # Group by date
      .transform_values { |queries| queries.sum { |_, count| count } }
  end
  
  def self.content_type_distribution(date_range)
    joins(embedding: :embeddable)
      .where(created_at: date_range)
      .group("embeddings.embeddable_type")
      .count
  end
  
  def self.user_engagement_metrics(date_range)
    {
      click_through_rate: calculate_ctr(date_range),
      average_session_searches: calculate_avg_session_searches(date_range),
      result_relevance_score: calculate_relevance_score(date_range),
      abandonment_rate: calculate_abandonment_rate(date_range)
    }
  end
end
```

### Query Performance Monitoring

```ruby
class SearchPerformanceMonitor
  def self.monitor_search_performance
    {
      embedding_generation_time: benchmark_embedding_generation,
      vector_search_time: benchmark_vector_search,
      fulltext_search_time: benchmark_fulltext_search,
      ranking_time: benchmark_ranking,
      total_search_time: benchmark_total_search,
      index_sizes: calculate_index_sizes,
      queue_depths: check_background_job_queues
    }
  end
  
  def self.benchmark_embedding_generation
    sample_queries = ["machine learning", "neural networks", "data science"]
    
    times = sample_queries.map do |query|
      Benchmark.realtime { EmbeddingService.generate_embedding(query) }
    end
    
    {
      average: times.sum / times.size,
      min: times.min,
      max: times.max,
      samples: times.size
    }
  end
  
  def self.benchmark_vector_search
    sample_vector = EmbeddingService.generate_embedding("test query")
    
    time = Benchmark.realtime do
      Embedding.select("embedding_vector <=> '#{sample_vector}' as distance")
               .order("embedding_vector <=> '#{sample_vector}'")
               .limit(20)
               .to_a
    end
    
    { duration: time, query_type: "vector_similarity" }
  end
end
```

## API Integration

### Search API Endpoints

```ruby
# High-level search API
class SearchAPI
  def search(params)
    query = params[:query]
    options = extract_search_options(params)
    
    case params[:search_type]
    when 'semantic'
      SearchEngine.search_similar_content(query, options)
    when 'fulltext'
      FullTextSearchEngine.search(query, options)
    when 'hybrid'
      HybridSearchEngine.hybrid_search(query, options)
    when 'faceted'
      FacetedSearch.search_with_facets(query, facets: params[:facets])
    else
      # Default to hybrid search
      HybridSearchEngine.hybrid_search(query, options)
    end
  end
  
  def suggest(params)
    SearchSuggestions.suggest_queries(
      params[:partial_query],
      limit: params[:limit] || 10
    )
  end
  
  def analytics(params)
    date_range = parse_date_range(params[:date_range])
    SearchAnalytics.dashboard_metrics(date_range)
  end
end

# Usage examples
POST /api/search
{
  "query": "machine learning algorithms",
  "search_type": "hybrid",
  "semantic_weight": 0.7,
  "text_weight": 0.3,
  "content_types": ["text", "image"],
  "similarity_threshold": 0.75,
  "limit": 20,
  "facets": {
    "classification": ["research", "technical"],
    "topics": ["AI", "neural networks"]
  }
}

GET /api/search/suggest?partial_query=machine&limit=10
{
  "suggestions": [
    "machine learning",
    "machine learning algorithms", 
    "machine learning models",
    "machine vision",
    "machine translation"
  ]
}
```

## Configuration

### Search Configuration

```ruby
Ragdoll::Core.configure do |config|
  # Basic search settings
  config.search_similarity_threshold = 0.7
  config.max_search_results = 20
  config.enable_usage_analytics = true
  
  # Ranking weights
  config.ranking_weights = {
    similarity: 0.6,
    usage: 0.3,
    metadata: 0.1
  }
  
  # Hybrid search settings
  config.enable_fulltext_search = true
  config.fulltext_search_weight = 0.3
  config.semantic_search_weight = 0.7
  
  # Performance settings
  config.search_cache_ttl = 300.seconds
  config.embedding_cache_size = 1000
  config.analytics_batch_size = 100
  
  # Index configuration
  config.vector_index_lists = 100  # IVFFlat lists parameter
  config.enable_search_suggestions = true
  config.suggestion_cache_ttl = 3600.seconds
end
```

## Best Practices

### 1. Search Optimization
- Use appropriate similarity thresholds based on your content
- Implement result caching for common queries
- Monitor search performance and optimize indexes
- Balance semantic and full-text search weights for your use case

### 2. Analytics Implementation
- Track user interactions with search results
- Monitor query performance and adjust configurations
- Analyze search patterns to improve content organization
- Use analytics to guide feature development

### 3. Ranking Strategy
- Tune ranking weights based on user feedback
- Consider domain-specific ranking factors
- Implement A/B testing for ranking algorithms
- Monitor ranking effectiveness through engagement metrics

### 4. Performance Scaling
- Implement search result caching
- Use connection pooling for database access
- Consider search result pre-computation for common queries
- Monitor and scale background job processing

The search and analytics system in Ragdoll provides enterprise-grade search capabilities that combine the power of semantic search with practical usage analytics and full-text search, enabling sophisticated document intelligence applications with excellent user experience.