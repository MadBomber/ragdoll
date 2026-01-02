# frozen_string_literal: true

require "test_helper"

class DocumentManagementTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
    super
  end

  # add_document tests
  def test_add_document_creates_new_document
    file_path = create_test_file("test_doc.txt", "Sample content")

    doc_id = Ragdoll::DocumentManagement.add_document(
      file_path,
      "Sample content",
      { title: "Test Document", document_type: "text" }
    )

    assert doc_id.present?
    document = Ragdoll::Document.find(doc_id)
    assert_equal "Test Document", document.title
    assert_equal "text", document.document_type
  end

  def test_add_document_with_minimal_metadata
    file_path = create_test_file("minimal.txt", "Content")

    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    document = Ragdoll::Document.find(doc_id)
    assert_equal "minimal", document.title # Extracted from filename
  end

  def test_add_document_returns_existing_for_duplicate_location
    file_path = create_test_file("dupe.txt", "Original content")

    first_id = Ragdoll::DocumentManagement.add_document(file_path, "Original content")
    second_id = Ragdoll::DocumentManagement.add_document(file_path, "Original content")

    assert_equal first_id, second_id
  end

  def test_add_document_with_force_creates_new_even_for_duplicate
    file_path = create_test_file("forced.txt", "Content")

    first_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")
    second_id = Ragdoll::DocumentManagement.add_document(file_path, "Content", {}, force: true)

    refute_equal first_id, second_id
  end

  def test_add_document_handles_url_location
    doc_id = Ragdoll::DocumentManagement.add_document(
      "https://example.com/document.pdf",
      "PDF content",
      { title: "Remote PDF" }
    )

    document = Ragdoll::Document.find(doc_id)
    assert_equal "https://example.com/document.pdf", document.location
  end

  def test_add_document_with_string_keys_in_metadata
    file_path = create_test_file("string_keys.txt", "Content")

    doc_id = Ragdoll::DocumentManagement.add_document(
      file_path,
      "Content",
      { "title" => "String Key Title", "document_type" => "markdown" }
    )

    document = Ragdoll::Document.find(doc_id)
    assert_equal "String Key Title", document.title
    assert_equal "markdown", document.document_type
  end

  def test_add_document_sets_file_modified_at_for_files
    file_path = create_test_file("timestamped.txt", "Content")

    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    document = Ragdoll::Document.find(doc_id)
    assert document.file_modified_at.present?
  end

  def test_add_document_sets_status_to_pending
    file_path = create_test_file("pending.txt", "Content")

    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    document = Ragdoll::Document.find(doc_id)
    assert_equal "pending", document.status
  end

  # get_document tests
  def test_get_document_returns_document_hash
    file_path = create_test_file("get_test.txt", "Test content")
    doc_id = Ragdoll::DocumentManagement.add_document(
      file_path,
      "Test content",
      { title: "Get Test" }
    )

    result = Ragdoll::DocumentManagement.get_document(doc_id)

    assert_kind_of Hash, result
    assert_equal "Get Test", result[:title]
  end

  def test_get_document_includes_content
    file_path = create_test_file("content_test.txt", "Full content here")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Full content here")

    result = Ragdoll::DocumentManagement.get_document(doc_id)

    assert_equal "Full content here", result[:content]
  end

  def test_get_document_returns_nil_for_nonexistent
    result = Ragdoll::DocumentManagement.get_document(999_999_999)
    assert_nil result
  end

  def test_get_document_accepts_string_id
    file_path = create_test_file("string_id.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.get_document(doc_id.to_s)
    assert result.present?
  end

  # update_document tests
  def test_update_document_updates_title
    file_path = create_test_file("update_title.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(
      file_path,
      "Content",
      { title: "Original Title" }
    )

    result = Ragdoll::DocumentManagement.update_document(doc_id, title: "Updated Title")

    assert_equal "Updated Title", result[:title]
    document = Ragdoll::Document.find(doc_id)
    assert_equal "Updated Title", document.title
  end

  def test_update_document_updates_metadata
    file_path = create_test_file("update_meta.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.update_document(
      doc_id,
      metadata: { author: "Test Author", version: "1.0" }
    )

    assert_equal "Test Author", result[:metadata]["author"]
  end

  def test_update_document_updates_status
    file_path = create_test_file("update_status.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.update_document(doc_id, status: "processed")

    assert_equal "processed", result[:status]
  end

  def test_update_document_updates_document_type
    file_path = create_test_file("update_type.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.update_document(doc_id, document_type: "markdown")

    assert_equal "markdown", result[:document_type]
  end

  def test_update_document_ignores_disallowed_fields
    file_path = create_test_file("disallowed.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")
    original_location = Ragdoll::Document.find(doc_id).location

    Ragdoll::DocumentManagement.update_document(doc_id, location: "/new/path.txt")

    document = Ragdoll::Document.find(doc_id)
    assert_equal original_location, document.location
  end

  def test_update_document_returns_nil_for_nonexistent
    result = Ragdoll::DocumentManagement.update_document(999_999_999, title: "New Title")
    assert_nil result
  end

  # delete_document tests
  def test_delete_document_removes_document
    file_path = create_test_file("delete_me.txt", "Content")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.delete_document(doc_id)

    assert_equal true, result
    assert_nil Ragdoll::Document.find_by(id: doc_id)
  end

  def test_delete_document_returns_nil_for_nonexistent
    result = Ragdoll::DocumentManagement.delete_document(999_999_999)
    assert_nil result
  end

  # list_documents tests
  def test_list_documents_returns_array
    result = Ragdoll::DocumentManagement.list_documents
    assert_kind_of Array, result
  end

  def test_list_documents_with_limit
    # Create multiple documents
    3.times do |i|
      file_path = create_test_file("list_#{i}.txt", "Content #{i}")
      Ragdoll::DocumentManagement.add_document(file_path, "Content #{i}")
    end

    result = Ragdoll::DocumentManagement.list_documents(limit: 2)

    assert_equal 2, result.size
  end

  def test_list_documents_with_offset
    # Create multiple documents
    3.times do |i|
      file_path = create_test_file("offset_#{i}.txt", "Content #{i}")
      Ragdoll::DocumentManagement.add_document(file_path, "Content #{i}")
    end

    all_docs = Ragdoll::DocumentManagement.list_documents(limit: 100)
    offset_docs = Ragdoll::DocumentManagement.list_documents(offset: 1, limit: 100)

    # Should have one fewer document when offset by 1
    assert offset_docs.size < all_docs.size || offset_docs.size == all_docs.size - 1
  end

  def test_list_documents_default_limit
    result = Ragdoll::DocumentManagement.list_documents
    # Default limit is 100
    assert result.size <= 100
  end

  # get_document_stats tests
  def test_get_document_stats_returns_hash
    result = Ragdoll::DocumentManagement.get_document_stats
    assert_kind_of Hash, result
  end

  def test_get_document_stats_includes_total_count
    # Create a document to ensure there's data
    file_path = create_test_file("stats.txt", "Content")
    Ragdoll::DocumentManagement.add_document(file_path, "Content")

    result = Ragdoll::DocumentManagement.get_document_stats

    assert result.key?(:total_documents) || result.key?("total_documents")
  end

  # add_embedding tests
  def test_add_embedding_creates_embedding
    # First create a document with content
    file_path = create_test_file("embed_doc.txt", "Content for embedding")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content for embedding")

    document = Ragdoll::Document.find(doc_id)
    text_content = document.text_contents.first
    skip "Document has no text content" unless text_content

    # Use 1536 dimensions (OpenAI default)
    embedding_id = Ragdoll::DocumentManagement.add_embedding(
      text_content.id,
      0,
      Array.new(1536) { rand },
      { embeddable_type: "Ragdoll::TextContent", content: "Chunk content" }
    )

    assert embedding_id.present?
    embedding = Ragdoll::Embedding.find(embedding_id)
    assert_equal 0, embedding.chunk_index
  end

  def test_add_embedding_with_metadata
    file_path = create_test_file("embed_meta.txt", "Content for embedding")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "Content for embedding")

    document = Ragdoll::Document.find(doc_id)
    text_content = document.text_contents.first
    skip "Document has no text content" unless text_content

    # Use 1536 dimensions (OpenAI default)
    embedding_id = Ragdoll::DocumentManagement.add_embedding(
      text_content.id,
      1,
      Array.new(1536) { rand },
      { embeddable_type: "Ragdoll::TextContent", content: "Specific chunk content" }
    )

    embedding = Ragdoll::Embedding.find(embedding_id)
    assert_equal "Specific chunk content", embedding.content
  end

  # Edge cases
  def test_add_document_with_empty_content
    file_path = create_test_file("empty.txt", "")
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, "")

    document = Ragdoll::Document.find(doc_id)
    assert document.present?
  end

  def test_add_document_with_unicode_content
    unicode_content = "Hello 世界! 🌍 Привет мир"
    file_path = create_test_file("unicode.txt", unicode_content)
    doc_id = Ragdoll::DocumentManagement.add_document(file_path, unicode_content)

    result = Ragdoll::DocumentManagement.get_document(doc_id)
    assert_equal unicode_content, result[:content]
  end

  def test_add_document_expands_relative_path
    file_path = create_test_file("relative.txt", "Content")
    relative_path = File.join(".", File.basename(file_path))

    # Change to the test directory to test relative path expansion
    Dir.chdir(@test_dir) do
      doc_id = Ragdoll::DocumentManagement.add_document(relative_path, "Content")
      document = Ragdoll::Document.find(doc_id)
      # Location should be expanded to absolute path
      assert document.location.start_with?("/")
    end
  end

  private

  def create_test_file(name, content)
    path = File.join(@test_dir, name)
    File.write(path, content)
    path
  end
end
