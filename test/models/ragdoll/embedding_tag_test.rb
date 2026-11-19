# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class EmbeddingTagTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::EmbeddingTag.delete_all
    Ragdoll::Embedding.delete_all
    Ragdoll::Tag.delete_all
    Ragdoll::Document.delete_all
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_embedding_tag_can_be_created
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert emb_tag.persisted?
  end

  def test_embedding_tag_stores_confidence
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.75,
      source: "auto"
    )
    assert_equal 0.75, emb_tag.confidence
  end

  def test_embedding_tag_stores_source
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "manual"
    )
    assert_equal "manual", emb_tag.source
  end

  # Validation tests
  def test_embedding_tag_requires_embedding_id
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.new(tag: tag, confidence: 0.9, source: "auto")
    refute emb_tag.valid?
    assert_includes emb_tag.errors[:embedding_id], "can't be blank"
  end

  def test_embedding_tag_requires_tag_id
    document = create_test_document
    embedding = create_test_embedding(document)
    emb_tag = Ragdoll::EmbeddingTag.new(embedding: embedding, confidence: 0.9, source: "auto")
    refute emb_tag.valid?
    assert_includes emb_tag.errors[:tag_id], "can't be blank"
  end

  def test_embedding_tag_uniqueness
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    duplicate = Ragdoll::EmbeddingTag.new(
      embedding: embedding,
      tag: tag,
      confidence: 0.8,
      source: "manual"
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:embedding_id], "has already been taken"
  end

  def test_embedding_tag_confidence_minimum
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.new(
      embedding: embedding,
      tag: tag,
      confidence: -0.1,
      source: "auto"
    )
    refute emb_tag.valid?
    assert emb_tag.errors[:confidence].any?
  end

  def test_embedding_tag_confidence_maximum
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.new(
      embedding: embedding,
      tag: tag,
      confidence: 1.1,
      source: "auto"
    )
    refute emb_tag.valid?
    assert emb_tag.errors[:confidence].any?
  end

  def test_embedding_tag_source_must_be_valid
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.new(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "invalid"
    )
    refute emb_tag.valid?
    assert emb_tag.errors[:source].any?
  end

  # Association tests
  def test_embedding_tag_belongs_to_embedding
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert_equal embedding.id, emb_tag.embedding.id
  end

  def test_embedding_tag_belongs_to_tag
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    emb_tag = Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert_equal tag.id, emb_tag.tag.id
  end

  # Callback tests
  def test_creating_embedding_tag_increments_tag_usage
    document = create_test_document
    embedding = create_test_embedding(document)
    tag = create_test_tag
    initial_count = tag.usage_count
    Ragdoll::EmbeddingTag.create!(
      embedding: embedding,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    tag.reload
    assert_equal initial_count + 1, tag.usage_count
  end

  # Scope tests
  def test_auto_extracted_scope
    document = create_test_document
    embedding = create_test_embedding(document)
    tag1 = create_test_tag("auto-tag")
    tag2 = create_test_tag("manual-tag")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag2, confidence: 0.9, source: "manual")
    auto = Ragdoll::EmbeddingTag.auto_extracted
    assert_equal 1, auto.count
    assert_equal tag1.id, auto.first.tag_id
  end

  def test_manual_scope
    document = create_test_document
    embedding = create_test_embedding(document)
    tag1 = create_test_tag("auto-tag")
    tag2 = create_test_tag("manual-tag")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag2, confidence: 0.9, source: "manual")
    manual = Ragdoll::EmbeddingTag.manual
    assert_equal 1, manual.count
    assert_equal tag2.id, manual.first.tag_id
  end

  def test_high_confidence_scope
    document = create_test_document
    embedding = create_test_embedding(document)
    tag1 = create_test_tag("high-conf")
    tag2 = create_test_tag("low-conf")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag2, confidence: 0.5, source: "auto")
    high_conf = Ragdoll::EmbeddingTag.high_confidence
    assert_equal 1, high_conf.count
    assert_equal tag1.id, high_conf.first.tag_id
  end

  def test_by_confidence_scope_orders_desc
    document = create_test_document
    embedding = create_test_embedding(document)
    tag1 = create_test_tag("low-conf")
    tag2 = create_test_tag("high-conf")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag1, confidence: 0.3, source: "auto")
    Ragdoll::EmbeddingTag.create!(embedding: embedding, tag: tag2, confidence: 0.9, source: "auto")
    ordered = Ragdoll::EmbeddingTag.by_confidence
    assert_equal tag2.id, ordered.first.tag_id
  end

  # Multiple embedding tags test
  def test_same_tag_different_embeddings
    document = create_test_document
    embedding1 = create_test_embedding(document, 0)
    embedding2 = create_test_embedding(document, 1)
    tag = create_test_tag
    emb_tag1 = Ragdoll::EmbeddingTag.create!(
      embedding: embedding1,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    emb_tag2 = Ragdoll::EmbeddingTag.create!(
      embedding: embedding2,
      tag: tag,
      confidence: 0.85,
      source: "auto"
    )
    assert emb_tag1.persisted?
    assert emb_tag2.persisted?
    refute_equal emb_tag1.id, emb_tag2.id
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

  def create_test_embedding(document, chunk_index = 0)
    Ragdoll::Embedding.create!(
      embeddable: document,
      content: "Test embedding content chunk #{chunk_index}",
      chunk_index: chunk_index,
      embedding_vector: [0.1] * 1536
    )
  end

  def create_test_tag(name = "test-tag")
    Ragdoll::Tag.create!(name: name)
  end
end
