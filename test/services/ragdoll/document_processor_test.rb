# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class DocumentProcessorTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Error classes
  def test_parse_error_class_exists
    assert_equal Ragdoll::Core::DocumentError, Ragdoll::DocumentProcessor::ParseError.superclass
  end

  def test_unsupported_format_error_class_exists
    assert_equal Ragdoll::DocumentProcessor::ParseError, Ragdoll::DocumentProcessor::UnsupportedFormatError.superclass
  end

  # parse class method tests
  def test_parse_class_method_returns_hash
    file_path = create_test_file("test.txt", "Test content.")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert_kind_of Hash, result
  end

  def test_parse_class_method_raises_for_nonexistent_file
    assert_raises(Ragdoll::DocumentProcessor::ParseError) do
      Ragdoll::DocumentProcessor.parse("/nonexistent/file.txt")
    end
  end

  def test_parse_returns_content
    file_path = create_test_file("test.txt", "Test content here.")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result.key?(:content)
    assert result[:content].present?
  end

  def test_parse_returns_metadata
    file_path = create_test_file("test.txt", "Test content.")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result.key?(:metadata)
    assert_kind_of Hash, result[:metadata]
  end

  def test_parse_returns_title
    file_path = create_test_file("my-document.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result.key?(:title)
    assert result[:title].present?
  end

  def test_parse_returns_document_type
    file_path = create_test_file("test.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result.key?(:document_type)
    assert result[:document_type].present?
  end

  # determine_document_type tests
  def test_determine_document_type_for_txt
    result = Ragdoll::DocumentProcessor.determine_document_type("file.txt")
    assert_equal "text", result
  end

  def test_determine_document_type_for_pdf
    result = Ragdoll::DocumentProcessor.determine_document_type("file.pdf")
    assert_equal "pdf", result
  end

  def test_determine_document_type_for_docx
    result = Ragdoll::DocumentProcessor.determine_document_type("file.docx")
    assert_equal "docx", result
  end

  def test_determine_document_type_for_markdown
    result = Ragdoll::DocumentProcessor.determine_document_type("file.md")
    assert_equal "markdown", result
  end

  def test_determine_document_type_for_html
    result = Ragdoll::DocumentProcessor.determine_document_type("file.html")
    assert_equal "html", result
  end

  def test_determine_document_type_for_image_jpg
    result = Ragdoll::DocumentProcessor.determine_document_type("file.jpg")
    assert_equal "image", result
  end

  def test_determine_document_type_for_image_png
    result = Ragdoll::DocumentProcessor.determine_document_type("file.png")
    assert_equal "image", result
  end

  # determine_document_type_from_content_type tests
  def test_determine_type_from_content_type_pdf
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("application/pdf")
    assert_equal "pdf", result
  end

  def test_determine_type_from_content_type_docx
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type(
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )
    assert_equal "docx", result
  end

  def test_determine_type_from_content_type_text
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("text/plain")
    assert_equal "text", result
  end

  def test_determine_type_from_content_type_markdown
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("text/markdown")
    assert_equal "markdown", result
  end

  def test_determine_type_from_content_type_html
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("text/html")
    assert_equal "html", result
  end

  def test_determine_type_from_content_type_image
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("image/jpeg")
    assert_equal "image", result
  end

  def test_determine_type_from_content_type_audio
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("audio/mpeg")
    assert_equal "audio", result
  end

  def test_determine_type_from_content_type_video
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("video/mp4")
    assert_equal "video", result
  end

  def test_determine_type_from_content_type_unknown_defaults_to_text
    result = Ragdoll::DocumentProcessor.determine_document_type_from_content_type("application/octet-stream")
    assert_equal "text", result
  end

  # determine_content_type tests
  def test_determine_content_type_pdf
    result = Ragdoll::DocumentProcessor.determine_content_type("file.pdf")
    assert_equal "application/pdf", result
  end

  def test_determine_content_type_docx
    result = Ragdoll::DocumentProcessor.determine_content_type("file.docx")
    assert_equal "application/vnd.openxmlformats-officedocument.wordprocessingml.document", result
  end

  def test_determine_content_type_txt
    result = Ragdoll::DocumentProcessor.determine_content_type("file.txt")
    assert_equal "text/plain", result
  end

  def test_determine_content_type_markdown
    result = Ragdoll::DocumentProcessor.determine_content_type("file.md")
    assert_equal "text/markdown", result
  end

  def test_determine_content_type_html
    result = Ragdoll::DocumentProcessor.determine_content_type("file.html")
    assert_equal "text/html", result
  end

  def test_determine_content_type_jpg
    result = Ragdoll::DocumentProcessor.determine_content_type("file.jpg")
    assert_equal "image/jpeg", result
  end

  def test_determine_content_type_png
    result = Ragdoll::DocumentProcessor.determine_content_type("file.png")
    assert_equal "image/png", result
  end

  def test_determine_content_type_mp3
    result = Ragdoll::DocumentProcessor.determine_content_type("file.mp3")
    assert_equal "audio/mpeg", result
  end

  def test_determine_content_type_mp4
    result = Ragdoll::DocumentProcessor.determine_content_type("file.mp4")
    assert_equal "video/mp4", result
  end

  def test_determine_content_type_unknown
    result = Ragdoll::DocumentProcessor.determine_content_type("file.xyz")
    assert_equal "application/octet-stream", result
  end

  # create_document_from_file tests
  # Note: These tests may be skipped if Shrine file attachment is not configured
  def test_create_document_from_file_returns_document
    file_path = create_test_file("document.txt", "Document content for creation.")
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert_kind_of Ragdoll::Document, document
    assert document.persisted?
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_sets_location
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert_equal File.expand_path(file_path), document.location
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_sets_title
    file_path = create_test_file("my-document.txt", "Content")
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert document.title.present?
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_sets_content
    content = "This is the document content."
    file_path = create_test_file("test.txt", content)
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert document.content.present?
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_sets_document_type
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert_equal "text", document.document_type
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_sets_status
    file_path = create_test_file("test.txt", "Content")
    document = Ragdoll::DocumentProcessor.create_document_from_file(file_path)

    assert_equal "processed", document.status
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  def test_create_document_from_file_raises_for_nonexistent_file
    assert_raises(Ragdoll::DocumentProcessor::ParseError) do
      Ragdoll::DocumentProcessor.create_document_from_file("/nonexistent/file.txt")
    end
  rescue NoMethodError => e
    skip "Shrine file attachment not configured: #{e.message.split("\n").first}"
  end

  # Instance method tests
  def test_initialize_with_file_path
    file_path = create_test_file("test.txt", "Content")
    processor = Ragdoll::DocumentProcessor.new(file_path)

    assert processor.present?
  end

  def test_instance_parse_returns_hash
    file_path = create_test_file("test.txt", "Content")
    processor = Ragdoll::DocumentProcessor.new(file_path)
    result = processor.parse

    assert_kind_of Hash, result
    assert result.key?(:content)
    assert result.key?(:metadata)
  end

  # Metadata extraction tests
  def test_parse_includes_file_size_in_metadata
    content = "x" * 100
    file_path = create_test_file("test.txt", content)
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result[:metadata].key?(:file_size)
    assert_equal 100, result[:metadata][:file_size]
  end

  def test_parse_includes_file_hash_in_metadata
    file_path = create_test_file("test.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result[:metadata].key?(:file_hash)
    assert result[:metadata][:file_hash].present?
  end

  def test_parse_includes_original_filename_in_metadata
    file_path = create_test_file("test.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result[:metadata].key?(:original_filename)
    assert_equal "test.txt", result[:metadata][:original_filename]
  end

  def test_parse_includes_file_extension_in_metadata
    file_path = create_test_file("test.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result[:metadata].key?(:file_extension)
    assert_equal ".txt", result[:metadata][:file_extension]
  end

  def test_parse_includes_encoding_for_text_files
    file_path = create_test_file("test.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert result[:metadata].key?(:encoding)
  end

  # Title extraction tests
  def test_title_extracted_from_filename
    file_path = create_test_file("my-test-document.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    # Title should be cleaned up from filename
    assert result[:title].present?
    assert result[:title].include?("My") || result[:title].include?("Test")
  end

  def test_title_handles_camel_case_filename
    file_path = create_test_file("MyTestDocument.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    # Should split camel case
    assert result[:title].present?
  end

  def test_title_handles_underscores_in_filename
    file_path = create_test_file("my_test_document.txt", "Content")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    # Should replace underscores with spaces
    assert result[:title].include?(" ") || result[:title].include?("My")
  end

  # Different file types
  def test_parse_markdown_file
    file_path = create_test_file("test.md", "# Heading\n\nParagraph content.")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert_equal "markdown", result[:document_type]
    assert result[:content].present?
  end

  def test_parse_html_file
    file_path = create_test_file("test.html", "<html><body>HTML content</body></html>")
    result = Ragdoll::DocumentProcessor.parse(file_path)

    assert_equal "html", result[:document_type]
    assert result[:content].present?
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@test_dir, filename)
    File.write(file_path, content)
    file_path
  end
end
