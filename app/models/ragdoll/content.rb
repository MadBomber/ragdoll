# frozen_string_literal: true

require "active_record"

module Ragdoll
  class Content < ActiveRecord::Base
    self.table_name = "ragdoll_contents"

    belongs_to :document,
               class_name: "Ragdoll::Document",
               foreign_key: "document_id"

    has_many :embeddings,
             class_name: "Ragdoll::Embedding",
             as: :embeddable,
             dependent: :destroy

    validates :type, presence: true
    validates :embedding_model, presence: true
    validates :document_id, presence: true

    # JSON columns are handled natively by PostgreSQL

    scope :by_type, ->(content_type) { where(type: content_type) }
    scope :with_embeddings, -> { joins(:embeddings).distinct }
    scope :without_embeddings, -> { left_joins(:embeddings).where(embeddings: { id: nil }) }

    # Generate embeddings for this content
    def generate_embeddings!
      return unless should_generate_embeddings?

      embedding_content = content_for_embedding
      return if embedding_content.blank?

      # Clear existing embeddings
      embeddings.destroy_all

      # Use TextChunker to split content into chunks
      chunks = Ragdoll::Core::TextChunker.chunk(embedding_content)

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

      update!(metadata: metadata.merge("embeddings_generated_at" => Time.current))
    end

    # Content to use for embedding generation (overridden by subclasses)
    def content_for_embedding
      content
    end

    # Whether this content should generate embeddings
    def should_generate_embeddings?
      content_for_embedding.present? && embeddings.empty?
    end

    # Statistics
    def word_count
      return 0 unless content.present?
      content.split(/\s+/).length
    end

    def character_count
      content&.length || 0
    end

    def embedding_count
      embeddings.count
    end

    # Search within this content type
    def self.search_content(query, **options)
      return none if query.blank?

      where(
        "to_tsvector('english', COALESCE(content, '')) @@ plainto_tsquery('english', ?)",
        query
      ).limit(options[:limit] || 20)
    end
  end
end