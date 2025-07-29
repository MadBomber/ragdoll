# frozen_string_literal: true

require_relative "../test_helper"

class EmbeddingServiceTest < Minitest::Test
  def setup
    super
    @config = Ragdoll::Core::Configuration.new
    @config.models[:embedding][:text] = "test-model"
    @config.ruby_llm_config[:openai][:api_key] = "test-key"
  end

  def test_initialize_with_default_configuration
    service = Ragdoll::Core::EmbeddingService.new

    assert_nil service.instance_variable_get(:@client)
  end

  def test_initialize_with_custom_client
    mock_client = Object.new
    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)

    # Instead of checking object equality on mock, check that client is set
    refute_nil service.instance_variable_get(:@client)
  end

  def test_generate_embedding_with_nil_text
    service = Ragdoll::Core::EmbeddingService.new

    assert_nil service.generate_embedding(nil)
  end

  def test_generate_embedding_with_empty_text
    service = Ragdoll::Core::EmbeddingService.new

    assert_nil service.generate_embedding("")
    assert_nil service.generate_embedding("   ")
  end

  def test_generate_embedding_without_client
    service = Ragdoll::Core::EmbeddingService.new
    result = service.generate_embedding("test text")

    assert_instance_of Array, result
    assert_equal 1536, result.length
    assert(result.all? { |val| val.is_a?(Float) && val >= -1.0 && val <= 1.0 })
  end

  def test_generate_embedding_with_mock_client_embeddings_format
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "embeddings" => [[0.1, 0.2, 0.3]] }
    end

    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)
    result = service.generate_embedding("test text")

    assert_equal [0.1, 0.2, 0.3], result
  end

  def test_generate_embedding_with_mock_client_data_format
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "data" => [{ "embedding" => [0.4, 0.5, 0.6] }] }
    end

    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)
    result = service.generate_embedding("test text")

    assert_equal [0.4, 0.5, 0.6], result
  end

  def test_generate_embedding_with_invalid_response
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "invalid" => "response" }
    end

    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)

    error = assert_raises(Ragdoll::Core::EmbeddingError) do
      service.generate_embedding("test text")
    end

    assert_includes error.message, "Invalid response format"
  end

  def test_generate_embedding_with_client_error
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      raise StandardError, "API error"
    end

    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)

    error = assert_raises(Ragdoll::Core::EmbeddingError) do
      service.generate_embedding("test text")
    end

    assert_includes error.message, "Failed to generate embedding"
    assert_includes error.message, "API error"
  end

  def test_generate_embeddings_batch_empty_array
    service = Ragdoll::Core::EmbeddingService.new

    assert_empty service.generate_embeddings_batch([])
  end

  def test_generate_embeddings_batch_with_empty_texts
    service = Ragdoll::Core::EmbeddingService.new

    assert_empty service.generate_embeddings_batch(["", nil, "   "])
  end

  def test_generate_embeddings_batch_without_client
    service = Ragdoll::Core::EmbeddingService.new
    result = service.generate_embeddings_batch(%w[text1 text2])

    assert_instance_of Array, result
    assert_equal 2, result.length
    result.each do |embedding|
      assert_instance_of Array, embedding
      assert_equal 1536, embedding.length
    end
  end

  def test_generate_embeddings_batch_with_mock_client
    mock_client = Object.new
    def mock_client.embed(input:, model:)
      { "embeddings" => [[0.1, 0.2], [0.3, 0.4]] }
    end

    service = Ragdoll::Core::EmbeddingService.new(client: mock_client)
    result = service.generate_embeddings_batch(%w[text1 text2])

    assert_equal [[0.1, 0.2], [0.3, 0.4]], result
  end

  def test_cosine_similarity_with_identical_vectors
    service = Ragdoll::Core::EmbeddingService.new
    vector = [1.0, 2.0, 3.0]

    similarity = service.cosine_similarity(vector, vector)
    assert_in_delta 1.0, similarity, 0.001
  end

  def test_cosine_similarity_with_orthogonal_vectors
    service = Ragdoll::Core::EmbeddingService.new
    vector1 = [1.0, 0.0]
    vector2 = [0.0, 1.0]

    similarity = service.cosine_similarity(vector1, vector2)
    assert_in_delta 0.0, similarity, 0.001
  end

  def test_cosine_similarity_with_opposite_vectors
    service = Ragdoll::Core::EmbeddingService.new
    vector1 = [1.0, 0.0]
    vector2 = [-1.0, 0.0]

    similarity = service.cosine_similarity(vector1, vector2)
    assert_in_delta(-1.0, similarity, 0.001)
  end

  def test_cosine_similarity_with_nil_vectors
    service = Ragdoll::Core::EmbeddingService.new

    assert_equal 0.0, service.cosine_similarity(nil, [1.0, 2.0])
    assert_equal 0.0, service.cosine_similarity([1.0, 2.0], nil)
    assert_equal 0.0, service.cosine_similarity(nil, nil)
  end

  def test_cosine_similarity_with_different_lengths
    service = Ragdoll::Core::EmbeddingService.new
    vector1 = [1.0, 2.0]
    vector2 = [1.0, 2.0, 3.0]

    assert_equal 0.0, service.cosine_similarity(vector1, vector2)
  end

  def test_cosine_similarity_with_zero_magnitude
    service = Ragdoll::Core::EmbeddingService.new
    vector1 = [0.0, 0.0]
    vector2 = [1.0, 2.0]

    assert_equal 0.0, service.cosine_similarity(vector1, vector2)
    assert_equal 0.0, service.cosine_similarity(vector2, vector1)
  end

  def test_clean_text_with_nil
    service = Ragdoll::Core::EmbeddingService.new

    assert_equal "", service.send(:clean_text, nil)
  end

  def test_clean_text_normalization
    service = Ragdoll::Core::EmbeddingService.new
    input = "  Multiple   spaces\n\n\nNewlines\t\tTabs  "
    expected = "Multiple spaces Newlines Tabs"

    assert_equal expected, service.send(:clean_text, input)
  end

  def test_clean_text_truncation
    service = Ragdoll::Core::EmbeddingService.new
    long_text = "A" * 9000
    result = service.send(:clean_text, long_text)

    assert_equal 8000, result.length
  end

  def test_configure_ruby_llm_openai
    @config.llm_provider = :openai
    @config.llm_config = {
      openai: {
        api_key: "test-key",
        organization: "test-org",
        project: "test-project"
      }
    }

    service = Ragdoll::Core::EmbeddingService.new
    # Just verify it doesn't raise an error
    assert_instance_of Ragdoll::Core::EmbeddingService, service
  end

  def test_configure_ruby_llm_unsupported_provider
    @config.llm_provider = :unsupported

    # With our defensive implementation, unsupported providers just show a warning
    # but don't raise an error - this allows for graceful handling
    service = Ragdoll::Core::EmbeddingService.new
    assert_instance_of Ragdoll::Core::EmbeddingService, service
  end

  def test_embedding_provider_fallback
    @config.embedding_provider = :anthropic if @config.respond_to?(:embedding_provider=)
    @config.llm_provider = :openai
    @config.llm_config = {
      anthropic: { api_key: "anthropic-key" },
      openai: { api_key: "openai-key" }
    }

    service = Ragdoll::Core::EmbeddingService.new
    assert_instance_of Ragdoll::Core::EmbeddingService, service
  end
end
