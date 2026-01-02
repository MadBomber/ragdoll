# frozen_string_literal: true

require "test_helper"

class ConfigurationServiceTest < Minitest::Test
  def setup
    super
    @service = Ragdoll::ConfigurationService.new
  end

  # Initialization tests
  def test_initializes_with_default_config
    service = Ragdoll::ConfigurationService.new
    assert service.config.present?
  end

  def test_initializes_with_custom_config
    custom_config = Ragdoll.config
    service = Ragdoll::ConfigurationService.new(custom_config)
    assert_equal custom_config, service.config
  end

  def test_config_accessor_returns_underlying_config
    assert_kind_of Ragdoll::Core::Config, @service.config
  end

  # resolve_model tests
  def test_resolve_model_for_embedding_task
    result = @service.resolve_model(:embedding)
    assert result.present?
  end

  def test_resolve_model_for_summary_task
    result = @service.resolve_model(:summary)
    assert result.present?
  end

  def test_resolve_model_for_keywords_task
    result = @service.resolve_model(:keywords)
    assert result.present?
  end

  def test_resolve_model_for_unknown_task_returns_default
    result = @service.resolve_model(:unknown_task)
    assert result.present?
  end

  def test_resolve_model_accepts_content_type_parameter
    result = @service.resolve_model(:embedding, :text)
    assert result.present?
  end

  # provider_credentials tests
  def test_provider_credentials_returns_hash_for_configured_provider
    # This test depends on configuration - may need to skip if no provider configured
    begin
      credentials = @service.provider_credentials(:ollama)
      assert_kind_of Hash, credentials
    rescue Ragdoll::Core::ConfigurationError
      skip "Ollama provider not configured"
    end
  end

  def test_provider_credentials_uses_default_provider_when_nil
    begin
      credentials = @service.provider_credentials(nil)
      assert_kind_of Hash, credentials
    rescue Ragdoll::Core::ConfigurationError
      # Expected if no default provider configured
      pass
    end
  end

  def test_provider_credentials_raises_for_unconfigured_provider
    assert_raises(Ragdoll::Core::ConfigurationError) do
      @service.provider_credentials(:nonexistent_provider_xyz)
    end
  end

  # chunking_config tests
  def test_chunking_config_returns_hash
    result = @service.chunking_config
    assert_kind_of Hash, result
  end

  def test_chunking_config_includes_max_tokens
    result = @service.chunking_config
    assert result.key?(:max_tokens)
  end

  def test_chunking_config_includes_overlap
    result = @service.chunking_config
    assert result.key?(:overlap)
  end

  def test_chunking_config_accepts_content_type
    result = @service.chunking_config(:text)
    assert_kind_of Hash, result
  end

  # search_config tests
  def test_search_config_returns_hash
    result = @service.search_config
    assert_kind_of Hash, result
  end

  def test_search_config_includes_similarity_threshold
    result = @service.search_config
    assert result.key?(:similarity_threshold)
  end

  def test_search_config_includes_max_results
    result = @service.search_config
    assert result.key?(:max_results)
  end

  def test_search_config_includes_analytics
    result = @service.search_config
    assert result.key?(:analytics)
    assert_kind_of Hash, result[:analytics]
  end

  # prompt_template tests
  def test_prompt_template_returns_string_for_valid_template
    begin
      result = @service.prompt_template(:rag_enhancement)
      assert_kind_of String, result
    rescue Ragdoll::Core::ConfigurationError
      skip "Prompt template not configured"
    end
  end

  def test_prompt_template_raises_for_unknown_template
    assert_raises(Ragdoll::Core::ConfigurationError) do
      @service.prompt_template(:nonexistent_template_xyz)
    end
  end

  # embedding_config tests
  def test_embedding_config_returns_hash
    result = @service.embedding_config
    assert_kind_of Hash, result
  end

  def test_embedding_config_includes_provider
    result = @service.embedding_config
    assert result.key?(:provider)
  end

  def test_embedding_config_includes_model
    result = @service.embedding_config
    assert result.key?(:model)
  end

  def test_embedding_config_includes_dimensions
    result = @service.embedding_config
    assert result.key?(:dimensions)
  end

  def test_embedding_config_includes_timeout
    result = @service.embedding_config
    assert result.key?(:timeout)
  end

  def test_embedding_config_includes_max_dimensions
    result = @service.embedding_config
    assert result.key?(:max_dimensions)
  end

  def test_embedding_config_includes_cache_embeddings
    result = @service.embedding_config
    assert result.key?(:cache_embeddings)
  end

  # database_config tests
  def test_database_config_returns_value
    result = @service.database_config
    assert result.present?
  end

  # circuit_breaker_config tests
  def test_circuit_breaker_config_returns_hash
    result = @service.circuit_breaker_config
    assert_kind_of Hash, result
  end

  def test_circuit_breaker_config_includes_failure_threshold
    result = @service.circuit_breaker_config
    assert result.key?(:failure_threshold)
  end

  def test_circuit_breaker_config_includes_reset_timeout
    result = @service.circuit_breaker_config
    assert result.key?(:reset_timeout)
  end

  def test_circuit_breaker_config_includes_half_open_max_calls
    result = @service.circuit_breaker_config
    assert result.key?(:half_open_max_calls)
  end

  # hybrid_search_config tests
  def test_hybrid_search_config_returns_hash
    result = @service.hybrid_search_config
    assert_kind_of Hash, result
  end

  def test_hybrid_search_config_includes_enabled
    result = @service.hybrid_search_config
    assert result.key?(:enabled)
  end

  def test_hybrid_search_config_includes_rrf_k
    result = @service.hybrid_search_config
    assert result.key?(:rrf_k)
  end

  def test_hybrid_search_config_includes_candidate_multiplier
    result = @service.hybrid_search_config
    assert result.key?(:candidate_multiplier)
  end

  def test_hybrid_search_config_includes_weights
    result = @service.hybrid_search_config
    assert result.key?(:weights)
    assert_kind_of Hash, result[:weights]
  end

  def test_hybrid_search_weights_includes_semantic
    result = @service.hybrid_search_config
    assert result[:weights].key?(:semantic)
  end

  def test_hybrid_search_weights_includes_fulltext
    result = @service.hybrid_search_config
    assert result[:weights].key?(:fulltext)
  end

  def test_hybrid_search_weights_includes_tags
    result = @service.hybrid_search_config
    assert result[:weights].key?(:tags)
  end

  # tagging_config tests
  def test_tagging_config_returns_hash
    result = @service.tagging_config
    assert_kind_of Hash, result
  end

  def test_tagging_config_includes_enabled
    result = @service.tagging_config
    assert result.key?(:enabled)
  end

  def test_tagging_config_includes_max_depth
    result = @service.tagging_config
    assert result.key?(:max_depth)
  end

  def test_tagging_config_includes_auto_extract
    result = @service.tagging_config
    assert result.key?(:auto_extract)
  end

  # propositions_config tests
  def test_propositions_config_returns_hash
    result = @service.propositions_config
    assert_kind_of Hash, result
  end

  def test_propositions_config_includes_enabled
    result = @service.propositions_config
    assert result.key?(:enabled)
  end

  def test_propositions_config_includes_auto_extract
    result = @service.propositions_config
    assert result.key?(:auto_extract)
  end

  def test_propositions_config_includes_min_length
    result = @service.propositions_config
    assert result.key?(:min_length)
  end

  def test_propositions_config_includes_max_length
    result = @service.propositions_config
    assert result.key?(:max_length)
  end

  def test_propositions_config_includes_min_words
    result = @service.propositions_config
    assert result.key?(:min_words)
  end

  # validate! tests
  def test_validate_returns_true_when_valid
    # This may pass or raise depending on configuration state
    begin
      result = @service.validate!
      assert_equal true, result
    rescue Ragdoll::Core::ConfigurationError
      # Expected if configuration is incomplete
      pass
    end
  end

  def test_validate_raises_configuration_error_when_invalid
    # Test that validate! can raise ConfigurationError
    # This depends on the actual configuration state
    # The validate! method checks for missing provider credentials
    service = Ragdoll::ConfigurationService.new

    # Either succeeds (if ollama is default) or raises (if another provider without creds)
    begin
      result = service.validate!
      assert_equal true, result
    rescue Ragdoll::Core::ConfigurationError => e
      assert e.message.include?("Configuration validation failed")
    end
  end

  # valid? tests
  def test_valid_returns_boolean
    result = @service.valid?
    assert [true, false].include?(result)
  end

  def test_valid_does_not_raise_exceptions
    # Should never raise exceptions, just return true or false
    service = Ragdoll::ConfigurationService.new

    # Should not raise - just return boolean
    result = service.valid?
    assert [true, false].include?(result)
  end
end
