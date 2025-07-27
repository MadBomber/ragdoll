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
      class ImageContent < Content
        validate :image_data_or_description_present

        scope :recent, -> { order(created_at: :desc) }
        scope :with_images, -> { where.not(data: [nil, ""]) }
        scope :with_descriptions, -> { where.not(content: [nil, ""]) }

        # Image content accessors - content field stores description for embedding
        def description
          content
        end

        def description=(value)
          self.content = value
        end

        # Image file data accessor
        def image_data
          data
        end

        def image_data=(value)
          self.data = value
        end

        # Image-specific technical metadata (raw file properties)
        # This metadata is about the actual image file data, not AI-generated insights
        def alt_text
          metadata.dig('alt_text')
        end

        def alt_text=(value)
          self.metadata = metadata.merge('alt_text' => value)
        end

        def embedding_count
          embeddings.count
        end

        # Image file technical properties (stored in content metadata - raw file data)
        def image_attached?
          data.present?
        end

        def image_size
          metadata.dig('file_size') || 0
        end

        def image_size=(value)
          self.metadata = metadata.merge('file_size' => value)
        end

        def image_content_type
          metadata.dig('content_type')
        end

        def image_content_type=(value)
          self.metadata = metadata.merge('content_type' => value)
        end

        def image_filename
          metadata.dig('filename')
        end

        def image_filename=(value)
          self.metadata = metadata.merge('filename' => value)
        end

        def image_dimensions
          width = metadata.dig('width')
          height = metadata.dig('height')
          return nil unless width && height

          { width: width, height: height }
        end

        def set_image_dimensions(width, height)
          self.metadata = metadata.merge('width' => width, 'height' => height)
        end

        # Image format and technical details
        def color_space
          metadata.dig('color_space')
        end

        def color_space=(value)
          self.metadata = metadata.merge('color_space' => value)
        end

        def bit_depth
          metadata.dig('bit_depth')
        end

        def bit_depth=(value)
          self.metadata = metadata.merge('bit_depth' => value)
        end

        # Generate description from image file using LLM vision capabilities
        def generate_description_from_image!(options = {})
          return false unless image_attached? || file_path_available?

          begin
            image_path = get_image_path
            return false unless image_path

            # Use the image description service
            require_relative "../services/image_description_service"
            description_service = Services::ImageDescriptionService.new

            generated_description = description_service.generate_description(image_path, options)

            if generated_description.present?
              self.description = generated_description
              save!
              return true
            end

            false
          rescue StandardError => e
            puts "Failed to generate image description: #{e.message}"
            false
          end
        end

        # Override content for embedding to combine description and alt_text
        def content_for_embedding
          content_parts = []
          content_parts << alt_text if alt_text.present?
          content_parts << description if description.present?
          content_parts.join(" ")
        end

        def generate_embeddings!
          return unless should_generate_embeddings?

          embedding_content = content_for_embedding
          return if embedding_content.blank?

          # Generate embeddings using the base class method
          super
        end

        # Override should_generate_embeddings to check for content
        def should_generate_embeddings?
          content_for_embedding.present? && embeddings.empty?
        end

        def self.stats
          {
            total_image_contents: count,
            by_model: group(:embedding_model).count,
            total_embeddings: joins(:embeddings).count,
            with_images: with_images.count,
            with_descriptions: with_descriptions.count,
            average_image_size: joins(:image_attachment).average("active_storage_blobs.byte_size")
          }
        end

        private

        def file_path_available?
          document&.location&.present? && File.exist?(document.location)
        end

        def get_image_path
          if file_path_available?
            # Use document location if it's an image file
            document.location if image_file?(document.location)
          elsif image_attached?
            # Try to get path from stored data (if it's a file path)
            data if data&.start_with?('/')
          end
        end

        def image_file?(file_path)
          return false unless file_path

          image_extensions = %w[.jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff .tif]
          ext = File.extname(file_path).downcase
          image_extensions.include?(ext)
        end

        def image_data_or_description_present
          return if image_attached? || description.present? || alt_text.present?

          errors.add(:base, "Must have either image data or description/alt_text")
        end
      end
    end
  end
end
