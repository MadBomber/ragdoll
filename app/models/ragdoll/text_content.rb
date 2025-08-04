# frozen_string_literal: true

require "active_record"
require_relative "content"

module Ragdoll
  class TextContent < Content
    validates :content, presence: true

    scope :recent, -> { order(created_at: :desc) }

    # Text-specific processing configuration stored in content metadata
    # This metadata is about the raw content processing, not AI-generated insights
    def chunk_size
      metadata.dig('chunk_size') || 1000
    end

    def chunk_size=(value)
      self.metadata = metadata.merge('chunk_size' => value)
    end

    def overlap
      metadata.dig('overlap') || 200
    end

    def overlap=(value)
      self.metadata = metadata.merge('overlap' => value)
    end

    # Content-specific technical metadata (file processing info)
    def encoding
      metadata.dig('encoding')
    end

    def encoding=(value)
      self.metadata = metadata.merge('encoding' => value)
    end

    def line_count
      metadata.dig('line_count')
    end

    def line_count=(value)
      self.metadata = metadata.merge('line_count' => value)
    end

    def word_count
      content&.split&.length || 0
    end

    def character_count
      content&.length || 0
    end

    def embedding_count
      embeddings.count
    end

    # Text-specific processing methods
    def chunks
      return [] if content.blank?

      chunks = []
      start_pos = 0

      while start_pos < content.length
        end_pos = [start_pos + chunk_size, content.length].min

        # Try to break at word boundary if not at end
        if end_pos < content.length
          last_space = content.rindex(" ", end_pos)
          end_pos = last_space if last_space && last_space > start_pos
        end

        chunk_content = content[start_pos...end_pos].strip
        if chunk_content.present?
          chunks << {
            content: chunk_content,
            start_position: start_pos,
            end_position: end_pos,
            chunk_index: chunks.length
          }
        end

        break if end_pos >= content.length

        start_pos = [end_pos - overlap, start_pos + 1].max
      end

      chunks
    end

    def generate_embeddings!
      return if content.blank?

      # Clear existing embeddings
      embeddings.destroy_all

      # Use TextChunker to split content into manageable chunks
      chunks = Ragdoll::Core::TextChunker.chunk(content)

      # Generate embeddings for each chunk
      embedding_service = Ragdoll::EmbeddingService.new

      chunks.each_with_index do |chunk_text, index|
        begin
          vector = embedding_service.generate_embedding(chunk_text)

          embeddings.create!(
            content: chunk_text,
            embedding_vector: vector,
            chunk_index: index
          )
        rescue StandardError => e
          puts "Failed to generate embedding for chunk #{index}: #{e.message}"
        end
      end

      update!(metadata: (metadata || {}).merge("embeddings_generated_at" => Time.current))
    end

    # Override content for embedding to use the text content
    def content_for_embedding
      content
    end

    def self.stats
      {
        total_text_contents:  count,
        by_model:             group(:embedding_model).count,
        total_embeddings:     joins(:embeddings).count,
        average_word_count:   average("LENGTH(content) - LENGTH(REPLACE(content, ' ', '')) + 1"),
        average_chunk_size:   average(:chunk_size)
      }
    end
  end
end