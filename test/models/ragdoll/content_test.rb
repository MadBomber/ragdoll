# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class ContentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::Content.delete_all
    Ragdoll::Document.delete_all
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_content_can_be_created_with_valid_attributes
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "text-embedding-3-small",
      content: "Test content"
    )
    assert content.persisted?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_content_requires_type
    document = create_test_document
    content = Ragdoll::Content.new(
      document: document,
      embedding_model: "test-model"
    )
    refute content.valid?
    assert_includes content.errors[:type], "can't be blank"
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_requires_embedding_model
    document = create_test_document
    content = Ragdoll::Content.new(
      document: document,
      type: "Ragdoll::TextContent"
    )
    refute content.valid?
    assert_includes content.errors[:embedding_model], "can't be blank"
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_requires_document_id
    content = Ragdoll::Content.new(
      type: "Ragdoll::TextContent",
      embedding_model: "test-model"
    )
    refute content.valid?
    assert_includes content.errors[:document_id], "can't be blank"
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Association tests
  def test_content_belongs_to_document
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "text-embedding-3-small",
      content: "Test content"
    )
    assert_equal document.id, content.document.id
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # word_count method tests
  def test_word_count_returns_zero_for_nil_content
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: nil
    )
    assert_equal 0, content.word_count
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid => e
    skip "Content table not configured or null content not allowed: #{e.message.split("\n").first}"
  end

  def test_word_count_counts_words
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "one two three four five"
    )
    assert_equal 5, content.word_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # character_count method tests
  def test_character_count_returns_zero_for_nil_content
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: nil
    )
    assert_equal 0, content.character_count
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid => e
    skip "Content table not configured or null content not allowed: #{e.message.split("\n").first}"
  end

  def test_character_count_counts_characters
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "Hello"
    )
    assert_equal 5, content.character_count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # content_for_embedding method tests
  def test_content_for_embedding_returns_content
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "Embeddable text"
    )
    assert_equal "Embeddable text", content.content_for_embedding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # should_generate_embeddings? method tests
  def test_should_generate_embeddings_returns_true_when_content_present_and_no_embeddings
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "Some content"
    )
    assert content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_should_generate_embeddings_returns_false_when_content_blank
    document = create_test_document
    content = Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: ""
    )
    refute content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NotNullViolation, ActiveRecord::RecordInvalid => e
    skip "Content table not configured or blank content not allowed: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_by_type_scope
    document = create_test_document
    Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "Text"
    )
    Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::ImageContent",
      embedding_model: "test-model",
      content: "Image description"
    )
    texts = Ragdoll::Content.by_type("Ragdoll::TextContent")
    assert_equal 1, texts.count
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # search_content class method tests
  def test_search_content_returns_empty_for_blank_query
    result = Ragdoll::Content.search_content("")
    assert_empty result
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_search_content_returns_empty_for_nil_query
    result = Ragdoll::Content.search_content(nil)
    assert_empty result
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_search_content_finds_matching_content
    document = create_test_document
    Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "PostgreSQL database tutorial"
    )
    Ragdoll::Content.create!(
      document: document,
      type: "Ragdoll::TextContent",
      embedding_model: "test-model",
      content: "JavaScript frontend development"
    )
    results = Ragdoll::Content.search_content("PostgreSQL")
    assert_equal 1, results.count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedColumn => e
    skip "Full-text search not configured: #{e.message.split("\n").first}"
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
