# frozen_string_literal: true

require_relative "test_helper"

class CoreTest < Minitest::Test
  def setup
    super
    # Reset configuration before each test
    Ragdoll::Core.instance_variable_set(:@configuration, nil)
  end

  def test_configuration_returns_configuration_instance
    config = Ragdoll::Core.configuration

    assert_instance_of Ragdoll::Core::Configuration, config
  end

  def test_configuration_memoization
    config1 = Ragdoll::Core.configuration
    config2 = Ragdoll::Core.configuration

    assert_same config1, config2
  end

  def test_configure_yields_configuration
    Ragdoll::Core.configure do |config|
      assert_instance_of Ragdoll::Core::Configuration, config
      config.llm_provider = :test_provider
    end

    assert_equal :test_provider, Ragdoll::Core.configuration.llm_provider
  end

  def test_configure_modifies_configuration
    Ragdoll::Core.configure do |config|
      config.llm_provider = :new_provider
      config.chunk_size = 500
    end

    config = Ragdoll::Core.configuration
    assert_equal :new_provider, config.llm_provider
    assert_equal 500, config.chunk_size
  end

  def test_client_factory_method_with_no_options
    client = Ragdoll::Core.client

    assert_instance_of Ragdoll::Core::Client, client
  end

  def test_client_factory_method_with_config
    config = Ragdoll::Core::Configuration.new
    config.database_config = {
      adapter: "postgresql",
      database: "ragdoll_test",
      username: "postgres",
      password: "",
      host: "localhost",
      port: 5432,
      auto_migrate: true
    }

    client = Ragdoll::Core.client(config)

    assert_instance_of Ragdoll::Core::Client, client
    assert_equal config, client.instance_variable_get(:@config)
  end

  def test_reset_configuration_helper_method
    # First, modify the configuration
    Ragdoll::Core.configure do |config|
      config.llm_provider = :modified
    end

    assert_equal :modified, Ragdoll::Core.configuration.llm_provider

    # Reset should restore defaults
    Ragdoll::Core.reset_configuration!

    assert_equal :openai, Ragdoll::Core.configuration.llm_provider
  end

  def test_multiple_configure_calls
    Ragdoll::Core.configure do |config|
      config.llm_provider = :first
    end

    Ragdoll::Core.configure do |config|
      config.chunk_size = 123
    end

    config = Ragdoll::Core.configuration
    assert_equal :first, config.llm_provider  # Should persist
    assert_equal 123, config.chunk_size       # Should be set
  end

  def test_configuration_thread_safety
    # This is a basic test - in practice, thread safety would need more thorough testing
    results = []
    threads = []

    3.times do |i|
      threads << Thread.new do
        Ragdoll::Core.configure do |config|
          config.chunk_size = 100 + i
        end
        results << Ragdoll::Core.configuration.chunk_size
      end
    end

    threads.each(&:join)

    # All threads should see a valid chunk size
    assert(results.all? { |size| size >= 100 && size <= 102 })
  end

  def test_hybrid_search_delegation
    # Test that hybrid_search method is properly delegated
    assert Ragdoll::Core.respond_to?(:hybrid_search), "hybrid_search should be delegated to Core module"
  end

  def test_module_delegation_completeness
    # Test that all expected high-level API methods are available
    expected_methods = %i[
      add_document search enhance_prompt get_document
      document_status list_documents delete_document
      update_document get_context search_similar_content
      add_directory stats healthy? hybrid_search
    ]

    expected_methods.each do |method|
      assert Ragdoll::Core.respond_to?(method), "#{method} should be available on Core module"
    end
  end
end
