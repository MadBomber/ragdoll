# frozen_string_literal: true

require "active_record"

module Ragdoll
  class SearchResult < ActiveRecord::Base
    self.table_name = "ragdoll_search_results"

    belongs_to :search, class_name: "Ragdoll::Search"
    belongs_to :embedding, class_name: "Ragdoll::Embedding"

    validates :similarity_score, presence: true, numericality: { in: 0.0..1.0 }
    validates :result_rank, presence: true, numericality: { greater_than: 0 }
    validates :result_rank, uniqueness: { scope: :search_id }

    scope :by_rank, -> { order(:result_rank) }
    scope :clicked, -> { where(clicked: true) }
    scope :unclicked, -> { where(clicked: false) }
    scope :high_similarity, ->(threshold = 0.8) { where("similarity_score >= ?", threshold) }
    scope :recent_clicks, -> { where(clicked: true).order(clicked_at: :desc) }

    # Cleanup callback to remove searches when they have no results left
    after_destroy :cleanup_empty_search

    # Mark this result as clicked
    def mark_as_clicked!
      update!(clicked: true, clicked_at: Time.current)
    end

    # Get the content through the embedding relationship
    def content
      embedding&.content
    end

    # Get the document through the embedding relationship
    def document
      embedding&.embeddable&.document
    end

    # Get the document title
    def document_title
      document&.title
    end

    # Get the document location
    def document_location
      document&.location
    end

    # Analytics for search results
    def self.analytics(days: 30)
      start_date = days.days.ago
      results = where(created_at: start_date..)
      
      {
        total_results: results.count,
        clicked_results: results.where(clicked: true).count,
        click_through_rate: calculate_ctr(results),
        avg_similarity_score: results.average(:similarity_score)&.round(4),
        high_similarity_results: results.where("similarity_score >= 0.8").count,
        low_similarity_results: results.where("similarity_score < 0.5").count,
        rank_performance: rank_click_analysis(results)
      }
    end

    # Analyze click performance by result rank
    def self.rank_click_analysis(results = nil)
      results ||= all
      
      results.group(:result_rank)
             .group("clicked")
             .count
             .each_with_object({}) do |((rank, clicked), count), hash|
        hash[rank] ||= { total: 0, clicked: 0 }
        hash[rank][:total] += count
        hash[rank][:clicked] += count if clicked
      end
             .transform_values do |stats|
        stats.merge(
          ctr: stats[:total] > 0 ? (stats[:clicked].to_f / stats[:total] * 100).round(2) : 0.0
        )
      end
    end

    # Find embeddings that perform well across multiple searches
    def self.top_performing_embeddings(limit: 20)
      joins(:embedding)
        .group(:embedding_id)
        .select(
          "embedding_id",
          "COUNT(*) as appearance_count",
          "AVG(similarity_score) as avg_similarity",
          "COUNT(CASE WHEN clicked THEN 1 END) as click_count",
          "ROUND(COUNT(CASE WHEN clicked THEN 1 END) * 100.0 / COUNT(*), 2) as ctr"
        )
        .having("COUNT(*) > 1")
        .order("avg_similarity DESC, ctr DESC")
        .limit(limit)
    end

    private

    def self.calculate_ctr(results)
      total = results.count
      return 0.0 if total == 0

      clicked = results.where(clicked: true).count
      (clicked.to_f / total * 100).round(2)
    end

    # Cleanup callback to remove parent search if it has no results left
    def cleanup_empty_search
      return unless search
      
      # Check if this was the last result for the search
      if search.search_results.count == 0
        search.destroy
      end
    end
  end
end