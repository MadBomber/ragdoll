# frozen_string_literal: true

require "active_record"
require_relative "content"

# == Schema Information
#
# Table name: ragdoll_contents (STI)
#
#  id                                                            :bigint           not null, primary key
#  type(Type of content - TextContent, ImageContent, AudioContent) :string         not null
#  document_id(Reference to parent document)                     :bigint           not null
#  embedding_model(Embedding model to use for this content)      :string           not null
#  content(Text content or description of the file)              :text
#  data(Raw data from file)                                      :text
#  metadata(Additional metadata about the file's raw data)       :json             default({})
#  duration(Duration of audio in seconds - for audio content)    :float
#  sample_rate(Audio sample rate in Hz - for audio content)      :integer
#  created_at(Standard creation and update timestamps)           :datetime         not null
#  updated_at(Standard creation and update timestamps)           :datetime         not null
#
# Indexes
#
#  index_ragdoll_contents_on_document_id        (document_id)
#  index_ragdoll_contents_on_embedding_model    (embedding_model)
#  index_ragdoll_contents_on_type               (type)
#  index_ragdoll_contents_on_fulltext_search    (to_tsvector('english'::regconfig, COALESCE(content, ''::text))) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (document_id => ragdoll_documents.id)
#

module Ragdoll
  module Core
    module Models
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
          embedding_service = Ragdoll::Core::EmbeddingService.new

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
  end
end
