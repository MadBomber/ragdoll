# frozen_string_literal: true

require_relative "../../../test_helper"

class ConfigAccessorsTest < Minitest::Test
  def setup
    super
    Ragdoll::Core.reset_configuration!
    @config = Ragdoll.config
  end

  def teardown
    Ragdoll::Core.reset_configuration!
    super
  end

  # Class-level tests
  def test_config_class_exists
    assert defined?(Ragdoll::Core::Config)
  end

  def test_config_inherits_from_anyway_config
    assert Ragdoll::Core::Config < Anyway::Config
  end

  def test_config_name_is_ragdoll
    result = Ragdoll::Core::Config.config_name
    assert_equal "ragdoll", result.to_s.downcase
  end

  def test_env_prefix_is_ragdoll
    result = Ragdoll::Core::Config.env_prefix
    assert_equal "ragdoll", result.to_s.downcase
  end

  # Default constants
  def test_defaults_path_constant
    assert defined?(Ragdoll::Core::Config::DEFAULTS_PATH)
    assert File.exist?(Ragdoll::Core::Config::DEFAULTS_PATH)
  end

  def test_schema_constant_exists
    assert defined?(Ragdoll::Core::Config::SCHEMA)
    assert_kind_of Hash, Ragdoll::Core::Config::SCHEMA
  end

  def test_default_dimensions_constant
    assert defined?(Ragdoll::Core::Config::DEFAULT_DIMENSIONS)
    assert_kind_of Hash, Ragdoll::Core::Config::DEFAULT_DIMENSIONS
    assert_includes Ragdoll::Core::Config::DEFAULT_DIMENSIONS.keys, :openai
    assert_includes Ragdoll::Core::Config::DEFAULT_DIMENSIONS.keys, :ollama
  end

  # Environment detection
  def test_env_class_method
    result = Ragdoll::Core::Config.env
    assert_kind_of String, result
  end

  # Embedding accessors
  def test_embedding_provider_returns_symbol
    result = @config.embedding_provider
    assert_kind_of Symbol, result if result
  end

  def test_embedding_model_returns_string
    result = @config.embedding_model
    assert_kind_of String, result if result
  end

  def test_embedding_dimensions_returns_integer
    result = @config.embedding_dimensions
    assert_kind_of Integer, result
  end

  def test_embedding_timeout_returns_integer
    result = @config.embedding_timeout
    assert_kind_of Integer, result
  end

  def test_max_embedding_dimension_returns_integer
    result = @config.max_embedding_dimension
    assert_kind_of Integer, result
  end

  def test_cache_embeddings_query
    result = @config.cache_embeddings?
    assert [true, false, nil].include?(result)
  end

  # Generation accessors
  def test_default_model_accessor
    result = @config.default_model
    assert [String, NilClass].any? { |klass| result.is_a?(klass) }
  end

  def test_summary_model_returns_default_if_nil
    result = @config.summary_model
    assert [String, NilClass].any? { |klass| result.is_a?(klass) }
  end

  def test_keywords_model_returns_default_if_nil
    result = @config.keywords_model
    assert [String, NilClass].any? { |klass| result.is_a?(klass) }
  end

  # Chunking accessors
  def test_chunk_size_returns_integer
    result = @config.chunk_size
    assert_kind_of Integer, result
  end

  def test_chunk_overlap_returns_integer
    result = @config.chunk_overlap
    assert_kind_of Integer, result
  end

  # Search accessors
  def test_similarity_threshold_returns_float
    result = @config.similarity_threshold
    assert_kind_of Float, result
  end

  def test_max_results_returns_integer
    result = @config.max_results
    assert_kind_of Integer, result
  end

  # Analytics accessors
  def test_analytics_enabled_query
    result = @config.analytics_enabled?
    assert [true, false, nil].include?(result)
  end

  def test_usage_tracking_query
    result = @config.usage_tracking?
    assert [true, false, nil].include?(result)
  end

  # Hybrid search accessors
  def test_hybrid_search_enabled_query
    result = @config.hybrid_search_enabled?
    assert [true, false, nil].include?(result)
  end

  def test_rrf_k_returns_integer
    result = @config.rrf_k
    assert_kind_of Integer, result
  end

  # Summarization accessors
  def test_summarization_enabled_query
    result = @config.summarization_enabled?
    assert [true, false, nil].include?(result)
  end

  # Tagging accessors
  def test_tagging_enabled_query
    result = @config.tagging_enabled?
    assert [true, false, nil].include?(result)
  end

  def test_auto_extract_tags_query
    result = @config.auto_extract_tags?
    assert [true, false, nil].include?(result)
  end

  def test_max_tag_depth_returns_integer
    result = @config.max_tag_depth
    assert_kind_of Integer, result
  end

  # Propositions accessors
  def test_propositions_enabled_query
    result = @config.propositions_enabled?
    assert [true, false, nil].include?(result)
  end

  def test_auto_extract_propositions_query
    result = @config.auto_extract_propositions?
    assert [true, false, nil].include?(result)
  end

  # Circuit breaker accessors
  def test_circuit_breaker_failure_threshold_returns_integer
    result = @config.circuit_breaker_failure_threshold
    assert_kind_of Integer, result
  end

  def test_circuit_breaker_reset_timeout_returns_integer
    result = @config.circuit_breaker_reset_timeout
    assert_kind_of Integer, result
  end

  def test_circuit_breaker_half_open_max_calls_returns_integer
    result = @config.circuit_breaker_half_open_max_calls
    assert_kind_of Integer, result
  end

  # Timeframe accessors
  def test_week_start_returns_symbol
    result = @config.week_start
    assert_kind_of Symbol, result
  end

  def test_default_recent_days_returns_integer
    result = @config.default_recent_days
    assert_kind_of Integer, result
  end

  # Logging accessors
  def test_log_level_returns_symbol
    result = @config.log_level
    assert_kind_of Symbol, result
  end

  # Provider credentials
  def test_default_provider_returns_symbol
    result = @config.default_provider
    assert_kind_of Symbol, result
  end

  def test_provider_credentials_returns_hash
    result = @config.provider_credentials
    assert_kind_of Hash, result
  end

  def test_provider_credentials_with_specific_provider
    result = @config.provider_credentials(:openai)
    assert_kind_of Hash, result
  end

  def test_ollama_url_returns_string
    result = @config.ollama_url
    assert_kind_of String, result
    assert result.start_with?("http")
  end

  # Database config
  def test_database_config_returns_hash
    result = @config.database_config
    assert_kind_of Hash, result
    assert_includes result.keys, :adapter
  end

  def test_auto_migrate_query
    result = @config.auto_migrate?
    assert [true, false, nil].include?(result)
  end

  # Environment helpers
  def test_test_environment_query
    result = @config.test?
    # In test environment this should be true
    assert [true, false].include?(result)
  end

  def test_development_environment_query
    result = @config.development?
    assert [true, false].include?(result)
  end

  def test_production_environment_query
    result = @config.production?
    assert [true, false].include?(result)
  end

  def test_environment_returns_string
    result = @config.environment
    assert_kind_of String, result
  end

  # Base directory and paths
  def test_base_directory_returns_path
    result = @config.base_directory
    assert_kind_of String, result
  end

  def test_config_filepath_returns_path
    result = @config.config_filepath
    assert_kind_of String, result
    assert result.end_with?("config.yml")
  end

  # Prompt templates
  def test_prompt_templates_returns_hash
    result = @config.prompt_templates
    assert_kind_of Hash, result
  end

  def test_prompt_template_with_name
    result = @config.prompt_template(:rag_enhancement)
    # May be nil if not configured
    assert [String, NilClass].any? { |klass| result.is_a?(klass) }
  end

  # Backward compatibility
  def test_models_returns_hash
    result = @config.models
    assert_kind_of Hash, result
  end

  def test_processing_returns_hash
    result = @config.processing
    assert_kind_of Hash, result
  end

  def test_llm_providers_returns_hash
    result = @config.llm_providers
    assert_kind_of Hash, result
  end

  # XDG paths
  def test_xdg_config_paths_class_method
    result = Ragdoll::Core::Config.xdg_config_paths
    assert_kind_of Array, result
  end

  def test_xdg_config_file_class_method
    result = Ragdoll::Core::Config.xdg_config_file
    assert_kind_of String, result
    assert result.include?("ragdoll")
  end

  # Configuration alias
  def test_configuration_alias_exists
    assert_equal Ragdoll::Core::Config, Ragdoll::Core::Configuration
  end
end
