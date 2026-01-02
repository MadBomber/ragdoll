# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class TextContentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::TextContent.delete_all
    Ragdoll::Document.delete_all
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Inheritance tests
  def test_text_content_inherits_from_content
    assert Ragdoll::TextContent < Ragdoll::Content
  end

  # Initialization tests
  def test_text_content_can_be_created
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "text-embedding-3-small",
      content: "Test text content"
    )
    assert content.persisted?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_text_content_requires_content
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model"
    )
    refute content.valid?
    assert_includes content.errors[:content], "can't be blank"
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Metadata accessor tests
  def test_chunk_size_returns_default
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    assert_equal 1000, content.chunk_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_chunk_size_can_be_set
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    content.chunk_size = 500
    content.save!
    content.reload
    assert_equal 500, content.chunk_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_overlap_returns_default
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    assert_equal 200, content.overlap
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_overlap_can_be_set
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    content.overlap = 100
    content.save!
    content.reload
    assert_equal 100, content.overlap
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_encoding_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    content.encoding = "UTF-8"
    content.save!
    content.reload
    assert_equal "UTF-8", content.encoding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_line_count_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    content.line_count = 50
    content.save!
    content.reload
    assert_equal 50, content.line_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # word_count tests
  def test_word_count_returns_count
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "one two three"
    )
    assert_equal 3, content.word_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_word_count_returns_zero_for_nil
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model"
    )
    assert_equal 0, content.word_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # character_count tests
  def test_character_count_returns_count
    document = create_test_document
    content = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Hello"
    )
    assert_equal 5, content.character_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # chunks method tests
  def test_chunks_returns_empty_for_blank_content
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model",
      content: ""
    )
    assert_empty content.chunks
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_chunks_returns_array_of_hashes
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model",
      content: "This is some test content that will be chunked."
    )
    chunks = content.chunks
    assert_kind_of Array, chunks
    assert chunks.all? { |c| c.is_a?(Hash) }
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_chunks_include_content_key
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    chunks = content.chunks
    assert chunks.first.key?(:content)
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_chunks_include_position_keys
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Test content"
    )
    chunks = content.chunks
    assert chunks.first.key?(:start_position)
    assert chunks.first.key?(:end_position)
    assert chunks.first.key?(:chunk_index)
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # content_for_embedding tests
  def test_content_for_embedding_returns_content
    document = create_test_document
    content = Ragdoll::TextContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Embeddable text"
    )
    assert_equal "Embeddable text", content.content_for_embedding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_recent_scope_orders_by_created_at_desc
    document = create_test_document
    older = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Older"
    )
    sleep(0.01)
    newer = Ragdoll::TextContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Newer"
    )
    recent = Ragdoll::TextContent.recent
    assert_equal newer.id, recent.first.id
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # stats class method tests
  def test_stats_returns_hash
    result = Ragdoll::TextContent.stats
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_stats_includes_total_text_contents
    result = Ragdoll::TextContent.stats
    assert result.key?(:total_text_contents)
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  private

  def create_test_document(filename = "test_document.txt")
    file_path = File.join(@test_dir, filename)
    File.write(file_path, "Test document content.")
    Ragdoll::Document.create!(
      location: file_path,
      title: filename,
      document_type: "text",
      status: "processed"
    )
  end
end
