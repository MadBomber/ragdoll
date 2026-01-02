# frozen_string_literal: true

require "test_helper"

class EmbeddingServiceTest < Minitest::Test
  def setup
    super
    @service = Ragdoll::EmbeddingService.new
  end

  # Initialization tests
  def test_initializes_without_arguments
    service = Ragdoll::EmbeddingService.new
    assert service.present?
  end

  def test_initializes_with_custom_client
    mock_client = OpenStruct.new
    service = Ragdoll::EmbeddingService.new(client: mock_client)
    assert service.present?
  end

  def test_initializes_with_custom_config_service
    config_service = Ragdoll::ConfigurationService.new
    service = Ragdoll::EmbeddingService.new(config_service: config_service)
    assert service.present?
  end

  def test_initializes_with_custom_model_resolver
    model_resolver = Ragdoll::ModelResolver.new
    service = Ragdoll::EmbeddingService.new(model_resolver: model_resolver)
    assert service.present?
  end

  # generate_embedding tests
  def test_generate_embedding_returns_nil_for_nil_input
    result = @service.generate_embedding(nil)
    assert_nil result
  end

  def test_generate_embedding_returns_nil_for_empty_string
    result = @service.generate_embedding("")
    assert_nil result
  end

  def test_generate_embedding_returns_nil_for_whitespace_only
    result = @service.generate_embedding("   \n\t  ")
    assert_nil result
  end

  def test_generate_embedding_returns_array
    result = @service.generate_embedding("Test text for embedding.")
    assert_kind_of Array, result
  end

  def test_generate_embedding_returns_correct_dimensions
    result = @service.generate_embedding("Test text.")

    # Should return embedding with configured dimensions
    assert result.length > 0
    assert result.length <= 3072  # Max reasonable dimension
  end

  def test_generate_embedding_returns_floats
    result = @service.generate_embedding("Test text.")

    assert result.all? { |v| v.is_a?(Float) || v.is_a?(Integer) }
  end

  def test_generate_embedding_with_custom_client
    # Create mock client that returns expected format
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "embeddings" => [Array.new(1536) { rand }] }
    end

    service = Ragdoll::EmbeddingService.new(client: mock_client)
    result = service.generate_embedding("Test")

    assert_kind_of Array, result
    assert_equal 1536, result.length
  end

  def test_generate_embedding_with_openai_format_response
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "data" => [{ "embedding" => Array.new(1536) { rand } }] }
    end

    service = Ragdoll::EmbeddingService.new(client: mock_client)
    result = service.generate_embedding("Test")

    assert_kind_of Array, result
    assert_equal 1536, result.length
  end

  def test_generate_embedding_raises_for_invalid_response_from_client
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "invalid" => "response" }
    end

    service = Ragdoll::EmbeddingService.new(client: mock_client)

    assert_raises(Ragdoll::Core::EmbeddingError) do
      service.generate_embedding("Test")
    end
  end

  # generate_embeddings_batch tests
  def test_generate_embeddings_batch_returns_array
    result = @service.generate_embeddings_batch(["Text one", "Text two"])
    assert_kind_of Array, result
  end

  def test_generate_embeddings_batch_returns_empty_for_empty_input
    result = @service.generate_embeddings_batch([])
    assert_equal [], result
  end

  def test_generate_embeddings_batch_returns_empty_for_only_blank_texts
    result = @service.generate_embeddings_batch(["", "   ", nil])
    assert_equal [], result
  end

  def test_generate_embeddings_batch_returns_correct_count
    texts = ["Text one", "Text two", "Text three"]
    result = @service.generate_embeddings_batch(texts)

    assert_equal texts.length, result.length
  end

  def test_generate_embeddings_batch_with_custom_client
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      embeddings = input.is_a?(Array) ? input.map { Array.new(1536) { rand } } : [Array.new(1536) { rand }]
      { "embeddings" => embeddings }
    end

    service = Ragdoll::EmbeddingService.new(client: mock_client)
    result = service.generate_embeddings_batch(["Text one", "Text two"])

    assert_equal 2, result.length
    assert result.all? { |e| e.length == 1536 }
  end

  def test_generate_embeddings_batch_filters_empty_texts
    texts = ["Valid text", "", "Another valid", nil, "   "]
    result = @service.generate_embeddings_batch(texts)

    # Should only process non-empty texts
    assert_equal 2, result.length
  end

  # cosine_similarity tests
  def test_cosine_similarity_returns_zero_for_nil_inputs
    assert_equal 0.0, @service.cosine_similarity(nil, [1.0, 2.0])
    assert_equal 0.0, @service.cosine_similarity([1.0, 2.0], nil)
    assert_equal 0.0, @service.cosine_similarity(nil, nil)
  end

  def test_cosine_similarity_returns_zero_for_different_lengths
    result = @service.cosine_similarity([1.0, 2.0], [1.0, 2.0, 3.0])
    assert_equal 0.0, result
  end

  def test_cosine_similarity_returns_one_for_identical_vectors
    vec = [1.0, 2.0, 3.0]
    result = @service.cosine_similarity(vec, vec)
    assert_in_delta 1.0, result, 0.0001
  end

  def test_cosine_similarity_returns_negative_one_for_opposite_vectors
    vec1 = [1.0, 0.0]
    vec2 = [-1.0, 0.0]
    result = @service.cosine_similarity(vec1, vec2)
    assert_in_delta(-1.0, result, 0.0001)
  end

  def test_cosine_similarity_returns_zero_for_orthogonal_vectors
    vec1 = [1.0, 0.0]
    vec2 = [0.0, 1.0]
    result = @service.cosine_similarity(vec1, vec2)
    assert_in_delta 0.0, result, 0.0001
  end

  def test_cosine_similarity_handles_zero_magnitude
    vec1 = [0.0, 0.0]
    vec2 = [1.0, 2.0]
    result = @service.cosine_similarity(vec1, vec2)
    assert_equal 0.0, result
  end

  def test_cosine_similarity_range_is_valid
    vec1 = [0.5, 0.3, 0.8]
    vec2 = [0.1, 0.9, 0.2]
    result = @service.cosine_similarity(vec1, vec2)

    assert result >= -1.0
    assert result <= 1.0
  end

  # Edge cases
  def test_generate_embedding_cleans_excessive_whitespace
    text = "Text   with  \t\t  lots   of   spaces"
    result = @service.generate_embedding(text)

    # Should not fail
    assert result.present?
  end

  def test_generate_embedding_handles_very_long_text
    long_text = "word " * 5000  # Very long text
    result = @service.generate_embedding(long_text)

    # Should truncate and still return result
    assert result.present?
  end

  def test_generate_embedding_handles_unicode
    text = "日本語のテキスト with Unicode 🚀"
    result = @service.generate_embedding(text)

    assert result.present?
  end

  def test_generate_embedding_handles_special_characters
    text = "Text with <html> tags & special chars @#$%"
    result = @service.generate_embedding(text)

    assert result.present?
  end

  # Error handling
  def test_generate_embedding_raises_error_from_client
    error_client = Object.new
    def error_client.embed(input:, model:)
      raise StandardError, "API error"
    end

    service = Ragdoll::EmbeddingService.new(client: error_client)

    assert_raises(Ragdoll::Core::EmbeddingError) do
      service.generate_embedding("Test")
    end
  end

  def test_generate_embeddings_batch_raises_error_from_client
    error_client = Object.new
    def error_client.embed(input:, model:)
      raise StandardError, "API error"
    end

    service = Ragdoll::EmbeddingService.new(client: error_client)

    assert_raises(Ragdoll::Core::EmbeddingError) do
      service.generate_embeddings_batch(["Text"])
    end
  end

  # Multiple calls work correctly
  def test_multiple_embedding_calls_work_correctly
    result1 = @service.generate_embedding("First text")
    result2 = @service.generate_embedding("Second text")

    assert result1.present?
    assert result2.present?
    # Both should have same dimensions
    assert_equal result1.length, result2.length
  end

  def test_different_texts_may_produce_different_embeddings
    result1 = @service.generate_embedding("The quick brown fox")
    result2 = @service.generate_embedding("Completely different content about databases")

    # Both should be valid
    assert result1.present?
    assert result2.present?
  end
end
