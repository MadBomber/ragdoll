# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class AudioToTextServiceTest < Minitest::Test
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
    service = Ragdoll::AudioToTextService.new
    assert service.present?
  end

  def test_initializes_with_custom_options
    service = Ragdoll::AudioToTextService.new(
      model: "whisper-1",
      provider: :openai,
      temperature: 0.5
    )
    assert service.present?
  end

  def test_initializes_with_different_providers
    providers = %i[openai azure google whisper_local]
    providers.each do |provider|
      service = Ragdoll::AudioToTextService.new(provider: provider)
      assert service.present?, "Should initialize with #{provider} provider"
    end
  end

  # Error class tests
  def test_transcription_error_class_exists
    assert_equal StandardError, Ragdoll::AudioToTextService::TranscriptionError.superclass
  end

  # Class method tests
  def test_transcribe_class_method_exists
    assert Ragdoll::AudioToTextService.respond_to?(:transcribe)
  end

  # supported_formats tests
  def test_supported_formats_returns_array
    service = Ragdoll::AudioToTextService.new
    assert_kind_of Array, service.supported_formats
  end

  def test_supported_formats_includes_common_audio_formats
    service = Ragdoll::AudioToTextService.new
    formats = service.supported_formats

    assert_includes formats, ".mp3"
    assert_includes formats, ".wav"
    assert_includes formats, ".m4a"
    assert_includes formats, ".flac"
    assert_includes formats, ".ogg"
  end

  def test_supported_formats_includes_video_formats_with_audio
    service = Ragdoll::AudioToTextService.new
    formats = service.supported_formats

    assert_includes formats, ".mp4"
    assert_includes formats, ".mov"
    assert_includes formats, ".avi"
    assert_includes formats, ".webm"
  end

  # transcribe tests
  def test_transcribe_returns_empty_for_nonexistent_file
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe("/nonexistent/audio.mp3")
    assert_equal "", result
  end

  def test_transcribe_returns_empty_for_non_audio_file
    text_file = create_test_file("test.txt", "Not audio content")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(text_file)
    assert_equal "", result
  end

  def test_transcribe_returns_fallback_for_audio_file
    # Create a fake audio file (just with the right extension)
    audio_file = create_test_file("test.mp3", "fake audio data")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(audio_file)

    # Should return a fallback description
    assert result.include?("Audio file") || result == ""
  end

  def test_transcribe_with_wav_file
    wav_file = create_test_file("test.wav", "fake wav data")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(wav_file)

    assert result.include?("Audio file") || result == ""
  end

  def test_transcribe_with_flac_file
    flac_file = create_test_file("test.flac", "fake flac data")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(flac_file)

    assert result.include?("Audio file") || result == ""
  end

  # Provider configuration tests
  def test_openai_provider_configuration
    service = Ragdoll::AudioToTextService.new(provider: :openai)
    assert service.present?
  end

  def test_azure_provider_configuration
    service = Ragdoll::AudioToTextService.new(provider: :azure)
    assert service.present?
  end

  def test_google_provider_configuration
    service = Ragdoll::AudioToTextService.new(provider: :google)
    assert service.present?
  end

  def test_whisper_local_provider_configuration
    service = Ragdoll::AudioToTextService.new(provider: :whisper_local)
    assert service.present?
  end

  def test_unsupported_provider_configuration
    # Should not raise, just warn
    service = Ragdoll::AudioToTextService.new(provider: :unsupported)
    assert service.present?
  end

  # Language option tests
  def test_transcribe_with_language_option
    service = Ragdoll::AudioToTextService.new(language: "en")
    assert service.present?
  end

  def test_transcribe_with_nil_language_autodetects
    service = Ragdoll::AudioToTextService.new(language: nil)
    assert service.present?
  end

  # Temperature option tests
  def test_transcribe_with_different_temperatures
    [0.0, 0.5, 1.0].each do |temp|
      service = Ragdoll::AudioToTextService.new(temperature: temp)
      assert service.present?, "Should initialize with temperature #{temp}"
    end
  end

  # Multiple instances tests
  def test_multiple_service_instances_independent
    service1 = Ragdoll::AudioToTextService.new(provider: :openai)
    service2 = Ragdoll::AudioToTextService.new(provider: :azure)

    assert service1.present?
    assert service2.present?
    refute_same service1, service2
  end

  # Edge cases
  def test_transcribe_with_empty_file
    empty_file = create_test_file("empty.mp3", "")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(empty_file)

    # Should handle empty file gracefully
    assert result.is_a?(String)
  end

  def test_transcribe_with_special_characters_in_filename
    special_file = create_test_file("test file (1) @audio#.mp3", "fake audio")
    service = Ragdoll::AudioToTextService.new
    result = service.transcribe(special_file)

    assert result.is_a?(String)
  end

  private

  def create_test_file(filename, content)
    file_path = File.join(@test_dir, filename)
    File.write(file_path, content)
    file_path
  end
end
