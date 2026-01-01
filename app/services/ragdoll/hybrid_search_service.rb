# frozen_string_literal: true

module Ragdoll
  # Hybrid Search Service using Reciprocal Rank Fusion (RRF)
  #
  # Performs three independent searches and merges results:
  # 1. Vector similarity search for semantic matching
  # 2. Full-text search for keyword matching
  # 3. Tag-based search for hierarchical category matching
  #
  # Results are merged using RRF scoring. Items appearing in multiple
  # searches receive boosted scores, making them rank higher.
  #
  # RRF Formula: score = Σ 1/(k + rank) for each search where item appears
  #
  # Supports two execution modes:
  # - Parallel (default): Uses SimpleFlow workflow for concurrent execution
  # - Sequential (parallel: false): Runs searches one after another
  #
  # @example Sequential execution
  #   service = Ragdoll::HybridSearchService.new(embedding_service: embedding_service)
  #   results = service.search(query: "PostgreSQL performance", limit: 20)
  #
  # @example Parallel execution
  #   service = Ragdoll::HybridSearchService.new(embedding_service: embedding_service)
  #   results = service.search(query: "PostgreSQL performance", parallel: true)
  #
  class HybridSearchService
    # Maximum results to prevent DoS via unbounded queries
    MAX_HYBRID_LIMIT = 1000

    # RRF constant - higher values reduce the impact of rank differences
    # 60 is the standard value from the original RRF paper
    RRF_K = 60

    # Multiplier for candidates from each search
    CANDIDATE_MULTIPLIER = 3

    # @param embedding_service [Ragdoll::EmbeddingService] For generating query embeddings
    # @param concurrency [Symbol] Concurrency mode for parallel execution (:auto, :async, :threads)
    #
    def initialize(embedding_service:, concurrency: :auto)
      @embedding_service = embedding_service
      @concurrency = concurrency
      @workflow = nil
    end

    # Perform hybrid search using RRF fusion
    #
    # @param query [String] Search query
    # @param limit [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
    # @param timeframe [Range, nil] Time range filter
    # @param tags [Array<String>, nil] Filter by tags
    # @param filters [Hash] Additional filters (document_type, keywords, etc.)
    # @param candidate_limit [Integer] Candidates per search (default: 100)
    # @param parallel [Boolean] Use parallel execution via SimpleFlow (default: true)
    # @return [Array<Hash>] Merged results with RRF scores
    #
    def search(query:, limit: 20, timeframe: nil, tags: nil, filters: {}, candidate_limit: 100, parallel: true)
      # Use workflow-based parallel execution if requested
      if parallel
        return search_parallel(
          query: query,
          limit: limit,
          timeframe: timeframe,
          tags: tags,
          filters: filters,
          candidate_limit: candidate_limit
        )
      end
      safe_limit = [[limit.to_i, 1].max, MAX_HYBRID_LIMIT].min
      safe_candidate_limit = [candidate_limit.to_i, 1].max * CANDIDATE_MULTIPLIER

      # Normalize timeframe if provided
      normalized_timeframe = normalize_timeframe(timeframe, query)
      clean_query = normalized_timeframe[:query]
      time_range = normalized_timeframe[:timeframe]

      # Run all three searches independently
      vector_results = fetch_vector_candidates(
        query: clean_query,
        timeframe: time_range,
        filters: filters,
        limit: safe_candidate_limit
      )

      fulltext_results = fetch_fulltext_candidates(
        query: clean_query,
        timeframe: time_range,
        filters: filters,
        limit: safe_candidate_limit
      )

      tag_results = fetch_tag_candidates(
        tags: tags,
        timeframe: time_range,
        filters: filters,
        limit: safe_candidate_limit
      )

      # Merge using RRF
      merged = merge_with_rrf(vector_results, fulltext_results, tag_results)

      # Return top results
      merged.first(safe_limit)
    end

    # Perform hybrid search using parallel workflow
    #
    # Uses SimpleFlow to execute vector, fulltext, and tag searches concurrently.
    # ~3x faster than sequential execution for I/O-bound operations.
    #
    # @param query [String] Search query
    # @param limit [Integer] Maximum results
    # @param timeframe [Range, nil] Time range filter
    # @param tags [Array<String>, nil] Filter by tags
    # @param filters [Hash] Additional filters
    # @param candidate_limit [Integer] Candidates per search
    # @return [Array<Hash>] Merged results with RRF scores
    #
    def search_parallel(query:, limit: 20, timeframe: nil, tags: nil, filters: {}, candidate_limit: 100)
      workflow.call(
        query: query,
        limit: limit,
        timeframe: timeframe,
        tags: tags,
        filters: filters,
        candidate_limit: candidate_limit
      )
    end

    # Get the workflow for parallel execution (lazy-loaded)
    #
    # @return [Ragdoll::Workflows::HybridSearchWorkflow]
    #
    def workflow
      @workflow ||= Ragdoll::Workflows::HybridSearchWorkflow.new(
        embedding_service: @embedding_service,
        concurrency: @concurrency
      )
    end

    # Generate Mermaid diagram of the parallel workflow
    #
    # @return [String] Mermaid diagram markup
    #
    def to_mermaid
      workflow.to_mermaid
    end

    # Get the execution plan for the parallel workflow
    #
    # @return [Array] Execution plan
    #
    def execution_plan
      workflow.execution_plan
    end

    private

    # Normalize timeframe, extracting from query if :auto
    def normalize_timeframe(timeframe, query)
      if timeframe == :auto
        result = Ragdoll::Timeframe.normalize(:auto, query: query)
        { query: result.query, timeframe: result.timeframe }
      elsif timeframe
        { query: query, timeframe: Ragdoll::Timeframe.normalize(timeframe) }
      else
        { query: query, timeframe: nil }
      end
    end

    # Fetch candidates using vector similarity search
    def fetch_vector_candidates(query:, timeframe:, filters:, limit:)
      query_embedding = @embedding_service.generate_embedding(query)
      return [] unless query_embedding.is_a?(Array) && query_embedding.any?

      scope = Ragdoll::Embedding.all

      # Apply filters
      scope = apply_filters(scope, filters)
      scope = apply_timeframe(scope, timeframe)

      # Vector search using neighbor gem
      results = scope
        .nearest_neighbors(:embedding_vector, query_embedding, distance: "cosine")
        .limit(limit)
        .to_a

      results.map.with_index do |embedding, _idx|
        {
          'id' => embedding.id,
          'content' => embedding.content,
          'similarity' => 1.0 - embedding.neighbor_distance,
          'embedding' => embedding
        }
      end
    end

    # Fetch candidates using full-text search with trigram fallback
    def fetch_fulltext_candidates(query:, timeframe:, filters:, limit:)
      return [] if query.blank?

      # Build SQL for combined tsvector + trigram search
      base_conditions = ["ragdoll_embeddings.content IS NOT NULL"]
      base_conditions << timeframe_sql(timeframe) if timeframe
      base_conditions.concat(filter_conditions(filters))

      where_sql = base_conditions.join(" AND ")

      sql = <<~SQL
        WITH tsvector_matches AS (
          SELECT id, content,
                 (1.0 + ts_rank(to_tsvector('english', content), plainto_tsquery('english', $1))) as text_rank
          FROM ragdoll_embeddings
          WHERE #{where_sql}
          AND to_tsvector('english', content) @@ plainto_tsquery('english', $1)
        ),
        trigram_matches AS (
          SELECT id, content,
                 similarity(content, $1) as text_rank
          FROM ragdoll_embeddings
          WHERE #{where_sql}
          AND similarity(content, $1) >= 0.1
          AND id NOT IN (SELECT id FROM tsvector_matches)
        ),
        combined AS (
          SELECT * FROM tsvector_matches
          UNION ALL
          SELECT * FROM trigram_matches
        )
        SELECT id, content, text_rank
        FROM combined
        ORDER BY text_rank DESC
        LIMIT $2
      SQL

      results = ActiveRecord::Base.connection.exec_query(
        sql,
        "Fulltext Search",
        [[nil, query], [nil, limit]]
      ).to_a

      results.map do |row|
        {
          'id' => row['id'],
          'content' => row['content'],
          'text_rank' => row['text_rank'].to_f
        }
      end
    rescue StandardError => e
      # Fallback to simple ILIKE if fulltext indexes don't exist
      log(:warn, "Fulltext search failed, using ILIKE fallback: #{e.message}")
      fetch_ilike_candidates(query: query, timeframe: timeframe, filters: filters, limit: limit)
    end

    # Simple ILIKE fallback when fulltext indexes aren't available
    def fetch_ilike_candidates(query:, timeframe:, filters:, limit:)
      scope = Ragdoll::Embedding.where("content ILIKE ?", "%#{query}%")
      scope = apply_filters(scope, filters)
      scope = apply_timeframe(scope, timeframe)

      scope.limit(limit).map do |embedding|
        {
          'id' => embedding.id,
          'content' => embedding.content,
          'text_rank' => 0.5  # Default rank for ILIKE matches
        }
      end
    end

    # Fetch candidates using tag-based search
    def fetch_tag_candidates(tags:, timeframe:, filters:, limit:)
      return [] if tags.blank? || tags.empty?

      # Find embeddings with matching tags
      scope = Ragdoll::Embedding
        .joins(:tags)
        .where(ragdoll_tags: { name: tags })
        .distinct

      scope = apply_filters(scope, filters)
      scope = apply_timeframe(scope, timeframe)

      results = scope.limit(limit).to_a

      results.map do |embedding|
        matched_tags = embedding.tags.where(name: tags).pluck(:name)
        {
          'id' => embedding.id,
          'content' => embedding.content,
          'matched_tags' => matched_tags,
          'tag_score' => matched_tags.size.to_f / tags.size
        }
      end
    end

    # Merge three result sets using Reciprocal Rank Fusion
    #
    # RRF score = Σ 1/(k + rank) for each list where the item appears
    #
    def merge_with_rrf(vector_results, fulltext_results, tag_results)
      merged = {}

      # Process vector results
      vector_results.each_with_index do |result, index|
        id = result['id']
        rank = index + 1
        rrf_contribution = 1.0 / (RRF_K + rank)

        merged[id] = {
          'id' => id,
          'content' => result['content'],
          'similarity' => result['similarity'] || 0.0,
          'text_rank' => 0.0,
          'tag_score' => 0.0,
          'matched_tags' => [],
          'rrf_score' => rrf_contribution,
          'vector_rank' => rank,
          'fulltext_rank' => nil,
          'tag_rank' => nil,
          'sources' => ['vector'],
          'embedding' => result['embedding']
        }
      end

      # Process fulltext results
      fulltext_results.each_with_index do |result, index|
        id = result['id']
        rank = index + 1
        rrf_contribution = 1.0 / (RRF_K + rank)

        if merged.key?(id)
          # Node appears in both - add RRF contribution (boost!)
          merged[id]['rrf_score'] += rrf_contribution
          merged[id]['text_rank'] = result['text_rank']
          merged[id]['fulltext_rank'] = rank
          merged[id]['sources'] << 'fulltext'
        else
          merged[id] = {
            'id' => id,
            'content' => result['content'],
            'similarity' => 0.0,
            'text_rank' => result['text_rank'] || 0.0,
            'tag_score' => 0.0,
            'matched_tags' => [],
            'rrf_score' => rrf_contribution,
            'vector_rank' => nil,
            'fulltext_rank' => rank,
            'tag_rank' => nil,
            'sources' => ['fulltext']
          }
        end
      end

      # Process tag results
      tag_results.each_with_index do |result, index|
        id = result['id']
        rank = index + 1
        rrf_contribution = 1.0 / (RRF_K + rank)

        if merged.key?(id)
          # Node already found - add RRF contribution (boost!)
          merged[id]['rrf_score'] += rrf_contribution
          merged[id]['tag_score'] = result['tag_score']
          merged[id]['matched_tags'] = result['matched_tags']
          merged[id]['tag_rank'] = rank
          merged[id]['sources'] << 'tags'
        else
          merged[id] = {
            'id' => id,
            'content' => result['content'],
            'similarity' => 0.0,
            'text_rank' => 0.0,
            'tag_score' => result['tag_score'] || 0.0,
            'matched_tags' => result['matched_tags'] || [],
            'rrf_score' => rrf_contribution,
            'vector_rank' => nil,
            'fulltext_rank' => nil,
            'tag_rank' => rank,
            'sources' => ['tags']
          }
        end
      end

      # Sort by RRF score descending
      merged.values.sort_by { |r| -r['rrf_score'] }
    end

    # Apply filters to a scope
    def apply_filters(scope, filters)
      return scope if filters.blank?

      if filters[:document_type]
        scope = scope
          .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
          .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
          .where("ragdoll_documents.document_type = ?", filters[:document_type])
      end

      if filters[:keywords]&.any?
        scope = scope
          .joins("JOIN ragdoll_contents ON ragdoll_contents.id = ragdoll_embeddings.embeddable_id")
          .joins("JOIN ragdoll_documents ON ragdoll_documents.id = ragdoll_contents.document_id")
          .where("ragdoll_documents.keywords && ARRAY[?]::varchar[]", filters[:keywords])
      end

      scope
    end

    # Apply timeframe filter to a scope
    def apply_timeframe(scope, timeframe)
      return scope unless timeframe.is_a?(Range)

      scope.where(created_at: timeframe)
    end

    # Build SQL condition for timeframe
    def timeframe_sql(timeframe)
      return nil unless timeframe.is_a?(Range)

      "ragdoll_embeddings.created_at BETWEEN '#{timeframe.begin.to_fs(:db)}' AND '#{timeframe.end.to_fs(:db)}'"
    end

    # Build filter conditions for raw SQL
    def filter_conditions(filters)
      conditions = []
      # Add additional filter conditions as needed
      conditions
    end

    def log(level, message)
      return unless defined?(Rails) && Rails.logger

      Rails.logger.send(level, "HybridSearchService: #{message}")
    end
  end
end
