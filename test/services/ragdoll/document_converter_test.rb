# frozen_string_literal: true

require_relative "../../test_helper"

class Ragdoll::DocumentConverterTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @converter = Ragdoll::DocumentConverter.new
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir
  end

  def test_convert_text_file_to_text
    file_path = create_temp_file("sample.txt", "This is test content.")

    result = @converter.convert_to_text(file_path)

    assert_equal "This is test content.", result
  end

  def test_convert_markdown_file_to_text
    content = "# Title\n\nThis is markdown content."
    file_path = create_temp_file("sample.md", content)

    result = @converter.convert_to_text(file_path)

    assert_equal content, result
  end

  def test_convert_image_file_to_text
    # Create a dummy image file (we'll mock the conversion)
    file_path = create_temp_file("sample.jpg", "dummy image data")

    # Mock the ImageToTextService
    mock_service = Minitest::Mock.new
    mock_service.expect(:convert, "Image description: A test image", [file_path])

    Ragdoll::ImageToTextService.stub(:new, mock_service) do
      result = @converter.convert_to_text(file_path, "image")
      assert_equal "Image description: A test image", result
    end

    mock_service.verify
  end

  def test_convert_audio_file_to_text
    file_path = create_temp_file("sample.mp3", "dummy audio data")

    # Mock the AudioToTextService
    mock_service = Minitest::Mock.new
    mock_service.expect(:transcribe, "Audio transcript: Hello world", [file_path])

    Ragdoll::AudioToTextService.stub(:new, mock_service) do
      result = @converter.convert_to_text(file_path, "audio")
      assert_equal "Audio transcript: Hello world", result
    end

    mock_service.verify
  end

  def test_convert_unknown_file_to_text
    file_path = create_temp_file("sample.xyz", "Some unknown content")

    result = @converter.convert_to_text(file_path, "unknown")

    # Should attempt to read as text first, fallback to filename if binary
    assert_equal "Some unknown content", result
  end

  def test_determine_document_type
    test_cases = {
      "document.pdf" => "pdf",
      "document.docx" => "docx",
      "document.txt" => "text",
      "document.md" => "markdown",
      "document.html" => "html",
      "image.jpg" => "image",
      "image.png" => "image",
      "audio.mp3" => "audio",
      "video.mp4" => "video",
      "data.csv" => "csv",
      "config.json" => "json",
      "unknown.xyz" => "text"
    }

    test_cases.each do |filename, expected_type|
      actual_type = @converter.determine_document_type(filename)
      assert_equal expected_type, actual_type, "Expected #{filename} to be #{expected_type}, got #{actual_type}"
    end
  end

  def test_supported_formats
    formats = @converter.supported_formats

    assert formats.key?(:text)
    assert formats.key?(:documents)
    assert formats.key?(:images)
    assert formats.key?(:audio)
    assert formats.key?(:video)

    assert_includes formats[:text], ".txt"
    assert_includes formats[:documents], ".pdf"
    assert_includes formats[:images], ".jpg"
    assert_includes formats[:audio], ".mp3"
    assert_includes formats[:video], ".mp4"
  end

  def test_convert_nonexistent_file
    result = @converter.convert_to_text("/nonexistent/file.txt")

    assert_equal "", result
  end

  def test_convert_with_error_handling
    file_path = create_temp_file("sample.txt", "Test content")

    # Mock an error in text extraction
    Ragdoll::TextExtractionService.stub(:new, proc { raise StandardError, "Extraction failed" }) do
      result = @converter.convert_to_text(file_path, "text")

      # Should return fallback text on error
      assert_includes result.downcase, "sample.txt"
    end
  end

  def test_class_method_convert_to_text
    file_path = create_temp_file("sample.txt", "Test content")

    result = Ragdoll::DocumentConverter.convert_to_text(file_path)

    assert_equal "Test content", result
  end

  private

  def create_temp_file(filename, content)
    file_path = File.join(@temp_dir, filename)
    File.write(file_path, content)
    file_path
  end
end