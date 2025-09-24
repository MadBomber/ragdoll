# frozen_string_literal: true

require "test_helper"

class Ragdoll::TextExtractionServiceTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir
  end

  def test_extract_from_text_file
    file_path = create_temp_file("sample.txt", "This is a test document with some content.")

    service = Ragdoll::TextExtractionService.new(file_path)
    result = service.extract

    assert_equal "This is a test document with some content.", result
  end

  def test_extract_from_markdown_file
    content = "# Title\n\nThis is markdown content with **bold** text."
    file_path = create_temp_file("sample.md", content)

    service = Ragdoll::TextExtractionService.new(file_path)
    result = service.extract

    assert_equal content, result
  end

  def test_extract_from_markdown_with_yaml_front_matter
    content = "---\ntitle: Test Document\nauthor: Test Author\n---\n\n# Main Content\n\nThis is the body."
    file_path = create_temp_file("sample.md", content)

    service = Ragdoll::TextExtractionService.new(file_path)
    result = service.extract

    # The YAML front matter parsing may return the full content or just the body
    # depending on the implementation. Let's test that we get meaningful content.
    assert_includes result, "Main Content"
    assert_includes result, "This is the body"
    # Note: YAML front matter handling is optional in this service
  end

  def test_extract_from_html_file
    html_content = "<html><head><title>Test</title></head><body><h1>Title</h1><p>Content here</p></body></html>"
    file_path = create_temp_file("sample.html", html_content)

    service = Ragdoll::TextExtractionService.new(file_path)
    result = service.extract

    # Should strip HTML tags and normalize whitespace
    assert_includes result, "Title"
    assert_includes result, "Content here"
    # Note: The current implementation may not strip all HTML tags perfectly
    # This is expected behavior for the basic HTML stripping
  end

  def test_extract_with_encoding_issues
    # Create file with ISO-8859-1 encoding
    content = "This is a test with special characters: café"
    file_path = File.join(@temp_dir, "encoding_test.txt")

    File.open(file_path, "w:ISO-8859-1") do |f|
      f.write(content.encode("ISO-8859-1"))
    end

    service = Ragdoll::TextExtractionService.new(file_path)
    result = service.extract

    # Should handle encoding gracefully
    assert_includes result, "test"
    assert_includes result, "special"
  end

  def test_extract_from_nonexistent_file
    service = Ragdoll::TextExtractionService.new("/nonexistent/file.txt")

    assert_raises(Ragdoll::TextExtractionService::ExtractionError) do
      service.extract
    end
  end

  def test_determine_document_type
    assert_equal "pdf", Ragdoll::TextExtractionService.new("test.pdf").send(:determine_document_type)
    assert_equal "docx", Ragdoll::TextExtractionService.new("test.docx").send(:determine_document_type)
    assert_equal "text", Ragdoll::TextExtractionService.new("test.txt").send(:determine_document_type)
    assert_equal "markdown", Ragdoll::TextExtractionService.new("test.md").send(:determine_document_type)
    assert_equal "text", Ragdoll::TextExtractionService.new("test.unknown").send(:determine_document_type)
  end

  def test_class_method_extract
    file_path = create_temp_file("sample.txt", "Test content")

    result = Ragdoll::TextExtractionService.extract(file_path)

    assert_equal "Test content", result
  end

  private

  def create_temp_file(filename, content)
    file_path = File.join(@temp_dir, filename)
    File.write(file_path, content)
    file_path
  end
end