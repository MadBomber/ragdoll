# frozen_string_literal: true

require "test_helper"

class SearchTrackingIntegrationTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
    
    # Create test data
    @document = Ragdoll::Document.create!(
      location: "/test/document.txt",
      title: "Test Document",
      document_type: "text",
      status: "processed"
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

    @client = Ragdoll::Core::Client.new
  end

  private

  def ci_environment?
    ENV["CI"] == "true" || ENV["RAGDOLL_SKIP_DATABASE_TESTS"] == "true"
  end

  def test_client_search_creates_search_record
    # Verify no searches exist initially
    assert_equal 0, Ragdoll::Search.count
    
    # Perform a search through the client
    result = @client.search(query: "test content", limit: 5, session_id: "test_session", user_id: "test_user")
    
    # Verify search was recorded
    assert_equal 1, Ragdoll::Search.count
    
    search = Ragdoll::Search.first
    assert_equal "test content", search.query
    assert_equal "semantic", search.search_type
    assert_equal "test_session", search.session_id
    assert_equal "test_user", search.user_id
    assert search.execution_time_ms > 0
    
    # Verify search results were recorded if any results found
    if result[:results].any?
      assert search.search_results.count > 0
    end
  end

  def test_client_hybrid_search_creates_search_record
    # Verify no searches exist initially
    assert_equal 0, Ragdoll::Search.count
    
    # Perform a hybrid search through the client
    result = @client.hybrid_search(query: "test content", session_id: "hybrid_session", user_id: "hybrid_user")
    
    # Verify search was recorded
    assert_equal 1, Ragdoll::Search.count
    
    search = Ragdoll::Search.first
    assert_equal "test content", search.query
    assert_equal "hybrid", search.search_type
    assert_equal "hybrid_session", search.session_id
    assert_equal "hybrid_user", search.user_id
    assert search.execution_time_ms > 0
  end

  def test_search_tracking_can_be_disabled
    # Verify no searches exist initially
    assert_equal 0, Ragdoll::Search.count
    
    # Perform a search with tracking disabled
    result = @client.search(query: "test content", track_search: false)
    
    # Verify no search was recorded
    assert_equal 0, Ragdoll::Search.count
  end

  def test_search_with_empty_query_not_tracked
    # Verify no searches exist initially
    assert_equal 0, Ragdoll::Search.count
    
    # Perform a search with empty query
    result = @client.search(query: "", session_id: "empty_session")
    
    # Verify no search was recorded
    assert_equal 0, Ragdoll::Search.count
  end

  def test_multiple_searches_create_separate_records
    # Verify no searches exist initially
    assert_equal 0, Ragdoll::Search.count
    
    # Perform multiple searches
    @client.search(query: "first search", session_id: "session1")
    @client.search(query: "second search", session_id: "session2")
    
    # Verify both searches were recorded
    assert_equal 2, Ragdoll::Search.count
    
    queries = Ragdoll::Search.pluck(:query)
    assert_includes queries, "first search"
    assert_includes queries, "second search"
  end

  def test_search_error_does_not_break_search_functionality
    # Mock Search.record_search to raise an error
    original_method = Ragdoll::Search.method(:record_search)
    Ragdoll::Search.define_singleton_method(:record_search) do |**args|
      raise StandardError, "Search tracking failed"
    end
    
    # Perform a search - it should still work despite tracking error
    result = @client.search(query: "test content")
    
    # Search should still return results
    assert result.key?(:query)
    assert result.key?(:results)
    assert result.key?(:total_results)
    
  ensure
    # Restore original method
    Ragdoll::Search.define_singleton_method(:record_search, original_method) if original_method
  end
end