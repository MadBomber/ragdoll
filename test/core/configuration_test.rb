# frozen_string_literal: true

require_relative "../test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    super
    @config = Ragdoll::Core::Configuration.new
  end

  def test_default_values
    # Test new configuration structure
    assert_equal Model.new("openai/gpt-4o"), @config.models[:text_generation][:default]
    assert_equal Model.new("openai/gpt-4o"), @config.models[:text_generation][:summary] # Now returns Model instead of nil
    assert_equal Model.new("openai/gpt-4o"), @config.models[:text_generation][:keywords] # Now returns Model instead of nil
    assert_equal Model.new("openai/text-embedding-3-small"), @config.models[:embedding][:text]
    assert_equal 1000, @config.processing[:text][:chunking][:max_tokens]
    assert_equal 200, @config.processing[:text][:chunking][:overlap]
    assert_equal 0.7, @config.processing[:search][:similarity_threshold]
    assert_equal 10, @config.processing[:search][:max_results]
    assert_equal :openai, @config.models[:embedding][:provider]
    assert @config.models[:embedding][:cache_embeddings]
    assert_equal 3072, @config.models[:embedding][:max_dimensions]
    assert @config.summarization[:enable]
    assert_equal 300, @config.summarization[:max_length]
    assert_equal 300, @config.summarization[:min_content_length]

    # Test analytics grouping
    assert @config.processing[:search][:analytics][:usage_tracking_enabled]
    assert @config.processing[:search][:analytics][:ranking_enabled]
    assert_equal 0.3, @config.processing[:search][:analytics][:recency_weight]
    assert_equal 0.7, @config.processing[:search][:analytics][:frequency_weight]
    assert_equal 1.0, @config.processing[:search][:analytics][:similarity_weight]

    # Test logging fix
    assert_equal :warn, @config.logging[:level] # This was the bug - was log_level

    # Test base directory usage
    assert_includes @config.base_directory, "ragdoll"
    assert_includes @config.config_filepath, "config.yml"

    # Test prompt templates
    refute_nil @config.prompt_templates[:rag_enhancement]
    assert_includes @config.prompt_templates[:rag_enhancement], "Context:"
  end

  def test_llm_providers_defaults
    # Test llm_providers structure
    assert_instance_of Hash, @config.llm_providers
    assert_equal :openai, @config.llm_providers[:default_provider]
    assert @config.llm_providers.key?(:openai)
    assert @config.llm_providers.key?(:anthropic)
    assert @config.llm_providers.key?(:google)
    assert @config.llm_providers.key?(:azure)
    assert @config.llm_providers.key?(:ollama)
    assert @config.llm_providers.key?(:huggingface)
  end

  def test_openai_api_key_from_llm_providers
    # Test that OpenAI API key comes from llm_providers
    original_env = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    begin
      config = Ragdoll::Core::Configuration.new
      # The api_key should be resolved from the proc in llm_providers
      assert_equal "test-key", config.llm_providers[:openai][:api_key]
    ensure
      ENV["OPENAI_API_KEY"] = original_env
    end
  end

  def test_anthropic_api_key_from_llm_providers
    original_env = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "anthropic-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "anthropic-key", config.llm_providers[:anthropic][:api_key]
    ensure
      ENV["ANTHROPIC_API_KEY"] = original_env
    end
  end

  def test_google_api_key_from_llm_providers
    original_env = ENV["GOOGLE_API_KEY"]
    ENV["GOOGLE_API_KEY"] = "google-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "google-key", config.llm_providers[:google][:api_key]
    ensure
      ENV["GOOGLE_API_KEY"] = original_env
    end
  end

  def test_azure_api_key_from_llm_providers
    original_env = ENV["AZURE_OPENAI_API_KEY"]
    ENV["AZURE_OPENAI_API_KEY"] = "azure-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "azure-key", config.llm_providers[:azure][:api_key]
    ensure
      ENV["AZURE_OPENAI_API_KEY"] = original_env
    end
  end

  def test_ollama_endpoint_from_llm_providers
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = "http://custom:11434"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "http://custom:11434", config.llm_providers[:ollama][:endpoint]
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_ollama_endpoint_default
    original_env = ENV["OLLAMA_ENDPOINT"]
    ENV["OLLAMA_ENDPOINT"] = nil

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "http://localhost:11434", config.llm_providers[:ollama][:endpoint]
    ensure
      ENV["OLLAMA_ENDPOINT"] = original_env
    end
  end

  def test_huggingface_api_key_from_llm_providers
    original_env = ENV["HUGGINGFACE_API_KEY"]
    ENV["HUGGINGFACE_API_KEY"] = "hf-key"

    begin
      config = Ragdoll::Core::Configuration.new
      assert_equal "hf-key", config.llm_providers[:huggingface][:api_key]
    ensure
      ENV["HUGGINGFACE_API_KEY"] = original_env
    end
  end

  def test_current_configuration_structure_accessible
    # Test that current configuration structure can be read and written
    # Main configuration sections
    assert_respond_to @config, :models
    assert_respond_to @config, :processing
    assert_respond_to @config, :llm_providers
    assert_respond_to @config, :summarization
    assert_respond_to @config, :database
    assert_respond_to @config, :logging
    assert_respond_to @config, :prompt_templates

    # Test nested structure access
    assert_respond_to @config.models, :[]
    assert_respond_to @config.processing, :[]
    assert_respond_to @config.llm_providers, :[]
    assert_respond_to @config.summarization, :[]
    assert_respond_to @config.database, :[]
    assert_respond_to @config.logging, :[]
    assert_respond_to @config.prompt_templates, :[]
  end

  def test_llm_providers_structure
    config = @config.llm_providers

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
    @config.processing[:text][:chunking][:max_tokens] = 500
    assert_equal 500, @config.processing[:text][:chunking][:max_tokens]

    @config.processing[:text][:chunking][:overlap] = 50
    assert_equal 50, @config.processing[:text][:chunking][:overlap]

    # Test search configuration
    @config.processing[:search][:similarity_threshold] = 0.8
    assert_equal 0.8, @config.processing[:search][:similarity_threshold]

    @config.processing[:search][:analytics][:recency_weight] = 0.5
    assert_equal 0.5, @config.processing[:search][:analytics][:recency_weight]
  end

  def test_boolean_configuration_values
    # Test search configuration booleans
    @config.processing[:search][:analytics][:enable] = false
    refute @config.processing[:search][:analytics][:enable]

    # Test embedding configuration booleans
    @config.models[:embedding][:cache_embeddings] = false
    refute @config.models[:embedding][:cache_embeddings]

    # Test search usage ranking
    @config.processing[:search][:analytics][:ranking_enabled] = false
    refute @config.processing[:search][:analytics][:ranking_enabled]
  end

  def test_database_config_structure
    # Test database structure
    config = @config.database
    assert_instance_of Hash, config
    assert_equal "postgresql", config[:adapter]
    assert_equal "ragdoll_development", config[:database]
    assert_equal "localhost", config[:host]
    assert_equal 5432, config[:port]
    assert config[:auto_migrate]
  end

  def test_database_config_default
    assert_instance_of Hash, @config.database
    assert_equal "postgresql", @config.database[:adapter]
  end

  def test_model_inheritance_methods
    # Test new model resolution methods
    assert_equal Model.new("openai/gpt-4o"), @config.resolve_model(:default)
    assert_equal Model.new("openai/gpt-4o"), @config.resolve_model(:summary) # Should inherit from default
    assert_equal Model.new("openai/gpt-4o"), @config.resolve_model(:keywords) # Should inherit from default

    # Test embedding model resolution
    assert_equal Model.new("openai/text-embedding-3-small"), @config.embedding_model(:text)
    assert_equal Model.new("openai/clip-vit-base-patch32"), @config.embedding_model(:image)
    assert_equal Model.new("openai/whisper-1"), @config.embedding_model(:audio)
  end

  def test_prompt_template_access
    template = @config.prompt_template(:rag_enhancement)
    refute_nil template
    assert_includes template, "Context:"
    assert_includes template, "{{context}}"
    assert_includes template, "{{prompt}}"
  end
end
