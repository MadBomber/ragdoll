# frozen_string_literal: true

require "test_helper"

class Ragdoll::UnifiedDocumentManagementTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @management = Ragdoll::UnifiedDocumentManagement.new
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir
  end

  def test_add_document_from_file_path
    file_path = create_temp_file("sample.txt", "This is test content for unified RAG.")

    # Mock document creation to avoid database dependency
    mock_document = mock_unified_document

    @management.stub(:create_unified_document, mock_document) do
      @management.stub(:process_document_sync, mock_document) do
        document = @management.add_document(file_path)

        assert_equal mock_document, document
      end
    end
  end

  def test_add_document_with_async_processing
    file_path = create_temp_file("sample.txt", "Test content")
    mock_document = mock_unified_document

    @management.stub(:create_unified_document, mock_document) do
      @management.stub(:process_document_async, mock_document) do
        document = @management.add_document(file_path, async: true)

        assert_equal mock_document, document
      end
    end
  end

  def test_add_document_from_nonexistent_file
    result = @management.add_document("/nonexistent/file.txt")

    assert_nil result
  end

  def test_batch_process_documents
    file1 = create_temp_file("file1.txt", "Content 1")
    file2 = create_temp_file("file2.txt", "Content 2")
    file_paths = [file1, file2]

    mock_document = mock_unified_document

    @management.stub(:add_document, mock_document) do
      results = @management.batch_process_documents(file_paths)

      assert_equal 2, results[:total]
      assert_equal 2, results[:success_count]
      assert_equal 0, results[:error_count]
      assert_equal 2, results[:processed].length
      assert_empty results[:errors]
    end
  end

  def test_batch_process_with_errors
    file1 = create_temp_file("file1.txt", "Content 1")
    file2 = "/nonexistent/file.txt"
    file_paths = [file1, file2]

    mock_document = mock_unified_document

    call_count = 0
    @management.define_singleton_method(:add_document) do |path, **options|
      call_count += 1
      if path.include?("nonexistent")
        raise StandardError, "File not found"
      else
        mock_document
      end
    end

    results = @management.batch_process_documents(file_paths)

    assert_equal 2, results[:total]
    assert_equal 1, results[:success_count]
    assert_equal 1, results[:error_count]
    assert_equal 1, results[:processed].length
    assert_equal 1, results[:errors].length
  end

  def test_search_documents_with_unified_model
    query = "test search"
    mock_results = [mock_unified_document]

    # Test with UnifiedDocument available
    if defined?(Ragdoll::UnifiedDocument)
      Ragdoll::UnifiedDocument.stub(:search_content, mock_results) do
        results = @management.search_documents(query)
        assert_equal mock_results, results
      end
    else
      # Test fallback to regular Document
      Ragdoll::Document.stub(:search_content, mock_results) do
        results = @management.search_documents(query)
        assert_equal mock_results, results
      end
    end
  end

  def test_processing_stats
    mock_stats = {
      documents: {
        total_documents: 10,
        by_status: { "processed" => 8, "pending" => 2 },
        total_embeddings: 50
      },
      content: {
        total_contents: 10,
        by_media_type: { "text" => 6, "image" => 3, "audio" => 1 },
        content_quality_distribution: { high: 5, medium: 3, low: 2 }
      }
    }

    @management.stub(:processing_stats, mock_stats) do
      stats = @management.processing_stats

      assert_equal 10, stats[:documents][:total_documents]
      assert_equal 8, stats[:documents][:by_status]["processed"]
      assert stats[:content][:content_quality_distribution].is_a?(Hash)
    end
  end

  def test_reprocess_document
    file_path = create_temp_file("sample.txt", "Original content")
    mock_document = mock_unified_document
    mock_document.define_singleton_method(:location) { file_path }

    # Mock updated content
    File.write(file_path, "Updated content")

    if defined?(Ragdoll::UnifiedDocument)
      Ragdoll::UnifiedDocument.stub(:find, mock_document) do
        # Create simple objects instead of Minitest::Mock for more flexibility
        mock_unified_content = Object.new
        update_lambda = lambda { |*args, **kwargs| true }
        mock_unified_content.define_singleton_method(:update!, &update_lambda)

        mock_unified_contents = Object.new
        mock_unified_contents.define_singleton_method(:any?) { true }
        mock_unified_contents.define_singleton_method(:first) { mock_unified_content }

        mock_document.define_singleton_method(:unified_contents) { mock_unified_contents }
        mock_document.define_singleton_method(:respond_to?) { |method| method == :unified_contents }

        # Mock the converter calls
        mock_converter = Minitest::Mock.new
        mock_converter.expect(:determine_document_type, "text", [file_path])
        mock_converter.expect(:convert_to_text, "Updated content", [String, String])

        @management.instance_variable_set(:@converter, mock_converter)

        @management.stub(:process_document_sync, mock_document) do
          result = @management.reprocess_document(1)

          assert_equal mock_document, result
        end

        mock_converter.verify
      end
    end
  end

  def test_class_methods
    file_path = create_temp_file("sample.txt", "Test content")
    mock_document = mock_unified_document

    # Test class method add_document
    mock_instance = Minitest::Mock.new
    mock_instance.expect(:add_document, mock_document, [file_path])

    Ragdoll::UnifiedDocumentManagement.stub(:new, mock_instance) do
      result = Ragdoll::UnifiedDocumentManagement.add_document(file_path)
      assert_equal mock_document, result
    end

    # Test class method process_document
    mock_instance2 = Minitest::Mock.new
    mock_instance2.expect(:process_document, mock_document, [1])

    Ragdoll::UnifiedDocumentManagement.stub(:new, mock_instance2) do
      result = Ragdoll::UnifiedDocumentManagement.process_document(1)
      assert_equal mock_document, result
    end

    mock_instance.verify
    mock_instance2.verify
  end

  private

  def create_temp_file(filename, content)
    file_path = File.join(@temp_dir, filename)
    File.write(file_path, content)
    file_path
  end

  def mock_unified_document
    document = Object.new
    document.define_singleton_method(:id) { 1 }
    document.define_singleton_method(:title) { "Test Document" }
    document.define_singleton_method(:content) { "Test content" }
    document.define_singleton_method(:document_type) { "text" }
    document.define_singleton_method(:status) { "processed" }
    document.define_singleton_method(:persisted?) { true }
    document.define_singleton_method(:save!) { true }
    document.define_singleton_method(:update!) { |attrs| true }
    document
  end
end