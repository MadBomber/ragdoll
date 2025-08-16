# frozen_string_literal: true

require "active_record"
require "neighbor"

module Ragdoll
  class Search < ActiveRecord::Base
    self.table_name = "ragdoll_searches"

    # Use pgvector for vector similarity search on query embeddings
    has_neighbors :query_embedding

    has_many :search_results, class_name: "Ragdoll::SearchResult", foreign_key: "search_id", dependent: :destroy
    has_many :embeddings, through: :search_results

    validates :query, presence: true
    validates :query_embedding, presence: false, allow_nil: true
    validates :search_type, presence: true, inclusion: { in: %w[semantic hybrid fulltext] }
    validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

    scope :by_type, ->(type) { where(search_type: type) }
    scope :by_session, ->(session_id) { where(session_id: session_id) }
    scope :by_user, ->(user_id) { where(user_id: user_id) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_results, -> { where("results_count > 0") }
    scope :popular, -> { where("results_count > 0").order(results_count: :desc) }
    scope :slow_searches, ->(threshold_ms = 1000) { where("execution_time_ms > ?", threshold_ms) }

    # Find searches with similar query embeddings
    def self.find_similar(query_embedding, limit: 10, threshold: 0.8)
      nearest_neighbors(:query_embedding, query_embedding, distance: "cosine")
        .limit(limit * 2)
        .map do |search|
          similarity = 1.0 - search.neighbor_distance
          next if similarity < threshold
          
          search.define_singleton_method(:similarity_score) { similarity }
          search
        end
        .compact
        .sort_by(&:similarity_score)
        .reverse
        .take(limit)
    end

    # Calculate statistics for this search
    def calculate_similarity_stats!
      return unless search_results.any?
      
      scores = search_results.pluck(:similarity_score)
      update!(
        max_similarity_score: scores.max,
        min_similarity_score: scores.min,
        avg_similarity_score: scores.sum.to_f / scores.length
      )
    end

    # Get search results ordered by rank
    def ranked_results
      search_results.includes(:embedding).order(:result_rank)
    end

    # Get clicked results
    def clicked_results
      search_results.where(clicked: true).order(:clicked_at)
    end

    # Calculate click-through rate
    def click_through_rate
      return 0.0 if results_count == 0
      
      clicked_count = search_results.where(clicked: true).count
      clicked_count.to_f / results_count
    end

    # Record a search with its results
    def self.record_search(query:, query_embedding:, results:, search_type: "semantic", 
                          filters: {}, options: {}, execution_time_ms: nil, 
                          session_id: nil, user_id: nil)
      search = create!(
        query: query,
        query_embedding: query_embedding,
        search_type: search_type,
        results_count: results.length,
        search_filters: filters,
        search_options: options,
        execution_time_ms: execution_time_ms,
        session_id: session_id,
        user_id: user_id
      )

      # Create search result records
      results.each_with_index do |result, index|
        search.search_results.create!(
          embedding_id: result[:embedding_id],
          similarity_score: result[:similarity],
          result_rank: index + 1
        )
      end

      # Calculate and store similarity statistics
      search.calculate_similarity_stats!
      search
    end

    # Search analytics methods
    def self.search_analytics(days: 30)
      start_date = days.days.ago
      searches = where(created_at: start_date..)
      
      {
        total_searches: searches.count,
        unique_queries: searches.distinct.count(:query),
        avg_results_per_search: searches.average(:results_count)&.round(2),
        avg_execution_time: searches.average(:execution_time_ms)&.round(2),
        search_types: searches.group(:search_type).count,
        searches_with_results: searches.where("results_count > 0").count,
        avg_click_through_rate: calculate_avg_ctr(searches)
      }
    end

    # Cleanup orphaned searches that have no remaining search results
    def self.cleanup_orphaned_searches
      orphaned_search_ids = where.not(id: SearchResult.distinct.pluck(:search_id))
      orphaned_count = orphaned_search_ids.count
      
      if orphaned_count > 0
        orphaned_search_ids.destroy_all
        Rails.logger.info "Cleaned up #{orphaned_count} orphaned search records" if defined?(Rails)
      end
      
      orphaned_count
    end

    # Cleanup searches older than specified days with no clicks
    def self.cleanup_old_unused_searches(days: 30)
      cutoff_date = days.days.ago
      unused_searches = where(created_at: ...cutoff_date)
                       .left_joins(:search_results)
                       .where(search_results: { clicked: [nil, false] })
      
      unused_count = unused_searches.count
      
      if unused_count > 0
        unused_searches.destroy_all
        Rails.logger.info "Cleaned up #{unused_count} old unused search records" if defined?(Rails)
      end
      
      unused_count
    end

    private

    def self.calculate_avg_ctr(searches)
      search_ids = searches.pluck(:id)
      return 0.0 if search_ids.empty?

      total_results = SearchResult.where(search_id: search_ids).count
      return 0.0 if total_results == 0

      clicked_results = SearchResult.where(search_id: search_ids, clicked: true).count
      (clicked_results.to_f / total_results * 100).round(2)
    end
  end
end