# frozen_string_literal: true

require "active_record"

module Ragdoll
  # EmbeddingTag - Join table linking embeddings (chunks) to tags
  #
  # Provides chunk-level tagging for more granular retrieval.
  # A document may have tags like "database:postgresql" but a specific
  # chunk might have more specific tags like "database:postgresql:jsonb".
  #
  class EmbeddingTag < ActiveRecord::Base
    self.table_name = "ragdoll_embedding_tags"

    # Associations
    belongs_to :embedding, class_name: "Ragdoll::Embedding"
    belongs_to :tag, class_name: "Ragdoll::Tag"

    # Validations
    validates :embedding_id, presence: true
    validates :tag_id, presence: true
    validates :embedding_id, uniqueness: { scope: :tag_id }
    validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :source, inclusion: { in: %w[auto manual] }

    # Scopes
    scope :auto_extracted, -> { where(source: 'auto') }
    scope :manual, -> { where(source: 'manual') }
    scope :high_confidence, -> { where("confidence >= ?", 0.8) }
    scope :by_confidence, -> { order(confidence: :desc) }

    # Callbacks
    after_create :increment_tag_usage

    private

    def increment_tag_usage
      tag.increment_usage!
    end
  end
end
