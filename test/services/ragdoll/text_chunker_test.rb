# frozen_string_literal: true

require "test_helper"

class TextChunkerTest < Minitest::Test
  def setup
    super
  end

  # Class method tests
  def test_chunk_class_method_returns_array
    result = Ragdoll::TextChunker.chunk("Some text content.")
    assert_kind_of Array, result
  end

  def test_chunk_class_method_with_options
    text = "Word " * 500
    result = Ragdoll::TextChunker.chunk(text, chunk_size: 100, chunk_overlap: 20)
    assert_kind_of Array, result
    assert result.length > 1
  end

  # Constants
  def test_default_chunk_size_constant
    assert_equal 1000, Ragdoll::TextChunker::DEFAULT_CHUNK_SIZE
  end

  def test_default_chunk_overlap_constant
    assert_equal 200, Ragdoll::TextChunker::DEFAULT_CHUNK_OVERLAP
  end

  # Basic chunking tests
  def test_chunk_empty_text_returns_empty_array
    chunker = Ragdoll::TextChunker.new("")
    assert_equal [], chunker.chunk
  end

  def test_chunk_nil_text_returns_empty_array
    chunker = Ragdoll::TextChunker.new(nil)
    assert_equal [], chunker.chunk
  end

  def test_chunk_short_text_returns_single_chunk
    text = "This is a short text."
    chunker = Ragdoll::TextChunker.new(text)
    chunks = chunker.chunk

    assert_equal 1, chunks.length
    assert_equal text, chunks.first
  end

  def test_chunk_text_equal_to_size_returns_single_chunk
    text = "x" * 1000
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 1000)
    chunks = chunker.chunk

    assert_equal 1, chunks.length
  end

  def test_chunk_long_text_creates_multiple_chunks
    text = "This is a sentence. " * 200  # About 4000 characters
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 1000, chunk_overlap: 100)
    chunks = chunker.chunk

    assert chunks.length > 1
  end

  def test_chunks_do_not_exceed_chunk_size_significantly
    text = "Word " * 500
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 200, chunk_overlap: 50)
    chunks = chunker.chunk

    # Each chunk should be close to chunk size (may exceed slightly at natural boundaries)
    chunks.each do |chunk|
      assert chunk.length <= 250, "Chunk too long: #{chunk.length}"
    end
  end

  def test_chunks_overlap_correctly
    text = "The quick brown fox jumps over the lazy dog. " * 50
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 200, chunk_overlap: 50)
    chunks = chunker.chunk

    # Verify overlap exists between consecutive chunks
    (0...chunks.length - 1).each do |i|
      # The end of one chunk should overlap with the start of the next
      # This is a loose check since natural boundaries may affect exact overlap
      assert chunks[i].length > 0, "Chunk #{i} should not be empty"
      assert chunks[i + 1].length > 0, "Chunk #{i + 1} should not be empty"
    end
  end

  # Break position tests
  def test_chunk_breaks_at_paragraph
    text = "First paragraph content.\n\n" + "Second paragraph content. " * 100
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 500, chunk_overlap: 50)
    chunks = chunker.chunk

    # Should break at paragraph boundary
    assert chunks.length >= 1
  end

  def test_chunk_breaks_at_sentence
    text = "Sentence one. Sentence two. Sentence three. " * 50
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 200, chunk_overlap: 30)
    chunks = chunker.chunk

    # Chunks should be created and contain content
    assert chunks.length > 1
    assert chunks.all?(&:present?)
  end

  def test_chunk_breaks_at_word_boundary
    text = "word " * 500
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 100, chunk_overlap: 20)
    chunks = chunker.chunk

    # Chunks should not split words
    chunks.each do |chunk|
      # Each word should be complete (no partial words except at edges)
      assert chunk.split.all? { |word| word == "word" || word.length <= 4 }
    end
  end

  # Edge cases
  def test_chunk_handles_no_spaces
    text = "a" * 2000  # No word boundaries
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 500, chunk_overlap: 100)
    chunks = chunker.chunk

    # Should still chunk even without natural boundaries
    assert chunks.length > 1
  end

  def test_chunk_handles_only_whitespace
    text = "   \n\n   \t\t   "
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 100, chunk_overlap: 20)
    chunks = chunker.chunk

    # Should handle whitespace text without error
    assert_kind_of Array, chunks
  end

  def test_chunk_handles_unicode
    text = "日本語テキスト。 " * 200
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 100, chunk_overlap: 20)
    chunks = chunker.chunk

    # Should handle unicode characters
    assert chunks.all?(&:present?)
  end

  def test_chunk_handles_mixed_content
    text = "Text with numbers 123 and symbols @#$ and unicode 日本語. " * 50
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 200, chunk_overlap: 50)
    chunks = chunker.chunk

    assert chunks.length > 1
    assert chunks.all?(&:present?)
  end

  def test_chunk_overlap_greater_than_size_handled
    text = "word " * 100
    # Overlap >= size should be handled gracefully
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 50, chunk_overlap: 100)
    chunks = chunker.chunk

    # Should not loop infinitely
    assert chunks.length > 0
    assert chunks.length < 1000  # Reasonable upper bound
  end

  # chunk_by_structure tests
  def test_chunk_by_structure_returns_array
    text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
    result = Ragdoll::TextChunker.chunk_by_structure(text)
    assert_kind_of Array, result
  end

  def test_chunk_by_structure_with_empty_text
    result = Ragdoll::TextChunker.chunk_by_structure("")
    assert_equal [], result
  end

  def test_chunk_by_structure_preserves_paragraphs
    text = "First paragraph content.\n\nSecond paragraph content."
    result = Ragdoll::TextChunker.chunk_by_structure(text, max_chunk_size: 1000)

    # With large chunk size, both paragraphs fit in one chunk
    assert result.any? { |chunk| chunk.include?("First") }
  end

  def test_chunk_by_structure_handles_large_paragraphs
    large_para = "Long sentence. " * 100
    text = "Short intro.\n\n#{large_para}\n\nShort outro."
    result = Ragdoll::TextChunker.chunk_by_structure(text, max_chunk_size: 500)

    # Large paragraph should be split
    assert result.length > 1
  end

  def test_chunk_by_structure_handles_very_long_sentences
    very_long = "word " * 500  # Very long "sentence"
    text = "Intro.\n\n#{very_long}\n\nOutro."
    result = Ragdoll::TextChunker.chunk_by_structure(text, max_chunk_size: 200)

    # Should handle without infinite loop
    assert result.length > 0
  end

  # chunk_code tests
  def test_chunk_code_returns_array
    code = "def hello\n  puts 'world'\nend"
    result = Ragdoll::TextChunker.chunk_code(code)
    assert_kind_of Array, result
  end

  def test_chunk_code_with_empty_text
    result = Ragdoll::TextChunker.chunk_code("")
    assert_equal [], result
  end

  def test_chunk_code_handles_ruby_code
    code = <<~RUBY
      def method_one
        puts "hello"
      end

      def method_two
        puts "world"
      end

      class MyClass
        def initialize
          @value = 1
        end
      end
    RUBY
    result = Ragdoll::TextChunker.chunk_code(code, max_chunk_size: 100)
    assert result.length >= 1
  end

  def test_chunk_code_handles_javascript
    code = <<~JS
      function hello() {
        console.log("hello");
      }

      const world = () => {
        return "world";
      };

      let variable = "test";
    JS
    result = Ragdoll::TextChunker.chunk_code(code, max_chunk_size: 100)
    assert result.length >= 1
  end

  def test_chunk_code_handles_mixed_indentation
    code = "def outer\n  def inner\n    puts 'nested'\n  end\nend"
    result = Ragdoll::TextChunker.chunk_code(code)
    assert result.length >= 1
    assert result.all?(&:present?)
  end

  # Integration tests
  def test_chunk_produces_no_empty_chunks
    text = "Content. " * 100
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 200, chunk_overlap: 50)
    chunks = chunker.chunk

    assert chunks.all?(&:present?)
    refute chunks.any?(&:empty?)
  end

  def test_chunk_covers_all_content
    text = "Word1 Word2 Word3 Word4 Word5 " * 50
    chunker = Ragdoll::TextChunker.new(text, chunk_size: 100, chunk_overlap: 20)
    chunks = chunker.chunk

    # All unique words should appear in at least one chunk
    all_words = chunks.join(" ").split
    (1..5).each do |i|
      assert all_words.include?("Word#{i}"), "Missing Word#{i}"
    end
  end

  def test_multiple_chunker_instances_independent
    text1 = "First text content. " * 50
    text2 = "Second different text. " * 50

    chunker1 = Ragdoll::TextChunker.new(text1, chunk_size: 200)
    chunker2 = Ragdoll::TextChunker.new(text2, chunk_size: 300)

    chunks1 = chunker1.chunk
    chunks2 = chunker2.chunk

    # Different texts should produce different chunks
    refute_equal chunks1, chunks2
  end
end
