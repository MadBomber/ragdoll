# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/ragdoll"

class RagdollModuleTest < Minitest::Test
  def setup
    super
    Ragdoll::Core.reset_configuration!
  end

  def teardown
    Ragdoll::Core.reset_configuration!
    super
  end

  # Module existence tests
  def test_ragdoll_module_exists
    assert defined?(Ragdoll)
  end

  def test_ragdoll_has_core_submodule
    assert defined?(Ragdoll::Core)
  end

  # Configuration delegation tests
  def test_config_method_exists
    assert_respond_to Ragdoll, :config
  end

  def test_config_returns_configuration
    result = Ragdoll.config
    assert result.present?
  end

  def test_configure_method_exists
    assert_respond_to Ragdoll, :configure
  end

  def test_configure_yields_configuration
    yielded_config = nil
    Ragdoll.configure { |c| yielded_config = c }
    assert yielded_config.present?
  end

  def test_configuration_method_exists
    assert_respond_to Ragdoll, :configuration
  end

  def test_configuration_returns_config
    result = Ragdoll.configuration
    assert result.present?
  end

  def test_reset_configuration_method_exists
    assert_respond_to Ragdoll, :reset_configuration!
  end

  def test_reset_configuration_resets_config
    original = Ragdoll.config
    Ragdoll.reset_configuration!
    new_config = Ragdoll.config
    # After reset, should get a fresh config
    assert new_config.present?
  end

  # Document management delegation tests
  def test_add_directory_method_exists
    assert_respond_to Ragdoll, :add_directory
  end

  def test_add_document_method_exists
    assert_respond_to Ragdoll, :add_document
  end

  def test_add_alias_exists
    assert_respond_to Ragdoll, :add
  end

  def test_get_document_method_exists
    assert_respond_to Ragdoll, :get_document
  end

  def test_get_alias_exists
    assert_respond_to Ragdoll, :get
  end

  def test_list_documents_method_exists
    assert_respond_to Ragdoll, :list_documents
  end

  def test_list_alias_exists
    assert_respond_to Ragdoll, :list
  end

  def test_delete_document_method_exists
    assert_respond_to Ragdoll, :delete_document
  end

  def test_delete_alias_exists
    assert_respond_to Ragdoll, :delete
  end

  def test_document_status_method_exists
    assert_respond_to Ragdoll, :document_status
  end

  def test_status_alias_exists
    assert_respond_to Ragdoll, :status
  end

  def test_update_document_method_exists
    assert_respond_to Ragdoll, :update_document
  end

  def test_update_alias_exists
    assert_respond_to Ragdoll, :update
  end

  def test_documents_method_exists
    assert_respond_to Ragdoll, :documents
  end

  def test_docs_alias_exists
    assert_respond_to Ragdoll, :docs
  end

  def test_documents_returns_relation
    result = Ragdoll.documents
    assert_kind_of ActiveRecord::Relation, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Documents table not available: #{e.message.split("\n").first}"
  end

  # Retrieval delegation tests
  def test_search_method_exists
    assert_respond_to Ragdoll, :search
  end

  def test_enhance_prompt_method_exists
    assert_respond_to Ragdoll, :enhance_prompt
  end

  def test_get_context_method_exists
    assert_respond_to Ragdoll, :get_context
  end

  def test_search_similar_content_method_exists
    assert_respond_to Ragdoll, :search_similar_content
  end

  def test_hybrid_search_method_exists
    assert_respond_to Ragdoll, :hybrid_search
  end

  # Misc delegation tests
  def test_stats_method_exists
    assert_respond_to Ragdoll, :stats
  end

  def test_healthy_method_exists
    assert_respond_to Ragdoll, :healthy?
  end

  def test_client_method_exists
    assert_respond_to Ragdoll, :client
  end

  def test_version_method_exists
    assert_respond_to Ragdoll, :version
  end

  def test_version_returns_array
    result = Ragdoll.version
    assert_kind_of Array, result
  end

  def test_version_includes_core_version
    result = Ragdoll.version
    core_version = result.find { |v| v.include?("Ragdoll::Core") }
    assert core_version.present?, "Should include Ragdoll::Core version"
  end

  def test_version_format_is_correct
    result = Ragdoll.version
    result.each do |version_string|
      assert version_string.include?(":"), "Version string should include colon separator"
      assert version_string.match?(/Ragdoll::\w+/), "Should match Ragdoll module pattern"
    end
  end

  # Configuration can be accessed via configure block
  def test_configure_block_yields_config
    config_instance = nil
    Ragdoll.configure do |config|
      config_instance = config
    end
    assert config_instance.present?
    assert_kind_of Ragdoll::Core::Config, config_instance
  end
end
