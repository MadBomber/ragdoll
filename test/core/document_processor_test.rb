# frozen_string_literal: true

require_relative "../test_helper"
require "tempfile"

class CoreDocumentProcessorTest < Minitest::Test
  def setup
    super
    @processor = Ragdoll::DocumentProcessor
  end

  def test_class_parse_method
    with_temp_text_file("Hello world") do |file_path|
      result = @processor.parse(file_path)
      assert_equal "Hello world", result[:content]
      assert_equal "text", result[:document_type]
    end
  end

  def test_parse_text_file
    with_temp_text_file("Sample text content") do |file_path|
      processor = @processor.new(file_path)
      result = processor.parse

      assert_equal "Sample text content", result[:content]
      assert_equal "text", result[:document_type]
      assert result[:metadata][:file_size].positive?
      assert_equal "UTF-8", result[:metadata][:encoding]
    end
  end

  def test_parse_markdown_file
    content = "# Heading\n\nParagraph text"
    with_temp_file(content, ".md") do |file_path|
      processor = @processor.new(file_path)
      result = processor.parse

      assert_equal content, result[:content]
      assert_equal "markdown", result[:document_type]
    end
  end

  def test_parse_html_file
    html_content = "<html><head><title>Test</title></head><body><h1>Hello</h1><p>World</p></body></html>"
    with_temp_file(html_content, ".html") do |file_path|
      processor = @processor.new(file_path)
      result = processor.parse

      assert_includes result[:content], "Hello"
      assert_includes result[:content], "World"
      refute_includes result[:content], "<html>"
      refute_includes result[:content], "<h1>"
      assert_equal "html", result[:document_type]
    end
  end

  def test_parse_html_removes_script_and_style_tags
    html_content = '<html><head><style>body{color:red;}</style></head><body><script>alert("test");</script><p>Content</p></body></html>'
    with_temp_file(html_content, ".html") do |file_path|
      processor = @processor.new(file_path)
      result = processor.parse

      assert_includes result[:content], "Content"
      refute_includes result[:content], "alert"
      refute_includes result[:content], "color:red"
    end
  end

  def test_parse_unknown_extension_defaults_to_text
    with_temp_file("Unknown format content", ".xyz") do |file_path|
      processor = @processor.new(file_path)
      result = processor.parse

      assert_equal "Unknown format content", result[:content]
      assert_equal "text", result[:document_type]
    end
  end

  def test_parse_error_on_invalid_file
    processor = @processor.new("/nonexistent/file.txt")

    assert_raises(Ragdoll::DocumentProcessor::ParseError) do
      processor.parse
    end
  end

  def test_parse_encoding_fallback
    # Create file with non-UTF-8 content
    Tempfile.create(["test", ".txt"]) do |file|
      # Write content with ISO-8859-1 encoding
      content = "caf\xe9".dup.force_encoding("ISO-8859-1")
      file.write(content)
      file.close

      processor = @processor.new(file.path)
      result = processor.parse

      assert_includes result[:content], "caf"
      assert result[:metadata][:encoding]
    end
  end

  def test_initialize_sets_file_path_and_extension
    processor = @processor.new("/path/to/file.PDF")

    assert_equal "/path/to/file.PDF", processor.instance_variable_get(:@file_path)
    assert_equal ".pdf", processor.instance_variable_get(:@file_extension)
  end

  def test_error_classes_inheritance
    assert Ragdoll::DocumentProcessor::ParseError < Ragdoll::Core::DocumentError
    assert Ragdoll::DocumentProcessor::UnsupportedFormatError < Ragdoll::DocumentProcessor::ParseError
  end

  private

  def with_temp_text_file(content, &block)
    with_temp_file(content, ".txt", &block)
  end

  def with_temp_file(content, extension = ".txt")
    Tempfile.create(["test", extension]) do |file|
      file.write(content)
      file.close
      yield file.path
    end
  end
end
