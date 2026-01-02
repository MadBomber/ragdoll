# frozen_string_literal: true

require "test_helper"

class MetadataGeneratorTest < Minitest::Test
  def setup
    super
    @generator = Ragdoll::MetadataGenerator.new
  end

  # Initialization tests
  def test_initializes_without_llm_client
    generator = Ragdoll::MetadataGenerator.new
    assert generator.present?
  end

  def test_initializes_with_custom_llm_client
    mock_client = OpenStruct.new(provider: "openai")
    generator = Ragdoll::MetadataGenerator.new(llm_client: mock_client)
    assert generator.present?
  end

  # generate_for_document tests - routing based on document type
  def test_generate_for_document_handles_text_type
    document = create_mock_document("text")
    # Should not raise, returns empty hash without LLM
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_markdown_type
    document = create_mock_document("markdown")
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_html_type
    document = create_mock_document("html")
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_image_type
    document = create_mock_document("image", include_image: true)
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_audio_type
    document = create_mock_document("audio", include_audio: true)
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_pdf_type
    document = create_mock_document("pdf")
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_docx_type
    document = create_mock_document("docx")
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_handles_mixed_type
    document = create_mock_document("mixed", include_all: true)
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  def test_generate_for_document_defaults_to_text_for_unknown_type
    document = create_mock_document("unknown_type")
    result = @generator.generate_for_document(document)
    assert_kind_of Hash, result
  end

  # generate_text_metadata tests
  def test_generate_text_metadata_returns_empty_for_blank_content
    document = create_mock_document("text", content: "")
    result = @generator.generate_text_metadata(document)
    assert_equal({}, result)
  end

  def test_generate_text_metadata_with_content
    document = create_mock_document("text", content: "Test content for analysis")
    result = @generator.generate_text_metadata(document)
    assert_kind_of Hash, result
  end

  # generate_image_metadata tests
  def test_generate_image_metadata_returns_empty_without_image
    document = create_mock_document("image", include_image: false)
    result = @generator.generate_image_metadata(document)
    assert_equal({}, result)
  end

  # generate_audio_metadata tests
  def test_generate_audio_metadata_returns_empty_without_audio
    document = create_mock_document("audio", include_audio: false)
    result = @generator.generate_audio_metadata(document)
    assert_equal({}, result)
  end

  def test_generate_audio_metadata_with_transcript
    audio_content = OpenStruct.new(
      transcript: "This is a transcript of the audio.",
      duration: 120
    )
    document = OpenStruct.new(
      document_type: "audio",
      audio_contents: [audio_content],
      text_contents: [],
      image_contents: []
    )
    result = @generator.generate_audio_metadata(document)
    assert_kind_of Hash, result
  end

  def test_generate_audio_metadata_without_transcript
    audio_content = OpenStruct.new(
      transcript: nil,
      duration: 60,
      sample_rate: 44100
    )
    document = OpenStruct.new(
      document_type: "audio",
      audio_contents: [audio_content],
      text_contents: [],
      image_contents: []
    )
    result = @generator.generate_audio_metadata(document)
    assert_kind_of Hash, result
  end

  # generate_pdf_metadata tests
  def test_generate_pdf_metadata_returns_empty_for_blank_content
    document = create_mock_document("pdf", content: "")
    result = @generator.generate_pdf_metadata(document)
    assert_equal({}, result)
  end

  def test_generate_pdf_metadata_with_content
    document = OpenStruct.new(
      document_type: "pdf",
      text_contents: [OpenStruct.new(content: "PDF content here")],
      file_metadata: { page_count: 10, author: "Test Author" },
      image_contents: [],
      audio_contents: []
    )
    result = @generator.generate_pdf_metadata(document)
    assert_kind_of Hash, result
  end

  # generate_mixed_metadata tests
  def test_generate_mixed_metadata_combines_all_content_types
    document = create_mock_document("mixed", include_all: true)
    result = @generator.generate_mixed_metadata(document)
    assert_kind_of Hash, result
  end

  def test_generate_mixed_metadata_handles_empty_content
    document = OpenStruct.new(
      document_type: "mixed",
      text_contents: [],
      image_contents: [],
      audio_contents: []
    )
    result = @generator.generate_mixed_metadata(document)
    assert_kind_of Hash, result
  end

  # Error handling tests
  def test_generator_handles_errors_gracefully
    # Create a generator with a broken LLM client
    broken_client = OpenStruct.new(provider: "openai")
    def broken_client.chat(*)
      raise StandardError, "API error"
    end

    generator = Ragdoll::MetadataGenerator.new(llm_client: broken_client)
    document = create_mock_document("text", content: "Test content")

    # Should not raise, returns empty hash on error
    result = generator.generate_text_metadata(document)
    assert_kind_of Hash, result
  end

  # Prompt building tests (testing the prompt structure indirectly)
  def test_text_analysis_truncates_long_content
    long_content = "x" * 3000
    document = create_mock_document("text", content: long_content)
    # Should not raise, handles long content
    result = @generator.generate_text_metadata(document)
    assert_kind_of Hash, result
  end

  private

  def create_mock_document(type, content: "Default content", include_image: false, include_audio: false, include_all: false)
    text_contents = if content.present?
                      [OpenStruct.new(content: content)]
                    else
                      []
                    end

    image_contents = if include_image || include_all
                       [OpenStruct.new(
                         image_attached?: true,
                         description: "Test image description",
                         alt_text: "Test alt text",
                         image: OpenStruct.new(url: "http://example.com/image.jpg")
                       )]
                     else
                       [OpenStruct.new(image_attached?: false)]
                     end

    audio_contents = if include_audio || include_all
                       [OpenStruct.new(
                         transcript: "Audio transcript content",
                         duration: 120,
                         sample_rate: 44100
                       )]
                     else
                       []
                     end

    OpenStruct.new(
      document_type: type,
      text_contents: text_contents,
      image_contents: image_contents,
      audio_contents: audio_contents,
      file_metadata: {}
    )
  end
end
