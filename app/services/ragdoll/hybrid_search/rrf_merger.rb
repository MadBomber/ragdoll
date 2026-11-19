# frozen_string_literal: true

module Ragdoll
  module HybridSearch
    # Reciprocal Rank Fusion (RRF) merging algorithm
    #
    # Merges results from multiple search sources using the RRF formula:
    # score = Σ 1/(k + rank) for each list where the item appears
    #
    # Items appearing in multiple searches receive boosted scores.
    #
    module RrfMerger
      # RRF constant - higher values reduce the impact of rank differences
      # 60 is the standard value from the original RRF paper
      RRF_K = 60

      # Merge three result sets using Reciprocal Rank Fusion
      #
      # @param vector_results [Array<Hash>] Vector similarity search results
      # @param fulltext_results [Array<Hash>] Full-text search results
      # @param tag_results [Array<Hash>] Tag-based search results
      # @return [Array<Hash>] Merged results sorted by RRF score descending
      #
      def merge_with_rrf(vector_results, fulltext_results, tag_results)
        merged = {}

        add_results_to_merged(merged, vector_results, :vector)
        add_results_to_merged(merged, fulltext_results, :fulltext)
        add_results_to_merged(merged, tag_results, :tags)

        merged.values.sort_by { |r| -r["rrf_score"] }
      end

      private

      # Add results from a single source to the merged hash
      #
      # @param merged [Hash] Accumulated merged results (mutated)
      # @param results [Array<Hash>] Results from one search source
      # @param source [Symbol] Source type (:vector, :fulltext, :tags)
      #
      def add_results_to_merged(merged, results, source)
        results.each_with_index do |result, index|
          id = result["id"]
          rank = index + 1
          rrf_contribution = 1.0 / (RRF_K + rank)

          if merged.key?(id)
            update_existing_result(merged[id], result, source, rank, rrf_contribution)
          else
            merged[id] = build_new_result(result, source, rank, rrf_contribution)
          end
        end
      end

      # Update an existing merged result with data from a new source
      #
      def update_existing_result(entry, result, source, rank, rrf_contribution)
        entry["rrf_score"] += rrf_contribution
        entry["sources"] << source.to_s

        case source
        when :vector
          entry["similarity"] = result["similarity"] || 0.0
          entry["vector_rank"] = rank
          entry["embedding"] = result["embedding"]
        when :fulltext
          entry["text_rank"] = result["text_rank"] || 0.0
          entry["fulltext_rank"] = rank
        when :tags
          entry["tag_score"] = result["tag_score"] || 0.0
          entry["matched_tags"] = result["matched_tags"] || []
          entry["tag_rank"] = rank
        end
      end

      # Build a new result entry for the merged hash
      #
      def build_new_result(result, source, rank, rrf_contribution)
        entry = {
          "id" => result["id"],
          "content" => result["content"],
          "similarity" => 0.0,
          "text_rank" => 0.0,
          "tag_score" => 0.0,
          "matched_tags" => [],
          "rrf_score" => rrf_contribution,
          "vector_rank" => nil,
          "fulltext_rank" => nil,
          "tag_rank" => nil,
          "sources" => [source.to_s]
        }

        case source
        when :vector
          entry["similarity"] = result["similarity"] || 0.0
          entry["vector_rank"] = rank
          entry["embedding"] = result["embedding"]
        when :fulltext
          entry["text_rank"] = result["text_rank"] || 0.0
          entry["fulltext_rank"] = rank
        when :tags
          entry["tag_score"] = result["tag_score"] || 0.0
          entry["matched_tags"] = result["matched_tags"] || []
          entry["tag_rank"] = rank
        end

        entry
      end
    end
  end
end
