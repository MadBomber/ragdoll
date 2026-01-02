# frozen_string_literal: true

module Ragdoll
  module HybridSearch
    # Full-text search strategy with trigram fallback
    #
    # Uses PostgreSQL tsvector for full-text search with trigram
    # similarity as a fallback. Falls back to ILIKE if fulltext
    # indexes are not available.
    #
    module FulltextSearch
      # Fetch candidates using full-text search with trigram fallback
      #
      # @param query [String] Search query text
      # @param timeframe [Range, nil] Time range filter
      # @param filters [Hash] Additional filters
      # @param limit [Integer] Maximum results to return
      # @return [Array<Hash>] Results with id, content, text_rank
      #
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
            "id" => row["id"],
            "content" => row["content"],
            "text_rank" => row["text_rank"].to_f
          }
        end
      rescue StandardError => e
        # Fallback to simple ILIKE if fulltext indexes don't exist
        log(:warn, "Fulltext search failed, using ILIKE fallback: #{e.message}")
        fetch_ilike_candidates(query: query, timeframe: timeframe, filters: filters, limit: limit)
      end

      # Simple ILIKE fallback when fulltext indexes aren't available
      #
      # @param query [String] Search query text
      # @param timeframe [Range, nil] Time range filter
      # @param filters [Hash] Additional filters
      # @param limit [Integer] Maximum results to return
      # @return [Array<Hash>] Results with id, content, text_rank (default 0.5)
      #
      def fetch_ilike_candidates(query:, timeframe:, filters:, limit:)
        scope = Ragdoll::Embedding.where("content ILIKE ?", "%#{query}%")
        scope = apply_filters(scope, filters)
        scope = apply_timeframe(scope, timeframe)

        scope.limit(limit).map do |embedding|
          {
            "id" => embedding.id,
            "content" => embedding.content,
            "text_rank" => 0.5 # Default rank for ILIKE matches
          }
        end
      end
    end
  end
end
