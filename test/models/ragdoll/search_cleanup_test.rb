# frozen_string_literal: true

require "test_helper"

class Ragdoll::SearchCleanupTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
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

    @query_embedding = Array.new(1536) { rand }
    
    @search = Ragdoll::Search.create!(
      query: "test query",
      query_embedding: @query_embedding,
      search_type: "semantic",
      results_count: 1
    )

    @search_result = Ragdoll::SearchResult.create!(
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

  def test_search_result_cleanup_on_embedding_deletion
    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count
    assert_equal 1, Ragdoll::Embedding.count

    # Delete the embedding (this should cascade to search_result)
    @embedding.destroy

    # Verify search_result was deleted via cascade
    assert_equal 0, Ragdoll::SearchResult.count
    assert_equal 0, Ragdoll::Embedding.count
    
    # Verify search was cleaned up automatically
    assert_equal 0, Ragdoll::Search.count
  end

  def test_search_result_cleanup_on_content_deletion
    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count
    assert_equal 1, Ragdoll::Embedding.count

    # Delete the content (this should cascade to embedding, then search_result)
    @content.destroy

    # Verify everything was cleaned up
    assert_equal 0, Ragdoll::SearchResult.count
    assert_equal 0, Ragdoll::Embedding.count
    assert_equal 0, Ragdoll::Search.count
  end

  def test_search_result_cleanup_on_document_deletion
    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count
    assert_equal 1, Ragdoll::Embedding.count
    assert_equal 1, Ragdoll::Document.count

    # Delete the document (this should cascade through content -> embedding -> search_result -> search)
    @document.destroy

    # Verify complete cleanup
    assert_equal 0, Ragdoll::SearchResult.count
    assert_equal 0, Ragdoll::Embedding.count
    assert_equal 0, Ragdoll::Search.count
    assert_equal 0, Ragdoll::Document.count
  end

  def test_search_with_multiple_results_partial_cleanup
    # Create a second embedding and search result for the same search
    @embedding2 = Ragdoll::Embedding.create!(
      embeddable: @content,
      content: "Another chunk of content",
      embedding_vector: Array.new(1536) { rand },
      chunk_index: 1
    )

    @search_result2 = Ragdoll::SearchResult.create!(
      search: @search,
      embedding: @embedding2,
      similarity_score: 0.75,
      result_rank: 2
    )

    # Update search results count
    @search.update!(results_count: 2)

    # Verify initial state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 2, Ragdoll::SearchResult.count
    assert_equal 2, Ragdoll::Embedding.count

    # Delete only one embedding
    @embedding.destroy

    # Verify search still exists because it has remaining results
    assert_equal 1, Ragdoll::Search.count
    assert_equal 1, Ragdoll::SearchResult.count
    assert_equal 1, Ragdoll::Embedding.count

    # Delete the second embedding
    @embedding2.destroy

    # Now search should be cleaned up
    assert_equal 0, Ragdoll::Search.count
    assert_equal 0, Ragdoll::SearchResult.count
    assert_equal 0, Ragdoll::Embedding.count
  end

  def test_cleanup_orphaned_searches_method
    # Create an orphaned search by manually deleting search results
    @search_result.delete # Use delete to bypass callbacks
    
    # Verify orphaned state
    assert_equal 1, Ragdoll::Search.count
    assert_equal 0, Ragdoll::SearchResult.count

    # Run cleanup
    orphaned_count = Ragdoll::Search.cleanup_orphaned_searches

    # Verify cleanup worked
    assert_equal 1, orphaned_count
    assert_equal 0, Ragdoll::Search.count
  end

  def test_cleanup_old_unused_searches
    # Create old unused search
    old_search = Ragdoll::Search.create!(
      query: "old unused query",
      query_embedding: @query_embedding,
      search_type: "semantic",
      results_count: 1,
      created_at: 35.days.ago
    )

    old_result = Ragdoll::SearchResult.create!(
      search: old_search,
      embedding: @embedding,
      similarity_score: 0.60,
      result_rank: 1,
      clicked: false
    )

    # Verify initial state
    assert_equal 2, Ragdoll::Search.count

    # Run cleanup for searches older than 30 days
    unused_count = Ragdoll::Search.cleanup_old_unused_searches(days: 30)

    # Verify old unused search was cleaned up
    assert_equal 1, unused_count
    assert_equal 1, Ragdoll::Search.count
    assert_not Ragdoll::Search.exists?(old_search.id)
  end
end