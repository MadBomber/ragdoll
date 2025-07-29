# frozen_string_literal: true

require_relative "../test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    super
    @config = Ragdoll::Core::Configuration.new
  end

  def test_default_values
    # Test current configuration structure
    assert_equal "openai/gpt-4o", @config.models[:default]
    assert_equal "openai/gpt-4o", @config.models[:summary]
    assert_equal "text-embedding-3-small", @config.models[:embedding][:text]
    assert_equal 1000, @config.chunking[:text][:max_tokens]
    assert_equal 200, @config.chunking[:text][:overlap]
    assert_equal 0.7, @config.search[:similarity_threshold]
    assert_equal 10, @config.search[:max_results]
    assert_equal :openai, @config.embedding_config[:provider]
    assert @config.embedding_config[:cache_embeddings]
    assert_equal 3072, @config.embedding_config[:max_embedding_dimensions]
    assert @config.summarization_config[:enable]
    assert_equal 300, @config.summarization_config[:max_length]
    assert_equal 300, @config.summarization_config[:min_content_length]
    assert @config.search[:enable_usage_tracking]
    assert @config.search[:usage_ranking_enabled]
    assert_equal 0.3, @config.search[:usage_recency_weight]
    assert_equal 0.7, @config.search[:usage_frequency_weight]
    assert_equal 1.0, @config.search[:usage_similarity_weight]
  end

  def test_ruby_llm_config_defaults
    assert_instance_of Hash, @config.ruby_llm_config
    assert @config.ruby_llm_config.key?(:openai)
    assert @config.ruby_llm_config.key?(:anthropic)
    assert @config.ruby_llm_config.key?(:google)
    assert @config.ruby_llm_config.key?(:azure)
    assert @config.ruby_llm_config.key?(:ollama)
    assert @config.ruby_llm_config.key?(:huggingface)
  end

  def test_openai_api_key_from_ruby_llm_config
    # Test that OpenAI API key comes from ruby_llm_config
    original_env = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    begin
      config = Ragdoll::Core::Configuration.new
      # The api_key should be resolved from the proc in ruby_llm_config
      assert_equal "test-key", config.ruby_llm_config[:openai][:api_key]
    ensure
      ENV["OPENAI_API_KEY"] = original_env
    end
  end

  def test_anthropic_api_key_from_ruby_llm_config
    original_env = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "anthropic-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "anthropic-key", config.ruby_llm_config[:anthropic][:api_key]
    ensure
      ENV["ANTHROPIC_API_KEY"] = original_env
    end
  end

  def test_google_api_key_from_ruby_llm_config
    original_env = ENV["GOOGLE_API_KEY"]
    ENV["GOOGLE_API_KEY"] = "google-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "google-key", config.ruby_llm_config[:google][:api_key]
    ensure
      ENV["GOOGLE_API_KEY"] = original_env
    end
  end

  def test_azure_api_key_from_ruby_llm_config
    original_env = ENV["AZURE_OPENAI_API_KEY"]
    ENV["AZURE_OPENAI_API_KEY"] = "azure-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "azure-key", config.ruby_llm_config[:azure][:api_key]
    ensure
      ENV["AZURE_OPENAI_API_KEY"] = original_env
    end
  end

  def test_ollama_endpoint_from_ruby_llm_config
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = "http://custom:11434"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "http://custom:11434", config.ruby_llm_config[:ollama][:endpoint]
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_ollama_endpoint_default
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = nil

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "http://localhost:11434", config.ruby_llm_config[:ollama][:endpoint]
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_huggingface_api_key_from_ruby_llm_config
    original_env = ENV["HUGGINGFACE_API_KEY"]
    ENV["HUGGINGFACE_API_KEY"] = "hf-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "hf-key", config.ruby_llm_config[:huggingface][:api_key]
    ensure
      ENV["HUGGINGFACE_API_KEY"] = original_env
    end
  end

  def test_current_configuration_structure_accessible
    # Test that current configuration structure can be read and written
    # Main configuration sections
    assert_respond_to @config, :models
    assert_respond_to @config, :chunking
    assert_respond_to @config, :ruby_llm_config
    assert_respond_to @config, :embedding_config
    assert_respond_to @config, :summarization_config
    assert_respond_to @config, :database_config
    assert_respond_to @config, :logging_config
    assert_respond_to @config, :search

    # Test nested structure access
    assert_respond_to @config.models, :[]
    assert_respond_to @config.chunking, :[]
    assert_respond_to @config.ruby_llm_config, :[]
    assert_respond_to @config.embedding_config, :[]
    assert_respond_to @config.summarization_config, :[]
    assert_respond_to @config.database_config, :[]
    assert_respond_to @config.logging_config, :[]
    assert_respond_to @config.search, :[]
  end

  def test_ruby_llm_config_structure
    config = @config.ruby_llm_config

    assert_instance_of Hash, config

    # Check that all expected providers are present
    expected_providers = %i[openai anthropic google azure ollama huggingface openrouter]
    expected_providers.each do |provider|
      assert config.key?(provider), "Missing provider: #{provider}"
      assert_instance_of Hash, config[provider]
    end

    # Check specific structures
    assert config[:openai].key?(:api_key)
    assert config[:openai].key?(:organization)
    assert config[:openai].key?(:project)

    assert config[:azure].key?(:api_version)
    assert_equal "2024-02-01", config[:azure][:api_version]

    assert config[:ollama].key?(:endpoint)
    assert_equal "http://localhost:11434", config[:ollama][:endpoint]
  end

  def test_numeric_configuration_values
    # Test chunking configuration
    @config.chunking[:text][:max_tokens] = 500
    assert_equal 500, @config.chunking[:text][:max_tokens]

    @config.chunking[:text][:overlap] = 50
    assert_equal 50, @config.chunking[:text][:overlap]

    # Test search configuration
    @config.search[:similarity_threshold] = 0.8
    assert_equal 0.8, @config.search[:similarity_threshold]

    @config.search[:usage_recency_weight] = 0.5
    assert_equal 0.5, @config.search[:usage_recency_weight]
  end

  def test_boolean_configuration_values
    # Test search configuration booleans
    @config.search[:enable_analytics] = false
    refute @config.search[:enable_analytics]

    # Test embedding configuration booleans
    @config.embedding_config[:cache_embeddings] = false
    refute @config.embedding_config[:cache_embeddings]

    # Test search usage ranking
    @config.search[:usage_ranking_enabled] = false
    refute @config.search[:usage_ranking_enabled]
  end

  def test_database_config_structure
    config = @config.database_config

    assert_instance_of Hash, config
    assert_equal "postgresql", config[:adapter]
    assert_equal "ragdoll_development", config[:database]
    assert_equal "localhost", config[:host]
    assert_equal 5432, config[:port]
    assert config[:auto_migrate]
  end

  def test_database_config_default
    assert_instance_of Hash, @config.database_config
    assert_equal "postgresql", @config.database_config[:adapter]
  end
end
