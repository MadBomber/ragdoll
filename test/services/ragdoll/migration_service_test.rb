# frozen_string_literal: true

require "test_helper"

class Ragdoll::MigrationServiceTest < Minitest::Test
  def setup
    @migration_service = Ragdoll::MigrationService.new
  end

  def test_migrate_single_document
    # Create a mock old document
    mock_old_document = create_mock_old_document

    # Mock the unified document creation
    mock_unified_doc = create_mock_unified_document
    # Create simple objects instead of Minitest::Mock for more flexibility
    mock_unified_contents = Object.new
    mock_unified_content = create_mock_unified_content

    # Use flexible lambda for create! that accepts any arguments
    create_content_lambda = lambda { |*args, **kwargs| mock_unified_content }
    mock_unified_contents.define_singleton_method(:create!, &create_content_lambda)
    mock_unified_doc.define_singleton_method(:unified_contents) { mock_unified_contents }

    # Test migration without UnifiedDocument available
    unless defined?(Ragdoll::UnifiedDocument)
      result = @migration_service.send(:migrate_single_document, mock_old_document)
      assert_equal :skipped, result[:status]
      assert_equal "already_migrated", result[:reason]
      return
    end

    # Test with UnifiedDocument available
    Ragdoll::UnifiedDocument.stub(:exists?, false) do
      create_lambda = lambda { |*args, **kwargs| mock_unified_doc }
      Ragdoll::UnifiedDocument.stub(:create!, create_lambda) do
        @migration_service.stub(:extract_unified_text_from_document, "Extracted text content") do
          @migration_service.stub(:determine_primary_media_type, "text") do
            @migration_service.stub(:merge_document_metadata, {}) do
              result = @migration_service.send(:migrate_single_document, mock_old_document)

              assert_equal :migrated, result[:status]
              assert_equal mock_unified_doc, result[:unified_document]
            end
          end
        end
      end
    end
  end

  def test_migrate_document_with_no_content
    mock_old_document = create_mock_old_document

    # Mock empty content extraction
    @migration_service.stub(:extract_unified_text_from_document, "") do
      result = @migration_service.send(:migrate_single_document, mock_old_document)

      assert_equal :skipped, result[:status]
      assert_equal "no_content", result[:reason]
    end
  end

  def test_extract_unified_text_from_document
    mock_old_document = Object.new

    # Mock text contents
    mock_text_content1 = Object.new
    mock_text_content1.define_singleton_method(:content) { "Text content 1" }
    mock_text_content2 = Object.new
    mock_text_content2.define_singleton_method(:content) { "Text content 2" }

    # Mock image contents
    mock_image_content = Object.new
    mock_image_content.define_singleton_method(:description) { "Image description" }

    # Mock audio contents
    mock_audio_content = Object.new
    mock_audio_content.define_singleton_method(:transcript) { "Audio transcript" }

    # Set up the mock document with content relationships
    mock_old_document.define_singleton_method(:respond_to?) do |method|
      [:text_contents, :image_contents, :audio_contents, :content].include?(method)
    end

    mock_old_document.define_singleton_method(:text_contents) { [mock_text_content1, mock_text_content2] }
    mock_old_document.define_singleton_method(:image_contents) { [mock_image_content] }
    mock_old_document.define_singleton_method(:audio_contents) { [mock_audio_content] }
    mock_old_document.define_singleton_method(:content) { "Fallback content" }

    result = @migration_service.send(:extract_unified_text_from_document, mock_old_document)

    expected = "Text content 1\n\nText content 2\n\nImage description\n\nAudio transcript"
    assert_equal expected, result
  end

  def test_extract_unified_text_with_fallback_to_content_field
    mock_old_document = Object.new

    # Mock empty content collections but with content field
    mock_old_document.define_singleton_method(:respond_to?) do |method|
      [:text_contents, :image_contents, :audio_contents, :content].include?(method)
    end

    mock_old_document.define_singleton_method(:text_contents) { [] }
    mock_old_document.define_singleton_method(:image_contents) { [] }
    mock_old_document.define_singleton_method(:audio_contents) { [] }
    mock_old_document.define_singleton_method(:content) { "Fallback content from content field" }

    result = @migration_service.send(:extract_unified_text_from_document, mock_old_document)

    assert_equal "Fallback content from content field", result
  end

  def test_determine_primary_media_type
    # Test with content_types method
    mock_document = Object.new
    mock_document.define_singleton_method(:respond_to?) { |method| method == :content_types }
    mock_document.define_singleton_method(:content_types) { ["image", "text"] }

    result = @migration_service.send(:determine_primary_media_type, mock_document)
    assert_equal "image", result

    # Test fallback to document_type
    mock_document2 = Object.new
    mock_document2.define_singleton_method(:respond_to?) { |method| false }
    mock_document2.define_singleton_method(:document_type) { "pdf" }

    result2 = @migration_service.send(:determine_primary_media_type, mock_document2)
    assert_equal "text", result2
  end

  def test_create_comparison_report_without_unified_model
    # Test when UnifiedDocument is not available
    unless defined?(Ragdoll::UnifiedDocument)
      report = @migration_service.create_comparison_report

      assert report.key?(:error)
      assert_equal "UnifiedDocument model not available", report[:error]
    end
  end

  def test_validate_migration_without_unified_model
    # Test when UnifiedDocument is not available
    unless defined?(Ragdoll::UnifiedDocument)
      results = @migration_service.validate_migration

      assert results.key?(:error)
      assert_equal "UnifiedDocument model not available", results[:error]
    end
  end

  def test_content_quality_report
    # Test when UnifiedContent is not available
    unless defined?(Ragdoll::UnifiedContent)
      report = @migration_service.send(:content_quality_report)
      assert report.empty?
      return
    end

    # Mock UnifiedContent stats
    # The method calls where(...).count 3 times, so we need 3 separate mocks
    mock_high_quality = Minitest::Mock.new
    mock_medium_quality = Minitest::Mock.new
    mock_low_quality = Minitest::Mock.new

    mock_high_quality.expect(:count, 6)
    mock_medium_quality.expect(:count, 3)
    mock_low_quality.expect(:count, 1)

    call_count = 0
    mock_where = lambda do |condition|
      call_count += 1
      case call_count
      when 1 then mock_high_quality   # high quality
      when 2 then mock_medium_quality # medium quality
      when 3 then mock_low_quality    # low quality
      end
    end

    Ragdoll::UnifiedContent.stub(:count, 10) do
      Ragdoll::UnifiedContent.stub(:where, mock_where) do
        report = @migration_service.send(:content_quality_report)

        assert_equal 10, report[:total_contents]
        assert report.key?(:high_quality_percentage)
        assert report.key?(:medium_quality_percentage)
        assert report.key?(:low_quality_percentage)
      end
    end

    mock_high_quality.verify
    mock_medium_quality.verify
    mock_low_quality.verify
  end

  def test_merge_document_metadata
    mock_document = Object.new
    mock_document.define_singleton_method(:metadata) { { "title" => "Test", "author" => "Test Author" } }

    result = @migration_service.send(:merge_document_metadata, mock_document)

    assert_equal "Test", result["title"]
    assert_equal "Test Author", result["author"]
    assert result["migrated_from_multi_modal"]
    assert result.key?("migration_timestamp")
    assert_equal "multi_modal_sti", result["original_system"]
  end

  def test_generate_migration_recommendations
    recommendations = @migration_service.send(:generate_migration_recommendations)

    assert recommendations.is_a?(Array)
    assert recommendations.any?

    # Should include basic recommendations
    assert recommendations.any? { |r| r.include?("search functionality") }
    assert recommendations.any? { |r| r.include?("embedding generation") }
  end

  def test_class_methods
    # Test class method migrate_all_documents
    mock_service = Minitest::Mock.new
    mock_service.expect(:migrate_all_documents, { migrated: 5 })

    Ragdoll::MigrationService.stub(:new, mock_service) do
      result = Ragdoll::MigrationService.migrate_all_documents
      assert_equal 5, result[:migrated]
    end

    # Test class method migrate_document
    mock_service2 = Minitest::Mock.new
    mock_document = create_mock_unified_document
    mock_service2.expect(:migrate_document, mock_document, [1])

    Ragdoll::MigrationService.stub(:new, mock_service2) do
      result = Ragdoll::MigrationService.migrate_document(1)
      assert_equal mock_document, result
    end

    mock_service.verify
    mock_service2.verify
  end

  private

  def create_mock_old_document
    document = Object.new
    document.define_singleton_method(:id) { 1 }
    document.define_singleton_method(:location) { "/tmp/test.txt" }
    document.define_singleton_method(:title) { "Test Document" }
    document.define_singleton_method(:document_type) { "text" }
    document.define_singleton_method(:file_modified_at) { Time.current }
    document.define_singleton_method(:metadata) { { "source" => "test" } }
    document.define_singleton_method(:content) { "Test content" }

    # Mock content relationships
    document.define_singleton_method(:respond_to?) do |method|
      [:text_contents, :image_contents, :audio_contents, :content_types].include?(method)
    end

    document.define_singleton_method(:text_contents) { [] }
    document.define_singleton_method(:image_contents) { [] }
    document.define_singleton_method(:audio_contents) { [] }
    document.define_singleton_method(:content_types) { ["text"] }

    document
  end

  def create_mock_unified_document
    document = Object.new
    document.define_singleton_method(:id) { 1 }
    document.define_singleton_method(:title) { "Test Document" }
    document.define_singleton_method(:document_type) { "text" }
    document.define_singleton_method(:status) { "processed" }
    document.define_singleton_method(:persisted?) { true }
    document.define_singleton_method(:save!) { true }
    document.define_singleton_method(:update!) { |attrs| true }
    document.define_singleton_method(:process_document!) { true }
    document
  end

  def create_mock_unified_content
    content = Object.new
    content.define_singleton_method(:id) { 1 }
    content.define_singleton_method(:content) { "Test content" }
    content.define_singleton_method(:original_media_type) { "text" }
    content.define_singleton_method(:embedding_model) { "text-embedding-3-large" }
    content.define_singleton_method(:persisted?) { true }
    content.define_singleton_method(:save!) { true }
    content
  end
end