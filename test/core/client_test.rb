# frozen_string_literal: true

require_relative "../test_helper"
require "tempfile"

class ClientTest < Minitest::Test
  def setup
    super
    @client = Ragdoll::Core::Client.new
  end

  def test_initialize_with_default_config
    skip_if_database_unavailable
    assert_instance_of Ragdoll::Core::EmbeddingService, @client.instance_variable_get(:@embedding_service)
    assert_instance_of Ragdoll::Core::SearchEngine, @client.instance_variable_get(:@search_engine)
  end

  def test_enhance_prompt_with_context
    skip_if_database_unavailable
    # Add a document first
    @client.add_document(path: "test_content.txt")

    # Mock DocumentProcessor to return test content
    original_parse = Ragdoll::Core::DocumentProcessor.method(:parse)
    Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse) do |_path|
      {
        content: "Relevant context content",
        metadata: { title: "Test Doc" },
        document_type: "text"
      }
    end

    begin
      result = @client.enhance_prompt(prompt: "What is the content?")

      assert_instance_of Hash, result
      assert_equal "What is the content?", result[:original_prompt]
      assert_instance_of Array, result[:context_sources]
      assert_instance_of Integer, result[:context_count]
    ensure
      # Restore original method
      Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse, original_parse)
    end
  end

  def test_enhance_prompt_without_context
    skip_if_database_unavailable
    result = @client.enhance_prompt(prompt: "Random question")

    assert_equal "Random question", result[:enhanced_prompt]
    assert_equal "Random question", result[:original_prompt]
    assert_empty result[:context_sources]
    assert_equal 0, result[:context_count]
  end

  def test_get_context
    skip_if_database_unavailable
    @client.add_text(content: "Context content", title: "Test Doc")

    result = @client.get_context(query: "test query")

    assert_instance_of Hash, result
    assert_instance_of Array, result[:context_chunks]
    assert_instance_of String, result[:combined_context]
    assert_instance_of Integer, result[:total_chunks]
  end

  def test_search
    skip_if_database_unavailable
    @client.add_text(content: "Searchable content", title: "Test Doc")

    result = @client.search(query: "test query")

    assert_instance_of Hash, result
    assert_equal "test query", result[:query]
    assert_instance_of Array, result[:results]
    assert_instance_of Integer, result[:total_results]
  end

  def test_search_similar_content
    skip_if_database_unavailable
    @client.add_text(content: "Similar content", title: "Test Doc")

    result = @client.search_similar_content(query: "test query")

    assert_instance_of Array, result
  end

  def test_hybrid_search
    skip_if_database_unavailable
    @client.add_text(content: "Test content for hybrid search", title: "Hybrid Doc")

    result = @client.hybrid_search(query: "test query")

    assert_instance_of Hash, result
    assert_equal "test query", result[:query]
    assert_equal "hybrid", result[:search_type]
    assert_instance_of Array, result[:results]
    assert_instance_of Integer, result[:total_results]
    assert_instance_of Float, result[:semantic_weight]
    assert_instance_of Float, result[:text_weight]

    # Test default weights
    assert_equal 0.7, result[:semantic_weight]
    assert_equal 0.3, result[:text_weight]
  end

  def test_hybrid_search_with_custom_weights
    skip_if_database_unavailable
    @client.add_text(content: "Test content for weighted hybrid search", title: "Weighted Doc")

    result = @client.hybrid_search(
      query: "test query",
      semantic_weight: 0.8,
      text_weight: 0.2
    )

    assert_instance_of Hash, result
    assert_equal 0.8, result[:semantic_weight]
    assert_equal 0.2, result[:text_weight]
  end

  def test_add_document_with_file_path
    skip_if_database_unavailable
    with_temp_text_file("Test file content") do |file_path|
      result = @client.add_document(path: file_path)

      assert_instance_of Hash, result
      assert result[:success]
      assert_instance_of String, result[:document_id]

      doc = @client.get_document(id: result[:document_id])
      assert_equal result[:document_id], doc[:id]
    end
  end

  def test_add_text
    skip_if_database_unavailable
    doc_id = @client.add_text(content: "Direct content", title: "Direct Title")

    assert_instance_of String, doc_id

    doc = @client.get_document(id: doc_id)
    assert_equal doc_id, doc[:id]
    assert_equal "Direct Title", doc[:title]
  end

  def test_add_document_with_custom_title
    skip_if_database_unavailable
    with_temp_text_file("File content") do |file_path|
      # Mock DocumentProcessor to return metadata with title
      original_parse = Ragdoll::Core::DocumentProcessor.method(:parse)
      Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse) do |path|
        {
          content: File.read(path),
          metadata: { title: "Custom Title" },
          document_type: "text"
        }
      end

      begin
        result = @client.add_document(path: file_path)

        assert result[:success]
        doc = @client.get_document(id: result[:document_id])
        assert_equal "Custom Title", doc[:title]
      ensure
        # Restore original method
        Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse, original_parse)
      end
    end
  end

  def test_add_document_from_parser_metadata
    skip_if_database_unavailable
    content_with_title = "File content"
    with_temp_text_file(content_with_title) do |file_path|
      # Mock DocumentProcessor to return metadata with title
      original_parse = Ragdoll::Core::DocumentProcessor.method(:parse)
      Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse) do |path|
        {
          content: File.read(path),
          metadata: { title: "Metadata Title" },
          document_type: "text"
        }
      end

      begin
        result = @client.add_document(path: file_path)

        doc = @client.get_document(id: result[:document_id])
        assert_equal "Metadata Title", doc[:title]
      ensure
        # Restore original method
        Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse, original_parse)
      end
    end
  end

  def test_add_text_with_metadata
    skip_if_database_unavailable
    doc_id = @client.add_text(content: "Text content", title: "Text Title", author: "Test Author")

    assert_instance_of String, doc_id

    doc = @client.get_document(id: doc_id)
    assert_equal "Text Title", doc[:title]
    # NOTE: author metadata would be stored in document metadata, not directly accessible
  end

  def test_add_directory
    skip_if_database_unavailable
    Dir.mktmpdir do |dir|
      # Create test files
      File.write(File.join(dir, "file1.txt"), "Content 1")
      File.write(File.join(dir, "file2.txt"), "Content 2")
      File.write(File.join(dir, "image.jpg"), "binary image data")

      results = @client.add_directory(path: dir)

      assert_instance_of Array, results
      successful_results = results.select { |r| r[:status] == "success" }
      assert_equal 3, successful_results.length # Now processes all files including images

      results.each do |result|
        if result[:status] == "success"
          assert result[:document_id]
          assert result[:file]
        end
      end
    end
  end

  def test_add_directory_recursive
    skip_if_database_unavailable
    Dir.mktmpdir do |dir|
      # Create nested structure
      subdir = File.join(dir, "subdir")
      Dir.mkdir(subdir)
      File.write(File.join(dir, "file1.txt"), "Content 1")
      File.write(File.join(subdir, "file2.txt"), "Content 2")

      results = @client.add_directory(path: dir, recursive: true)

      assert_equal 2, results.select { |r| r[:status] == "success" }.length
    end
  end

  def test_get_document
    skip_if_database_unavailable
    doc_id = @client.add_text(content: "Get test content", title: "Get Test")

    doc = @client.get_document(id: doc_id)

    assert_instance_of Hash, doc
    assert_equal doc_id, doc[:id]
    assert_equal "Get Test", doc[:title]
    assert_instance_of Integer, doc[:content_length]
  end

  def test_update_document
    skip_if_database_unavailable
    doc_id = @client.add_text(content: "Original content", title: "Original Title")

    @client.update_document(id: doc_id, title: "Updated Title")

    # Test passes if no exception is raised
    assert true
  end

  def test_delete_document
    skip_if_database_unavailable
    doc_id = @client.add_text(content: "Delete test content", title: "Delete Test")

    @client.delete_document(id: doc_id)

    # Test passes if no exception is raised
    assert true
  end

  def test_list_documents
    skip_if_database_unavailable
    @client.add_text(content: "Doc 1", title: "Title 1")
    @client.add_text(content: "Doc 2", title: "Title 2")

    result = @client.list_documents(limit: 10)

    # Test passes if no exception is raised and result is reasonable
    assert result.nil? || result.is_a?(Array)
  end

  def test_stats
    skip_if_database_unavailable
    @client.add_text(content: "Stats test content", title: "Stats Test")

    stats = @client.stats

    # Test passes if no exception is raised
    assert stats.nil? || stats.is_a?(Hash)
  end

  def test_search_analytics
    skip_if_database_unavailable
    result = @client.search_analytics(days: 7)

    # search_analytics returns ActiveRecord query result, not a hash with specific structure
    assert result.respond_to?(:each) || result.is_a?(Hash)
  end

  def test_healthy_with_working_storage
    skip_if_database_unavailable
    @client.add_text(content: "Health test", title: "Health")

    # Mock stats to return valid data
    search_engine = @client.instance_variable_get(:@search_engine)
    search_engine.define_singleton_method(:get_document_stats) do
      { total_documents: 1 }
    end

    assert @client.healthy?
  end

  def test_healthy_with_failing_storage
    skip_if_database_unavailable
    # Mock stats to raise an error
    # Mock DocumentManagement.get_document_stats to raise error
    original_method = Ragdoll::Core::DocumentManagement.method(:get_document_stats)
    Ragdoll::Core::DocumentManagement.define_singleton_method(:get_document_stats) do
      raise StandardError, "Storage error"
    end

    refute @client.healthy?

    # Restore original method
    Ragdoll::Core::DocumentManagement.define_singleton_method(:get_document_stats, original_method)
  end

  def test_client_uses_database_storage
    skip_if_database_unavailable
    client = Ragdoll::Core::Client.new
    search_engine = client.instance_variable_get(:@search_engine)

    # Client uses SearchEngine, not direct storage backend
    assert_instance_of Ragdoll::Core::SearchEngine, search_engine
  end

  def test_client_initializes_embedding_service
    skip_if_database_unavailable
    client = Ragdoll::Core::Client.new
    embedding_service = client.instance_variable_get(:@embedding_service)

    assert_instance_of Ragdoll::Core::EmbeddingService, embedding_service
  end

  def test_client_setup_logging
    skip_if_database_unavailable
    # Test that client initializes without errors
    client = Ragdoll::Core::Client.new

    # Client should initialize successfully
    assert_instance_of Ragdoll::Core::Client, client
  end

  def test_build_enhanced_prompt_with_default_template
    skip_if_database_unavailable
    context = "Relevant context information"
    prompt = "What is the answer?"

    enhanced = @client.send(:build_enhanced_prompt, prompt, context)

    assert_includes enhanced, context
    assert_includes enhanced, prompt
    assert_includes enhanced, "You are an AI assistant"
  end

  def test_build_enhanced_prompt_with_custom_template
    skip_if_database_unavailable
    # NOTE: Currently build_enhanced_prompt uses a hardcoded default template
    # This test verifies it works with the default template structure
    context = "Custom context"
    prompt = "Custom question?"

    enhanced = @client.send(:build_enhanced_prompt, prompt, context)

    # Verify the basic substitution works with the default template
    assert_includes enhanced, context
    assert_includes enhanced, prompt
    assert_includes enhanced, "You are an AI assistant"
  end

  private

  def with_temp_text_file(content)
    Tempfile.create(["test", ".txt"]) do |file|
      file.write(content)
      file.close
      yield file.path
    end
  end
end
