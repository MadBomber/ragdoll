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
      class AudioContent < Content
        validate :audio_data_or_transcript_present
        validates :duration, numericality: { greater_than: 0 }, allow_nil: true
        validates :sample_rate, numericality: { greater_than: 0 }, allow_nil: true

        scope :recent, -> { order(created_at: :desc) }
        scope :with_audio, -> { where.not(data: [nil, ""]) }
        scope :with_transcripts, -> { where.not(content: [nil, ""]) }
        scope :by_duration, lambda { |min_duration, max_duration = nil|
          scope = where("duration >= ?", min_duration)
          scope = scope.where("duration <= ?", max_duration) if max_duration
          scope
        }


        # Audio content accessors - content field stores transcript for embedding
        def transcript
          content
        end

        def transcript=(value)
          self.content = value
        end

        # Audio file data accessor
        def audio_data
          data
        end

        def audio_data=(value)
          self.data = value
        end

        # Audio file technical properties (stored in content metadata - raw file data)
        def audio_attached?
          data.present?
        end

        def audio_size
          metadata.dig('file_size') || 0
        end

        def audio_size=(value)
          self.metadata = metadata.merge('file_size' => value)
        end

        def audio_content_type
          metadata.dig('content_type')
        end

        def audio_content_type=(value)
          self.metadata = metadata.merge('content_type' => value)
        end

        def audio_filename
          metadata.dig('filename')
        end

        def audio_filename=(value)
          self.metadata = metadata.merge('filename' => value)
        end

        # Audio format and technical details
        def codec
          metadata.dig('codec')
        end

        def codec=(value)
          self.metadata = metadata.merge('codec' => value)
        end

        def bitrate
          metadata.dig('bitrate')
        end

        def bitrate=(value)
          self.metadata = metadata.merge('bitrate' => value)
        end

        def channels
          metadata.dig('channels')
        end

        def channels=(value)
          self.metadata = metadata.merge('channels' => value)
        end

        def duration_formatted
          return "Unknown" unless duration

          minutes = (duration / 60).floor
          seconds = (duration % 60).round
          "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
        end

        # Override content for embedding to use transcript
        def content_for_embedding
          transcript.presence || "Audio content without transcript"
        end

        def generate_embeddings!
          return unless should_generate_embeddings?

          embedding_content = content_for_embedding
          return if embedding_content.blank?

          # Generate embeddings using the base class method
          super
        end

        # Override should_generate_embeddings to check for transcript
        def should_generate_embeddings?
          content_for_embedding.present? && embeddings.empty?
        end

        def self.stats
          {
            total_audio_contents: count,
            by_model: group(:embedding_model).count,
            total_embeddings: joins(:embeddings).count,
            with_audio: with_audio.count,
            with_transcripts: with_transcripts.count,
            total_duration: sum(:duration),
            average_duration: average(:duration),
            average_audio_size: joins(:audio_attachment).average("active_storage_blobs.byte_size")
          }
        end

        private

        def audio_data_or_transcript_present
          return if audio_attached? || transcript.present?

          errors.add(:base, "Must have either audio data or transcript")
        end
      end
    end
  end
end
