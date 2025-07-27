# frozen_string_literal: true

require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    super
    @config = Ragdoll::Core::Configuration.new
  end

  def test_default_values
    assert_equal :openai, @config.llm_provider
    assert_equal :openai, @config.embedding_provider
    assert_equal "text-embedding-3-small", @config.embedding_model
    assert_equal 1000, @config.chunk_size
    assert_equal 200, @config.chunk_overlap
    assert_equal 0.7, @config.search_similarity_threshold
    assert_equal 10, @config.max_search_results
    assert_equal "gpt-4", @config.default_model
    assert_nil @config.prompt_template
    assert @config.enable_search_analytics
    assert @config.cache_embeddings
    assert_equal 3072, @config.max_embedding_dimensions
    assert @config.enable_document_summarization
    assert_nil @config.summary_model
    assert_equal 300, @config.summary_max_length
    assert_equal 300, @config.summary_min_content_length
    assert @config.enable_usage_tracking
    assert @config.usage_ranking_enabled
    assert_equal 0.3, @config.usage_recency_weight
    assert_equal 0.7, @config.usage_frequency_weight
    assert_equal 1.0, @config.usage_similarity_weight
  end

  def test_llm_config_defaults
    assert_instance_of Hash, @config.llm_config
    assert @config.llm_config.key?(:openai)
    assert @config.llm_config.key?(:anthropic)
    assert @config.llm_config.key?(:google)
    assert @config.llm_config.key?(:azure)
    assert @config.llm_config.key?(:ollama)
    assert @config.llm_config.key?(:huggingface)
  end

  def test_openai_api_key_getter_with_config
    @config.llm_config[:openai][:api_key] = "test-key"
    assert_equal "test-key", @config.openai_api_key
  end

  def test_openai_api_key_getter_with_env
    # Mock ENV
    original_env = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "env-key"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:openai][:api_key] = nil
      assert_equal "env-key", config.openai_api_key
    ensure
      ENV["OPENAI_API_KEY"] = original_env
    end
  end

  def test_openai_api_key_setter
    @config.openai_api_key = "new-key"
    assert_equal "new-key", @config.llm_config[:openai][:api_key]
    assert_equal "new-key", @config.openai_api_key
  end

  def test_openai_api_key_setter_creates_config
    @config.instance_variable_set(:@llm_config, {})
    @config.openai_api_key = "new-key"
    assert_equal "new-key", @config.llm_config[:openai][:api_key]
  end

  def test_anthropic_api_key_getter_with_config
    @config.llm_config[:anthropic][:api_key] = "anthropic-key"
    assert_equal "anthropic-key", @config.anthropic_api_key
  end

  def test_anthropic_api_key_getter_with_env
    original_env = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "env-anthropic-key"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:anthropic][:api_key] = nil
      assert_equal "env-anthropic-key", config.anthropic_api_key
    ensure
      ENV["ANTHROPIC_API_KEY"] = original_env
    end
  end

  def test_anthropic_api_key_setter
    @config.anthropic_api_key = "new-anthropic-key"
    assert_equal "new-anthropic-key", @config.llm_config[:anthropic][:api_key]
  end

  def test_google_api_key_getter_with_config
    @config.llm_config[:google][:api_key] = "google-key"
    assert_equal "google-key", @config.google_api_key
  end

  def test_google_api_key_getter_with_env
    original_env = ENV["GOOGLE_API_KEY"]
    ENV["GOOGLE_API_KEY"] = "env-google-key"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:google][:api_key] = nil
      assert_equal "env-google-key", config.google_api_key
    ensure
      ENV["GOOGLE_API_KEY"] = original_env
    end
  end

  def test_google_api_key_setter
    @config.google_api_key = "new-google-key"
    assert_equal "new-google-key", @config.llm_config[:google][:api_key]
  end

  def test_azure_api_key_getter_with_config
    @config.llm_config[:azure][:api_key] = "azure-key"
    assert_equal "azure-key", @config.azure_api_key
  end

  def test_azure_api_key_getter_with_env
    original_env = ENV["AZURE_OPENAI_API_KEY"]
    ENV["AZURE_OPENAI_API_KEY"] = "env-azure-key"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:azure][:api_key] = nil
      assert_equal "env-azure-key", config.azure_api_key
    ensure
      ENV["AZURE_OPENAI_API_KEY"] = original_env
    end
  end

  def test_azure_api_key_setter
    @config.azure_api_key = "new-azure-key"
    assert_equal "new-azure-key", @config.llm_config[:azure][:api_key]
  end

  def test_ollama_url_getter_with_config
    @config.llm_config[:ollama][:endpoint] = "http://custom:11434"
    assert_equal "http://custom:11434", @config.ollama_url
  end

  def test_ollama_url_getter_with_env
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = "http://env:11434"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:ollama][:endpoint] = nil
      assert_equal "http://env:11434", config.ollama_url
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_ollama_url_getter_with_default
    @config.llm_config[:ollama][:endpoint] = nil
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = nil

    begin
      assert_equal "http://localhost:11434", @config.ollama_url
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_ollama_url_setter
    @config.ollama_url = "http://custom:8080"
    assert_equal "http://custom:8080", @config.llm_config[:ollama][:endpoint]
  end

  def test_huggingface_api_key_getter_with_config
    @config.llm_config[:huggingface][:api_key] = "hf-key"
    assert_equal "hf-key", @config.huggingface_api_key
  end

  def test_huggingface_api_key_getter_with_env
    original_env = ENV["HUGGINGFACE_API_KEY"]
    ENV["HUGGINGFACE_API_KEY"] = "env-hf-key"

    begin
      config = Ragdoll::Core::Configuration.new
      config.llm_config[:huggingface][:api_key] = nil
      assert_equal "env-hf-key", config.huggingface_api_key
    ensure
      ENV["HUGGINGFACE_API_KEY"] = original_env
    end
  end

  def test_huggingface_api_key_setter
    @config.huggingface_api_key = "new-hf-key"
    assert_equal "new-hf-key", @config.llm_config[:huggingface][:api_key]
  end

  def test_all_attributes_are_accessible
    # Test that all attr_accessor attributes can be read and written
    attributes = %i[
      llm_provider llm_config embedding_model embedding_provider
      chunk_size chunk_overlap search_similarity_threshold max_search_results
      default_model prompt_template enable_search_analytics cache_embeddings
      max_embedding_dimensions enable_document_summarization summary_model
      summary_max_length summary_min_content_length enable_usage_tracking
      usage_ranking_enabled usage_recency_weight usage_frequency_weight
      usage_similarity_weight database_config summary_provider_model
      keywords_provider_model embeddings_provider_model log_level log_file
    ]

    attributes.each do |attr|
      assert_respond_to @config, attr
      assert_respond_to @config, "#{attr}="

      # Test setting and getting a value
      original_value = @config.send(attr)
      test_value = case attr
                   when :llm_provider, :embedding_provider
                     :test_provider
                   when :llm_config, :database_config
                     { test: "value" }
                   when :enable_search_analytics, :cache_embeddings, :enable_document_summarization,
                        :enable_usage_tracking, :usage_ranking_enabled
                     !original_value
                   else
                     "test_value"
                   end

      @config.send("#{attr}=", test_value)
      assert_equal test_value, @config.send(attr)

      # Restore original value
      @config.send("#{attr}=", original_value)
    end
  end

  def test_default_llm_config_structure
    config = @config.send(:default_llm_config)

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

  def test_numeric_attributes_accept_numbers
    @config.chunk_size = 500
    assert_equal 500, @config.chunk_size

    @config.chunk_overlap = 50
    assert_equal 50, @config.chunk_overlap

    @config.search_similarity_threshold = 0.8
    assert_equal 0.8, @config.search_similarity_threshold

    @config.usage_recency_weight = 0.5
    assert_equal 0.5, @config.usage_recency_weight
  end

  def test_boolean_attributes_accept_booleans
    @config.enable_search_analytics = false
    refute @config.enable_search_analytics

    @config.cache_embeddings = false
    refute @config.cache_embeddings

    @config.usage_ranking_enabled = false
    refute @config.usage_ranking_enabled
  end

  def test_default_database_config
    config = @config.send(:default_database_config)

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
