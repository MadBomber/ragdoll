# frozen_string_literal: true

require_relative "../test_helper"
require "securerandom"
require "digest"

class DocumentManagementTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
  end

  def test_add_document_with_metadata
    location = "/path/to/document.txt"
    content = "This is the document content"
    metadata = {
      title: "Test Document",
      document_type: "text",
      author: "Test Author"
    }

    doc_id = Ragdoll::DocumentManagement.add_document(location, content, metadata)

    assert_match(/^\d+$/, doc_id)
    document = Ragdoll::Document.find(doc_id)
    assert_equal "Test Document", document.title
    assert_equal "text", document.document_type
    assert_equal "Test Author", document.metadata["author"]
    assert_equal content, document.content
    assert_equal File.expand_path(location), document.location
  end

  def test_add_document_minimal_data
    location = "/path/to/document.txt"
    content = "This is the document content"

    doc_id = Ragdoll::DocumentManagement.add_document(location, content)

    assert_match(/^\d+$/, doc_id)
    document = Ragdoll::Document.find(doc_id)
    assert_equal "document", document.title # extracted from filename
    assert_equal "text", document.document_type # default
    assert_equal content, document.content
  end

  def test_get_document_existing
    document = create_test_document

    result = Ragdoll::DocumentManagement.get_document(document.id)

    refute_nil result
    assert_equal document.id.to_s, result[:id]
    assert_equal document.title, result[:title]
    assert_equal document.content, result[:content]
    assert_equal document.location, result[:location]
  end

  def test_get_document_nonexistent
    result = Ragdoll::DocumentManagement.get_document(999_999)

    assert_nil result
  end

  def test_update_document_existing
    document = create_test_document

    result = Ragdoll::DocumentManagement.update_document(
      document.id,
      title: "Updated Title",
      metadata: { updated: true }
    )

    refute_nil result
    assert_equal "Updated Title", result[:title]

    # Verify in database
    document.reload
    assert_equal "Updated Title", document.title
    assert_equal true, document.metadata["updated"]
  end

  def test_update_document_nonexistent
    result = Ragdoll::DocumentManagement.update_document(999_999, title: "New Title")

    assert_nil result
  end

  def test_delete_document_existing
    document = create_test_document

    result = Ragdoll::DocumentManagement.delete_document(document.id)

    assert_equal true, result
    assert_raises(ActiveRecord::RecordNotFound) do
      Ragdoll::Document.find(document.id)
    end
  end

  def test_delete_document_nonexistent
    result = Ragdoll::DocumentManagement.delete_document(999_999)

    assert_nil result
  end

  def test_list_documents_default
    create_test_document(title: "Document 1")
    create_test_document(title: "Document 2")
    create_test_document(title: "Document 3")

    result = Ragdoll::DocumentManagement.list_documents

    assert_kind_of Array, result
    assert_equal 3, result.length

    # Should be ordered by most recent first
    titles = result.map { |doc| doc[:title] }
    assert_includes titles, "Document 1"
    assert_includes titles, "Document 2"
    assert_includes titles, "Document 3"
  end

  def test_list_documents_with_pagination
    5.times do |i|
      create_test_document(title: "Document #{i + 1}")
    end

    result = Ragdoll::DocumentManagement.list_documents(limit: 3, offset: 1)

    assert_kind_of Array, result
    assert_equal 3, result.length
  end

  def test_get_document_stats
    # Create documents with different statuses
    create_test_document(status: "pending")
    create_test_document(status: "processing")
    create_test_document(status: "processed")
    create_test_document(status: "processed")

    stats = Ragdoll::DocumentManagement.get_document_stats

    assert_kind_of Hash, stats
    assert_equal 4, stats[:total_documents]
    assert stats.key?(:by_status)
    assert stats.key?(:by_type)
  end

  def test_add_embedding
    document = create_test_document

    # First create text content for the document
    text_content = document.text_contents.create!(
      content: "test content",
      embedding_model: "test-model"
    )

    embedding_id = Ragdoll::DocumentManagement.add_embedding(
      text_content.id,
      0,
      Array.new(1536) { |i| (i / 1536.0) },
      {
        content: "test content",
        embeddable_type: "Ragdoll::TextContent"
      }
    )

    assert_match(/^\d+$/, embedding_id)
    embedding = Ragdoll::Embedding.find(embedding_id)
    assert_equal text_content.id, embedding.embeddable_id
    assert_equal 0, embedding.chunk_index
    assert_equal 1536, embedding.embedding_vector.length
    assert_equal "test content", embedding.content
    assert_equal "test-model", embedding.embedding_model # Now accessed via polymorphic relationship
  end

  def test_extract_title_from_location_private_method
    # Test the private method indirectly through add_document
    doc_id = Ragdoll::DocumentManagement.add_document("/path/to/my_document.pdf", "content")
    document = Ragdoll::Document.find(doc_id)

    assert_equal "my_document", document.title
  end

  def test_handles_url_locations
    url = "http://example.com/document.pdf"
    doc_id = Ragdoll::DocumentManagement.add_document(url, "content")
    document = Ragdoll::Document.find(doc_id)

    assert_equal url, document.location # Should not be expanded for URLs
  end

  def test_handles_ftp_locations
    ftp_url = "ftp://example.com/document.pdf"
    doc_id = Ragdoll::DocumentManagement.add_document(ftp_url, "content")
    document = Ragdoll::Document.find(doc_id)

    assert_equal ftp_url, document.location # Should not be expanded for FTP URLs
  end

  def test_duplicate_detection_prevents_duplicate_by_location_and_time
    location = "/path/to/duplicate_test.txt"
    content = "This is test content"
    # Use a unique location for this test to avoid conflicts with other tests
    unique_location = "#{location}_#{SecureRandom.hex(4)}"

    # Stub file operations for non-existent file
    File.stub(:exist?, false) do
      # Create first document
      doc_id1 = Ragdoll::DocumentManagement.add_document(unique_location, content, {}, force: false)
      
      # Try to add the same document again - should return existing document ID  
      doc_id2 = Ragdoll::DocumentManagement.add_document(unique_location, content, {}, force: false)
      
      assert_equal doc_id1, doc_id2, "Should return existing document ID for duplicate"
      assert_equal 1, Ragdoll::Document.where(location: File.expand_path(unique_location)).count
    end
  end

  def test_force_option_allows_duplicates
    location = "/path/to/force_test.txt"
    content = "This is test content"
    file_modified_at = Time.current.beginning_of_minute

    # Stub file operations for non-existent file
    File.stub(:exist?, false) do
      # Create first document
      doc_id1 = Ragdoll::DocumentManagement.add_document(location, content, {}, force: false)
      
      # Force add the same document - should create a new one with modified location
      doc_id2 = Ragdoll::DocumentManagement.add_document(location, content, {}, force: true)
      
      refute_equal doc_id1, doc_id2, "Force option should create new document despite duplicate"
      
      # Verify both documents exist but with different locations (force adds timestamp)
      doc1 = Ragdoll::Document.find(doc_id1)
      doc2 = Ragdoll::Document.find(doc_id2)
      
      assert_equal File.expand_path(location), doc1.location
      assert doc2.location.start_with?(File.expand_path(location)), "Forced document should have modified location"
      refute_equal doc1.location, doc2.location, "Documents should have different locations when forced"
    end
  end

  def test_duplicate_detection_by_content_hash_for_urls
    url = "http://example.com/document.txt"
    content = "This is unique content for testing"
    metadata = { content_hash: Digest::SHA256.hexdigest(content) }

    # Create first document
    doc_id1 = Ragdoll::DocumentManagement.add_document(url, content, metadata, force: false)
    
    # Try to add document with same content hash but different URL
    different_url = "http://example.com/different-document.txt"
    doc_id2 = Ragdoll::DocumentManagement.add_document(different_url, content, metadata, force: false)
    
    assert_equal doc_id1, doc_id2, "Should detect duplicate by content hash"
  end

  private

  def create_test_document(options = {})
    # Generate unique location to avoid constraint violations
    unique_id = SecureRandom.hex(8)

    Ragdoll::Document.create!({
      title: "Test Document",
      location: "/test/document_#{unique_id}.txt",
      document_type: "text",
      content: "Test content",
      status: "processed",
      metadata: {},
      file_modified_at: Time.current
    }.merge(options))
  end
end
