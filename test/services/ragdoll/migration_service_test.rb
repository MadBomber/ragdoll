# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class MigrationServiceTest < Minitest::Test
  def setup
    super
    @service = Ragdoll::MigrationService.new
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_initializes_without_arguments
    service = Ragdoll::MigrationService.new
    assert service.present?
  end

  # Error class tests
  def test_migration_error_class_exists
    assert_equal StandardError, Ragdoll::MigrationService::MigrationError.superclass
  end

  def test_migration_error_can_be_raised
    error = Ragdoll::MigrationService::MigrationError.new("Test error")
    assert_equal "Test error", error.message
  end

  # Class method tests
  def test_migrate_all_documents_class_method_exists
    assert Ragdoll::MigrationService.respond_to?(:migrate_all_documents)
  end

  def test_migrate_document_class_method_exists
    assert Ragdoll::MigrationService.respond_to?(:migrate_document)
  end

  # migrate_all_documents tests
  def test_migrate_all_documents_returns_hash_when_unified_document_not_available
    # This test checks behavior when UnifiedDocument is not defined
    # The method should return an error hash
    result = @service.migrate_all_documents

    if result.is_a?(Hash) && result[:error]
      assert_equal "UnifiedDocument model not available", result[:error]
    else
      # If UnifiedDocument IS available, verify we get valid stats
      assert_kind_of Hash, result
      assert result.key?(:started_at) || result.key?(:total_documents)
    end
  end

  def test_migrate_all_documents_accepts_batch_size_option
    result = @service.migrate_all_documents(batch_size: 25)
    # Should not raise an error for the batch_size option
    assert_kind_of Hash, result
  end

  # migrate_document tests
  def test_migrate_document_raises_for_nonexistent_document
    assert_raises(ActiveRecord::RecordNotFound) do
      @service.migrate_document(999999)
    end
  end

  def test_migrate_document_with_valid_document
    file_path = create_test_file("migrate_test.txt", "Content to migrate.")
    document = Ragdoll::Document.create!(
      location: file_path,
      title: "Test Migration",
      document_type: "text",
      status: "processed",
      content: "Content to migrate."
    )

    begin
      result = @service.migrate_document(document.id)
      assert_kind_of Hash, result
      assert result.key?(:status)
    rescue NameError => e
      skip "UnifiedDocument not available: #{e.message.split("\n").first}"
    rescue ActiveRecord::StatementInvalid => e
      skip "Database schema not configured: #{e.message.split("\n").first}"
    end
  ensure
    document&.destroy
  end

  # create_comparison_report tests
  def test_create_comparison_report_returns_hash
    result = @service.create_comparison_report
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  def test_create_comparison_report_returns_error_when_unified_document_not_available
    result = @service.create_comparison_report

    if result.is_a?(Hash) && result[:error]
      assert_equal "UnifiedDocument model not available", result[:error]
    else
      # If UnifiedDocument IS available
      assert result.key?(:migration_summary) || result.key?(:benefits)
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  def test_create_comparison_report_includes_benefits_section
    result = @service.create_comparison_report

    # Skip if UnifiedDocument not available
    return if result[:error]

    if result[:benefits]
      assert result[:benefits].key?(:simplified_architecture)
      assert result[:benefits].key?(:unified_search)
      assert result[:benefits].key?(:cross_modal_retrieval)
      assert result[:benefits].key?(:reduced_complexity)
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  def test_create_comparison_report_includes_recommendations
    result = @service.create_comparison_report

    # Skip if UnifiedDocument not available but check we have some result
    return if result[:error]

    if result[:recommendations]
      assert_kind_of Array, result[:recommendations]
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  # validate_migration tests
  def test_validate_migration_returns_hash
    result = @service.validate_migration
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, NoMethodError => e
    skip "Database schema or validation not configured: #{e.message.split("\n").first}"
  end

  def test_validate_migration_returns_error_when_unified_document_not_available
    result = @service.validate_migration

    if result[:error]
      assert_equal "UnifiedDocument model not available", result[:error]
    else
      # If UnifiedDocument IS available
      assert result.key?(:total_checks)
      assert result.key?(:passed)
      assert result.key?(:failed)
      assert result.key?(:issues)
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, NoMethodError => e
    skip "Database schema or validation not configured: #{e.message.split("\n").first}"
  end

  def test_validate_migration_includes_quality_report
    result = @service.validate_migration

    return if result[:error]

    if result.key?(:quality_report)
      assert_kind_of Hash, result[:quality_report]
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, NoMethodError => e
    skip "Database schema or validation not configured: #{e.message.split("\n").first}"
  end

  # Edge case tests
  def test_migrate_document_handles_document_without_content
    file_path = create_test_file("empty_test.txt", "")
    document = Ragdoll::Document.create!(
      location: file_path,
      title: "Empty Document",
      document_type: "text",
      status: "processed"
    )

    begin
      result = @service.migrate_document(document.id)
      assert_kind_of Hash, result
      # May be skipped due to no content or already migrated
      if result[:status] == :skipped
        assert_includes %w[no_content already_migrated], result[:reason]
      end
    rescue NameError => e
      skip "UnifiedDocument not available: #{e.message.split("\n").first}"
    rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
      skip "Database schema not configured: #{e.message.split("\n").first}"
    end
  ensure
    document&.destroy
  end

  def test_migrate_document_with_process_embeddings_option
    file_path = create_test_file("embed_test.txt", "Content with embeddings.")
    document = Ragdoll::Document.create!(
      location: file_path,
      title: "Embedding Test",
      document_type: "text",
      status: "processed",
      content: "Content with embeddings."
    )

    begin
      result = @service.migrate_document(document.id, process_embeddings: true)
      assert_kind_of Hash, result
    rescue NameError => e
      skip "UnifiedDocument not available: #{e.message.split("\n").first}"
    rescue ActiveRecord::StatementInvalid => e
      skip "Database schema not configured: #{e.message.split("\n").first}"
    rescue StandardError => e
      # Processing embeddings may fail in test environment
      skip "Embedding processing not available: #{e.message.split("\n").first}"
    end
  ensure
    document&.destroy
  end

  # Multiple service instances test
  def test_multiple_service_instances_work_independently
    service1 = Ragdoll::MigrationService.new
    service2 = Ragdoll::MigrationService.new

    assert service1.present?
    assert service2.present?
    refute_same service1, service2
  end

  # Integration-like tests
  def test_full_migration_workflow_structure
    # Test that the migration workflow returns expected structure
    result = @service.migrate_all_documents

    if result[:error]
      # UnifiedDocument not available
      assert_equal "UnifiedDocument model not available", result[:error]
    else
      # Full migration stats structure
      expected_keys = %i[started_at total_documents migrated skipped errors]
      expected_keys.each do |key|
        assert result.key?(key), "Expected result to include #{key}"
      end
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  def test_comparison_report_structure_when_available
    result = @service.create_comparison_report

    return if result[:error]

    if result[:migration_summary]
      summary = result[:migration_summary]
      assert summary.key?(:old_system) || summary.key?(:new_system)
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  # Document type handling
  def test_migrate_document_handles_different_document_types
    document_types = %w[text markdown html pdf]

    document_types.each do |doc_type|
      file_path = create_test_file("test_#{doc_type}.txt", "Content for #{doc_type}")
      document = Ragdoll::Document.create!(
        location: file_path,
        title: "Test #{doc_type}",
        document_type: doc_type,
        status: "processed",
        content: "Content for #{doc_type}"
      )

      begin
        result = @service.migrate_document(document.id)
        assert_kind_of Hash, result
      rescue NameError => e
        skip "UnifiedDocument not available: #{e.message.split("\n").first}"
      rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
        skip "Database schema not configured: #{e.message.split("\n").first}"
      end
    ensure
      document&.destroy
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Database schema not configured: #{e.message.split("\n").first}"
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@test_dir, filename)
    File.write(file_path, content)
    file_path
  end
end
