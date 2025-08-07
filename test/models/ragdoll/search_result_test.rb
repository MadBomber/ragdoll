# frozen_string_literal: true

require "test_helper"

class Ragdoll::SearchResultTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
    @document = Ragdoll::Document.create!(
      location: "/test/document.txt",
      title: "Test Document",
      document_type: "text"
    )

    @content = Ragdoll::TextContent.create!(
      document: @document,
      embedding_model: "text-embedding-3-large",
      content: "This is test content for embedding"
    )

    @embedding = Ragdoll::Embedding.create!(
      embeddable: @content,
      content: "This is test content for embedding",
      embedding_vector: Array.new(1536) { rand },
      chunk_index: 0
    )

    @search = Ragdoll::Search.create!(
      query: "test query",
      query_embedding: Array.new(1536) { rand },
      search_type: "semantic",
      results_count: 1
    )

    @search_result = Ragdoll::SearchResult.new(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.85,
      result_rank: 1
    )
  end

  private

  def ci_environment?
    ENV["CI"] == "true" || ENV["RAGDOLL_SKIP_DATABASE_TESTS"] == "true"
  end

  def test_valid_search_result
    assert @search_result.valid?
  end

  def test_similarity_score_validation
    @search_result.similarity_score = nil
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:similarity_score], "can't be blank"

    @search_result.similarity_score = -0.1
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:similarity_score], "must be in 0.0..1.0"

    @search_result.similarity_score = 1.1
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:similarity_score], "must be in 0.0..1.0"

    @search_result.similarity_score = 0.0
    assert @search_result.valid?

    @search_result.similarity_score = 1.0
    assert @search_result.valid?
  end

  def test_result_rank_validation
    @search_result.result_rank = nil
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:result_rank], "can't be blank"

    @search_result.result_rank = 0
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:result_rank], "must be greater than 0"

    @search_result.result_rank = -1
    assert_not @search_result.valid?
    assert_includes @search_result.errors[:result_rank], "must be greater than 0"

    @search_result.result_rank = 1
    assert @search_result.valid?
  end

  def test_result_rank_uniqueness_per_search
    @search_result.save!

    duplicate_rank_result = Ragdoll::SearchResult.new(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.75,
      result_rank: 1
    )

    assert_not duplicate_rank_result.valid?
    assert_includes duplicate_rank_result.errors[:result_rank], "has already been taken"

    # Same rank should be valid for different search
    other_search = Ragdoll::Search.create!(
      query: "other query",
      query_embedding: Array.new(1536) { rand }
    )

    duplicate_rank_result.search = other_search
    assert duplicate_rank_result.valid?
  end

  def test_belongs_to_associations
    @search_result.save!

    assert_equal @search, @search_result.search
    assert_equal @embedding, @search_result.embedding
  end

  def test_scopes
    @search_result.save!

    clicked_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.90,
      result_rank: 2,
      clicked: true,
      clicked_at: Time.current
    )

    high_sim_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.95,
      result_rank: 3
    )

    low_sim_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.45,
      result_rank: 4
    )

    # Test scopes
    assert_includes Ragdoll::SearchResult.by_rank, @search_result
    assert_equal [@search_result, clicked_result, high_sim_result, low_sim_result], 
                 Ragdoll::SearchResult.by_rank.to_a

    assert_includes Ragdoll::SearchResult.clicked, clicked_result
    assert_not_includes Ragdoll::SearchResult.clicked, @search_result

    assert_includes Ragdoll::SearchResult.unclicked, @search_result
    assert_not_includes Ragdoll::SearchResult.unclicked, clicked_result

    assert_includes Ragdoll::SearchResult.high_similarity(0.8), @search_result
    assert_includes Ragdoll::SearchResult.high_similarity(0.8), clicked_result
    assert_includes Ragdoll::SearchResult.high_similarity(0.8), high_sim_result
    assert_not_includes Ragdoll::SearchResult.high_similarity(0.8), low_sim_result

    assert_includes Ragdoll::SearchResult.recent_clicks, clicked_result
    assert_not_includes Ragdoll::SearchResult.recent_clicks, @search_result
  end

  def test_mark_as_clicked
    @search_result.save!

    assert_not @search_result.clicked
    assert_nil @search_result.clicked_at

    @search_result.mark_as_clicked!
    @search_result.reload

    assert @search_result.clicked
    assert_not_nil @search_result.clicked_at
    assert_in_delta Time.current, @search_result.clicked_at, 1.second
  end

  def test_content_delegation
    @search_result.save!

    assert_equal @embedding.content, @search_result.content
  end

  def test_document_delegation
    @search_result.save!

    assert_equal @document, @search_result.document
    assert_equal @document.title, @search_result.document_title
    assert_equal @document.location, @search_result.document_location
  end

  def test_analytics_class_method
    # Create test data for analytics
    @search_result.save!
    
    clicked_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.95,
      result_rank: 2,
      clicked: true,
      clicked_at: Time.current
    )

    low_sim_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.40,
      result_rank: 3,
      created_at: 2.days.ago
    )

    old_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.70,
      result_rank: 4,
      created_at: 40.days.ago
    )

    analytics = Ragdoll::SearchResult.analytics(days: 30)

    assert_equal 3, analytics[:total_results] # Excludes old_result
    assert_equal 1, analytics[:clicked_results]
    assert_equal 33.33, analytics[:click_through_rate]
    assert_in_delta 0.73, analytics[:avg_similarity_score], 0.01
    assert_equal 2, analytics[:high_similarity_results] # >= 0.8
    assert_equal 1, analytics[:low_similarity_results] # < 0.5
    assert analytics[:rank_performance].is_a?(Hash)
  end

  def test_rank_click_analysis
    @search_result.save!

    # Create results with different ranks and click patterns
    # Note: @search_result already has rank 1, so we need different ranks
    Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.90,
      result_rank: 3,
      clicked: true
    )

    Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.85,
      result_rank: 4,
      clicked: false
    )

    Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.80,
      result_rank: 2,
      clicked: true
    )

    analysis = Ragdoll::SearchResult.rank_click_analysis

    assert analysis[1][:total] >= 1  # @search_result with rank 1
    assert analysis[1][:clicked] >= 0
    assert analysis[1][:ctr] >= 0

    assert analysis[2][:total] >= 1
    assert analysis[2][:clicked] >= 1
    assert_equal 100.0, analysis[2][:ctr]
    
    assert analysis[3][:total] >= 1
    assert analysis[3][:clicked] >= 1
    assert_equal 100.0, analysis[3][:ctr]
  end

  def test_top_performing_embeddings
    @search_result.save!

    # Create multiple search results for the same embedding
    other_search = Ragdoll::Search.create!(
      query: "another query",
      query_embedding: Array.new(1536) { rand }
    )

    Ragdoll::SearchResult.create!(
      search: other_search,
      embedding: @embedding,
      similarity_score: 0.90,
      result_rank: 1,
      clicked: true
    )

    Ragdoll::SearchResult.create!(
      search: other_search,
      embedding: @embedding,
      similarity_score: 0.80,
      result_rank: 2,
      clicked: false
    )

    top_performers = Ragdoll::SearchResult.top_performing_embeddings(limit: 10)

    assert top_performers.any?
    
    performer = top_performers.first
    assert_equal @embedding.id, performer.embedding_id
    assert performer.appearance_count >= 2
    assert performer.avg_similarity > 0
    assert performer.click_count >= 0
    assert performer.ctr >= 0
  end

  def test_cleanup_empty_search_callback
    @search_result.save!

    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count

    # Destroy the search result
    @search_result.destroy

    # Verify search was cleaned up because it has no results left
    assert_equal 0, Ragdoll::Search.count
    assert_equal 0, Ragdoll::SearchResult.count
  end

  def test_cleanup_empty_search_callback_with_multiple_results
    @search_result.save!

    # Create second result for same search
    second_result = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding,
      similarity_score: 0.75,
      result_rank: 2
    )

    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 2, Ragdoll::SearchResult.count

    # Destroy one result
    @search_result.destroy

    # Search should still exist because it has remaining results
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count

    # Destroy the last result
    second_result.destroy

    # Now search should be cleaned up
    assert_equal 0, Ragdoll::Search.count
    assert_equal 0, Ragdoll::SearchResult.count
  end

  def test_cleanup_callback_handles_missing_search
    @search_result.save!
    
    # Delete the search using SQL to bypass ActiveRecord completely
    search_id = @search.id
    ActiveRecord::Base.connection.execute("DELETE FROM ragdoll_searches WHERE id = #{search_id}")
    
    # Reload the search result to clear any cached associations
    @search_result.reload
    
    # Destroying the result shouldn't raise an error even though search is gone
    assert_nothing_raised do
      @search_result.destroy
    end
  end
end