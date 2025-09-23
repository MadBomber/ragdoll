# frozen_string_literal: true

require "active_record"

module Ragdoll
  # Unified content model for text-based RAG system
  # All content types (text, image, audio, video) are converted to text
  # and stored in a single content field for unified embedding generation
  class UnifiedContent < ActiveRecord::Base
    self.table_name = "ragdoll_unified_contents"

    belongs_to :document,
               class_name: "Ragdoll::Document",
               foreign_key: "document_id"

    has_many :embeddings,
             class_name: "Ragdoll::Embedding",
             as: :embeddable,
             dependent: :destroy

    validates :content, presence: true
    validates :embedding_model, presence: true
    validates :document_id, presence: true
    validates :original_media_type, presence: true,
                                   inclusion: { in: %w[text image audio video pdf docx html markdown unknown] }

    # JSON columns are handled natively by PostgreSQL

    scope :by_media_type, ->(media_type) { where(original_media_type: media_type) }
    scope :with_embeddings, -> { joins(:embeddings).distinct }
    scope :without_embeddings, -> { left_joins(:embeddings).where(embeddings: { id: nil }) }

    # Generate embeddings for this content
    def generate_embeddings!
      return unless should_generate_embeddings?

      # Clear existing embeddings
      embeddings.destroy_all

      # Use TextChunker to split content into chunks
      chunks = Ragdoll::TextChunker.chunk(content)

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

      update!(metadata: metadata.merge("embeddings_generated_at" => Time.current))
    end

    # Whether this content should generate embeddings
    def should_generate_embeddings?
      content.present? && embeddings.empty?
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

    # Media type specific accessors for backward compatibility
    def text_content?
      %w[text markdown html pdf docx].include?(original_media_type)
    end

    def image_content?
      original_media_type == "image"
    end

    def audio_content?
      original_media_type == "audio"
    end

    def video_content?
      original_media_type == "video"
    end

    # Original media metadata
    def original_filename
      metadata.dig("original_filename")
    end

    def original_filename=(value)
      self.metadata = metadata.merge("original_filename" => value)
    end

    def file_size
      metadata.dig("file_size") || 0
    end

    def file_size=(value)
      self.metadata = metadata.merge("file_size" => value)
    end

    def conversion_method
      metadata.dig("conversion_method")
    end

    def conversion_method=(value)
      self.metadata = metadata.merge("conversion_method" => value)
    end

    # Image-specific metadata (for backward compatibility)
    def image_width
      metadata.dig("width")
    end

    def image_height
      metadata.dig("height")
    end

    def image_dimensions
      width = image_width
      height = image_height
      return nil unless width && height

      { width: width, height: height }
    end

    # Audio-specific metadata
    def audio_duration
      metadata.dig("duration")
    end

    def audio_duration=(value)
      self.metadata = metadata.merge("duration" => value)
    end

    # Content quality scoring
    def content_quality_score
      return 0.0 if content.blank?

      score = 0.0

      # Base score for having content
      score += 0.3

      # Length scoring (normalized)
      if word_count > 0
        # Score based on reasonable content length (50-2000 words is ideal)
        length_score = case word_count
                      when 0..10 then 0.1
                      when 11..50 then 0.5
                      when 51..500 then 1.0
                      when 501..2000 then 0.9
                      when 2001..5000 then 0.7
                      else 0.5
                      end
        score += length_score * 0.4
      end

      # Content type scoring
      type_score = case original_media_type
                  when "text", "markdown" then 1.0
                  when "pdf", "docx", "html" then 0.9
                  when "image" then content.include?("Image file:") ? 0.3 : 0.8
                  when "audio" then content.include?("Audio file:") ? 0.3 : 0.8
                  when "video" then content.include?("Video file:") ? 0.3 : 0.7
                  else 0.5
                  end
      score += type_score * 0.3

      [score, 1.0].min # Cap at 1.0
    end

    # Search within this content type
    def self.search_content(query, **options)
      return none if query.blank?

      where(
        "to_tsvector('english', COALESCE(content, '')) @@ plainto_tsquery('english', ?)",
        query
      ).limit(options[:limit] || 20)
    end

    # Get statistics for all content
    def self.stats
      {
        total_contents: count,
        by_media_type: group(:original_media_type).count,
        by_model: group(:embedding_model).count,
        total_embeddings: joins(:embeddings).count,
        with_embeddings: with_embeddings.count,
        without_embeddings: without_embeddings.count,
        average_word_count: average("LENGTH(content) - LENGTH(REPLACE(content, ' ', '')) + 1"),
        average_character_count: average("LENGTH(content)"),
        content_quality_distribution: {
          high: where("LENGTH(content) > 1000").count,
          medium: where("LENGTH(content) BETWEEN 100 AND 1000").count,
          low: where("LENGTH(content) < 100").count
        }
      }
    end
  end
end