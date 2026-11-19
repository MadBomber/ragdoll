# frozen_string_literal: true

require_relative "../../test_helper"

module Ragdoll
  class GenerateEmbeddingsJobTest < Minitest::Test
    TEXT = ("Retrieval augmented generation pairs search with language models. " * 45).strip

    def setup
      super
      skip_if_database_unavailable
      @document = Ragdoll::Document.create!(location: "/path/to/chunks.txt", title: "Chunks",
                                            document_type: "text", status: "pending")
      @document.text_contents.create!(content: TEXT, embedding_model: "test-model")
    end

    def test_perform_chunks_with_the_given_chunk_size_and_overlap
      with_fake_embedding_service do
        Ragdoll::GenerateEmbeddingsJob.new.perform(@document.id, chunk_size: 300, chunk_overlap: 50)
      end

      expected = Ragdoll::TextChunker.chunk(TEXT, chunk_size: 300, chunk_overlap: 50)
      assert_operator expected.length, :>, default_chunk_count
      assert_equal expected, embedded_chunks
    end

    def test_perform_chunks_with_the_configured_chunking_settings
      Ragdoll.configure do |config|
        config.chunking.size = 400
        config.chunking.overlap = 40
      end

      with_fake_embedding_service { Ragdoll::GenerateEmbeddingsJob.new.perform(@document.id) }

      assert_equal Ragdoll::TextChunker.chunk(TEXT, chunk_size: 400, chunk_overlap: 40), embedded_chunks
    end

    private

    def default_chunk_count
      Ragdoll::TextChunker.chunk(TEXT).length
    end

    def embedded_chunks
      Ragdoll::Embedding.where(embeddable: @document.text_contents).order(:chunk_index).pluck(:content)
    end

    def with_fake_embedding_service
      service = Object.new
      service.define_singleton_method(:generate_embedding) { |_text| Array.new(1536) { 0.1 } }
      Ragdoll::EmbeddingService.define_singleton_method(:new) { |*| service }
      yield
    ensure
      Ragdoll::EmbeddingService.singleton_class.remove_method(:new)
    end
  end
end
