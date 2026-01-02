# frozen_string_literal: true

require "test_helper"

class DocumentConverterTest < Minitest::Test
  def setup
    super
    @converter = Ragdoll::DocumentConverter.new
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
    super
  end

  # Class method tests
  def test_class_method_convert_to_text
    file_path = create_text_file("Hello World")
    result = Ragdoll::DocumentConverter.convert_to_text(file_path)
    assert_equal "Hello World", result.strip
  end

  def test_class_method_with_document_type_override
    file_path = create_text_file("Hello World")
    result = Ragdoll::DocumentConverter.convert_to_text(file_path, "text")
    assert_equal "Hello World", result.strip
  end

  # Document type detection tests
  def test_determine_document_type_for_pdf
    assert_equal "pdf", @converter.determine_document_type("file.pdf")
    assert_equal "pdf", @converter.determine_document_type("file.PDF")
  end

  def test_determine_document_type_for_docx
    assert_equal "docx", @converter.determine_document_type("file.docx")
  end

  def test_determine_document_type_for_text
    assert_equal "text", @converter.determine_document_type("file.txt")
  end

  def test_determine_document_type_for_markdown
    assert_equal "markdown", @converter.determine_document_type("file.md")
    assert_equal "markdown", @converter.determine_document_type("file.markdown")
  end

  def test_determine_document_type_for_html
    assert_equal "html", @converter.determine_document_type("file.html")
    assert_equal "html", @converter.determine_document_type("file.htm")
  end

  def test_determine_document_type_for_images
    %w[jpg jpeg png gif bmp webp svg ico tiff tif].each do |ext|
      assert_equal "image", @converter.determine_document_type("file.#{ext}"),
                   "Expected 'image' for .#{ext} extension"
    end
  end

  def test_determine_document_type_for_audio
    %w[mp3 wav m4a flac ogg aac wma].each do |ext|
      assert_equal "audio", @converter.determine_document_type("file.#{ext}"),
                   "Expected 'audio' for .#{ext} extension"
    end
  end

  def test_determine_document_type_for_video
    %w[mp4 mov avi webm mkv].each do |ext|
      assert_equal "video", @converter.determine_document_type("file.#{ext}"),
                   "Expected 'video' for .#{ext} extension"
    end
  end

  def test_determine_document_type_for_csv
    assert_equal "csv", @converter.determine_document_type("file.csv")
  end

  def test_determine_document_type_for_json
    assert_equal "json", @converter.determine_document_type("file.json")
  end

  def test_determine_document_type_for_xml
    assert_equal "xml", @converter.determine_document_type("file.xml")
  end

  def test_determine_document_type_for_yaml
    assert_equal "yaml", @converter.determine_document_type("file.yml")
    assert_equal "yaml", @converter.determine_document_type("file.yaml")
  end

  def test_determine_document_type_defaults_to_text
    assert_equal "text", @converter.determine_document_type("file.unknown")
    assert_equal "text", @converter.determine_document_type("file")
  end

  # Supported formats test
  def test_supported_formats_returns_all_categories
    formats = @converter.supported_formats

    assert_includes formats.keys, :text
    assert_includes formats.keys, :documents
    assert_includes formats.keys, :images
    assert_includes formats.keys, :audio
    assert_includes formats.keys, :video
  end

  def test_supported_formats_text_includes_common_extensions
    formats = @converter.supported_formats[:text]

    assert_includes formats, ".txt"
    assert_includes formats, ".md"
    assert_includes formats, ".html"
    assert_includes formats, ".csv"
    assert_includes formats, ".json"
  end

  # Conversion tests
  def test_convert_to_text_returns_empty_for_nonexistent_file
    result = @converter.convert_to_text("/nonexistent/file.txt")
    assert_equal "", result
  end

  def test_convert_to_text_handles_text_files
    file_path = create_text_file("Sample text content")
    result = @converter.convert_to_text(file_path)
    assert_equal "Sample text content", result.strip
  end

  def test_convert_to_text_handles_markdown_files
    content = "# Header\n\nParagraph text"
    file_path = create_file("test.md", content)
    result = @converter.convert_to_text(file_path)
    assert_includes result, "Header"
    assert_includes result, "Paragraph text"
  end

  def test_convert_to_text_handles_csv_files
    content = "name,age\nJohn,30\nJane,25"
    file_path = create_file("test.csv", content)
    result = @converter.convert_to_text(file_path, "csv")
    assert_includes result.downcase, "john"
  end

  def test_convert_to_text_handles_json_files
    content = '{"name": "John", "age": 30}'
    file_path = create_file("test.json", content)
    result = @converter.convert_to_text(file_path, "json")
    assert_includes result, "John"
  end

  def test_convert_to_text_generates_fallback_for_images
    # Create a dummy image file (just metadata content)
    file_path = create_file("test.png", "dummy content")
    result = @converter.convert_to_text(file_path, "image")
    # Should contain file info
    assert_includes result.downcase, "image"
  end

  def test_convert_to_text_generates_fallback_for_audio
    file_path = create_file("test.mp3", "dummy content")
    result = @converter.convert_to_text(file_path, "audio")
    assert_includes result.downcase, "audio"
  end

  def test_convert_to_text_generates_fallback_for_video
    file_path = create_file("test.mp4", "dummy content")
    result = @converter.convert_to_text(file_path, "video")
    assert_includes result.downcase, "video"
  end

  def test_convert_to_text_with_explicit_type_override
    content = "Plain text content"
    file_path = create_file("test.unknown", content)
    result = @converter.convert_to_text(file_path, "text")
    assert_equal content, result.strip
  end

  # Edge case tests
  def test_convert_to_text_handles_empty_file
    file_path = create_text_file("")
    result = @converter.convert_to_text(file_path)
    assert_equal "", result.strip
  end

  def test_convert_to_text_handles_unicode_content
    content = "Hello 世界! 🌍"
    file_path = create_text_file(content)
    result = @converter.convert_to_text(file_path)
    assert_equal content, result.strip
  end

  def test_convert_to_text_handles_large_content
    content = "x" * 10_000
    file_path = create_text_file(content)
    result = @converter.convert_to_text(file_path)
    assert_equal 10_000, result.strip.length
  end

  private

  def create_text_file(content)
    create_file("test.txt", content)
  end

  def create_file(name, content)
    path = File.join(@test_dir, name)
    File.write(path, content)
    path
  end
end
