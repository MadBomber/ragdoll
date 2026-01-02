# frozen_string_literal: true

require_relative "../test_helper"

class CoreTest < Minitest::Test
  def setup
    super
    # Reset configuration before each test using official API
    Ragdoll::Core.reset_configuration!
  end

  def teardown
    super
    Ragdoll::Core.reset_configuration!
  end

  def test_configuration_returns_configuration_instance
    config = Ragdoll::Core.configuration

    assert_instance_of Ragdoll::Core::Configuration, config
  end

  def test_config_alias_returns_same_instance
    config = Ragdoll::Core.config

    assert_instance_of Ragdoll::Core::Config, config
    assert_same Ragdoll::Core.config, Ragdoll::Core.configuration
  end

  def test_configuration_memoization
    config1 = Ragdoll::Core.configuration
    config2 = Ragdoll::Core.configuration

    assert_same config1, config2
  end

  def test_configure_yields_configuration
    Ragdoll::Core.configure do |config|
      assert_instance_of Ragdoll::Core::Config, config
    end
  end

  def test_configure_modifies_configuration_via_method_access
    Ragdoll::Core.configure do |config|
      config.chunking.size = 500
    end

    assert_equal 500, Ragdoll::Core.configuration.chunk_size
  end

  def test_client_factory_method_with_no_options
    return if ci_environment?

    # Configure database via the new ConfigSection API
    config = Ragdoll.config
    config.database.name = "ragdoll_test"
    config.database.user = ENV.fetch("RAGDOLL_POSTGRES_USER") { ENV.fetch("USER", "postgres") }
    config.database.password = ENV.fetch("RAGDOLL_POSTGRES_PASSWORD", "")
    config.database.host = ENV.fetch("RAGDOLL_POSTGRES_HOST", "localhost")
    config.database.port = ENV.fetch("RAGDOLL_POSTGRES_PORT", 5432).to_i
    config.database.auto_migrate = true

    client = Ragdoll::Core.client

    assert_instance_of Ragdoll::Core::Client, client
  end

  def test_client_factory_method_with_config
    return if ci_environment?

    # Configure database via the new ConfigSection API
    config = Ragdoll.config
    config.database.name = "ragdoll_test"
    config.database.user = ENV.fetch("RAGDOLL_POSTGRES_USER") { ENV.fetch("USER", "postgres") }
    config.database.password = ENV.fetch("RAGDOLL_POSTGRES_PASSWORD", "")
    config.database.host = ENV.fetch("RAGDOLL_POSTGRES_HOST", "localhost")
    config.database.port = ENV.fetch("RAGDOLL_POSTGRES_PORT", 5432).to_i
    config.database.auto_migrate = true

    # The config parameter is accepted but ignored - client always uses Ragdoll.config
    client = Ragdoll::Core.client(config)

    assert_instance_of Ragdoll::Core::Client, client
    # Client doesn't store config as instance variable - it uses Ragdoll.config
    refute client.instance_variable_defined?(:@config)
  end

  def test_reset_configuration_helper_method
    # First, modify the configuration
    Ragdoll::Core.configure do |config|
      config.chunking.size = 999
    end

    assert_equal 999, Ragdoll::Core.configuration.chunk_size

    # Reset should restore defaults
    Ragdoll::Core.reset_configuration!

    assert_equal 1000, Ragdoll::Core.configuration.chunk_size
  end

  def test_multiple_configure_calls
    Ragdoll::Core.configure do |config|
      config.chunking.size = 500
    end

    Ragdoll::Core.configure do |config|
      config.chunking.overlap = 123
    end

    config = Ragdoll::Core.configuration
    assert_equal 500, config.chunk_size # Should persist
    assert_equal 123, config.chunk_overlap # Should be set
  end

  def test_configuration_thread_safety
    # This is a basic test - in practice, thread safety would need more thorough testing
    results = []
    threads = []

    3.times do |i|
      threads << Thread.new do
        Ragdoll::Core.configure do |config|
          config.chunking.size = 100 + i
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

  def test_backward_compat_models_hash
    # Test that backward-compatible models hash still works
    models = Ragdoll::Core.configuration.models

    assert_instance_of Hash, models
    assert models.key?(:text_generation)
    assert models.key?(:embedding)
  end

  def test_backward_compat_processing_hash
    # Test that backward-compatible processing hash still works
    processing = Ragdoll::Core.configuration.processing

    assert_instance_of Hash, processing
    assert processing.key?(:text)
    assert processing.key?(:search)
  end

  def test_ragdoll_module_shortcuts
    # Test that Ragdoll module has config shortcuts
    assert_respond_to Ragdoll, :config
    assert_respond_to Ragdoll, :configure
    assert_respond_to Ragdoll, :env

    assert_same Ragdoll.config, Ragdoll::Core.config
  end

  def test_environment_detection
    # Test environment detection methods
    config = Ragdoll::Core.configuration

    assert_respond_to config, :test?
    assert_respond_to config, :development?
    assert_respond_to config, :production?
    assert_respond_to config, :environment
  end
end
