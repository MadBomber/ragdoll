# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

class AudioContentTest < Minitest::Test
  def setup
    super
    @test_dir = File.join(File.dirname(__FILE__), "..", "..", "tmp")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    Ragdoll::AudioContent.delete_all rescue nil
    Ragdoll::Document.delete_all rescue nil
    FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
    super
  end

  # Inheritance tests
  def test_audio_content_inherits_from_content
    assert Ragdoll::AudioContent < Ragdoll::Content
  end

  # Initialization tests
  def test_audio_content_can_be_created_with_transcript
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "whisper-large",
      content: "This is the transcript of the audio."
    )
    assert content.persisted?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Validation tests
  def test_audio_content_requires_audio_or_transcript
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model"
    )
    refute content.valid?
    assert content.errors[:base].any?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_content_duration_must_be_positive
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript",
      duration: -1
    )
    refute content.valid?
    assert content.errors[:duration].any?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_content_sample_rate_must_be_positive
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript",
      sample_rate: 0
    )
    refute content.valid?
    assert content.errors[:sample_rate].any?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # transcript accessor tests
  def test_transcript_returns_content
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Hello world"
    )
    assert_equal "Hello world", content.transcript
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_transcript_setter_sets_content
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model"
    )
    content.transcript = "New transcript"
    assert_equal "New transcript", content.content
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # audio_data accessor tests
  def test_audio_data_returns_data
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      data: "/path/to/audio.mp3",
      content: "Transcript"
    )
    assert_equal "/path/to/audio.mp3", content.audio_data
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_data_setter_sets_data
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model"
    )
    content.audio_data = "/path/to/podcast.wav"
    assert_equal "/path/to/podcast.wav", content.data
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # audio_attached? tests
  def test_audio_attached_returns_false_when_no_data
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    refute content.audio_attached?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_attached_returns_true_when_data_present
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      data: "/path/to/audio.mp3"
    )
    assert content.audio_attached?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # audio_size metadata accessor tests
  def test_audio_size_returns_zero_by_default
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    assert_equal 0, content.audio_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_audio_size_can_be_set
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    content.audio_size = 5242880
    content.save!
    content.reload
    assert_equal 5242880, content.audio_size
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # codec metadata accessor tests
  def test_codec_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    content.codec = "aac"
    content.save!
    content.reload
    assert_equal "aac", content.codec
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # bitrate metadata accessor tests
  def test_bitrate_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    content.bitrate = 320000
    content.save!
    content.reload
    assert_equal 320000, content.bitrate
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # channels metadata accessor tests
  def test_channels_can_be_set_and_retrieved
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    content.channels = 2
    content.save!
    content.reload
    assert_equal 2, content.channels
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # duration_formatted tests
  def test_duration_formatted_returns_unknown_for_nil_duration
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    assert_equal "Unknown", content.duration_formatted
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_duration_formatted_formats_correctly
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript",
      duration: 185
    )
    assert_equal "3:05", content.duration_formatted
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_duration_formatted_handles_single_digit_seconds
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "Transcript",
      duration: 65
    )
    assert_equal "1:05", content.duration_formatted
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # content_for_embedding tests
  def test_content_for_embedding_returns_transcript
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      content: "This is the transcript"
    )
    assert_equal "This is the transcript", content.content_for_embedding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_content_for_embedding_returns_fallback_when_no_transcript
    document = create_test_document
    content = Ragdoll::AudioContent.new(
      document: document,
      embedding_model: "test-model",
      data: "/path/to/audio.mp3"
    )
    assert_equal "Audio content without transcript", content.content_for_embedding
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # should_generate_embeddings? tests
  def test_should_generate_embeddings_returns_true_when_transcript_present
    document = create_test_document
    content = Ragdoll::AudioContent.create!(
      document: document,
      embedding_model: "test-model",
      content: "Transcript"
    )
    assert content.should_generate_embeddings?
  rescue ActiveRecord::StatementInvalid => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  # Scope tests
  def test_recent_scope_exists
    assert Ragdoll::AudioContent.respond_to?(:recent)
  end

  def test_with_audio_scope_exists
    assert Ragdoll::AudioContent.respond_to?(:with_audio)
  end

  def test_with_transcripts_scope_exists
    assert Ragdoll::AudioContent.respond_to?(:with_transcripts)
  end

  def test_by_duration_scope_exists
    assert Ragdoll::AudioContent.respond_to?(:by_duration)
  end

  # stats class method tests
  def test_stats_returns_hash
    result = Ragdoll::AudioContent.stats
    assert_kind_of Hash, result
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConfigurationError, PG::UndefinedTable => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  def test_stats_includes_total_audio_contents
    result = Ragdoll::AudioContent.stats
    assert result.key?(:total_audio_contents)
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConfigurationError, PG::UndefinedTable => e
    skip "Content table not configured: #{e.message.split("\n").first}"
  end

  private

  def create_test_document(filename = "test_audio.mp3")
    file_path = File.join(@test_dir, filename)
    File.write(file_path, "fake audio data")
    Ragdoll::Document.create!(
      location: file_path,
      title: filename,
      document_type: "audio",
      status: "processed"
    )
  end
end
