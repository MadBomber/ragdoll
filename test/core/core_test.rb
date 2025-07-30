# frozen_string_literal: true

require_relative "../test_helper"

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
      config.models[:text_generation][:default] = "test/provider"
    end

    default_model = Ragdoll::Core.configuration.models[:text_generation][:default]
    expected = default_model.is_a?(Model) ? default_model.name : default_model
    assert_equal "test/provider", expected
  end

  def test_configure_modifies_configuration
    Ragdoll::Core.configure do |config|
      config.models[:text_generation][:default] = "new/provider"
      config.processing[:text][:chunking][:max_tokens] = 500
    end

    config = Ragdoll::Core.configuration
    default_model = config.models[:text_generation][:default]
    expected = default_model.is_a?(Model) ? default_model.name : default_model
    assert_equal "new/provider", expected
    assert_equal 500, config.processing[:text][:chunking][:max_tokens]
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

    # The config parameter is accepted but ignored - client always uses Ragdoll.config
    client = Ragdoll::Core.client(config)

    assert_instance_of Ragdoll::Core::Client, client
    # Client doesn't store config as instance variable - it uses Ragdoll.config
    refute client.instance_variable_defined?(:@config)
  end

  def test_reset_configuration_helper_method
    # First, modify the configuration
    Ragdoll::Core.configure do |config|
      config.models[:text_generation][:default] = "modified/provider"
    end

    default_model = Ragdoll::Core.configuration.models[:text_generation][:default]
    expected = default_model.is_a?(Model) ? default_model.name : default_model
    assert_equal "modified/provider", expected

    # Reset should restore defaults
    Ragdoll::Core.reset_configuration!

    assert_equal "openai/gpt-4o", Ragdoll::Core.configuration.models[:text_generation][:default].name
  end

  def test_multiple_configure_calls
    Ragdoll::Core.configure do |config|
      config.models[:text_generation][:default] = "first/provider"
    end

    Ragdoll::Core.configure do |config|
      config.processing[:text][:chunking][:max_tokens] = 123
    end

    config = Ragdoll::Core.configuration
    default_model = config.models[:text_generation][:default]
    expected = default_model.is_a?(Model) ? default_model.name : default_model
    assert_equal "first/provider", expected # Should persist
    assert_equal 123, config.processing[:text][:chunking][:max_tokens] # Should be set
  end

  def test_configuration_thread_safety
    # This is a basic test - in practice, thread safety would need more thorough testing
    results = []
    threads = []

    3.times do |i|
      threads << Thread.new do
        Ragdoll::Core.configure do |config|
          config.processing[:text][:chunking][:max_tokens] = 100 + i
        end
        results << Ragdoll::Core.configuration.processing[:text][:chunking][:max_tokens]
      end
    end

    threads.each(&:join)

    # All threads should see a valid chunk size
    assert(results.all? { |size| size >= 100 && size <= 102 })
  end

  def test_hybrid_search_delegation
    # Test that hybrid_search method is properly delegated
    assert_respond_to Ragdoll::Core, :hybrid_search, "hybrid_search should be delegated to Core module"
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
      assert_respond_to Ragdoll::Core, method, "#{method} should be available on Core module"
    end
  end
end
