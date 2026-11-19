# frozen_string_literal: true

module Ragdoll
  module HybridSearch
    # Tag-based search strategy
    #
    # Searches for embeddings that have matching tags from the
    # hierarchical tag system. Scores results based on the
    # proportion of requested tags that match.
    #
    module TagSearch
      # Fetch candidates using tag-based search
      #
      # @param tags [Array<String>, nil] Tags to search for
      # @param timeframe [Range, nil] Time range filter
      # @param filters [Hash] Additional filters
      # @param limit [Integer] Maximum results to return
      # @return [Array<Hash>] Results with id, content, matched_tags, tag_score
      #
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
            "id" => embedding.id,
            "content" => embedding.content,
            "matched_tags" => matched_tags,
            "tag_score" => matched_tags.size.to_f / tags.size
          }
        end
      end
    end
  end
end
