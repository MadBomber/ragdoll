# frozen_string_literal: true

require_relative "../../test_helper"

class Ragdoll::UnifiedContentTest < Minitest::Test
  def setup
    super
    skip("Skipping database test in CI environment") if ci_environment?
    @document = create_test_document
  end

  def test_create_unified_content
    content = Ragdoll::UnifiedContent.create!(
      document: @document,
      content: "This is test content for unified RAG system.",
      original_media_type: "text",
      embedding_model: "text-embedding-3-large",
      metadata: { source: "test" }
    )

    assert content.persisted?
    assert_equal "This is test content for unified RAG system.", content.content
    assert_equal "text", content.original_media_type
    assert_equal "text-embedding-3-large", content.embedding_model
    assert_equal @document.id, content.document_id
  end

  def test_validations
    content = Ragdoll::UnifiedContent.new

    refute content.valid?
    assert_includes content.errors[:content], "can't be blank"
    assert_includes content.errors[:embedding_model], "can't be blank"
    assert_includes content.errors[:document_id], "can't be blank"
    assert_includes content.errors[:original_media_type], "can't be blank"
  end

  def test_original_media_type_validation
    content = Ragdoll::UnifiedContent.new(
      document: @document,
      content: "Test content",
      embedding_model: "test-model",
      original_media_type: "invalid_type"
    )

    refute content.valid?
    assert_includes content.errors[:original_media_type], "is not included in the list"
  end

  def test_word_count
    content = create_unified_content("This is a test with five words.")

    assert_equal 7, content.word_count
  end

  def test_word_count_with_minimal_content
    # Test word count calculation with minimal content that contains only punctuation with spaces
    content = create_unified_content("...   !!!")  # Punctuation with spaces - split gives 2 tokens

    assert_equal 2, content.word_count
  end

  def test_character_count
    content = create_unified_content("Test content")

    assert_equal 12, content.character_count
  end

  def test_media_type_predicates
    text_content = create_unified_content("Text", "text")
    assert text_content.text_content?
    refute text_content.image_content?
    refute text_content.audio_content?
    refute text_content.video_content?

    image_content = create_unified_content("Image description", "image")
    refute image_content.text_content?
    assert image_content.image_content?
    refute image_content.audio_content?
    refute image_content.video_content?

    audio_content = create_unified_content("Audio transcript", "audio")
    refute audio_content.text_content?
    refute audio_content.image_content?
    assert audio_content.audio_content?
    refute audio_content.video_content?
  end

  def test_metadata_accessors
    content = create_unified_content("Test content")

    content.original_filename = "test.txt"
    assert_equal "test.txt", content.original_filename

    content.file_size = 1024
    assert_equal 1024, content.file_size

    content.conversion_method = "text_extraction"
    assert_equal "text_extraction", content.conversion_method
  end

  def test_content_quality_score
    # High quality content (good length, text type)
    high_quality = create_unified_content("This is a substantial piece of content with meaningful information that would be valuable for search and retrieval. " * 10, "text")
    score = high_quality.content_quality_score
    assert score > 0.7, "Expected high quality score, got #{score}"

    # Low quality content (very short)
    low_quality = create_unified_content("Short", "text")
    score = low_quality.content_quality_score
    assert score < 0.7, "Expected low quality score, got #{score}"

    # Fallback content (image file placeholder)
    fallback = create_unified_content("Image file: sample.jpg", "image")
    score = fallback.content_quality_score
    assert score < 0.5, "Expected very low quality score for fallback, got #{score}"
  end

  def test_scopes
    text_content = create_unified_content("Text content", "text")
    image_content = create_unified_content("Image description", "image")

    # Test by_media_type scope
    text_results = Ragdoll::UnifiedContent.by_media_type("text")
    assert_includes text_results, text_content
    refute_includes text_results, image_content

    image_results = Ragdoll::UnifiedContent.by_media_type("image")
    assert_includes image_results, image_content
    refute_includes image_results, text_content
  end

  def test_search_content
    content1 = create_unified_content("Ruby programming language tutorial")
    content2 = create_unified_content("Python data analysis guide")
    content3 = create_unified_content("JavaScript web development")

    # Search for Ruby-related content
    results = Ragdoll::UnifiedContent.search_content("Ruby programming")
    assert_includes results, content1
    refute_includes results, content2

    # Search for programming-related content
    results = Ragdoll::UnifiedContent.search_content("programming")
    assert_includes results, content1
    refute_includes results, content2
  end

  def test_stats
    # Get initial count to adjust expectations
    initial_count = Ragdoll::UnifiedContent.count

    create_unified_content("Short", "text")
    create_unified_content("Medium length content with some words here", "image")
    create_unified_content("Very long content with substantial information that exceeds the typical short content threshold and provides meaningful data for analysis and retrieval purposes in the system", "audio")

    stats = Ragdoll::UnifiedContent.stats

    assert_equal initial_count + 3, stats[:total_contents]
    assert stats[:by_media_type]["text"] >= 1
    assert stats[:by_media_type]["image"] >= 1
    assert stats[:by_media_type]["audio"] >= 1

    assert stats[:content_quality_distribution].is_a?(Hash)
    assert stats[:content_quality_distribution].key?(:high)
    assert stats[:content_quality_distribution].key?(:medium)
    assert stats[:content_quality_distribution].key?(:low)
  end

  def test_should_generate_embeddings
    content = create_unified_content("Test content")

    # Should generate embeddings when content exists and no embeddings present
    assert content.should_generate_embeddings?

    # Mock having embeddings
    mock_embedding = Object.new
    mock_embedding.define_singleton_method(:id) { 1 }

    content.stub(:embeddings, [mock_embedding]) do
      refute content.should_generate_embeddings?
    end
  end

  def test_generate_embeddings_with_mock
    content = create_unified_content("Test content for embedding generation")

    # Mock the embedding service and text chunker
    mock_chunks = ["Test content for", "embedding generation"]
    mock_embeddings = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]]

    mock_chunker = Minitest::Mock.new
    mock_chunker.expect(:chunk, mock_chunks, [content.content])

    mock_service = Minitest::Mock.new
    mock_embeddings.each_with_index do |embedding, index|
      mock_service.expect(:generate_embedding, embedding, [mock_chunks[index]])
    end

    Ragdoll::TextChunker.stub(:chunk, mock_chunks) do
      Ragdoll::EmbeddingService.stub(:new, mock_service) do
        # Mock the embeddings.create! calls
        content.embeddings.stub(:destroy_all, true) do
          content.embeddings.stub(:create!, true) do
            content.generate_embeddings!
          end
        end
      end
    end

    mock_service.verify
  end

  private

  def create_test_document
    # Use unique location to avoid constraint violations
    unique_id = rand(100000)
    Ragdoll::Document.create!(
      location: "/tmp/test_#{unique_id}.txt",
      title: "Test Document #{unique_id}",
      content: "Test content",
      document_type: "text",
      status: "processed",
      file_modified_at: Time.current
    )
  end

  def create_unified_content(content_text, media_type = "text")
    Ragdoll::UnifiedContent.create!(
      document: @document,
      content: content_text,
      original_media_type: media_type,
      embedding_model: "text-embedding-3-large",
      metadata: { source: "test" }
    )
  end
end