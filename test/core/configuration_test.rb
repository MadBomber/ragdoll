# frozen_string_literal: true

require_relative "../test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    super
    # Reset configuration to ensure clean state
    Ragdoll::Core.reset_configuration!
    @config = Ragdoll::Core::Config.new
  end

  def teardown
    super
    Ragdoll::Core.reset_configuration!
  end

  def test_default_values
    # Test new configuration structure using method-based access
    assert_equal "openai/gpt-4o", @config.default_model
    assert_equal "openai/gpt-4o", @config.summary_model # Inherits from default
    assert_equal "openai/gpt-4o", @config.keywords_model # Inherits from default
    assert_equal "nomic-embed-text:latest", @config.embedding_model
    assert_equal 1000, @config.chunk_size
    assert_equal 200, @config.chunk_overlap
    assert_equal 0.7, @config.similarity_threshold
    assert_equal 10, @config.max_results
    assert_equal :ollama, @config.embedding_provider
    assert @config.cache_embeddings?
    assert_equal 3072, @config.max_embedding_dimension
    assert @config.summarization_enabled?

    # Test analytics accessors - test environment has analytics disabled
    if @config.test?
      refute @config.analytics_enabled?
    else
      assert @config.analytics_enabled?
    end
    # usage_tracking is based on analytics.enabled OR usage_tracking_enabled
    assert_respond_to @config, :usage_tracking?

    # Test logging - development environment overrides to debug
    expected_level = @config.development? ? :debug : (@config.test? ? :warn : :info)
    assert_equal expected_level, @config.log_level

    # Test base directory usage
    assert_includes @config.base_directory, "ragdoll"
    assert_includes @config.config_filepath, "config.yml"

    # Test prompt templates
    template = @config.prompt_template(:rag_enhancement)
    refute_nil template
    assert_includes template, "Context:"
  end

  def test_providers_defaults
    # Test providers structure via ConfigSection
    assert_equal :openai, @config.default_provider

    # Check that all expected providers are accessible
    refute_nil @config.providers.openai
    refute_nil @config.providers.anthropic
    refute_nil @config.providers.google
    refute_nil @config.providers.azure
    refute_nil @config.providers.ollama
    refute_nil @config.providers.huggingface
  end

  def test_openai_api_key_from_env
    # Test that OpenAI API key comes from environment
    original_env = ENV["RAGDOLL_PROVIDERS__OPENAI__API_KEY"]
    ENV["RAGDOLL_PROVIDERS__OPENAI__API_KEY"] = "test-key"

    begin
      Ragdoll::Core.reset_configuration!
      config = Ragdoll::Core::Config.new
      assert_equal "test-key", config.openai_api_key
    ensure
      if original_env
        ENV["RAGDOLL_PROVIDERS__OPENAI__API_KEY"] = original_env
      else
        ENV.delete("RAGDOLL_PROVIDERS__OPENAI__API_KEY")
      end
    end
  end

  def test_anthropic_api_key_from_env
    original_env = ENV["RAGDOLL_PROVIDERS__ANTHROPIC__API_KEY"]
    ENV["RAGDOLL_PROVIDERS__ANTHROPIC__API_KEY"] = "anthropic-key"

    begin
      Ragdoll::Core.reset_configuration!
      config = Ragdoll::Core::Config.new
      assert_equal "anthropic-key", config.anthropic_api_key
    ensure
      if original_env
        ENV["RAGDOLL_PROVIDERS__ANTHROPIC__API_KEY"] = original_env
      else
        ENV.delete("RAGDOLL_PROVIDERS__ANTHROPIC__API_KEY")
      end
    end
  end

  def test_ollama_url_default
    assert_equal "http://localhost:11434", @config.ollama_url
  end

  def test_ollama_url_from_env
    original_env = ENV["RAGDOLL_PROVIDERS__OLLAMA__URL"]
    ENV["RAGDOLL_PROVIDERS__OLLAMA__URL"] = "http://custom:11434"

    begin
      Ragdoll::Core.reset_configuration!
      config = Ragdoll::Core::Config.new
      assert_equal "http://custom:11434", config.ollama_url
    ensure
      if original_env
        ENV["RAGDOLL_PROVIDERS__OLLAMA__URL"] = original_env
      else
        ENV.delete("RAGDOLL_PROVIDERS__OLLAMA__URL")
      end
    end
  end

  def test_current_configuration_structure_accessible
    # Test that configuration sections are accessible
    assert_respond_to @config, :embedding
    assert_respond_to @config, :generation
    assert_respond_to @config, :chunking
    assert_respond_to @config, :search
    assert_respond_to @config, :analytics
    assert_respond_to @config, :database
    assert_respond_to @config, :providers

    # Test ConfigSection method access
    refute_nil @config.embedding.provider
    refute_nil @config.embedding.model
    refute_nil @config.database.adapter
    refute_nil @config.database.host
  end

  def test_providers_structure
    # Check that all expected providers are present as ConfigSections
    assert_respond_to @config.providers, :openai
    assert_respond_to @config.providers, :anthropic
    assert_respond_to @config.providers, :google
    assert_respond_to @config.providers, :azure
    assert_respond_to @config.providers, :ollama
    assert_respond_to @config.providers, :huggingface

    # Check specific structures via hash access
    assert_equal "http://localhost:11434", @config.providers.ollama.url
  end

  def test_database_config_structure
    # Test database structure via ConfigSection
    assert_equal "postgresql", @config.database.adapter
    assert_equal "localhost", @config.database.host
    assert_equal 5432, @config.database.port
  end

  def test_database_config_hash
    # Test database_config returns ActiveRecord-compatible hash
    db_config = @config.database_config
    assert_instance_of Hash, db_config
    assert_equal "postgresql", db_config[:adapter]
    assert_equal "localhost", db_config[:host]
  end

  def test_embedding_config
    assert_equal :ollama, @config.embedding_provider
    assert_equal "nomic-embed-text:latest", @config.embedding_model
    assert_equal 1536, @config.embedding_dimensions
    assert_equal 120, @config.embedding_timeout
  end

  def test_chunking_config
    assert_equal 1000, @config.chunk_size
    assert_equal 200, @config.chunk_overlap
  end

  def test_search_config
    assert_equal 0.7, @config.similarity_threshold
    assert_equal 10, @config.max_results
  end

  def test_circuit_breaker_config
    assert_equal 5, @config.circuit_breaker_failure_threshold
    assert_equal 60, @config.circuit_breaker_reset_timeout
    assert_equal 3, @config.circuit_breaker_half_open_max_calls
  end

  def test_environment_helpers
    assert_respond_to @config, :test?
    assert_respond_to @config, :development?
    assert_respond_to @config, :production?
    assert_respond_to @config, :environment
  end

  def test_prompt_template_access
    template = @config.prompt_template(:rag_enhancement)
    refute_nil template
    assert_includes template, "Context:"
    assert_includes template, "{{context}}"
    assert_includes template, "{{prompt}}"
  end

  def test_provider_credentials
    credentials = @config.provider_credentials(:ollama)
    assert_instance_of Hash, credentials
  end

  def test_configure_ruby_llm
    # Should not raise an error
    assert_respond_to @config, :configure_ruby_llm
  end

  def test_normalize_ollama_model
    # Test model name normalization
    assert_equal "llama2:latest", @config.normalize_ollama_model("llama2")
    assert_equal "nomic-embed-text:latest", @config.normalize_ollama_model("nomic-embed-text:latest")
  end

  # Backward compatibility tests
  def test_backward_compat_models_hash
    models = @config.models
    assert_instance_of Hash, models
    assert models.key?(:text_generation)
    assert models.key?(:embedding)
  end

  def test_backward_compat_processing_hash
    processing = @config.processing
    assert_instance_of Hash, processing
    assert processing.key?(:text)
    assert processing.key?(:search)
  end

  def test_backward_compat_llm_providers_hash
    providers = @config.llm_providers
    assert_instance_of Hash, providers
    assert providers.key?(:default_provider)
    assert providers.key?(:openai)
    assert providers.key?(:ollama)
  end

  def test_configuration_alias
    # Test that Configuration is an alias for Config
    assert_equal Ragdoll::Core::Config, Ragdoll::Core::Configuration
  end
end
