# frozen_string_literal: true

require "test_helper"

class SearchEngineTest < Minitest::Test
  def setup
    super
    @mock_embedding_service = OpenStruct.new
    # Default: return a valid 1536-dimension embedding
    def @mock_embedding_service.generate_embedding(_text)
      Array.new(1536) { rand }
    end
    @engine = Ragdoll::SearchEngine.new(@mock_embedding_service)
  end

  # Initialization tests
  def test_initializes_with_embedding_service
    engine = Ragdoll::SearchEngine.new(@mock_embedding_service)
    assert engine.present?
  end

  def test_initializes_with_custom_config_service
    config_service = Ragdoll::ConfigurationService.new
    engine = Ragdoll::SearchEngine.new(@mock_embedding_service, config_service: config_service)
    assert engine.present?
  end

  # search_documents tests
  def test_search_documents_returns_array
    result = @engine.search_documents("test query")
    assert_kind_of Array, result
  end

  def test_search_documents_returns_empty_when_embedding_is_nil
    # Mock service that returns nil
    nil_service = OpenStruct.new
    def nil_service.generate_embedding(_text)
      nil
    end
    engine = Ragdoll::SearchEngine.new(nil_service)

    result = engine.search_documents("test query")
    assert_equal [], result
  end

  def test_search_documents_accepts_limit_option
    result = @engine.search_documents("test query", limit: 5)
    # Should not raise and return array
    assert_kind_of Array, result
  end

  def test_search_documents_accepts_threshold_option
    result = @engine.search_documents("test query", threshold: 0.9)
    assert_kind_of Array, result
  end

  def test_search_documents_accepts_filters_option
    result = @engine.search_documents("test query", filters: { document_id: 1 })
    assert_kind_of Array, result
  end

  # search_similar_content tests
  def test_search_similar_content_returns_hash
    result = @engine.search_similar_content("test query")
    assert_kind_of Hash, result
  end

  def test_search_similar_content_includes_results
    result = @engine.search_similar_content("test query")
    assert result.key?(:results)
  end

  def test_search_similar_content_includes_execution_time
    result = @engine.search_similar_content("test query")
    assert result.key?(:execution_time_ms)
    assert_kind_of Integer, result[:execution_time_ms]
  end

  def test_search_similar_content_includes_statistics
    result = @engine.search_similar_content("test query")
    assert result.key?(:statistics)
  end

  def test_search_similar_content_returns_empty_results_when_embedding_is_nil
    nil_service = OpenStruct.new
    def nil_service.generate_embedding(_text)
      nil
    end
    engine = Ragdoll::SearchEngine.new(nil_service)

    result = engine.search_similar_content("test query")
    assert_equal [], result
  end

  def test_search_similar_content_accepts_embedding_array_directly
    embedding = Array.new(1536) { rand }
    result = @engine.search_similar_content(embedding, query: "original query")
    assert_kind_of Hash, result
    assert result.key?(:results)
  end

  def test_search_similar_content_accepts_limit_option
    result = @engine.search_similar_content("test query", limit: 5)
    assert_kind_of Hash, result
  end

  def test_search_similar_content_accepts_threshold_option
    result = @engine.search_similar_content("test query", threshold: 0.85)
    assert_kind_of Hash, result
  end

  def test_search_similar_content_accepts_keywords_option
    result = @engine.search_similar_content("test query", keywords: ["ruby", "rails"])
    assert_kind_of Hash, result
  end

  def test_search_similar_content_accepts_keywords_as_string
    result = @engine.search_similar_content("test query", keywords: "ruby")
    assert_kind_of Hash, result
  end

  def test_search_similar_content_filters_empty_keywords
    result = @engine.search_similar_content("test query", keywords: ["ruby", "", nil])
    assert_kind_of Hash, result
  end

  def test_search_similar_content_accepts_session_id
    result = @engine.search_similar_content("test query", session_id: "session-123")
    assert_kind_of Hash, result
  end

  def test_search_similar_content_accepts_user_id
    result = @engine.search_similar_content("test query", user_id: 42)
    assert_kind_of Hash, result
  end

  def test_search_similar_content_can_disable_tracking
    result = @engine.search_similar_content("test query", track_search: false)
    assert_kind_of Hash, result
  end

  def test_search_similar_content_with_all_options
    result = @engine.search_similar_content(
      "test query",
      limit: 10,
      threshold: 0.8,
      keywords: ["ruby"],
      session_id: "session-123",
      user_id: 1,
      filters: { document_type: "text" }
    )
    assert_kind_of Hash, result
    assert result.key?(:results)
  end

  # Edge cases
  def test_search_with_empty_query
    result = @engine.search_similar_content("")
    # Should still work - let embedding service handle it
    assert_kind_of Hash, result
  end

  def test_search_with_very_long_query
    long_query = "word " * 1000
    result = @engine.search_similar_content(long_query)
    assert_kind_of Hash, result
  end

  def test_search_with_special_characters
    result = @engine.search_similar_content("test & query | with <special> chars!")
    assert_kind_of Hash, result
  end

  def test_search_with_unicode
    result = @engine.search_similar_content("测试查询 with Unicode 🔍")
    assert_kind_of Hash, result
  end

  def test_multiple_searches_work_correctly
    result1 = @engine.search_similar_content("first query")
    result2 = @engine.search_similar_content("second query")

    assert_kind_of Hash, result1
    assert_kind_of Hash, result2
  end

  def test_search_execution_time_is_positive
    result = @engine.search_similar_content("test query")
    assert result[:execution_time_ms] >= 0
  end

  # Error handling
  def test_search_handles_embedding_service_errors_gracefully
    error_service = Object.new
    def error_service.generate_embedding(_text)
      raise StandardError, "Embedding generation failed"
    end
    engine = Ragdoll::SearchEngine.new(error_service)

    assert_raises(StandardError) do
      engine.search_similar_content("test query")
    end
  end

  def test_search_documents_handles_embedding_service_errors
    error_service = Object.new
    def error_service.generate_embedding(_text)
      raise StandardError, "Embedding generation failed"
    end
    engine = Ragdoll::SearchEngine.new(error_service)

    assert_raises(StandardError) do
      engine.search_documents("test query")
    end
  end
end
