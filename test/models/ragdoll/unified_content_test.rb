# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class UnifiedContentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::UnifiedContent.delete_all rescue nil
    Ragdoll::Document.delete_all
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_unified_content_can_be_created
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Test unified content",
      embedding_model: "text-embedding-3-large",
      original_media_type: "text"
    )
    assert content.persisted?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_unified_content_requires_content
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      embedding_model: "test-model",
      original_media_type: "text"
    )
    refute content.valid?
    assert_includes content.errors[:content], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_content_requires_embedding_model
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Test",
      original_media_type: "text"
    )
    refute content.valid?
    assert_includes content.errors[:embedding_model], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_content_requires_original_media_type
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Test",
      embedding_model: "test-model"
    )
    refute content.valid?
    assert_includes content.errors[:original_media_type], "can't be blank"
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_unified_content_validates_media_type_inclusion
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Test",
      embedding_model: "test-model",
      original_media_type: "invalid_type"
    )
    refute content.valid?
    assert content.errors[:original_media_type].any?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # word_count tests
  def test_word_count_returns_count
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "one two three four",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert_equal 4, content.word_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_word_count_returns_zero_for_nil
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert_equal 0, content.word_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # character_count tests
  def test_character_count_returns_count
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Hello",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert_equal 5, content.character_count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Media type query methods
  def test_text_content_returns_true_for_text_types
    %w[text markdown html pdf docx].each do |type|
      document = create_test_document
      content = Ragdoll::UnifiedContent.new(
        document: document,
        content: "Test",
        embedding_model: "test-model",
        original_media_type: type
      )
      assert content.text_content?, "Should return true for #{type}"
    end
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_image_content_returns_true_for_image
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Image description",
      embedding_model: "test-model",
      original_media_type: "image"
    )
    assert content.image_content?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_content_returns_true_for_audio
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Audio transcript",
      embedding_model: "test-model",
      original_media_type: "audio"
    )
    assert content.audio_content?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_video_content_returns_true_for_video
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Video description",
      embedding_model: "test-model",
      original_media_type: "video"
    )
    assert content.video_content?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Metadata accessor tests
  def test_original_filename_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Test",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    content.original_filename = "test.txt"
    content.save!
    content.reload
    assert_equal "test.txt", content.original_filename
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_file_size_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Test",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    content.file_size = 1024
    content.save!
    content.reload
    assert_equal 1024, content.file_size
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_conversion_method_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Test",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    content.conversion_method = "pdf_to_text"
    content.save!
    content.reload
    assert_equal "pdf_to_text", content.conversion_method
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Audio duration metadata tests
  def test_audio_duration_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Transcript",
      embedding_model: "test-model",
      original_media_type: "audio"
    )
    content.audio_duration = 180.5
    content.save!
    content.reload
    assert_equal 180.5, content.audio_duration
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Image dimension metadata tests
  def test_image_dimensions_returns_nil_when_not_set
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "Description",
      embedding_model: "test-model",
      original_media_type: "image"
    )
    assert_nil content.image_dimensions
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # content_quality_score tests
  def test_content_quality_score_returns_zero_for_blank_content
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert_equal 0.0, content.content_quality_score
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_quality_score_returns_positive_for_content
    document = create_test_document
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: "This is some test content with multiple words.",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert content.content_quality_score > 0
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_quality_score_capped_at_one
    document = create_test_document
    long_content = "word " * 500
    content = Ragdoll::UnifiedContent.new(
      document: document,
      content: long_content,
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert content.content_quality_score <= 1.0
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # should_generate_embeddings? tests
  def test_should_generate_embeddings_returns_true_when_content_present
    document = create_test_document
    content = Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Test content",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    assert content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_by_media_type_scope
    document = create_test_document
    Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Text",
      embedding_model: "test-model",
      original_media_type: "text"
    )
    Ragdoll::UnifiedContent.create!(
      document: document,
      content: "Image desc",
      embedding_model: "test-model",
      original_media_type: "image"
    )
    texts = Ragdoll::UnifiedContent.by_media_type("text")
    assert_equal 1, texts.count
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # search_content class method tests
  def test_search_content_returns_empty_for_blank_query
    result = Ragdoll::UnifiedContent.search_content("")
    assert_empty result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  # stats class method tests
  def test_stats_returns_hash
    result = Ragdoll::UnifiedContent.stats
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
  end

  def test_stats_includes_total_contents
    result = Ragdoll::UnifiedContent.stats
    assert result.key?(:total_contents)
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable => e
    skip "Unified content table not configured: #{e.message.split("\n").first}"
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
