# frozen_string_literal: true

module Ragdoll
  module HybridSearch
    # Vector similarity search strategy
    #
    # Uses embedding vectors and the neighbor gem to find semantically
    # similar content using cosine distance.
    #
    module VectorSearch
      # Fetch candidates using vector similarity search
      #
      # @param query [String] Search query text
      # @param timeframe [Range, nil] Time range filter
      # @param filters [Hash] Additional filters
      # @param limit [Integer] Maximum results to return
      # @return [Array<Hash>] Results with id, content, similarity, embedding
      #
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
            "id" => embedding.id,
            "content" => embedding.content,
            "similarity" => 1.0 - embedding.neighbor_distance,
            "embedding" => embedding
          }
        end
      end
    end
  end
end
