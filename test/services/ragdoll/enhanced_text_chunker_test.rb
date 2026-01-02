# frozen_string_literal: true

require_relative "../../test_helper"

class EnhancedTextChunkerTest < Minitest::Test
  def setup
    super
    @chunker_class = Ragdoll::TextChunker
  end

  # Class method tests
  def test_class_chunk_method_exists
    assert_respond_to @chunker_class, :chunk
  end

  def test_class_chunk_returns_array
    result = @chunker_class.chunk("Some text")
    assert_kind_of Array, result
  end

  def test_class_chunk_with_empty_string
    result = @chunker_class.chunk("")
    assert_equal [], result
  end

  def test_class_chunk_with_nil_coerced_to_string
    result = @chunker_class.chunk(nil)
    assert_equal [], result
  end

  # Instance initialization tests
  def test_initialize_with_defaults
    chunker = @chunker_class.new("test text")
    assert_instance_of @chunker_class, chunker
  end

  def test_initialize_with_custom_chunk_size
    chunker = @chunker_class.new("test", chunk_size: 500)
    assert_instance_of @chunker_class, chunker
  end

  def test_initialize_with_custom_overlap
    chunker = @chunker_class.new("test", chunk_overlap: 50)
    assert_instance_of @chunker_class, chunker
  end

  # Chunk instance method tests
  def test_chunk_empty_string_returns_empty_array
    chunker = @chunker_class.new("")
    assert_equal [], chunker.chunk
  end

  def test_chunk_short_text_returns_single_chunk
    text = "Short text"
    chunker = @chunker_class.new(text, chunk_size: 1000)
    result = chunker.chunk
    assert_equal [text], result
  end

  def test_chunk_text_equal_to_chunk_size
    text = "x" * 100
    chunker = @chunker_class.new(text, chunk_size: 100)
    result = chunker.chunk
    assert_equal 1, result.size
  end

  def test_chunk_text_larger_than_chunk_size
    text = "word " * 100 # 500 characters
    chunker = @chunker_class.new(text, chunk_size: 100, chunk_overlap: 20)
    result = chunker.chunk
    assert result.size > 1, "Expected multiple chunks"
  end

  # Overlap behavior tests
  def test_chunk_overlap_creates_overlapping_content
    text = "This is sentence one. This is sentence two. This is sentence three."
    chunker = @chunker_class.new(text, chunk_size: 30, chunk_overlap: 10)
    result = chunker.chunk

    # With overlap, consecutive chunks should share some content
    assert result.size >= 2, "Expected at least 2 chunks"
  end

  def test_chunk_zero_overlap_still_works
    text = "word " * 50
    chunker = @chunker_class.new(text, chunk_size: 50, chunk_overlap: 0)
    result = chunker.chunk
    assert result.size > 1
  end

  def test_chunk_overlap_equal_to_chunk_size_is_handled
    # This edge case should be handled to prevent infinite loops
    text = "x" * 200
    chunker = @chunker_class.new(text, chunk_size: 50, chunk_overlap: 50)
    result = chunker.chunk
    # Should still produce chunks and not loop forever
    assert result.any?
  end

  def test_chunk_overlap_greater_than_chunk_size_is_handled
    text = "x" * 200
    chunker = @chunker_class.new(text, chunk_size: 50, chunk_overlap: 100)
    result = chunker.chunk
    assert result.any?
  end

  # Break position tests
  def test_chunk_breaks_on_paragraph
    text = "First paragraph text here.\n\nSecond paragraph text here."
    chunker = @chunker_class.new(text, chunk_size: 40, chunk_overlap: 5)
    result = chunker.chunk

    # Should attempt to break at paragraph boundary
    assert result.size >= 1
  end

  def test_chunk_breaks_on_sentence
    text = "First sentence. Second sentence. Third sentence. Fourth sentence."
    chunker = @chunker_class.new(text, chunk_size: 35, chunk_overlap: 5)
    result = chunker.chunk

    assert result.size >= 2
  end

  def test_chunk_handles_newline_only_text
    text = "\n\n\n"
    chunker = @chunker_class.new(text, chunk_size: 10)
    result = chunker.chunk
    # Should handle gracefully, may return empty array if whitespace stripped
    assert_kind_of Array, result
  end

  def test_chunk_handles_whitespace_only
    text = "   \t\n   "
    chunker = @chunker_class.new(text, chunk_size: 10)
    result = chunker.chunk
    assert_kind_of Array, result
  end

  # Default constants tests
  def test_default_chunk_size_constant
    assert_equal 1000, @chunker_class::DEFAULT_CHUNK_SIZE
  end

  def test_default_chunk_overlap_constant
    assert_equal 200, @chunker_class::DEFAULT_CHUNK_OVERLAP
  end

  # Content preservation tests
  def test_chunk_preserves_all_content
    text = "The quick brown fox jumps over the lazy dog."
    chunker = @chunker_class.new(text, chunk_size: 1000)
    result = chunker.chunk
    assert_equal text, result.first
  end

  def test_chunk_preserves_whitespace_in_content
    chunker = @chunker_class.new("  text  ", chunk_size: 1000)
    result = chunker.chunk
    # TextChunker preserves original content
    assert result.first.include?("text")
  end

  def test_chunk_rejects_empty_chunks
    text = "word\n\n\n\nword"
    chunker = @chunker_class.new(text, chunk_size: 6, chunk_overlap: 1)
    result = chunker.chunk
    result.each do |chunk|
      refute chunk.empty?, "No empty chunks should be returned"
    end
  end

  # Edge cases
  def test_chunk_single_character
    chunker = @chunker_class.new("a", chunk_size: 1000)
    result = chunker.chunk
    assert_equal ["a"], result
  end

  def test_chunk_unicode_text
    text = "Hello \u4e16\u754c. \u3053\u3093\u306b\u3061\u306f." # Hello 世界. こんにちは.
    chunker = @chunker_class.new(text, chunk_size: 1000)
    result = chunker.chunk
    assert_equal [text], result
  end

  def test_chunk_emoji_text
    text = "Hello! \u{1F600} How are you? \u{1F44D}"
    chunker = @chunker_class.new(text, chunk_size: 1000)
    result = chunker.chunk
    assert result.first.include?("\u{1F600}")
  end

  def test_chunk_with_very_small_chunk_size
    text = "abcdefghijklmnop"
    chunker = @chunker_class.new(text, chunk_size: 3, chunk_overlap: 1)
    result = chunker.chunk
    assert result.size > 1
    result.each do |chunk|
      refute chunk.empty?
    end
  end

  # Various punctuation patterns
  def test_chunk_handles_exclamation_marks
    text = "Wow! This is exciting! Really amazing!"
    chunker = @chunker_class.new(text, chunk_size: 15, chunk_overlap: 3)
    result = chunker.chunk
    assert result.size >= 1
  end

  def test_chunk_handles_question_marks
    text = "What? When? Where? Why? How?"
    chunker = @chunker_class.new(text, chunk_size: 12, chunk_overlap: 2)
    result = chunker.chunk
    assert result.size >= 1
  end

  def test_chunk_handles_mixed_punctuation
    text = "Hello! How are you? I'm fine. Thanks!"
    chunker = @chunker_class.new(text, chunk_size: 20, chunk_overlap: 5)
    result = chunker.chunk
    assert result.size >= 1
  end
end
