# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class DocumentTagTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::DocumentTag.delete_all
    Ragdoll::Tag.delete_all
    Ragdoll::Document.delete_all
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_document_tag_can_be_created
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert doc_tag.persisted?
  end

  def test_document_tag_stores_confidence
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.85,
      source: "auto"
    )
    assert_equal 0.85, doc_tag.confidence
  end

  def test_document_tag_stores_source
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "manual"
    )
    assert_equal "manual", doc_tag.source
  end

  # Validation tests
  def test_document_tag_requires_document_id
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.new(tag: tag, confidence: 0.9, source: "auto")
    refute doc_tag.valid?
    assert_includes doc_tag.errors[:document_id], "can't be blank"
  end

  def test_document_tag_requires_tag_id
    document = create_test_document
    doc_tag = Ragdoll::DocumentTag.new(document: document, confidence: 0.9, source: "auto")
    refute doc_tag.valid?
    assert_includes doc_tag.errors[:tag_id], "can't be blank"
  end

  def test_document_tag_uniqueness
    document = create_test_document
    tag = create_test_tag
    Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    duplicate = Ragdoll::DocumentTag.new(
      document: document,
      tag: tag,
      confidence: 0.8,
      source: "manual"
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:document_id], "has already been taken"
  end

  def test_document_tag_confidence_minimum
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.new(
      document: document,
      tag: tag,
      confidence: -0.1,
      source: "auto"
    )
    refute doc_tag.valid?
    assert doc_tag.errors[:confidence].any?
  end

  def test_document_tag_confidence_maximum
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.new(
      document: document,
      tag: tag,
      confidence: 1.1,
      source: "auto"
    )
    refute doc_tag.valid?
    assert doc_tag.errors[:confidence].any?
  end

  def test_document_tag_confidence_valid_range
    document = create_test_document
    tag = create_test_tag
    [0, 0.5, 1].each do |conf|
      doc_tag = Ragdoll::DocumentTag.new(
        document: document,
        tag: tag,
        confidence: conf,
        source: "auto"
      )
      assert doc_tag.valid?, "Should be valid with confidence #{conf}"
      # Clean up for next iteration
      Ragdoll::DocumentTag.delete_all
    end
  end

  def test_document_tag_source_must_be_auto_or_manual
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.new(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "invalid"
    )
    refute doc_tag.valid?
    assert doc_tag.errors[:source].any?
  end

  # Association tests
  def test_document_tag_belongs_to_document
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert_equal document.id, doc_tag.document.id
  end

  def test_document_tag_belongs_to_tag
    document = create_test_document
    tag = create_test_tag
    doc_tag = Ragdoll::DocumentTag.create!(
      document: document,
      tag: tag,
      confidence: 0.9,
      source: "auto"
    )
    assert_equal tag.id, doc_tag.tag.id
  end

  # Callback tests
  def test_creating_document_tag_increments_tag_usage
    document = create_test_document
    tag = create_test_tag
    initial_count = tag.usage_count
    Ragdoll::DocumentTag.create!(
      document: document,
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
    tag1 = create_test_tag("auto-tag")
    tag2 = create_test_tag("manual-tag")
    Ragdoll::DocumentTag.create!(document: document, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::DocumentTag.create!(document: document, tag: tag2, confidence: 0.9, source: "manual")
    auto = Ragdoll::DocumentTag.auto_extracted
    assert_equal 1, auto.count
    assert_equal tag1.id, auto.first.tag_id
  end

  def test_manual_scope
    document = create_test_document
    tag1 = create_test_tag("auto-tag")
    tag2 = create_test_tag("manual-tag")
    Ragdoll::DocumentTag.create!(document: document, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::DocumentTag.create!(document: document, tag: tag2, confidence: 0.9, source: "manual")
    manual = Ragdoll::DocumentTag.manual
    assert_equal 1, manual.count
    assert_equal tag2.id, manual.first.tag_id
  end

  def test_high_confidence_scope
    document = create_test_document
    tag1 = create_test_tag("high-conf")
    tag2 = create_test_tag("low-conf")
    Ragdoll::DocumentTag.create!(document: document, tag: tag1, confidence: 0.9, source: "auto")
    Ragdoll::DocumentTag.create!(document: document, tag: tag2, confidence: 0.5, source: "auto")
    high_conf = Ragdoll::DocumentTag.high_confidence
    assert_equal 1, high_conf.count
    assert_equal tag1.id, high_conf.first.tag_id
  end

  def test_by_confidence_scope_orders_desc
    document = create_test_document
    tag1 = create_test_tag("low-conf")
    tag2 = create_test_tag("high-conf")
    Ragdoll::DocumentTag.create!(document: document, tag: tag1, confidence: 0.3, source: "auto")
    Ragdoll::DocumentTag.create!(document: document, tag: tag2, confidence: 0.9, source: "auto")
    ordered = Ragdoll::DocumentTag.by_confidence
    assert_equal tag2.id, ordered.first.tag_id
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

  def create_test_tag(name = "test-tag")
    Ragdoll::Tag.create!(name: name)
  end
end
