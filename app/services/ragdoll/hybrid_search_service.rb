# frozen_string_literal: true

require_relative "hybrid_search/filters"
require_relative "hybrid_search/rrf_merger"
require_relative "hybrid_search/vector_search"
require_relative "hybrid_search/fulltext_search"
require_relative "hybrid_search/tag_search"

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
    include HybridSearch::Filters
    include HybridSearch::RrfMerger
    include HybridSearch::VectorSearch
    include HybridSearch::FulltextSearch
    include HybridSearch::TagSearch

    # Maximum results to prevent DoS via unbounded queries
    MAX_HYBRID_LIMIT = 1000

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
      return search_parallel(query: query, limit: limit, timeframe: timeframe,
                             tags: tags, filters: filters, candidate_limit: candidate_limit) if parallel

      safe_limit = [[limit.to_i, 1].max, MAX_HYBRID_LIMIT].min
      safe_candidate_limit = [candidate_limit.to_i, 1].max * CANDIDATE_MULTIPLIER

      # Normalize timeframe if provided
      normalized_timeframe = normalize_timeframe(timeframe, query)
      clean_query = normalized_timeframe[:query]
      time_range = normalized_timeframe[:timeframe]

      # Run all three searches independently
      vector_results = fetch_vector_candidates(
        query: clean_query, timeframe: time_range, filters: filters, limit: safe_candidate_limit
      )

      fulltext_results = fetch_fulltext_candidates(
        query: clean_query, timeframe: time_range, filters: filters, limit: safe_candidate_limit
      )

      tag_results = fetch_tag_candidates(
        tags: tags, timeframe: time_range, filters: filters, limit: safe_candidate_limit
      )

      # Merge using RRF and return top results
      merge_with_rrf(vector_results, fulltext_results, tag_results).first(safe_limit)
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

    def log(level, message)
      return unless defined?(Rails) && Rails.logger

      Rails.logger.send(level, "HybridSearchService: #{message}")
    end
  end
end
