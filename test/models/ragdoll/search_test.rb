# frozen_string_literal: true

require "test_helper"

class Ragdoll::SearchTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
    @query_embedding = Array.new(1536) { rand }
    
    @search = Ragdoll::Search.new(
      query: "machine learning algorithms",
      query_embedding: @query_embedding,
      search_type: "semantic",
      results_count: 5,
      max_similarity_score: 0.95,
      min_similarity_score: 0.70,
      avg_similarity_score: 0.82,
      search_filters: { document_type: "text" },
      search_options: { limit: 10, threshold: 0.7 },
      execution_time_ms: 150,
      session_id: "session_123",
      user_id: "user_456"
    )
  end

  private

  def ci_environment?
    ENV["CI"] == "true" || ENV["RAGDOLL_SKIP_DATABASE_TESTS"] == "true"
  end

  def test_valid_search
    assert @search.valid?
  end

  def test_query_presence_validation
    @search.query = nil
    assert_not @search.valid?
    assert_includes @search.errors[:query], "can't be blank"

    @search.query = ""
    assert_not @search.valid?
    assert_includes @search.errors[:query], "can't be blank"
  end

  def test_query_embedding_presence_validation
    @search.query_embedding = nil
    assert_not @search.valid?
    assert_includes @search.errors[:query_embedding], "can't be blank"
  end

  def test_search_type_validation
    @search.search_type = nil
    assert_not @search.valid?
    assert_includes @search.errors[:search_type], "can't be blank"

    @search.search_type = "invalid_type"
    assert_not @search.valid?
    assert_includes @search.errors[:search_type], "is not included in the list"

    %w[semantic hybrid fulltext].each do |valid_type|
      @search.search_type = valid_type
      assert @search.valid?, "#{valid_type} should be valid"
    end
  end

  def test_results_count_validation
    @search.results_count = nil
    assert_not @search.valid?
    assert_includes @search.errors[:results_count], "can't be blank"

    @search.results_count = -1
    assert_not @search.valid?
    assert_includes @search.errors[:results_count], "must be greater than or equal to 0"

    @search.results_count = 0
    assert @search.valid?
  end

  def test_search_type_scopes
    @search.save!
    
    semantic_search = Ragdoll::Search.create!(
      query: "test semantic",
      query_embedding: @query_embedding,
      search_type: "semantic"
    )
    
    hybrid_search = Ragdoll::Search.create!(
      query: "test hybrid", 
      query_embedding: @query_embedding,
      search_type: "hybrid"
    )

    assert_includes Ragdoll::Search.by_type("semantic"), @search
    assert_includes Ragdoll::Search.by_type("semantic"), semantic_search
    assert_not_includes Ragdoll::Search.by_type("semantic"), hybrid_search
  end

  def test_session_and_user_scopes
    @search.save!
    
    other_search = Ragdoll::Search.create!(
      query: "other query",
      query_embedding: @query_embedding,
      session_id: "different_session",
      user_id: "different_user"
    )

    assert_includes Ragdoll::Search.by_session("session_123"), @search
    assert_not_includes Ragdoll::Search.by_session("session_123"), other_search

    assert_includes Ragdoll::Search.by_user("user_456"), @search
    assert_not_includes Ragdoll::Search.by_user("user_456"), other_search
  end

  def test_with_results_and_popular_scopes
    @search.results_count = 0
    @search.save!
    
    popular_search = Ragdoll::Search.create!(
      query: "popular query",
      query_embedding: @query_embedding,
      results_count: 10
    )

    assert_not_includes Ragdoll::Search.with_results, @search
    assert_includes Ragdoll::Search.with_results, popular_search
    
    assert_includes Ragdoll::Search.popular, popular_search
  end

  def test_slow_searches_scope
    @search.execution_time_ms = 500
    @search.save!
    
    slow_search = Ragdoll::Search.create!(
      query: "slow query",
      query_embedding: @query_embedding,
      execution_time_ms: 1500
    )

    assert_not_includes Ragdoll::Search.slow_searches(1000), @search
    assert_includes Ragdoll::Search.slow_searches(1000), slow_search
  end

  def test_find_similar_searches
    @search.save!
    
    # Create similar search with slightly different embedding
    similar_embedding = @query_embedding.map { |val| val + rand(-0.1..0.1) }
    similar_search = Ragdoll::Search.create!(
      query: "similar machine learning query",
      query_embedding: similar_embedding
    )
    
    # Create dissimilar search
    dissimilar_embedding = Array.new(1536) { rand }
    dissimilar_search = Ragdoll::Search.create!(
      query: "completely different topic",
      query_embedding: dissimilar_embedding
    )

    similar_results = Ragdoll::Search.find_similar(@query_embedding, limit: 5, threshold: 0.5)
    
    assert similar_results.any?
    # The original search should be most similar to itself
    assert_equal @search.id, similar_results.first.id
    
    # Check that similarity scores are assigned
    similar_results.each do |result|
      assert result.respond_to?(:similarity_score)
      assert result.similarity_score >= 0.5
    end
  end

  def test_calculate_similarity_stats
    @search.save!
    
    # Create some search results
    document = Ragdoll::Document.create!(
      location: "/test/doc.txt",
      title: "Test Document", 
      document_type: "text"
    )
    
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "text-embedding-3-large",
      content: "test content"
    )
    
    embedding = Ragdoll::Embedding.create!(
      embeddable: content,
      content: "test content",
      embedding_vector: @query_embedding,
      chunk_index: 0
    )

    # Create second embedding for different result
    embedding2 = Ragdoll::Embedding.create!(
      embeddable: content,
      content: "another chunk of test content",
      embedding_vector: Array.new(1536) { rand },
      chunk_index: 1
    )

    @search.search_results.create!(
      embedding: embedding,
      similarity_score: 0.95,
      result_rank: 1
    )
    
    @search.search_results.create!(
      embedding: embedding2,
      similarity_score: 0.85,
      result_rank: 2
    )

    @search.calculate_similarity_stats!
    @search.reload

    assert_equal 0.95, @search.max_similarity_score
    assert_equal 0.85, @search.min_similarity_score
    assert_equal 0.90, @search.avg_similarity_score
  end

  def test_click_through_rate_calculation
    @search.save!
    
    document = create_test_document_with_embedding
    
    # Create search results with mixed click status
    clicked_result = @search.search_results.create!(
      embedding: document[:embedding],
      similarity_score: 0.90,
      result_rank: 1,
      clicked: true
    )
    
    unclicked_result = @search.search_results.create!(
      embedding: document[:embedding],
      similarity_score: 0.80,
      result_rank: 2,
      clicked: false
    )

    # Update the search results count to match actual results
    @search.update!(results_count: 2)

    assert_equal 50.0, @search.click_through_rate
  end

  def test_record_search_class_method
    # Create real embeddings first
    document = create_test_document_with_embedding
    
    embedding2 = Ragdoll::Embedding.create!(
      embeddable: document[:content],
      content: "second chunk",
      embedding_vector: Array.new(1536) { rand },
      chunk_index: 1
    )
    
    results = [
      { embedding_id: document[:embedding].id, similarity: 0.95 },
      { embedding_id: embedding2.id, similarity: 0.85 }
    ]
    
    search = Ragdoll::Search.record_search(
      query: "test query",
      query_embedding: @query_embedding,
      results: results,
      search_type: "semantic",
      filters: { document_type: "text" },
      options: { limit: 10 },
      execution_time_ms: 200,
      session_id: "test_session",
      user_id: "test_user"
    )

    assert_equal "test query", search.query
    assert_equal @query_embedding, search.query_embedding
    assert_equal "semantic", search.search_type
    assert_equal 2, search.results_count
    assert_equal({ "document_type" => "text" }, search.search_filters)
    assert_equal({ "limit" => 10 }, search.search_options)
    assert_equal 200, search.execution_time_ms
    assert_equal "test_session", search.session_id
    assert_equal "test_user", search.user_id
    
    # Check that search results were created
    assert_equal 2, search.search_results.count
    
    # Check similarity stats were calculated
    assert_equal 0.95, search.max_similarity_score
    assert_equal 0.85, search.min_similarity_score
    assert_equal 0.90, search.avg_similarity_score
  end

  def test_search_analytics
    # Create test data
    recent_search = Ragdoll::Search.create!(
      query: "recent query",
      query_embedding: @query_embedding,
      results_count: 5,
      execution_time_ms: 100,
      created_at: 1.day.ago
    )
    
    old_search = Ragdoll::Search.create!(
      query: "old query", 
      query_embedding: @query_embedding,
      results_count: 3,
      execution_time_ms: 200,
      created_at: 40.days.ago
    )

    analytics = Ragdoll::Search.search_analytics(days: 30)
    
    assert_equal 1, analytics[:total_searches]
    assert_equal 1, analytics[:unique_queries] 
    assert_equal 5.0, analytics[:avg_results_per_search]
    assert_equal 100.0, analytics[:avg_execution_time]
    assert_equal({ "semantic" => 1 }, analytics[:search_types])
    assert_equal 1, analytics[:searches_with_results]
  end

  def test_cleanup_orphaned_searches
    # Create orphaned search by manually deleting search results
    @search.save!
    search_result = @search.search_results.create!(
      embedding: create_test_document_with_embedding[:embedding],
      similarity_score: 0.80,
      result_rank: 1
    )
    
    # Delete search result without triggering callbacks
    search_result.delete
    
    assert_equal 1, Ragdoll::Search.count
    assert_equal 0, Ragdoll::SearchResult.count
    
    cleaned_count = Ragdoll::Search.cleanup_orphaned_searches
    
    assert_equal 1, cleaned_count
    assert_equal 0, Ragdoll::Search.count
  end

  def test_cleanup_old_unused_searches
    # Create old unused search
    old_search = Ragdoll::Search.create!(
      query: "old unused",
      query_embedding: @query_embedding,
      created_at: 35.days.ago
    )
    
    old_result = old_search.search_results.create!(
      embedding: create_test_document_with_embedding[:embedding],
      similarity_score: 0.70,
      result_rank: 1,
      clicked: false
    )
    
    # Create recent search
    recent_search = Ragdoll::Search.create!(
      query: "recent search",
      query_embedding: @query_embedding,
      created_at: 1.day.ago
    )

    assert_equal 2, Ragdoll::Search.count
    
    cleaned_count = Ragdoll::Search.cleanup_old_unused_searches(days: 30)
    
    assert_equal 1, cleaned_count
    assert_equal 1, Ragdoll::Search.count
    assert Ragdoll::Search.exists?(recent_search.id)
    assert_not Ragdoll::Search.exists?(old_search.id)
  end

  private

  def create_test_document_with_embedding
    document = Ragdoll::Document.create!(
      location: "/test/document.txt",
      title: "Test Document",
      document_type: "text"
    )
    
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "text-embedding-3-large", 
      content: "test content"
    )
    
    embedding = Ragdoll::Embedding.create!(
      embeddable: content,
      content: "test content",
      embedding_vector: Array.new(1536) { rand },
      chunk_index: 0
    )
    
    { document: document, content: content, embedding: embedding }
  end
end