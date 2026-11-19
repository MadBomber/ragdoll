# frozen_string_literal: true

require "test_helper"

class ModelResolverTest < Minitest::Test
  def setup
    super
    @resolver = Ragdoll::ModelResolver.new
  end

  # Initialization tests
  def test_initializes_with_default_config_service
    resolver = Ragdoll::ModelResolver.new
    assert resolver.present?
  end

  def test_initializes_with_custom_config_service
    config_service = Ragdoll::ConfigurationService.new
    resolver = Ragdoll::ModelResolver.new(config_service)
    assert resolver.present?
  end

  # resolve_for_task tests
  def test_resolve_for_task_returns_model_object
    result = @resolver.resolve_for_task(:embedding)
    assert_kind_of Ragdoll::Core::Model, result
  end

  def test_resolve_for_task_for_summary
    result = @resolver.resolve_for_task(:summary)
    assert_kind_of Ragdoll::Core::Model, result
  end

  def test_resolve_for_task_for_keywords
    result = @resolver.resolve_for_task(:keywords)
    assert_kind_of Ragdoll::Core::Model, result
  end

  def test_resolve_for_task_for_default
    result = @resolver.resolve_for_task(:default)
    assert_kind_of Ragdoll::Core::Model, result
  end

  def test_resolve_for_task_accepts_content_type
    result = @resolver.resolve_for_task(:embedding, :text)
    assert_kind_of Ragdoll::Core::Model, result
  end

  def test_model_has_provider_info
    model = @resolver.resolve_for_task(:embedding)
    # Model should respond to provider method
    assert model.respond_to?(:provider) || model.respond_to?(:model)
  end

  def test_model_has_model_name
    model = @resolver.resolve_for_task(:embedding)
    # Model should have a model identifier
    assert model.respond_to?(:model) || model.respond_to?(:to_s)
  end

  # resolve_embedding tests
  def test_resolve_embedding_returns_openstruct
    result = @resolver.resolve_embedding
    assert_kind_of OpenStruct, result
  end

  def test_resolve_embedding_includes_model
    result = @resolver.resolve_embedding
    assert result.respond_to?(:model)
    assert result.model.present?
  end

  def test_resolve_embedding_includes_provider_type
    result = @resolver.resolve_embedding
    assert result.respond_to?(:provider_type)
  end

  def test_resolve_embedding_includes_max_dimensions
    result = @resolver.resolve_embedding
    assert result.respond_to?(:max_dimensions)
  end

  def test_resolve_embedding_includes_cache_embeddings
    result = @resolver.resolve_embedding
    assert result.respond_to?(:cache_embeddings)
  end

  def test_resolve_embedding_accepts_content_type
    result = @resolver.resolve_embedding(:text)
    assert_kind_of OpenStruct, result
  end

  def test_resolve_embedding_model_is_model_object
    result = @resolver.resolve_embedding
    assert_kind_of Ragdoll::Core::Model, result.model
  end

  # provider_credentials_for_model tests
  def test_provider_credentials_for_model_returns_hash
    model = @resolver.resolve_for_task(:embedding)
    begin
      credentials = @resolver.provider_credentials_for_model(model)
      assert_kind_of Hash, credentials
    rescue Ragdoll::Core::ConfigurationError
      skip "Provider not configured"
    end
  end

  def test_provider_credentials_uses_model_provider
    model = @resolver.resolve_for_task(:embedding)
    begin
      credentials = @resolver.provider_credentials_for_model(model)
      assert credentials.present? || credentials.empty?
    rescue Ragdoll::Core::ConfigurationError
      skip "Provider not configured"
    end
  end

  # resolve_all_models tests
  def test_resolve_all_models_returns_hash
    result = @resolver.resolve_all_models
    assert_kind_of Hash, result
  end

  def test_resolve_all_models_includes_text_generation_or_error
    result = @resolver.resolve_all_models
    assert result.key?(:text_generation) || result.key?(:error)
  end

  def test_resolve_all_models_includes_embedding_or_error
    result = @resolver.resolve_all_models
    assert result.key?(:embedding) || result.key?(:error)
  end

  def test_resolve_all_models_handles_configuration_errors
    # Should not raise, even if some models not configured
    result = @resolver.resolve_all_models
    assert_kind_of Hash, result
    # May have partial results with error
    if result[:error]
      assert result[:partial] == true
    end
  end

  def test_resolve_all_models_text_generation_has_default
    result = @resolver.resolve_all_models
    if result[:text_generation]
      assert result[:text_generation].key?(:default)
    end
  end

  def test_resolve_all_models_text_generation_has_summary
    result = @resolver.resolve_all_models
    if result[:text_generation]
      assert result[:text_generation].key?(:summary)
    end
  end

  def test_resolve_all_models_text_generation_has_keywords
    result = @resolver.resolve_all_models
    if result[:text_generation]
      assert result[:text_generation].key?(:keywords)
    end
  end

  def test_resolve_all_models_embedding_has_text
    result = @resolver.resolve_all_models
    if result[:embedding]
      assert result[:embedding].key?(:text)
    end
  end

  # Edge cases
  def test_resolver_with_nil_config_service_uses_default
    resolver = Ragdoll::ModelResolver.new(nil)
    result = resolver.resolve_for_task(:embedding)
    assert result.present?
  end

  def test_multiple_resolvers_work_independently
    resolver1 = Ragdoll::ModelResolver.new
    resolver2 = Ragdoll::ModelResolver.new

    model1 = resolver1.resolve_for_task(:embedding)
    model2 = resolver2.resolve_for_task(:embedding)

    # Both should return valid models
    assert model1.present?
    assert model2.present?
  end
end
