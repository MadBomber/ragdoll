# frozen_string_literal: true

require 'simple_flow'

module Ragdoll
  module Workflows
    # Hybrid Search Workflow using SimpleFlow for parallel execution
    #
    # Executes vector, fulltext, and tag searches in parallel, then merges
    # results using Reciprocal Rank Fusion (RRF).
    #
    # Pipeline structure:
    #   ├─→ vector_search   (no deps)
    #   ├─→ fulltext_search (no deps)  ← All 3 run in parallel
    #   └─→ tag_search      (no deps)
    #              ↓
    #         merge_rrf (depends on all searches)
    #
    # @example
    #   workflow = Ragdoll::Workflows::HybridSearchWorkflow.new(
    #     embedding_service: embedding_service
    #   )
    #   results = workflow.call(
    #     query: "PostgreSQL performance",
    #     timeframe: 1.week.ago..Time.now,
    #     tags: ["database"],
    #     limit: 20
    #   )
    #
    class HybridSearchWorkflow
      # RRF constant - higher values reduce the impact of rank differences
      RRF_K = 60

      # Multiplier for candidates from each search
      CANDIDATE_MULTIPLIER = 3

      # Maximum results to prevent DoS via unbounded queries
      MAX_HYBRID_LIMIT = 1000

      # @param embedding_service [Ragdoll::EmbeddingService] For generating query embeddings
      # @param concurrency [Symbol] Concurrency mode (:auto, :async, :threads)
      #
      def initialize(embedding_service:, concurrency: :auto)
        @embedding_service = embedding_service
        @concurrency = concurrency
        build_pipeline
      end

      # Execute the hybrid search workflow
      #
      # @param query [String] Search query
      # @param limit [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
      # @param timeframe [Range, nil] Time range filter
      # @param tags [Array<String>, nil] Filter by tags
      # @param filters [Hash] Additional filters (document_type, keywords, etc.)
      # @param candidate_limit [Integer] Candidates per search (default: 100)
      # @return [Array<Hash>] Merged results with RRF scores
      #
      def call(query:, limit: 20, timeframe: nil, tags: nil, filters: {}, candidate_limit: 100)
        safe_limit = [[limit.to_i, 1].max, MAX_HYBRID_LIMIT].min
        safe_candidate_limit = [candidate_limit.to_i, 1].max * CANDIDATE_MULTIPLIER

        # Normalize timeframe if provided
        normalized_timeframe = normalize_timeframe(timeframe, query)
        clean_query = normalized_timeframe[:query]
        time_range = normalized_timeframe[:timeframe]

        # Prepare initial data for the pipeline
        initial_data = {
          query: clean_query,
          original_query: query,
          timeframe: time_range,
          tags: tags,
          filters: filters,
          limit: safe_limit,
          candidate_limit: safe_candidate_limit,
          query_embedding: nil,
          vector_results: [],
          fulltext_results: [],
          tag_results: []
        }

        # Execute the parallel pipeline
        result = @pipeline.call_parallel(SimpleFlow::Result.new(initial_data))

        if result.continue?
          result.value[:merged_results].first(safe_limit)
        else
          log(:error, "HybridSearchWorkflow failed: #{result.errors.inspect}")
          []
        end
      end

      # Generate Mermaid diagram of the workflow
      def to_mermaid
        @pipeline.visualize_mermaid
      end

      # Get the execution plan
      def execution_plan
        @pipeline.execution_plan
      end

      private

      def build_pipeline
        embedding_service = @embedding_service
        workflow_logger = method(:log)
        vector_search_fn = method(:fetch_vector_candidates)
        fulltext_search_fn = method(:fetch_fulltext_candidates)
        tag_search_fn = method(:fetch_tag_candidates)
        merge_fn = method(:merge_with_rrf)

        @pipeline = SimpleFlow::Pipeline.new(concurrency: @concurrency) do
          # Generate query embedding (required for vector search)
          step :generate_embedding, ->(result) {
            data = result.value
            begin
              embedding = embedding_service.generate_embedding(data[:query])
              data[:query_embedding] = embedding if embedding.is_a?(Array) && embedding.any?
            rescue StandardError => e
              workflow_logger.call(:warn, "Embedding generation failed: #{e.message}")
            end
            result.continue(data)
          }, depends_on: :none

          # Vector similarity search (runs after embedding is ready)
          step :vector_search, ->(result) {
            data = result.value
            begin
              data[:vector_results] = vector_search_fn.call(
                query_embedding: data[:query_embedding],
                timeframe: data[:timeframe],
                filters: data[:filters],
                limit: data[:candidate_limit]
              )
            rescue StandardError => e
              workflow_logger.call(:warn, "Vector search failed: #{e.message}")
              data[:vector_results] = []
            end
            result.continue(data)
          }, depends_on: [:generate_embedding]

          # Full-text search (runs in parallel with vector search)
          step :fulltext_search, ->(result) {
            data = result.value
            begin
              data[:fulltext_results] = fulltext_search_fn.call(
                query: data[:query],
                timeframe: data[:timeframe],
                filters: data[:filters],
                limit: data[:candidate_limit]
              )
            rescue StandardError => e
              workflow_logger.call(:warn, "Fulltext search failed: #{e.message}")
              data[:fulltext_results] = []
            end
            result.continue(data)
          }, depends_on: [:generate_embedding]

          # Tag-based search (runs in parallel with other searches)
          step :tag_search, ->(result) {
            data = result.value
            begin
              data[:tag_results] = tag_search_fn.call(
                tags: data[:tags],
                timeframe: data[:timeframe],
                filters: data[:filters],
                limit: data[:candidate_limit]
              )
            rescue StandardError => e
              workflow_logger.call(:warn, "Tag search failed: #{e.message}")
              data[:tag_results] = []
            end
            result.continue(data)
          }, depends_on: [:generate_embedding]

          # Merge results using RRF (waits for all searches to complete)
          step :merge_rrf, ->(result) {
            data = result.value
            data[:merged_results] = merge_fn.call(
              data[:vector_results],
              data[:fulltext_results],
              data[:tag_results]
            )
            result.continue(data)
          }, depends_on: [:vector_search, :fulltext_search, :tag_search]
        end
      end

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
      def fetch_vector_candidates(query_embedding:, timeframe:, filters:, limit:)
        return [] unless query_embedding.is_a?(Array) && query_embedding.any?

        scope = Ragdoll::Embedding.all
        scope = apply_filters(scope, filters)
        scope = apply_timeframe(scope, timeframe)

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
            'text_rank' => 0.5
          }
        end
      end

      # Fetch candidates using tag-based search
      def fetch_tag_candidates(tags:, timeframe:, filters:, limit:)
        return [] if tags.blank? || tags.empty?

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
        conditions
      end

      def log(level, message)
        return unless defined?(Rails) && Rails.logger

        Rails.logger.send(level, "HybridSearchWorkflow: #{message}")
      end
    end
  end
end
