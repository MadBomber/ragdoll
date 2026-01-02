# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class ImageDescriptionServiceTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Initialization tests
  def test_initializes_without_arguments
    service = Ragdoll::ImageDescriptionService.new
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_custom_primary_options
    primary = { model: "gemma3", provider: :ollama, temperature: 0.5, prompt: "Describe this." }
    service = Ragdoll::ImageDescriptionService.new(primary: primary)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_custom_fallback_options
    fallback = { model: "smollm2", provider: :ollama, temperature: 0.6 }
    service = Ragdoll::ImageDescriptionService.new(fallback: fallback)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_both_primary_and_fallback
    primary = { model: "gemma3", provider: :ollama, temperature: 0.4 }
    fallback = { model: "smollm2", provider: :ollama, temperature: 0.6 }
    service = Ragdoll::ImageDescriptionService.new(primary: primary, fallback: fallback)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Error class tests
  def test_description_error_class_exists
    assert_equal StandardError, Ragdoll::ImageDescriptionService::DescriptionError.superclass
  end

  # Constants tests
  def test_default_options_constant_exists
    assert Ragdoll::ImageDescriptionService::DEFAULT_OPTIONS.is_a?(Hash)
  end

  def test_default_options_includes_model
    options = Ragdoll::ImageDescriptionService::DEFAULT_OPTIONS
    assert options.key?(:model)
  end

  def test_default_options_includes_provider
    options = Ragdoll::ImageDescriptionService::DEFAULT_OPTIONS
    assert options.key?(:provider)
  end

  def test_default_options_includes_temperature
    options = Ragdoll::ImageDescriptionService::DEFAULT_OPTIONS
    assert options.key?(:temperature)
  end

  def test_default_options_includes_prompt
    options = Ragdoll::ImageDescriptionService::DEFAULT_OPTIONS
    assert options.key?(:prompt)
  end

  def test_default_fallback_options_constant_exists
    assert Ragdoll::ImageDescriptionService::DEFAULT_FALLBACK_OPTIONS.is_a?(Hash)
  end

  # generate_description tests
  def test_generate_description_returns_empty_for_nonexistent_file
    service = Ragdoll::ImageDescriptionService.new
    result = service.generate_description("/nonexistent/image.png")
    assert_equal "", result
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_generate_description_returns_empty_for_nil_path
    service = Ragdoll::ImageDescriptionService.new
    result = service.generate_description(nil)
    assert_equal "", result
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_generate_description_returns_empty_for_non_image_file
    text_file = create_test_file("test.txt", "Not image content")
    service = Ragdoll::ImageDescriptionService.new
    result = service.generate_description(text_file)
    assert_equal "", result
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Multiple instances tests
  def test_multiple_service_instances_independent
    service1 = Ragdoll::ImageDescriptionService.new
    service2 = Ragdoll::ImageDescriptionService.new

    assert service1.present?
    assert service2.present?
    refute_same service1, service2
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Edge cases
  def test_generate_description_with_special_characters_in_path
    special_file = create_test_file("test image (1) @special#.txt", "content")
    service = Ragdoll::ImageDescriptionService.new
    result = service.generate_description(special_file)
    # Should not crash, may return empty for non-image
    assert result.is_a?(String)
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@test_dir, filename)
    File.write(file_path, content)
    file_path
  end
end
