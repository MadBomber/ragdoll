# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class ImageToTextServiceTest < Minitest::Test
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
    service = Ragdoll::ImageToTextService.new
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_custom_options
    service = Ragdoll::ImageToTextService.new(
      model: "gemma3",
      provider: :ollama,
      temperature: 0.5,
      detail_level: :standard
    )
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_custom_primary_and_fallback
    primary = { model: "gemma3", provider: :ollama, temperature: 0.3 }
    fallback = { model: "smollm2", provider: :ollama, temperature: 0.5 }
    service = Ragdoll::ImageToTextService.new(primary: primary, fallback: fallback)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Error class tests
  def test_description_error_class_exists
    assert_equal StandardError, Ragdoll::ImageToTextService::DescriptionError.superclass
  end

  # Constants tests
  def test_default_options_constant_exists
    assert Ragdoll::ImageToTextService::DEFAULT_OPTIONS.is_a?(Hash)
  end

  def test_default_fallback_options_constant_exists
    assert Ragdoll::ImageToTextService::DEFAULT_FALLBACK_OPTIONS.is_a?(Hash)
  end

  def test_detail_levels_constant_exists
    assert Ragdoll::ImageToTextService::DETAIL_LEVELS.is_a?(Hash)
  end

  def test_detail_levels_includes_expected_keys
    levels = Ragdoll::ImageToTextService::DETAIL_LEVELS
    assert levels.key?(:minimal)
    assert levels.key?(:standard)
    assert levels.key?(:comprehensive)
    assert levels.key?(:analytical)
  end

  # Class method tests
  def test_convert_class_method_exists
    assert Ragdoll::ImageToTextService.respond_to?(:convert)
  end

  # supported_formats tests
  def test_supported_formats_returns_array
    service = Ragdoll::ImageToTextService.new
    assert_kind_of Array, service.supported_formats
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_supported_formats_includes_common_image_formats
    service = Ragdoll::ImageToTextService.new
    formats = service.supported_formats

    assert_includes formats, ".jpg"
    assert_includes formats, ".jpeg"
    assert_includes formats, ".png"
    assert_includes formats, ".gif"
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_supported_formats_includes_other_formats
    service = Ragdoll::ImageToTextService.new
    formats = service.supported_formats

    assert_includes formats, ".webp"
    assert_includes formats, ".svg"
    assert_includes formats, ".bmp"
    assert_includes formats, ".tiff"
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # convert tests
  def test_convert_returns_empty_for_nonexistent_file
    service = Ragdoll::ImageToTextService.new
    result = service.convert("/nonexistent/image.png")
    assert_equal "", result
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_convert_returns_empty_for_non_image_file
    text_file = create_test_file("test.txt", "Not image content")
    service = Ragdoll::ImageToTextService.new
    result = service.convert(text_file)
    assert_equal "", result
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Detail level tests
  def test_initializes_with_minimal_detail_level
    service = Ragdoll::ImageToTextService.new(detail_level: :minimal)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_standard_detail_level
    service = Ragdoll::ImageToTextService.new(detail_level: :standard)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_comprehensive_detail_level
    service = Ragdoll::ImageToTextService.new(detail_level: :comprehensive)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  def test_initializes_with_analytical_detail_level
    service = Ragdoll::ImageToTextService.new(detail_level: :analytical)
    assert service.present?
  rescue LoadError, NameError => e
    skip "RMagick or dependencies not available: #{e.message.split("\n").first}"
  end

  # Multiple instances tests
  def test_multiple_service_instances_independent
    service1 = Ragdoll::ImageToTextService.new(detail_level: :minimal)
    service2 = Ragdoll::ImageToTextService.new(detail_level: :analytical)

    assert service1.present?
    assert service2.present?
    refute_same service1, service2
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
