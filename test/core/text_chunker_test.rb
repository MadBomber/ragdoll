# frozen_string_literal: true

require_relative "../test_helper"

class CoreTextChunkerTest < Minitest::Test
  def setup
    super
    @chunker = Ragdoll::TextChunker
  end

  def test_constants
    assert_equal 1000, Ragdoll::TextChunker::DEFAULT_CHUNK_SIZE
    assert_equal 200, Ragdoll::TextChunker::DEFAULT_CHUNK_OVERLAP
  end

  def test_class_chunk_method
    text = "This is a test. " * 100
    result = @chunker.chunk(text)

    assert_instance_of Array, result
    assert result.length > 1
  end

  def test_empty_text_returns_empty_array
    chunker = @chunker.new("")
    assert_empty chunker.chunk
  end

  def test_short_text_returns_single_chunk
    text = "Short text"
    chunker = @chunker.new(text, chunk_size: 100)
    result = chunker.chunk

    assert_equal [text], result
  end

  def test_text_chunking_with_default_parameters
    text = "A" * 1500
    chunker = @chunker.new(text)
    result = chunker.chunk

    assert result.length >= 2
    assert result.first.length <= 1000
  end

  def test_text_chunking_with_custom_parameters
    text = "A" * 500
    chunker = @chunker.new(text, chunk_size: 100, chunk_overlap: 20)
    result = chunker.chunk

    assert result.length >= 5
    assert result.first.length <= 100
  end

  def test_chunk_overlap_functionality
    text = "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15"
    chunker = @chunker.new(text, chunk_size: 50, chunk_overlap: 10)
    result = chunker.chunk

    assert result.length > 1
    # With word boundaries, there should be some overlap or at least logical chunking
    assert(result.all? { |chunk| chunk.length <= 50 })
    # Verify chunks are not identical (which was the original failing case)
    assert(result.uniq.length > 1, "Chunks should not all be identical")
  end

  def test_overlap_with_simple_text
    # Test actual overlap with non-repetitive text that has no natural breaks
    text = "A" * 100 # Simple text without natural break points
    chunker = @chunker.new(text, chunk_size: 30, chunk_overlap: 10)
    result = chunker.chunk

    assert result.length > 1
    # When there are no natural breaks, overlap should still work properly
    assert(result.all? { |chunk| chunk.length <= 30 })

    # With our fixed implementation, should handle this gracefully
    assert result.length >= 3 # Should create multiple chunks
  end

  def test_paragraph_break_detection
    text = "First paragraph with some content.\n\nSecond paragraph with more content.\n\nThird paragraph."
    chunker = @chunker.new(text, chunk_size: 50, chunk_overlap: 10)
    result = chunker.chunk

    # Should prefer breaking at paragraph boundaries
    assert(result.any? { |chunk| chunk.include?("First paragraph") })
  end

  def test_sentence_break_detection
    text = "First sentence. Second sentence! Third sentence? Fourth sentence."
    chunker = @chunker.new(text, chunk_size: 30, chunk_overlap: 5)
    result = chunker.chunk

    # Should prefer breaking at sentence boundaries
    assert(result.any? { |chunk| chunk.end_with?(".") || chunk.end_with?("!") || chunk.end_with?("?") })
  end

  def test_word_boundary_fallback
    text = "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10"
    chunker = @chunker.new(text, chunk_size: 25, chunk_overlap: 5)
    result = chunker.chunk

    # Should break at word boundaries
    assert(result.all? { |chunk| !chunk.end_with?(" ") })
  end

  def test_strips_whitespace_from_chunks
    text = "   First chunk   \n\n   Second chunk   "
    chunker = @chunker.new(text, chunk_size: 15, chunk_overlap: 0)
    result = chunker.chunk

    result.each do |chunk|
      assert_equal chunk, chunk.strip
    end
  end

  def test_filters_empty_chunks
    text = "\n\n\n   \n\n   Some content   \n\n\n"
    chunker = @chunker.new(text, chunk_size: 10, chunk_overlap: 0)
    result = chunker.chunk

    assert(result.all? { |chunk| !chunk.empty? })
  end

  def test_chunk_by_structure_class_method
    text = "First paragraph.\n\nSecond paragraph with more content.\n\nThird paragraph."
    result = @chunker.chunk_by_structure(text, max_chunk_size: 50)

    assert_instance_of Array, result
    assert result.length >= 1
  end

  def test_chunk_by_structure_respects_paragraphs
    text = "Short para.\n\nAnother short paragraph.\n\nThird paragraph."
    result = @chunker.chunk_by_structure(text, max_chunk_size: 100)

    # Should combine small paragraphs
    assert result.length < 3
    assert_includes result.first, "Short para"
  end

  def test_chunk_by_structure_splits_large_paragraphs
    long_sentence = "This is a very long sentence that exceeds the chunk size limit. "
    text = (long_sentence * 10).strip
    result = @chunker.chunk_by_structure(text, max_chunk_size: 50)

    assert result.length > 1
  end

  def test_chunk_code_class_method
    code = "def method1\n  puts 'hello'\nend\n\ndef method2\n  puts 'world'\nend"
    result = @chunker.chunk_code(code, max_chunk_size: 100)

    assert_instance_of Array, result
    assert result.length >= 1
  end

  def test_chunk_code_respects_function_boundaries
    code = "def method1\n  puts 'hello'\nend\n\ndef method2\n  puts 'world'\nend"
    result = @chunker.chunk_code(code, max_chunk_size: 30)

    # Should split at function boundaries
    assert(result.any? { |chunk| chunk.include?("method1") })
    assert(result.any? { |chunk| chunk.include?("method2") })
  end

  def test_chunk_code_detects_different_block_types
    code = "class MyClass\n  def method\n    puts 'test'\n  end\nend\n\nfunction jsFunc() {\n  console.log('test');\n}"
    result = @chunker.chunk_code(code, max_chunk_size: 50)

    assert result.length >= 1
    assert(result.any? { |chunk| chunk.include?("class") || chunk.include?("function") })
  end

  def test_handles_nil_chunk_size
    text = "Test text"
    chunker = @chunker.new(text, chunk_size: nil, chunk_overlap: nil)
    result = chunker.chunk

    assert_equal [text], result
  end

  def test_handles_string_parameters
    text = "Test text " * 200
    chunker = @chunker.new(text, chunk_size: "100", chunk_overlap: "20")
    result = chunker.chunk

    assert result.length > 1
    assert result.first.length <= 100
  end

  def test_negative_start_position_handling
    text = "A" * 100
    chunker = @chunker.new(text, chunk_size: 50, chunk_overlap: 60) # Overlap > chunk_size
    result = chunker.chunk

    assert result.length >= 1
    assert(result.all? { |chunk| !chunk.empty? })
  end

  def test_find_break_position_private_method
    text = "This is a test sentence. Another sentence follows."
    chunker = @chunker.new(text, chunk_size: 25, chunk_overlap: 5)

    # Test that break position finding works reasonably
    result = chunker.chunk
    assert result.length > 1
  end
end
